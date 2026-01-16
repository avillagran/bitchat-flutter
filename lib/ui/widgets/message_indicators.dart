import 'package:flutter/material.dart';
import 'package:bitchat/data/models/bitchat_message.dart';
import 'package:intl/intl.dart';

/// Widget displaying message delivery and read status indicators.
///
/// Shows:
/// - Delivery status icon (sending, sent, delivered, read, failed)
/// - Timestamp with timezone
/// - RSSI signal strength indicator (when available)
///
/// Used within message bubbles to provide feedback on message transmission status.
class MessageIndicators extends StatelessWidget {
  /// The message to display indicators for.
  final BitchatMessage message;

  /// RSSI value in dBm (Received Signal Strength Indicator).
  /// If null, RSSI indicator is not shown.
  final int? rssi;

  /// Whether to show the timestamp.
  /// Defaults to true.
  final bool showTimestamp;

  /// Whether to show the RSSI indicator.
  /// Defaults to true.
  final bool showRssi;

  const MessageIndicators({
    super.key,
    required this.message,
    this.rssi,
    this.showTimestamp = true,
    this.showRssi = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.deliveryStatus != null) ...[
            _DeliveryStatusIcon(status: message.deliveryStatus!),
            const SizedBox(width: 4),
          ],
          if (showTimestamp) ...[
            Text(
              _formatTimestamp(message.timestamp),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 4),
          ],
          if (showRssi && rssi != null) ...[
            _RssiIndicator(rssi: rssi!),
          ],
        ],
      ),
    );
  }

  /// Format timestamp with timezone.
  ///
  /// Returns time in HH:mm format if the message is from today,
  /// otherwise includes the date.
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      return DateFormat.Hm().format(timestamp);
    } else {
      return DateFormat.yMd().add_Hm().format(timestamp);
    }
  }
}

/// Widget displaying delivery status icon for a message.
class _DeliveryStatusIcon extends StatelessWidget {
  final DeliveryStatus status;

  const _DeliveryStatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    IconData icon = Icons.help_outline;
    Color color = Colors.grey;
    String tooltip = 'Unknown status';

    status.when(
      sending: () {
        icon = Icons.hourglass_empty;
        color = theme.colorScheme.primary.withOpacity(0.6);
        tooltip = 'Sending...';
      },
      sent: () {
        icon = Icons.check_circle_outline;
        color = theme.colorScheme.primary.withOpacity(0.6);
        tooltip = 'Sent';
      },
      delivered: (to, at) {
        icon = Icons.check_circle;
        color = theme.colorScheme.primary.withOpacity(0.8);
        tooltip = 'Delivered to $to';
      },
      read: (by, at) {
        icon = Icons.done_all;
        color = theme.colorScheme.primary;
        tooltip = 'Read by $by';
      },
      failed: (reason) {
        icon = Icons.error_outline;
        color = theme.colorScheme.error;
        tooltip = 'Failed: $reason';
      },
      partiallyDelivered: (reached, total) {
        icon = Icons.warning_amber_outlined;
        color = theme.colorScheme.tertiary;
        tooltip = 'Partially delivered: $reached/$total';
      },
    );

    return Tooltip(
      message: tooltip,
      child: Icon(
        icon,
        size: 14,
        color: color,
      ),
    );
  }
}

/// Widget displaying RSSI signal strength indicator.
///
/// RSSI (Received Signal Strength Indicator) is measured in dBm.
/// Higher values (closer to 0) indicate stronger signal.
/// Typical values: -50 dBm (excellent) to -100 dBm (poor).
class _RssiIndicator extends StatelessWidget {
  final int rssi;

  const _RssiIndicator({required this.rssi});

  @override
  Widget build(BuildContext context) {
    // Convert RSSI to signal bars and color
    final data = _getRssiData();

    return Tooltip(
      message: 'Signal strength: $rssi dBm (${data.label})',
      child: Icon(
        data.icon,
        size: 14,
        color: data.color,
      ),
    );
  }

  /// Get icon, color, and label for RSSI value.
  _RssiData _getRssiData() {
    // RSSI thresholds (in dBm)
    if (rssi >= -50) {
      // Excellent signal - 4 bars
      return _RssiData(
        Icons.signal_cellular_alt,
        Colors.green,
        'Excellent',
      );
    } else if (rssi >= -60) {
      // Good signal - 3 bars
      return _RssiData(
        Icons.network_wifi_3_bar,
        Colors.lightGreen,
        'Good',
      );
    } else if (rssi >= -70) {
      // Fair signal - 2 bars
      return _RssiData(
        Icons.network_wifi_2_bar,
        Colors.yellow,
        'Fair',
      );
    } else if (rssi >= -80) {
      // Weak signal - 1 bar
      return _RssiData(
        Icons.network_wifi_1_bar,
        Colors.orange,
        'Weak',
      );
    } else {
      // Very weak signal - 0 bars
      return _RssiData(
        Icons.signal_wifi_0_bar,
        Colors.red,
        'Very weak',
      );
    }
  }
}

/// Data class for RSSI indicator information.
class _RssiData {
  final IconData icon;
  final Color color;
  final String label;

  _RssiData(this.icon, this.color, this.label);
}
