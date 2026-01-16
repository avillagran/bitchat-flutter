// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'identity_announcement.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$IdentityAnnouncementImpl _$$IdentityAnnouncementImplFromJson(
        Map<String, dynamic> json) =>
    _$IdentityAnnouncementImpl(
      nickname: json['nickname'] as String,
      noisePublicKey: const Uint8ListBase64Converter()
          .fromJson(json['noisePublicKey'] as String?),
      signingPublicKey: const Uint8ListBase64Converter()
          .fromJson(json['signingPublicKey'] as String?),
    );

Map<String, dynamic> _$$IdentityAnnouncementImplToJson(
        _$IdentityAnnouncementImpl instance) =>
    <String, dynamic>{
      'nickname': instance.nickname,
      'noisePublicKey':
          const Uint8ListBase64Converter().toJson(instance.noisePublicKey),
      'signingPublicKey':
          const Uint8ListBase64Converter().toJson(instance.signingPublicKey),
    };
