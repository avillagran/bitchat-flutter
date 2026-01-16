import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitchat/data/models/bitchat_message.dart';
import 'package:bitchat/data/models/bitchat_file_packet.dart';
import 'package:bitchat/data/models/identity_announcement.dart';
import 'package:bitchat/data/models/routed_packet.dart';
import 'package:bitchat/features/mesh/message_handler.dart';
import 'package:bitchat/protocol/message_type.dart';

/// Mock delegate for testing MessageHandler.
class MockMessageHandlerDelegate implements MessageHandlerDelegate {
  final List<String> infoMessages = [];
  final List<String> warningMessages = [];
  final List<String> errorMessages = [];
  final List<BitchatMessage> receivedMessages = [];
  final Map<String, PeerInfo> peerInfoMap = {};
  String myNickname = 'TestUser';

  @override
  void logInfo(String message) {
    infoMessages.add(message);
  }

  @override
  void logWarning(String message) {
    warningMessages.add(message);
  }

  @override
  void logError(String message, [Object? stackTrace]) {
    errorMessages.add(message);
  }

  @override
  Future<void> updatePeerInfo({
    required String peerID,
    required String nickname,
    Uint8List? noisePublicKey,
    Uint8List? signingPublicKey,
    required bool isVerified,
  }) async {
    peerInfoMap[peerID] = PeerInfo(
      nickname: nickname,
      noisePublicKey: noisePublicKey,
      signingPublicKey: signingPublicKey,
      isVerifiedNickname: isVerified,
      lastSeen: DateTime.now(),
    );
  }

  @override
  Future<PeerInfo?> getPeerInfo(String peerID) async {
    return peerInfoMap[peerID];
  }

  @override
  Future<void> removePeer(String peerID) async {
    peerInfoMap.remove(peerID);
  }

  @override
  Future<String?> getMyNickname() async {
    return myNickname;
  }

  @override
  Future<bool> verifyEd25519Signature(
    Uint8List signature,
    Uint8List data,
    Uint8List publicKey,
  ) async {
    // Always return true for tests
    return true;
  }

  @override
  Future<bool> verifySignature(BitchatPacket packet, String peerID) async {
    // Always return true for tests
    return true;
  }

  @override
  Future<Uint8List?> decryptFromPeer(
    Uint8List encryptedData,
    String senderPeerID,
  ) async {
    // Return the same data for tests (no actual decryption)
    return encryptedData;
  }

  @override
  Future<bool> hasNoiseSession(String peerID) async {
    return false;
  }

  @override
  Future<Uint8List?> processNoiseHandshakeMessage(
    Uint8List payload,
    String peerID,
  ) async {
    // Return mock response
    return Uint8List.fromList([0x01, 0x02, 0x03]);
  }

  @override
  Future<void> sendPacketToPeer(
    String peerID,
    MessageType type,
    Uint8List payload,
  ) async {
    // Mock implementation
  }

  @override
  Future<BitchatPacket?> handleFragment(BitchatPacket packet) async {
    // Return null for tests (no fragment reassembly)
    return null;
  }

  @override
  Future<String> saveIncomingFile(BitchatFilePacket file) async {
    return '/mock/path/${file.fileName}';
  }

  @override
  Future<void> handleRequestSync(RoutedPacket routed) async {
    // Mock implementation
  }

  @override
  void onMessageReceived(BitchatMessage message) {
    receivedMessages.add(message);
  }

  @override
  void onChannelLeave(String channel, String fromPeer) {
    // Mock implementation
  }

  @override
  void onDeliveryAckReceived(String messageID, String peerID) {
    // Mock implementation
  }

  @override
  void onReadReceiptReceived(String messageID, String peerID) {
    // Mock implementation
  }

  void clear() {
    infoMessages.clear();
    warningMessages.clear();
    errorMessages.clear();
    receivedMessages.clear();
    peerInfoMap.clear();
  }
}

void main() {
  group('MessageType enum', () {
    test('should have correct values', () {
      expect(MessageType.announce.value, 0x01);
      expect(MessageType.message.value, 0x02);
      expect(MessageType.leave.value, 0x03);
      expect(MessageType.noiseHandshake.value, 0x10);
      expect(MessageType.noiseEncrypted.value, 0x11);
      expect(MessageType.fragment.value, 0x20);
      expect(MessageType.requestSync.value, 0x21);
      expect(MessageType.fileTransfer.value, 0x22);
    });

    test('should convert from value correctly', () {
      expect(MessageType.fromValue(0x01), MessageType.announce);
      expect(MessageType.fromValue(0x02), MessageType.message);
      expect(MessageType.fromValue(0x03), MessageType.leave);
      expect(MessageType.fromValue(0x10), MessageType.noiseHandshake);
      expect(MessageType.fromValue(0x11), MessageType.noiseEncrypted);
      expect(MessageType.fromValue(0x20), MessageType.fragment);
      expect(MessageType.fromValue(0x21), MessageType.requestSync);
      expect(MessageType.fromValue(0x22), MessageType.fileTransfer);
      expect(MessageType.fromValue(0xFF), isNull);
    });

    test('should have correct names', () {
      expect(MessageType.announce.name, 'ANNOUNCE');
      expect(MessageType.message.name, 'MESSAGE');
      expect(MessageType.leave.name, 'LEAVE');
      expect(MessageType.noiseHandshake.name, 'NOISE_HANDSHAKE');
      expect(MessageType.noiseEncrypted.name, 'NOISE_ENCRYPTED');
      expect(MessageType.fragment.name, 'FRAGMENT');
      expect(MessageType.requestSync.name, 'REQUEST_SYNC');
      expect(MessageType.fileTransfer.name, 'FILE_TRANSFER');
    });
  });

  group('MessageHandler', () {
    late MessageHandler messageHandler;
    late MockMessageHandlerDelegate mockDelegate;
    const myPeerID = '0102030405060708';

    setUp(() {
      mockDelegate = MockMessageHandlerDelegate();
      messageHandler = MessageHandler(myPeerID);
      messageHandler.delegate = mockDelegate;
    });

    test('should skip packets from own peer ID', () async {
      final packet = _createTestPacket(
        type: MessageType.message.value,
        senderID: _hexToBytes(myPeerID),
      );
      final routed = RoutedPacket(packet: packet, peerID: myPeerID);

      final result = await messageHandler.processPacket(routed);
      expect(result, false);
      expect(mockDelegate.receivedMessages.isEmpty, true);
    });

    test('should handle unknown packet types', () async {
      const unknownPeerID = '1122334455667788';
      final packet = _createTestPacket(
        type: 0xFF, // Unknown type
        senderID: _hexToBytes(unknownPeerID),
      );
      final routed = RoutedPacket(packet: packet, peerID: unknownPeerID);

      final result = await messageHandler.processPacket(routed);
      expect(result, false);
      expect(mockDelegate.warningMessages.length, greaterThan(0));
    });

    test('should handle announce packet successfully', () async {
      const peerID = '1122334455667788';
      final announcement = IdentityAnnouncement(
        nickname: 'TestPeer',
        noisePublicKey: Uint8List.fromList([0x01, 0x02, 0x03]),
        signingPublicKey: Uint8List.fromList([0x04, 0x05, 0x06]),
      );
      final payload = announcement.encode()!;

      final packet = _createTestPacket(
        type: MessageType.announce.value,
        senderID: _hexToBytes(peerID),
        payload: payload,
        signature: Uint8List(64), // Mock signature
      );
      final routed = RoutedPacket(packet: packet, peerID: peerID);

      final result = await messageHandler.processPacket(routed);
      expect(result, true);

      final peerInfo = await mockDelegate.getPeerInfo(peerID);
      expect(peerInfo, isNotNull);
      expect(peerInfo?.nickname, 'TestPeer');
      expect(peerInfo?.isVerifiedNickname, true);
    });

    test('should handle announce with key mismatch', () async {
      const peerID = '1122334455667788';
      
      // First add peer with different keys
      mockDelegate.peerInfoMap[peerID] = PeerInfo(
        nickname: 'TestPeerOld',
        noisePublicKey: Uint8List.fromList([0x99, 0x99, 0x99]),
        signingPublicKey: Uint8List.fromList([0x99, 0x99, 0x99]),
        isVerifiedNickname: true,
        lastSeen: DateTime.now(),
      );
      
      final announcement = IdentityAnnouncement(
        nickname: 'TestPeer',
        noisePublicKey: Uint8List.fromList([0x01, 0x02, 0x03]),
        signingPublicKey: Uint8List.fromList([0x04, 0x05, 0x06]),
      );
      final payload = announcement.encode()!;

      final packet = _createTestPacket(
        type: MessageType.announce.value,
        senderID: _hexToBytes(peerID),
        payload: payload,
        signature: Uint8List(64),
      );
      final routed = RoutedPacket(packet: packet, peerID: peerID);

      final result = await messageHandler.processPacket(routed);
      expect(result, false); // Should return false due to key mismatch
      expect(mockDelegate.warningMessages.length, greaterThan(0));
    });

    test('should handle broadcast message from verified peer', () async {
      const peerID = '1122334455667788';
      const content = 'Hello mesh!';

      // First, add verified peer
      mockDelegate.peerInfoMap[peerID] = PeerInfo(
        nickname: 'TestPeer',
        isVerifiedNickname: true,
        lastSeen: DateTime.now(),
      );

      final packet = _createTestPacket(
        type: MessageType.message.value,
        senderID: _hexToBytes(peerID),
        payload: _encodeString(content),
        recipientID: Uint8List.fromList(SpecialRecipients.broadcastRecipient),
      );
      final routed = RoutedPacket(packet: packet, peerID: peerID);

      final result = await messageHandler.processPacket(routed);
      expect(result, true);
      expect(mockDelegate.receivedMessages.length, 1);
      expect(mockDelegate.receivedMessages.first.content, content);
      expect(mockDelegate.receivedMessages.first.sender, 'TestPeer');
      expect(mockDelegate.receivedMessages.first.isPrivate, false);
    });

    test('should drop broadcast message from unverified peer', () async {
      const peerID = '1122334455667788';
      const content = 'Hello mesh!';

      // Add unverified peer
      mockDelegate.peerInfoMap[peerID] = PeerInfo(
        nickname: 'TestPeer',
        isVerifiedNickname: false,
        lastSeen: DateTime.now(),
      );

      final packet = _createTestPacket(
        type: MessageType.message.value,
        senderID: _hexToBytes(peerID),
        payload: _encodeString(content),
        recipientID: Uint8List.fromList(SpecialRecipients.broadcastRecipient),
      );
      final routed = RoutedPacket(packet: packet, peerID: peerID);

      final result = await messageHandler.processPacket(routed);
      expect(result, false);
      expect(mockDelegate.receivedMessages.isEmpty, true);
      expect(mockDelegate.warningMessages.length, greaterThan(0));
    });

    test('should handle private message addressed to us', () async {
      const peerID = '1122334455667788';
      const content = 'Private hello!';

      // Add peer info
      mockDelegate.peerInfoMap[peerID] = PeerInfo(
        nickname: 'TestPeer',
        isVerifiedNickname: true,
        lastSeen: DateTime.now(),
      );

      final packet = _createTestPacket(
        type: MessageType.message.value,
        senderID: _hexToBytes(peerID),
        payload: _encodeString(content),
        recipientID: _hexToBytes(myPeerID),
      );
      final routed = RoutedPacket(packet: packet, peerID: peerID);

      final result = await messageHandler.processPacket(routed);
      expect(result, true);
      expect(mockDelegate.receivedMessages.length, 1);
      expect(mockDelegate.receivedMessages.first.content, content);
      expect(mockDelegate.receivedMessages.first.isPrivate, true);
      expect(mockDelegate.receivedMessages.first.recipientNickname, 'TestUser');
    });

    test('should ignore private message not addressed to us', () async {
      const peerID = '1122334455667788';
      const otherPeerID = '1122334455667799';
      const content = 'Not for me!';

      final packet = _createTestPacket(
        type: MessageType.message.value,
        senderID: _hexToBytes(peerID),
        payload: _encodeString(content),
        recipientID: _hexToBytes(otherPeerID),
      );
      final routed = RoutedPacket(packet: packet, peerID: peerID);

      final result = await messageHandler.processPacket(routed);
      expect(result, false);
      expect(mockDelegate.receivedMessages.isEmpty, true);
    });

    test('should handle leave message', () async {
      const peerID = '1122334455667788';

      // Add peer first
      mockDelegate.peerInfoMap[peerID] = PeerInfo(
        nickname: 'TestPeer',
        isVerifiedNickname: true,
        lastSeen: DateTime.now(),
      );

      final packet = _createTestPacket(
        type: MessageType.leave.value,
        senderID: _hexToBytes(peerID),
        payload: _encodeString('leaving'),
      );
      final routed = RoutedPacket(packet: packet, peerID: peerID);

      final result = await messageHandler.processPacket(routed);
      expect(result, true);
      expect(mockDelegate.peerInfoMap.containsKey(peerID), false);
    });

    test('should handle noise handshake addressed to us', () async {
      const peerID = '1122334455667788';
      final payload = Uint8List.fromList([0x01, 0x02, 0x03]);

      final packet = _createTestPacket(
        type: MessageType.noiseHandshake.value,
        senderID: _hexToBytes(peerID),
        payload: payload,
        recipientID: _hexToBytes(myPeerID),
      );
      final routed = RoutedPacket(packet: packet, peerID: peerID);

      final result = await messageHandler.processPacket(routed);
      expect(result, true);
      expect(mockDelegate.infoMessages.length, greaterThan(0));
    });

    test('should ignore noise handshake not addressed to us', () async {
      const peerID = '1122334455667788';
      const otherPeerID = '1122334455667799';
      final payload = Uint8List.fromList([0x01, 0x02, 0x03]);

      final packet = _createTestPacket(
        type: MessageType.noiseHandshake.value,
        senderID: _hexToBytes(peerID),
        payload: payload,
        recipientID: _hexToBytes(otherPeerID),
      );
      final routed = RoutedPacket(packet: packet, peerID: peerID);

      final result = await messageHandler.processPacket(routed);
      expect(result, false);
    });

    test('should handle noise encrypted message', () async {
      const peerID = '1122334455667788';

      // Create noise payload with type 0x01 (PRIVATE_MESSAGE)
      // TLV format for content: type (1) + length (1) + data
      final content = 'Encrypted hi';
      final payload = Uint8List.fromList([
        0x01, // Payload type (PRIVATE_MESSAGE)
        // TLV message ID
        0x01,
        5,
        ...'msg01'.codeUnits,
        // TLV content (length should match content exactly)
        0x02,
        content.length,
        ...content.codeUnits,
      ]);

      final packet = _createTestPacket(
        type: MessageType.noiseEncrypted.value,
        senderID: _hexToBytes(peerID),
        payload: payload,
        recipientID: _hexToBytes(myPeerID),
      );
      final routed = RoutedPacket(packet: packet, peerID: peerID);

      final result = await messageHandler.processPacket(routed);
      expect(result, true);
      expect(mockDelegate.receivedMessages.length, 1);
      expect(mockDelegate.receivedMessages.first.id, 'msg01');
      expect(mockDelegate.receivedMessages.first.content, content);
      expect(mockDelegate.receivedMessages.first.isPrivate, true);
    });

    test('should handle file transfer packet', () async {
      const peerID = '1122334455667788';

      // First, add verified peer
      mockDelegate.peerInfoMap[peerID] = PeerInfo(
        nickname: 'TestPeer',
        isVerifiedNickname: true,
        lastSeen: DateTime.now(),
      );

      // Create file packet
      final filePacket = BitchatFilePacket(
        fileName: 'test.txt',
        fileSize: 12,
        mimeType: 'text/plain',
        content: Uint8List.fromList('Hello World!'.codeUnits),
      );
      final payload = filePacket.encode();

      final packet = _createTestPacket(
        type: MessageType.fileTransfer.value,
        senderID: _hexToBytes(peerID),
        payload: payload ?? Uint8List(0),
        recipientID: Uint8List.fromList(SpecialRecipients.broadcastRecipient),
      );
      final routed = RoutedPacket(packet: packet, peerID: peerID);

      final result = await messageHandler.processPacket(routed);
      expect(result, true);
      expect(mockDelegate.receivedMessages.length, 1);
      expect(mockDelegate.receivedMessages.first.type, BitchatMessageType.File);
      expect(mockDelegate.receivedMessages.first.content, '/mock/path/test.txt');
    });

    test('should handle request sync packet', () async {
      const peerID = '1122334455667788';

      final packet = _createTestPacket(
        type: MessageType.requestSync.value,
        senderID: _hexToBytes(peerID),
        payload: Uint8List.fromList('sync_request'.codeUnits),
      );
      final routed = RoutedPacket(packet: packet, peerID: peerID);

      final result = await messageHandler.processPacket(routed);
      expect(result, true);
      expect(mockDelegate.infoMessages.length, greaterThan(0));
    });

    test('should handle fragment packet', () async {
      const peerID = '1122334455667788';

      final packet = _createTestPacket(
        type: MessageType.fragment.value,
        senderID: _hexToBytes(peerID),
        payload: Uint8List.fromList('fragment_data'.codeUnits),
      );
      final routed = RoutedPacket(packet: packet, peerID: peerID);

      final result = await messageHandler.processPacket(routed);
      expect(result, false); // No fragment reassembly in mock
    });

    test('should handle delivery ACK', () async {
      const peerID = '1122334455667788';

      // Create noise payload with type 0x10 (DELIVERED)
      final payload = Uint8List.fromList([
        0x10, // Payload type
        ...'msg123'.codeUnits, // Message ID
      ]);

      final packet = _createTestPacket(
        type: MessageType.noiseEncrypted.value,
        senderID: _hexToBytes(peerID),
        payload: payload,
        recipientID: _hexToBytes(myPeerID),
      );
      final routed = RoutedPacket(packet: packet, peerID: peerID);

      final result = await messageHandler.processPacket(routed);
      expect(result, true);
    });

    test('should handle read receipt', () async {
      const peerID = '1122334455667788';

      // Create noise payload with type 0x11 (READ_RECEIPT)
      final payload = Uint8List.fromList([
        0x11, // Payload type
        ...'msg456'.codeUnits, // Message ID
      ]);

      final packet = _createTestPacket(
        type: MessageType.noiseEncrypted.value,
        senderID: _hexToBytes(peerID),
        payload: payload,
        recipientID: _hexToBytes(myPeerID),
      );
      final routed = RoutedPacket(packet: packet, peerID: peerID);

      final result = await messageHandler.processPacket(routed);
      expect(result, true);
    });

    test('should shutdown correctly', () {
      expect(messageHandler.delegate, isNotNull);
      messageHandler.shutdown();
      expect(messageHandler.delegate, isNull);
    });
  });
}

/// Helper function to create a test packet.
BitchatPacket _createTestPacket({
  required int type,
  required Uint8List senderID,
  Uint8List? recipientID,
  Uint8List? payload,
  Uint8List? signature,
  int ttl = 7,
}) {
  return BitchatPacket(
    version: 1,
    type: type,
    ttl: ttl,
    timestamp: DateTime.now(),
    senderID: senderID,
    recipientID: recipientID,
    payload: payload ?? Uint8List(0),
    signature: signature,
  );
}

/// Helper function to encode a string as bytes.
Uint8List _encodeString(String str) {
  return Uint8List.fromList(str.codeUnits);
}

/// Helper function to convert hex string to bytes.
Uint8List _hexToBytes(String hex) {
  final result = Uint8List(8);
  for (int i = 0; i < 16 && i < hex.length; i += 2) {
    final byte = int.tryParse(hex.substring(i, i + 2), radix: 16);
    if (byte != null) {
      result[i ~/ 2] = byte;
    }
  }
  return result;
}
