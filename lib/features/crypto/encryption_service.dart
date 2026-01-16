import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'noise_protocol.dart';

class EncryptionService {
  // Singleton
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final _storage = const FlutterSecureStorage();

  static const String _staticPrivKeyPref = "noise_static_private_key";
  static const String _signingPrivKeyPref = "ed25519_signing_private_key";

  late Uint8List _staticIdentityPrivateKey;
  late Uint8List _staticIdentityPublicKey;
  late Uint8List _signingPrivateKey;
  late Uint8List _signingPublicKey;

  final Map<String, NoiseSession> _sessions = {};

  Uint8List get staticPublicKey => _staticIdentityPublicKey;
  Uint8List get signingPublicKey => _signingPublicKey;

  Future<void> initialize() async {
    // 1. Noise Static Keys (X25519)
    final storedNoisePriv = await _storage.read(key: _staticPrivKeyPref);
    if (storedNoisePriv != null) {
      _staticIdentityPrivateKey = base64Decode(storedNoisePriv);
      final keyPair =
          await crypto.X25519().newKeyPairFromSeed(_staticIdentityPrivateKey);
      _staticIdentityPublicKey =
          Uint8List.fromList((await keyPair.extractPublicKey()).bytes);
    } else {
      final keyPair = await crypto.X25519().newKeyPair();
      final data = await keyPair.extract();
      _staticIdentityPrivateKey = Uint8List.fromList(data.bytes);
      _staticIdentityPublicKey =
          Uint8List.fromList((await keyPair.extractPublicKey()).bytes);
      await _storage.write(
          key: _staticPrivKeyPref,
          value: base64Encode(_staticIdentityPrivateKey));
    }

    // 2. Ed25519 Signing Keys
    final storedSignPriv = await _storage.read(key: _signingPrivKeyPref);
    if (storedSignPriv != null) {
      _signingPrivateKey = base64Decode(storedSignPriv);
      final keyPair =
          await crypto.Ed25519().newKeyPairFromSeed(_signingPrivateKey);
      _signingPublicKey =
          Uint8List.fromList((await keyPair.extractPublicKey()).bytes);
    } else {
      final keyPair = await crypto.Ed25519().newKeyPair();
      final data = await keyPair.extract();
      _signingPrivateKey = Uint8List.fromList(data.bytes);
      _signingPublicKey =
          Uint8List.fromList((await keyPair.extractPublicKey()).bytes);
      await _storage.write(
          key: _signingPrivKeyPref, value: base64Encode(_signingPrivateKey));
    }
  }

  Future<Uint8List?> signData(Uint8List data) async {
    final keyPair =
        await crypto.Ed25519().newKeyPairFromSeed(_signingPrivateKey);
    final signature = await crypto.Ed25519().sign(data, keyPair: keyPair);
    return Uint8List.fromList(signature.bytes);
  }

  Future<bool> verifySignature(
      Uint8List signature, Uint8List data, Uint8List publicKey) async {
    final pubKey =
        crypto.SimplePublicKey(publicKey, type: crypto.KeyPairType.ed25519);
    final sig = crypto.Signature(signature, publicKey: pubKey);
    return await crypto.Ed25519().verify(data, signature: sig);
  }

  NoiseSession getOrCreateSession(String peerID, bool isInitiator) {
    return _sessions.putIfAbsent(
        peerID,
        () => NoiseSession(
              peerID: peerID,
              isInitiator: isInitiator,
              localStaticPrivateKey: _staticIdentityPrivateKey,
              localStaticPublicKey: _staticIdentityPublicKey,
            ));
  }

  void removeSession(String peerID) {
    _sessions.remove(peerID);
  }

  void clearIdentity() async {
    await _storage.delete(key: _staticPrivKeyPref);
    await _storage.delete(key: _signingPrivKeyPref);
    _sessions.clear();
  }
}
