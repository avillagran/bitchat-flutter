// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'noise_encrypted.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NoisePayloadImpl _$$NoisePayloadImplFromJson(Map<String, dynamic> json) =>
    _$NoisePayloadImpl(
      type: $enumDecode(_$NoisePayloadTypeEnumMap, json['type']),
      data: const Uint8ListBase64Converter().fromJson(json['data'] as String?),
    );

Map<String, dynamic> _$$NoisePayloadImplToJson(_$NoisePayloadImpl instance) =>
    <String, dynamic>{
      'type': _$NoisePayloadTypeEnumMap[instance.type]!,
      'data': const Uint8ListBase64Converter().toJson(instance.data),
    };

const _$NoisePayloadTypeEnumMap = {
  NoisePayloadType.privateMessage: 'privateMessage',
  NoisePayloadType.readReceipt: 'readReceipt',
  NoisePayloadType.delivered: 'delivered',
  NoisePayloadType.verifyChallenge: 'verifyChallenge',
  NoisePayloadType.verifyResponse: 'verifyResponse',
  NoisePayloadType.fileTransfer: 'fileTransfer',
};

_$PrivateMessagePacketImpl _$$PrivateMessagePacketImplFromJson(
        Map<String, dynamic> json) =>
    _$PrivateMessagePacketImpl(
      messageID: json['messageID'] as String,
      content: json['content'] as String,
    );

Map<String, dynamic> _$$PrivateMessagePacketImplToJson(
        _$PrivateMessagePacketImpl instance) =>
    <String, dynamic>{
      'messageID': instance.messageID,
      'content': instance.content,
    };

_$NoiseEncryptedImpl _$$NoiseEncryptedImplFromJson(Map<String, dynamic> json) =>
    _$NoiseEncryptedImpl(
      ephemeralKey: const Uint8ListBase64Converter()
          .fromJson(json['ephemeralKey'] as String?),
      ciphertext: const Uint8ListBase64Converter()
          .fromJson(json['ciphertext'] as String?),
    );

Map<String, dynamic> _$$NoiseEncryptedImplToJson(
        _$NoiseEncryptedImpl instance) =>
    <String, dynamic>{
      'ephemeralKey':
          const Uint8ListBase64Converter().toJson(instance.ephemeralKey),
      'ciphertext':
          const Uint8ListBase64Converter().toJson(instance.ciphertext),
    };
