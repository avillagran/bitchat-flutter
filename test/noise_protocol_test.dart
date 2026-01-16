import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitchat/features/crypto/noise_protocol.dart';
import 'package:cryptography/cryptography.dart' as crypto;

void main() {
  group('NoiseProtocol Handshake', () {
    test('Initiator and Responder can complete XX handshake', () async {
      // Generate proper X25519 key pairs from deterministic seeds
      final x25519 = crypto.X25519();

      // Alice (Initiator) - static key from seed
      final aliceSeed = Uint8List(32)..fillRange(0, 32, 1);
      final aliceStaticKeyPair = await x25519.newKeyPairFromSeed(aliceSeed);
      final alicePriv =
          Uint8List.fromList((await aliceStaticKeyPair.extract()).bytes);
      final alicePub = Uint8List.fromList(
          (await aliceStaticKeyPair.extractPublicKey()).bytes);

      // Alice ephemeral key from seed (for deterministic testing)
      final aliceEphemSeed = Uint8List(32)..fillRange(0, 32, 5);
      final aliceEphemKeyPair = await x25519.newKeyPairFromSeed(aliceEphemSeed);
      final aliceEphemPriv =
          Uint8List.fromList((await aliceEphemKeyPair.extract()).bytes);
      final aliceEphemPub = Uint8List.fromList(
          (await aliceEphemKeyPair.extractPublicKey()).bytes);

      // Bob (Responder) - static key from seed
      final bobSeed = Uint8List(32)..fillRange(0, 32, 3);
      final bobStaticKeyPair = await x25519.newKeyPairFromSeed(bobSeed);
      final bobPriv =
          Uint8List.fromList((await bobStaticKeyPair.extract()).bytes);
      final bobPub =
          Uint8List.fromList((await bobStaticKeyPair.extractPublicKey()).bytes);

      // Bob ephemeral key from seed (for deterministic testing)
      final bobEphemSeed = Uint8List(32)..fillRange(0, 32, 7);
      final bobEphemKeyPair = await x25519.newKeyPairFromSeed(bobEphemSeed);
      final bobEphemPriv =
          Uint8List.fromList((await bobEphemKeyPair.extract()).bytes);
      final bobEphemPub =
          Uint8List.fromList((await bobEphemKeyPair.extractPublicKey()).bytes);

      final alice = NoiseSession(
        peerID: "alice",
        isInitiator: true,
        localStaticPrivateKey: alicePriv,
        localStaticPublicKey: alicePub,
      );
      alice.setFixedEphemeral(aliceEphemPriv, aliceEphemPub);

      final bob = NoiseSession(
        peerID: "bob",
        isInitiator: false,
        localStaticPrivateKey: bobPriv,
        localStaticPublicKey: bobPub,
      );
      bob.setFixedEphemeral(bobEphemPriv, bobEphemPub);

      print("--- HANDSHAKE START ---");
      print("Alice static pub: ${_hex(alicePub)}");
      print("Alice ephem pub:  ${_hex(aliceEphemPub)}");
      print("Bob static pub:   ${_hex(bobPub)}");
      print("Bob ephem pub:    ${_hex(bobEphemPub)}");

      // 1. Alice -> e -> Bob
      final msg1 = await alice.startHandshake();
      print("Msg1 length: ${msg1.length}");
      expect(msg1.length, 32);

      // 2. Bob processes msg1 and sends msg2
      final msg2 = await bob.processHandshakeMessage(msg1);
      print("Msg2 length: ${msg2?.length}");
      expect(msg2, isNotNull);
      expect(msg2!.length, 96);

      // 3. Alice processes msg2 and sends msg3
      final msg3 = await alice.processHandshakeMessage(msg2!);
      print("Msg3 length: ${msg3?.length}");
      expect(msg3, isNotNull);
      expect(msg3!.length, 64);

      // 4. Bob processes msg3
      final last = await bob.processHandshakeMessage(msg3!);
      expect(last, isNull);

      expect(alice.isEstablished(), isTrue);
      expect(bob.isEstablished(), isTrue);

      print("--- TRANSPORT TEST ---");
      final plaintext = Uint8List.fromList(utf8.encode("secret message"));
      final ciphertext = await alice.encrypt(plaintext);

      final decrypted = await bob.decrypt(ciphertext);
      expect(utf8.decode(decrypted), "secret message");
    });
  });
}

String _hex(List<int> data) {
  final sb = StringBuffer();
  for (final b in data) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}
