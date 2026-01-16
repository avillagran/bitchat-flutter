import 'dart:typed_data';

// Port of SouthernStorm ChaChaCore and Poly1305 (Java) to Dart for bit-for-bit parity

/// Set to true to enable verbose debug logging for ChaCha/Poly1305
const bool kChaChaPolyDebug = false;

void _debugPrint(String message) {
  if (kChaChaPolyDebug) _debugPrint(message);
}

String _hex(List<int> data) {
  final sb = StringBuffer();
  for (final b in data) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

int _u32(int x) => x & 0xFFFFFFFF;

int _rotl(int v, int n) {
  v = v & 0xFFFFFFFF;
  return _u32(((v << n) & 0xFFFFFFFF) | ((v & 0xFFFFFFFF) >> (32 - n)));
}

int _char4(int c1, int c2, int c3, int c4) {
  return ((c1 & 0xFF)) |
      ((c2 & 0xFF) << 8) |
      ((c3 & 0xFF) << 16) |
      ((c4 & 0xFF) << 24);
}

int _fromLittleEndian(Uint8List key, int offset) {
  return (key[offset] & 0xFF) |
      ((key[offset + 1] & 0xFF) << 8) |
      ((key[offset + 2] & 0xFF) << 16) |
      ((key[offset + 3] & 0xFF) << 24);
}

class ChaChaCore {
  // Hashes an input block with ChaCha20.
  static void hash(List<int> output, List<int> input) {
    // output and input are lists of 16 32-bit words
    for (var i = 0; i < 16; ++i) output[i] = _u32(input[i]);

    for (var index = 0; index < 20; index += 2) {
      // Column round
      _quarterRound(output, 0, 4, 8, 12);
      _quarterRound(output, 1, 5, 9, 13);
      _quarterRound(output, 2, 6, 10, 14);
      _quarterRound(output, 3, 7, 11, 15);
      // Diagonal round
      _quarterRound(output, 0, 5, 10, 15);
      _quarterRound(output, 1, 6, 11, 12);
      _quarterRound(output, 2, 7, 8, 13);
      _quarterRound(output, 3, 4, 9, 14);
    }

    for (var i = 0; i < 16; ++i) {
      output[i] = _u32(output[i] + input[i]);
    }
  }

  static void _quarterRound(List<int> v, int a, int b, int c, int d) {
    v[a] = _u32(v[a] + v[b]);
    v[d] = _rotl(v[d] ^ v[a], 16);
    v[c] = _u32(v[c] + v[d]);
    v[b] = _rotl(v[b] ^ v[c], 12);
    v[a] = _u32(v[a] + v[b]);
    v[d] = _rotl(v[d] ^ v[a], 8);
    v[c] = _u32(v[c] + v[d]);
    v[b] = _rotl(v[b] ^ v[c], 7);
  }

  static void initKey256(List<int> output, Uint8List key, int offset) {
    output[0] = _char4('e'.codeUnitAt(0), 'x'.codeUnitAt(0), 'p'.codeUnitAt(0),
        'a'.codeUnitAt(0));
    output[1] = _char4('n'.codeUnitAt(0), 'd'.codeUnitAt(0), ' '.codeUnitAt(0),
        '3'.codeUnitAt(0));
    output[2] = _char4('2'.codeUnitAt(0), '-'.codeUnitAt(0), 'b'.codeUnitAt(0),
        'y'.codeUnitAt(0));
    output[3] = _char4('t'.codeUnitAt(0), 'e'.codeUnitAt(0), ' '.codeUnitAt(0),
        'k'.codeUnitAt(0));
    output[4] = _fromLittleEndian(key, offset);
    output[5] = _fromLittleEndian(key, offset + 4);
    output[6] = _fromLittleEndian(key, offset + 8);
    output[7] = _fromLittleEndian(key, offset + 12);
    output[8] = _fromLittleEndian(key, offset + 16);
    output[9] = _fromLittleEndian(key, offset + 20);
    output[10] = _fromLittleEndian(key, offset + 24);
    output[11] = _fromLittleEndian(key, offset + 28);
    output[12] = 0;
    output[13] = 0;
    output[14] = 0;
    output[15] = 0;
    _debugPrint(
        'TRACE ChaChaCore.initKey256: output words after initKey256 = [' +
            output
                .map((w) => w.toUnsigned(32).toRadixString(16).padLeft(8, '0'))
                .join(', ') +
            ']');
  }

  static void initIV(List<int> output, int iv) {
    // iv is 64-bit but we accept it as int (Dart int)
    output[12] = 0;
    output[13] = 0;
    output[14] = iv & 0xFFFFFFFF;
    output[15] = (iv >> 32) & 0xFFFFFFFF;
    // TRACE: show iv and resulting words
    _debugPrint('TRACE ChaChaCore.initIV: iv=' +
        iv.toUnsigned(64).toRadixString(16) +
        ' output[12..15]=[' +
        output[12].toUnsigned(32).toRadixString(16).padLeft(8, '0') +
        ', ' +
        output[13].toUnsigned(32).toRadixString(16).padLeft(8, '0') +
        ', ' +
        output[14].toUnsigned(32).toRadixString(16).padLeft(8, '0') +
        ', ' +
        output[15].toUnsigned(32).toRadixString(16).padLeft(8, '0') +
        ']');
  }

  static void initIVWithCounter(List<int> output, int iv, int counter) {
    output[12] = counter & 0xFFFFFFFF;
    output[13] = (counter >> 32) & 0xFFFFFFFF;
    output[14] = iv & 0xFFFFFFFF;
    output[15] = (iv >> 32) & 0xFFFFFFFF;
    _debugPrint('TRACE ChaChaCore.initIVWithCounter: iv=' +
        iv.toUnsigned(64).toRadixString(16) +
        ' counter=' +
        counter.toUnsigned(64).toRadixString(16) +
        ' output[12..15]=[' +
        output[12].toUnsigned(32).toRadixString(16).padLeft(8, '0') +
        ', ' +
        output[13].toUnsigned(32).toRadixString(16).padLeft(8, '0') +
        ', ' +
        output[14].toUnsigned(32).toRadixString(16).padLeft(8, '0') +
        ', ' +
        output[15].toUnsigned(32).toRadixString(16).padLeft(8, '0') +
        ']');
  }
}

class Poly1305 {
  late Uint8List nonce; // 16
  late Uint8List block; // 16
  late List<int> h; // 5
  late List<int> r; // 5
  late List<int> c; // 5
  late List<int> t; // 10 (use int for 64-bit intermediate)
  int posn = 0;

  Poly1305() {
    nonce = Uint8List(16);
    block = Uint8List(16);
    h = List<int>.filled(5, 0);
    r = List<int>.filled(5, 0);
    c = List<int>.filled(5, 0);
    t = List<int>.filled(10, 0);
    posn = 0;
  }

  void reset(Uint8List key, int offset) {
    for (var i = 0; i < 16; i++) nonce[i] = key[offset + 16 + i];
    for (var i = 0; i < 5; i++) h[i] = 0;
    posn = 0;

    r[0] = (key[offset] & 0xFF) |
        ((key[offset + 1] & 0xFF) << 8) |
        ((key[offset + 2] & 0xFF) << 16) |
        ((key[offset + 3] & 0x03) << 24);
    r[1] = ((key[offset + 3] & 0x0C) >> 2) |
        ((key[offset + 4] & 0xFC) << 6) |
        ((key[offset + 5] & 0xFF) << 14) |
        ((key[offset + 6] & 0x0F) << 22);
    r[2] = ((key[offset + 6] & 0xF0) >> 4) |
        ((key[offset + 7] & 0x0F) << 4) |
        ((key[offset + 8] & 0xFC) << 12) |
        ((key[offset + 9] & 0x3F) << 20);
    r[3] = ((key[offset + 9] & 0xC0) >> 6) |
        ((key[offset + 10] & 0xFF) << 2) |
        ((key[offset + 11] & 0x0F) << 10) |
        ((key[offset + 12] & 0xFC) << 18);
    r[4] = ((key[offset + 13] & 0xFF)) |
        ((key[offset + 14] & 0xFF) << 8) |
        ((key[offset + 15] & 0x0F) << 16);
  }

  void update(Uint8List data, int offset, int length) {
    while (length > 0) {
      if (posn == 0 && length >= 16) {
        _processChunk(data, offset, false);
        offset += 16;
        length -= 16;
      } else {
        var temp = 16 - posn;
        if (temp > length) temp = length;
        block.setRange(posn, posn + temp, data, offset);
        offset += temp;
        length -= temp;
        posn += temp;
        if (posn >= 16) {
          _processChunk(block, 0, false);
          posn = 0;
        }
      }
    }
  }

  void pad() {
    _debugPrint('TRACE Poly1305.pad: entering posn=$posn');
    if (posn != 0) {
      for (var i = posn; i < 16; ++i) block[i] = 0;
      _processChunk(block, 0, false);
      posn = 0;
    }
    _debugPrint('TRACE Poly1305.pad: exiting posn=$posn');
  }

  void finish(Uint8List token, int offset) {
    _debugPrint('TRACE Poly1305.finish: entering posn=$posn');
    if (posn != 0) {
      block[posn] = 1;
      for (var i = posn + 1; i < 16; ++i) block[i] = 0;
      _processChunk(block, 0, true);
    }

    // Final reduction and conversion to bytes
    var carry = ((h[4] >> 26) * 5) + h[0];
    h[0] = carry & 0x03FFFFFF;
    carry = (carry >> 26) + h[1];
    h[1] = carry & 0x03FFFFFF;
    carry = (carry >> 26) + h[2];
    h[2] = carry & 0x03FFFFFF;
    carry = (carry >> 26) + h[3];
    h[3] = carry & 0x03FFFFFF;
    h[4] = (carry >> 26) + (h[4] & 0x03FFFFFF);

    carry = 5 + h[0];
    c[0] = carry & 0x03FFFFFF;
    carry = (carry >> 26) + h[1];
    c[1] = carry & 0x03FFFFFF;
    carry = (carry >> 26) + h[2];
    c[2] = carry & 0x03FFFFFF;
    carry = (carry >> 26) + h[3];
    c[3] = carry & 0x03FFFFFF;
    c[4] = (carry >> 26) + h[4];

    var mask = -((c[4] >> 26) & 0x01);
    var nmask = ~mask;
    for (var i = 0; i < 5; ++i) {
      h[i] = (h[i] & nmask) | (c[i] & mask);
    }

    // Convert h into little-endian in block buffer
    block[0] = (h[0] & 0xFF);
    block[1] = ((h[0] >> 8) & 0xFF);
    block[2] = ((h[0] >> 16) & 0xFF);
    block[3] = (((h[0] >> 24) & 0xFF) | ((h[1] << 2) & 0xFF));
    block[4] = ((h[1] >> 6) & 0xFF);
    block[5] = ((h[1] >> 14) & 0xFF);
    block[6] = (((h[1] >> 22) & 0xFF) | ((h[2] << 4) & 0xFF));
    block[7] = ((h[2] >> 4) & 0xFF);
    block[8] = ((h[2] >> 12) & 0xFF);
    block[9] = (((h[2] >> 20) & 0xFF) | ((h[3] << 6) & 0xFF));
    block[10] = ((h[3] >> 2) & 0xFF);
    block[11] = ((h[3] >> 10) & 0xFF);
    block[12] = ((h[3] >> 18) & 0xFF);
    block[13] = (h[4] & 0xFF);
    block[14] = ((h[4] >> 8) & 0xFF);
    block[15] = ((h[4] >> 16) & 0xFF);

    // Add nonce and write token
    var carry2 = (nonce[0] & 0xFF) + (block[0] & 0xFF);
    token[offset] = carry2 & 0xFF;
    for (var x = 1; x < 16; ++x) {
      carry2 = (carry2 >> 8) + (nonce[x] & 0xFF) + (block[x] & 0xFF);
      token[offset + x] = carry2 & 0xFF;
    }
    _debugPrint('TRACE Poly1305.finish: computed tag=' +
        _hex(token.sublist(offset, offset + 16)));
  }

  void _processChunk(Uint8List chunk, int offset, bool finalChunk) {
    // Unpack 128-bit chunk into c
    c[0] = ((chunk[offset] & 0xFF)) |
        ((chunk[offset + 1] & 0xFF) << 8) |
        ((chunk[offset + 2] & 0xFF) << 16) |
        ((chunk[offset + 3] & 0x03) << 24);
    c[1] = ((chunk[offset + 3] & 0xFC) >> 2) |
        ((chunk[offset + 4] & 0xFF) << 6) |
        ((chunk[offset + 5] & 0xFF) << 14) |
        ((chunk[offset + 6] & 0x0F) << 22);
    c[2] = ((chunk[offset + 6] & 0xF0) >> 4) |
        ((chunk[offset + 7] & 0xFF) << 4) |
        ((chunk[offset + 8] & 0xFF) << 12) |
        ((chunk[offset + 9] & 0x3F) << 20);
    c[3] = ((chunk[offset + 9] & 0xC0) >> 6) |
        ((chunk[offset + 10] & 0xFF) << 2) |
        ((chunk[offset + 11] & 0xFF) << 10) |
        ((chunk[offset + 12] & 0xFF) << 18);
    c[4] = ((chunk[offset + 13] & 0xFF)) |
        ((chunk[offset + 14] & 0xFF) << 8) |
        ((chunk[offset + 15] & 0xFF) << 16);
    if (!finalChunk) c[4] |= (1 << 24);

    h[0] += c[0];
    h[1] += c[1];
    h[2] += c[2];
    h[3] += c[3];
    h[4] += c[4];

    // Multiply h by r producing t
    var hv = h[0];
    t[0] = hv * r[0];
    t[1] = hv * r[1];
    t[2] = hv * r[2];
    t[3] = hv * r[3];
    t[4] = hv * r[4];
    for (var x = 1; x < 5; ++x) {
      hv = h[x];
      t[x] = t[x] + hv * r[0];
      t[x + 1] = t[x + 1] + hv * r[1];
      t[x + 2] = t[x + 2] + hv * r[2];
      t[x + 3] = t[x + 3] + hv * r[3];
      t[x + 4] = hv * r[4];
    }

    // Propagate carries
    h[0] = (t[0]).toInt() & 0x03FFFFFF;
    hv = t[1] + ((t[0] >> 26));
    h[1] = hv.toInt() & 0x03FFFFFF;
    hv = t[2] + ((hv >> 26));
    h[2] = hv.toInt() & 0x03FFFFFF;
    hv = t[3] + ((hv >> 26));
    h[3] = hv.toInt() & 0x03FFFFFF;
    hv = t[4] + ((hv >> 26));
    h[4] = hv.toInt() & 0x03FFFFFF;
    hv = t[5] + ((hv >> 26));
    c[0] = hv.toInt() & 0x03FFFFFF;
    hv = t[6] + ((hv >> 26));
    c[1] = hv.toInt() & 0x03FFFFFF;
    hv = t[7] + ((hv >> 26));
    c[2] = hv.toInt() & 0x03FFFFFF;
    hv = t[8] + ((hv >> 26));
    c[3] = hv.toInt() & 0x03FFFFFF;
    hv = t[9] + ((hv >> 26));
    c[4] = hv.toInt();

    // Reduce h
    var carry = h[0] + c[0] * 5;
    h[0] = carry & 0x03FFFFFF;
    carry = (carry >> 26) + h[1] + c[1] * 5;
    h[1] = carry & 0x03FFFFFF;
    carry = (carry >> 26) + h[2] + c[2] * 5;
    h[2] = carry & 0x03FFFFFF;
    carry = (carry >> 26) + h[3] + c[3] * 5;
    h[3] = carry & 0x03FFFFFF;
    carry = (carry >> 26) + h[4] + c[4] * 5;
    h[4] = carry;
  }

  void destroy() {
    for (var i = 0; i < nonce.length; ++i) nonce[i] = 0;
    for (var i = 0; i < block.length; ++i) block[i] = 0;
    for (var i = 0; i < h.length; ++i) h[i] = 0;
    for (var i = 0; i < r.length; ++i) r[i] = 0;
    for (var i = 0; i < c.length; ++i) c[i] = 0;
    for (var i = 0; i < t.length; ++i) t[i] = 0;
  }
}

class ChaChaPolyCipherStatePort {
  late Poly1305 poly;
  late List<int> input;
  late List<int> output;
  late Uint8List polyKey;
  int n = 0; // using int for 64-bit counter
  bool haskey = false;

  ChaChaPolyCipherStatePort() {
    poly = Poly1305();
    input = List<int>.filled(16, 0);
    output = List<int>.filled(16, 0);
    polyKey = Uint8List(32);
    n = 0;
    haskey = false;
  }

  void destroy() {
    poly.destroy();
    for (var i = 0; i < input.length; ++i) input[i] = 0;
    for (var i = 0; i < output.length; ++i) output[i] = 0;
    for (var i = 0; i < polyKey.length; ++i) polyKey[i] = 0;
  }

  String getCipherName() => 'ChaChaPoly';
  int getKeyLength() => 32;
  int getMACLength() => haskey ? 16 : 0;

  void initializeKey(Uint8List key) {
    ChaChaCore.initKey256(input, key, 0);
    // TRACE: show internal input words after initKey256
    _debugPrint(
        'TRACE ChaChaPolyPort.initializeKey: after initKey256 input words = [' +
            input
                .map((w) => w.toUnsigned(32).toRadixString(16).padLeft(8, '0'))
                .join(', ') +
            ']');
    n = 0;
    haskey = true;
    _debugPrint('DEBUG ChaChaPolyPort.initializeKey: key=' + _hex(key));
  }

  bool hasKey() => haskey;

  void _xorBlock(Uint8List inputBuf, int inputOffset, Uint8List outBuf,
      int outOffset, int length, List<int> blockWords) {
    var posn = 0;
    int value;
    while (length >= 4) {
      value = blockWords[posn++];
      outBuf[outOffset] = (inputBuf[inputOffset] ^ (value & 0xFF)) & 0xFF;
      outBuf[outOffset + 1] =
          (inputBuf[inputOffset + 1] ^ ((value >> 8) & 0xFF)) & 0xFF;
      outBuf[outOffset + 2] =
          (inputBuf[inputOffset + 2] ^ ((value >> 16) & 0xFF)) & 0xFF;
      outBuf[outOffset + 3] =
          (inputBuf[inputOffset + 3] ^ ((value >> 24) & 0xFF)) & 0xFF;
      inputOffset += 4;
      outOffset += 4;
      length -= 4;
    }
    if (length == 3) {
      value = blockWords[posn];
      outBuf[outOffset] = (inputBuf[inputOffset] ^ (value & 0xFF)) & 0xFF;
      outBuf[outOffset + 1] =
          (inputBuf[inputOffset + 1] ^ ((value >> 8) & 0xFF)) & 0xFF;
      outBuf[outOffset + 2] =
          (inputBuf[inputOffset + 2] ^ ((value >> 16) & 0xFF)) & 0xFF;
    } else if (length == 2) {
      value = blockWords[posn];
      outBuf[outOffset] = (inputBuf[inputOffset] ^ (value & 0xFF)) & 0xFF;
      outBuf[outOffset + 1] =
          (inputBuf[inputOffset + 1] ^ ((value >> 8) & 0xFF)) & 0xFF;
    } else if (length == 1) {
      value = blockWords[posn];
      outBuf[outOffset] = (inputBuf[inputOffset] ^ (value & 0xFF)) & 0xFF;
    }
  }

  void _setup(Uint8List ad) {
    if (n == -1) throw StateError('Nonce wrapped');
    _debugPrint(
        'DEBUG ChaChaPolyPort._setup: entering n=$n ad.len=${ad?.length ?? 0}');
    // TRACE: show input words before initIV (from initializeKey)
    _debugPrint('TRACE ChaChaPolyPort._setup: input words prior to initIV = [' +
        input
            .map((w) => w.toUnsigned(32).toRadixString(16).padLeft(8, '0'))
            .join(', ') +
        ']');
    ChaChaCore.initIV(input, n++);
    _debugPrint(
        'TRACE ChaChaPolyPort._setup: after initIV with n=${_u32(n - 1)} input words = [' +
            input
                .map((w) => w.toUnsigned(32).toRadixString(16).padLeft(8, '0'))
                .join(', ') +
            ']');
    ChaChaCore.hash(output, input);
    _debugPrint('DEBUG ChaChaPolyPort._setup: output words after hash = [' +
        output
            .map((w) => w.toUnsigned(32).toRadixString(16).padLeft(8, '0'))
            .join(', ') +
        ']');
    for (var i = 0; i < 32; ++i) polyKey[i] = 0;
    // xorBlock(polyKey,0,polyKey,0,32,output)
    // output are 32-bit words; write as bytes little endian
    for (var i = 0; i < 8; ++i) {
      var word = output[i];
      polyKey[i * 4] = (word & 0xFF);
      polyKey[i * 4 + 1] = ((word >> 8) & 0xFF);
      polyKey[i * 4 + 2] = ((word >> 16) & 0xFF);
      polyKey[i * 4 + 3] = ((word >> 24) & 0xFF);
    }
    _debugPrint(
        'DEBUG ChaChaPolyPort._setup: derived polyKey=' + _hex(polyKey));
    poly.reset(polyKey, 0);
    _debugPrint('DEBUG ChaChaPolyPort._setup: poly.nonce=' + _hex(poly.nonce));
    if (ad != null) {
      _debugPrint('DEBUG ChaChaPolyPort._setup: AD (hex)=' + _hex(ad));
      poly.update(ad, 0, ad.length);
      poly.pad();
    }
    // Match Java pre-increment semantics: if (++input[12] == 0) ++input[13]
    var beforeCounter = input[12];
    input[12] = _u32(input[12] + 1);
    if (input[12] == 0) input[13] = _u32(input[13] + 1);
    _debugPrint(
        'DEBUG ChaChaPolyPort._setup: counter before=$beforeCounter after=${input[12]} carry=${input[13]} n=${n}');
  }

  void _putLittleEndian64(Uint8List outputBuf, int offset, int value) {
    // value might be larger than 32-bit; write 8 bytes LE
    var v = value;
    outputBuf[offset] = v & 0xFF;
    outputBuf[offset + 1] = (v >> 8) & 0xFF;
    outputBuf[offset + 2] = (v >> 16) & 0xFF;
    outputBuf[offset + 3] = (v >> 24) & 0xFF;
    outputBuf[offset + 4] = (v >> 32) & 0xFF;
    outputBuf[offset + 5] = (v >> 40) & 0xFF;
    outputBuf[offset + 6] = (v >> 48) & 0xFF;
    outputBuf[offset + 7] = (v >> 56) & 0xFF;
  }

  void _finish(Uint8List ad, int length) {
    _debugPrint(
        'TRACE ChaChaPolyPort._finish: entering poly.posn=${poly.posn}');
    poly.pad();
    _putLittleEndian64(polyKey, 0, ad != null ? ad.length : 0);
    _putLittleEndian64(polyKey, 8, length);
    _debugPrint('DEBUG ChaChaPolyPort._finish: polyKey before finish=' +
        _hex(polyKey) +
        ' ad.len=${ad?.length ?? 0} length=$length');
    _debugPrint('DEBUG ChaChaPolyPort._finish: poly.nonce=' + _hex(poly.nonce));
    poly.update(polyKey, 0, 16);
    poly.finish(polyKey, 0);
    _debugPrint('DEBUG ChaChaPolyPort._finish: computedTag=' +
        _hex(polyKey.sublist(0, 16)) +
        ' poly.posn=${poly.posn}');
  }

  Uint8List encryptWithAd(Uint8List ad, Uint8List plaintext) {
    if (!haskey) return Uint8List.fromList(plaintext);
    final out = Uint8List(plaintext.length + 16);
    _setup(ad);
    // encrypt
    var remaining = plaintext.length;
    var inOffset = 0;
    var outOffset = 0;
    var blockCount = 0;
    while (remaining > 0) {
      var tempLen = 64;
      if (tempLen > remaining) tempLen = remaining;
      ChaChaCore.hash(output, input);
      // Print counter and output words for the first block only to reduce noise
      if (blockCount == 0) {
        _debugPrint('TRACE ChaChaPolyPort.encrypt: counter input words=[' +
            input
                .map((w) => w.toUnsigned(32).toRadixString(16).padLeft(8, '0'))
                .join(', ') +
            ']');
        _debugPrint('TRACE ChaChaPolyPort.encrypt: output words=[' +
            output
                .map((w) => w.toUnsigned(32).toRadixString(16).padLeft(8, '0'))
                .join(', ') +
            ']');
      }
      _xorBlock(plaintext, inOffset, out, outOffset, tempLen, output);
      input[12] = _u32(input[12] + 1);
      if (input[12] == 0) input[13] = _u32(input[13] + 1);
      inOffset += tempLen;
      outOffset += tempLen;
      remaining -= tempLen;
      blockCount++;
    }
    // poly update with ciphertext
    poly.update(out, 0, plaintext.length);
    _finish(ad, plaintext.length);
    // append tag
    out.setRange(
        plaintext.length, plaintext.length + 16, polyKey.sublist(0, 16));
    return out;
  }

  Uint8List decryptWithAd(Uint8List ad, Uint8List ciphertextWithTag) {
    if (!haskey) return Uint8List.fromList(ciphertextWithTag);
    if (ciphertextWithTag.length < 16) throw StateError('Ciphertext too short');
    final dataLen = ciphertextWithTag.length - 16;
    _setup(ad);
    // poly update with ciphertext
    poly.update(ciphertextWithTag, 0, dataLen);
    _finish(ad, dataLen);
    // compare tags
    var bad = 0;
    // DEBUG: show computed tag and incoming tag
    var computedTag = polyKey.sublist(0, 16);
    var incomingTag = ciphertextWithTag.sublist(dataLen, dataLen + 16);
    // print to help diagnose parity issues
    _debugPrint(
        'DEBUG ChaChaPolyPort: computedTag=${_hex(computedTag)} incomingTag=${_hex(incomingTag)} ad.len=${ad?.length ?? 0} dataLen=$dataLen n=${n}');
    for (var i = 0; i < 16; ++i) {
      bad |= (polyKey[i] ^ ciphertextWithTag[dataLen + i]);
    }
    if ((bad & 0xFF) != 0) throw StateError('Bad tag');
    // decrypt by xoring
    final out = Uint8List(dataLen);
    var remaining = dataLen;
    var inOffset = 0;
    var outOffset = 0;
    while (remaining > 0) {
      var tempLen = 64;
      if (tempLen > remaining) tempLen = remaining;
      ChaChaCore.hash(output, input);
      _xorBlock(ciphertextWithTag, inOffset, out, outOffset, tempLen, output);
      input[12] = _u32(input[12] + 1);
      if (input[12] == 0) input[13] = _u32(input[13] + 1);
      inOffset += tempLen;
      outOffset += tempLen;
      remaining -= tempLen;
    }
    return out;
  }

  ChaChaPolyCipherStatePort fork(Uint8List key) {
    final c = ChaChaPolyCipherStatePort();
    c.initializeKey(key);
    return c;
  }

  void setNonce(int nonce) {
    n = nonce;
  }
}
