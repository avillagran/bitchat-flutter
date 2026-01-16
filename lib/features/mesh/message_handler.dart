import 'dart:typed_data';
import 'package:bitchat/data/models/bitchat_message.dart';
import 'package:bitchat/data/models/bitchat_file_packet.dart';
import 'package:bitchat/data/models/identity_announcement.dart';
import 'package:bitchat/data/models/routed_packet.dart';
import 'package:bitchat/protocol/message_type.dart';
import 'package:bitchat/protocol/packet_codec.dart';

/// Handles processing of different message types in mesh network.
/// Extracted from BluetoothMeshService for better separation of concerns.
/// Provides packet deserialization and routing to correct handlers.
///
/// This implementation maintains Android parity with MessageHandler.kt
/// in bitchat-android project.
class MessageHandler {
  /// The local peer ID for this instance.
  final String myPeerID;

  /// Delegate for callbacks and external operations.
  MessageHandlerDelegate? delegate;

  /// Creates a new MessageHandler with the given local peer ID.
  MessageHandler(this.myPeerID);

  /// Main entry point for processing a routed packet.
  /// Deserializes the packet and routes it to the appropriate handler.
  ///
  /// Returns true if the packet was successfully processed, false otherwise.
  Future<bool> processPacket(RoutedPacket routed) async {
    try {
      final packet = routed.packet;
      final peerID = routed.peerID ?? 'unknown';

      // Skip our own packets
      if (peerID == myPeerID) {
        return false;
      }

      final messageType = MessageType.fromValue(packet.type);
      if (messageType == null) {
        delegate?.logWarning(
          'Unknown packet type: ${packet.type} from peer $peerID',
        );
        return false;
      }

      delegate?.logInfo(
        'Processing packet type ${messageType.name} from peer $peerID',
      );

      // Route to appropriate handler based on message type
      return await _routePacket(messageType, routed);
    } catch (e, stackTrace) {
      delegate?.logError(
        'Error processing packet: $e',
        stackTrace,
      );
      return false;
    }
  }

  /// Routes a packet to the appropriate handler based on its type.
  Future<bool> _routePacket(
    MessageType messageType,
    RoutedPacket routed,
  ) async {
    final packet = routed.packet;
    final peerID = routed.peerID ?? 'unknown';

    // Check if packet is addressed to us (for private packet types)
    final isAddressedToMe = _isPacketAddressedToMe(packet);

    switch (messageType) {
      case MessageType.announce:
        return await _handleAnnounce(routed);

      case MessageType.message:
      case MessageType.fileTransfer:
        return await _handleMessage(routed);

      case MessageType.leave:
        return await _handleLeave(routed);

      case MessageType.fragment:
        return await _handleFragment(routed);

      case MessageType.noiseHandshake:
        if (isAddressedToMe) {
          return await _handleNoiseHandshake(routed);
        } else {
          delegate?.logInfo(
            'Noise handshake not addressed to us from peer $peerID',
          );
          return false;
        }

      case MessageType.noiseEncrypted:
        if (isAddressedToMe) {
          return await _handleNoiseEncrypted(routed);
        } else {
          delegate?.logInfo(
            'Noise encrypted message not addressed to us from peer $peerID',
          );
          return false;
        }

      case MessageType.requestSync:
        return await _handleRequestSync(routed);
    }
  }

  /// Checks if a packet is addressed to this peer.
  bool _isPacketAddressedToMe(BitchatPacket packet) {
    if (packet.recipientID == null) {
      return false;
    }

    final recipientHex = _bytesToHex(packet.recipientID!);
    return recipientHex == myPeerID;
  }

  /// Handles an ANNOUNCE packet.
  /// Verifies the announcement and updates peer information.
  Future<bool> _handleAnnounce(RoutedPacket routed) async {
    final packet = routed.packet;
    final peerID = routed.peerID ?? 'unknown';

    try {
      final payload = packet.payload ?? Uint8List(0);
      
      // Decode the announcement payload
      final announcement = IdentityAnnouncement.decode(payload);
      if (announcement == null) {
        delegate?.logWarning(
          'Failed to decode announce from peer $peerID',
        );
        return false;
      }

      // Verify packet signature if present
      var isVerified = packet.signature != null;
      if (packet.signature != null) {
        final dataToVerify = _getPacketDataForSigning(packet);
        if (dataToVerify != null &&
            announcement.signingPublicKey != null) {
          isVerified = await delegate?.verifyEd25519Signature(
                packet.signature!,
                dataToVerify,
                announcement.signingPublicKey!,
              ) ??
              false;
        }

        if (!isVerified) {
          delegate?.logWarning(
            'Signature verification for announce failed from peer $peerID',
          );
          // Don't return false here, just log warning (Android parity)
        }
      }

      // Check for existing peer with different noise public key
      final existingPeer = await delegate?.getPeerInfo(peerID);
      if (existingPeer != null &&
          existingPeer.noisePublicKey != null &&
          announcement.noisePublicKey != null &&
          !_listsEqual(existingPeer.noisePublicKey!, announcement.noisePublicKey!)) {
        delegate?.logWarning(
          'Announce key mismatch for peer $peerID - keeping unverified',
        );
        isVerified = false;
      }

      // Ignore unverified announces (security requirement)
      if (!isVerified) {
        delegate?.logWarning(
          'Ignoring unverified announce from peer $peerID',
        );
        return false;
      }

      // Update peer info with verified status
      await delegate?.updatePeerInfo(
        peerID: peerID,
        nickname: announcement.nickname,
        noisePublicKey: announcement.noisePublicKey,
        signingPublicKey: announcement.signingPublicKey,
        isVerified: isVerified,
      );

      delegate?.logInfo(
        'Successfully processed announce from peer $peerID: '
        '${announcement.nickname}',
      );

      return true;
    } catch (e, stackTrace) {
      delegate?.logError(
        'Error handling announce from peer $peerID: $e',
        stackTrace,
      );
      return false;
    }
  }

  /// Handles a MESSAGE or FILE_TRANSFER packet.
  /// Routes to broadcast or private message handler based on recipient.
  Future<bool> _handleMessage(RoutedPacket routed) async {
    final packet = routed.packet;
    final peerID = routed.peerID ?? 'unknown';

    try {
      // Check if this is a broadcast message
      if (_isBroadcastRecipient(packet.recipientID)) {
        return await _handleBroadcastMessage(routed);
      } else if (_isPacketAddressedToMe(packet)) {
        return await _handlePrivateMessage(routed);
      } else {
        // Message not for us, ignore (relay handled elsewhere)
        return false;
      }
    } catch (e, stackTrace) {
      delegate?.logError(
        'Error handling message from peer $peerID: $e',
        stackTrace,
      );
      return false;
    }
  }

  /// Handles a broadcast message.
  Future<bool> _handleBroadcastMessage(RoutedPacket routed) async {
    final packet = routed.packet;
    final peerID = routed.peerID ?? 'unknown';

    // Get peer info to check verification status
    final peerInfo = await delegate?.getPeerInfo(peerID);
    if (peerInfo == null || !peerInfo.isVerifiedNickname) {
      delegate?.logWarning(
        'Dropping public message from unverified peer $peerID',
      );
      return false;
    }

    try {
      final payload = packet.payload ?? Uint8List(0);
      
      // Try file packet first
      final messageType = MessageType.fromValue(packet.type);
      if (messageType == MessageType.fileTransfer) {
        final file = BitchatFilePacket.decode(payload);
        if (file != null) {
          return await _handleFilePacket(file, peerID, packet, isPrivate: false);
        }
      }

      // Fallback: plain text message
      final message = BitchatMessage(
        sender: peerInfo.nickname,
        content: String.fromCharCodes(payload),
        type: BitchatMessageType.Message,
        timestamp: packet.timestamp,
        senderPeerID: peerID,
      );

      delegate?.onMessageReceived(message);
      return true;
    } catch (e, stackTrace) {
      delegate?.logError(
        'Error handling broadcast message from peer $peerID: $e',
        stackTrace,
      );
      return false;
    }
  }

  /// Handles a private message addressed to this peer.
  Future<bool> _handlePrivateMessage(RoutedPacket routed) async {
    final packet = routed.packet;
    final peerID = routed.peerID ?? 'unknown';

    try {
      // Verify signature if present
      if (packet.signature != null) {
        final verified = await delegate?.verifySignature(packet, peerID) ?? false;
        if (!verified) {
          delegate?.logWarning(
            'Invalid signature for private message from peer $peerID',
          );
          return false;
        }
      }

      // Get peer info
      final peerInfo = await delegate?.getPeerInfo(peerID);
      final nickname = peerInfo?.nickname ?? 'Unknown';
      
      final payload = packet.payload ?? Uint8List(0);

      // Try file packet first
      final messageType = MessageType.fromValue(packet.type);
      if (messageType == MessageType.fileTransfer) {
        final file = BitchatFilePacket.decode(payload);
        if (file != null) {
          return await _handleFilePacket(
            file,
            peerID,
            packet,
            isPrivate: true,
            nickname: nickname,
          );
        }
      }

      // Fallback: plain text message
      final message = BitchatMessage(
        sender: nickname,
        content: String.fromCharCodes(payload),
        type: BitchatMessageType.Message,
        timestamp: packet.timestamp,
        senderPeerID: peerID,
        isPrivate: true,
        recipientNickname: await delegate?.getMyNickname(),
      );

      delegate?.onMessageReceived(message);
      return true;
    } catch (e, stackTrace) {
      delegate?.logError(
        'Error handling private message from peer $peerID: $e',
        stackTrace,
      );
      return false;
    }
  }

  /// Handles a file transfer packet.
  Future<bool> _handleFilePacket(
    BitchatFilePacket file,
    String peerID,
    BitchatPacket packet, {
    bool isPrivate = false,
    String? nickname,
  }) async {
    try {
      // Save the incoming file
      final savedPath = await delegate?.saveIncomingFile(file) ?? '';

      // Get peer info if not provided
      final peerInfo = nickname ??
          (await delegate?.getPeerInfo(peerID))?.nickname ??
          'Unknown';

      // Determine message type based on file MIME type
      final messageType = _getMessageTypeForMime(file.mimeType);

      final message = BitchatMessage(
        sender: peerInfo,
        content: savedPath,
        type: messageType,
        timestamp: packet.timestamp,
        senderPeerID: peerID,
        isPrivate: isPrivate,
        recipientNickname: isPrivate ? await delegate?.getMyNickname() : null,
      );

      delegate?.onMessageReceived(message);
      return true;
    } catch (e, stackTrace) {
      delegate?.logError(
        'Error handling file packet from peer $peerID: $e',
        stackTrace,
      );
      return false;
    }
  }

  /// Handles a LEAVE packet.
  Future<bool> _handleLeave(RoutedPacket routed) async {
    final packet = routed.packet;
    final peerID = routed.peerID ?? 'unknown';

    try {
      final payload = packet.payload ?? Uint8List(0);
      final content = String.fromCharCodes(payload);

      if (content.startsWith('#')) {
        // Channel leave
        delegate?.onChannelLeave(content, peerID);
      } else {
        // Peer disconnect
        delegate?.removePeer(peerID);
      }

      delegate?.logInfo('Processed leave from peer $peerID');
      return true;
    } catch (e, stackTrace) {
      delegate?.logError(
        'Error handling leave from peer $peerID: $e',
        stackTrace,
      );
      return false;
    }
  }

  /// Handles a FRAGMENT packet.
  /// Delegates to fragment handler for reassembly.
  Future<bool> _handleFragment(RoutedPacket routed) async {
    final packet = routed.packet;
    final peerID = routed.peerID ?? 'unknown';

    try {
      final reassembled = await delegate?.handleFragment(packet);
      if (reassembled != null) {
        delegate?.logInfo('Fragment reassembled from peer $peerID');
        // Create a new routed packet with reassembled data
        final reassembledRouted = routed.copyWith(
          packet: reassembled,
        );
        return await processPacket(reassembledRouted);
      }

      return false;
    } catch (e, stackTrace) {
      delegate?.logError(
        'Error handling fragment from peer $peerID: $e',
        stackTrace,
      );
      return false;
    }
  }

  /// Handles a NOISE_HANDSHAKE packet.
  Future<bool> _handleNoiseHandshake(RoutedPacket routed) async {
    final packet = routed.packet;
    final peerID = routed.peerID ?? 'unknown';

    try {
      final payload = packet.payload ?? Uint8List(0);
      final response = await delegate?.processNoiseHandshakeMessage(
            payload,
            peerID,
          );

      if (response != null) {
        delegate?.logInfo(
          'Generated handshake response for peer $peerID',
        );

        // Send response using same packet type
        await delegate?.sendPacketToPeer(
          peerID,
          MessageType.noiseHandshake,
          response,
        );

        // Check if session is now established
        final hasSession = await delegate?.hasNoiseSession(peerID) ?? false;
        if (hasSession) {
          delegate?.logInfo(
            'Noise session established with peer $peerID',
          );
        }

        return true;
      }

      return false;
    } catch (e, stackTrace) {
      delegate?.logError(
        'Error handling noise handshake from peer $peerID: $e',
        stackTrace,
      );
      return false;
    }
  }

  /// Handles a NOISE_ENCRYPTED packet.
  Future<bool> _handleNoiseEncrypted(RoutedPacket routed) async {
    final packet = routed.packet;
    final peerID = routed.peerID ?? 'unknown';

    try {
      final payload = packet.payload ?? Uint8List(0);
      
      // Decrypt the message
      final decryptedData = await delegate?.decryptFromPeer(
            payload,
            peerID,
          );

      if (decryptedData == null || decryptedData.isEmpty) {
        delegate?.logWarning(
          'Failed to decrypt noise message from peer $peerID',
        );
        return false;
      }

      // Parse the noise payload (TLV format)
      final noisePayload = _parseNoisePayload(decryptedData);
      if (noisePayload == null) {
        delegate?.logWarning(
          'Failed to parse noise payload from peer $peerID',
        );
        return false;
      }

      delegate?.logInfo(
        'Decrypted noise payload type ${noisePayload.type} from peer $peerID',
      );

      // Handle based on noise payload type
      return await _handleNoisePayload(noisePayload, peerID, packet);
    } catch (e, stackTrace) {
      delegate?.logError(
        'Error handling noise encrypted from peer $peerID: $e',
        stackTrace,
      );
      return false;
    }
  }

  /// Handles a noise encrypted payload.
  Future<bool> _handleNoisePayload(
    _NoisePayload noisePayload,
    String peerID,
    BitchatPacket originalPacket,
  ) async {
    try {
      switch (noisePayload.type) {
        case 0x01: // PRIVATE_MESSAGE
          return await _handlePrivateMessagePayload(noisePayload.data, peerID);

        case 0x02: // FILE_TRANSFER
          final file = BitchatFilePacket.decode(noisePayload.data);
          if (file != null) {
            return await _handleFilePacket(
              file,
              peerID,
              originalPacket,
              isPrivate: true,
            );
          }
          return false;

        case 0x10: // DELIVERED (delivery ACK)
          final messageID = String.fromCharCodes(noisePayload.data);
          delegate?.onDeliveryAckReceived(messageID, peerID);
          return true;

        case 0x11: // READ_RECEIPT
          final messageID = String.fromCharCodes(noisePayload.data);
          delegate?.onReadReceiptReceived(messageID, peerID);
          return true;

        default:
          delegate?.logWarning(
            'Unknown noise payload type: ${noisePayload.type} from peer $peerID',
          );
          return false;
      }
    } catch (e, stackTrace) {
      delegate?.logError(
        'Error handling noise payload from peer $peerID: $e',
        stackTrace,
      );
      return false;
    }
  }

  /// Handles a private message payload (TLV format).
  Future<bool> _handlePrivateMessagePayload(
    Uint8List data,
    String peerID,
  ) async {
    try {
      final privateMessage = _parsePrivateMessage(data);
      if (privateMessage == null) {
        delegate?.logWarning(
          'Failed to parse private message from peer $peerID',
        );
        return false;
      }

      final peerInfo = await delegate?.getPeerInfo(peerID);
      final nickname = peerInfo?.nickname ?? 'Unknown';

      final message = BitchatMessage(
        id: privateMessage.messageID,
        sender: nickname,
        content: privateMessage.content,
        type: BitchatMessageType.Message,
        timestamp: DateTime.fromMillisecondsSinceEpoch(privateMessage.timestamp),
        isRelay: privateMessage.isRelay,
        originalSender: privateMessage.originalSender,
        isPrivate: true,
        recipientNickname: await delegate?.getMyNickname(),
        senderPeerID: peerID,
      );

      delegate?.onMessageReceived(message);
      return true;
    } catch (e, stackTrace) {
      delegate?.logError(
        'Error handling private message payload from peer $peerID: $e',
        stackTrace,
      );
      return false;
    }
  }

  /// Handles a REQUEST_SYNC packet.
  Future<bool> _handleRequestSync(RoutedPacket routed) async {
    final peerID = routed.peerID ?? 'unknown';

    try {
      delegate?.logInfo(
        'Processing request sync from peer $peerID',
      );

      // Delegate handles the sync response
      await delegate?.handleRequestSync(routed);

      return true;
    } catch (e, stackTrace) {
      delegate?.logError(
        'Error handling request sync from peer $peerID: $e',
        stackTrace,
      );
      return false;
    }
  }

  /// Converts bytes to hex string.
  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Gets packet data for signature verification.
  Uint8List? _getPacketDataForSigning(BitchatPacket packet) {
    try {
      // Create a new packet without signature for signing
      final signPacket = BitchatPacket(
        version: packet.version,
        type: packet.type,
        ttl: packet.ttl,
        timestamp: packet.timestamp,
        senderID: packet.senderID,
        recipientID: packet.recipientID,
        payload: packet.payload,
        signature: null,
      );
      
      final bytes = PacketCodec.encode(
        signPacket,
        senderID: packet.senderID ?? Uint8List(8),
        recipientID: packet.recipientID,
      );
      return bytes;
    } catch (e) {
      delegate?.logError('Error encoding packet for signing: $e');
      return null;
    }
  }

  /// Checks if the recipient ID is the broadcast address.
  bool _isBroadcastRecipient(Uint8List? recipientID) {
    if (recipientID == null) return true;
    if (recipientID.length != SpecialRecipients.broadcastRecipient.length) {
      return false;
    }
    for (int i = 0; i < recipientID.length; i++) {
      if (recipientID[i] != SpecialRecipients.broadcastRecipient[i]) {
        return false;
      }
    }
    return true;
  }

  /// Gets message type from MIME type.
  BitchatMessageType _getMessageTypeForMime(String? mimeType) {
    if (mimeType == null) return BitchatMessageType.Message;

    if (mimeType.startsWith('audio/')) {
      return BitchatMessageType.Audio;
    } else if (mimeType.startsWith('image/')) {
      return BitchatMessageType.Image;
    } else {
      return BitchatMessageType.File;
    }
  }

  /// Compares two byte lists for equality.
  bool _listsEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Parses a noise payload from bytes (simple TLV format).
  _NoisePayload? _parseNoisePayload(Uint8List data) {
    try {
      if (data.isEmpty) return null;

      final type = data[0];
      final payloadData = data.length > 1 ? data.sublist(1) : Uint8List(0);

      return _NoisePayload(type: type, data: payloadData);
    } catch (_) {
      return null;
    }
  }

  /// Parses a private message from bytes (TLV format).
  _PrivateMessage? _parsePrivateMessage(Uint8List data) {
    try {
      int offset = 0;
      String? messageID;
      String? content;
      int timestamp = DateTime.now().millisecondsSinceEpoch;
      bool isRelay = false;
      String? originalSender;

      while (offset + 2 <= data.length) {
        final type = data[offset++];
        final length = data[offset++];

        if (offset + length > data.length) break;

        final value = data.sublist(offset, offset + length);
        offset += length;

        switch (type) {
          case 0x01: // MESSAGE_ID
            messageID = String.fromCharCodes(value);
            break;
          case 0x02: // CONTENT
            content = String.fromCharCodes(value);
            break;
          case 0x03: // TIMESTAMP
            if (value.length == 8) {
              final byteData = ByteData.sublistView(value);
              timestamp = byteData.getInt64(0, Endian.big);
            }
            break;
          case 0x04: // IS_RELAY
            isRelay = value.isNotEmpty && value[0] != 0;
            break;
          case 0x05: // ORIGINAL_SENDER
            originalSender = String.fromCharCodes(value);
            break;
        }
      }

      if (messageID != null && content != null) {
        return _PrivateMessage(
          messageID: messageID,
          content: content,
          timestamp: timestamp,
          isRelay: isRelay,
          originalSender: originalSender,
        );
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Shuts down the message handler and releases resources.
  void shutdown() {
    delegate = null;
  }
}

/// Internal representation of a noise payload.
class _NoisePayload {
  final int type;
  final Uint8List data;

  _NoisePayload({required this.type, required this.data});
}

/// Internal representation of a private message.
class _PrivateMessage {
  final String messageID;
  final String content;
  final int timestamp;
  final bool isRelay;
  final String? originalSender;

  _PrivateMessage({
    required this.messageID,
    required this.content,
    required this.timestamp,
    this.isRelay = false,
    this.originalSender,
  });
}

/// Delegate interface for message handler callbacks.
abstract class MessageHandlerDelegate {
  /// Logging callbacks
  void logInfo(String message);
  void logWarning(String message);
  void logError(String message, [Object? stackTrace]);

  /// Peer management
  Future<void> updatePeerInfo({
    required String peerID,
    required String nickname,
    Uint8List? noisePublicKey,
    Uint8List? signingPublicKey,
    required bool isVerified,
  });

  Future<PeerInfo?> getPeerInfo(String peerID);
  Future<void> removePeer(String peerID);
  Future<String?> getMyNickname();

  /// Cryptographic operations
  Future<bool> verifyEd25519Signature(
    Uint8List signature,
    Uint8List data,
    Uint8List publicKey,
  );

  Future<bool> verifySignature(BitchatPacket packet, String peerID);
  Future<Uint8List?> decryptFromPeer(
    Uint8List encryptedData,
    String senderPeerID,
  );

  /// Noise protocol operations
  Future<bool> hasNoiseSession(String peerID);
  Future<Uint8List?> processNoiseHandshakeMessage(
    Uint8List payload,
    String peerID,
  );

  Future<void> sendPacketToPeer(
    String peerID,
    MessageType type,
    Uint8List payload,
  );

  /// Fragment handling
  Future<BitchatPacket?> handleFragment(BitchatPacket packet);

  /// File operations
  Future<String> saveIncomingFile(BitchatFilePacket file);

  /// Sync operations
  Future<void> handleRequestSync(RoutedPacket routed);

  /// Message callbacks
  void onMessageReceived(BitchatMessage message);
  void onChannelLeave(String channel, String fromPeer);
  void onDeliveryAckReceived(String messageID, String peerID);
  void onReadReceiptReceived(String messageID, String peerID);
}

/// Peer information model.
class PeerInfo {
  final String nickname;
  final Uint8List? noisePublicKey;
  final Uint8List? signingPublicKey;
  final bool isVerifiedNickname;
  final DateTime lastSeen;

  PeerInfo({
    required this.nickname,
    this.noisePublicKey,
    this.signingPublicKey,
    required this.isVerifiedNickname,
    required this.lastSeen,
  });
}
