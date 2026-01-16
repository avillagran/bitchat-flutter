import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bitchat/ui/theme/bitchat_theme.dart';
import 'package:bitchat/ui/theme/bitchat_typography.dart';

/// Widget for chat message input with minimal IRC-style design.
/// Matches Android implementation for cross-platform parity.
class ChatInput extends ConsumerStatefulWidget {
  /// Current text in the input field
  final String text;

  /// Callback when text changes
  final ValueChanged<String> onTextChanged;

  /// Callback when send button is pressed
  final VoidCallback onSend;

  /// Currently selected channel (null for mesh broadcast)
  final String? selectedChannel;

  /// List of available channels
  final List<String> availableChannels;

  /// Callback when channel is changed
  final ValueChanged<String?> onChannelChanged;

  /// Whether store-forward is enabled (affects send button icon)
  final bool isStoreForwardEnabled;

  /// Whether to show mention suggestions
  final bool showMentionSuggestions;

  /// List of mention suggestions
  final List<String> mentionSuggestions;

  /// Callback when a mention suggestion is selected
  final ValueChanged<String> onMentionSelected;

  /// Whether to show command suggestions
  final bool showCommandSuggestions;

  /// List of command suggestions
  final List<String> commandSuggestions;

  /// Callback when a command suggestion is selected
  final ValueChanged<String> onCommandSelected;

  const ChatInput({
    super.key,
    required this.text,
    required this.onTextChanged,
    required this.onSend,
    this.selectedChannel,
    this.availableChannels = const [],
    required this.onChannelChanged,
    this.isStoreForwardEnabled = false,
    this.showMentionSuggestions = false,
    this.mentionSuggestions = const [],
    required this.onMentionSelected,
    this.showCommandSuggestions = false,
    this.commandSuggestions = const [],
    required this.onCommandSelected,
  });

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.text);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(ChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != _textController.text) {
      _textController.text = widget.text;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    if (_textController.text.trim().isNotEmpty) {
      widget.onSend();
      _textController.clear();
      widget.onTextChanged('');
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = BitchatTheme.isDarkTheme(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Command suggestions overlay
        if (widget.showCommandSuggestions &&
            widget.commandSuggestions.isNotEmpty)
          _buildCommandSuggestions(colorScheme, isDark),

        // Mention suggestions overlay
        if (widget.showMentionSuggestions &&
            widget.mentionSuggestions.isNotEmpty)
          _buildMentionSuggestions(colorScheme, isDark),

        // Main input row - minimal style
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: colorScheme.primary.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // Channel indicator (minimal)
                if (widget.selectedChannel != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '#${widget.selectedChannel}',
                      style: TextStyle(
                        color: colorScheme.primary.withOpacity(0.7),
                        fontFamily: 'monospace',
                        fontSize: BitchatTypography.baseFontSize - 2,
                      ),
                    ),
                  ),

                // Text input field - minimal, no rounded borders
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    onChanged: widget.onTextChanged,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _handleSend(),
                    decoration: InputDecoration(
                      hintText: widget.selectedChannel != null
                          ? 'Message #${widget.selectedChannel}'
                          : 'Broadcast to mesh',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.4),
                        fontFamily: 'monospace',
                        fontSize: BitchatTypography.baseFontSize,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontFamily: 'monospace',
                      fontSize: BitchatTypography.baseFontSize,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    cursorColor: colorScheme.primary,
                  ),
                ),

                const SizedBox(width: 6),

                // Send button - 30dp, arrow_upward, minimal style
                _buildSendButton(colorScheme),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the send button with minimal IRC-style design.
  /// 30dp size with arrow_upward icon, matching Android.
  Widget _buildSendButton(ColorScheme colorScheme) {
    final hasText = _textController.text.trim().isNotEmpty;
    final canSend = hasText;

    return SizedBox(
      width: 30,
      height: 30,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canSend ? _handleSend : null,
          child: Container(
            decoration: BoxDecoration(
              color: canSend
                  ? colorScheme.primary
                  : colorScheme.primary.withOpacity(0.3),
              // No border radius - square button
            ),
            child: Icon(
              widget.isStoreForwardEnabled
                  ? Icons.cloud_upload
                  : Icons.arrow_upward,
              color: canSend
                  ? colorScheme.onPrimary
                  : colorScheme.onPrimary.withOpacity(0.5),
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the mention suggestions overlay.
  Widget _buildMentionSuggestions(ColorScheme colorScheme, bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: widget.mentionSuggestions.length,
        itemBuilder: (context, index) {
          final suggestion = widget.mentionSuggestions[index];
          return InkWell(
            onTap: () => widget.onMentionSelected(suggestion),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.person, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    '@$suggestion',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: BitchatTypography.baseFontSize,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Builds the command suggestions overlay.
  Widget _buildCommandSuggestions(ColorScheme colorScheme, bool isDark) {
    // Command descriptions
    const commandDescriptions = {
      '/join': 'Join a channel',
      '/msg': 'Send private message',
      '/who': 'List online peers',
      '/block': 'Block a peer',
      '/unblock': 'Unblock a peer',
      '/leave': 'Leave current channel',
      '/clear': 'Clear messages',
    };

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: widget.commandSuggestions.length,
        itemBuilder: (context, index) {
          final command = widget.commandSuggestions[index];
          final description = commandDescriptions[command] ?? '';
          return InkWell(
            onTap: () => widget.onCommandSelected(command),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    _getCommandIcon(command),
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          command,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: BitchatTypography.baseFontSize,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                        if (description.isNotEmpty)
                          Text(
                            description,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: BitchatTypography.baseFontSize - 2,
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Returns an icon for the given command.
  IconData _getCommandIcon(String command) {
    switch (command) {
      case '/join':
        return Icons.login;
      case '/msg':
        return Icons.chat_bubble_outline;
      case '/who':
        return Icons.people_outline;
      case '/block':
        return Icons.block;
      case '/unblock':
        return Icons.check_circle_outline;
      case '/leave':
        return Icons.logout;
      case '/clear':
        return Icons.delete_outline;
      default:
        return Icons.terminal;
    }
  }
}
