// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bitchat_file_packet.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

BitchatFilePacket _$BitchatFilePacketFromJson(Map<String, dynamic> json) {
  return _BitchatFilePacket.fromJson(json);
}

/// @nodoc
mixin _$BitchatFilePacket {
  String get fileName => throw _privateConstructorUsedError;
  int get fileSize => throw _privateConstructorUsedError;
  String get mimeType => throw _privateConstructorUsedError;
  @Uint8ListBase64Converter()
  Uint8List? get content => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $BitchatFilePacketCopyWith<BitchatFilePacket> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BitchatFilePacketCopyWith<$Res> {
  factory $BitchatFilePacketCopyWith(
          BitchatFilePacket value, $Res Function(BitchatFilePacket) then) =
      _$BitchatFilePacketCopyWithImpl<$Res, BitchatFilePacket>;
  @useResult
  $Res call(
      {String fileName,
      int fileSize,
      String mimeType,
      @Uint8ListBase64Converter() Uint8List? content});
}

/// @nodoc
class _$BitchatFilePacketCopyWithImpl<$Res, $Val extends BitchatFilePacket>
    implements $BitchatFilePacketCopyWith<$Res> {
  _$BitchatFilePacketCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fileName = null,
    Object? fileSize = null,
    Object? mimeType = null,
    Object? content = freezed,
  }) {
    return _then(_value.copyWith(
      fileName: null == fileName
          ? _value.fileName
          : fileName // ignore: cast_nullable_to_non_nullable
              as String,
      fileSize: null == fileSize
          ? _value.fileSize
          : fileSize // ignore: cast_nullable_to_non_nullable
              as int,
      mimeType: null == mimeType
          ? _value.mimeType
          : mimeType // ignore: cast_nullable_to_non_nullable
              as String,
      content: freezed == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BitchatFilePacketImplCopyWith<$Res>
    implements $BitchatFilePacketCopyWith<$Res> {
  factory _$$BitchatFilePacketImplCopyWith(_$BitchatFilePacketImpl value,
          $Res Function(_$BitchatFilePacketImpl) then) =
      __$$BitchatFilePacketImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String fileName,
      int fileSize,
      String mimeType,
      @Uint8ListBase64Converter() Uint8List? content});
}

/// @nodoc
class __$$BitchatFilePacketImplCopyWithImpl<$Res>
    extends _$BitchatFilePacketCopyWithImpl<$Res, _$BitchatFilePacketImpl>
    implements _$$BitchatFilePacketImplCopyWith<$Res> {
  __$$BitchatFilePacketImplCopyWithImpl(_$BitchatFilePacketImpl _value,
      $Res Function(_$BitchatFilePacketImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fileName = null,
    Object? fileSize = null,
    Object? mimeType = null,
    Object? content = freezed,
  }) {
    return _then(_$BitchatFilePacketImpl(
      fileName: null == fileName
          ? _value.fileName
          : fileName // ignore: cast_nullable_to_non_nullable
              as String,
      fileSize: null == fileSize
          ? _value.fileSize
          : fileSize // ignore: cast_nullable_to_non_nullable
              as int,
      mimeType: null == mimeType
          ? _value.mimeType
          : mimeType // ignore: cast_nullable_to_non_nullable
              as String,
      content: freezed == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BitchatFilePacketImpl extends _BitchatFilePacket {
  const _$BitchatFilePacketImpl(
      {required this.fileName,
      required this.fileSize,
      required this.mimeType,
      @Uint8ListBase64Converter() this.content})
      : super._();

  factory _$BitchatFilePacketImpl.fromJson(Map<String, dynamic> json) =>
      _$$BitchatFilePacketImplFromJson(json);

  @override
  final String fileName;
  @override
  final int fileSize;
  @override
  final String mimeType;
  @override
  @Uint8ListBase64Converter()
  final Uint8List? content;

  @override
  String toString() {
    return 'BitchatFilePacket(fileName: $fileName, fileSize: $fileSize, mimeType: $mimeType, content: $content)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BitchatFilePacketImpl &&
            (identical(other.fileName, fileName) ||
                other.fileName == fileName) &&
            (identical(other.fileSize, fileSize) ||
                other.fileSize == fileSize) &&
            (identical(other.mimeType, mimeType) ||
                other.mimeType == mimeType) &&
            const DeepCollectionEquality().equals(other.content, content));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, fileName, fileSize, mimeType,
      const DeepCollectionEquality().hash(content));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$BitchatFilePacketImplCopyWith<_$BitchatFilePacketImpl> get copyWith =>
      __$$BitchatFilePacketImplCopyWithImpl<_$BitchatFilePacketImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BitchatFilePacketImplToJson(
      this,
    );
  }
}

abstract class _BitchatFilePacket extends BitchatFilePacket {
  const factory _BitchatFilePacket(
          {required final String fileName,
          required final int fileSize,
          required final String mimeType,
          @Uint8ListBase64Converter() final Uint8List? content}) =
      _$BitchatFilePacketImpl;
  const _BitchatFilePacket._() : super._();

  factory _BitchatFilePacket.fromJson(Map<String, dynamic> json) =
      _$BitchatFilePacketImpl.fromJson;

  @override
  String get fileName;
  @override
  int get fileSize;
  @override
  String get mimeType;
  @override
  @Uint8ListBase64Converter()
  Uint8List? get content;
  @override
  @JsonKey(ignore: true)
  _$$BitchatFilePacketImplCopyWith<_$BitchatFilePacketImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
