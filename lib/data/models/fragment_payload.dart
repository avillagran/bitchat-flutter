import 'dart:typed_data';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:bitchat/core/json_converters.dart';

part 'fragment_payload.freezed.dart';
part 'fragment_payload.g.dart';

@freezed
class FragmentPayload with _$FragmentPayload {
  const factory FragmentPayload({
    @Uint8ListBase64Converter() Uint8List? fragmentID,
    required int index,
    required int total,
    required int originalType,
    @Uint8ListBase64Converter() Uint8List? data,
  }) = _FragmentPayload;

  factory FragmentPayload.fromJson(Map<String, dynamic> json) =>
      _$FragmentPayloadFromJson(json);

  const FragmentPayload._();

  static const int headerSize = 13;
  static const int fragmentIdSize = 8;

  Uint8List encode() {
    final fragmentIDBytes = fragmentID ?? Uint8List(fragmentIdSize);
    final dataBytes = data ?? Uint8List(0);
    final payload = Uint8List(headerSize + dataBytes.length);
    final buf = ByteData.view(payload.buffer);

    // Fragment ID (8 bytes)
    payload.setRange(0, fragmentIdSize, fragmentIDBytes);

    // Index (2 bytes, big-endian)
    buf.setUint16(8, index, Endian.big);

    // Total (2 bytes, big-endian)
    buf.setUint16(10, total, Endian.big);

    // Original type (1 byte)
    payload[12] = originalType & 0xFF;

    // Fragment data
    if (dataBytes.isNotEmpty) {
      payload.setRange(headerSize, payload.length, dataBytes);
    }

    return payload;
  }

  static FragmentPayload? decode(Uint8List payloadData) {
    if (payloadData.length < headerSize) return null;

    try {
      final buf = ByteData.sublistView(payloadData);

      final fragmentID = payloadData.sublist(0, fragmentIdSize);
      final index = buf.getUint16(8, Endian.big);
      final total = buf.getUint16(10, Endian.big);
      final originalType = payloadData[12];

      final data = payloadData.length > headerSize
          ? payloadData.sublist(headerSize)
          : Uint8List(0);

      return FragmentPayload(
        fragmentID: fragmentID,
        index: index,
        total: total,
        originalType: originalType,
        data: data,
      );
    } catch (e) {
      return null;
    }
  }
}
