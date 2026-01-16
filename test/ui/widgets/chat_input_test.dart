import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitchat/ui/widgets/chat_input.dart';

void main() {
  group('ChatInput Widget Tests', () {
    testWidgets('displays text field with correct hint', (WidgetTester tester) async {
      String inputText = '';
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatInput(
                text: inputText,
                onTextChanged: (text) => inputText = text,
                onSend: () {},
                onChannelChanged: (_) {},
                onMentionSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Broadcast to mesh'), findsOneWidget);
    });

    testWidgets('shows channel selector hint when channel selected', (WidgetTester tester) async {
      String inputText = '';
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatInput(
                text: inputText,
                selectedChannel: 'general',
                onTextChanged: (text) => inputText = text,
                onSend: () {},
                onChannelChanged: (_) {},
                onMentionSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Message #general'), findsOneWidget);
    });

    testWidgets('calls onTextChanged when text is entered', (WidgetTester tester) async {
      String inputText = '';
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatInput(
                text: inputText,
                onTextChanged: (text) => inputText = text,
                onSend: () {},
                onChannelChanged: (_) {},
                onMentionSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Hello');
      expect(inputText, 'Hello');
    });

    testWidgets('calls onSend when send button is pressed with text', (WidgetTester tester) async {
      var sendCalled = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatInput(
                text: 'Test message',
                onTextChanged: (_) {},
                onSend: () {
                  sendCalled = true;
                },
                onChannelChanged: (_) {},
                onMentionSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      expect(sendCalled, isTrue);
    });

    testWidgets('does not call onSend when send button is pressed with empty text', (WidgetTester tester) async {
      var sendCalled = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatInput(
                text: '',
                onTextChanged: (_) {},
                onSend: () {
                  sendCalled = true;
                },
                onChannelChanged: (_) {},
                onMentionSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      expect(sendCalled, isFalse);
    });

    testWidgets('displays mention suggestions when showMentionSuggestions is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatInput(
                text: '@',
                onTextChanged: (_) {},
                onSend: () {},
                onChannelChanged: (_) {},
                showMentionSuggestions: true,
                mentionSuggestions: ['Alice', 'Bob', 'Charlie'],
                onMentionSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);
    });

    testWidgets('calls onMentionSelected when suggestion is tapped', (WidgetTester tester) async {
      String selectedMention = '';
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatInput(
                text: '@',
                onTextChanged: (_) {},
                onSend: () {},
                onChannelChanged: (_) {},
                showMentionSuggestions: true,
                mentionSuggestions: ['Alice'],
                onMentionSelected: (mention) {
                  selectedMention = mention;
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Alice'));
      expect(selectedMention, 'Alice');
    });

    testWidgets('displays available channels', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatInput(
                text: '',
                onTextChanged: (_) {},
                onSend: () {},
                availableChannels: ['general', 'random'],
                onChannelChanged: (_) {},
                onMentionSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('#general'), findsOneWidget);
      expect(find.text('#random'), findsOneWidget);
    });

    testWidgets('shows channel indicator with selected channel', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatInput(
                text: '',
                selectedChannel: 'general',
                onTextChanged: (_) {},
                onSend: () {},
                availableChannels: ['general'],
                onChannelChanged: (_) {},
                onMentionSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('#general'), findsWidgets);
    });

    testWidgets('shows cloud icon when store-forward is enabled', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatInput(
                text: 'Test',
                onTextChanged: (_) {},
                onSend: () {},
                isStoreForwardEnabled: true,
                onChannelChanged: (_) {},
                onMentionSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
    });

    testWidgets('shows send icon when store-forward is disabled', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatInput(
                text: 'Test',
                onTextChanged: (_) {},
                onSend: () {},
                isStoreForwardEnabled: false,
                onChannelChanged: (_) {},
                onMentionSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.send), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload), findsNothing);
    });
  });
}
