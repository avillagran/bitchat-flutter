// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_sync_packet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RequestSyncPacketImpl _$$RequestSyncPacketImplFromJson(
        Map<String, dynamic> json) =>
    _$RequestSyncPacketImpl(
      p: (json['p'] as num).toInt(),
      m: (json['m'] as num).toInt(),
      data: const Uint8ListBase64Converter().fromJson(json['data'] as String?),
    );

Map<String, dynamic> _$$RequestSyncPacketImplToJson(
        _$RequestSyncPacketImpl instance) =>
    <String, dynamic>{
      'p': instance.p,
      'm': instance.m,
      'data': const Uint8ListBase64Converter().toJson(instance.data),
    };
