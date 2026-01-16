import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bitchat/ui/theme/bitchat_colors.dart';

/// Utility functions for chat UI styling and formatting.
/// Matches Android implementation for cross-platform parity.
class ChatUiUtils {
  ChatUiUtils._();

  // ==========================================================================
  // DJB2 HASH ALGORITHM FOR PEER COLORS
  // ==========================================================================

  /// Generates a color for a peer based on their seed string using djb2 hash.
  /// Matches iOS/Android implementation for consistent colors across platforms.
  static Color colorForPeerSeed(String seed, {required bool isDark}) {
    // djb2 hash algorithm
    int hash = 5381;
    for (final byte in utf8.encode(seed)) {
      hash = ((hash << 5) + hash) + byte;
      hash = hash & 0xFFFFFFFF; // Keep as 32-bit unsigned
    }

    double hue = (hash % 360) / 360.0;

    // Avoid orange (~30 degrees) reserved for self messages
    const orangeHue = 30.0 / 360.0;
    if ((hue - orangeHue).abs() < 0.05) {
      hue = (hue + 0.12) % 1.0;
    }

    final saturation = isDark ? 0.50 : 0.70;
    final brightness = isDark ? 0.85 : 0.35;

    return HSVColor.fromAHSV(1.0, hue * 360, saturation, brightness).toColor();
  }

  /// Gets the seed string for a peer based on their type.
  /// Priority: nostr > noise stable (64 chars) > noise ephemeral (16 chars) > sender
  static String seedForPeer(String peerID, {String? sender}) {
    if (peerID.startsWith('nostr:') || peerID.startsWith('npub')) {
      return 'nostr:${peerID.toLowerCase()}';
    }
    // Stable Noise key (64 char hex = 32 bytes)
    if (peerID.length == 64 && _isHexString(peerID)) {
      return 'noise:${peerID.toLowerCase()}';
    }
    // Ephemeral peer ID (16 chars)
    if (peerID.length == 16) {
      return 'noise:${peerID.toLowerCase()}';
    }
    // Fallback to sender or peerID
    return (sender ?? peerID).toLowerCase();
  }

  static bool _isHexString(String s) {
    return s.split('').every((c) => '0123456789abcdefABCDEF'.contains(c));
  }

  // ==========================================================================
  // NICKNAME HANDLING
  // ==========================================================================

  /// Maximum length for nickname display.
  static const int maxNicknameLength = 15;

  /// Splits a nickname into base and hash suffix.
  /// Returns (base, suffix) where suffix is "#XXXX" format or empty.
  static (String base, String suffix) splitSuffix(String name) {
    if (name.length < 5) return (name, '');

    final suffix = name.substring(name.length - 5);
    if (suffix.startsWith('#') &&
        suffix
            .substring(1)
            .split('')
            .every((c) => '0123456789abcdefABCDEF'.contains(c))) {
      final base = name.substring(0, name.length - 5);
      return (base, suffix);
    }

    return (name, '');
  }

  /// Truncates a nickname to the maximum length.
  static String truncateNickname(String name,
      {int maxLen = maxNicknameLength}) {
    return name.length <= maxLen ? name : name.substring(0, maxLen);
  }

  // ==========================================================================
  // TIMESTAMP FORMATTING
  // ==========================================================================

  /// Formats a timestamp for display.
  /// - Same day: HH:mm:ss
  /// - Same year: MMM d, HH:mm
  /// - Different year: MMM d yyyy, HH:mm
  static String formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();

    if (_isSameDay(timestamp, now)) {
      return DateFormat.Hms().format(timestamp); // HH:mm:ss
    } else if (timestamp.year == now.year) {
      return DateFormat('MMM d, HH:mm').format(timestamp);
    } else {
      return DateFormat('MMM d yyyy, HH:mm').format(timestamp);
    }
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // ==========================================================================
  // IRC-STYLE MESSAGE FORMATTING
  // ==========================================================================

  /// Formats a message in IRC style: <@nickname#hash> content [HH:mm:ss]
  static String formatIrcMessage({
    required String sender,
    required String content,
    required DateTime timestamp,
  }) {
    final (base, suffix) = splitSuffix(sender);
    final truncatedBase = truncateNickname(base);
    final time = DateFormat.Hms().format(timestamp);

    return '<@$truncatedBase$suffix> $content [$time]';
  }

  /// Formats a system message: * content * [HH:mm:ss]
  static String formatSystemMessage(String content, DateTime timestamp) {
    final time = DateFormat.Hms().format(timestamp);
    return '* $content * [$time]';
  }

  // ==========================================================================
  // DELIVERY STATUS FORMATTING
  // ==========================================================================

  /// Gets the display string for a delivery status.
  static String deliveryStatusString(DeliveryStatusType status) {
    switch (status) {
      case DeliveryStatusType.sending:
        return '\u22EF'; // ⋯ (horizontal ellipsis)
      case DeliveryStatusType.sent:
        return '\u25EF'; // ◯ (white circle)
      case DeliveryStatusType.delivered:
        return '\u2713'; // ✓ (check mark)
      case DeliveryStatusType.read:
        return '\u2713\u2713'; // ✓✓ (double check)
      case DeliveryStatusType.failed:
        return '\u2717'; // ✗ (x mark)
      case DeliveryStatusType.partiallyDelivered:
        return '\u2713'; // ✓ (single check)
    }
  }

  /// Gets the color for a delivery status.
  static Color deliveryStatusColor(
      DeliveryStatusType status, ColorScheme colorScheme) {
    switch (status) {
      case DeliveryStatusType.sending:
        return colorScheme.primary.withOpacity(0.6);
      case DeliveryStatusType.sent:
        return colorScheme.primary.withOpacity(0.6);
      case DeliveryStatusType.delivered:
        return colorScheme.primary.withOpacity(0.8);
      case DeliveryStatusType.read:
        return BitchatColors.linkColor; // iOS blue
      case DeliveryStatusType.failed:
        return colorScheme.error.withOpacity(0.8);
      case DeliveryStatusType.partiallyDelivered:
        return colorScheme.primary.withOpacity(0.6);
    }
  }
}

/// Enum for delivery status types (matches DeliveryStatus from models).
enum DeliveryStatusType {
  sending,
  sent,
  delivered,
  read,
  failed,
  partiallyDelivered,
}
