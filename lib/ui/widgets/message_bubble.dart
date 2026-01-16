import 'package:flutter/material.dart';

import 'package:bitchat/data/models/bitchat_message.dart';
import 'package:bitchat/ui/theme/bitchat_colors.dart';
import 'package:bitchat/ui/theme/bitchat_theme.dart';
import 'package:bitchat/ui/theme/bitchat_typography.dart';
import 'package:bitchat/ui/utils/chat_ui_utils.dart';

/// Widget that displays a single chat message in IRC-style inline format.
/// Format: <@nickname#hash> message content [HH:mm:ss] ⛨Nb
/// Matches Android implementation for cross-platform parity.
class MessageBubble extends StatelessWidget {
  /// The message to display
  final BitchatMessage message;

  /// Nickname of the current user to distinguish sent vs received messages
  final String currentUserNickname;

  /// Peer ID for color generation (defaults to sender if not provided)
  final String? peerID;

  /// RSSI signal strength (optional, displays as icon if provided)
  final int? rssi;

  /// Callback when sender nickname is tapped
  final VoidCallback? onNicknameTap;

  /// Callback when message is long pressed
  final VoidCallback? onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    required this.currentUserNickname,
    this.peerID,
    this.rssi,
    this.onNicknameTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = BitchatTheme.isDarkTheme(context);
    final isOwnMessage = message.sender == currentUserNickname;

    // System messages use different formatting
    if (message.type == BitchatMessageType.Message && _isSystemMessage) {
      return _buildSystemMessage(context, colorScheme);
    }

    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        child: RichText(
          text: TextSpan(
            style: BitchatTypography.messageContentStyle(colorScheme),
            children: _buildIrcMessageSpans(
                context, colorScheme, isDark, isOwnMessage),
          ),
        ),
      ),
    );
  }

  bool get _isSystemMessage {
    // System messages are typically marked or have specific content patterns
    return message.sender == 'system' || message.sender.isEmpty;
  }

  /// Builds the IRC-style message: <@nickname#hash> content [HH:mm:ss]
  List<InlineSpan> _buildIrcMessageSpans(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
    bool isOwnMessage,
  ) {
    final spans = <InlineSpan>[];

    // Determine peer color
    final Color peerColor;
    if (isOwnMessage) {
      peerColor = BitchatColors.selfMessageColor; // Orange for self
    } else {
      final seed = ChatUiUtils.seedForPeer(
        peerID ?? message.senderPeerID ?? message.sender,
        sender: message.sender,
      );
      peerColor = ChatUiUtils.colorForPeerSeed(seed, isDark: isDark);
    }

    // Split nickname into base and hash suffix
    final (base, suffix) = ChatUiUtils.splitSuffix(message.sender);
    final truncatedBase = ChatUiUtils.truncateNickname(base);

    // 1. Opening bracket with @
    spans.add(TextSpan(
      text: '<@',
      style: BitchatTypography.senderNicknameStyle(peerColor),
    ));

    // 2. Nickname (clickable if callback provided)
    if (onNicknameTap != null && !isOwnMessage) {
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          onTap: onNicknameTap,
          child: Text(
            truncatedBase,
            style: BitchatTypography.senderNicknameStyle(peerColor).copyWith(
              decoration: TextDecoration.underline,
              decorationColor: peerColor.withOpacity(0.5),
            ),
          ),
        ),
      ));
    } else {
      spans.add(TextSpan(
        text: truncatedBase,
        style: BitchatTypography.senderNicknameStyle(peerColor),
      ));
    }

    // 3. Hash suffix (lighter color)
    if (suffix.isNotEmpty) {
      spans.add(TextSpan(
        text: suffix,
        style: BitchatTypography.hashSuffixStyle(peerColor),
      ));
    }

    // 4. Closing bracket
    spans.add(TextSpan(
      text: '> ',
      style: BitchatTypography.senderNicknameStyle(peerColor),
    ));

    // 5. Message content with mentions highlighted
    spans.addAll(_buildContentSpans(colorScheme, peerColor, isDark));

    // 6. Timestamp
    final timeStr = ' [${ChatUiUtils.formatTimestamp(message.timestamp)}]';
    spans.add(TextSpan(
      text: timeStr,
      style: BitchatTypography.timestampStyle(colorScheme),
    ));

    // 7. Delivery status (for own messages)
    if (isOwnMessage && message.deliveryStatus != null) {
      spans.add(_buildDeliveryStatusSpan(colorScheme));
    }

    // 8. RSSI indicator (if provided)
    if (rssi != null) {
      spans.add(_buildRssiSpan());
    }

    // 9. PoW badge (if present)
    if (message.powDifficulty != null && message.powDifficulty! > 0) {
      spans.add(TextSpan(
        text: ' \u26E8${message.powDifficulty}b',
        style: BitchatTypography.timestampStyle(colorScheme),
      ));
    }

    return spans;
  }

  /// Builds content spans with mention highlighting.
  List<TextSpan> _buildContentSpans(
      ColorScheme colorScheme, Color peerColor, bool isDark) {
    final content = message.content;
    final spans = <TextSpan>[];

    // Regex to find mentions (@username) and channels (#channel)
    final mentionPattern = RegExp(r'(@[a-zA-Z0-9_#]+)');
    final channelPattern = RegExp(r'(#[a-zA-Z0-9_]+)');

    int currentIndex = 0;
    final allMatches = [
      ...mentionPattern.allMatches(content),
      ...channelPattern.allMatches(content),
    ];

    // Sort matches by start index
    allMatches.sort((a, b) => a.start.compareTo(b.start));

    for (final match in allMatches) {
      // Skip overlapping matches
      if (match.start < currentIndex) continue;

      // Add text before the match
      if (match.start > currentIndex) {
        spans.add(TextSpan(
          text: content.substring(currentIndex, match.start),
          style: TextStyle(color: peerColor),
        ));
      }

      // Style the matched text
      final matchedText = match.group(0)!;
      if (matchedText.startsWith('@')) {
        // Check if it's a mention to self
        final isSelfMention = matchedText
            .toLowerCase()
            .contains(currentUserNickname.toLowerCase());

        // Get color for mentioned peer
        final mentionColor = isSelfMention
            ? BitchatColors.selfMessageColor
            : ChatUiUtils.colorForPeerSeed(matchedText, isDark: isDark);

        spans.add(TextSpan(
          text: matchedText,
          style: TextStyle(
            color: mentionColor,
            fontWeight: FontWeight.bold,
          ),
        ));
      } else if (matchedText.startsWith('#')) {
        // Channel style - use link color
        spans.add(TextSpan(
          text: matchedText,
          style: TextStyle(
            color: BitchatColors.linkColor,
            fontWeight: FontWeight.w600,
          ),
        ));
      }

      currentIndex = match.end;
    }

    // Add remaining text
    if (currentIndex < content.length) {
      spans.add(TextSpan(
        text: content.substring(currentIndex),
        style: TextStyle(color: peerColor),
      ));
    }

    // If no matches found, return single span
    if (spans.isEmpty) {
      spans.add(TextSpan(
        text: content,
        style: TextStyle(color: peerColor),
      ));
    }

    return spans;
  }

  /// Builds delivery status span for own messages.
  TextSpan _buildDeliveryStatusSpan(ColorScheme colorScheme) {
    final status = message.deliveryStatus;
    if (status == null) return const TextSpan();

    late String statusStr;
    late Color statusColor;

    status.map(
      sending: (_) {
        statusStr = ' \u22EF'; // ⋯
        statusColor = colorScheme.primary.withOpacity(0.6);
      },
      sent: (_) {
        statusStr = ' \u25EF'; // ◯
        statusColor = colorScheme.primary.withOpacity(0.6);
      },
      delivered: (_) {
        statusStr = ' \u2713'; // ✓
        statusColor = colorScheme.primary.withOpacity(0.8);
      },
      read: (_) {
        statusStr = ' \u2713\u2713'; // ✓✓
        statusColor = BitchatColors.linkColor;
      },
      failed: (_) {
        statusStr = ' \u2717'; // ✗
        statusColor = colorScheme.error.withOpacity(0.8);
      },
      partiallyDelivered: (_) {
        statusStr = ' \u2713'; // ✓
        statusColor = colorScheme.primary.withOpacity(0.6);
      },
    );

    return TextSpan(
      text: statusStr,
      style: TextStyle(
        color: statusColor,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  /// Builds RSSI indicator span.
  TextSpan _buildRssiSpan() {
    if (rssi == null) return const TextSpan();

    final rssiColor = BitchatColors.colorForRssi(rssi!);
    return TextSpan(
      text: ' \u26E8', // ⛨ shield symbol
      style: TextStyle(color: rssiColor),
    );
  }

  /// Builds a system message in format: * content * [HH:mm:ss]
  Widget _buildSystemMessage(BuildContext context, ColorScheme colorScheme) {
    final timeStr = ChatUiUtils.formatTimestamp(message.timestamp);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Text(
        '* ${message.content} * [$timeStr]',
        style: BitchatTypography.systemMessageStyle(colorScheme),
        textAlign: TextAlign.center,
      ),
    );
  }
}
