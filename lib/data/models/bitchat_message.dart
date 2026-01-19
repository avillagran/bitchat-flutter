import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:bitchat/core/json_converters.dart';

part 'bitchat_message.freezed.dart';
part 'bitchat_message.g.dart';

enum BitchatMessageType { Message, Audio, Image, File }

@freezed
class DeliveryStatus with _$DeliveryStatus {
  const factory DeliveryStatus.sending() = Sending;
  const factory DeliveryStatus.sent() = Sent;
  const factory DeliveryStatus.delivered({
    required String to,
    required DateTime at,
  }) = Delivered;
  const factory DeliveryStatus.read({
    required String by,
    required DateTime at,
  }) = Read;
  const factory DeliveryStatus.failed({required String reason}) = Failed;
  const factory DeliveryStatus.partiallyDelivered({
    required int reached,
    required int total,
  }) = PartiallyDelivered;

  factory DeliveryStatus.fromJson(Map<String, dynamic> json) =>
      _$DeliveryStatusFromJson(json);
}

@freezed
class BitchatMessage with _$BitchatMessage {
  const factory BitchatMessage({
    @Default('') String id,
    required String sender,
    @Default('') String content,
    @Default(BitchatMessageType.Message) BitchatMessageType type,
    required DateTime timestamp,
    @Default(false) bool isRelay,
    String? originalSender,
    @Default(false) bool isPrivate,
    String? recipientNickname,
    String? senderPeerID,
    List<String>? mentions,
    String? channel,
    @Uint8ListBase64Converter() Uint8List? encryptedContent,
    @Default(false) bool isEncrypted,
    DeliveryStatus? deliveryStatus,
    int? powDifficulty,
    int? rssi,
  }) = _BitchatMessage;

  factory BitchatMessage.fromJson(Map<String, dynamic> json) =>
      _$BitchatMessageFromJson(json);

  // Binary serialization compatible with Android implementation
  static Uint8List? toBinaryPayload(BitchatMessage msg) {
    try {
      final bytes = BytesBuilder();

      int flags = 0;
      if (msg.isRelay) flags |= 0x01;
      if (msg.isPrivate) flags |= 0x02;
      if (msg.originalSender != null) flags |= 0x04;
      if (msg.recipientNickname != null) flags |= 0x08;
      if (msg.senderPeerID != null) flags |= 0x10;
      if (msg.mentions != null && msg.mentions!.isNotEmpty) flags |= 0x20;
      if (msg.channel != null) flags |= 0x40;
      if (msg.isEncrypted) flags |= 0x80;

      bytes.addByte(flags);

      // Timestamp 8 bytes big-endian
      final ts = msg.timestamp.millisecondsSinceEpoch;
      final tsBuf = ByteData(8);
      tsBuf.setInt64(0, ts, Endian.big);
      bytes.add(tsBuf.buffer.asUint8List());

      // ID
      final idBytes = utf8.encode(msg.id);
      bytes.addByte(idBytes.length.clamp(0, 255));
      bytes.add(idBytes.sublist(0, idBytes.length.clamp(0, 255)));

      // Sender
      final senderBytes = utf8.encode(msg.sender);
      bytes.addByte(senderBytes.length.clamp(0, 255));
      bytes.add(senderBytes.sublist(0, senderBytes.length.clamp(0, 255)));

      // Content or encrypted content
      if (msg.isEncrypted && msg.encryptedContent != null) {
        final len = msg.encryptedContent!.length.clamp(0, 65535);
        final lenBuf = ByteData(2);
        lenBuf.setUint16(0, len, Endian.big);
        bytes.add(lenBuf.buffer.asUint8List());
        bytes.add(msg.encryptedContent!.sublist(0, len));
      } else {
        final contentBytes = utf8.encode(msg.content);
        final len = contentBytes.length.clamp(0, 65535);
        final lenBuf = ByteData(2);
        lenBuf.setUint16(0, len, Endian.big);
        bytes.add(lenBuf.buffer.asUint8List());
        bytes.add(contentBytes.sublist(0, len));
      }

      // Optional originalSender
      if (msg.originalSender != null) {
        final o = utf8.encode(msg.originalSender!);
        bytes.addByte(o.length.clamp(0, 255));
        bytes.add(o.sublist(0, o.length.clamp(0, 255)));
      }

      // recipientNickname
      if (msg.recipientNickname != null) {
        final r = utf8.encode(msg.recipientNickname!);
        bytes.addByte(r.length.clamp(0, 255));
        bytes.add(r.sublist(0, r.length.clamp(0, 255)));
      }

      // senderPeerID
      if (msg.senderPeerID != null) {
        final p = utf8.encode(msg.senderPeerID!);
        bytes.addByte(p.length.clamp(0, 255));
        bytes.add(p.sublist(0, p.length.clamp(0, 255)));
      }

      // mentions array
      if (msg.mentions != null && msg.mentions!.isNotEmpty) {
        bytes.addByte(msg.mentions!.length.clamp(0, 255));
        for (final mention in msg.mentions!) {
          final m = utf8.encode(mention);
          bytes.addByte(m.length.clamp(0, 255));
          bytes.add(m.sublist(0, m.length.clamp(0, 255)));
        }
      }

      // channel
      if (msg.channel != null) {
        final c = utf8.encode(msg.channel!);
        bytes.addByte(c.length.clamp(0, 255));
        bytes.add(c.sublist(0, c.length.clamp(0, 255)));
      }

      return bytes.toBytes();
    } catch (e) {
      return null;
    }
  }

  static BitchatMessage? fromBinaryPayload(Uint8List data) {
    debugPrint('[BitchatMessage] ========================================');
    debugPrint('[BitchatMessage] fromBinaryPayload CALLED');
    debugPrint('[BitchatMessage] Input size: ${data.length} bytes');
    debugPrint('[BitchatMessage] First 30 bytes: ${data.take(30).toList()}');
    debugPrint('[BitchatMessage] ========================================');

    try {
      if (data.isEmpty) {
        debugPrint('[BitchatMessage] FAIL: data is empty');
        return null;
      }

      // Try structured binary format first (Flutter-to-Flutter)
      if (data.length >= 13) {
        debugPrint('[BitchatMessage] Trying structured format (len >= 13)...');
        final structured = _parseStructuredPayload(data);
        if (structured != null) {
          debugPrint('[BitchatMessage] Structured format SUCCESS');
          debugPrint(
              '[BitchatMessage] Parsed content: "${structured.content}"');
          return structured;
        }
        debugPrint('[BitchatMessage] Structured format FAILED');
      }

      // Fallback: Android sends plain UTF-8 text as payload
      // Try to decode as plain UTF-8 string
      debugPrint('[BitchatMessage] Trying plain UTF-8 fallback...');
      try {
        final content = utf8.decode(data, allowMalformed: false);
        debugPrint('[BitchatMessage] UTF-8 decode SUCCESS');
        debugPrint('[BitchatMessage] Content: "$content"');

        // Generate unique ID: timestamp + content hash + random suffix
        // This ensures different messages with same content get unique IDs
        final now = DateTime.now();
        final timestamp = now.millisecondsSinceEpoch;
        final contentHash = (content.hashCode.abs() % 10000).toString().padLeft(4, '0');
        final randomSuffix = (now.microsecond % 1000).toString().padLeft(3, '0');
        final uniqueId = 'android-$timestamp-$contentHash-$randomSuffix';

        debugPrint('[BitchatMessage] Generated unique ID: $uniqueId');

        return BitchatMessage(
          id: uniqueId,
          sender: '', // Will be filled by caller from packet senderID
          content: content,
          type: BitchatMessageType.Message,
          timestamp: now,
        );
      } catch (e) {
        debugPrint('[BitchatMessage] UTF-8 decode FAILED: $e');
        debugPrint(
            '[BitchatMessage] Raw bytes as hex: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
        // Not valid UTF-8, return null
        return null;
      }
    } catch (e, stack) {
      debugPrint('[BitchatMessage] EXCEPTION: $e');
      debugPrint('[BitchatMessage] Stack: $stack');
      return null;
    }
  }

  /// Parse the structured binary format (Flutter-to-Flutter messages)
  static BitchatMessage? _parseStructuredPayload(Uint8List data) {
    try {
      final buf = ByteData.sublistView(data);
      int offset = 0;
      final flags = buf.getUint8(offset);
      offset += 1;

      debugPrint(
          '[BitchatMessage._parseStructured] Flags: 0x${flags.toRadixString(16)}');

      final isRelay = (flags & 0x01) != 0;
      final isPrivate = (flags & 0x02) != 0;
      final hasOriginalSender = (flags & 0x04) != 0;
      final hasRecipientNickname = (flags & 0x08) != 0;
      final hasSenderPeerID = (flags & 0x10) != 0;
      final hasMentions = (flags & 0x20) != 0;
      final hasChannel = (flags & 0x40) != 0;
      final isEncrypted = (flags & 0x80) != 0;

      debugPrint(
          '[BitchatMessage._parseStructured] isRelay=$isRelay, isPrivate=$isPrivate, hasChannel=$hasChannel, isEncrypted=$isEncrypted');

      final ts = buf.getInt64(offset, Endian.big);
      offset += 8;
      final timestamp = DateTime.fromMillisecondsSinceEpoch(ts);
      debugPrint('[BitchatMessage._parseStructured] Timestamp: $timestamp');

      final idLength = buf.getUint8(offset);
      offset += 1;
      debugPrint('[BitchatMessage._parseStructured] ID length: $idLength');
      if (data.length < offset + idLength) {
        debugPrint(
            '[BitchatMessage._parseStructured] FAIL: not enough data for ID');
        return null;
      }
      final id = utf8.decode(data.sublist(offset, offset + idLength));
      offset += idLength;
      debugPrint('[BitchatMessage._parseStructured] ID: "$id"');

      final senderLength = buf.getUint8(offset);
      offset += 1;
      debugPrint(
          '[BitchatMessage._parseStructured] Sender length: $senderLength');
      if (data.length < offset + senderLength) {
        debugPrint(
            '[BitchatMessage._parseStructured] FAIL: not enough data for sender');
        return null;
      }
      final sender = utf8.decode(data.sublist(offset, offset + senderLength));
      offset += senderLength;
      debugPrint('[BitchatMessage._parseStructured] Sender: "$sender"');

      final contentLength = buf.getUint16(offset, Endian.big);
      offset += 2;
      debugPrint(
          '[BitchatMessage._parseStructured] Content length: $contentLength');
      if (data.length < offset + contentLength) {
        debugPrint(
            '[BitchatMessage._parseStructured] FAIL: not enough data for content');
        return null;
      }

      String content = '';
      Uint8List? encryptedContent;
      if (isEncrypted) {
        encryptedContent = data.sublist(offset, offset + contentLength);
        offset += contentLength;
        debugPrint(
            '[BitchatMessage._parseStructured] Encrypted content: ${encryptedContent.length} bytes');
      } else {
        content = utf8.decode(data.sublist(offset, offset + contentLength));
        offset += contentLength;
        debugPrint('[BitchatMessage._parseStructured] Content: "$content"');
      }

      String? originalSender;
      if (hasOriginalSender && offset < data.length) {
        final len = data[offset];
        offset += 1;
        if (data.length >= offset + len) {
          originalSender = utf8.decode(data.sublist(offset, offset + len));
          offset += len;
        }
      }

      String? recipientNickname;
      if (hasRecipientNickname && offset < data.length) {
        final len = data[offset];
        offset += 1;
        if (data.length >= offset + len) {
          recipientNickname = utf8.decode(data.sublist(offset, offset + len));
          offset += len;
        }
      }

      String? senderPeerID;
      if (hasSenderPeerID && offset < data.length) {
        final len = data[offset];
        offset += 1;
        if (data.length >= offset + len) {
          senderPeerID = utf8.decode(data.sublist(offset, offset + len));
          offset += len;
        }
      }

      List<String>? mentions;
      if (hasMentions && offset < data.length) {
        final mentionCount = data[offset];
        offset += 1;
        final mList = <String>[];
        for (int i = 0; i < mentionCount; i++) {
          if (offset >= data.length) break;
          final len = data[offset];
          offset += 1;
          if (data.length >= offset + len) {
            mList.add(utf8.decode(data.sublist(offset, offset + len)));
            offset += len;
          }
        }
        if (mList.isNotEmpty) mentions = mList;
      }

      String? channel;
      if (hasChannel && offset < data.length) {
        final len = data[offset];
        offset += 1;
        if (data.length >= offset + len) {
          channel = utf8.decode(data.sublist(offset, offset + len));
          offset += len;
          debugPrint('[BitchatMessage._parseStructured] Channel: "$channel"');
        }
      }

      debugPrint(
          '[BitchatMessage._parseStructured] SUCCESS - returning message');
      return BitchatMessage(
        id: id,
        sender: sender,
        content: content,
        type: BitchatMessageType.Message,
        timestamp: timestamp,
        isRelay: isRelay,
        originalSender: originalSender,
        isPrivate: isPrivate,
        recipientNickname: recipientNickname,
        senderPeerID: senderPeerID,
        mentions: mentions,
        channel: channel,
        encryptedContent: encryptedContent,
        isEncrypted: isEncrypted,
      );
    } catch (e, stack) {
      debugPrint('[BitchatMessage._parseStructured] EXCEPTION: $e');
      debugPrint('[BitchatMessage._parseStructured] Stack: $stack');
      return null;
    }
  }
}
