// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routed_packet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RoutedPacketImpl _$$RoutedPacketImplFromJson(Map<String, dynamic> json) =>
    _$RoutedPacketImpl(
      packet: BitchatPacket.fromJson(json['packet'] as Map<String, dynamic>),
      peerID: json['peerID'] as String?,
      relayAddress: json['relayAddress'] as String?,
      transferId: json['transferId'] as String?,
    );

Map<String, dynamic> _$$RoutedPacketImplToJson(_$RoutedPacketImpl instance) =>
    <String, dynamic>{
      'packet': instance.packet,
      'peerID': instance.peerID,
      'relayAddress': instance.relayAddress,
      'transferId': instance.transferId,
    };

_$BitchatPacketImpl _$$BitchatPacketImplFromJson(Map<String, dynamic> json) =>
    _$BitchatPacketImpl(
      version: (json['version'] as num?)?.toInt() ?? 1,
      type: (json['type'] as num?)?.toInt() ?? 0,
      ttl: (json['ttl'] as num?)?.toInt() ?? 7,
      senderID: const Uint8ListBase64Converter()
          .fromJson(json['senderID'] as String?),
      recipientID: const Uint8ListBase64Converter()
          .fromJson(json['recipientID'] as String?),
      timestamp: DateTime.parse(json['timestamp'] as String),
      payload:
          const Uint8ListBase64Converter().fromJson(json['payload'] as String?),
      route: const Uint8ListListConverter().fromJson(json['route'] as List?),
      signature: const Uint8ListBase64Converter()
          .fromJson(json['signature'] as String?),
    );

Map<String, dynamic> _$$BitchatPacketImplToJson(_$BitchatPacketImpl instance) =>
    <String, dynamic>{
      'version': instance.version,
      'type': instance.type,
      'ttl': instance.ttl,
      'senderID': const Uint8ListBase64Converter().toJson(instance.senderID),
      'recipientID':
          const Uint8ListBase64Converter().toJson(instance.recipientID),
      'timestamp': instance.timestamp.toIso8601String(),
      'payload': const Uint8ListBase64Converter().toJson(instance.payload),
      'route': const Uint8ListListConverter().toJson(instance.route),
      'signature': const Uint8ListBase64Converter().toJson(instance.signature),
    };
