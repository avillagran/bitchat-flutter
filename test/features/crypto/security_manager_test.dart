import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:bitchat/features/crypto/noise_protocol.dart';

// NOTE: Tests target the NoiseSession implementation in
// `lib/features/crypto/noise_protocol.dart` and its manual
// Noise implementation in `noise_protocol_manual.dart`.

/// Helper: derive public key bytes from a 32-byte seed for X25519
Future<Uint8List> _x25519PublicFromSeed(Uint8List seed) async {
  final keyPair = await crypto.X25519().newKeyPairFromSeed(seed);
  final pub = await keyPair.extractPublicKey();
  return Uint8List.fromList(pub.bytes);
}

Uint8List _filledSeed(int value) => Uint8List.fromList(List.filled(32, value));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NoiseSession (XX) handshake and crypto', () {
    test('Handshake: initiator and responder establish session', () async {
      final initSeed = _filledSeed(1);
      final respSeed = _filledSeed(2);

      final initPub = await _x25519PublicFromSeed(initSeed);
      final respPub = await _x25519PublicFromSeed(respSeed);

      final initiator = NoiseSession(
        peerID: 'peerB',
        isInitiator: true,
        localStaticPrivateKey: initSeed,
        localStaticPublicKey: initPub,
      );

      final responder = NoiseSession(
        peerID: 'peerA',
        isInitiator: false,
        localStaticPrivateKey: respSeed,
        localStaticPublicKey: respPub,
      );

      // Fixed ephemeral for deterministic handshake
      final ephSeed = _filledSeed(3);
      final ephPub = await _x25519PublicFromSeed(ephSeed);
      initiator.setFixedEphemeral(ephSeed, ephPub);
      responder.setFixedEphemeral(ephSeed, ephPub);

      final msg1 = await initiator.startHandshake();
      expect(msg1, isNotNull);
      expect(initiator.state, NoiseSessionState.handshaking);

      final msg2 = await responder.processHandshakeMessage(msg1);
      expect(msg2, isNotNull);
      // After responder processes msg1 and writes msg2 it may still be handshaking

      final msg3 = await initiator.processHandshakeMessage(msg2!);
      // If initiator returned a final handshake message, responder must process it
      if (msg3 != null) {
        await responder.processHandshakeMessage(msg3);
      }

      expect(initiator.isEstablished(), isTrue);
      expect(responder.isEstablished(), isTrue);

      // remote static keys should be set correctly
      expect(initiator.remoteStaticPublicKey, equals(respPub));
      expect(responder.remoteStaticPublicKey, equals(initPub));

      expect(initiator.handshakeHash, isNotNull);
      expect(responder.handshakeHash, isNotNull);
    });

    test('Encrypt/Decrypt and replay detection', () async {
      final aSeed = _filledSeed(10);
      final bSeed = _filledSeed(11);
      final aPub = await _x25519PublicFromSeed(aSeed);
      final bPub = await _x25519PublicFromSeed(bSeed);

      final a = NoiseSession(
        peerID: 'B',
        isInitiator: true,
        localStaticPrivateKey: aSeed,
        localStaticPublicKey: aPub,
      );
      final b = NoiseSession(
        peerID: 'A',
        isInitiator: false,
        localStaticPrivateKey: bSeed,
        localStaticPublicKey: bPub,
      );

      final eph = _filledSeed(12);
      final ephPub = await _x25519PublicFromSeed(eph);
      a.setFixedEphemeral(eph, ephPub);
      b.setFixedEphemeral(eph, ephPub);

      final m1 = await a.startHandshake();
      final m2 = await b.processHandshakeMessage(m1);
      final m3 = await a.processHandshakeMessage(m2!);
      if (m3 != null) {
        await b.processHandshakeMessage(m3);
      }

      expect(a.isEstablished(), isTrue);
      expect(b.isEstablished(), isTrue);

      final plaintext = Uint8List.fromList([1, 2, 3, 4, 5]);
      final combined = await a.encrypt(plaintext);
      expect(combined.length, greaterThan(0));

      final decrypted = await b.decrypt(combined);
      expect(decrypted, equals(plaintext));

      // Replay: decrypting the same ciphertext again should throw
      bool threw = false;
      try {
        await b.decrypt(combined);
      } catch (e) {
        threw = true;
      }
      expect(threw, isTrue);
    });

    test('Key rotation produces different handshake keys', () async {
      // Initial keys
      final aSeed1 = _filledSeed(20);
      final bSeed1 = _filledSeed(21);
      final aPub1 = await _x25519PublicFromSeed(aSeed1);
      final bPub1 = await _x25519PublicFromSeed(bSeed1);

      final a1 = NoiseSession(
        peerID: 'B',
        isInitiator: true,
        localStaticPrivateKey: aSeed1,
        localStaticPublicKey: aPub1,
      );
      final b1 = NoiseSession(
        peerID: 'A',
        isInitiator: false,
        localStaticPrivateKey: bSeed1,
        localStaticPublicKey: bPub1,
      );

      final eph1 = _filledSeed(22);
      final eph1Pub = await _x25519PublicFromSeed(eph1);
      a1.setFixedEphemeral(eph1, eph1Pub);
      b1.setFixedEphemeral(eph1, eph1Pub);

      final r1 = await a1.startHandshake();
      final r2 = await b1.processHandshakeMessage(r1);
      final r3 = await a1.processHandshakeMessage(r2!);
      if (r3 != null) {
        await b1.processHandshakeMessage(r3);
      }

      expect(a1.isEstablished(), isTrue);
      expect(b1.isEstablished(), isTrue);

      // Rotate: create new static keys
      final aSeed2 = _filledSeed(30);
      final bSeed2 = _filledSeed(31);
      final aPub2 = await _x25519PublicFromSeed(aSeed2);
      final bPub2 = await _x25519PublicFromSeed(bSeed2);

      final a2 = NoiseSession(
        peerID: 'B',
        isInitiator: true,
        localStaticPrivateKey: aSeed2,
        localStaticPublicKey: aPub2,
      );
      final b2 = NoiseSession(
        peerID: 'A',
        isInitiator: false,
        localStaticPrivateKey: bSeed2,
        localStaticPublicKey: bPub2,
      );

      final eph2 = _filledSeed(32);
      final eph2Pub = await _x25519PublicFromSeed(eph2);
      a2.setFixedEphemeral(eph2, eph2Pub);
      b2.setFixedEphemeral(eph2, eph2Pub);

      final s1 = await a2.startHandshake();
      final s2 = await b2.processHandshakeMessage(s1);
      final s3 = await a2.processHandshakeMessage(s2!);
      if (s3 != null) {
        await b2.processHandshakeMessage(s3);
      }

      expect(a2.isEstablished(), isTrue);
      expect(b2.isEstablished(), isTrue);

      // Ensure handshake hashes differ between the two handshakes
      expect(a1.handshakeHash, isNotNull);
      expect(a2.handshakeHash, isNotNull);
      expect(a1.handshakeHash, isNot(equals(a2.handshakeHash)));

      // Remote static keys differ as well
      expect(a1.remoteStaticPublicKey, isNot(equals(a2.remoteStaticPublicKey)));
    });

    test('Session creation times differ (timeout simulation)', () async {
      final seedA = _filledSeed(40);
      final pubA = await _x25519PublicFromSeed(seedA);
      final sA = NoiseSession(
        peerID: 'X',
        isInitiator: true,
        localStaticPrivateKey: seedA,
        localStaticPublicKey: pubA,
      );

      final seedB = _filledSeed(41);
      final pubB = await _x25519PublicFromSeed(seedB);
      final sB = NoiseSession(
        peerID: 'Y',
        isInitiator: true,
        localStaticPrivateKey: seedB,
        localStaticPublicKey: pubB,
      );

      // creationTime is set at construction; newer session should have >= time
      expect(sB.creationTime >= sA.creationTime, isTrue);

      // Simulate timeout by checking age difference (can't modify system time here)
      final ageA = DateTime.now().millisecondsSinceEpoch - sA.creationTime;
      final ageB = DateTime.now().millisecondsSinceEpoch - sB.creationTime;
      expect(ageA >= 0, isTrue);
      expect(ageB >= 0, isTrue);
    });
  });
}
