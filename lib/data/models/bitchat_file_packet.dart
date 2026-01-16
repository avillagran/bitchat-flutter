import 'dart:convert';
import 'dart:typed_data';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:bitchat/core/json_converters.dart';

part 'bitchat_file_packet.freezed.dart';
part 'bitchat_file_packet.g.dart';

@freezed
class BitchatFilePacket with _$BitchatFilePacket {
  const factory BitchatFilePacket({
    required String fileName,
    required int fileSize,
    required String mimeType,
    @Uint8ListBase64Converter() Uint8List? content,
  }) = _BitchatFilePacket;

  factory BitchatFilePacket.fromJson(Map<String, dynamic> json) =>
      _$BitchatFilePacketFromJson(json);

  const BitchatFilePacket._();

  Uint8List? encode() {
    try {
      final nameBytes = utf8.encode(fileName);
      final mimeBytes = utf8.encode(mimeType);
      final contentBytes = content ?? Uint8List(0);

      if (nameBytes.length > 0xFFFF || mimeBytes.length > 0xFFFF) {
        return null;
      }

      // Exact layout from Android:
      // FILE_NAME (1b type, 2b len, data)
      // FILE_SIZE (1b type, 2b len=4, 4b value)
      // MIME_TYPE (1b type, 2b len, data)
      // CONTENT (1b type, 4b len, data)

      const sizeFieldLen = 4;
      const contentLenFieldLen = 4;

      final capacity = (1 + 2 + nameBytes.length) +
          (1 + 2 + sizeFieldLen) +
          (1 + 2 + mimeBytes.length) +
          (1 + contentLenFieldLen + contentBytes.length);

      final result = Uint8List(capacity);
      final buf = ByteData.view(result.buffer);
      int off = 0;

      // FILE_NAME (0x01)
      result[off++] = 0x01;
      buf.setUint16(off, nameBytes.length, Endian.big);
      off += 2;
      result.setRange(off, off + nameBytes.length, nameBytes);
      off += nameBytes.length;

      // FILE_SIZE (0x02) - 4 bytes payload
      result[off++] = 0x02;
      buf.setUint16(off, 4, Endian.big);
      off += 2;
      buf.setUint32(off, fileSize, Endian.big);
      off += 4;

      // MIME_TYPE (0x03)
      result[off++] = 0x03;
      buf.setUint16(off, mimeBytes.length, Endian.big);
      off += 2;
      result.setRange(off, off + mimeBytes.length, mimeBytes);
      off += mimeBytes.length;

      // CONTENT (0x04) - 4 bytes length
      result[off++] = 0x04;
      buf.setUint32(off, contentBytes.length, Endian.big);
      off += 4;
      result.setRange(off, off + contentBytes.length, contentBytes);
      off += contentBytes.length;

      return result;
    } catch (e) {
      return null;
    }
  }

  static BitchatFilePacket? decode(Uint8List data) {
    try {
      int off = 0;
      String? name;
      int? size;
      String? mime;
      final contentBuilder = BytesBuilder();
      bool hasContent = false;

      final buf = ByteData.sublistView(data);

      while (off + 3 <= data.length) {
        final type = data[off++];
        int len;
        if (type == 0x04) {
          // CONTENT uses 4-byte length
          if (off + 4 > data.length) return null;
          len = buf.getUint32(off, Endian.big);
          off += 4;
        } else {
          if (off + 2 > data.length) return null;
          len = buf.getUint16(off, Endian.big);
          off += 2;
        }

        if (len < 0 || off + len > data.length) return null;
        final value = data.sublist(off, off + len);
        off += len;

        switch (type) {
          case 0x01: // FILE_NAME
            name = utf8.decode(value);
            break;
          case 0x02: // FILE_SIZE
            if (len == 4) {
              size = ByteData.sublistView(value).getUint32(0, Endian.big);
            }
            break;
          case 0x03: // MIME_TYPE
            mime = utf8.decode(value);
            break;
          case 0x04: // CONTENT
            contentBuilder.add(value);
            hasContent = true;
            break;
        }
      }

      if (name == null || !hasContent) return null;

      return BitchatFilePacket(
        fileName: name,
        fileSize: size ?? contentBuilder.length,
        mimeType: mime ?? 'application/octet-stream',
        content: contentBuilder.toBytes(),
      );
    } catch (e) {
      return null;
    }
  }
}
