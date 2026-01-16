import 'package:flutter_test/flutter_test.dart';
import 'package:bitchat/features/mesh/store_forward_manager.dart';

void main() {
  group('StoreForwardManager', () {
    late StoreForwardManager manager;
    setUp(() => manager = StoreForwardManager());

    test('enqueue and dequeue message', () {
      final msg = StoreForwardMessage(
        id: 'm1',
        payload: 'payload',
        destination: 'd1',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        type: StoreForwardMessageType.outbound,
      );
      manager.enqueueMessage(msg);
      expect(manager.getPendingMessages().length, 1);
      final out = manager.dequeueMessage();
      expect(out?.id, 'm1');
      expect(manager.getPendingMessages(), isEmpty);
    });

    test('removeMessage by id', () {
      final msg = StoreForwardMessage(
        id: 'm2',
        payload: 'payload2',
        destination: 'd2',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        type: StoreForwardMessageType.inbound,
      );
      manager.enqueueMessage(msg);
      final removed = manager.removeMessage('m2');
      expect(removed, true);
      expect(manager.getPendingMessages(), isEmpty);
    });

    test('clearExpired', () {
      final old = StoreForwardMessage(
        id: 'x',
        payload: 'x',
        destination: 'x',
        timestamp: DateTime.now().millisecondsSinceEpoch - 600000,
        type: StoreForwardMessageType.offline,
      );
      manager.enqueueMessage(old);
      final n = manager.clearExpired(expiryMillisAgo: 1000);
      expect(n, 1);
      expect(manager.getPendingMessages(), isEmpty);
    });
  });
}
