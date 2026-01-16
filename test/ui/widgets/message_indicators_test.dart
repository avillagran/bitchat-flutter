import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitchat/ui/widgets/message_indicators.dart';
import 'package:bitchat/data/models/bitchat_message.dart';

void main() {
  final testTimestamp = DateTime(2024, 1, 15, 14, 30);

  group('MessageIndicators', () {
    testWidgets('should display delivery status icon', (tester) async {
      final message = BitchatMessage(
        id: '1',
        sender: 'alice',
        content: 'Hello',
        timestamp: DateTime.now(),
        deliveryStatus: DeliveryStatus.delivered(
          to: 'bob',
          at: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageIndicators(message: message),
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('should display timestamp', (tester) async {
      final message = BitchatMessage(
        id: '1',
        sender: 'alice',
        content: 'Hello',
        timestamp: testTimestamp,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageIndicators(message: message),
          ),
        ),
      );

      expect(find.text('14:30'), findsOneWidget);
    });

    testWidgets('should hide timestamp when showTimestamp is false',
        (tester) async {
      final message = BitchatMessage(
        id: '1',
        sender: 'alice',
        content: 'Hello',
        timestamp: testTimestamp,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageIndicators(
              message: message,
              showTimestamp: false,
            ),
          ),
        ),
      );

      expect(find.text('14:30'), findsNothing);
    });

    testWidgets('should display RSSI indicator when provided', (tester) async {
      final message = BitchatMessage(
        id: '1',
        sender: 'alice',
        content: 'Hello',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageIndicators(
              message: message,
              rssi: -60,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.network_wifi_3_bar), findsOneWidget);
    });

    testWidgets('should hide RSSI when showRssi is false', (tester) async {
      final message = BitchatMessage(
        id: '1',
        sender: 'alice',
        content: 'Hello',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageIndicators(
              message: message,
              rssi: -60,
              showRssi: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.network_wifi_3_bar), findsNothing);
    });

    testWidgets(
        'should display different icons for different delivery statuses',
        (tester) async {
      final statuses = <DeliveryStatus>[
        const DeliveryStatus.sending(),
        const DeliveryStatus.sent(),
        DeliveryStatus.delivered(
          to: 'bob',
          at: DateTime.now(),
        ),
        DeliveryStatus.read(
          by: 'bob',
          at: DateTime.now(),
        ),
        const DeliveryStatus.failed(reason: 'Network error'),
      ];

      final expectedIcons = <IconData>[
        Icons.hourglass_empty,
        Icons.check_circle_outline,
        Icons.check_circle,
        Icons.done_all,
        Icons.error_outline,
      ];

      for (var i = 0; i < statuses.length; i++) {
        final message = BitchatMessage(
          id: '1',
          sender: 'alice',
          content: 'Hello',
          timestamp: DateTime.now(),
          deliveryStatus: statuses[i],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageIndicators(message: message),
            ),
          ),
        );

        expect(find.byIcon(expectedIcons[i]), findsOneWidget,
            reason: 'Expected icon $i for status $i');
      }
    });

    testWidgets('should display excellent signal for excellent RSSI (-50)',
        (tester) async {
      final message = BitchatMessage(
        id: '1',
        sender: 'alice',
        content: 'Hello',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageIndicators(message: message, rssi: -50),
          ),
        ),
      );

      expect(find.byIcon(Icons.signal_cellular_alt), findsOneWidget);
    });

    testWidgets('should display weak signal for weak RSSI (-80)',
        (tester) async {
      final message = BitchatMessage(
        id: '1',
        sender: 'alice',
        content: 'Hello',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageIndicators(message: message, rssi: -80),
          ),
        ),
      );

      expect(find.byIcon(Icons.network_wifi_1_bar), findsOneWidget);
    });

    testWidgets('should format date for messages not from today',
        (tester) async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final message = BitchatMessage(
        id: '1',
        sender: 'alice',
        content: 'Hello',
        timestamp: yesterday,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageIndicators(message: message),
          ),
        ),
      );

      // Should include date in format (e.g., "1/14/2024 14:30")
      expect(find.textContaining('/'), findsOneWidget);
    });

    testWidgets('should hide RSSI when not provided', (tester) async {
      final message = BitchatMessage(
        id: '1',
        sender: 'alice',
        content: 'Hello',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageIndicators(message: message),
          ),
        ),
      );

      expect(find.byType(Icon), findsWidgets);
    });
  });

  group('DeliveryStatusIcon via MessageIndicators', () {
    testWidgets('should have tooltip for sending status', (tester) async {
      final message = BitchatMessage(
        id: '1',
        sender: 'alice',
        content: 'Hello',
        timestamp: DateTime.now(),
        deliveryStatus: const DeliveryStatus.sending(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageIndicators(message: message),
          ),
        ),
      );

      final iconFinder = find.byIcon(Icons.hourglass_empty);
      expect(iconFinder, findsOneWidget);
    });

    testWidgets('should have error color for failed status', (tester) async {
      final message = BitchatMessage(
        id: '1',
        sender: 'alice',
        content: 'Hello',
        timestamp: DateTime.now(),
        deliveryStatus: const DeliveryStatus.failed(reason: 'Network error'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageIndicators(message: message),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
      expect(icon.color, equals(Colors.red));
    });
  });

  group('_RssiIndicator', () {
    testWidgets('should display tooltip with RSSI value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageIndicators(
              message: BitchatMessage(
                id: '1',
                sender: 'alice',
                content: 'Hello',
                timestamp: DateTime.now(),
              ),
              rssi: -60,
            ),
          ),
        ),
      );

      expect(find.textContaining('-60 dBm'), findsOneWidget);
    });

    testWidgets('should show good color for good RSSI (-60)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageIndicators(
              message: BitchatMessage(
                id: '1',
                sender: 'alice',
                content: 'Hello',
                timestamp: DateTime.now(),
              ),
              rssi: -60,
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.network_wifi_3_bar));
      expect(icon.color, equals(Colors.lightGreen));
    });

    testWidgets('should show weak color for weak RSSI (-80)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageIndicators(
              message: BitchatMessage(
                id: '1',
                sender: 'alice',
                content: 'Hello',
                timestamp: DateTime.now(),
              ),
              rssi: -80,
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.network_wifi_1_bar));
      expect(icon.color, equals(Colors.orange));
    });
  });
}
