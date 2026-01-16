import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:bitchat/features/nostr/nostr_mesh_serializer.dart';
import 'package:bitchat/features/nostr/nostr_event.dart';

void main() {
  group('NostrMeshGateway', () {
    test('TYPE_NOSTR_RELAY_REQUEST header is correct', () {
      expect(NostrMeshSerializer.TYPE_NOSTR_RELAY_REQUEST, equals(0x7E));
    });

    test('TYPE_NOSTR_PLAINTEXT header is correct', () {
      expect(NostrMeshSerializer.TYPE_NOSTR_PLAINTEXT, equals(0x00));
    });

    test('serializeEventForMesh produces valid packet with header', () {
      final event = NostrEvent(
        id: 'abc123',
        pubkey: 'pubkey123',
        createdAt: 1234567890,
        kind: 1,
        tags: [],
        content: 'Hello World',
        sig: 'sig123',
      );

      final serialized = NostrMeshSerializer.serializeEventForMesh(event);
      expect(serialized.length, greaterThanOrEqualTo(5));
      final header = serialized[0];
      expect(
          header == NostrMeshSerializer.TYPE_NOSTR_RELAY_REQUEST ||
              header == NostrMeshSerializer.TYPE_NOSTR_PLAINTEXT,
          isTrue);
    });

    test(
        'serializeEventForMesh and deserializeEventFromMesh are inverse operations',
        () {
      final event = NostrEvent(
        id: 'testid123456789',
        pubkey: 'testpubkey',
        createdAt: 1700000000,
        kind: 1,
        tags: [
          ['nonce', '12345', '8']
        ],
        content: 'Test content for serialization',
        sig: 'testsignature',
      );

      final serialized = NostrMeshSerializer.serializeEventForMesh(event);
      final deserialized =
          NostrMeshSerializer.deserializeEventFromMesh(serialized as Uint8List);
      expect(deserialized, isNotNull);
      final parsedEvent = NostrEvent.fromJsonString(deserialized!);
      expect(parsedEvent, isNotNull);
      expect(parsedEvent!.id, equals(event.id));
      expect(parsedEvent.pubkey, equals(event.pubkey));
      expect(parsedEvent.content, equals(event.content));
      expect(parsedEvent.kind, equals(event.kind));
    });

    test('deserializeEventFromMesh returns null for invalid header', () {
      final invalidPacket = Uint8List.fromList(
          [0x99, 0x00, 0x00, 0x00, 0x05, 0x48, 0x65, 0x6C, 0x6C, 0x6F]);
      final result =
          NostrMeshSerializer.deserializeEventFromMesh(invalidPacket);
      expect(result, isNull);
    });

    test('deserializeEventFromMesh returns null for empty packet', () {
      final emptyPacket = Uint8List.fromList([]);
      final result = NostrMeshSerializer.deserializeEventFromMesh(emptyPacket);
      expect(result, isNull);
    });

    test('deserializeEventFromMesh returns null for packet too small', () {
      final tooSmall = Uint8List.fromList([0x7E, 0x00, 0x00]);
      final result = NostrMeshSerializer.deserializeEventFromMesh(tooSmall);
      expect(result, isNull);
    });

    test('NIP-17 DM encryption and decryption stub', () {
      final fromPriv = 'privkey1';
      final toPub = 'pubkey2';
      final plaintext = 'hello secret';
      final cipher =
          NostrMeshSerializer.encryptNip17Dm(fromPriv, toPub, plaintext);
      expect(cipher, isNotNull);
      final decrypted =
          NostrMeshSerializer.decryptNip17Dm('unused', fromPriv, cipher);
      // Our stub returns plaintext as decrypted content
      expect(decrypted, equals(plaintext));
    });

    test('Geohash event creation', () {
      final e = NostrMeshSerializer.createGeohashEvent(
        id: 'geo1',
        pubkey: 'pub',
        createdAt: 1700000000,
        geohash: 'u4pruydqqvj',
        content: 'location info',
      );
      expect(e.kind, equals(30023));
      expect(
          e.tags
              .any((t) => t.isNotEmpty && t[0] == 'g' && t[1] == 'u4pruydqqvj'),
          isTrue);
    });
  });
}
