import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bitchat/data/models/bitchat_message.dart';
import 'package:bitchat/data/models/routed_packet.dart';
import 'package:bitchat/data/models/bitchat_file_packet.dart';
import 'package:bitchat/features/mesh/bluetooth_mesh_service.dart';
import 'package:bitchat/features/mesh/peer_manager.dart' as pm;
import 'package:bitchat/features/mesh/message_handler.dart';
import 'package:bitchat/features/mesh/store_forward_manager.dart';
import 'package:bitchat/features/storage/message_storage_service.dart';
import 'package:bitchat/protocol/message_type.dart';

/// Represents the connection status of the mesh network.
enum ChatConnectionStatus {
  disconnected,
  connecting,
  connected,
  scanning,
  error,
}

/// Represents the current channel or peer selection context.
class ChatSelection {
  final String? selectedPeerId;
  final String? selectedChannel;
  final bool isPrivateChat;

  const ChatSelection({
    this.selectedPeerId,
    this.selectedChannel,
    this.isPrivateChat = false,
  });

  ChatSelection copyWith({
    String? selectedPeerId,
    String? selectedChannel,
    bool? isPrivateChat,
  }) {
    return ChatSelection(
      selectedPeerId: selectedPeerId ?? this.selectedPeerId,
      selectedChannel: selectedChannel ?? this.selectedChannel,
      isPrivateChat: isPrivateChat ?? this.isPrivateChat,
    );
  }
}

/// Contains all observable state for the chat system.
/// Mirrors Android ChatState.kt structure for cross-platform parity.
@immutable
class ChatState {
  /// List of all messages in the current view context.
  final List<BitchatMessage> messages;

  /// Current peer list with connection status.
  final List<pm.PeerInfo> peers;

  /// Currently selected peer or channel context.
  final ChatSelection selection;

  /// Current mesh connection status.
  final ChatConnectionStatus connectionStatus;

  /// Total unread message count.
  final int unreadCount;

  /// Unread messages per peer (peerId -> count).
  final Map<String, int> unreadByPeer;

  /// Unread messages per channel (channel -> count).
  final Map<String, int> unreadByChannel;

  /// Set of blocked peer IDs.
  final Set<String> blockedPeers;

  /// Currently joined channels.
  final Set<String> joinedChannels;

  /// Favorite peer IDs.
  final Set<String> favoritePeers;

  /// Password-protected channels.
  final Set<String> passwordProtectedChannels;

  /// Whether to show password prompt.
  final bool showPasswordPrompt;

  /// Password prompt target channel.
  final String? passwordPromptChannel;

  /// Whether command suggestions are visible.
  final bool showCommandSuggestions;

  /// Whether mention suggestions are visible.
  final bool showMentionSuggestions;

  /// Current mention suggestions.
  final List<String> mentionSuggestions;

  /// User nickname.
  final String nickname;

  /// Loading state indicator.
  final bool isLoading;

  /// Error message if any.
  final String? errorMessage;

  /// Current geohash location for location channel badge.
  /// Null means #mesh mode, non-null shows #<geohash>.
  final String? currentGeohash;

  const ChatState({
    this.messages = const [],
    this.peers = const [],
    this.selection = const ChatSelection(),
    this.connectionStatus = ChatConnectionStatus.disconnected,
    this.unreadCount = 0,
    this.unreadByPeer = const {},
    this.unreadByChannel = const {},
    this.blockedPeers = const {},
    this.joinedChannels = const {},
    this.favoritePeers = const {},
    this.passwordProtectedChannels = const {},
    this.showPasswordPrompt = false,
    this.passwordPromptChannel,
    this.showCommandSuggestions = false,
    this.showMentionSuggestions = false,
    this.mentionSuggestions = const [],
    this.nickname = '',
    this.isLoading = false,
    this.errorMessage,
    this.currentGeohash,
  });

  ChatState copyWith({
    List<BitchatMessage>? messages,
    List<pm.PeerInfo>? peers,
    ChatSelection? selection,
    ChatConnectionStatus? connectionStatus,
    int? unreadCount,
    Map<String, int>? unreadByPeer,
    Map<String, int>? unreadByChannel,
    Set<String>? blockedPeers,
    Set<String>? joinedChannels,
    Set<String>? favoritePeers,
    Set<String>? passwordProtectedChannels,
    bool? showPasswordPrompt,
    String? passwordPromptChannel,
    bool? showCommandSuggestions,
    bool? showMentionSuggestions,
    List<String>? mentionSuggestions,
    String? nickname,
    bool? isLoading,
    String? errorMessage,
    String? currentGeohash,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      peers: peers ?? this.peers,
      selection: selection ?? this.selection,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      unreadCount: unreadCount ?? this.unreadCount,
      unreadByPeer: unreadByPeer ?? this.unreadByPeer,
      unreadByChannel: unreadByChannel ?? this.unreadByChannel,
      blockedPeers: blockedPeers ?? this.blockedPeers,
      joinedChannels: joinedChannels ?? this.joinedChannels,
      favoritePeers: favoritePeers ?? this.favoritePeers,
      passwordProtectedChannels:
          passwordProtectedChannels ?? this.passwordProtectedChannels,
      showPasswordPrompt: showPasswordPrompt ?? this.showPasswordPrompt,
      passwordPromptChannel:
          passwordPromptChannel ?? this.passwordPromptChannel,
      showCommandSuggestions:
          showCommandSuggestions ?? this.showCommandSuggestions,
      showMentionSuggestions:
          showMentionSuggestions ?? this.showMentionSuggestions,
      mentionSuggestions: mentionSuggestions ?? this.mentionSuggestions,
      nickname: nickname ?? this.nickname,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      currentGeohash: currentGeohash ?? this.currentGeohash,
    );
  }
}

/// Manages chat state and operations with Riverpod StateNotifier pattern.
/// Integrates with BluetoothMeshService, MessageHandler, and StoreForwardManager.
/// Implements BluetoothMeshDelegate to receive messages from the mesh.
class ChatNotifier extends StateNotifier<ChatState>
    implements BluetoothMeshDelegate {
  final BluetoothMeshService _meshService;
  final MessageHandler _messageHandler;
  final StoreForwardManager _storeForwardManager;
  final MessageStorageService _messageStorage;

  StreamSubscription? _meshSubscription;

  ChatNotifier(
    this._meshService,
    this._messageHandler,
    this._storeForwardManager,
    this._messageStorage,
  ) : super(const ChatState()) {
    _initialize();
  }

  /// Initialize the chat provider and set up subscriptions.
  Future<void> _initialize() async {
    try {
      // Register as mesh delegate to receive messages
      _meshService.delegate = this;

      // Initialize message storage
      await _messageStorage.initialize();

      // Load persisted nickname
      await _loadPersistedNickname();

      // Load persisted messages
      await _loadPersistedMessages();

      // Set initial connection status based on mesh service
      if (_meshService.isActive) {
        state = state.copyWith(
          connectionStatus: ChatConnectionStatus.connected,
          peers: _meshService.peerManager.getAllPeers(),
        );
      }

      // Subscribe to message handler callbacks
      _messageHandler.delegate = _MessageHandlerDelegateImpl(this);
    } catch (e, stackTrace) {
      debugPrint('Error initializing ChatNotifier: $e\n$stackTrace');
      state = state.copyWith(
        connectionStatus: ChatConnectionStatus.error,
        errorMessage: 'Failed to initialize: $e',
      );
    }
  }

  /// Load persisted messages from storage.
  Future<void> _loadPersistedMessages() async {
    try {
      final publicMessages = _messageStorage.getPublicMessages();
      if (publicMessages.isNotEmpty) {
        state = state.copyWith(messages: publicMessages);
        debugPrint(
            '[ChatNotifier] Loaded ${publicMessages.length} persisted messages');
      }
    } catch (e) {
      debugPrint('[ChatNotifier] Error loading persisted messages: $e');
    }
  }

  /// Load persisted nickname from shared preferences.
  Future<void> _loadPersistedNickname() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nickname = prefs.getString('user_nickname') ?? '';
      if (nickname.isNotEmpty) {
        state = state.copyWith(nickname: nickname);
        _meshService.userNickname = nickname;
        debugPrint('[ChatNotifier] Loaded persisted nickname: $nickname');
      }
    } catch (e) {
      debugPrint('[ChatNotifier] Error loading persisted nickname: $e');
    }
  }

  // ============================================================
  // BluetoothMeshDelegate implementation
  // ============================================================

  @override
  void didReceiveMessage(BitchatMessage message) {
    debugPrint('[ChatNotifier] ========================================');
    debugPrint('[ChatNotifier] didReceiveMessage CALLED');
    debugPrint('[ChatNotifier] Message ID: ${message.id}');
    debugPrint('[ChatNotifier] Message sender: ${message.sender}');
    debugPrint('[ChatNotifier] Message content: "${message.content}"');
    debugPrint('[ChatNotifier] Message channel: ${message.channel}');
    debugPrint('[ChatNotifier] Message timestamp: ${message.timestamp}');
    debugPrint(
        '[ChatNotifier] Current state has ${state.messages.length} messages');
    debugPrint('[ChatNotifier] ========================================');

    // Persist message based on type
    _persistMessage(message);

    // Add to UI state
    debugPrint('[ChatNotifier] Calling addMessage...');
    addMessage(message);
    debugPrint(
        '[ChatNotifier] addMessage completed, now have ${state.messages.length} messages');
  }

  /// Persist a message to storage based on its type.
  Future<void> _persistMessage(BitchatMessage message) async {
    try {
      if (message.isPrivate && message.senderPeerID != null) {
        await _messageStorage.addPrivateMessage(message.senderPeerID!, message);
      } else if (message.channel != null) {
        await _messageStorage.addChannelMessage(message.channel!, message);
      } else {
        await _messageStorage.addPublicMessage(message);
      }
    } catch (e) {
      debugPrint('[ChatNotifier] Error persisting message: $e');
    }
  }

  @override
  void didUpdatePeerList(List<String> peers) {
    debugPrint('[ChatNotifier] didUpdatePeerList: ${peers.length} peers');
    updatePeers();
  }

  @override
  void didReceiveChannelLeave(String channel, String fromPeer) {
    debugPrint(
        '[ChatNotifier] didReceiveChannelLeave: $fromPeer left $channel');
    final newChannels = Set<String>.from(state.joinedChannels);
    if (newChannels.remove(channel)) {
      addSystemMessage('$fromPeer left channel: $channel');
      state = state.copyWith(joinedChannels: newChannels);
    }
  }

  @override
  void didReceiveDeliveryAck(String messageID, String recipientPeerID) {
    debugPrint(
        '[ChatNotifier] didReceiveDeliveryAck: $messageID from $recipientPeerID');
    final messages = List<BitchatMessage>.from(state.messages);
    final index = messages.indexWhere((m) => m.id == messageID);
    if (index != -1) {
      final status = DeliveryStatus.delivered(
        to: recipientPeerID,
        at: DateTime.now(),
      );
      messages[index] = messages[index].copyWith(deliveryStatus: status);
      state = state.copyWith(messages: messages);

      // Persist status change
      _messageStorage.updatePrivateMessageStatus(messageID, status);
    }
  }

  @override
  void didReceiveReadReceipt(String messageID, String recipientPeerID) {
    debugPrint(
        '[ChatNotifier] didReceiveReadReceipt: $messageID from $recipientPeerID');
    final messages = List<BitchatMessage>.from(state.messages);
    final index = messages.indexWhere((m) => m.id == messageID);
    if (index != -1) {
      final status = DeliveryStatus.read(
        by: recipientPeerID,
        at: DateTime.now(),
      );
      messages[index] = messages[index].copyWith(deliveryStatus: status);
      state = state.copyWith(messages: messages);

      // Persist status change
      _messageStorage.updatePrivateMessageStatus(messageID, status);
    }
  }

  @override
  String? getNickname() {
    return state.nickname.isNotEmpty ? state.nickname : null;
  }

  @override
  bool isFavorite(String peerID) {
    return state.favoritePeers.contains(peerID);
  }

  // ============================================================
  // End BluetoothMeshDelegate implementation
  // ============================================================

  /// Send a message to the mesh network.
  /// Routes to private message or public channel based on current selection.
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) {
      return;
    }

    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      // Check for command
      if (content.startsWith('/')) {
        await _processCommand(content);
        return;
      }

      final selection = state.selection;

      // Route based on selection context
      if (selection.isPrivateChat && selection.selectedPeerId != null) {
        await _sendPrivateMessage(content, selection.selectedPeerId!);
      } else if (selection.selectedChannel != null) {
        await _sendChannelMessage(content, selection.selectedChannel!);
      } else {
        // Public broadcast
        await _sendPublicMessage(content);
      }

      state = state.copyWith(isLoading: false);
    } catch (e, stackTrace) {
      debugPrint('Error sending message: $e\n$stackTrace');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to send message: $e',
      );
    }
  }

  /// Process a slash command.
  Future<void> _processCommand(String command) async {
    try {
      final parts = command.split(' ');
      final cmd = parts[0].toLowerCase();
      final args = parts.skip(1).join(' ');

      switch (cmd) {
        case '/join':
          await _handleJoinCommand(args);
          break;
        case '/msg':
          await _handleMsgCommand(args);
          break;
        case '/who':
          await _handleWhoCommand();
          break;
        case '/block':
          await _handleBlockCommand(args);
          break;
        case '/unblock':
          await _handleUnblockCommand(args);
          break;
        case '/leave':
          await _handleLeaveCommand(args);
          break;
        case '/clear':
          clearMessages();
          break;
        default:
          addSystemMessage('Unknown command: $cmd');
      }
    } catch (e, stackTrace) {
      debugPrint('Error processing command: $e\n$stackTrace');
      addSystemMessage('Error processing command: $e');
    }
  }

  /// Handle /join command to join a channel.
  Future<void> _handleJoinCommand(String channel) async {
    if (channel.trim().isEmpty) {
      addSystemMessage('Usage: /join <channel_name>');
      return;
    }

    final newChannels = Set<String>.from(state.joinedChannels);
    if (!newChannels.contains(channel)) {
      newChannels.add(channel);
      state = state.copyWith(joinedChannels: newChannels);
      addSystemMessage('Joined channel: $channel');

      // Send join notification via mesh
      await _meshService.sendMessage('joined $channel');
    } else {
      addSystemMessage('Already in channel: $channel');
    }
  }

  /// Handle /msg command to start private chat.
  Future<void> _handleMsgCommand(String args) async {
    if (args.trim().isEmpty) {
      addSystemMessage('Usage: /msg <peer_id_or_nickname>');
      return;
    }

    // Try to find peer by ID or nickname
    final peer = state.peers.firstWhere(
      (p) => p.id == args || p.name == args,
      orElse: () => throw Exception('Peer not found: $args'),
    );

    selectPeer(peer.id);
    addSystemMessage('Private chat with ${peer.name}');
  }

  /// Handle /who command to list online peers.
  Future<void> _handleWhoCommand() async {
    final connectedPeers = state.peers.where((p) => p.isConnected).toList();
    if (connectedPeers.isEmpty) {
      addSystemMessage('No peers currently connected.');
    } else {
      final peerList =
          connectedPeers.map((p) => '• ${p.name} (${p.id})').join('\n');
      addSystemMessage('Online peers:\n$peerList');
    }
  }

  /// Handle /block command to block a peer.
  Future<void> _handleBlockCommand(String peerId) async {
    if (peerId.trim().isEmpty) {
      addSystemMessage('Usage: /block <peer_id>');
      return;
    }

    await blockPeer(peerId);
  }

  /// Handle /unblock command to unblock a peer.
  Future<void> _handleUnblockCommand(String peerId) async {
    if (peerId.trim().isEmpty) {
      addSystemMessage('Usage: /unblock <peer_id>');
      return;
    }

    final newBlockedPeers = Set<String>.from(state.blockedPeers);
    if (newBlockedPeers.remove(peerId)) {
      state = state.copyWith(blockedPeers: newBlockedPeers);
      addSystemMessage('Unblocked peer: $peerId');
    } else {
      addSystemMessage('Peer not blocked: $peerId');
    }
  }

  /// Handle /leave command to leave a channel.
  Future<void> _handleLeaveCommand(String channel) async {
    if (channel.trim().isEmpty) {
      addSystemMessage('Usage: /leave <channel_name>');
      return;
    }

    final newChannels = Set<String>.from(state.joinedChannels);
    if (newChannels.remove(channel)) {
      state = state.copyWith(joinedChannels: newChannels);
      addSystemMessage('Left channel: $channel');

      // Send leave notification via mesh
      await _meshService.sendMessage('left $channel');

      // Clear messages for this channel
      if (state.selection.selectedChannel == channel) {
        selectChannel(null);
      }
    } else {
      addSystemMessage('Not in channel: $channel');
    }
  }

  /// Send a private message to a peer.
  Future<void> _sendPrivateMessage(String content, String peerId) async {
    final peer = state.peers.firstWhere(
      (p) => p.id == peerId,
      orElse: () => throw Exception('Peer not found: $peerId'),
    );

    // Create message with private flag
    final message = BitchatMessage(
      id: _generateMessageId(),
      sender:
          state.nickname.isNotEmpty ? state.nickname : _meshService.myPeerID,
      content: content,
      timestamp: DateTime.now(),
      isPrivate: true,
      recipientNickname: peer.name,
      senderPeerID: _meshService.myPeerID,
      deliveryStatus: const DeliveryStatus.sending(),
    );

    // Add optimistically to state
    _addMessage(message);

    // Send via mesh service (will need to implement private message routing)
    await _meshService.sendMessage(content);

    // Enqueue for store-forward
    _storeForwardManager.enqueueMessage(StoreForwardMessage(
      id: message.id,
      payload: content,
      destination: peerId,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      type: StoreForwardMessageType.outbound,
    ));

    debugPrint('Sent private message to $peerId: $content');
  }

  /// Send a message to a channel.
  Future<void> _sendChannelMessage(String content, String channel) async {
    // Create message with channel
    final message = BitchatMessage(
      id: _generateMessageId(),
      sender:
          state.nickname.isNotEmpty ? state.nickname : _meshService.myPeerID,
      content: content,
      timestamp: DateTime.now(),
      channel: channel,
      senderPeerID: _meshService.myPeerID,
      deliveryStatus: const DeliveryStatus.sending(),
    );

    // Add optimistically to state
    _addMessage(message);

    // Send via mesh service
    await _meshService.sendMessage(content, channel: channel);

    // Enqueue for store-forward
    _storeForwardManager.enqueueMessage(StoreForwardMessage(
      id: message.id,
      payload: content,
      destination: channel,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      type: StoreForwardMessageType.outbound,
    ));

    debugPrint('Sent channel message to $channel: $content');
  }

  /// Send a public broadcast message.
  Future<void> _sendPublicMessage(String content) async {
    final message = BitchatMessage(
      id: _generateMessageId(),
      sender:
          state.nickname.isNotEmpty ? state.nickname : _meshService.myPeerID,
      content: content,
      timestamp: DateTime.now(),
      senderPeerID: _meshService.myPeerID,
      deliveryStatus: const DeliveryStatus.sending(),
    );

    // Add optimistically to state
    _addMessage(message);

    debugPrint('[ChatNotifier] Calling meshService.sendMessage: "$content"');

    // Send via mesh service
    await _meshService.sendMessage(content);

    // Enqueue for store-forward
    _storeForwardManager.enqueueMessage(StoreForwardMessage(
      id: message.id,
      payload: content,
      destination: 'mesh-broadcast',
      timestamp: DateTime.now().millisecondsSinceEpoch,
      type: StoreForwardMessageType.outbound,
    ));

    debugPrint('[ChatNotifier] Sent broadcast message: $content');
  }

  /// Add a message to state.
  void addMessage(BitchatMessage message) {
    _addMessage(message);

    // Update unread counts if message is not from self
    if (message.senderPeerID != _meshService.myPeerID) {
      _updateUnreadCounts(message);
    }
  }

  /// Set to track seen message IDs for deduplication
  final Set<String> _seenMessageIds = {};

  /// Internal method to add message and notify listeners.
  void _addMessage(BitchatMessage message) {
    // Deduplicate by message ID
    if (_seenMessageIds.contains(message.id)) {
      debugPrint('[ChatNotifier] Skipping duplicate message: ${message.id}');
      return;
    }
    _seenMessageIds.add(message.id);

    final updatedMessages = List<BitchatMessage>.from(state.messages);
    updatedMessages.add(message);
    state = state.copyWith(messages: updatedMessages);
  }

  /// Add a system message to the chat (public for testing).
  void addSystemMessage(String content) {
    final systemMessage = BitchatMessage(
      id: _generateMessageId(),
      sender: 'system',
      content: content,
      timestamp: DateTime.now(),
    );
    _addMessage(systemMessage);
  }

  /// Update unread counts for private messages and channel messages.
  void _updateUnreadCounts(BitchatMessage message) {
    if (message.isPrivate && message.senderPeerID != null) {
      final newUnreadByPeer = Map<String, int>.from(state.unreadByPeer);
      final peerId = message.senderPeerID!;
      newUnreadByPeer[peerId] = (newUnreadByPeer[peerId] ?? 0) + 1;

      final newTotal = state.unreadCount + 1;
      state = state.copyWith(
        unreadByPeer: newUnreadByPeer,
        unreadCount: newTotal,
      );
    } else if (message.channel != null) {
      final channel = message.channel!;
      final newUnreadByChannel = Map<String, int>.from(state.unreadByChannel);
      newUnreadByChannel[channel] = (newUnreadByChannel[channel] ?? 0) + 1;

      final newTotal = state.unreadCount + 1;
      state = state.copyWith(
        unreadByChannel: newUnreadByChannel,
        unreadCount: newTotal,
      );
    }
  }

  /// Clear all messages from state.
  void clearMessages() {
    state = state.copyWith(messages: const []);
    debugPrint('Cleared all messages');
  }

  /// Select a peer for private chat.
  void selectPeer(String peerId) {
    final newSelection = state.selection.copyWith(
      selectedPeerId: peerId,
      selectedChannel: null,
      isPrivateChat: true,
    );
    state = state.copyWith(selection: newSelection);

    // Clear unread count for this peer
    _clearUnreadForPeer(peerId);

    debugPrint('Selected peer: $peerId');
  }

  /// Select a channel.
  void selectChannel(String? channel) {
    final newSelection = state.selection.copyWith(
      selectedPeerId: null,
      selectedChannel: channel,
      isPrivateChat: false,
    );
    state = state.copyWith(selection: newSelection);

    // Clear unread count for this channel
    if (channel != null) {
      _clearUnreadForChannel(channel);
    }

    debugPrint('Selected channel: $channel');
  }

  /// Clear current selection.
  void clearSelection() {
    state = state.copyWith(selection: const ChatSelection());
    debugPrint('Cleared selection');
  }

  /// Leave a channel.
  Future<void> leaveChannel(String channel) async {
    await _handleLeaveCommand(channel);
  }

  /// Block a peer by ID.
  Future<void> blockPeer(String peerId) async {
    final newBlockedPeers = Set<String>.from(state.blockedPeers);
    if (!newBlockedPeers.contains(peerId)) {
      newBlockedPeers.add(peerId);
      state = state.copyWith(blockedPeers: newBlockedPeers);
      addSystemMessage('Blocked peer: $peerId');

      // Optionally notify peer via mesh
      await _meshService.sendMessage('blocked $peerId');
    } else {
      addSystemMessage('Peer already blocked: $peerId');
    }
  }

  /// Toggle favorite status for a peer.
  void toggleFavorite(String peerId) {
    final newFavorites = Set<String>.from(state.favoritePeers);
    if (newFavorites.contains(peerId)) {
      newFavorites.remove(peerId);
      addSystemMessage('Removed from favorites: $peerId');
    } else {
      newFavorites.add(peerId);
      addSystemMessage('Added to favorites: $peerId');
    }
    state = state.copyWith(favoritePeers: newFavorites);
  }

  /// Update nickname.
  void setNickname(String nickname) async {
    state = state.copyWith(nickname: nickname);
    // Update mesh service with new nickname for announcements
    _meshService.userNickname = nickname;
    // Persist nickname
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_nickname', nickname);
    } catch (e) {
      debugPrint('Error saving nickname: $e');
    }
    debugPrint('Nickname set to: $nickname');
  }

  /// Update current geohash from location services.
  /// Called by LocationChannelManager when location updates.
  void updateCurrentGeohash(String? geohash) {
    if (state.currentGeohash != geohash) {
      state = state.copyWith(currentGeohash: geohash);
      debugPrint('[ChatNotifier] Current geohash updated: $geohash');
    }
  }

  /// Update peer list from mesh service.
  void updatePeers() {
    final peers = _meshService.peerManager.getAllPeers();
    state = state.copyWith(peers: peers);
  }

  /// Update connection status.
  void updateConnectionStatus(ChatConnectionStatus status) {
    state = state.copyWith(connectionStatus: status);
  }

  /// Clear unread count for a specific peer.
  void _clearUnreadForPeer(String peerId) {
    final newUnreadByPeer = Map<String, int>.from(state.unreadByPeer);
    final oldCount = newUnreadByPeer.remove(peerId) ?? 0;
    final newTotal =
        (state.unreadCount - oldCount).clamp(0, double.infinity).toInt();

    state = state.copyWith(
      unreadByPeer: newUnreadByPeer,
      unreadCount: newTotal,
    );
  }

  /// Clear unread count for a specific channel.
  void _clearUnreadForChannel(String channel) {
    final newUnreadByChannel = Map<String, int>.from(state.unreadByChannel);
    final oldCount = newUnreadByChannel.remove(channel) ?? 0;
    final newTotal =
        (state.unreadCount - oldCount).clamp(0, double.infinity).toInt();

    state = state.copyWith(
      unreadByChannel: newUnreadByChannel,
      unreadCount: newTotal,
    );
  }

  /// Generate a unique message ID.
  String _generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}_${state.messages.length}';
  }

  /// Clear any error message.
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// Get command suggestions for current input.
  List<String> getCommandSuggestions(String input) {
    if (!input.startsWith('/')) {
      return const [];
    }

    final commands = [
      '/join',
      '/msg',
      '/who',
      '/block',
      '/unblock',
      '/leave',
      '/clear'
    ];
    final match = input.toLowerCase();

    return commands.where((cmd) => cmd.startsWith(match)).toList();
  }

  /// Get mention suggestions for current input.
  List<String> getMentionSuggestions(String input) {
    final mentionMatch = RegExp(r'@(\w*)$').firstMatch(input);
    if (mentionMatch == null) {
      return const [];
    }

    final partial = mentionMatch.group(1)?.toLowerCase() ?? '';
    final connectedPeers = state.peers.where((p) => p.isConnected).toList();

    final suggestions = connectedPeers
        .where((p) => p.name.toLowerCase().startsWith(partial))
        .map((p) => p.name)
        .toList();

    return suggestions.cast<String>();
  }

  /// Show command suggestions.
  void showSuggestions() {
    state = state.copyWith(showCommandSuggestions: true);
  }

  /// Hide command suggestions.
  void hideSuggestions() {
    state = state.copyWith(
      showCommandSuggestions: false,
      showMentionSuggestions: false,
      mentionSuggestions: const [],
    );
  }

  @override
  void dispose() {
    _meshSubscription?.cancel();
    super.dispose();
  }
}

/// Implementation of MessageHandlerDelegate for ChatNotifier.
class _MessageHandlerDelegateImpl implements MessageHandlerDelegate {
  final ChatNotifier notifier;

  _MessageHandlerDelegateImpl(this.notifier);

  @override
  void logInfo(String message) {
    debugPrint('[ChatProvider] INFO: $message');
  }

  @override
  void logWarning(String message) {
    debugPrint('[ChatProvider] WARNING: $message');
  }

  @override
  void logError(String message, [Object? stackTrace]) {
    debugPrint('[ChatProvider] ERROR: $message');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }

  @override
  Future<PeerInfo?> getPeerInfo(String peerID) async {
    final peer = notifier._meshService.peerManager.getPeer(peerID);
    if (peer == null) return null;
    return PeerInfo(
      nickname: peer.name,
      noisePublicKey: peer.noisePublicKey,
      signingPublicKey: peer.signingPublicKey,
      isVerifiedNickname: peer.isVerifiedName,
      lastSeen: DateTime.fromMillisecondsSinceEpoch(peer.lastSeen),
    );
  }

  @override
  Future<void> updatePeerInfo({
    required String peerID,
    required String nickname,
    Uint8List? noisePublicKey,
    Uint8List? signingPublicKey,
    required bool isVerified,
  }) async {
    // Delegate to PeerManager via mesh service
    notifier._meshService.peerManager.updatePeer(
      peerID,
      name: nickname,
      noisePublicKey: noisePublicKey,
      signingPublicKey: signingPublicKey,
      isVerifiedName: isVerified,
    );
    notifier.updatePeers();
  }

  @override
  Future<void> removePeer(String peerID) async {
    notifier._meshService.peerManager.removePeer(peerID);
    notifier.updatePeers();
  }

  @override
  Future<String?> getMyNickname() async {
    return notifier.getNickname();
  }

  @override
  Future<bool> verifyEd25519Signature(
    Uint8List signature,
    Uint8List data,
    Uint8List publicKey,
  ) async {
    // Delegate to encryption service if needed
    // For now, return false as verification is handled elsewhere
    return false;
  }

  @override
  Future<bool> verifySignature(BitchatPacket packet, String peerID) async {
    // Delegate to encryption service if needed
    return false;
  }

  @override
  Future<Uint8List?> decryptFromPeer(
    Uint8List encryptedData,
    String senderPeerID,
  ) async {
    // Delegate to encryption service
    return null;
  }

  @override
  Future<bool> hasNoiseSession(String peerID) async {
    // Check with mesh service
    return false;
  }

  @override
  Future<Uint8List?> processNoiseHandshakeMessage(
    Uint8List payload,
    String peerID,
  ) async {
    // Delegate to mesh service
    return null;
  }

  @override
  Future<void> sendPacketToPeer(
    String peerID,
    MessageType type,
    Uint8List payload,
  ) async {
    // Send via mesh service
  }

  @override
  Future<BitchatPacket?> handleFragment(BitchatPacket packet) async {
    // Handle fragmentation if needed
    return null;
  }

  @override
  Future<String> saveIncomingFile(BitchatFilePacket file) async {
    // Save file to local storage
    return file.fileName;
  }

  @override
  Future<void> handleRequestSync(RoutedPacket routed) async {
    // Handle sync request if needed
  }

  @override
  void onMessageReceived(BitchatMessage message) {
    // Delegate to BluetoothMeshDelegate implementation
    notifier.didReceiveMessage(message);
  }

  @override
  void onChannelLeave(String channel, String fromPeer) {
    // Delegate to BluetoothMeshDelegate implementation
    notifier.didReceiveChannelLeave(channel, fromPeer);
  }

  @override
  void onDeliveryAckReceived(String messageID, String peerID) {
    // Delegate to BluetoothMeshDelegate implementation
    notifier.didReceiveDeliveryAck(messageID, peerID);
  }

  @override
  void onReadReceiptReceived(String messageID, String peerID) {
    // Delegate to BluetoothMeshDelegate implementation
    notifier.didReceiveReadReceipt(messageID, peerID);
  }
}

/// Provider for the ChatNotifier (StateNotifier<ChatState>).
/// Integrates with meshServiceProvider, messageHandler, and storeForwardManager.
final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final meshService = ref.watch(meshServiceProvider);

  // Note: MessageHandler and StoreForwardManager will need proper providers
  // For now, create instances directly (to be refactored with proper DI)
  final messageHandler = MessageHandler(meshService.myPeerID);
  final storeForwardManager = StoreForwardManager();
  final messageStorage = MessageStorageService();

  return ChatNotifier(
    meshService,
    messageHandler,
    storeForwardManager,
    messageStorage,
  );
});
