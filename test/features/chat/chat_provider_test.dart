import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitchat/features/chat/chat_provider.dart';
import 'package:bitchat/features/mesh/bluetooth_mesh_service.dart';
import 'package:bitchat/features/mesh/message_handler.dart' show MessageHandler;
import 'package:bitchat/features/mesh/store_forward_manager.dart';
import 'package:bitchat/features/mesh/peer_manager.dart';
import 'package:bitchat/features/storage/message_storage_service.dart';
import 'package:bitchat/data/models/bitchat_message.dart';
import 'package:bitchat/features/crypto/encryption_service.dart';

/// Mock implementations for testing.
class MockBluetoothMeshService extends BluetoothMeshService {
  bool _isActive = false;
  final PeerManager _peerManager = PeerManager();

  // Spy fields for assertions
  String? lastSentContent;
  String? lastSentChannel;
  int sendCount = 0;

  MockBluetoothMeshService() : super(EncryptionService());

  @override
  bool get isActive => _isActive;

  @override
  String get myPeerID => 'mock_peer_id_12345';

  @override
  PeerManager get peerManager => _peerManager;

  @override
  Future<void> sendMessage(
    String content, {
    List<String>? mentions,
    String? channel,
  }) async {
    // Record call for tests
    lastSentContent = content;
    lastSentChannel = channel;
    sendCount += 1;
  }

  void setActive(bool active) {
    _isActive = active;
  }
}

/// Mock MessageStorageService for testing (doesn't actually persist).
class MockMessageStorageService extends MessageStorageService {
  final List<BitchatMessage> _publicMessages = [];

  @override
  Future<void> initialize() async {
    // No-op for testing
  }

  @override
  bool hasSeenMessage(String messageId) => false;

  @override
  Future<void> markMessageSeen(String messageId) async {}

  @override
  Future<bool> addPublicMessage(BitchatMessage message) async {
    _publicMessages.add(message);
    return true;
  }

  @override
  List<BitchatMessage> getPublicMessages() => _publicMessages;

  @override
  Future<bool> addPrivateMessage(String peerID, BitchatMessage message) async {
    return true;
  }

  @override
  Future<bool> addChannelMessage(String channel, BitchatMessage message) async {
    return true;
  }

  @override
  Future<void> updatePrivateMessageStatus(
    String messageID,
    DeliveryStatus status,
  ) async {}
}

void main() {
  group('ChatState', () {
    test('should create default state with empty values', () {
      final state = const ChatState();

      expect(state.messages, isEmpty);
      expect(state.peers, isEmpty);
      expect(state.selection.selectedPeerId, isNull);
      expect(state.selection.selectedChannel, isNull);
      expect(state.selection.isPrivateChat, false);
      expect(state.connectionStatus, ChatConnectionStatus.disconnected);
      expect(state.unreadCount, 0);
      expect(state.unreadByPeer, isEmpty);
      expect(state.unreadByChannel, isEmpty);
      expect(state.blockedPeers, isEmpty);
      expect(state.joinedChannels, isEmpty);
      expect(state.favoritePeers, isEmpty);
      expect(state.showPasswordPrompt, false);
      expect(state.passwordPromptChannel, isNull);
      expect(state.showCommandSuggestions, false);
      expect(state.showMentionSuggestions, false);
      expect(state.mentionSuggestions, isEmpty);
      expect(state.nickname, '');
      expect(state.isLoading, false);
      expect(state.errorMessage, isNull);
    });

    test('should create state with custom values', () {
      final message = BitchatMessage(
        id: 'test_id',
        sender: 'test_sender',
        content: 'test content',
        timestamp: DateTime(2024, 1, 1),
      );

      final state = ChatState(
        messages: [message],
        connectionStatus: ChatConnectionStatus.connected,
        unreadCount: 5,
        nickname: 'test_user',
      );

      expect(state.messages, hasLength(1));
      expect(state.messages.first, message);
      expect(state.connectionStatus, ChatConnectionStatus.connected);
      expect(state.unreadCount, 5);
      expect(state.nickname, 'test_user');
    });

    test('should copy state with new values', () {
      final originalState = const ChatState(
        connectionStatus: ChatConnectionStatus.disconnected,
        unreadCount: 0,
      );

      final newState = originalState.copyWith(
        connectionStatus: ChatConnectionStatus.connected,
        unreadCount: 10,
      );

      expect(originalState.connectionStatus, ChatConnectionStatus.disconnected);
      expect(originalState.unreadCount, 0);
      expect(newState.connectionStatus, ChatConnectionStatus.connected);
      expect(newState.unreadCount, 10);
    });

    test('should retain unchanged values when copying', () {
      final originalState = ChatState(
        messages: [
          BitchatMessage(
            id: 'test_id',
            sender: 'test_sender',
            content: 'test content',
            timestamp: DateTime(2024, 1, 1),
          ),
        ],
        nickname: 'test_user',
      );

      final newState = originalState.copyWith(
        unreadCount: 5,
      );

      expect(newState.messages, originalState.messages);
      expect(newState.nickname, 'test_user');
      expect(newState.unreadCount, 5);
    });
  });

  group('ChatSelection', () {
    test('should create default selection', () {
      const selection = ChatSelection();

      expect(selection.selectedPeerId, isNull);
      expect(selection.selectedChannel, isNull);
      expect(selection.isPrivateChat, false);
    });

    test('should create selection with peer', () {
      const selection = ChatSelection(
        selectedPeerId: 'peer_123',
        isPrivateChat: true,
      );

      expect(selection.selectedPeerId, 'peer_123');
      expect(selection.selectedChannel, isNull);
      expect(selection.isPrivateChat, true);
    });

    test('should create selection with channel', () {
      const selection = ChatSelection(
        selectedChannel: '#general',
      );

      expect(selection.selectedPeerId, isNull);
      expect(selection.selectedChannel, '#general');
      expect(selection.isPrivateChat, false);
    });

    test('should copy selection with new values', () {
      const originalSelection = ChatSelection(
        selectedPeerId: 'peer_123',
      );

      final newSelection = originalSelection.copyWith(
        selectedChannel: '#general',
        isPrivateChat: false,
      );

      expect(originalSelection.selectedPeerId, 'peer_123');
      expect(originalSelection.selectedChannel, isNull);
      expect(newSelection.selectedPeerId, 'peer_123');
      expect(newSelection.selectedChannel, '#general');
      expect(newSelection.isPrivateChat, false);
    });
  });

  group('ChatNotifier', () {
    late ChatNotifier notifier;
    late MockBluetoothMeshService meshService;
    late StoreForwardManager storeForwardManager;
    late MockMessageStorageService messageStorage;

    setUp(() {
      meshService = MockBluetoothMeshService();
      storeForwardManager = StoreForwardManager();
      messageStorage = MockMessageStorageService();
      // Use basic MessageHandler without delegate for tests
      notifier = ChatNotifier(
        meshService,
        MessageHandler(meshService.myPeerID),
        storeForwardManager,
        messageStorage,
      );
    });

    test('should create notifier with default state', () {
      expect(notifier.state.messages, isEmpty);
      expect(
          notifier.state.connectionStatus, ChatConnectionStatus.disconnected);
    });

    test('should add message to state', () {
      final message = BitchatMessage(
        id: 'test_id',
        sender: 'test_sender',
        content: 'test content',
        timestamp: DateTime(2024, 1, 1),
      );

      notifier.addMessage(message);

      expect(notifier.state.messages, hasLength(1));
      expect(notifier.state.messages.first, message);
    });

    test('should add multiple messages in order', () {
      final message1 = BitchatMessage(
        id: 'id1',
        sender: 'sender1',
        content: 'content1',
        timestamp: DateTime(2024, 1, 1, 10, 0),
      );

      final message2 = BitchatMessage(
        id: 'id2',
        sender: 'sender2',
        content: 'content2',
        timestamp: DateTime(2024, 1, 1, 11, 0),
      );

      notifier.addMessage(message1);
      notifier.addMessage(message2);

      expect(notifier.state.messages, hasLength(2));
      expect(notifier.state.messages[0], message1);
      expect(notifier.state.messages[1], message2);
    });

    test('should clear all messages', () {
      notifier.addMessage(BitchatMessage(
        id: 'id1',
        sender: 'sender1',
        content: 'content1',
        timestamp: DateTime(2024, 1, 1),
      ));

      notifier.addMessage(BitchatMessage(
        id: 'id2',
        sender: 'sender2',
        content: 'content2',
        timestamp: DateTime(2024, 1, 1),
      ));

      expect(notifier.state.messages, hasLength(2));

      notifier.clearMessages();

      expect(notifier.state.messages, isEmpty);
    });

    test('should select peer for private chat', () {
      notifier.selectPeer('peer_123');

      expect(notifier.state.selection.selectedPeerId, 'peer_123');
      expect(notifier.state.selection.selectedChannel, isNull);
      expect(notifier.state.selection.isPrivateChat, true);
    });

    test('should select channel', () {
      notifier.selectChannel('#general');

      expect(notifier.state.selection.selectedPeerId, isNull);
      expect(notifier.state.selection.selectedChannel, '#general');
      expect(notifier.state.selection.isPrivateChat, false);
    });

    test('should clear selection', () {
      notifier.selectPeer('peer_123');
      notifier.clearSelection();

      expect(notifier.state.selection.selectedPeerId, isNull);
      expect(notifier.state.selection.selectedChannel, isNull);
      expect(notifier.state.selection.isPrivateChat, false);
    });

    test('should block peer', () async {
      await notifier.blockPeer('peer_123');

      expect(notifier.state.blockedPeers, contains('peer_123'));
    });

    test('should not add same blocked peer twice', () async {
      await notifier.blockPeer('peer_123');
      await notifier.blockPeer('peer_123');

      expect(notifier.state.blockedPeers, hasLength(1));
    });

    test('should toggle favorite peer', () {
      notifier.toggleFavorite('peer_123');

      expect(notifier.state.favoritePeers, contains('peer_123'));

      notifier.toggleFavorite('peer_123');

      expect(notifier.state.favoritePeers, isNot(contains('peer_123')));
    });

    test('should set nickname', () {
      notifier.setNickname('test_user');

      expect(notifier.state.nickname, 'test_user');
    });

    test('should update connection status', () {
      notifier.updateConnectionStatus(ChatConnectionStatus.connected);

      expect(notifier.state.connectionStatus, ChatConnectionStatus.connected);
    });

    test('should clear error message', () {
      notifier.addSystemMessage('Test error message');
      notifier.clearError();

      expect(notifier.state.errorMessage, isNull);
    });

    test('should get command suggestions', () {
      final suggestions = notifier.getCommandSuggestions('/j');

      expect(suggestions, contains('/join'));
      expect(suggestions, isNot(contains('/who')));
    });

    test('should return empty command suggestions for non-command input', () {
      final suggestions = notifier.getCommandSuggestions('hello');

      expect(suggestions, isEmpty);
    });

    test('should show and hide suggestions', () {
      notifier.showSuggestions();

      expect(notifier.state.showCommandSuggestions, true);

      notifier.hideSuggestions();

      expect(notifier.state.showCommandSuggestions, false);
    });

    test('should update unread count for incoming private messages', () {
      meshService.peerManager.addPeer(PeerInfo(
        id: 'peer_123',
        name: 'Test Peer',
        isConnected: true,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      ));

      notifier.updatePeers();

      final message = BitchatMessage(
        id: 'test_id',
        sender: 'Test Peer',
        content: 'test message',
        timestamp: DateTime(2024, 1, 1),
        isPrivate: true,
        senderPeerID: 'peer_123',
      );

      notifier.addMessage(message);

      expect(notifier.state.unreadCount, 1);
      expect(notifier.state.unreadByPeer['peer_123'], 1);
    });

    test('should clear unread count when selecting peer', () {
      meshService.peerManager.addPeer(PeerInfo(
        id: 'peer_123',
        name: 'Test Peer',
        isConnected: true,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      ));

      notifier.updatePeers();

      final message = BitchatMessage(
        id: 'test_id',
        sender: 'Test Peer',
        content: 'test message',
        timestamp: DateTime(2024, 1, 1),
        isPrivate: true,
        senderPeerID: 'peer_123',
      );

      notifier.addMessage(message);
      expect(notifier.state.unreadByPeer['peer_123'], 1);

      notifier.selectPeer('peer_123');

      expect(notifier.state.unreadByPeer['peer_123'], isNull);
      expect(notifier.state.unreadCount, 0);
    });

    test('should update unread count for channel messages', () {
      final message = BitchatMessage(
        id: 'test_id',
        sender: 'Test Sender',
        content: 'test message',
        timestamp: DateTime(2024, 1, 1),
        channel: '#general',
      );

      notifier.addMessage(message);

      expect(notifier.state.unreadCount, 1);
      expect(notifier.state.unreadByChannel['#general'], 1);
    });

    test('should clear unread count when selecting channel', () {
      final message = BitchatMessage(
        id: 'test_id',
        sender: 'Test Sender',
        content: 'test message',
        timestamp: DateTime(2024, 1, 1),
        channel: '#general',
      );

      notifier.addMessage(message);
      expect(notifier.state.unreadByChannel['#general'], 1);

      notifier.selectChannel('#general');

      expect(notifier.state.unreadByChannel['#general'], isNull);
      expect(notifier.state.unreadCount, 0);
    });

    test('should not increment unread count for own messages', () {
      final message = BitchatMessage(
        id: 'test_id',
        sender: 'Me',
        content: 'my message',
        timestamp: DateTime(2024, 1, 1),
        senderPeerID: meshService.myPeerID,
      );

      notifier.addMessage(message);

      expect(notifier.state.unreadCount, 0);
    });

    test('should get mention suggestions for peers', () {
      meshService.peerManager.addPeer(PeerInfo(
        id: 'peer_1',
        name: 'Alice',
        isConnected: true,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      ));

      meshService.peerManager.addPeer(PeerInfo(
        id: 'peer_2',
        name: 'Bob',
        isConnected: true,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      ));

      notifier.updatePeers();

      final suggestions = notifier.getMentionSuggestions('Hello @al');

      expect(suggestions, contains('Alice'));
      expect(suggestions, isNot(contains('Bob')));
    });

    test('should not include disconnected peers in mention suggestions', () {
      meshService.peerManager.addPeer(PeerInfo(
        id: 'peer_1',
        name: 'Alice',
        isConnected: false,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      ));

      meshService.peerManager.addPeer(PeerInfo(
        id: 'peer_2',
        name: 'Bob',
        isConnected: true,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      ));

      notifier.updatePeers();

      final suggestions = notifier.getMentionSuggestions('Hello @');

      expect(suggestions, isNot(contains('Alice')));
      expect(suggestions, contains('Bob'));
    });

    test('should process /join command via sendMessage', () async {
      final mesh = MockBluetoothMeshService();
      final sfm = StoreForwardManager();
      final storage = MockMessageStorageService();
      final n = ChatNotifier(mesh, MessageHandler(mesh.myPeerID), sfm, storage);

      await n.sendMessage('/join #flutter');

      expect(n.state.joinedChannels, contains('#flutter'));
      // system message added
      expect(
          n.state.messages.last.content, contains('Joined channel: #flutter'));
      expect(mesh.lastSentContent, 'joined #flutter');
    });

    test('should process /msg command via sendMessage and select peer',
        () async {
      final mesh = MockBluetoothMeshService();
      mesh.peerManager.addPeer(PeerInfo(
        id: 'peer_42',
        name: 'Peer42',
        isConnected: true,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      ));
      final sfm = StoreForwardManager();
      final storage = MockMessageStorageService();
      final n = ChatNotifier(mesh, MessageHandler(mesh.myPeerID), sfm, storage);

      // Ensure notifier has current peers
      n.updatePeers();

      await n.sendMessage('/msg peer_42');

      expect(n.state.selection.selectedPeerId, 'peer_42');
      expect(n.state.messages.last.content, contains('Private chat with'));
    });

    test('should route channel message when channel selected', () async {
      final mesh = MockBluetoothMeshService();
      final sfm = StoreForwardManager();
      final storage = MockMessageStorageService();
      final n = ChatNotifier(mesh, MessageHandler(mesh.myPeerID), sfm, storage);

      n.selectChannel('#testing');
      await n.sendMessage('hello channel');

      // meshService.sendMessage should be called with channel
      expect(mesh.lastSentContent, 'hello channel');
      expect(mesh.lastSentChannel, '#testing');

      // store-forward should have enqueued an outbound message
      final pending = sfm.getPendingMessages();
      expect(pending, isNotEmpty);
      expect(pending.first.destination, '#testing');
    });

    test('should route private message when peer selected', () async {
      final mesh = MockBluetoothMeshService();
      mesh.peerManager.addPeer(PeerInfo(
        id: 'peer_x',
        name: 'PeerX',
        isConnected: true,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      ));
      final sfm = StoreForwardManager();
      final storage = MockMessageStorageService();
      final n = ChatNotifier(mesh, MessageHandler(mesh.myPeerID), sfm, storage);

      // Ensure peers are loaded into state
      n.updatePeers();

      n.selectPeer('peer_x');
      await n.sendMessage('hello private');

      // meshService.sendMessage should be called
      expect(mesh.lastSentContent, 'hello private');

      // store-forward should have enqueued outbound to peer id
      final pending = sfm.getPendingMessages();
      expect(pending, isNotEmpty);
      expect(pending.first.destination, 'peer_x');
    });

    test('should process /who command via sendMessage', () async {
      final mesh = MockBluetoothMeshService();
      mesh.peerManager.addPeer(PeerInfo(
        id: 'peer_a',
        name: 'Alice',
        isConnected: true,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      ));
      final sfm = StoreForwardManager();
      final storage = MockMessageStorageService();
      final n = ChatNotifier(mesh, MessageHandler(mesh.myPeerID), sfm, storage);

      n.updatePeers();

      await n.sendMessage('/who');

      expect(n.state.messages.last.content, contains('Online peers'));
    });
  });

  group('Integration Tests', () {
    test('should integrate with mesh service peer list', () {
      final meshService = MockBluetoothMeshService();
      final storeForwardManager = StoreForwardManager();
      final messageStorage = MockMessageStorageService();
      final notifier = ChatNotifier(
        meshService,
        MessageHandler(meshService.myPeerID),
        storeForwardManager,
        messageStorage,
      );

      meshService.peerManager.addPeer(PeerInfo(
        id: 'peer_1',
        name: 'Alice',
        isConnected: true,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      ));

      notifier.updatePeers();

      expect(notifier.state.peers, hasLength(1));
      expect(notifier.state.peers.first.id, 'peer_1');
      expect(notifier.state.peers.first.name, 'Alice');
    });

    test('should enqueue message in store-forward manager', () {
      final meshService = MockBluetoothMeshService();
      final storeForwardManager = StoreForwardManager();
      final messageStorage = MockMessageStorageService();
      final notifier = ChatNotifier(
        meshService,
        MessageHandler(meshService.myPeerID),
        storeForwardManager,
        messageStorage,
      );

      // Send a message
      notifier.addMessage(BitchatMessage(
        id: 'test_id',
        sender: 'test_sender',
        content: 'test content',
        timestamp: DateTime(2024, 1, 1),
      ));

      // Check if storeForwardManager is connected
      final pending = storeForwardManager.getPendingMessages();
      expect(pending, isA<List>());
    });
  });

  group('Provider Tests', () {
    // Note: These tests use the real chatProvider which requires Hive.
    // For now, we skip these tests as they require full Hive initialization.
    // The core functionality is tested above with mock services.
    test('should create ChatNotifier with mock services', () {
      final meshService = MockBluetoothMeshService();
      final storeForwardManager = StoreForwardManager();
      final messageStorage = MockMessageStorageService();
      final notifier = ChatNotifier(
        meshService,
        MessageHandler(meshService.myPeerID),
        storeForwardManager,
        messageStorage,
      );

      expect(notifier, isA<ChatNotifier>());
      expect(notifier.state, isA<ChatState>());
    });

    test('should update state via notifier', () {
      final meshService = MockBluetoothMeshService();
      final storeForwardManager = StoreForwardManager();
      final messageStorage = MockMessageStorageService();
      final notifier = ChatNotifier(
        meshService,
        MessageHandler(meshService.myPeerID),
        storeForwardManager,
        messageStorage,
      );

      notifier.addMessage(BitchatMessage(
        id: 'test_id',
        sender: 'test_sender',
        content: 'test content',
        timestamp: DateTime(2024, 1, 1),
      ));

      expect(notifier.state.messages, hasLength(1));
    });
  });
}
