import 'dart:convert';
import 'dart:typed_data';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:bitchat/core/json_converters.dart';

part 'identity_announcement.freezed.dart';
part 'identity_announcement.g.dart';

@freezed
class IdentityAnnouncement with _$IdentityAnnouncement {
  const factory IdentityAnnouncement({
    required String nickname,
    @Uint8ListBase64Converter() Uint8List? noisePublicKey,
    @Uint8ListBase64Converter() Uint8List? signingPublicKey,
  }) = _IdentityAnnouncement;

  factory IdentityAnnouncement.fromJson(Map<String, dynamic> json) =>
      _$IdentityAnnouncementFromJson(json);

  const IdentityAnnouncement._();

  Uint8List? encode() {
    try {
      final nicknameData = utf8.encode(nickname);
      final noisePKBytes = noisePublicKey ?? Uint8List(0);
      final signingPKBytes = signingPublicKey ?? Uint8List(0);

      if (nicknameData.length > 255 ||
          noisePKBytes.length > 255 ||
          signingPKBytes.length > 255) {
        return null;
      }

      final result = <int>[];

      // TLV for nickname (0x01)
      result.add(0x01);
      result.add(nicknameData.length);
      result.addAll(nicknameData);

      // TLV for noise public key (0x02)
      result.add(0x02);
      result.add(noisePKBytes.length);
      result.addAll(noisePKBytes);

      // TLV for signing public key (0x03)
      result.add(0x03);
      result.add(signingPKBytes.length);
      result.addAll(signingPKBytes);

      return Uint8List.fromList(result);
    } catch (e) {
      return null;
    }
  }

  static IdentityAnnouncement? decode(Uint8List data) {
    try {
      int offset = 0;
      String? nickname;
      Uint8List? noisePublicKey;
      Uint8List? signingPublicKey;

      while (offset + 2 <= data.length) {
        final type = data[offset++];
        final length = data[offset++];

        if (offset + length > data.length) return null;

        final value = data.sublist(offset, offset + length);
        offset += length;

        switch (type) {
          case 0x01: // NICKNAME
            nickname = utf8.decode(value);
            break;
          case 0x02: // NOISE_PUBLIC_KEY
            noisePublicKey = value;
            break;
          case 0x03: // SIGNING_PUBLIC_KEY
            signingPublicKey = value;
            break;
          default:
            continue;
        }
      }

      if (nickname != null &&
          noisePublicKey != null &&
          signingPublicKey != null) {
        return IdentityAnnouncement(
          nickname: nickname,
          noisePublicKey: noisePublicKey,
          signingPublicKey: signingPublicKey,
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
