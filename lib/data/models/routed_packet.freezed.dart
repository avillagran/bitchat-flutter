// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'routed_packet.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

RoutedPacket _$RoutedPacketFromJson(Map<String, dynamic> json) {
  return _RoutedPacket.fromJson(json);
}

/// @nodoc
mixin _$RoutedPacket {
  BitchatPacket get packet => throw _privateConstructorUsedError;
  String? get peerID => throw _privateConstructorUsedError;
  String? get relayAddress => throw _privateConstructorUsedError;
  String? get transferId => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $RoutedPacketCopyWith<RoutedPacket> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RoutedPacketCopyWith<$Res> {
  factory $RoutedPacketCopyWith(
          RoutedPacket value, $Res Function(RoutedPacket) then) =
      _$RoutedPacketCopyWithImpl<$Res, RoutedPacket>;
  @useResult
  $Res call(
      {BitchatPacket packet,
      String? peerID,
      String? relayAddress,
      String? transferId});

  $BitchatPacketCopyWith<$Res> get packet;
}

/// @nodoc
class _$RoutedPacketCopyWithImpl<$Res, $Val extends RoutedPacket>
    implements $RoutedPacketCopyWith<$Res> {
  _$RoutedPacketCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? packet = null,
    Object? peerID = freezed,
    Object? relayAddress = freezed,
    Object? transferId = freezed,
  }) {
    return _then(_value.copyWith(
      packet: null == packet
          ? _value.packet
          : packet // ignore: cast_nullable_to_non_nullable
              as BitchatPacket,
      peerID: freezed == peerID
          ? _value.peerID
          : peerID // ignore: cast_nullable_to_non_nullable
              as String?,
      relayAddress: freezed == relayAddress
          ? _value.relayAddress
          : relayAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      transferId: freezed == transferId
          ? _value.transferId
          : transferId // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $BitchatPacketCopyWith<$Res> get packet {
    return $BitchatPacketCopyWith<$Res>(_value.packet, (value) {
      return _then(_value.copyWith(packet: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$RoutedPacketImplCopyWith<$Res>
    implements $RoutedPacketCopyWith<$Res> {
  factory _$$RoutedPacketImplCopyWith(
          _$RoutedPacketImpl value, $Res Function(_$RoutedPacketImpl) then) =
      __$$RoutedPacketImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {BitchatPacket packet,
      String? peerID,
      String? relayAddress,
      String? transferId});

  @override
  $BitchatPacketCopyWith<$Res> get packet;
}

/// @nodoc
class __$$RoutedPacketImplCopyWithImpl<$Res>
    extends _$RoutedPacketCopyWithImpl<$Res, _$RoutedPacketImpl>
    implements _$$RoutedPacketImplCopyWith<$Res> {
  __$$RoutedPacketImplCopyWithImpl(
      _$RoutedPacketImpl _value, $Res Function(_$RoutedPacketImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? packet = null,
    Object? peerID = freezed,
    Object? relayAddress = freezed,
    Object? transferId = freezed,
  }) {
    return _then(_$RoutedPacketImpl(
      packet: null == packet
          ? _value.packet
          : packet // ignore: cast_nullable_to_non_nullable
              as BitchatPacket,
      peerID: freezed == peerID
          ? _value.peerID
          : peerID // ignore: cast_nullable_to_non_nullable
              as String?,
      relayAddress: freezed == relayAddress
          ? _value.relayAddress
          : relayAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      transferId: freezed == transferId
          ? _value.transferId
          : transferId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RoutedPacketImpl implements _RoutedPacket {
  const _$RoutedPacketImpl(
      {required this.packet, this.peerID, this.relayAddress, this.transferId});

  factory _$RoutedPacketImpl.fromJson(Map<String, dynamic> json) =>
      _$$RoutedPacketImplFromJson(json);

  @override
  final BitchatPacket packet;
  @override
  final String? peerID;
  @override
  final String? relayAddress;
  @override
  final String? transferId;

  @override
  String toString() {
    return 'RoutedPacket(packet: $packet, peerID: $peerID, relayAddress: $relayAddress, transferId: $transferId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RoutedPacketImpl &&
            (identical(other.packet, packet) || other.packet == packet) &&
            (identical(other.peerID, peerID) || other.peerID == peerID) &&
            (identical(other.relayAddress, relayAddress) ||
                other.relayAddress == relayAddress) &&
            (identical(other.transferId, transferId) ||
                other.transferId == transferId));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, packet, peerID, relayAddress, transferId);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$RoutedPacketImplCopyWith<_$RoutedPacketImpl> get copyWith =>
      __$$RoutedPacketImplCopyWithImpl<_$RoutedPacketImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RoutedPacketImplToJson(
      this,
    );
  }
}

abstract class _RoutedPacket implements RoutedPacket {
  const factory _RoutedPacket(
      {required final BitchatPacket packet,
      final String? peerID,
      final String? relayAddress,
      final String? transferId}) = _$RoutedPacketImpl;

  factory _RoutedPacket.fromJson(Map<String, dynamic> json) =
      _$RoutedPacketImpl.fromJson;

  @override
  BitchatPacket get packet;
  @override
  String? get peerID;
  @override
  String? get relayAddress;
  @override
  String? get transferId;
  @override
  @JsonKey(ignore: true)
  _$$RoutedPacketImplCopyWith<_$RoutedPacketImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

BitchatPacket _$BitchatPacketFromJson(Map<String, dynamic> json) {
  return _BitchatPacket.fromJson(json);
}

/// @nodoc
mixin _$BitchatPacket {
  int get version => throw _privateConstructorUsedError;
  int get type => throw _privateConstructorUsedError;
  int get ttl => throw _privateConstructorUsedError;
  @Uint8ListBase64Converter()
  Uint8List? get senderID => throw _privateConstructorUsedError;
  @Uint8ListBase64Converter()
  Uint8List? get recipientID => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  @Uint8ListBase64Converter()
  Uint8List? get payload => throw _privateConstructorUsedError;
  @Uint8ListListConverter()
  List<Uint8List>? get route => throw _privateConstructorUsedError;
  @Uint8ListBase64Converter()
  Uint8List? get signature => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $BitchatPacketCopyWith<BitchatPacket> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BitchatPacketCopyWith<$Res> {
  factory $BitchatPacketCopyWith(
          BitchatPacket value, $Res Function(BitchatPacket) then) =
      _$BitchatPacketCopyWithImpl<$Res, BitchatPacket>;
  @useResult
  $Res call(
      {int version,
      int type,
      int ttl,
      @Uint8ListBase64Converter() Uint8List? senderID,
      @Uint8ListBase64Converter() Uint8List? recipientID,
      DateTime timestamp,
      @Uint8ListBase64Converter() Uint8List? payload,
      @Uint8ListListConverter() List<Uint8List>? route,
      @Uint8ListBase64Converter() Uint8List? signature});
}

/// @nodoc
class _$BitchatPacketCopyWithImpl<$Res, $Val extends BitchatPacket>
    implements $BitchatPacketCopyWith<$Res> {
  _$BitchatPacketCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? version = null,
    Object? type = null,
    Object? ttl = null,
    Object? senderID = freezed,
    Object? recipientID = freezed,
    Object? timestamp = null,
    Object? payload = freezed,
    Object? route = freezed,
    Object? signature = freezed,
  }) {
    return _then(_value.copyWith(
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as int,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as int,
      ttl: null == ttl
          ? _value.ttl
          : ttl // ignore: cast_nullable_to_non_nullable
              as int,
      senderID: freezed == senderID
          ? _value.senderID
          : senderID // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
      recipientID: freezed == recipientID
          ? _value.recipientID
          : recipientID // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      payload: freezed == payload
          ? _value.payload
          : payload // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
      route: freezed == route
          ? _value.route
          : route // ignore: cast_nullable_to_non_nullable
              as List<Uint8List>?,
      signature: freezed == signature
          ? _value.signature
          : signature // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BitchatPacketImplCopyWith<$Res>
    implements $BitchatPacketCopyWith<$Res> {
  factory _$$BitchatPacketImplCopyWith(
          _$BitchatPacketImpl value, $Res Function(_$BitchatPacketImpl) then) =
      __$$BitchatPacketImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int version,
      int type,
      int ttl,
      @Uint8ListBase64Converter() Uint8List? senderID,
      @Uint8ListBase64Converter() Uint8List? recipientID,
      DateTime timestamp,
      @Uint8ListBase64Converter() Uint8List? payload,
      @Uint8ListListConverter() List<Uint8List>? route,
      @Uint8ListBase64Converter() Uint8List? signature});
}

/// @nodoc
class __$$BitchatPacketImplCopyWithImpl<$Res>
    extends _$BitchatPacketCopyWithImpl<$Res, _$BitchatPacketImpl>
    implements _$$BitchatPacketImplCopyWith<$Res> {
  __$$BitchatPacketImplCopyWithImpl(
      _$BitchatPacketImpl _value, $Res Function(_$BitchatPacketImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? version = null,
    Object? type = null,
    Object? ttl = null,
    Object? senderID = freezed,
    Object? recipientID = freezed,
    Object? timestamp = null,
    Object? payload = freezed,
    Object? route = freezed,
    Object? signature = freezed,
  }) {
    return _then(_$BitchatPacketImpl(
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as int,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as int,
      ttl: null == ttl
          ? _value.ttl
          : ttl // ignore: cast_nullable_to_non_nullable
              as int,
      senderID: freezed == senderID
          ? _value.senderID
          : senderID // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
      recipientID: freezed == recipientID
          ? _value.recipientID
          : recipientID // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      payload: freezed == payload
          ? _value.payload
          : payload // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
      route: freezed == route
          ? _value._route
          : route // ignore: cast_nullable_to_non_nullable
              as List<Uint8List>?,
      signature: freezed == signature
          ? _value.signature
          : signature // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BitchatPacketImpl extends _BitchatPacket {
  const _$BitchatPacketImpl(
      {this.version = 1,
      this.type = 0,
      this.ttl = 7,
      @Uint8ListBase64Converter() this.senderID,
      @Uint8ListBase64Converter() this.recipientID,
      required this.timestamp,
      @Uint8ListBase64Converter() this.payload,
      @Uint8ListListConverter() final List<Uint8List>? route,
      @Uint8ListBase64Converter() this.signature})
      : _route = route,
        super._();

  factory _$BitchatPacketImpl.fromJson(Map<String, dynamic> json) =>
      _$$BitchatPacketImplFromJson(json);

  @override
  @JsonKey()
  final int version;
  @override
  @JsonKey()
  final int type;
  @override
  @JsonKey()
  final int ttl;
  @override
  @Uint8ListBase64Converter()
  final Uint8List? senderID;
  @override
  @Uint8ListBase64Converter()
  final Uint8List? recipientID;
  @override
  final DateTime timestamp;
  @override
  @Uint8ListBase64Converter()
  final Uint8List? payload;
  final List<Uint8List>? _route;
  @override
  @Uint8ListListConverter()
  List<Uint8List>? get route {
    final value = _route;
    if (value == null) return null;
    if (_route is EqualUnmodifiableListView) return _route;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @Uint8ListBase64Converter()
  final Uint8List? signature;

  @override
  String toString() {
    return 'BitchatPacket(version: $version, type: $type, ttl: $ttl, senderID: $senderID, recipientID: $recipientID, timestamp: $timestamp, payload: $payload, route: $route, signature: $signature)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BitchatPacketImpl &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.ttl, ttl) || other.ttl == ttl) &&
            const DeepCollectionEquality().equals(other.senderID, senderID) &&
            const DeepCollectionEquality()
                .equals(other.recipientID, recipientID) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            const DeepCollectionEquality().equals(other.payload, payload) &&
            const DeepCollectionEquality().equals(other._route, _route) &&
            const DeepCollectionEquality().equals(other.signature, signature));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      version,
      type,
      ttl,
      const DeepCollectionEquality().hash(senderID),
      const DeepCollectionEquality().hash(recipientID),
      timestamp,
      const DeepCollectionEquality().hash(payload),
      const DeepCollectionEquality().hash(_route),
      const DeepCollectionEquality().hash(signature));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$BitchatPacketImplCopyWith<_$BitchatPacketImpl> get copyWith =>
      __$$BitchatPacketImplCopyWithImpl<_$BitchatPacketImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BitchatPacketImplToJson(
      this,
    );
  }
}

abstract class _BitchatPacket extends BitchatPacket {
  const factory _BitchatPacket(
          {final int version,
          final int type,
          final int ttl,
          @Uint8ListBase64Converter() final Uint8List? senderID,
          @Uint8ListBase64Converter() final Uint8List? recipientID,
          required final DateTime timestamp,
          @Uint8ListBase64Converter() final Uint8List? payload,
          @Uint8ListListConverter() final List<Uint8List>? route,
          @Uint8ListBase64Converter() final Uint8List? signature}) =
      _$BitchatPacketImpl;
  const _BitchatPacket._() : super._();

  factory _BitchatPacket.fromJson(Map<String, dynamic> json) =
      _$BitchatPacketImpl.fromJson;

  @override
  int get version;
  @override
  int get type;
  @override
  int get ttl;
  @override
  @Uint8ListBase64Converter()
  Uint8List? get senderID;
  @override
  @Uint8ListBase64Converter()
  Uint8List? get recipientID;
  @override
  DateTime get timestamp;
  @override
  @Uint8ListBase64Converter()
  Uint8List? get payload;
  @override
  @Uint8ListListConverter()
  List<Uint8List>? get route;
  @override
  @Uint8ListBase64Converter()
  Uint8List? get signature;
  @override
  @JsonKey(ignore: true)
  _$$BitchatPacketImplCopyWith<_$BitchatPacketImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
