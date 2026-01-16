// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'noise_encrypted.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

NoisePayload _$NoisePayloadFromJson(Map<String, dynamic> json) {
  return _NoisePayload.fromJson(json);
}

/// @nodoc
mixin _$NoisePayload {
  NoisePayloadType get type => throw _privateConstructorUsedError;
  @Uint8ListBase64Converter()
  Uint8List? get data => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $NoisePayloadCopyWith<NoisePayload> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NoisePayloadCopyWith<$Res> {
  factory $NoisePayloadCopyWith(
          NoisePayload value, $Res Function(NoisePayload) then) =
      _$NoisePayloadCopyWithImpl<$Res, NoisePayload>;
  @useResult
  $Res call(
      {NoisePayloadType type, @Uint8ListBase64Converter() Uint8List? data});
}

/// @nodoc
class _$NoisePayloadCopyWithImpl<$Res, $Val extends NoisePayload>
    implements $NoisePayloadCopyWith<$Res> {
  _$NoisePayloadCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? data = freezed,
  }) {
    return _then(_value.copyWith(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as NoisePayloadType,
      data: freezed == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$NoisePayloadImplCopyWith<$Res>
    implements $NoisePayloadCopyWith<$Res> {
  factory _$$NoisePayloadImplCopyWith(
          _$NoisePayloadImpl value, $Res Function(_$NoisePayloadImpl) then) =
      __$$NoisePayloadImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {NoisePayloadType type, @Uint8ListBase64Converter() Uint8List? data});
}

/// @nodoc
class __$$NoisePayloadImplCopyWithImpl<$Res>
    extends _$NoisePayloadCopyWithImpl<$Res, _$NoisePayloadImpl>
    implements _$$NoisePayloadImplCopyWith<$Res> {
  __$$NoisePayloadImplCopyWithImpl(
      _$NoisePayloadImpl _value, $Res Function(_$NoisePayloadImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? data = freezed,
  }) {
    return _then(_$NoisePayloadImpl(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as NoisePayloadType,
      data: freezed == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$NoisePayloadImpl extends _NoisePayload {
  const _$NoisePayloadImpl(
      {required this.type, @Uint8ListBase64Converter() this.data})
      : super._();

  factory _$NoisePayloadImpl.fromJson(Map<String, dynamic> json) =>
      _$$NoisePayloadImplFromJson(json);

  @override
  final NoisePayloadType type;
  @override
  @Uint8ListBase64Converter()
  final Uint8List? data;

  @override
  String toString() {
    return 'NoisePayload(type: $type, data: $data)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NoisePayloadImpl &&
            (identical(other.type, type) || other.type == type) &&
            const DeepCollectionEquality().equals(other.data, data));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, type, const DeepCollectionEquality().hash(data));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$NoisePayloadImplCopyWith<_$NoisePayloadImpl> get copyWith =>
      __$$NoisePayloadImplCopyWithImpl<_$NoisePayloadImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NoisePayloadImplToJson(
      this,
    );
  }
}

abstract class _NoisePayload extends NoisePayload {
  const factory _NoisePayload(
      {required final NoisePayloadType type,
      @Uint8ListBase64Converter() final Uint8List? data}) = _$NoisePayloadImpl;
  const _NoisePayload._() : super._();

  factory _NoisePayload.fromJson(Map<String, dynamic> json) =
      _$NoisePayloadImpl.fromJson;

  @override
  NoisePayloadType get type;
  @override
  @Uint8ListBase64Converter()
  Uint8List? get data;
  @override
  @JsonKey(ignore: true)
  _$$NoisePayloadImplCopyWith<_$NoisePayloadImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PrivateMessagePacket _$PrivateMessagePacketFromJson(Map<String, dynamic> json) {
  return _PrivateMessagePacket.fromJson(json);
}

/// @nodoc
mixin _$PrivateMessagePacket {
  String get messageID => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $PrivateMessagePacketCopyWith<PrivateMessagePacket> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PrivateMessagePacketCopyWith<$Res> {
  factory $PrivateMessagePacketCopyWith(PrivateMessagePacket value,
          $Res Function(PrivateMessagePacket) then) =
      _$PrivateMessagePacketCopyWithImpl<$Res, PrivateMessagePacket>;
  @useResult
  $Res call({String messageID, String content});
}

/// @nodoc
class _$PrivateMessagePacketCopyWithImpl<$Res,
        $Val extends PrivateMessagePacket>
    implements $PrivateMessagePacketCopyWith<$Res> {
  _$PrivateMessagePacketCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? messageID = null,
    Object? content = null,
  }) {
    return _then(_value.copyWith(
      messageID: null == messageID
          ? _value.messageID
          : messageID // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PrivateMessagePacketImplCopyWith<$Res>
    implements $PrivateMessagePacketCopyWith<$Res> {
  factory _$$PrivateMessagePacketImplCopyWith(_$PrivateMessagePacketImpl value,
          $Res Function(_$PrivateMessagePacketImpl) then) =
      __$$PrivateMessagePacketImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String messageID, String content});
}

/// @nodoc
class __$$PrivateMessagePacketImplCopyWithImpl<$Res>
    extends _$PrivateMessagePacketCopyWithImpl<$Res, _$PrivateMessagePacketImpl>
    implements _$$PrivateMessagePacketImplCopyWith<$Res> {
  __$$PrivateMessagePacketImplCopyWithImpl(_$PrivateMessagePacketImpl _value,
      $Res Function(_$PrivateMessagePacketImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? messageID = null,
    Object? content = null,
  }) {
    return _then(_$PrivateMessagePacketImpl(
      messageID: null == messageID
          ? _value.messageID
          : messageID // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PrivateMessagePacketImpl extends _PrivateMessagePacket {
  const _$PrivateMessagePacketImpl(
      {required this.messageID, required this.content})
      : super._();

  factory _$PrivateMessagePacketImpl.fromJson(Map<String, dynamic> json) =>
      _$$PrivateMessagePacketImplFromJson(json);

  @override
  final String messageID;
  @override
  final String content;

  @override
  String toString() {
    return 'PrivateMessagePacket(messageID: $messageID, content: $content)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PrivateMessagePacketImpl &&
            (identical(other.messageID, messageID) ||
                other.messageID == messageID) &&
            (identical(other.content, content) || other.content == content));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, messageID, content);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PrivateMessagePacketImplCopyWith<_$PrivateMessagePacketImpl>
      get copyWith =>
          __$$PrivateMessagePacketImplCopyWithImpl<_$PrivateMessagePacketImpl>(
              this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PrivateMessagePacketImplToJson(
      this,
    );
  }
}

abstract class _PrivateMessagePacket extends PrivateMessagePacket {
  const factory _PrivateMessagePacket(
      {required final String messageID,
      required final String content}) = _$PrivateMessagePacketImpl;
  const _PrivateMessagePacket._() : super._();

  factory _PrivateMessagePacket.fromJson(Map<String, dynamic> json) =
      _$PrivateMessagePacketImpl.fromJson;

  @override
  String get messageID;
  @override
  String get content;
  @override
  @JsonKey(ignore: true)
  _$$PrivateMessagePacketImplCopyWith<_$PrivateMessagePacketImpl>
      get copyWith => throw _privateConstructorUsedError;
}

NoiseEncrypted _$NoiseEncryptedFromJson(Map<String, dynamic> json) {
  return _NoiseEncrypted.fromJson(json);
}

/// @nodoc
mixin _$NoiseEncrypted {
  @Uint8ListBase64Converter()
  Uint8List? get ephemeralKey => throw _privateConstructorUsedError;
  @Uint8ListBase64Converter()
  Uint8List? get ciphertext => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $NoiseEncryptedCopyWith<NoiseEncrypted> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NoiseEncryptedCopyWith<$Res> {
  factory $NoiseEncryptedCopyWith(
          NoiseEncrypted value, $Res Function(NoiseEncrypted) then) =
      _$NoiseEncryptedCopyWithImpl<$Res, NoiseEncrypted>;
  @useResult
  $Res call(
      {@Uint8ListBase64Converter() Uint8List? ephemeralKey,
      @Uint8ListBase64Converter() Uint8List? ciphertext});
}

/// @nodoc
class _$NoiseEncryptedCopyWithImpl<$Res, $Val extends NoiseEncrypted>
    implements $NoiseEncryptedCopyWith<$Res> {
  _$NoiseEncryptedCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? ephemeralKey = freezed,
    Object? ciphertext = freezed,
  }) {
    return _then(_value.copyWith(
      ephemeralKey: freezed == ephemeralKey
          ? _value.ephemeralKey
          : ephemeralKey // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
      ciphertext: freezed == ciphertext
          ? _value.ciphertext
          : ciphertext // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$NoiseEncryptedImplCopyWith<$Res>
    implements $NoiseEncryptedCopyWith<$Res> {
  factory _$$NoiseEncryptedImplCopyWith(_$NoiseEncryptedImpl value,
          $Res Function(_$NoiseEncryptedImpl) then) =
      __$$NoiseEncryptedImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@Uint8ListBase64Converter() Uint8List? ephemeralKey,
      @Uint8ListBase64Converter() Uint8List? ciphertext});
}

/// @nodoc
class __$$NoiseEncryptedImplCopyWithImpl<$Res>
    extends _$NoiseEncryptedCopyWithImpl<$Res, _$NoiseEncryptedImpl>
    implements _$$NoiseEncryptedImplCopyWith<$Res> {
  __$$NoiseEncryptedImplCopyWithImpl(
      _$NoiseEncryptedImpl _value, $Res Function(_$NoiseEncryptedImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? ephemeralKey = freezed,
    Object? ciphertext = freezed,
  }) {
    return _then(_$NoiseEncryptedImpl(
      ephemeralKey: freezed == ephemeralKey
          ? _value.ephemeralKey
          : ephemeralKey // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
      ciphertext: freezed == ciphertext
          ? _value.ciphertext
          : ciphertext // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$NoiseEncryptedImpl implements _NoiseEncrypted {
  const _$NoiseEncryptedImpl(
      {@Uint8ListBase64Converter() this.ephemeralKey,
      @Uint8ListBase64Converter() this.ciphertext});

  factory _$NoiseEncryptedImpl.fromJson(Map<String, dynamic> json) =>
      _$$NoiseEncryptedImplFromJson(json);

  @override
  @Uint8ListBase64Converter()
  final Uint8List? ephemeralKey;
  @override
  @Uint8ListBase64Converter()
  final Uint8List? ciphertext;

  @override
  String toString() {
    return 'NoiseEncrypted(ephemeralKey: $ephemeralKey, ciphertext: $ciphertext)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NoiseEncryptedImpl &&
            const DeepCollectionEquality()
                .equals(other.ephemeralKey, ephemeralKey) &&
            const DeepCollectionEquality()
                .equals(other.ciphertext, ciphertext));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(ephemeralKey),
      const DeepCollectionEquality().hash(ciphertext));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$NoiseEncryptedImplCopyWith<_$NoiseEncryptedImpl> get copyWith =>
      __$$NoiseEncryptedImplCopyWithImpl<_$NoiseEncryptedImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NoiseEncryptedImplToJson(
      this,
    );
  }
}

abstract class _NoiseEncrypted implements NoiseEncrypted {
  const factory _NoiseEncrypted(
          {@Uint8ListBase64Converter() final Uint8List? ephemeralKey,
          @Uint8ListBase64Converter() final Uint8List? ciphertext}) =
      _$NoiseEncryptedImpl;

  factory _NoiseEncrypted.fromJson(Map<String, dynamic> json) =
      _$NoiseEncryptedImpl.fromJson;

  @override
  @Uint8ListBase64Converter()
  Uint8List? get ephemeralKey;
  @override
  @Uint8ListBase64Converter()
  Uint8List? get ciphertext;
  @override
  @JsonKey(ignore: true)
  _$$NoiseEncryptedImplCopyWith<_$NoiseEncryptedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
