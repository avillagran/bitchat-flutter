// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'identity_announcement.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

IdentityAnnouncement _$IdentityAnnouncementFromJson(Map<String, dynamic> json) {
  return _IdentityAnnouncement.fromJson(json);
}

/// @nodoc
mixin _$IdentityAnnouncement {
  String get nickname => throw _privateConstructorUsedError;
  @Uint8ListBase64Converter()
  Uint8List? get noisePublicKey => throw _privateConstructorUsedError;
  @Uint8ListBase64Converter()
  Uint8List? get signingPublicKey => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $IdentityAnnouncementCopyWith<IdentityAnnouncement> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $IdentityAnnouncementCopyWith<$Res> {
  factory $IdentityAnnouncementCopyWith(IdentityAnnouncement value,
          $Res Function(IdentityAnnouncement) then) =
      _$IdentityAnnouncementCopyWithImpl<$Res, IdentityAnnouncement>;
  @useResult
  $Res call(
      {String nickname,
      @Uint8ListBase64Converter() Uint8List? noisePublicKey,
      @Uint8ListBase64Converter() Uint8List? signingPublicKey});
}

/// @nodoc
class _$IdentityAnnouncementCopyWithImpl<$Res,
        $Val extends IdentityAnnouncement>
    implements $IdentityAnnouncementCopyWith<$Res> {
  _$IdentityAnnouncementCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? nickname = null,
    Object? noisePublicKey = freezed,
    Object? signingPublicKey = freezed,
  }) {
    return _then(_value.copyWith(
      nickname: null == nickname
          ? _value.nickname
          : nickname // ignore: cast_nullable_to_non_nullable
              as String,
      noisePublicKey: freezed == noisePublicKey
          ? _value.noisePublicKey
          : noisePublicKey // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
      signingPublicKey: freezed == signingPublicKey
          ? _value.signingPublicKey
          : signingPublicKey // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$IdentityAnnouncementImplCopyWith<$Res>
    implements $IdentityAnnouncementCopyWith<$Res> {
  factory _$$IdentityAnnouncementImplCopyWith(_$IdentityAnnouncementImpl value,
          $Res Function(_$IdentityAnnouncementImpl) then) =
      __$$IdentityAnnouncementImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String nickname,
      @Uint8ListBase64Converter() Uint8List? noisePublicKey,
      @Uint8ListBase64Converter() Uint8List? signingPublicKey});
}

/// @nodoc
class __$$IdentityAnnouncementImplCopyWithImpl<$Res>
    extends _$IdentityAnnouncementCopyWithImpl<$Res, _$IdentityAnnouncementImpl>
    implements _$$IdentityAnnouncementImplCopyWith<$Res> {
  __$$IdentityAnnouncementImplCopyWithImpl(_$IdentityAnnouncementImpl _value,
      $Res Function(_$IdentityAnnouncementImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? nickname = null,
    Object? noisePublicKey = freezed,
    Object? signingPublicKey = freezed,
  }) {
    return _then(_$IdentityAnnouncementImpl(
      nickname: null == nickname
          ? _value.nickname
          : nickname // ignore: cast_nullable_to_non_nullable
              as String,
      noisePublicKey: freezed == noisePublicKey
          ? _value.noisePublicKey
          : noisePublicKey // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
      signingPublicKey: freezed == signingPublicKey
          ? _value.signingPublicKey
          : signingPublicKey // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$IdentityAnnouncementImpl extends _IdentityAnnouncement {
  const _$IdentityAnnouncementImpl(
      {required this.nickname,
      @Uint8ListBase64Converter() this.noisePublicKey,
      @Uint8ListBase64Converter() this.signingPublicKey})
      : super._();

  factory _$IdentityAnnouncementImpl.fromJson(Map<String, dynamic> json) =>
      _$$IdentityAnnouncementImplFromJson(json);

  @override
  final String nickname;
  @override
  @Uint8ListBase64Converter()
  final Uint8List? noisePublicKey;
  @override
  @Uint8ListBase64Converter()
  final Uint8List? signingPublicKey;

  @override
  String toString() {
    return 'IdentityAnnouncement(nickname: $nickname, noisePublicKey: $noisePublicKey, signingPublicKey: $signingPublicKey)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$IdentityAnnouncementImpl &&
            (identical(other.nickname, nickname) ||
                other.nickname == nickname) &&
            const DeepCollectionEquality()
                .equals(other.noisePublicKey, noisePublicKey) &&
            const DeepCollectionEquality()
                .equals(other.signingPublicKey, signingPublicKey));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      nickname,
      const DeepCollectionEquality().hash(noisePublicKey),
      const DeepCollectionEquality().hash(signingPublicKey));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$IdentityAnnouncementImplCopyWith<_$IdentityAnnouncementImpl>
      get copyWith =>
          __$$IdentityAnnouncementImplCopyWithImpl<_$IdentityAnnouncementImpl>(
              this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$IdentityAnnouncementImplToJson(
      this,
    );
  }
}

abstract class _IdentityAnnouncement extends IdentityAnnouncement {
  const factory _IdentityAnnouncement(
          {required final String nickname,
          @Uint8ListBase64Converter() final Uint8List? noisePublicKey,
          @Uint8ListBase64Converter() final Uint8List? signingPublicKey}) =
      _$IdentityAnnouncementImpl;
  const _IdentityAnnouncement._() : super._();

  factory _IdentityAnnouncement.fromJson(Map<String, dynamic> json) =
      _$IdentityAnnouncementImpl.fromJson;

  @override
  String get nickname;
  @override
  @Uint8ListBase64Converter()
  Uint8List? get noisePublicKey;
  @override
  @Uint8ListBase64Converter()
  Uint8List? get signingPublicKey;
  @override
  @JsonKey(ignore: true)
  _$$IdentityAnnouncementImplCopyWith<_$IdentityAnnouncementImpl>
      get copyWith => throw _privateConstructorUsedError;
}
