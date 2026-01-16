import 'dart:math';
import 'dart:typed_data';
import 'package:bitchat/data/models/routed_packet.dart';
import 'package:bitchat/protocol/packet_codec.dart';

/// Delegate interface for packet relay manager callbacks.
///
/// Implementations must provide network information and packet transmission methods.
abstract class PacketRelayManagerDelegate {
  /// Gets the current network size (number of connected peers).
  int getNetworkSize();

  /// Gets the broadcast recipient identifier (all 0xFF bytes).
  Uint8List getBroadcastRecipient();

  /// Broadcasts a packet to all connected peers.
  void broadcastPacket(RoutedPacket routed);

  /// Sends a packet to a specific peer by ID.
  /// Returns true if the peer was directly connected and the packet was sent successfully.
  bool sendToPeer(String peerID, RoutedPacket routed);
}

/// Centralized packet relay management.
///
/// Handles all relay decisions and logic for bitchat packets.
/// All packets that aren't specifically addressed to us get processed here.
///
/// This implementation is in parity with the Android version at:
/// /Users/avillagran/Desarrollo/bitchat-android/app/src/main/java/com/bitchat/android/mesh/PacketRelayManager.kt
class PacketRelayManager {
  static const String _tag = 'PacketRelayManager';

  /// Our local peer ID (hex string).
  final String myPeerID;

  /// Delegate for callbacks and network operations.
  PacketRelayManagerDelegate? delegate;

  /// Random instance for adaptive relay probability decisions.
  final Random _random = Random();

  /// Creates a new PacketRelayManager with the given peer ID.
  PacketRelayManager(this.myPeerID);

  /// Main entry point for relay decisions.
  ///
  /// Only packets that aren't specifically addressed to us should be passed here.
  /// This method implements the full relay logic:
  /// 1. Check if packet is addressed to us (skip if so)
  /// 2. Skip our own packets
  /// 3. Check TTL and decrement
  /// 4. Try source-routed forwarding if applicable
  /// 5. Fall back to broadcast with adaptive probability
  ///
  /// Throws [StateError] if delegate is not set.
  Future<void> handlePacketRelay(RoutedPacket routed) async {
    final packet = routed.packet;
    final peerID = routed.peerID ?? 'unknown';

    _log('Evaluating relay for packet type ${packet.type} from $peerID (TTL: ${packet.ttl})');

    // Double-check this packet isn't addressed to us
    if (isPacketAddressedToMe(packet)) {
      _log('Packet addressed to us, skipping relay');
      return;
    }

    // Skip our own packets
    if (peerID == myPeerID) {
      _log('Packet from ourselves, skipping relay');
      return;
    }

    // Check TTL and decrement
    if (packet.ttl == 0) {
      _log('TTL expired, not relaying packet');
      return;
    }

    // Decrement TTL by 1
    final relayPacket = packet.copyWith(ttl: packet.ttl - 1);
    _log('Decremented TTL from ${packet.ttl} to ${relayPacket.ttl}');

    // Source-based routing: if route is set and includes us, try targeted next-hop forwarding
    final route = relayPacket.route;
    if (route != null && route.isNotEmpty) {
      // Check for duplicate hops to prevent routing loops
      final hexHops = route.map((h) => _bytesToHex(h)).toSet();
      if (hexHops.length < route.length) {
        _logWarning('Packet with duplicate hops dropped');
        return;
      }

      final myIdBytes = _hexToBytes(myPeerID);
      final index = route.indexWhere((h) => _listEquals(h, myIdBytes));

      if (index >= 0) {
        // We're in the route, try to forward to next hop
        String? nextHopIdHex;
        final nextIndex = index + 1;

        if (nextIndex < route.length) {
          // There's another hop in the route
          nextHopIdHex = _bytesToHex(route[nextIndex]);
        } else {
          // We are the last intermediate; try final recipient as next hop
          if (relayPacket.recipientID != null) {
            nextHopIdHex = _bytesToHex(relayPacket.recipientID!);
          }
        }

        if (nextHopIdHex != null) {
          bool success = false;
          try {
            success = delegate?.sendToPeer(
                  nextHopIdHex,
                  routed.copyWith(packet: relayPacket),
                ) ??
                false;
          } catch (e) {
            _logError('Error sending to peer $nextHopIdHex: $e');
            success = false;
          }

          if (success) {
            _logInfo('Source-route relay: ${peerID.substring(0, 8)} -> ${nextHopIdHex.substring(0, 8)} (type ${packet.type}, TTL ${relayPacket.ttl})');
            return;
          } else {
            _log('Source-route next hop ${nextHopIdHex.substring(0, 8)} not directly connected; falling back to broadcast');
          }
        }
      }
    }

    // Apply relay logic based on network conditions
    if (_isRelayEnabled() && shouldRelayPacket(relayPacket, peerID)) {
      _relayPacket(RoutedPacket(packet: relayPacket, peerID: peerID, relayAddress: routed.relayAddress));
    } else {
      _log('Relay decision: NOT relaying packet type ${packet.type}');
    }
  }

  /// Check if a packet is specifically addressed to us.
  ///
  /// Returns true if the packet's recipient ID matches our peer ID.
  /// Returns false for broadcast packets or packets without a recipient.
  bool isPacketAddressedToMe(BitchatPacket packet) {
    final recipientID = packet.recipientID;

    // No recipient means broadcast (not addressed to us specifically)
    if (recipientID == null) {
      return false;
    }

    // Check if it's a broadcast recipient
    final broadcastRecipient = delegate?.getBroadcastRecipient();
    if (broadcastRecipient != null && _listEquals(recipientID, broadcastRecipient)) {
      return false;
    }

    // Check if recipient matches our peer ID
    final recipientIDString = _bytesToHex(recipientID);
    return recipientIDString == myPeerID;
  }

  /// Determine if we should relay this packet based on type and network conditions.
  ///
  /// Uses adaptive relay probability based on network size:
  /// - Networks <= 10 peers: Always relay (100%)
  /// - Networks <= 30 peers: High probability (85%)
  /// - Networks <= 50 peers: Moderate probability (70%)
  /// - Networks <= 100 peers: Lower probability (55%)
  /// - Networks > 100 peers: Lowest probability (40%)
  ///
  /// High TTL (>= 4) packets are always relayed regardless of network size.
  bool shouldRelayPacket(BitchatPacket packet, String fromPeerID) {
    // Always relay if TTL is high enough (indicates important message)
    if (packet.ttl >= 4) {
      _log('High TTL (${packet.ttl}), relaying');
      return true;
    }

    // Get network size for adaptive relay probability
    final networkSize = delegate?.getNetworkSize() ?? 1;

    // Small networks always relay to ensure connectivity
    if (networkSize <= 3) {
      _log('Small network ($networkSize peers), relaying');
      return true;
    }

    // Apply adaptive relay probability based on network size
    final double relayProb;
    if (networkSize <= 10) {
      relayProb = 1.0; // Always relay in small networks
    } else if (networkSize <= 30) {
      relayProb = 0.85; // High probability for medium networks
    } else if (networkSize <= 50) {
      relayProb = 0.7; // Moderate probability
    } else if (networkSize <= 100) {
      relayProb = 0.55; // Lower probability for large networks
    } else {
      relayProb = 0.4; // Lowest probability for very large networks
    }

    final shouldRelay = _random.nextDouble() < relayProb;
    _log('Network size: $networkSize, Relay probability: $relayProb, Decision: $shouldRelay');

    return shouldRelay;
  }

  /// Actually broadcast the packet for relay.
  void _relayPacket(RoutedPacket routed) {
    _log('Relaying packet type ${routed.packet.type} with TTL ${routed.packet.ttl}');
    delegate?.broadcastPacket(routed);
  }

  /// Check if packet relay is enabled.
  ///
  /// In a production environment, this would check debug settings.
  /// For now, always returns true.
  bool _isRelayEnabled() {
    // TODO: Integrate with debug settings when available
    return true;
  }

  /// Get debug information about the relay manager state.
  String getDebugInfo() {
    return '''
=== Packet Relay Manager Debug Info ===
My Peer ID: $myPeerID
Network Size: ${delegate?.getNetworkSize() ?? 'unknown'}
Relay Enabled: ${_isRelayEnabled()}
''';
  }

  /// Convert hex string peer ID to 8-byte Uint8List.
  Uint8List _hexToBytes(String hex) {
    final result = Uint8List(8);
    int idx = 0;
    int out = 0;

    while (idx + 1 < hex.length && out < 8) {
      final byteStr = hex.substring(idx, idx + 2);
      try {
        result[out] = int.parse(byteStr, radix: 16);
      } catch (e) {
        result[out] = 0; // Default to 0 on parse error
      }
      idx += 2;
      out++;
    }

    return result;
  }

  /// Convert Uint8List to hex string.
  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Compare two Uint8Lists for equality.
  bool _listEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Internal debug logging at debug level.
  void _log(String message) {
    // TODO: Replace with proper logging when available
    // print('[$_tag] $message');
  }

  /// Internal debug logging at info level.
  void _logInfo(String message) {
    // TODO: Replace with proper logging when available
    // print('[$_tag] INFO: $message');
  }

  /// Internal debug logging at warning level.
  void _logWarning(String message) {
    // TODO: Replace with proper logging when available
    // print('[$_tag] WARNING: $message');
  }

  /// Internal debug logging at error level.
  void _logError(String message) {
    // TODO: Replace with proper logging when available
    // print('[$_tag] ERROR: $message');
  }
}
