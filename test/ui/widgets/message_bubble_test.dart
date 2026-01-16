import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitchat/data/models/bitchat_message.dart';
import 'package:bitchat/ui/widgets/message_bubble.dart';

void main() {
  group('MessageBubble Widget Tests', () {
    testWidgets('displays message content correctly', (WidgetTester tester) async {
      final message = BitchatMessage(
        id: '1',
        sender: 'Alice',
        content: 'Hello, world!',
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: message,
              currentUserNickname: 'Bob',
            ),
          ),
        ),
      );

      expect(find.text('Hello, world!'), findsOneWidget);
      expect(find.text('@Alice'), findsOneWidget);
      expect(find.text('12:00:00'), findsOneWidget);
    });

    testWidgets('aligns own messages to the right', (WidgetTester tester) async {
      final message = BitchatMessage(
        id: '1',
        sender: 'Bob',
        content: 'My message',
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: message,
              currentUserNickname: 'Bob',
            ),
          ),
        ),
      );

      final alignWidget = tester.widget<Align>(find.byType(Align));
      expect(alignWidget.alignment, Alignment.centerRight);
    });

    testWidgets('aligns received messages to the left', (WidgetTester tester) async {
      final message = BitchatMessage(
        id: '1',
        sender: 'Alice',
        content: 'Their message',
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: message,
              currentUserNickname: 'Bob',
            ),
          ),
        ),
      );

      final alignWidget = tester.widget<Align>(find.byType(Align));
      expect(alignWidget.alignment, Alignment.centerLeft);
    });

    testWidgets('displays delivery status for own messages', (WidgetTester tester) async {
      final message = BitchatMessage(
        id: '1',
        sender: 'Bob',
        content: 'Sent message',
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
        deliveryStatus: const DeliveryStatus.sent(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: message,
              currentUserNickname: 'Bob',
            ),
          ),
        ),
      );

      expect(find.text('Sent'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('displays read status with green color', (WidgetTester tester) async {
      final message = BitchatMessage(
        id: '1',
        sender: 'Bob',
        content: 'Read message',
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
        deliveryStatus: DeliveryStatus.read(
          by: 'Alice',
          at: DateTime(2024, 1, 1, 12, 0, 1),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: message,
              currentUserNickname: 'Bob',
            ),
          ),
        ),
      );

      expect(find.text('Read'), findsOneWidget);
      expect(find.byIcon(Icons.done_all), findsOneWidget);
    });

    testWidgets('triggers onNicknameTap callback when tapped', (WidgetTester tester) async {
      var callbackCalled = false;
      final message = BitchatMessage(
        id: '1',
        sender: 'Alice',
        content: 'Hello',
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: message,
              currentUserNickname: 'Bob',
              onNicknameTap: () {
                callbackCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('@Alice'));
      expect(callbackCalled, isTrue);
    });

    testWidgets('triggers onLongPress callback when long pressed', (WidgetTester tester) async {
      var callbackCalled = false;
      final message = BitchatMessage(
        id: '1',
        sender: 'Alice',
        content: 'Hello',
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: message,
              currentUserNickname: 'Bob',
              onLongPress: () {
                callbackCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.longPress(find.byType(Container).first);
      expect(callbackCalled, isTrue);
    });

    testWidgets('displays sender as You for own messages', (WidgetTester tester) async {
      final message = BitchatMessage(
        id: '1',
        sender: 'Bob',
        content: 'My message',
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: message,
              currentUserNickname: 'Bob',
            ),
          ),
        ),
      );

      expect(find.text('You'), findsOneWidget);
      expect(find.text('@Bob'), findsNothing);
    });
  });
}
