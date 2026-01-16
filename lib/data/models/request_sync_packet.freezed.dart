// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'request_sync_packet.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

RequestSyncPacket _$RequestSyncPacketFromJson(Map<String, dynamic> json) {
  return _RequestSyncPacket.fromJson(json);
}

/// @nodoc
mixin _$RequestSyncPacket {
  int get p => throw _privateConstructorUsedError;
  int get m => throw _privateConstructorUsedError;
  @Uint8ListBase64Converter()
  Uint8List? get data => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $RequestSyncPacketCopyWith<RequestSyncPacket> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RequestSyncPacketCopyWith<$Res> {
  factory $RequestSyncPacketCopyWith(
          RequestSyncPacket value, $Res Function(RequestSyncPacket) then) =
      _$RequestSyncPacketCopyWithImpl<$Res, RequestSyncPacket>;
  @useResult
  $Res call({int p, int m, @Uint8ListBase64Converter() Uint8List? data});
}

/// @nodoc
class _$RequestSyncPacketCopyWithImpl<$Res, $Val extends RequestSyncPacket>
    implements $RequestSyncPacketCopyWith<$Res> {
  _$RequestSyncPacketCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? p = null,
    Object? m = null,
    Object? data = freezed,
  }) {
    return _then(_value.copyWith(
      p: null == p
          ? _value.p
          : p // ignore: cast_nullable_to_non_nullable
              as int,
      m: null == m
          ? _value.m
          : m // ignore: cast_nullable_to_non_nullable
              as int,
      data: freezed == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RequestSyncPacketImplCopyWith<$Res>
    implements $RequestSyncPacketCopyWith<$Res> {
  factory _$$RequestSyncPacketImplCopyWith(_$RequestSyncPacketImpl value,
          $Res Function(_$RequestSyncPacketImpl) then) =
      __$$RequestSyncPacketImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int p, int m, @Uint8ListBase64Converter() Uint8List? data});
}

/// @nodoc
class __$$RequestSyncPacketImplCopyWithImpl<$Res>
    extends _$RequestSyncPacketCopyWithImpl<$Res, _$RequestSyncPacketImpl>
    implements _$$RequestSyncPacketImplCopyWith<$Res> {
  __$$RequestSyncPacketImplCopyWithImpl(_$RequestSyncPacketImpl _value,
      $Res Function(_$RequestSyncPacketImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? p = null,
    Object? m = null,
    Object? data = freezed,
  }) {
    return _then(_$RequestSyncPacketImpl(
      p: null == p
          ? _value.p
          : p // ignore: cast_nullable_to_non_nullable
              as int,
      m: null == m
          ? _value.m
          : m // ignore: cast_nullable_to_non_nullable
              as int,
      data: freezed == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RequestSyncPacketImpl extends _RequestSyncPacket {
  const _$RequestSyncPacketImpl(
      {required this.p, required this.m, @Uint8ListBase64Converter() this.data})
      : super._();

  factory _$RequestSyncPacketImpl.fromJson(Map<String, dynamic> json) =>
      _$$RequestSyncPacketImplFromJson(json);

  @override
  final int p;
  @override
  final int m;
  @override
  @Uint8ListBase64Converter()
  final Uint8List? data;

  @override
  String toString() {
    return 'RequestSyncPacket(p: $p, m: $m, data: $data)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RequestSyncPacketImpl &&
            (identical(other.p, p) || other.p == p) &&
            (identical(other.m, m) || other.m == m) &&
            const DeepCollectionEquality().equals(other.data, data));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, p, m, const DeepCollectionEquality().hash(data));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$RequestSyncPacketImplCopyWith<_$RequestSyncPacketImpl> get copyWith =>
      __$$RequestSyncPacketImplCopyWithImpl<_$RequestSyncPacketImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RequestSyncPacketImplToJson(
      this,
    );
  }
}

abstract class _RequestSyncPacket extends RequestSyncPacket {
  const factory _RequestSyncPacket(
          {required final int p,
          required final int m,
          @Uint8ListBase64Converter() final Uint8List? data}) =
      _$RequestSyncPacketImpl;
  const _RequestSyncPacket._() : super._();

  factory _RequestSyncPacket.fromJson(Map<String, dynamic> json) =
      _$RequestSyncPacketImpl.fromJson;

  @override
  int get p;
  @override
  int get m;
  @override
  @Uint8ListBase64Converter()
  Uint8List? get data;
  @override
  @JsonKey(ignore: true)
  _$$RequestSyncPacketImplCopyWith<_$RequestSyncPacketImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
