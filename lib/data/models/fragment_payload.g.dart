// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fragment_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FragmentPayloadImpl _$$FragmentPayloadImplFromJson(
        Map<String, dynamic> json) =>
    _$FragmentPayloadImpl(
      fragmentID: const Uint8ListBase64Converter()
          .fromJson(json['fragmentID'] as String?),
      index: (json['index'] as num).toInt(),
      total: (json['total'] as num).toInt(),
      originalType: (json['originalType'] as num).toInt(),
      data: const Uint8ListBase64Converter().fromJson(json['data'] as String?),
    );

Map<String, dynamic> _$$FragmentPayloadImplToJson(
        _$FragmentPayloadImpl instance) =>
    <String, dynamic>{
      'fragmentID':
          const Uint8ListBase64Converter().toJson(instance.fragmentID),
      'index': instance.index,
      'total': instance.total,
      'originalType': instance.originalType,
      'data': const Uint8ListBase64Converter().toJson(instance.data),
    };
