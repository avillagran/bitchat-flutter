import 'dart:async';
import 'dart:typed_data';
import 'package:bitchat/data/models/bitchat_file_packet.dart';
import 'package:bitchat/data/models/routed_packet.dart';
import 'package:bitchat/data/models/fragment_payload.dart';
import 'package:bitchat/features/mesh/fragment_manager.dart';

/// Simple file transfer helper used by tests.
///
/// Provides fragmentation, incoming fragment handling and a progress stream.
class FileTransferManager implements FragmentManagerDelegate {
  final FragmentManager _fragmentManager;

  // Track received fragment indices per fragmentID
  final Map<String, Set<int>> _receivedIndices = {};
  final Map<String, int> _expectedTotals = {};

  final StreamController<FileTransferProgress> _progressController =
      StreamController.broadcast();

  FileTransferManager({FragmentManager? fragmentManager})
      : _fragmentManager = fragmentManager ?? FragmentManager() {
    _fragmentManager.delegate = this;
  }

  Stream<FileTransferProgress> get progressStream => _progressController.stream;

  /// Create a BitchatPacket that wraps the file packet as payload with fileTransfer type.
  BitchatPacket createFilePacket(BitchatFilePacket file) {
    final payload = file.encode();
    return BitchatPacket(
      version: 1,
      type: 0x22, // fileTransfer
      ttl: 7,
      senderID: Uint8List(8),
      recipientID: null,
      timestamp: DateTime.now(),
      payload: payload,
      route: null,
      signature: null,
    );
  }

  /// Fragment the packet using FragmentManager logic.
  List<BitchatPacket> fragmentPacket(BitchatPacket packet,
      {required Uint8List mySenderID}) {
    return _fragmentManager.createFragments(packet, mySenderID: mySenderID);
  }

  /// Handle an incoming fragment packet. Returns the reassembled packet if complete.
  Future<BitchatPacket?> handleIncomingFragment(
      BitchatPacket fragmentPacket) async {
    try {
      final payload = fragmentPacket.payload;
      if (payload == null) return null;

      // Decode fragment payload to extract metadata for progress tracking
      final frag = FragmentPayload.decode(payload);
      if (frag == null) return null;
      final id = _bytesToHex(frag.fragmentID!);

      _expectedTotals[id] = frag.total;
      _receivedIndices.putIfAbsent(id, () => <int>{});
      _receivedIndices[id]!.add(frag.index);

      // Emit progress
      final received = _receivedIndices[id]!.length;
      final total = frag.total;
      final progress = received / total;
      _progressController
          .add(FileTransferProgress(transferId: id, progress: progress));

      // Let fragment manager handle reassembly and delegate callback
      final reassembled = _fragmentManager.handleFragment(fragmentPacket);
      if (reassembled != null) {
        // Completed - ensure progress=1.0 emitted
        _progressController
            .add(FileTransferProgress(transferId: id, progress: 1.0));
      }

      return reassembled;
    } catch (e) {
      return null;
    }
  }

  @override
  void onPacketReassembled(BitchatPacket packet) {
    // Called when FragmentManager reassembles a packet; emit generic progress with unknown ID
    _progressController
        .add(FileTransferProgress(transferId: 'reassembled', progress: 1.0));
  }

  String _bytesToHex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  void dispose() {
    _fragmentManager.dispose();
    _progressController.close();
  }
}

class FileTransferProgress {
  final String transferId;
  final double progress; // 0.0 - 1.0
  FileTransferProgress({required this.transferId, required this.progress});
}
