import 'dart:typed_data';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:bitchat/core/json_converters.dart';

part 'request_sync_packet.freezed.dart';
part 'request_sync_packet.g.dart';

@freezed
class RequestSyncPacket with _$RequestSyncPacket {
  const factory RequestSyncPacket({
    required int p,
    required int m,
    @Uint8ListBase64Converter() Uint8List? data,
  }) = _RequestSyncPacket;

  factory RequestSyncPacket.fromJson(Map<String, dynamic> json) =>
      _$RequestSyncPacketFromJson(json);

  const RequestSyncPacket._();

  static const int maxAcceptFilterBytes = 10 * 1024 * 1024; // 10MB safety limit

  Uint8List encode() {
    final out = <int>[];

    void putTLV(int t, Uint8List v) {
      out.add(t & 0xFF);
      final len = v.length;
      out.add((len >> 8) & 0xFF);
      out.add(len & 0xFF);
      out.addAll(v);
    }

    // P (0x01)
    putTLV(0x01, Uint8List.fromList([p & 0xFF]));

    // M (0x02) - uint32 big-endian
    final m32 = m.clamp(0, 0xFFFFFFFF);
    final mBytes = Uint8List(4);
    ByteData.view(mBytes.buffer).setUint32(0, m32, Endian.big);
    putTLV(0x02, mBytes);

    // data (0x03)
    putTLV(0x03, data ?? Uint8List(0));

    return Uint8List.fromList(out);
  }

  static RequestSyncPacket? decode(Uint8List data) {
    int off = 0;
    int? p;
    int? m;
    Uint8List? payload;

    final buf = ByteData.sublistView(data);

    while (off + 3 <= data.length) {
      final t = data[off++];
      final len = (data[off] << 8) | data[off + 1];
      off += 2;

      if (off + len > data.length) return null;
      final v = data.sublist(off, off + len);
      off += len;

      switch (t) {
        case 0x01:
          if (len == 1) p = v[0];
          break;
        case 0x02:
          if (len == 4) {
            m = ByteData.sublistView(v).getUint32(0, Endian.big);
          }
          break;
        case 0x03:
          if (v.length > maxAcceptFilterBytes) return null;
          payload = v;
          break;
      }
    }

    if (p == null || m == null || payload == null) return null;
    if (p < 1 || m <= 0) return null;

    return RequestSyncPacket(p: p, m: m, data: payload);
  }
}
