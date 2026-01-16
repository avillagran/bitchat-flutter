import 'dart:convert';
import 'dart:typed_data';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:bitchat/core/json_converters.dart';

part 'noise_encrypted.freezed.dart';
part 'noise_encrypted.g.dart';

enum NoisePayloadType {
  privateMessage(0x01),
  readReceipt(0x02),
  delivered(0x03),
  verifyChallenge(0x10),
  verifyResponse(0x11),
  fileTransfer(0x20);

  final int value;
  const NoisePayloadType(this.value);

  static NoisePayloadType? fromValue(int value) {
    for (var type in NoisePayloadType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

@freezed
class NoisePayload with _$NoisePayload {
  const factory NoisePayload({
    required NoisePayloadType type,
    @Uint8ListBase64Converter() Uint8List? data,
  }) = _NoisePayload;

  factory NoisePayload.fromJson(Map<String, dynamic> json) =>
      _$NoisePayloadFromJson(json);

  const NoisePayload._();

  Uint8List encode() {
    final dataBytes = data ?? Uint8List(0);
    final result = Uint8List(1 + dataBytes.length);
    result[0] = type.value & 0xFF;
    result.setRange(1, result.length, dataBytes);
    return result;
  }

  static NoisePayload? decode(Uint8List data) {
    if (data.isEmpty) return null;
    final typeValue = data[0];
    final type = NoisePayloadType.fromValue(typeValue);
    if (type == null) return null;

    final payloadData = data.length > 1 ? data.sublist(1) : Uint8List(0);
    return NoisePayload(type: type, data: payloadData);
  }
}

@freezed
class PrivateMessagePacket with _$PrivateMessagePacket {
  const factory PrivateMessagePacket({
    required String messageID,
    required String content,
  }) = _PrivateMessagePacket;

  factory PrivateMessagePacket.fromJson(Map<String, dynamic> json) =>
      _$PrivateMessagePacketFromJson(json);

  const PrivateMessagePacket._();

  Uint8List? encode() {
    try {
      final idData = utf8.encode(messageID);
      final contentData = utf8.encode(content);

      if (idData.length > 255 || contentData.length > 255) return null;

      final result = <int>[];
      // TLV for messageID (0x00)
      result.add(0x00);
      result.add(idData.length);
      result.addAll(idData);

      // TLV for content (0x01)
      result.add(0x01);
      result.add(contentData.length);
      result.addAll(contentData);

      return Uint8List.fromList(result);
    } catch (e) {
      return null;
    }
  }

  static PrivateMessagePacket? decode(Uint8List data) {
    try {
      int offset = 0;
      String? messageID;
      String? content;

      while (offset + 2 <= data.length) {
        final type = data[offset++];
        final len = data[offset++];

        if (offset + len > data.length) return null;
        final value = data.sublist(offset, offset + len);
        offset += len;

        switch (type) {
          case 0x00:
            messageID = utf8.decode(value);
            break;
          case 0x01:
            content = utf8.decode(value);
            break;
        }
      }

      if (messageID != null && content != null) {
        return PrivateMessagePacket(messageID: messageID, content: content);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

@freezed
class NoiseEncrypted with _$NoiseEncrypted {
  const factory NoiseEncrypted({
    @Uint8ListBase64Converter() Uint8List? ephemeralKey,
    @Uint8ListBase64Converter() Uint8List? ciphertext,
  }) = _NoiseEncrypted;

  factory NoiseEncrypted.fromJson(Map<String, dynamic> json) =>
      _$NoiseEncryptedFromJson(json);
}
