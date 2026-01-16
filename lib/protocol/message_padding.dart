import 'dart:typed_data';

/// Privacy-preserving padding utilities - matches Android/iOS implementation.
/// Provides traffic analysis resistance by normalizing message sizes.
class MessagePadding {
  /// Standard block sizes for padding - matches Android/iOS
  static const List<int> _blockSizes = [256, 512, 1024, 2048];

  /// Find optimal block size for data - matches Android/iOS logic
  static int optimalBlockSize(int dataSize) {
    // Account for encryption overhead (~16 bytes for AES-GCM tag)
    final totalSize = dataSize + 16;

    // Find smallest block that fits
    for (final blockSize in _blockSizes) {
      if (totalSize <= blockSize) {
        return blockSize;
      }
    }

    // For very large messages, just use the original size
    // (will be fragmented anyway)
    return dataSize;
  }

  /// Add PKCS#7-style padding to reach target size.
  /// All pad bytes are equal to the padding length.
  static Uint8List pad(Uint8List data, int targetSize) {
    if (data.length >= targetSize) return data;

    final paddingNeeded = targetSize - data.length;

    // Constrain to 255 to fit a single-byte pad length marker
    if (paddingNeeded <= 0 || paddingNeeded > 255) return data;

    final result = Uint8List(targetSize);

    // Copy original data
    result.setRange(0, data.length, data);

    // PKCS#7: All pad bytes are equal to the pad length
    for (var i = data.length; i < targetSize; i++) {
      result[i] = paddingNeeded;
    }

    return result;
  }

  /// Remove PKCS#7 padding from data.
  /// Returns original data if padding is invalid.
  static Uint8List unpad(Uint8List data) {
    if (data.isEmpty) return data;

    final last = data[data.length - 1];
    final paddingLength = last & 0xFF;

    // Must have at least 1 pad byte and not exceed data length
    if (paddingLength <= 0 || paddingLength > data.length) return data;

    // Verify PKCS#7: all last N bytes equal to pad length
    final start = data.length - paddingLength;
    for (var i = start; i < data.length; i++) {
      if (data[i] != last) {
        return data; // Invalid padding, return original
      }
    }

    return Uint8List.sublistView(data, 0, start);
  }
}
