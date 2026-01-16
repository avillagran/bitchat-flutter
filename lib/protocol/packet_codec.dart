import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:bitchat/data/models/routed_packet.dart';
import 'package:bitchat/protocol/message_padding.dart';

class PacketCodec {
  // V1 header: version(1) + type(1) + ttl(1) + timestamp(8) + flags(1) + payloadLength(2) = 14
  static const int headerSizeV1 = 14;
  // V2 header: version(1) + type(1) + ttl(1) + timestamp(8) + flags(1) + payloadLength(4) = 16
  static const int headerSizeV2 = 16;
  static const int senderIdSize = 8;
  static const int recipientIdSize = 8;
  static const int signatureSize = 64;

  static const int flagHasRecipient = 0x01;
  static const int flagHasSignature = 0x02;
  static const int flagIsCompressed = 0x04;
  static const int flagHasRoute = 0x08;

  static int getHeaderSize(int version) {
    return version == 1 ? headerSizeV1 : headerSizeV2;
  }

  static Uint8List? encode(
    BitchatPacket packet, {
    required Uint8List senderID,
    Uint8List? recipientID,
    Uint8List? signature,
    bool isCompressed = false,
    int? originalSize,
  }) {
    try {
      final payload = packet.payload ?? Uint8List(0);
      final version = packet.version;
      final headerSize = getHeaderSize(version);

      bool hasRecipient = recipientID != null;
      bool hasSignature = signature != null && signature.length == signatureSize;

      final recipientBytes = hasRecipient ? recipientIdSize : 0;
      final signatureBytes = hasSignature ? signatureSize : 0;
      final sizeFieldBytes = isCompressed ? (version >= 2 ? 4 : 2) : 0;
      final payloadBytes = payload.length + sizeFieldBytes;

      final capacity =
          headerSize + senderIdSize + recipientBytes + payloadBytes + signatureBytes;
      final result = Uint8List(capacity);
      final buf = ByteData.view(result.buffer);
      int off = 0;

      // Header
      buf.setUint8(off++, version);
      buf.setUint8(off++, packet.type);
      buf.setUint8(off++, packet.ttl);

      buf.setUint64(off, packet.timestamp.millisecondsSinceEpoch, Endian.big);
      off += 8;

      // Flags
      int flags = 0;
      if (hasRecipient) flags |= flagHasRecipient;
      if (hasSignature) flags |= flagHasSignature;
      if (isCompressed) flags |= flagIsCompressed;
      buf.setUint8(off++, flags);

      // Payload length (version-dependent)
      if (version >= 2) {
        buf.setUint32(off, payloadBytes, Endian.big);
        off += 4;
      } else {
        buf.setUint16(off, payloadBytes, Endian.big);
        off += 2;
      }

      // SenderID
      result.setRange(off, off + 8, senderID.sublist(0, 8));
      off += 8;

      // RecipientID
      if (hasRecipient) {
        result.setRange(off, off + 8, recipientID!.sublist(0, 8));
        off += 8;
      }

      // Payload
      if (isCompressed && originalSize != null) {
        if (version >= 2) {
          buf.setUint32(off, originalSize, Endian.big);
          off += 4;
        } else {
          buf.setUint16(off, originalSize, Endian.big);
          off += 2;
        }
      }

      result.setRange(off, off + payload.length, payload);
      off += payload.length;

      // Signature (at the end, after payload)
      if (hasSignature) {
        result.setRange(off, off + signatureSize, signature!);
      }

      return result;
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('[PacketCodec.encode] ERROR: $e\n$stackTrace');
      return null;
    }
  }

  /// Encodes a packet for signing (without signature, with TTL=0 for relay compatibility).
  /// This matches Android's BitchatPacket.toBinaryDataForSigning() behavior.
  /// IMPORTANT: Applies PKCS#7 padding to match Android's encode() which pads for signing.
  static Uint8List? encodeForSigning(
    BitchatPacket packet, {
    required Uint8List senderID,
    Uint8List? recipientID,
  }) {
    // Create a copy with TTL=0 and no signature for signing
    final signingPacket = BitchatPacket(
      version: packet.version,
      type: packet.type,
      ttl: 0, // Fixed TTL for signing to ensure relay compatibility
      timestamp: packet.timestamp,
      senderID: senderID,
      recipientID: recipientID,
      payload: packet.payload,
      signature: null, // No signature when encoding for signing
      route: packet.route,
    );
    final raw = encode(
      signingPacket,
      senderID: senderID,
      recipientID: recipientID,
      signature: null,
    );
    if (raw == null) return null;

    // Apply PKCS#7 padding to match Android's BinaryProtocol.encode() behavior
    // Android pads all encoded packets (including those for signing) for traffic analysis resistance
    final optimalSize = MessagePadding.optimalBlockSize(raw.length);
    return MessagePadding.pad(raw, optimalSize);
  }

  /// Decodes a packet from binary data.
  /// First tries to decode as-is, then tries after removing PKCS#7 padding.
  /// This matches Android's BinaryProtocol.decode() behavior.
  static BitchatPacket? decode(Uint8List data) {
    debugPrint('[PacketCodec] ========================================');
    debugPrint('[PacketCodec] decode() CALLED');
    debugPrint('[PacketCodec] Input size: ${data.length} bytes');
    debugPrint('[PacketCodec] First 30 bytes: ${data.take(30).toList()}');
    debugPrint('[PacketCodec] ========================================');

    // Try decode as-is first (robust when padding wasn't applied)
    debugPrint('[PacketCodec] Attempting direct decode...');
    final direct = _decodeCore(data);
    if (direct != null) {
      debugPrint('[PacketCodec] Direct decode SUCCESS');
      debugPrint(
          '[PacketCodec] Decoded type: 0x${direct.type.toRadixString(16)}');
      debugPrint(
          '[PacketCodec] Decoded payload: ${direct.payload?.length ?? 0} bytes');
      return direct;
    }
    debugPrint('[PacketCodec] Direct decode FAILED');

    // If that fails, try after removing padding
    debugPrint('[PacketCodec] Attempting unpad then decode...');
    final unpadded = MessagePadding.unpad(data);
    debugPrint(
        '[PacketCodec] After unpad: ${unpadded.length} bytes (was ${data.length})');

    if (unpadded.length == data.length) {
      // No padding was removed, already failed
      debugPrint('[PacketCodec] No padding removed, decode FAILED');
      return null;
    }

    final unpaddedResult = _decodeCore(unpadded);
    if (unpaddedResult != null) {
      debugPrint('[PacketCodec] Unpadded decode SUCCESS');
      debugPrint(
          '[PacketCodec] Decoded type: 0x${unpaddedResult.type.toRadixString(16)}');
      return unpaddedResult;
    }

    debugPrint('[PacketCodec] Unpadded decode also FAILED');
    return null;
  }

  /// Core decoding implementation.
  static BitchatPacket? _decodeCore(Uint8List data) {
    try {
      debugPrint('[PacketCodec._decodeCore] Input size: ${data.length}');

      if (data.length < headerSizeV1 + senderIdSize) {
        debugPrint(
            '[PacketCodec._decodeCore] FAIL: too short (need ${headerSizeV1 + senderIdSize}, got ${data.length})');
        return null;
      }

      final buf = ByteData.sublistView(data);
      int off = 0;

      final version = buf.getUint8(off++);
      debugPrint('[PacketCodec._decodeCore] Version: $version');

      if (version != 1 && version != 2) {
        debugPrint('[PacketCodec._decodeCore] FAIL: invalid version $version');
        return null;
      }

      final headerSize = getHeaderSize(version);
      final type = buf.getUint8(off++);
      final ttl = buf.getUint8(off++);
      final timestampMs = buf.getUint64(off, Endian.big);
      final timestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
      off += 8;

      final flags = buf.getUint8(off++);
      final hasRecipient = (flags & flagHasRecipient) != 0;
      final hasSignature = (flags & flagHasSignature) != 0;
      final isCompressed = (flags & flagIsCompressed) != 0;
      final hasRoute = (version >= 2) && (flags & flagHasRoute) != 0;

      debugPrint(
          '[PacketCodec._decodeCore] Type: 0x${type.toRadixString(16)}, TTL: $ttl, Flags: 0x${flags.toRadixString(16)}');
      debugPrint(
          '[PacketCodec._decodeCore] hasRecipient: $hasRecipient, hasSignature: $hasSignature, isCompressed: $isCompressed');

      final int payloadLength;
      if (version >= 2) {
        payloadLength = buf.getUint32(off, Endian.big);
        off += 4;
      } else {
        payloadLength = buf.getUint16(off, Endian.big);
        off += 2;
      }
      debugPrint('[PacketCodec._decodeCore] Payload length: $payloadLength');

      // Calculate expected size for validation
      int expectedSize = headerSize + senderIdSize + payloadLength;
      if (hasRecipient) expectedSize += recipientIdSize;
      if (hasSignature) expectedSize += signatureSize;

      // For route, we need to peek at the count
      int routeCount = 0;
      if (hasRoute) {
        final routeOffset =
            headerSize + senderIdSize + (hasRecipient ? recipientIdSize : 0);
        if (data.length > routeOffset) {
          routeCount = data[routeOffset] & 0xFF;
        }
        expectedSize += 1 + (routeCount * senderIdSize);
      }

      debugPrint(
          '[PacketCodec._decodeCore] Expected size: $expectedSize, actual: ${data.length}');

      if (data.length < expectedSize) {
        debugPrint('[PacketCodec._decodeCore] FAIL: data too short');
        return null;
      }

      // SenderID
      final senderID = Uint8List.sublistView(data, off, off + senderIdSize);
      off += senderIdSize;
      debugPrint(
          '[PacketCodec._decodeCore] SenderID: ${senderID.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');

      // RecipientID
      Uint8List? recipientID;
      if (hasRecipient) {
        recipientID = Uint8List.sublistView(data, off, off + recipientIdSize);
        off += recipientIdSize;
      }

      // Route (optional, v2+ only)
      List<Uint8List>? route;
      if (hasRoute) {
        final count = data[off++] & 0xFF;
        if (count > 0) {
          route = <Uint8List>[];
          for (var i = 0; i < count; i++) {
            route.add(Uint8List.sublistView(data, off, off + senderIdSize));
            off += senderIdSize;
          }
        }
      }

      // Payload
      Uint8List payload;
      if (isCompressed) {
        final lenField = version >= 2 ? 4 : 2;
        if (payloadLength < lenField) {
          debugPrint(
              '[PacketCodec._decodeCore] FAIL: compressed payload too short');
          return null;
        }

        // Skip original size field (we don't decompress here)
        off += lenField;
        final compressedSize = payloadLength - lenField;
        payload = Uint8List.sublistView(data, off, off + compressedSize);
        off += compressedSize;
      } else {
        payload = Uint8List.sublistView(data, off, off + payloadLength);
        off += payloadLength;
      }
      debugPrint(
          '[PacketCodec._decodeCore] Extracted payload: ${payload.length} bytes');

      // Signature (optional)
      Uint8List? signature;
      if (hasSignature) {
        signature = Uint8List.sublistView(data, off, off + signatureSize);
        off += signatureSize;
      }

      debugPrint('[PacketCodec._decodeCore] SUCCESS - returning BitchatPacket');
      return BitchatPacket(
        version: version,
        type: type,
        ttl: ttl,
        timestamp: timestamp,
        senderID: senderID,
        recipientID: recipientID,
        payload: payload,
        signature: signature,
        route: route,
      );
    } catch (e, stack) {
      debugPrint('[PacketCodec._decodeCore] EXCEPTION: $e');
      debugPrint('[PacketCodec._decodeCore] Stack: $stack');
      return null;
    }
  }
}
