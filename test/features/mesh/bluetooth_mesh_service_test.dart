import 'package:flutter_test/flutter_test.dart';
import 'package:bitchat/features/mesh/bluetooth_mesh_service.dart';
import 'package:bitchat/features/crypto/encryption_service.dart';
import 'package:bitchat/features/mesh/peer_manager.dart';
import 'package:bitchat/features/mesh/store_forward_manager.dart';
import 'package:bitchat/data/models/bitchat_message.dart';
import 'package:bitchat/data/models/routed_packet.dart';
import 'package:bitchat/data/models/identity_announcement.dart';
import 'dart:typed_data';

void main() {
  group('BluetoothMeshService', () {
    late BluetoothMeshService meshService;

    setUp(() {
      final encryptionService = EncryptionService();
      meshService = BluetoothMeshService(encryptionService);
    });

    test('should initialize with valid peer ID', () {
      expect(meshService.myPeerID, isNotEmpty);
      expect(meshService.myPeerID.length, equals(16));
    });

    test('should not be active before start', () {
      expect(meshService.isActive, false);
    });

    test('should have peer manager and store-forward manager', () {
      expect(meshService.peerManager, isNotNull);
      expect(meshService.storeForwardManager, isNotNull);
      expect(meshService.powerManager, isNotNull);
    });

    test('getActivePeers should return empty list initially', () {
      final activePeers = meshService.getActivePeers();
      expect(activePeers, isEmpty);
    });

    test('getPeerCount should return zero initially', () {
      final count = meshService.getPeerCount();
      expect(count, equals(0));
    });

    test('should add peer via peerManager', () {
      final peer = PeerInfo(
        id: 'test-peer',
        name: 'Test Peer',
        noisePublicKey: Uint8List(32),
        signingPublicKey: Uint8List(32),
        isConnected: true,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
        transport: TransportType.bluetooth,
        isVerifiedName: false,
      );

      meshService.peerManager.addPeer(peer);
      
      expect(meshService.getPeerCount(), equals(1));
      expect(meshService.peerManager.getPeer('test-peer'), isNotNull);
    });

    test('should return active peers correctly', () {
      final activePeer = PeerInfo(
        id: 'active-peer',
        name: 'Active Peer',
        noisePublicKey: Uint8List(32),
        signingPublicKey: Uint8List(32),
        isConnected: true,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
        transport: TransportType.bluetooth,
        isVerifiedName: false,
      );

      final inactivePeer = PeerInfo(
        id: 'inactive-peer',
        name: 'Inactive Peer',
        noisePublicKey: Uint8List(32),
        signingPublicKey: Uint8List(32),
        isConnected: false,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
        transport: TransportType.bluetooth,
        isVerifiedName: false,
      );

      meshService.peerManager.addPeer(activePeer);
      meshService.peerManager.addPeer(inactivePeer);

      final activePeers = meshService.getActivePeers();
      expect(activePeers.length, equals(1));
      expect(activePeers.first.id, equals('active-peer'));
    });

    test('should have store-forward manager initialized', () {
      expect(meshService.storeForwardManager, isNotNull);
      expect(meshService.storeForwardManager.getPendingMessages(), isEmpty);
    });

    test('should enqueue message in store-forward', () {
      final message = StoreForwardMessage(
        id: 'test-message-1',
        payload: Uint8List.fromList([1, 2, 3, 4]),
        destination: 'mesh-broadcast',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        type: StoreForwardMessageType.outbound,
      );

      meshService.storeForwardManager.enqueueMessage(message);
      
      final pending = meshService.storeForwardManager.getPendingMessages();
      expect(pending.length, equals(1));
      expect(pending.first.id, equals('test-message-1'));
    });

    test('should clear store-forward messages', () {
      final message = StoreForwardMessage(
        id: 'test-message-clear',
        payload: Uint8List.fromList([1, 2, 3]),
        destination: 'mesh-broadcast',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        type: StoreForwardMessageType.outbound,
      );

      meshService.storeForwardManager.enqueueMessage(message);
      expect(meshService.storeForwardManager.getPendingMessages().length, equals(1));
      
      meshService.storeForwardManager.clearAll();
      expect(meshService.storeForwardManager.getPendingMessages().length, equals(0));
    });
  });

  group('BluetoothMeshService Public Methods', () {
    late BluetoothMeshService meshService;

    setUp(() {
      final encryptionService = EncryptionService();
      meshService = BluetoothMeshService(encryptionService);
    });

    test('isActive should reflect service state', () {
      expect(meshService.isActive, false);
      // Note: Actual start/stop testing would require mocking BLE managers
    });

    test('getActivePeers filters by connection status', () {
      final activePeer = PeerInfo(
        id: 'active',
        name: 'Active',
        isConnected: true,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
        transport: TransportType.bluetooth,
      );

      final inactivePeer = PeerInfo(
        id: 'inactive',
        name: 'Inactive',
        isConnected: false,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
        transport: TransportType.bluetooth,
      );

      meshService.peerManager.addPeer(activePeer);
      meshService.peerManager.addPeer(inactivePeer);

      final activePeers = meshService.getActivePeers();
      expect(activePeers.length, equals(1));
      expect(activePeers.first.id, equals('active'));
    });

    test('getPeerCount returns total peer count', () {
      expect(meshService.getPeerCount(), equals(0));

      meshService.peerManager.addPeer(PeerInfo(
        id: 'peer1',
        name: 'Peer 1',
        isConnected: true,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
        transport: TransportType.bluetooth,
      ));

      expect(meshService.getPeerCount(), equals(1));

      meshService.peerManager.addPeer(PeerInfo(
        id: 'peer2',
        name: 'Peer 2',
        isConnected: false,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
        transport: TransportType.bluetooth,
      ));

      expect(meshService.getPeerCount(), equals(2));
    });

    test('broadcastPacket should return zero when not active', () async {
      final packet = BitchatPacket(
        version: 1,
        type: 0x02,
        ttl: 7,
        timestamp: DateTime.now(),
        payload: Uint8List(0),
      );

      final sentCount = await meshService.broadcastPacket(packet);
      expect(sentCount, equals(0));
    });

    test('sendPacketToPeer should return false when not active', () async {
      final packet = BitchatPacket(
        version: 1,
        type: 0x02,
        ttl: 7,
        timestamp: DateTime.now(),
        payload: Uint8List(0),
      );

      final sent = await meshService.sendPacketToPeer('test-peer', packet);
      expect(sent, false);
    });
  });

  group('BluetoothMeshService Message Integration', () {
    late BluetoothMeshService meshService;

    setUp(() {
      final encryptionService = EncryptionService();
      meshService = BluetoothMeshService(encryptionService);
    });

    test('should create and encode identity announcement', () {
      final announce = IdentityAnnouncement(
        nickname: 'Test User',
        noisePublicKey: Uint8List(32),
        signingPublicKey: Uint8List(32),
      );

      final payload = announce.encode();
      expect(payload, isNotNull);
      expect(payload!.length, greaterThan(0));
    });

    test('should decode identity announcement', () {
      final announce = IdentityAnnouncement(
        nickname: 'Decoded User',
        noisePublicKey: Uint8List.fromList(List.generate(32, (i) => i)),
        signingPublicKey: Uint8List.fromList(List.generate(32, (i) => i + 32)),
      );

      final payload = announce.encode();
      expect(payload, isNotNull);

      final decoded = IdentityAnnouncement.decode(payload!);
      expect(decoded, isNotNull);
      expect(decoded!.nickname, equals('Decoded User'));
    });

    test('should encode and decode bitchat message', () {
      final msg = BitchatMessage(
        sender: 'sender-id',
        content: 'Hello, world!',
        timestamp: DateTime.now(),
      );

      final payload = BitchatMessage.toBinaryPayload(msg);
      expect(payload, isNotNull);

      final decoded = BitchatMessage.fromBinaryPayload(payload!);
      expect(decoded, isNotNull);
      expect(decoded!.content, equals('Hello, world!'));
      expect(decoded.sender, equals('sender-id'));
    });

    test('should handle message with mentions', () {
      final msg = BitchatMessage(
        sender: 'sender-id',
        content: 'Hello @user1 and @user2',
        timestamp: DateTime.now(),
        mentions: ['user1', 'user2'],
      );

      final payload = BitchatMessage.toBinaryPayload(msg);
      expect(payload, isNotNull);

      final decoded = BitchatMessage.fromBinaryPayload(payload!);
      expect(decoded, isNotNull);
      expect(decoded!.mentions, isNotNull);
      expect(decoded.mentions!.length, equals(2));
    });

    test('should handle message with channel', () {
      final msg = BitchatMessage(
        sender: 'sender-id',
        content: 'Channel message',
        timestamp: DateTime.now(),
        channel: 'test-channel',
      );

      final payload = BitchatMessage.toBinaryPayload(msg);
      expect(payload, isNotNull);

      final decoded = BitchatMessage.fromBinaryPayload(payload!);
      expect(decoded, isNotNull);
      expect(decoded!.channel, equals('test-channel'));
    });
  });
}
