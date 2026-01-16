import 'dart:typed_data';
import 'noise_protocol_manual.dart';

enum NoiseSessionState {
  uninitialized,
  handshaking,
  established,
  failed,
}

class NoiseSession {
  final String peerID;
  final bool isInitiator;
  final Uint8List localStaticPrivateKey;
  final Uint8List localStaticPublicKey;

  static const String protocolName = "Noise_XX_25519_ChaChaPoly_SHA256";
  static const int nonceSizeBytes = 4;
  static const int replayWindowSize = 1024;
  static const int replayWindowBytes = replayWindowSize ~/ 8; // 128 bytes

  NoiseHandshakeState? _handshakeState;
  NoiseCipherState? _sendCipher;
  NoiseCipherState? _receiveCipher;

  NoiseSessionState _state = NoiseSessionState.uninitialized;
  final int creationTime = DateTime.now().millisecondsSinceEpoch;

  int _messagesSent = 0;
  int _highestReceivedNonce = 0;
  final Uint8List _replayWindow = Uint8List(replayWindowBytes);

  Uint8List? remoteStaticPublicKey;
  Uint8List? handshakeHash;

  // Fixed ephemeral key for testing only
  Uint8List? _fixedEphemeralPrivate;
  Uint8List? _fixedEphemeralPublic;

  NoiseSession({
    required this.peerID,
    required this.isInitiator,
    required this.localStaticPrivateKey,
    required this.localStaticPublicKey,
  }) {
    _initialize();
  }

  void _initialize() {
    if (localStaticPrivateKey.length != 32 ||
        localStaticPublicKey.length != 32) {
      _state = NoiseSessionState.failed;
    }
  }

  NoiseSessionState get state => _state;
  bool isEstablished() => _state == NoiseSessionState.established;

  /// Set fixed ephemeral key for testing only.
  /// This should NOT be used in production - only for deterministic test vectors.
  void setFixedEphemeral(Uint8List priv, Uint8List pub) {
    _fixedEphemeralPrivate = priv;
    _fixedEphemeralPublic = pub;
  }

  Future<Uint8List> startHandshake() async {
    if (!isInitiator) throw Exception("Only initiator can start");

    _handshakeState =
        NoiseHandshakeState(protocolName, NoiseHandshakeState.initiator);
    _handshakeState!
        .setLocalStaticKey(localStaticPrivateKey, localStaticPublicKey);

    // Apply fixed ephemeral key if set (for testing)
    if (_fixedEphemeralPrivate != null && _fixedEphemeralPublic != null) {
      _handshakeState!
          .setFixedEphemeral(_fixedEphemeralPrivate!, _fixedEphemeralPublic!);
    }

    _state = NoiseSessionState.handshaking;

    return await _handshakeState!.writeHandshakeMessage(Uint8List(0));
  }

  Future<Uint8List?> processHandshakeMessage(Uint8List message) async {
    if (_state == NoiseSessionState.uninitialized && !isInitiator) {
      _handshakeState =
          NoiseHandshakeState(protocolName, NoiseHandshakeState.responder);
      _handshakeState!
          .setLocalStaticKey(localStaticPrivateKey, localStaticPublicKey);

      // Apply fixed ephemeral key if set (for testing)
      if (_fixedEphemeralPrivate != null && _fixedEphemeralPublic != null) {
        _handshakeState!
            .setFixedEphemeral(_fixedEphemeralPrivate!, _fixedEphemeralPublic!);
      }

      _state = NoiseSessionState.handshaking;
    }

    final protocol = _handshakeState;
    if (protocol == null) return null;

    if (protocol.action == NoiseHandshakeState.readMessage) {
      await protocol.readHandshakeMessage(message);
    }

    if (protocol.action == NoiseHandshakeState.splitAction) {
      _completeHandshake();
      return null;
    }

    if (protocol.action == NoiseHandshakeState.writeMessage) {
      final response = await protocol.writeHandshakeMessage(Uint8List(0));
      if (protocol.action == NoiseHandshakeState.splitAction) {
        _completeHandshake();
      }
      return response;
    }

    return null;
  }

  void _completeHandshake() {
    final protocol = _handshakeState;
    if (protocol == null) return;

    final result = protocol.split();
    // Noise spec: initiator sends with k1, receives with k2
    //             responder sends with k2, receives with k1
    if (isInitiator) {
      _sendCipher = result.first;
      _receiveCipher = result.second;
    } else {
      _sendCipher = result.second;
      _receiveCipher = result.first;
    }

    remoteStaticPublicKey = protocol.rsPub;
    handshakeHash = protocol.symmetric.h;

    _messagesSent = 0;
    _highestReceivedNonce = 0;
    _replayWindow.fillRange(0, _replayWindow.length, 0);

    _state = NoiseSessionState.established;
    _handshakeState = null;
  }

  Future<Uint8List> encrypt(Uint8List data) async {
    final cipher = _sendCipher;
    if (cipher == null || !isEstablished()) {
      throw Exception("Session not established");
    }

    final currentNonce = _messagesSent;
    if (currentNonce >= 0xFFFFFFFF) {
      throw Exception("Nonce exceeded 4-byte limit");
    }

    _messagesSent++;

    cipher.setNonce(currentNonce);
    final ciphertext = await cipher.encryptWithAd(Uint8List(0), data);

    final result = Uint8List(nonceSizeBytes + ciphertext.length);
    final view = ByteData.view(result.buffer);
    view.setUint32(0, currentNonce, Endian.big);
    result.setRange(nonceSizeBytes, result.length, ciphertext);

    return result;
  }

  Future<Uint8List> decrypt(Uint8List combinedPayload) async {
    final cipher = _receiveCipher;
    if (cipher == null || !isEstablished()) {
      throw Exception("Session not established");
    }
    if (combinedPayload.length < nonceSizeBytes) {
      throw Exception("Payload too small");
    }

    final view = ByteData.view(
        combinedPayload.buffer, combinedPayload.offsetInBytes, nonceSizeBytes);
    final receivedNonce = view.getUint32(0, Endian.big);
    final ciphertext = combinedPayload.sublist(nonceSizeBytes);

    if (!_isValidNonce(receivedNonce)) {
      throw Exception("Replay attack detected: nonce $receivedNonce rejected");
    }

    cipher.setNonce(receivedNonce);
    final plaintext = await cipher.decryptWithAd(Uint8List(0), ciphertext);

    _markNonceAsSeen(receivedNonce);
    return plaintext;
  }

  bool _isValidNonce(int receivedNonce) {
    if (receivedNonce + replayWindowSize <= _highestReceivedNonce) {
      return false;
    }
    if (receivedNonce > _highestReceivedNonce) {
      return true;
    }
    final offset = _highestReceivedNonce - receivedNonce;
    final byteIndex = offset ~/ 8;
    final bitIndex = offset % 8;
    return (_replayWindow[byteIndex] & (1 << bitIndex)) == 0;
  }

  void _markNonceAsSeen(int receivedNonce) {
    if (receivedNonce > _highestReceivedNonce) {
      final shift = receivedNonce - _highestReceivedNonce;
      if (shift >= replayWindowSize) {
        _replayWindow.fillRange(0, _replayWindow.length, 0);
      } else {
        _shiftWindow(shift);
      }
      _highestReceivedNonce = receivedNonce;
      _replayWindow[0] |= 1;
    } else {
      final offset = _highestReceivedNonce - receivedNonce;
      final byteIndex = offset ~/ 8;
      final bitIndex = offset % 8;
      _replayWindow[byteIndex] |= (1 << bitIndex);
    }
  }

  void _shiftWindow(int shift) {
    final byteShift = shift ~/ 8;
    final bitShift = shift % 8;
    for (int i = replayWindowBytes - 1; i >= 0; i--) {
      int sourceByteIndex = i - byteShift;
      int newByte = 0;
      if (sourceByteIndex >= 0) {
        newByte = (_replayWindow[sourceByteIndex] & 0xFF) >> bitShift;
        if (sourceByteIndex > 0 && bitShift != 0) {
          newByte |=
              (_replayWindow[sourceByteIndex - 1] & 0xFF) << (8 - bitShift);
        }
      }
      _replayWindow[i] = newByte & 0xFF;
    }
  }
}
