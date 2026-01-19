import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bitchat/data/models/bitchat_message.dart';
import 'package:bitchat/features/chat/chat_provider.dart';
import 'package:bitchat/features/debug/debug_settings_provider.dart';
import 'package:bitchat/ui/theme/bitchat_colors.dart';
import 'package:bitchat/ui/widgets/about_sheet.dart';
import 'package:bitchat/ui/widgets/chat_input.dart';
import 'package:bitchat/ui/widgets/location_channels_sheet.dart';
import 'package:bitchat/ui/widgets/message_bubble.dart';
import 'package:bitchat/ui/widgets/network_sidebar_content.dart';
import 'package:bitchat/ui/widgets/responsive_sidebar.dart';
import 'package:bitchat/ui/widgets/status_badges.dart';

/// Main chat screen for Bitchat mesh messaging.
/// Displays message history, handles input, and provides access to peers and channels.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  // Input state
  String _inputText = '';

  // Nickname editing state
  bool _isEditingNickname = false;
  late TextEditingController _nicknameController;
  late FocusNode _nicknameFocusNode;

  // Scroll controller for messages
  final ScrollController _scrollController = ScrollController();

  // Suggestion state
  bool _showCommandSuggestions = false;
  bool _showMentionSuggestions = false;
  List<String> _commandSuggestions = [];
  List<String> _mentionSuggestions = [];

  // Sidebar state
  final GlobalKey<ResponsiveSidebarState> _sidebarKey =
      GlobalKey<ResponsiveSidebarState>();
  bool _isSidebarVisible = true;

  // Debug panel state
  bool _debugPanelExpanded = true;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController();
    _nicknameFocusNode = FocusNode();
    _nicknameFocusNode.addListener(_onNicknameFocusChange);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _nicknameFocusNode.removeListener(_onNicknameFocusChange);
    _nicknameFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Handle nickname focus changes.
  void _onNicknameFocusChange() {
    if (!_nicknameFocusNode.hasFocus && _isEditingNickname) {
      _saveNickname();
    }
  }

  /// Start editing the nickname.
  void _startEditingNickname(String currentNickname) {
    setState(() {
      _isEditingNickname = true;
      _nicknameController.text = currentNickname;
    });
    // Request focus after the frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nicknameFocusNode.requestFocus();
    });
  }

  /// Save the edited nickname.
  void _saveNickname() {
    if (_nicknameController.text.trim().isNotEmpty) {
      final chatNotifier = ref.read(chatProvider.notifier);
      chatNotifier.setNickname(_nicknameController.text.trim());
    }
    setState(() {
      _isEditingNickname = false;
    });
  }

  /// Handles message sending.
  void _handleSend() {
    if (_inputText.trim().isEmpty) return;

    final chatNotifier = ref.read(chatProvider.notifier);

    // Send message via chatNotifier (handles routing based on selection)
    chatNotifier.sendMessage(_inputText);

    setState(() {
      _inputText = '';
    });

    // Scroll to bottom after sending
    _scrollToBottom();
  }

  /// Handles text input changes.
  void _handleTextChanged(String text) {
    setState(() {
      _inputText = text;
    });

    // Check for command suggestions (starts with /)
    if (text.startsWith('/')) {
      _updateCommandSuggestions(text);
    } else {
      setState(() {
        _showCommandSuggestions = false;
        _commandSuggestions = [];
      });
    }

    // Check for mention suggestions (contains @)
    if (text.contains('@')) {
      _updateMentionSuggestions(text);
    } else {
      setState(() {
        _showMentionSuggestions = false;
        _mentionSuggestions = [];
      });
    }
  }

  /// Updates command suggestions based on current input.
  void _updateCommandSuggestions(String text) {
    final chatNotifier = ref.read(chatProvider.notifier);
    final suggestions = chatNotifier.getCommandSuggestions(text);

    setState(() {
      _commandSuggestions = suggestions;
      _showCommandSuggestions = suggestions.isNotEmpty;
    });
  }

  /// Updates mention suggestions based on current input.
  void _updateMentionSuggestions(String text) {
    final chatNotifier = ref.read(chatProvider.notifier);
    final suggestions = chatNotifier.getMentionSuggestions(text);

    setState(() {
      _mentionSuggestions = suggestions;
      _showMentionSuggestions = suggestions.isNotEmpty;
    });
  }

  /// Handles selection of a mention suggestion.
  void _handleMentionSelected(String mention) {
    final text = _inputText;
    final mentionMatch = RegExp(r'@([a-zA-Z0-9_]*)$').firstMatch(text);

    if (mentionMatch != null) {
      // Replace partial mention with selected one
      final beforeMention = text.substring(0, mentionMatch.start);
      final afterMention = text.substring(mentionMatch.end);
      final newText = '$beforeMention@$mention $afterMention';

      setState(() {
        _inputText = newText;
        _showMentionSuggestions = false;
        _mentionSuggestions = [];
      });
    }
  }

  /// Handles selection of a command suggestion.
  void _handleCommandSelected(String command) {
    setState(() {
      _inputText = '$command ';
      _showCommandSuggestions = false;
      _commandSuggestions = [];
    });
  }

  /// Shows the location channels sheet.
  void _showLocationChannelsSheet() {
    final chatState = ref.read(chatProvider);
    showLocationChannelsSheet(
      context,
      currentGeohash: chatState.currentGeohash,
      selectedChannel: chatState.selection.selectedChannel,
      onChannelSelected: _handleChannelChanged,
    );
  }

  /// Handles channel selection change.
  void _handleChannelChanged(String? channel) {
    final chatNotifier = ref.read(chatProvider.notifier);
    chatNotifier.selectChannel(channel);
  }

  /// Handles tapping on a peer (start private chat).
  void _handlePeerTap(String peerId) {
    final chatNotifier = ref.read(chatProvider.notifier);
    chatNotifier.selectPeer(peerId);
  }

  /// Handles peer verification action.
  void _handleVerifyPeer(String peerId) {
    // TODO: Implement peer verification flow
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Verify $peerId coming soon!')),
    );
  }

  /// Handles peer blocking action.
  void _handleBlockPeer(String peerId) {
    final chatNotifier = ref.read(chatProvider.notifier);
    chatNotifier.blockPeer(peerId);
  }

  /// Scrolls the message list to the bottom.
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(
        const Duration(milliseconds: 100),
        () => _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        ),
      );
    }
  }

  /// Toggles the network sidebar visibility.
  void _toggleSidebar() {
    _sidebarKey.currentState?.toggleSidebar();
  }

  /// Shows the network sidebar (for mobile).
  void _showNetworkSidebar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= kDesktopBreakpoint;

    if (isDesktop) {
      // On desktop, just toggle the sidebar
      _toggleSidebar();
    } else {
      // On mobile, show the sidebar
      _sidebarKey.currentState?.showSidebar();
    }
  }

  /// Shows the peer list sheet (fallback for mobile when sidebar is hidden).
  void _showPeerListSheet() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= kDesktopBreakpoint;

    if (isDesktop) {
      // On desktop, show/toggle the sidebar instead
      if (!_isSidebarVisible) {
        _toggleSidebar();
      }
    } else {
      // On mobile, show the sidebar panel
      _showNetworkSidebar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= kDesktopBreakpoint;

    // Watch chat state
    final chatState = ref.watch(chatProvider);

    // DEBUG: Log every rebuild to confirm UI updates
    debugPrint('[ChatScreen] ========================================');
    debugPrint('[ChatScreen] BUILD CALLED');
    debugPrint('[ChatScreen] peers.length: ${chatState.peers.length}');
    debugPrint('[ChatScreen] messages.length: ${chatState.messages.length}');
    for (final p in chatState.peers) {
      debugPrint('[ChatScreen]   peer: ${p.name} (${p.id}), connected: ${p.isConnected}');
    }
    debugPrint('[ChatScreen] ========================================');

    // Watch debug settings for verbose mode
    final debugState = ref.watch(debugSettingsProvider);
    final isVerbose = debugState.verboseLoggingEnabled;

    // Build the main chat content
    final chatContent = Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        titleSpacing: 8,
        title: _buildHeader(chatState, colorScheme),
        actions: [
          // Location channels button (#mesh or #geohash) - matches Android
          LocationBadge(
            geohash: chatState.currentGeohash,
            onTap: _showLocationChannelsSheet,
          ),
          const SizedBox(width: 6),

          // Tor status dot (8dp colored circle) - matches Android
          const TorStatusDot(),
          const SizedBox(width: 4),

          // PoW status indicator (security icon) - matches Android
          const PoWStatusBadge(),
          const SizedBox(width: 4),

          // Peer counter with group icon - matches Android PeerCounter
          _buildPeerCounter(chatState, colorScheme),

          // Desktop: Sidebar toggle button
          if (isDesktop) ...[
            const SizedBox(width: 4),
            SidebarToggleButton(
              isVisible: _isSidebarVisible,
              onToggle: _toggleSidebar,
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Divider under header
          Divider(
            height: 1,
            thickness: 1,
            color: colorScheme.primary.withOpacity(0.2),
          ),

          // Debug panel (only when verbose logging enabled)
          if (isVerbose) _buildDebugMessagesPanel(chatState, colorScheme),

          // Messages list
          Expanded(
            child: _buildMessagesList(theme, colorScheme, chatState),
          ),

          // Chat input
          ChatInput(
            text: _inputText,
            onTextChanged: _handleTextChanged,
            onSend: _handleSend,
            selectedChannel: chatState.selection.selectedChannel,
            availableChannels: chatState.joinedChannels.toList(),
            onChannelChanged: _handleChannelChanged,
            isStoreForwardEnabled: true, // TODO: Check store-forward status
            showMentionSuggestions: _showMentionSuggestions,
            mentionSuggestions: _mentionSuggestions,
            onMentionSelected: _handleMentionSelected,
            showCommandSuggestions: _showCommandSuggestions,
            commandSuggestions: _commandSuggestions,
            onCommandSelected: _handleCommandSelected,
          ),
        ],
      ),
    );

    // Build the sidebar content (wrap in Material for ListTile)
    final sidebarContent = Material(
      color: colorScheme.surface,
      child: NetworkSidebarContent(
        peers: chatState.peers,
        selectedPrivatePeerId: chatState.selection.selectedPeerId,
        onPeerTap: _handlePeerTap,
        onVerifyTap: _handleVerifyPeer,
        onBlockTap: _handleBlockPeer,
        channels: chatState.joinedChannels.toList(),
        selectedChannel: chatState.selection.selectedChannel,
        onChannelTap: _handleChannelChanged,
        currentGeohash: chatState.currentGeohash,
      ),
    );

    // Wrap with responsive sidebar
    return ResponsiveSidebar(
      key: _sidebarKey,
      initiallyVisible: isDesktop, // Desktop: visible by default, Mobile: hidden
      onVisibilityChanged: (visible) {
        setState(() {
          _isSidebarVisible = visible;
        });
      },
      sidebarHeader: SidebarHeader(
        title: 'Your Network',
        onClose: () {
          _sidebarKey.currentState?.hideSidebar();
        },
        showCloseButton: !isDesktop, // Only show close button on mobile
      ),
      sidebar: sidebarContent,
      child: chatContent,
    );
  }

  /// Builds the header with editable nickname (matches Android).
  Widget _buildHeader(ChatState chatState, ColorScheme colorScheme) {
    final nickname = chatState.nickname.isEmpty ? 'anon' : chatState.nickname;

    // Check if we're in a channel
    if (chatState.selection.selectedChannel != null) {
      return _buildChannelHeader(
          chatState.selection.selectedChannel!, colorScheme);
    }

    return Row(
      children: [
        // "bitchat" title
        GestureDetector(
          onTap: () {
            showAboutSheet(context);
          },
          child: Text(
            'bitchat',
            style: TextStyle(
              color: colorScheme.primary,
              fontFamily: 'monospace',
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(width: 4),

        // Editable nickname with @ prefix
        _buildNicknameEditor(nickname, colorScheme),
      ],
    );
  }

  /// Builds the editable nickname editor.
  Widget _buildNicknameEditor(String nickname, ColorScheme colorScheme) {
    if (_isEditingNickname) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '@',
            style: TextStyle(
              color: colorScheme.primary.withOpacity(0.8),
              fontFamily: 'monospace',
              fontSize: 14,
            ),
          ),
          SizedBox(
            width: 100,
            child: TextField(
              controller: _nicknameController,
              focusNode: _nicknameFocusNode,
              style: TextStyle(
                color: colorScheme.primary,
                fontFamily: 'monospace',
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _saveNickname(),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () => _startEditingNickname(nickname),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '@',
            style: TextStyle(
              color: colorScheme.primary.withOpacity(0.8),
              fontFamily: 'monospace',
              fontSize: 14,
            ),
          ),
          Text(
            nickname,
            style: TextStyle(
              color: colorScheme.primary,
              fontFamily: 'monospace',
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the channel header with back button.
  Widget _buildChannelHeader(String channel, ColorScheme colorScheme) {
    return Row(
      children: [
        // Back button
        GestureDetector(
          onTap: () {
            final chatNotifier = ref.read(chatProvider.notifier);
            chatNotifier.selectChannel(null);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_back,
                color: colorScheme.primary,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                'Back',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 16),

        // Channel name
        Expanded(
          child: Center(
            child: Text(
              '#$channel',
              style: TextStyle(
                color: BitchatColors.selfMessageColor,
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Leave button
        GestureDetector(
          onTap: () {
            final chatNotifier = ref.read(chatProvider.notifier);
            chatNotifier.leaveChannel(channel);
          },
          child: Text(
            'Leave',
            style: TextStyle(
              color: colorScheme.error,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the peer counter widget (matches Android PeerCounter).
  /// Color is based on channel selection:
  /// - Mesh channel: blue (BitchatColors.meshBlue)
  /// - Geohash channel: green (BitchatColors.locationGreen)
  Widget _buildPeerCounter(ChatState chatState, ColorScheme colorScheme) {
    final peerCount = chatState.peers.length;
    final isGeohashMode = chatState.currentGeohash != null;

    // DEBUG: Print peer count when building this widget
    debugPrint('[PeerCounter] Building with peerCount: $peerCount');

    // Match Android colors: blue for mesh, green for geohash
    final countColor = isGeohashMode
        ? BitchatColors.locationGreen
        : BitchatColors.meshBlue;

    return GestureDetector(
      onTap: _showPeerListSheet,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.group,
            color: peerCount > 0 ? countColor : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            '$peerCount',
            style: TextStyle(
              fontSize: 16,
              color: peerCount > 0 ? countColor : Colors.grey,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the messages list widget.
  Widget _buildMessagesList(
    ThemeData theme,
    ColorScheme colorScheme,
    ChatState chatState,
  ) {
    final messages = chatState.messages;

    if (messages.isEmpty) {
      return _buildEmptyState(colorScheme, chatState);
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[messages.length - 1 - index];

        return MessageBubble(
          message: msg,
          currentUserNickname:
              chatState.nickname.isEmpty ? 'You' : chatState.nickname,
          onNicknameTap: () {
            // Insert mention into input when nickname is tapped
            final mention = '@${msg.recipientNickname ?? msg.sender}';
            setState(() {
              if (_inputText.isEmpty) {
                _inputText = '$mention ';
              } else {
                _inputText = '$_inputText $mention ';
              }
            });
          },
          onLongPress: () {
            // Show message options
            _showMessageOptions(msg);
          },
        );
      },
    );
  }

  /// Builds the empty state when no messages exist.
  Widget _buildEmptyState(ColorScheme colorScheme, ChatState chatState) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            chatState.selection.isPrivateChat
                ? 'Private chat with ${chatState.peers.where((p) => p.id == chatState.selection.selectedPeerId).map((p) => p.name).firstOrNull ?? 'peer'}'
                : chatState.selection.selectedChannel != null
                    ? 'Channel #${chatState.selection.selectedChannel}'
                    : 'Start a conversation with nearby devices',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.primary.withOpacity(0.7),
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Builds the debug messages panel showing ALL messages in state.
  /// Only visible when verbose logging is enabled in debug settings.
  Widget _buildDebugMessagesPanel(ChatState chatState, ColorScheme colorScheme) {
    final messages = chatState.messages;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        border: Border(
          bottom: BorderSide(color: Colors.amber.withOpacity(0.5), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with toggle
          GestureDetector(
            onTap: () {
              setState(() {
                _debugPanelExpanded = !_debugPanelExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: Colors.amber.withOpacity(0.2),
              child: Row(
                children: [
                  Icon(
                    _debugPanelExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: Colors.amber,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '🐛 DEBUG: ${messages.length} messages in state',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'tap to ${_debugPanelExpanded ? 'collapse' : 'expand'}',
                    style: TextStyle(
                      color: Colors.amber.withOpacity(0.6),
                      fontFamily: 'monospace',
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable content
          if (_debugPanelExpanded)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: messages.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'No messages in state',
                        style: TextStyle(
                          color: Colors.grey,
                          fontFamily: 'monospace',
                          fontSize: 10,
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMyMessage =
                            msg.senderPeerID == chatState.nickname ||
                                msg.sender == chatState.nickname;

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.withOpacity(0.2),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Message ID and sender
                              Row(
                                children: [
                                  Text(
                                    '#$index',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontFamily: 'monospace',
                                      fontSize: 9,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'ID: ${msg.id}',
                                      style: TextStyle(
                                        color: isMyMessage
                                            ? Colors.cyan
                                            : Colors.green,
                                        fontFamily: 'monospace',
                                        fontSize: 9,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              // Sender info
                              Row(
                                children: [
                                  Text(
                                    'sender: ',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontFamily: 'monospace',
                                      fontSize: 9,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '"${msg.sender}" (peerID: ${msg.senderPeerID ?? "null"})',
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontFamily: 'monospace',
                                        fontSize: 9,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              // Content preview
                              Row(
                                children: [
                                  Text(
                                    'content: ',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontFamily: 'monospace',
                                      fontSize: 9,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '"${msg.content.length > 50 ? '${msg.content.substring(0, 50)}...' : msg.content}"',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'monospace',
                                        fontSize: 9,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              // Channel if present
                              if (msg.channel != null)
                                Text(
                                  'channel: ${msg.channel}',
                                  style: TextStyle(
                                    color: Colors.purple.shade300,
                                    fontFamily: 'monospace',
                                    fontSize: 9,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }

  /// Shows message options dialog when a message is long-pressed.
  void _showMessageOptions(BitchatMessage message) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colorScheme.surface,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.reply, color: colorScheme.primary),
                title: Text(
                  'Reply',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontFamily: 'monospace',
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  // TODO: Implement reply functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reply coming soon!')),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.copy, color: colorScheme.primary),
                title: Text(
                  'Copy',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontFamily: 'monospace',
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  Clipboard.setData(ClipboardData(text: message.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message copied')),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: colorScheme.error),
                title: Text(
                  'Delete',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontFamily: 'monospace',
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  // TODO: Implement delete functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Delete coming soon!')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

}
