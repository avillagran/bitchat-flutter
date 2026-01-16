// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'fragment_payload.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

FragmentPayload _$FragmentPayloadFromJson(Map<String, dynamic> json) {
  return _FragmentPayload.fromJson(json);
}

/// @nodoc
mixin _$FragmentPayload {
  @Uint8ListBase64Converter()
  Uint8List? get fragmentID => throw _privateConstructorUsedError;
  int get index => throw _privateConstructorUsedError;
  int get total => throw _privateConstructorUsedError;
  int get originalType => throw _privateConstructorUsedError;
  @Uint8ListBase64Converter()
  Uint8List? get data => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $FragmentPayloadCopyWith<FragmentPayload> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FragmentPayloadCopyWith<$Res> {
  factory $FragmentPayloadCopyWith(
          FragmentPayload value, $Res Function(FragmentPayload) then) =
      _$FragmentPayloadCopyWithImpl<$Res, FragmentPayload>;
  @useResult
  $Res call(
      {@Uint8ListBase64Converter() Uint8List? fragmentID,
      int index,
      int total,
      int originalType,
      @Uint8ListBase64Converter() Uint8List? data});
}

/// @nodoc
class _$FragmentPayloadCopyWithImpl<$Res, $Val extends FragmentPayload>
    implements $FragmentPayloadCopyWith<$Res> {
  _$FragmentPayloadCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fragmentID = freezed,
    Object? index = null,
    Object? total = null,
    Object? originalType = null,
    Object? data = freezed,
  }) {
    return _then(_value.copyWith(
      fragmentID: freezed == fragmentID
          ? _value.fragmentID
          : fragmentID // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
      index: null == index
          ? _value.index
          : index // ignore: cast_nullable_to_non_nullable
              as int,
      total: null == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
      originalType: null == originalType
          ? _value.originalType
          : originalType // ignore: cast_nullable_to_non_nullable
              as int,
      data: freezed == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FragmentPayloadImplCopyWith<$Res>
    implements $FragmentPayloadCopyWith<$Res> {
  factory _$$FragmentPayloadImplCopyWith(_$FragmentPayloadImpl value,
          $Res Function(_$FragmentPayloadImpl) then) =
      __$$FragmentPayloadImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@Uint8ListBase64Converter() Uint8List? fragmentID,
      int index,
      int total,
      int originalType,
      @Uint8ListBase64Converter() Uint8List? data});
}

/// @nodoc
class __$$FragmentPayloadImplCopyWithImpl<$Res>
    extends _$FragmentPayloadCopyWithImpl<$Res, _$FragmentPayloadImpl>
    implements _$$FragmentPayloadImplCopyWith<$Res> {
  __$$FragmentPayloadImplCopyWithImpl(
      _$FragmentPayloadImpl _value, $Res Function(_$FragmentPayloadImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fragmentID = freezed,
    Object? index = null,
    Object? total = null,
    Object? originalType = null,
    Object? data = freezed,
  }) {
    return _then(_$FragmentPayloadImpl(
      fragmentID: freezed == fragmentID
          ? _value.fragmentID
          : fragmentID // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
      index: null == index
          ? _value.index
          : index // ignore: cast_nullable_to_non_nullable
              as int,
      total: null == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
      originalType: null == originalType
          ? _value.originalType
          : originalType // ignore: cast_nullable_to_non_nullable
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
class _$FragmentPayloadImpl extends _FragmentPayload {
  const _$FragmentPayloadImpl(
      {@Uint8ListBase64Converter() this.fragmentID,
      required this.index,
      required this.total,
      required this.originalType,
      @Uint8ListBase64Converter() this.data})
      : super._();

  factory _$FragmentPayloadImpl.fromJson(Map<String, dynamic> json) =>
      _$$FragmentPayloadImplFromJson(json);

  @override
  @Uint8ListBase64Converter()
  final Uint8List? fragmentID;
  @override
  final int index;
  @override
  final int total;
  @override
  final int originalType;
  @override
  @Uint8ListBase64Converter()
  final Uint8List? data;

  @override
  String toString() {
    return 'FragmentPayload(fragmentID: $fragmentID, index: $index, total: $total, originalType: $originalType, data: $data)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FragmentPayloadImpl &&
            const DeepCollectionEquality()
                .equals(other.fragmentID, fragmentID) &&
            (identical(other.index, index) || other.index == index) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.originalType, originalType) ||
                other.originalType == originalType) &&
            const DeepCollectionEquality().equals(other.data, data));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(fragmentID),
      index,
      total,
      originalType,
      const DeepCollectionEquality().hash(data));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$FragmentPayloadImplCopyWith<_$FragmentPayloadImpl> get copyWith =>
      __$$FragmentPayloadImplCopyWithImpl<_$FragmentPayloadImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FragmentPayloadImplToJson(
      this,
    );
  }
}

abstract class _FragmentPayload extends FragmentPayload {
  const factory _FragmentPayload(
          {@Uint8ListBase64Converter() final Uint8List? fragmentID,
          required final int index,
          required final int total,
          required final int originalType,
          @Uint8ListBase64Converter() final Uint8List? data}) =
      _$FragmentPayloadImpl;
  const _FragmentPayload._() : super._();

  factory _FragmentPayload.fromJson(Map<String, dynamic> json) =
      _$FragmentPayloadImpl.fromJson;

  @override
  @Uint8ListBase64Converter()
  Uint8List? get fragmentID;
  @override
  int get index;
  @override
  int get total;
  @override
  int get originalType;
  @override
  @Uint8ListBase64Converter()
  Uint8List? get data;
  @override
  @JsonKey(ignore: true)
  _$$FragmentPayloadImplCopyWith<_$FragmentPayloadImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
