import 'package:freezed_annotation/freezed_annotation.dart';

/// Message types for Bitchat packets.
/// Exact same as Android version with Noise Protocol support.
enum MessageType {
  /// Identity announcement packet (0x01)
  announce(0x01),

  /// All user messages - private and broadcast (0x02)
  message(0x02),

  /// Peer leaving the mesh (0x03)
  leave(0x03),

  /// Noise protocol handshake (0x10)
  noiseHandshake(0x10),

  /// Noise encrypted transport message (0x11)
  noiseEncrypted(0x11),

  /// Fragmentation for large packets (0x20)
  fragment(0x20),

  /// Request sync packet for GCS-based sync (0x21)
  requestSync(0x21),

  /// File transfer packet - BLE voice notes, images, etc. (0x22)
  fileTransfer(0x22);

  final int value;

  const MessageType(this.value);

  /// Get MessageType from integer value, returns null if unknown.
  static MessageType? fromValue(int value) {
    try {
      return MessageType.values.firstWhere((type) => type.value == value);
    } catch (_) {
      return null;
    }
  }

  /// Get the string representation for debugging.
  String get name {
    switch (this) {
      case MessageType.announce:
        return 'ANNOUNCE';
      case MessageType.message:
        return 'MESSAGE';
      case MessageType.leave:
        return 'LEAVE';
      case MessageType.noiseHandshake:
        return 'NOISE_HANDSHAKE';
      case MessageType.noiseEncrypted:
        return 'NOISE_ENCRYPTED';
      case MessageType.fragment:
        return 'FRAGMENT';
      case MessageType.requestSync:
        return 'REQUEST_SYNC';
      case MessageType.fileTransfer:
        return 'FILE_TRANSFER';
    }
  }
}

/// Special recipient IDs - exact same as Android version.
class SpecialRecipients {
  /// Broadcast recipient ID - all 0xFF bytes
  static const broadcastRecipient = <int>[
    0xFF,
    0xFF,
    0xFF,
    0xFF,
    0xFF,
    0xFF,
    0xFF,
    0xFF,
  ];
}
