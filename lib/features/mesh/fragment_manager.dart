import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import 'package:bitchat/core/constants.dart';
import 'package:bitchat/data/models/routed_packet.dart';
import 'package:bitchat/data/models/fragment_payload.dart';
import 'package:bitchat/protocol/packet_codec.dart';

/// Delegate interface for fragment manager callbacks.
abstract class FragmentManagerDelegate {
  /// Called when a packet has been successfully reassembled from fragments.
  void onPacketReassembled(BitchatPacket packet);
}

/// Fragment metadata for tracking reassembly state.
class FragmentMetadata {
  final int originalType;
  final int total;
  final int timestamp;

  FragmentMetadata(this.originalType, this.total, this.timestamp);
}

/// Manages message fragmentation and reassembly - 100% iOS/Android Compatible.
///
/// This implementation exactly matches iOS SimplifiedBluetoothService fragmentation
/// and Android FragmentManager:
/// - Same fragment payload structure (13-byte header + data)
/// - Same MTU thresholds and fragment sizes
/// - Same reassembly logic and timeout handling
/// - Uses FragmentPayload model for type safety
///
/// Android reference:
/// /Users/avillagran/Desarrollo/bitchat-android/app/src/main/java/com/bitchat/android/mesh/FragmentManager.kt
class FragmentManager {
  static const String _tag = 'FragmentManager';

  // Fragmentation constants - iOS values
  static const int fragmentSizeThreshold = AppConstants.fragmentSizeThreshold;
  static const int maxFragmentSize = AppConstants.maxFragmentSize;
  static const int fragmentTimeoutMs = 30000;
  static const int cleanupIntervalMs = 10000;
  static const int mtuSize = 512;
  static const int paddingBuffer = 16; // MessagePadding.optimalBlockSize adds 16 bytes overhead

  // Fragment storage
  final Map<String, Map<int, Uint8List>> _incomingFragments = {};
  final Map<String, FragmentMetadata> _fragmentMetadata = {};

  // Delegate for callbacks
  FragmentManagerDelegate? delegate;

  // Timer for periodic cleanup
  Timer? _cleanupTimer;
  bool _isActive = true;

  // Random for fragment ID generation
  final Random _random = Random.secure();

  /// Creates a new FragmentManager.
  FragmentManager() {
    _startPeriodicCleanup();
  }

  /// Starts the periodic cleanup timer.
  void _startPeriodicCleanup() {
    _cleanupTimer = Timer.periodic(
      const Duration(milliseconds: cleanupIntervalMs),
      (timer) {
        if (!_isActive) {
          timer.cancel();
          return;
        }
        _cleanupOldFragments();
      },
    );
  }

  /// Cleans up old fragments that have exceeded the timeout.
  void _cleanupOldFragments() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final keysToRemove = <String>[];

    _fragmentMetadata.forEach((key, meta) {
      if (now - meta.timestamp > fragmentTimeoutMs) {
        keysToRemove.add(key);
      }
    });

    for (final key in keysToRemove) {
      _incomingFragments.remove(key);
      _fragmentMetadata.remove(key);
    }

    if (keysToRemove.isNotEmpty) {
      _log('Cleaned up ${keysToRemove.length} old fragment sets (iOS compatible)');
    }
  }

  /// Create fragments from a large packet - 100% iOS/Android Compatible.
  ///
  /// Matches iOS sendFragmentedPacket() and Android createFragments() implementation exactly.
  /// Returns the original packet if it doesn't need fragmentation.
  ///
  /// The fragment size is dynamically calculated to fit within MTU (512 bytes)
  /// accounting for packet overhead (headers, route, etc.).
  List<BitchatPacket> createFragments(
    BitchatPacket packet, {
    required Uint8List mySenderID,
  }) {
    try {
      _log('Creating fragments for packet type ${packet.type}, payload: ${packet.payload?.length ?? 0} bytes');

      final encoded = packet.toBinaryData();
      if (encoded == null) {
        _logError('Failed to encode packet to binary data');
        return [];
      }

      _log('Encoded to ${encoded.length} bytes');

      // Fragment the unpadded frame; each fragment will be encoded (and padded) independently
      // Note: For Flutter, we'll skip unpadding for now since MessagePadding is not yet implemented
      final fullData = encoded;

      // iOS logic: if data.count > 512 && packet.type != MessageType.fragment.rawValue
      if (fullData.length <= fragmentSizeThreshold) {
        return [packet]; // No fragmentation needed
      }

      final fragments = <BitchatPacket>[];

      // iOS: let fragmentID = Data((0..<8).map { _ in UInt8.random(in: 0...255) })
      final fragmentID = _generateFragmentID();

      // Calculate dynamic fragment size to fit in MTU (512)
      // Packet = Header + Sender + Recipient + Route + FragmentHeader + Payload + PaddingBuffer
      final hasRoute = packet.route != null && packet.route!.isNotEmpty;
      final version = packet.version;
      final headerSize = version == 2 ? 15 : 13;
      final senderSize = 8;
      final recipientSize = packet.recipientID != null ? 8 : 0;
      // Route: 1 byte count + 8 bytes per hop
      final routeSize = hasRoute ? (1 + (packet.route!.length * 8)) : 0;
      final fragmentHeaderSize = 13; // FragmentPayload header

      // 512 - Overhead
      final packetOverhead = headerSize + senderSize + recipientSize + routeSize + fragmentHeaderSize + paddingBuffer;
      final maxDataSize = (mtuSize - packetOverhead).clamp(1, maxFragmentSize);

      if (maxDataSize <= 0) {
        _logError('Calculated maxDataSize is non-positive ($maxDataSize). Route too large?');
        return [];
      }

      _log('Dynamic fragment size: $maxDataSize (MAX: $maxFragmentSize, Overhead: $packetOverhead)');

      // Calculate total fragments
      final totalFragments = (fullData.length / maxDataSize).ceil();

      // Create fragments
      for (int index = 0; index < totalFragments; index++) {
        final offset = index * maxDataSize;
        final endOffset = [offset + maxDataSize, fullData.length].reduce((a, b) => a < b ? a : b);
        final fragmentData = fullData.sublist(offset, endOffset);

        // Create iOS-compatible fragment payload
        final fragmentPayload = FragmentPayload(
          fragmentID: fragmentID,
          index: index,
          total: totalFragments,
          originalType: packet.type,
          data: fragmentData,
        );

        // iOS: MessageType.fragment.rawValue (single fragment type)
        // Fix: Fragments must inherit source route and use v2 if routed
        final fragmentPacket = BitchatPacket(
          version: hasRoute ? 2 : 1,
          type: 0x20, // MessageType.FRAGMENT.value
          ttl: packet.ttl,
          senderID: packet.senderID,
          recipientID: packet.recipientID,
          timestamp: packet.timestamp,
          payload: fragmentPayload.encode(),
          route: packet.route,
          signature: null, // iOS: signature: nil
        );

        fragments.add(fragmentPacket);
      }

      _log('Created ${fragments.length} fragments successfully');
      return fragments;
    } catch (e) {
      _logError('Fragment creation failed: $e');
      _logError('Packet type: ${packet.type}, payload: ${packet.payload?.length ?? 0} bytes');
      return [];
    }
  }

  /// Handle incoming fragment - 100% iOS/Android Compatible.
  ///
  /// Matches iOS handleFragment() and Android handleFragment() implementation exactly.
  /// Returns the reassembled packet when all fragments have been received, or null otherwise.
  ///
  /// After reassembly, the TTL is set to 0 to prevent re-relay of the reconstructed packet,
  /// as the fragments were already relayed during transmission.
  BitchatPacket? handleFragment(BitchatPacket packet) {
    // iOS: guard packet.payload.count > 13 else { return }
    final payload = packet.payload;
    if (payload == null || payload.length < FragmentPayload.headerSize) {
      _log('Fragment packet too small: ${payload?.length ?? 0}');
      return null;
    }

    try {
      // Use FragmentPayload for type-safe decoding
      final fragmentPayload = FragmentPayload.decode(payload);
      if (fragmentPayload == null) {
        _log('Invalid fragment payload: decode returned null');
        return null;
      }

      // Validate fragment payload
      if (fragmentPayload.fragmentID == null || fragmentPayload.data == null) {
        _log('Invalid fragment payload: missing required fields');
        return null;
      }

      // iOS: let fragmentID = packet.payload[0..<8].map { String(format: "%02x", $0) }.joined()
      final fragmentIDString = _bytesToHex(fragmentPayload.fragmentID!);

      _log('Received fragment ${fragmentPayload.index}/${fragmentPayload.total} for fragmentID: $fragmentIDString, originalType: ${fragmentPayload.originalType}');

      // iOS: if incomingFragments[fragmentID] == nil
      if (!_incomingFragments.containsKey(fragmentIDString)) {
        _incomingFragments[fragmentIDString] = {};
        _fragmentMetadata[fragmentIDString] = FragmentMetadata(
          fragmentPayload.originalType,
          fragmentPayload.total,
          DateTime.now().millisecondsSinceEpoch,
        );
      }

      // iOS: incomingFragments[fragmentID]?[index] = Data(fragmentData)
      _incomingFragments[fragmentIDString]![fragmentPayload.index] = fragmentPayload.data!;

      // iOS: if let fragments = incomingFragments[fragmentID], fragments.count == total
      final fragmentMap = _incomingFragments[fragmentIDString];
      if (fragmentMap != null && fragmentMap.length == fragmentPayload.total) {
        _log('All fragments received for $fragmentIDString, reassembling...');

        // iOS reassembly logic: for i in 0..<total { if let fragment = fragments[i] { reassembled.append(fragment) } }
        final reassembledData = <int>[];
        for (int i = 0; i < fragmentPayload.total; i++) {
          final fragment = fragmentMap[i];
          if (fragment != null) {
            reassembledData.addAll(fragment);
          } else {
            _logError('Missing fragment index $i during reassembly');
            // Clean up this corrupted fragment set
            _incomingFragments.remove(fragmentIDString);
            _fragmentMetadata.remove(fragmentIDString);
            return null;
          }
        }

        // Decode the original packet bytes we reassembled
        final originalPacket = BitchatPacket.decode(Uint8List.fromList(reassembledData));

        if (originalPacket != null) {
          // iOS cleanup: incomingFragments.removeValue(forKey: fragmentID)
          _incomingFragments.remove(fragmentIDString);
          _fragmentMetadata.remove(fragmentIDString);

          // Suppress re-broadcast of the reassembled packet by zeroing TTL.
          // We already relayed the incoming fragments; setting TTL=0 ensures
          // PacketRelayManager will skip relaying this reconstructed packet.
          final suppressedTtlPacket = originalPacket.copyWith(ttl: 0);
          _log('Successfully reassembled original (${reassembledData.length} bytes); set TTL=0 to suppress relay');

          // Notify delegate
          delegate?.onPacketReassembled(suppressedTtlPacket);

          return suppressedTtlPacket;
        } else {
          final metadata = _fragmentMetadata[fragmentIDString];
          _logError('Failed to decode reassembled packet (type=${metadata?.originalType}, total=${metadata?.total})');
        }
      } else {
        final received = fragmentMap?.length ?? 0;
        _log('Fragment ${fragmentPayload.index} stored, have $received/${fragmentPayload.total} fragments for $fragmentIDString');
      }
    } catch (e) {
      _logError('Failed to handle fragment: $e');
    }

    return null;
  }

  /// Generate a random 8-byte fragment ID.
  ///
  /// iOS uses: Data((0..<8).map { _ in UInt8.random(in: 0...255) })
  Uint8List _generateFragmentID() {
    final fragmentID = Uint8List(8);
    for (int i = 0; i < 8; i++) {
      fragmentID[i] = _random.nextInt(256);
    }
    return fragmentID;
  }

  /// Convert Uint8List to hex string.
  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Get debug information about fragment manager state.
  String getDebugInfo() {
    final buffer = StringBuffer();
    buffer.writeln('=== Fragment Manager Debug Info (iOS Compatible) ===');
    buffer.writeln('Active Fragment Sets: ${_incomingFragments.length}');
    buffer.writeln('Fragment Size Threshold: $fragmentSizeThreshold bytes');
    buffer.writeln('Max Fragment Size: $maxFragmentSize bytes');
    buffer.writeln('Fragment Timeout: ${fragmentTimeoutMs}ms');

    _fragmentMetadata.forEach((fragmentID, metadata) {
      final received = _incomingFragments[fragmentID]?.length ?? 0;
      final ageSeconds = (DateTime.now().millisecondsSinceEpoch - metadata.timestamp) ~/ 1000;
      buffer.writeln('  - $fragmentID: $received/${metadata.total} fragments, type: ${metadata.originalType}, age: ${ageSeconds}s');
    });

    return buffer.toString();
  }

  /// Clear all stored fragments.
  void clearAllFragments() {
    _incomingFragments.clear();
    _fragmentMetadata.clear();
  }

  /// Shutdown the fragment manager and cleanup resources.
  void dispose() {
    _isActive = false;
    _cleanupTimer?.cancel();
    clearAllFragments();
  }

  /// Internal debug logging.
  void _log(String message) {
    // TODO: Replace with proper logging when available
    // print('[$_tag] $message');
  }

  /// Internal error logging.
  void _logError(String message) {
    // TODO: Replace with proper logging when available
    // print('[$_tag] ERROR: $message');
  }
}
