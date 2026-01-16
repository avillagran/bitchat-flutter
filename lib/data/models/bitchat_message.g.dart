// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bitchat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SendingImpl _$$SendingImplFromJson(Map<String, dynamic> json) =>
    _$SendingImpl(
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$SendingImplToJson(_$SendingImpl instance) =>
    <String, dynamic>{
      'runtimeType': instance.$type,
    };

_$SentImpl _$$SentImplFromJson(Map<String, dynamic> json) => _$SentImpl(
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$SentImplToJson(_$SentImpl instance) =>
    <String, dynamic>{
      'runtimeType': instance.$type,
    };

_$DeliveredImpl _$$DeliveredImplFromJson(Map<String, dynamic> json) =>
    _$DeliveredImpl(
      to: json['to'] as String,
      at: DateTime.parse(json['at'] as String),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$DeliveredImplToJson(_$DeliveredImpl instance) =>
    <String, dynamic>{
      'to': instance.to,
      'at': instance.at.toIso8601String(),
      'runtimeType': instance.$type,
    };

_$ReadImpl _$$ReadImplFromJson(Map<String, dynamic> json) => _$ReadImpl(
      by: json['by'] as String,
      at: DateTime.parse(json['at'] as String),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$ReadImplToJson(_$ReadImpl instance) =>
    <String, dynamic>{
      'by': instance.by,
      'at': instance.at.toIso8601String(),
      'runtimeType': instance.$type,
    };

_$FailedImpl _$$FailedImplFromJson(Map<String, dynamic> json) => _$FailedImpl(
      reason: json['reason'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$FailedImplToJson(_$FailedImpl instance) =>
    <String, dynamic>{
      'reason': instance.reason,
      'runtimeType': instance.$type,
    };

_$PartiallyDeliveredImpl _$$PartiallyDeliveredImplFromJson(
        Map<String, dynamic> json) =>
    _$PartiallyDeliveredImpl(
      reached: (json['reached'] as num).toInt(),
      total: (json['total'] as num).toInt(),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$PartiallyDeliveredImplToJson(
        _$PartiallyDeliveredImpl instance) =>
    <String, dynamic>{
      'reached': instance.reached,
      'total': instance.total,
      'runtimeType': instance.$type,
    };

_$BitchatMessageImpl _$$BitchatMessageImplFromJson(Map<String, dynamic> json) =>
    _$BitchatMessageImpl(
      id: json['id'] as String? ?? '',
      sender: json['sender'] as String,
      content: json['content'] as String? ?? '',
      type: $enumDecodeNullable(_$BitchatMessageTypeEnumMap, json['type']) ??
          BitchatMessageType.Message,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRelay: json['isRelay'] as bool? ?? false,
      originalSender: json['originalSender'] as String?,
      isPrivate: json['isPrivate'] as bool? ?? false,
      recipientNickname: json['recipientNickname'] as String?,
      senderPeerID: json['senderPeerID'] as String?,
      mentions: (json['mentions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      channel: json['channel'] as String?,
      encryptedContent: const Uint8ListBase64Converter()
          .fromJson(json['encryptedContent'] as String?),
      isEncrypted: json['isEncrypted'] as bool? ?? false,
      deliveryStatus: json['deliveryStatus'] == null
          ? null
          : DeliveryStatus.fromJson(
              json['deliveryStatus'] as Map<String, dynamic>),
      powDifficulty: (json['powDifficulty'] as num?)?.toInt(),
      rssi: (json['rssi'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$BitchatMessageImplToJson(
        _$BitchatMessageImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sender': instance.sender,
      'content': instance.content,
      'type': _$BitchatMessageTypeEnumMap[instance.type]!,
      'timestamp': instance.timestamp.toIso8601String(),
      'isRelay': instance.isRelay,
      'originalSender': instance.originalSender,
      'isPrivate': instance.isPrivate,
      'recipientNickname': instance.recipientNickname,
      'senderPeerID': instance.senderPeerID,
      'mentions': instance.mentions,
      'channel': instance.channel,
      'encryptedContent':
          const Uint8ListBase64Converter().toJson(instance.encryptedContent),
      'isEncrypted': instance.isEncrypted,
      'deliveryStatus': instance.deliveryStatus,
      'powDifficulty': instance.powDifficulty,
      'rssi': instance.rssi,
    };

const _$BitchatMessageTypeEnumMap = {
  BitchatMessageType.Message: 'Message',
  BitchatMessageType.Audio: 'Audio',
  BitchatMessageType.Image: 'Image',
  BitchatMessageType.File: 'File',
};
