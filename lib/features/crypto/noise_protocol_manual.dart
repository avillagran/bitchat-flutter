import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:pointycastle/export.dart' as pc;
import 'chacha_poly_port.dart' as cp;

/// Manual implementation of Noise Protocol State Machine
/// Pattern: Noise_XX_25519_ChaChaPoly_SHA256

/// Set to true to enable verbose debug logging for Noise protocol
const bool kNoiseDebug = false;

void _debugPrint(String message) {
  if (kNoiseDebug) _debugPrint(message);
}

String _hex(List<int> data) {
  final sb = StringBuffer();
  for (final b in data) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

class NoiseCipherState {
  cp.ChaChaPolyCipherStatePort _impl = cp.ChaChaPolyCipherStatePort();
  Uint8List? _key;
  int _n = 0;
  bool _hasKey = false;

  bool get hasKey => _impl.haskey;

  void initializeKey(Uint8List key) {
    _key = Uint8List.fromList(key);
    _impl.initializeKey(_key!);
    _n = 0;
    _hasKey = true;
    _debugPrint('DEBUG CipherState.initializeKey: key.len=${_key?.length}');
  }

  void setNonce(int nonce) {
    _n = nonce;
    _impl.setNonce(nonce);
  }

  Future<Uint8List> encryptWithAd(Uint8List ad, Uint8List plaintext) async {
    if (!_impl.haskey) return plaintext;
    // sync nonce to impl
    _impl.setNonce(_n);
    final out = _impl.encryptWithAd(ad, plaintext);
    // sync back
    _n = _impl.n;
    // DEBUG: split out tag
    final ctLen = out.length - 16;
    _debugPrint(
        'DEBUG encryptWithAd (port): nonce=${_n} ct.len=$ctLen mac=${_hex(out.sublist(ctLen))}');
    return out;
  }

  Future<Uint8List> decryptWithAd(Uint8List ad, Uint8List ciphertext) async {
    if (!_impl.haskey) return ciphertext;
    // sync nonce to impl
    _impl.setNonce(_n);
    final out = _impl.decryptWithAd(ad, ciphertext);
    // sync back
    _n = _impl.n;
    _debugPrint(
        'DEBUG decryptWithAd (port): nonce=${_n} ct.len=${ciphertext.length - 16} mac=${_hex(ciphertext.sublist(ciphertext.length - 16))}');
    return out;
  }

  NoiseCipherState fork(Uint8List key) {
    final newState = NoiseCipherState();
    newState.initializeKey(key);
    return newState;
  }
}

class NoiseSymmetricState {
  final String protocolName;
  late Uint8List h;
  late Uint8List ck;
  final NoiseCipherState cipher = NoiseCipherState();

  NoiseSymmetricState(this.protocolName) {
    final nameBytes = utf8.encode(protocolName);
    final digest = pc.SHA256Digest();
    if (nameBytes.length <= 32) {
      h = Uint8List(32);
      h.setRange(0, nameBytes.length, nameBytes);
    } else {
      h = digest.process(Uint8List.fromList(nameBytes));
    }
    ck = Uint8List.fromList(h);
    _debugPrint(
        'DEBUG SymmetricState.init: protocol=$protocolName h=${_hex(h)} ck.len=${ck.length}');
  }

  void mixHash(Uint8List data) {
    final digest = pc.SHA256Digest();
    // hashTwo: h = HASH(h || data)
    final combined = Uint8List(h.length + data.length);
    combined.setRange(0, h.length, h);
    combined.setRange(h.length, combined.length, data);
    h = digest.process(combined);
    _debugPrint('DEBUG mixHash: data.len=${data.length} h=${_hex(h)}');
  }

  void mixKey(Uint8List data) {
    _debugPrint('TRACE mixKey: called with data=${_hex(data)} ck=${_hex(ck)}');
    final hkdf = _hkdfSHA256(ck, data);
    _debugPrint(
        'TRACE mixKey: hkdf.first=${_hex(hkdf.first)} hkdf.second=${_hex(hkdf.second)}');
    ck = hkdf.first;
    cipher.initializeKey(hkdf.second);
    _debugPrint('TRACE mixKey: ck=${_hex(ck)} k.len=${hkdf.second.length}');
  }

  Pair<Uint8List, Uint8List> _hkdfSHA256(
      Uint8List chainingKey, Uint8List data) {
    // Implement HKDF as in Android Noise implementation (extract then expand with counter)
    final extract = pc.HMac(pc.SHA256Digest(), 64);
    extract.init(pc.KeyParameter(chainingKey));
    final tempKey = extract.process(data);

    // DEBUG
    _debugPrint('DEBUG HKDF extract tempKey=${_hex(tempKey)}');

    final hmac1 = pc.HMac(pc.SHA256Digest(), 64);
    hmac1.init(pc.KeyParameter(tempKey));
    final out1 = hmac1.process(Uint8List.fromList([0x01]));

    final hmac2 = pc.HMac(pc.SHA256Digest(), 64);
    hmac2.init(pc.KeyParameter(tempKey));
    final input2 = Uint8List(out1.length + 1);
    input2.setRange(0, out1.length, out1);
    input2[input2.length - 1] = 0x02;
    final out2 = hmac2.process(input2);

    // DEBUG
    _debugPrint('DEBUG HKDF out1=${_hex(out1)} out2=${_hex(out2)}');

    return Pair(out1, out2);
  }

  // Encrypt and then mix the ciphertext into the handshake hash (Android: encryptAndHash)
  Future<Uint8List> encryptAndHash(Uint8List plaintext) async {
    // AD is current h
    _debugPrint(
        'DEBUG encryptAndHash AD(h)=${_hex(h)} plaintext.len=${plaintext.length}');
    final ct = await cipher.encryptWithAd(h, plaintext);
    mixHash(ct);
    return ct;
  }

  // Mix ciphertext into hash then decrypt using prev_h as AD (Android: decryptAndHash)
  Future<Uint8List> decryptAndHash(Uint8List ciphertext) async {
    final prevH = Uint8List.fromList(h);
    _debugPrint(
        'DEBUG decryptAndHash prevH=${_hex(prevH)} ciphertext.len=${ciphertext.length}');
    mixHash(ciphertext);
    final pt = await cipher.decryptWithAd(prevH, ciphertext);
    return pt;
  }

  Pair<NoiseCipherState, NoiseCipherState> split() {
    final hkdf = _hkdfSHA256(ck, Uint8List(0));
    return Pair(cipher.fork(hkdf.first), cipher.fork(hkdf.second));
  }
}

class Pair<A, B> {
  final A first;
  final B second;
  Pair(this.first, this.second);
}

class NoiseHandshakeState {
  static const int initiator = 1;
  static const int responder = 2;
  static const int writeMessage = 1;
  static const int readMessage = 2;
  static const int splitAction = 4;

  final int role;
  late NoiseSymmetricState symmetric;
  int action = 0;
  int patternStep = 0;

  Uint8List? s; // local static private
  Uint8List? sPub; // local static public
  Uint8List? e; // local ephemeral private
  Uint8List? ePub; // local ephemeral public
  Uint8List? rsPub; // remote static public
  Uint8List? rePub; // remote ephemeral public

  // Fixed ephemeral key for testing (like Android's getFixedEphemeralKey)
  Uint8List? _fixedEphemeralPrivate;
  Uint8List? _fixedEphemeralPublic;

  NoiseHandshakeState(String protocolName, this.role) {
    symmetric = NoiseSymmetricState(protocolName);
    action = (role == initiator) ? writeMessage : readMessage;
  }

  void setLocalStaticKey(Uint8List priv, Uint8List pub) {
    s = priv;
    sPub = pub;
    _debugPrint(
        'DEBUG setLocalStaticKey: s.len=${s?.length} sPub.len=${sPub?.length}');
  }

  /// Set fixed ephemeral key for testing (like Android's getFixedEphemeralKey).
  /// This should NOT be used in production - only for deterministic test vectors.
  void setFixedEphemeral(Uint8List priv, Uint8List pub) {
    _fixedEphemeralPrivate = priv;
    _fixedEphemeralPublic = pub;
    _debugPrint(
        'DEBUG setFixedEphemeral: priv.len=${priv.length} pub.len=${pub.length}');
  }

  Future<Uint8List> writeHandshakeMessage(Uint8List payload) async {
    final out = BytesBuilder();
    final roleName =
        role == NoiseHandshakeState.initiator ? 'initiator' : 'responder';
    if (patternStep == 0 && role == initiator) {
      // Generate or use fixed ephemeral key (like Android's fixedEphemeral)
      if (_fixedEphemeralPrivate != null && _fixedEphemeralPublic != null) {
        e = Uint8List.fromList(_fixedEphemeralPrivate!);
        ePub = Uint8List.fromList(_fixedEphemeralPublic!);
        _debugPrint('DEBUG write initiator using FIXED ePub=${_hex(ePub!)}');
      } else {
        final ephem = await crypto.X25519().newKeyPair();
        final ephemData = await ephem.extract();
        e = Uint8List.fromList(ephemData.bytes);
        ePub = Uint8List.fromList((await ephem.extractPublicKey()).bytes);
        _debugPrint('DEBUG write initiator ePub=${_hex(ePub!)}');
      }
      out.add(ePub!);
      symmetric.mixHash(ePub!);
      patternStep = 1;
      action = readMessage;
    } else if (patternStep == 1 && role == responder) {
      // Generate or use fixed ephemeral key (like Android's fixedEphemeral)
      if (_fixedEphemeralPrivate != null && _fixedEphemeralPublic != null) {
        e = Uint8List.fromList(_fixedEphemeralPrivate!);
        ePub = Uint8List.fromList(_fixedEphemeralPublic!);
        _debugPrint('DEBUG write responder using FIXED ePub=${_hex(ePub!)}');
      } else {
        final ephem = await crypto.X25519().newKeyPair();
        final ephemData = await ephem.extract();
        e = Uint8List.fromList(ephemData.bytes);
        ePub = Uint8List.fromList((await ephem.extractPublicKey()).bytes);
        _debugPrint('DEBUG write responder ePub=${_hex(ePub!)}');
      }
      out.add(ePub!);
      symmetric.mixHash(ePub!);
      final dh1 = await _calculateDH(e!, rePub!);
      _debugPrint('DEBUG write responder DH e/rePub=${_hex(dh1)}');
      _debugPrint(
          'TRACE [$roleName][write][patternStep=$patternStep] mixKey dh=${_hex(dh1)} ck=${_hex(symmetric.ck)}');
      symmetric.mixKey(dh1);
      _debugPrint(
          'TRACE [$roleName][write][patternStep=$patternStep] encryptAndHash sPub.len=${sPub?.length}');
      final encryptedS = await symmetric.encryptAndHash(sPub!);
      // DEBUG
      _debugPrint(
          'DEBUG write responder: role=$role patternStep=$patternStep ePub.len=${ePub?.length} sPub.len=${sPub?.length} encryptedS.len=${encryptedS.length} h.len=${symmetric.h.length} hasKey=${symmetric.cipher.hasKey}');
      out.add(encryptedS);
      // Debug: print full encryptedS bytes for sender
      _debugPrint('TRACE write responder encryptedS.hex=' + _hex(encryptedS));
      final dh2 = await _calculateDH(s!, rePub!);
      _debugPrint('DEBUG write responder DH s/rePub=${_hex(dh2)}');
      symmetric.mixKey(dh2);
      patternStep = 2;
      action = readMessage;
    } else if (patternStep == 2 && role == initiator) {
      _debugPrint(
          'TRACE [$roleName][write][patternStep=$patternStep] encryptAndHash sPub.len=${sPub?.length}');
      final encryptedS = await symmetric.encryptAndHash(sPub!);
      // DEBUG
      _debugPrint(
          'DEBUG write initiator: role=$role patternStep=$patternStep sPub.len=${sPub?.length} encryptedS.len=${encryptedS.length} h.len=${symmetric.h.length} hasKey=${symmetric.cipher.hasKey}');
      out.add(encryptedS);
      final dh3 = await _calculateDH(s!, rePub!);
      _debugPrint('DEBUG write initiator DH s/rePub=${_hex(dh3)}');
      symmetric.mixKey(dh3);
      patternStep = 3;
      action = splitAction;
    }
    _debugPrint(
        'TRACE [${role == NoiseHandshakeState.initiator ? 'initiator' : 'responder'}][write][patternStep=$patternStep] encryptAndHash payload.len=${payload.length}');
    final encryptedPayload = await symmetric.encryptAndHash(payload);
    // DEBUG
    _debugPrint(
        'DEBUG write payload: patternStep=$patternStep payload.len=${payload.length} encryptedPayload.len=${encryptedPayload.length} h=${_hex(symmetric.h)}');
    out.add(encryptedPayload);
    // Debug: print payload ciphertext
    _debugPrint('TRACE write payload hex=' + _hex(encryptedPayload));

    return out.toBytes();
  }

  Future<Uint8List> readHandshakeMessage(Uint8List message) async {
    int off = 0;
    if (patternStep == 0 && role == responder) {
      rePub = message.sublist(off, off + 32);
      off += 32;
      symmetric.mixHash(rePub!);
      _debugPrint('DEBUG read responder rePub=${_hex(rePub!)}');
      patternStep = 1;
      action = writeMessage;
    } else if (patternStep == 1 && role == initiator) {
      rePub = message.sublist(off, off + 32);
      off += 32;
      symmetric.mixHash(rePub!);
      _debugPrint('DEBUG read initiator rePub=${_hex(rePub!)}');
      final dh1 = await _calculateDH(e!, rePub!);
      _debugPrint('DEBUG read initiator DH e/rePub=${_hex(dh1)}');
      symmetric.mixKey(dh1);
      final sLen = 32 + (symmetric.cipher.hasKey ? 16 : 0);
      final encryptedS = message.sublist(off, off + sLen);
      // Debug: print full encryptedS bytes for receiver
      _debugPrint('TRACE read initiator encryptedS.hex=' + _hex(encryptedS));
      rsPub = await symmetric.decryptAndHash(encryptedS);
      // DEBUG
      _debugPrint(
          'DEBUG read initiator: decrypted rsPub.len=${rsPub?.length} encryptedS.len=${encryptedS.length} hasKey=${symmetric.cipher.hasKey}');
      _debugPrint('DEBUG read initiator decrypted rsPub=${_hex(rsPub!)}');
      off += sLen;

      final dh2 = await _calculateDH(e!, rsPub!);
      _debugPrint('DEBUG read initiator DH e/rsPub=${_hex(dh2)}');
      symmetric.mixKey(dh2);
      patternStep = 2;
      action = writeMessage;
    } else if (patternStep == 2 && role == responder) {
      final sLen = 32 + (symmetric.cipher.hasKey ? 16 : 0);
      final encryptedS = message.sublist(off, off + sLen);
      rsPub = await symmetric.decryptAndHash(encryptedS);
      // DEBUG
      _debugPrint(
          'DEBUG read responder: decrypted rsPub.len=${rsPub?.length} encryptedS.len=${encryptedS.length} hasKey=${symmetric.cipher.hasKey}');
      _debugPrint('DEBUG read responder decrypted rsPub=${_hex(rsPub!)}');
      off += sLen;
      // SE token: for responder, this is DH(e, rs) - responder's ephemeral with initiator's static
      final dh3 = await _calculateDH(e!, rsPub!);
      _debugPrint('DEBUG read responder DH e/rsPub=${_hex(dh3)}');
      symmetric.mixKey(dh3);
      patternStep = 3;
      action = splitAction;
    }
    final payloadData = message.sublist(off);
    // Debug: print payload ciphertext at receiver
    _debugPrint('TRACE read payload hex=' + _hex(payloadData));
    final plaintext = await symmetric.decryptAndHash(payloadData);
    return plaintext;
  }

  Future<Uint8List> _calculateDH(Uint8List priv, Uint8List pub) async {
    final keyPair = await crypto.X25519().newKeyPairFromSeed(priv);
    final sharedSecret = await crypto.X25519().sharedSecretKey(
        keyPair: keyPair,
        remotePublicKey:
            crypto.SimplePublicKey(pub, type: crypto.KeyPairType.x25519));
    final sharedSecretData = await sharedSecret.extractBytes();
    final result = Uint8List.fromList(sharedSecretData);
    _debugPrint(
        'DEBUG calculateDH: priv=${_hex(priv)} pub=${_hex(pub)} dh=${_hex(result)}');
    return result;
  }

  Pair<NoiseCipherState, NoiseCipherState> split() {
    return symmetric.split();
  }
}
