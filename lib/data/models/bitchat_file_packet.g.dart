// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bitchat_file_packet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BitchatFilePacketImpl _$$BitchatFilePacketImplFromJson(
        Map<String, dynamic> json) =>
    _$BitchatFilePacketImpl(
      fileName: json['fileName'] as String,
      fileSize: (json['fileSize'] as num).toInt(),
      mimeType: json['mimeType'] as String,
      content:
          const Uint8ListBase64Converter().fromJson(json['content'] as String?),
    );

Map<String, dynamic> _$$BitchatFilePacketImplToJson(
        _$BitchatFilePacketImpl instance) =>
    <String, dynamic>{
      'fileName': instance.fileName,
      'fileSize': instance.fileSize,
      'mimeType': instance.mimeType,
      'content': const Uint8ListBase64Converter().toJson(instance.content),
    };
