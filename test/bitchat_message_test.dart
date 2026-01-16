import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitchat/data/models/bitchat_message.dart';

void main() {
  group('BitchatMessage Binary Serialization', () {
    test('should encode and decode a simple message correctly', () {
      final msg = BitchatMessage(
        id: 'test-id',
        sender: 'alice',
        content: 'hello mesh',
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(1705334400000), // 2024-01-15
      );

      final encoded = BitchatMessage.toBinaryPayload(msg);
      expect(encoded, isNotNull);

      final decoded = BitchatMessage.fromBinaryPayload(encoded!);
      expect(decoded, isNotNull);
      expect(decoded!.id, msg.id);
      expect(decoded.sender, msg.sender);
      expect(decoded.content, msg.content);
      expect(decoded.timestamp.millisecondsSinceEpoch,
          msg.timestamp.millisecondsSinceEpoch);
    });

    test('should handle optional fields correctly', () {
      final msg = BitchatMessage(
        id: 'opt-id',
        sender: 'bob',
        content: 'with options',
        timestamp: DateTime.now(),
        isPrivate: true,
        recipientNickname: 'alice_nick',
        channel: 'general',
        mentions: ['alice', 'charlie'],
      );

      final encoded = BitchatMessage.toBinaryPayload(msg);
      final decoded = BitchatMessage.fromBinaryPayload(encoded!);

      expect(decoded!.isPrivate, isTrue);
      expect(decoded.recipientNickname, 'alice_nick');
      expect(decoded.channel, 'general');
      expect(decoded.mentions, containsAll(['alice', 'charlie']));
    });
  });
}
