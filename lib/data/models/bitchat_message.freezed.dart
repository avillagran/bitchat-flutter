// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bitchat_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

DeliveryStatus _$DeliveryStatusFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'sending':
      return Sending.fromJson(json);
    case 'sent':
      return Sent.fromJson(json);
    case 'delivered':
      return Delivered.fromJson(json);
    case 'read':
      return Read.fromJson(json);
    case 'failed':
      return Failed.fromJson(json);
    case 'partiallyDelivered':
      return PartiallyDelivered.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'DeliveryStatus',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$DeliveryStatus {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() sending,
    required TResult Function() sent,
    required TResult Function(String to, DateTime at) delivered,
    required TResult Function(String by, DateTime at) read,
    required TResult Function(String reason) failed,
    required TResult Function(int reached, int total) partiallyDelivered,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? sending,
    TResult? Function()? sent,
    TResult? Function(String to, DateTime at)? delivered,
    TResult? Function(String by, DateTime at)? read,
    TResult? Function(String reason)? failed,
    TResult? Function(int reached, int total)? partiallyDelivered,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? sending,
    TResult Function()? sent,
    TResult Function(String to, DateTime at)? delivered,
    TResult Function(String by, DateTime at)? read,
    TResult Function(String reason)? failed,
    TResult Function(int reached, int total)? partiallyDelivered,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(Sending value) sending,
    required TResult Function(Sent value) sent,
    required TResult Function(Delivered value) delivered,
    required TResult Function(Read value) read,
    required TResult Function(Failed value) failed,
    required TResult Function(PartiallyDelivered value) partiallyDelivered,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(Sending value)? sending,
    TResult? Function(Sent value)? sent,
    TResult? Function(Delivered value)? delivered,
    TResult? Function(Read value)? read,
    TResult? Function(Failed value)? failed,
    TResult? Function(PartiallyDelivered value)? partiallyDelivered,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(Sending value)? sending,
    TResult Function(Sent value)? sent,
    TResult Function(Delivered value)? delivered,
    TResult Function(Read value)? read,
    TResult Function(Failed value)? failed,
    TResult Function(PartiallyDelivered value)? partiallyDelivered,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DeliveryStatusCopyWith<$Res> {
  factory $DeliveryStatusCopyWith(
          DeliveryStatus value, $Res Function(DeliveryStatus) then) =
      _$DeliveryStatusCopyWithImpl<$Res, DeliveryStatus>;
}

/// @nodoc
class _$DeliveryStatusCopyWithImpl<$Res, $Val extends DeliveryStatus>
    implements $DeliveryStatusCopyWith<$Res> {
  _$DeliveryStatusCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;
}

/// @nodoc
abstract class _$$SendingImplCopyWith<$Res> {
  factory _$$SendingImplCopyWith(
          _$SendingImpl value, $Res Function(_$SendingImpl) then) =
      __$$SendingImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$SendingImplCopyWithImpl<$Res>
    extends _$DeliveryStatusCopyWithImpl<$Res, _$SendingImpl>
    implements _$$SendingImplCopyWith<$Res> {
  __$$SendingImplCopyWithImpl(
      _$SendingImpl _value, $Res Function(_$SendingImpl) _then)
      : super(_value, _then);
}

/// @nodoc
@JsonSerializable()
class _$SendingImpl with DiagnosticableTreeMixin implements Sending {
  const _$SendingImpl({final String? $type}) : $type = $type ?? 'sending';

  factory _$SendingImpl.fromJson(Map<String, dynamic> json) =>
      _$$SendingImplFromJson(json);

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'DeliveryStatus.sending()';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty('type', 'DeliveryStatus.sending'));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$SendingImpl);
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() sending,
    required TResult Function() sent,
    required TResult Function(String to, DateTime at) delivered,
    required TResult Function(String by, DateTime at) read,
    required TResult Function(String reason) failed,
    required TResult Function(int reached, int total) partiallyDelivered,
  }) {
    return sending();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? sending,
    TResult? Function()? sent,
    TResult? Function(String to, DateTime at)? delivered,
    TResult? Function(String by, DateTime at)? read,
    TResult? Function(String reason)? failed,
    TResult? Function(int reached, int total)? partiallyDelivered,
  }) {
    return sending?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? sending,
    TResult Function()? sent,
    TResult Function(String to, DateTime at)? delivered,
    TResult Function(String by, DateTime at)? read,
    TResult Function(String reason)? failed,
    TResult Function(int reached, int total)? partiallyDelivered,
    required TResult orElse(),
  }) {
    if (sending != null) {
      return sending();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(Sending value) sending,
    required TResult Function(Sent value) sent,
    required TResult Function(Delivered value) delivered,
    required TResult Function(Read value) read,
    required TResult Function(Failed value) failed,
    required TResult Function(PartiallyDelivered value) partiallyDelivered,
  }) {
    return sending(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(Sending value)? sending,
    TResult? Function(Sent value)? sent,
    TResult? Function(Delivered value)? delivered,
    TResult? Function(Read value)? read,
    TResult? Function(Failed value)? failed,
    TResult? Function(PartiallyDelivered value)? partiallyDelivered,
  }) {
    return sending?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(Sending value)? sending,
    TResult Function(Sent value)? sent,
    TResult Function(Delivered value)? delivered,
    TResult Function(Read value)? read,
    TResult Function(Failed value)? failed,
    TResult Function(PartiallyDelivered value)? partiallyDelivered,
    required TResult orElse(),
  }) {
    if (sending != null) {
      return sending(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$SendingImplToJson(
      this,
    );
  }
}

abstract class Sending implements DeliveryStatus {
  const factory Sending() = _$SendingImpl;

  factory Sending.fromJson(Map<String, dynamic> json) = _$SendingImpl.fromJson;
}

/// @nodoc
abstract class _$$SentImplCopyWith<$Res> {
  factory _$$SentImplCopyWith(
          _$SentImpl value, $Res Function(_$SentImpl) then) =
      __$$SentImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$SentImplCopyWithImpl<$Res>
    extends _$DeliveryStatusCopyWithImpl<$Res, _$SentImpl>
    implements _$$SentImplCopyWith<$Res> {
  __$$SentImplCopyWithImpl(_$SentImpl _value, $Res Function(_$SentImpl) _then)
      : super(_value, _then);
}

/// @nodoc
@JsonSerializable()
class _$SentImpl with DiagnosticableTreeMixin implements Sent {
  const _$SentImpl({final String? $type}) : $type = $type ?? 'sent';

  factory _$SentImpl.fromJson(Map<String, dynamic> json) =>
      _$$SentImplFromJson(json);

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'DeliveryStatus.sent()';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty('type', 'DeliveryStatus.sent'));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$SentImpl);
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() sending,
    required TResult Function() sent,
    required TResult Function(String to, DateTime at) delivered,
    required TResult Function(String by, DateTime at) read,
    required TResult Function(String reason) failed,
    required TResult Function(int reached, int total) partiallyDelivered,
  }) {
    return sent();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? sending,
    TResult? Function()? sent,
    TResult? Function(String to, DateTime at)? delivered,
    TResult? Function(String by, DateTime at)? read,
    TResult? Function(String reason)? failed,
    TResult? Function(int reached, int total)? partiallyDelivered,
  }) {
    return sent?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? sending,
    TResult Function()? sent,
    TResult Function(String to, DateTime at)? delivered,
    TResult Function(String by, DateTime at)? read,
    TResult Function(String reason)? failed,
    TResult Function(int reached, int total)? partiallyDelivered,
    required TResult orElse(),
  }) {
    if (sent != null) {
      return sent();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(Sending value) sending,
    required TResult Function(Sent value) sent,
    required TResult Function(Delivered value) delivered,
    required TResult Function(Read value) read,
    required TResult Function(Failed value) failed,
    required TResult Function(PartiallyDelivered value) partiallyDelivered,
  }) {
    return sent(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(Sending value)? sending,
    TResult? Function(Sent value)? sent,
    TResult? Function(Delivered value)? delivered,
    TResult? Function(Read value)? read,
    TResult? Function(Failed value)? failed,
    TResult? Function(PartiallyDelivered value)? partiallyDelivered,
  }) {
    return sent?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(Sending value)? sending,
    TResult Function(Sent value)? sent,
    TResult Function(Delivered value)? delivered,
    TResult Function(Read value)? read,
    TResult Function(Failed value)? failed,
    TResult Function(PartiallyDelivered value)? partiallyDelivered,
    required TResult orElse(),
  }) {
    if (sent != null) {
      return sent(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$SentImplToJson(
      this,
    );
  }
}

abstract class Sent implements DeliveryStatus {
  const factory Sent() = _$SentImpl;

  factory Sent.fromJson(Map<String, dynamic> json) = _$SentImpl.fromJson;
}

/// @nodoc
abstract class _$$DeliveredImplCopyWith<$Res> {
  factory _$$DeliveredImplCopyWith(
          _$DeliveredImpl value, $Res Function(_$DeliveredImpl) then) =
      __$$DeliveredImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String to, DateTime at});
}

/// @nodoc
class __$$DeliveredImplCopyWithImpl<$Res>
    extends _$DeliveryStatusCopyWithImpl<$Res, _$DeliveredImpl>
    implements _$$DeliveredImplCopyWith<$Res> {
  __$$DeliveredImplCopyWithImpl(
      _$DeliveredImpl _value, $Res Function(_$DeliveredImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? to = null,
    Object? at = null,
  }) {
    return _then(_$DeliveredImpl(
      to: null == to
          ? _value.to
          : to // ignore: cast_nullable_to_non_nullable
              as String,
      at: null == at
          ? _value.at
          : at // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DeliveredImpl with DiagnosticableTreeMixin implements Delivered {
  const _$DeliveredImpl(
      {required this.to, required this.at, final String? $type})
      : $type = $type ?? 'delivered';

  factory _$DeliveredImpl.fromJson(Map<String, dynamic> json) =>
      _$$DeliveredImplFromJson(json);

  @override
  final String to;
  @override
  final DateTime at;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'DeliveryStatus.delivered(to: $to, at: $at)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'DeliveryStatus.delivered'))
      ..add(DiagnosticsProperty('to', to))
      ..add(DiagnosticsProperty('at', at));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DeliveredImpl &&
            (identical(other.to, to) || other.to == to) &&
            (identical(other.at, at) || other.at == at));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, to, at);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$DeliveredImplCopyWith<_$DeliveredImpl> get copyWith =>
      __$$DeliveredImplCopyWithImpl<_$DeliveredImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() sending,
    required TResult Function() sent,
    required TResult Function(String to, DateTime at) delivered,
    required TResult Function(String by, DateTime at) read,
    required TResult Function(String reason) failed,
    required TResult Function(int reached, int total) partiallyDelivered,
  }) {
    return delivered(to, at);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? sending,
    TResult? Function()? sent,
    TResult? Function(String to, DateTime at)? delivered,
    TResult? Function(String by, DateTime at)? read,
    TResult? Function(String reason)? failed,
    TResult? Function(int reached, int total)? partiallyDelivered,
  }) {
    return delivered?.call(to, at);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? sending,
    TResult Function()? sent,
    TResult Function(String to, DateTime at)? delivered,
    TResult Function(String by, DateTime at)? read,
    TResult Function(String reason)? failed,
    TResult Function(int reached, int total)? partiallyDelivered,
    required TResult orElse(),
  }) {
    if (delivered != null) {
      return delivered(to, at);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(Sending value) sending,
    required TResult Function(Sent value) sent,
    required TResult Function(Delivered value) delivered,
    required TResult Function(Read value) read,
    required TResult Function(Failed value) failed,
    required TResult Function(PartiallyDelivered value) partiallyDelivered,
  }) {
    return delivered(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(Sending value)? sending,
    TResult? Function(Sent value)? sent,
    TResult? Function(Delivered value)? delivered,
    TResult? Function(Read value)? read,
    TResult? Function(Failed value)? failed,
    TResult? Function(PartiallyDelivered value)? partiallyDelivered,
  }) {
    return delivered?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(Sending value)? sending,
    TResult Function(Sent value)? sent,
    TResult Function(Delivered value)? delivered,
    TResult Function(Read value)? read,
    TResult Function(Failed value)? failed,
    TResult Function(PartiallyDelivered value)? partiallyDelivered,
    required TResult orElse(),
  }) {
    if (delivered != null) {
      return delivered(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$DeliveredImplToJson(
      this,
    );
  }
}

abstract class Delivered implements DeliveryStatus {
  const factory Delivered(
      {required final String to, required final DateTime at}) = _$DeliveredImpl;

  factory Delivered.fromJson(Map<String, dynamic> json) =
      _$DeliveredImpl.fromJson;

  String get to;
  DateTime get at;
  @JsonKey(ignore: true)
  _$$DeliveredImplCopyWith<_$DeliveredImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ReadImplCopyWith<$Res> {
  factory _$$ReadImplCopyWith(
          _$ReadImpl value, $Res Function(_$ReadImpl) then) =
      __$$ReadImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String by, DateTime at});
}

/// @nodoc
class __$$ReadImplCopyWithImpl<$Res>
    extends _$DeliveryStatusCopyWithImpl<$Res, _$ReadImpl>
    implements _$$ReadImplCopyWith<$Res> {
  __$$ReadImplCopyWithImpl(_$ReadImpl _value, $Res Function(_$ReadImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? by = null,
    Object? at = null,
  }) {
    return _then(_$ReadImpl(
      by: null == by
          ? _value.by
          : by // ignore: cast_nullable_to_non_nullable
              as String,
      at: null == at
          ? _value.at
          : at // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ReadImpl with DiagnosticableTreeMixin implements Read {
  const _$ReadImpl({required this.by, required this.at, final String? $type})
      : $type = $type ?? 'read';

  factory _$ReadImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReadImplFromJson(json);

  @override
  final String by;
  @override
  final DateTime at;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'DeliveryStatus.read(by: $by, at: $at)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'DeliveryStatus.read'))
      ..add(DiagnosticsProperty('by', by))
      ..add(DiagnosticsProperty('at', at));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReadImpl &&
            (identical(other.by, by) || other.by == by) &&
            (identical(other.at, at) || other.at == at));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, by, at);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ReadImplCopyWith<_$ReadImpl> get copyWith =>
      __$$ReadImplCopyWithImpl<_$ReadImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() sending,
    required TResult Function() sent,
    required TResult Function(String to, DateTime at) delivered,
    required TResult Function(String by, DateTime at) read,
    required TResult Function(String reason) failed,
    required TResult Function(int reached, int total) partiallyDelivered,
  }) {
    return read(by, at);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? sending,
    TResult? Function()? sent,
    TResult? Function(String to, DateTime at)? delivered,
    TResult? Function(String by, DateTime at)? read,
    TResult? Function(String reason)? failed,
    TResult? Function(int reached, int total)? partiallyDelivered,
  }) {
    return read?.call(by, at);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? sending,
    TResult Function()? sent,
    TResult Function(String to, DateTime at)? delivered,
    TResult Function(String by, DateTime at)? read,
    TResult Function(String reason)? failed,
    TResult Function(int reached, int total)? partiallyDelivered,
    required TResult orElse(),
  }) {
    if (read != null) {
      return read(by, at);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(Sending value) sending,
    required TResult Function(Sent value) sent,
    required TResult Function(Delivered value) delivered,
    required TResult Function(Read value) read,
    required TResult Function(Failed value) failed,
    required TResult Function(PartiallyDelivered value) partiallyDelivered,
  }) {
    return read(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(Sending value)? sending,
    TResult? Function(Sent value)? sent,
    TResult? Function(Delivered value)? delivered,
    TResult? Function(Read value)? read,
    TResult? Function(Failed value)? failed,
    TResult? Function(PartiallyDelivered value)? partiallyDelivered,
  }) {
    return read?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(Sending value)? sending,
    TResult Function(Sent value)? sent,
    TResult Function(Delivered value)? delivered,
    TResult Function(Read value)? read,
    TResult Function(Failed value)? failed,
    TResult Function(PartiallyDelivered value)? partiallyDelivered,
    required TResult orElse(),
  }) {
    if (read != null) {
      return read(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$ReadImplToJson(
      this,
    );
  }
}

abstract class Read implements DeliveryStatus {
  const factory Read({required final String by, required final DateTime at}) =
      _$ReadImpl;

  factory Read.fromJson(Map<String, dynamic> json) = _$ReadImpl.fromJson;

  String get by;
  DateTime get at;
  @JsonKey(ignore: true)
  _$$ReadImplCopyWith<_$ReadImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$FailedImplCopyWith<$Res> {
  factory _$$FailedImplCopyWith(
          _$FailedImpl value, $Res Function(_$FailedImpl) then) =
      __$$FailedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String reason});
}

/// @nodoc
class __$$FailedImplCopyWithImpl<$Res>
    extends _$DeliveryStatusCopyWithImpl<$Res, _$FailedImpl>
    implements _$$FailedImplCopyWith<$Res> {
  __$$FailedImplCopyWithImpl(
      _$FailedImpl _value, $Res Function(_$FailedImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? reason = null,
  }) {
    return _then(_$FailedImpl(
      reason: null == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FailedImpl with DiagnosticableTreeMixin implements Failed {
  const _$FailedImpl({required this.reason, final String? $type})
      : $type = $type ?? 'failed';

  factory _$FailedImpl.fromJson(Map<String, dynamic> json) =>
      _$$FailedImplFromJson(json);

  @override
  final String reason;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'DeliveryStatus.failed(reason: $reason)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'DeliveryStatus.failed'))
      ..add(DiagnosticsProperty('reason', reason));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FailedImpl &&
            (identical(other.reason, reason) || other.reason == reason));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, reason);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$FailedImplCopyWith<_$FailedImpl> get copyWith =>
      __$$FailedImplCopyWithImpl<_$FailedImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() sending,
    required TResult Function() sent,
    required TResult Function(String to, DateTime at) delivered,
    required TResult Function(String by, DateTime at) read,
    required TResult Function(String reason) failed,
    required TResult Function(int reached, int total) partiallyDelivered,
  }) {
    return failed(reason);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? sending,
    TResult? Function()? sent,
    TResult? Function(String to, DateTime at)? delivered,
    TResult? Function(String by, DateTime at)? read,
    TResult? Function(String reason)? failed,
    TResult? Function(int reached, int total)? partiallyDelivered,
  }) {
    return failed?.call(reason);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? sending,
    TResult Function()? sent,
    TResult Function(String to, DateTime at)? delivered,
    TResult Function(String by, DateTime at)? read,
    TResult Function(String reason)? failed,
    TResult Function(int reached, int total)? partiallyDelivered,
    required TResult orElse(),
  }) {
    if (failed != null) {
      return failed(reason);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(Sending value) sending,
    required TResult Function(Sent value) sent,
    required TResult Function(Delivered value) delivered,
    required TResult Function(Read value) read,
    required TResult Function(Failed value) failed,
    required TResult Function(PartiallyDelivered value) partiallyDelivered,
  }) {
    return failed(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(Sending value)? sending,
    TResult? Function(Sent value)? sent,
    TResult? Function(Delivered value)? delivered,
    TResult? Function(Read value)? read,
    TResult? Function(Failed value)? failed,
    TResult? Function(PartiallyDelivered value)? partiallyDelivered,
  }) {
    return failed?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(Sending value)? sending,
    TResult Function(Sent value)? sent,
    TResult Function(Delivered value)? delivered,
    TResult Function(Read value)? read,
    TResult Function(Failed value)? failed,
    TResult Function(PartiallyDelivered value)? partiallyDelivered,
    required TResult orElse(),
  }) {
    if (failed != null) {
      return failed(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$FailedImplToJson(
      this,
    );
  }
}

abstract class Failed implements DeliveryStatus {
  const factory Failed({required final String reason}) = _$FailedImpl;

  factory Failed.fromJson(Map<String, dynamic> json) = _$FailedImpl.fromJson;

  String get reason;
  @JsonKey(ignore: true)
  _$$FailedImplCopyWith<_$FailedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$PartiallyDeliveredImplCopyWith<$Res> {
  factory _$$PartiallyDeliveredImplCopyWith(_$PartiallyDeliveredImpl value,
          $Res Function(_$PartiallyDeliveredImpl) then) =
      __$$PartiallyDeliveredImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int reached, int total});
}

/// @nodoc
class __$$PartiallyDeliveredImplCopyWithImpl<$Res>
    extends _$DeliveryStatusCopyWithImpl<$Res, _$PartiallyDeliveredImpl>
    implements _$$PartiallyDeliveredImplCopyWith<$Res> {
  __$$PartiallyDeliveredImplCopyWithImpl(_$PartiallyDeliveredImpl _value,
      $Res Function(_$PartiallyDeliveredImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? reached = null,
    Object? total = null,
  }) {
    return _then(_$PartiallyDeliveredImpl(
      reached: null == reached
          ? _value.reached
          : reached // ignore: cast_nullable_to_non_nullable
              as int,
      total: null == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PartiallyDeliveredImpl
    with DiagnosticableTreeMixin
    implements PartiallyDelivered {
  const _$PartiallyDeliveredImpl(
      {required this.reached, required this.total, final String? $type})
      : $type = $type ?? 'partiallyDelivered';

  factory _$PartiallyDeliveredImpl.fromJson(Map<String, dynamic> json) =>
      _$$PartiallyDeliveredImplFromJson(json);

  @override
  final int reached;
  @override
  final int total;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'DeliveryStatus.partiallyDelivered(reached: $reached, total: $total)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'DeliveryStatus.partiallyDelivered'))
      ..add(DiagnosticsProperty('reached', reached))
      ..add(DiagnosticsProperty('total', total));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PartiallyDeliveredImpl &&
            (identical(other.reached, reached) || other.reached == reached) &&
            (identical(other.total, total) || other.total == total));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, reached, total);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PartiallyDeliveredImplCopyWith<_$PartiallyDeliveredImpl> get copyWith =>
      __$$PartiallyDeliveredImplCopyWithImpl<_$PartiallyDeliveredImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() sending,
    required TResult Function() sent,
    required TResult Function(String to, DateTime at) delivered,
    required TResult Function(String by, DateTime at) read,
    required TResult Function(String reason) failed,
    required TResult Function(int reached, int total) partiallyDelivered,
  }) {
    return partiallyDelivered(reached, total);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? sending,
    TResult? Function()? sent,
    TResult? Function(String to, DateTime at)? delivered,
    TResult? Function(String by, DateTime at)? read,
    TResult? Function(String reason)? failed,
    TResult? Function(int reached, int total)? partiallyDelivered,
  }) {
    return partiallyDelivered?.call(reached, total);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? sending,
    TResult Function()? sent,
    TResult Function(String to, DateTime at)? delivered,
    TResult Function(String by, DateTime at)? read,
    TResult Function(String reason)? failed,
    TResult Function(int reached, int total)? partiallyDelivered,
    required TResult orElse(),
  }) {
    if (partiallyDelivered != null) {
      return partiallyDelivered(reached, total);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(Sending value) sending,
    required TResult Function(Sent value) sent,
    required TResult Function(Delivered value) delivered,
    required TResult Function(Read value) read,
    required TResult Function(Failed value) failed,
    required TResult Function(PartiallyDelivered value) partiallyDelivered,
  }) {
    return partiallyDelivered(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(Sending value)? sending,
    TResult? Function(Sent value)? sent,
    TResult? Function(Delivered value)? delivered,
    TResult? Function(Read value)? read,
    TResult? Function(Failed value)? failed,
    TResult? Function(PartiallyDelivered value)? partiallyDelivered,
  }) {
    return partiallyDelivered?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(Sending value)? sending,
    TResult Function(Sent value)? sent,
    TResult Function(Delivered value)? delivered,
    TResult Function(Read value)? read,
    TResult Function(Failed value)? failed,
    TResult Function(PartiallyDelivered value)? partiallyDelivered,
    required TResult orElse(),
  }) {
    if (partiallyDelivered != null) {
      return partiallyDelivered(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$PartiallyDeliveredImplToJson(
      this,
    );
  }
}

abstract class PartiallyDelivered implements DeliveryStatus {
  const factory PartiallyDelivered(
      {required final int reached,
      required final int total}) = _$PartiallyDeliveredImpl;

  factory PartiallyDelivered.fromJson(Map<String, dynamic> json) =
      _$PartiallyDeliveredImpl.fromJson;

  int get reached;
  int get total;
  @JsonKey(ignore: true)
  _$$PartiallyDeliveredImplCopyWith<_$PartiallyDeliveredImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

BitchatMessage _$BitchatMessageFromJson(Map<String, dynamic> json) {
  return _BitchatMessage.fromJson(json);
}

/// @nodoc
mixin _$BitchatMessage {
  String get id => throw _privateConstructorUsedError;
  String get sender => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  BitchatMessageType get type => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  bool get isRelay => throw _privateConstructorUsedError;
  String? get originalSender => throw _privateConstructorUsedError;
  bool get isPrivate => throw _privateConstructorUsedError;
  String? get recipientNickname => throw _privateConstructorUsedError;
  String? get senderPeerID => throw _privateConstructorUsedError;
  List<String>? get mentions => throw _privateConstructorUsedError;
  String? get channel => throw _privateConstructorUsedError;
  @Uint8ListBase64Converter()
  Uint8List? get encryptedContent => throw _privateConstructorUsedError;
  bool get isEncrypted => throw _privateConstructorUsedError;
  DeliveryStatus? get deliveryStatus => throw _privateConstructorUsedError;
  int? get powDifficulty => throw _privateConstructorUsedError;
  int? get rssi => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $BitchatMessageCopyWith<BitchatMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BitchatMessageCopyWith<$Res> {
  factory $BitchatMessageCopyWith(
          BitchatMessage value, $Res Function(BitchatMessage) then) =
      _$BitchatMessageCopyWithImpl<$Res, BitchatMessage>;
  @useResult
  $Res call(
      {String id,
      String sender,
      String content,
      BitchatMessageType type,
      DateTime timestamp,
      bool isRelay,
      String? originalSender,
      bool isPrivate,
      String? recipientNickname,
      String? senderPeerID,
      List<String>? mentions,
      String? channel,
      @Uint8ListBase64Converter() Uint8List? encryptedContent,
      bool isEncrypted,
      DeliveryStatus? deliveryStatus,
      int? powDifficulty,
      int? rssi});

  $DeliveryStatusCopyWith<$Res>? get deliveryStatus;
}

/// @nodoc
class _$BitchatMessageCopyWithImpl<$Res, $Val extends BitchatMessage>
    implements $BitchatMessageCopyWith<$Res> {
  _$BitchatMessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sender = null,
    Object? content = null,
    Object? type = null,
    Object? timestamp = null,
    Object? isRelay = null,
    Object? originalSender = freezed,
    Object? isPrivate = null,
    Object? recipientNickname = freezed,
    Object? senderPeerID = freezed,
    Object? mentions = freezed,
    Object? channel = freezed,
    Object? encryptedContent = freezed,
    Object? isEncrypted = null,
    Object? deliveryStatus = freezed,
    Object? powDifficulty = freezed,
    Object? rssi = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      sender: null == sender
          ? _value.sender
          : sender // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as BitchatMessageType,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isRelay: null == isRelay
          ? _value.isRelay
          : isRelay // ignore: cast_nullable_to_non_nullable
              as bool,
      originalSender: freezed == originalSender
          ? _value.originalSender
          : originalSender // ignore: cast_nullable_to_non_nullable
              as String?,
      isPrivate: null == isPrivate
          ? _value.isPrivate
          : isPrivate // ignore: cast_nullable_to_non_nullable
              as bool,
      recipientNickname: freezed == recipientNickname
          ? _value.recipientNickname
          : recipientNickname // ignore: cast_nullable_to_non_nullable
              as String?,
      senderPeerID: freezed == senderPeerID
          ? _value.senderPeerID
          : senderPeerID // ignore: cast_nullable_to_non_nullable
              as String?,
      mentions: freezed == mentions
          ? _value.mentions
          : mentions // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      channel: freezed == channel
          ? _value.channel
          : channel // ignore: cast_nullable_to_non_nullable
              as String?,
      encryptedContent: freezed == encryptedContent
          ? _value.encryptedContent
          : encryptedContent // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
      isEncrypted: null == isEncrypted
          ? _value.isEncrypted
          : isEncrypted // ignore: cast_nullable_to_non_nullable
              as bool,
      deliveryStatus: freezed == deliveryStatus
          ? _value.deliveryStatus
          : deliveryStatus // ignore: cast_nullable_to_non_nullable
              as DeliveryStatus?,
      powDifficulty: freezed == powDifficulty
          ? _value.powDifficulty
          : powDifficulty // ignore: cast_nullable_to_non_nullable
              as int?,
      rssi: freezed == rssi
          ? _value.rssi
          : rssi // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $DeliveryStatusCopyWith<$Res>? get deliveryStatus {
    if (_value.deliveryStatus == null) {
      return null;
    }

    return $DeliveryStatusCopyWith<$Res>(_value.deliveryStatus!, (value) {
      return _then(_value.copyWith(deliveryStatus: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$BitchatMessageImplCopyWith<$Res>
    implements $BitchatMessageCopyWith<$Res> {
  factory _$$BitchatMessageImplCopyWith(_$BitchatMessageImpl value,
          $Res Function(_$BitchatMessageImpl) then) =
      __$$BitchatMessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String sender,
      String content,
      BitchatMessageType type,
      DateTime timestamp,
      bool isRelay,
      String? originalSender,
      bool isPrivate,
      String? recipientNickname,
      String? senderPeerID,
      List<String>? mentions,
      String? channel,
      @Uint8ListBase64Converter() Uint8List? encryptedContent,
      bool isEncrypted,
      DeliveryStatus? deliveryStatus,
      int? powDifficulty,
      int? rssi});

  @override
  $DeliveryStatusCopyWith<$Res>? get deliveryStatus;
}

/// @nodoc
class __$$BitchatMessageImplCopyWithImpl<$Res>
    extends _$BitchatMessageCopyWithImpl<$Res, _$BitchatMessageImpl>
    implements _$$BitchatMessageImplCopyWith<$Res> {
  __$$BitchatMessageImplCopyWithImpl(
      _$BitchatMessageImpl _value, $Res Function(_$BitchatMessageImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sender = null,
    Object? content = null,
    Object? type = null,
    Object? timestamp = null,
    Object? isRelay = null,
    Object? originalSender = freezed,
    Object? isPrivate = null,
    Object? recipientNickname = freezed,
    Object? senderPeerID = freezed,
    Object? mentions = freezed,
    Object? channel = freezed,
    Object? encryptedContent = freezed,
    Object? isEncrypted = null,
    Object? deliveryStatus = freezed,
    Object? powDifficulty = freezed,
    Object? rssi = freezed,
  }) {
    return _then(_$BitchatMessageImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      sender: null == sender
          ? _value.sender
          : sender // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as BitchatMessageType,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isRelay: null == isRelay
          ? _value.isRelay
          : isRelay // ignore: cast_nullable_to_non_nullable
              as bool,
      originalSender: freezed == originalSender
          ? _value.originalSender
          : originalSender // ignore: cast_nullable_to_non_nullable
              as String?,
      isPrivate: null == isPrivate
          ? _value.isPrivate
          : isPrivate // ignore: cast_nullable_to_non_nullable
              as bool,
      recipientNickname: freezed == recipientNickname
          ? _value.recipientNickname
          : recipientNickname // ignore: cast_nullable_to_non_nullable
              as String?,
      senderPeerID: freezed == senderPeerID
          ? _value.senderPeerID
          : senderPeerID // ignore: cast_nullable_to_non_nullable
              as String?,
      mentions: freezed == mentions
          ? _value._mentions
          : mentions // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      channel: freezed == channel
          ? _value.channel
          : channel // ignore: cast_nullable_to_non_nullable
              as String?,
      encryptedContent: freezed == encryptedContent
          ? _value.encryptedContent
          : encryptedContent // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
      isEncrypted: null == isEncrypted
          ? _value.isEncrypted
          : isEncrypted // ignore: cast_nullable_to_non_nullable
              as bool,
      deliveryStatus: freezed == deliveryStatus
          ? _value.deliveryStatus
          : deliveryStatus // ignore: cast_nullable_to_non_nullable
              as DeliveryStatus?,
      powDifficulty: freezed == powDifficulty
          ? _value.powDifficulty
          : powDifficulty // ignore: cast_nullable_to_non_nullable
              as int?,
      rssi: freezed == rssi
          ? _value.rssi
          : rssi // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BitchatMessageImpl
    with DiagnosticableTreeMixin
    implements _BitchatMessage {
  const _$BitchatMessageImpl(
      {this.id = '',
      required this.sender,
      this.content = '',
      this.type = BitchatMessageType.Message,
      required this.timestamp,
      this.isRelay = false,
      this.originalSender,
      this.isPrivate = false,
      this.recipientNickname,
      this.senderPeerID,
      final List<String>? mentions,
      this.channel,
      @Uint8ListBase64Converter() this.encryptedContent,
      this.isEncrypted = false,
      this.deliveryStatus,
      this.powDifficulty,
      this.rssi})
      : _mentions = mentions;

  factory _$BitchatMessageImpl.fromJson(Map<String, dynamic> json) =>
      _$$BitchatMessageImplFromJson(json);

  @override
  @JsonKey()
  final String id;
  @override
  final String sender;
  @override
  @JsonKey()
  final String content;
  @override
  @JsonKey()
  final BitchatMessageType type;
  @override
  final DateTime timestamp;
  @override
  @JsonKey()
  final bool isRelay;
  @override
  final String? originalSender;
  @override
  @JsonKey()
  final bool isPrivate;
  @override
  final String? recipientNickname;
  @override
  final String? senderPeerID;
  final List<String>? _mentions;
  @override
  List<String>? get mentions {
    final value = _mentions;
    if (value == null) return null;
    if (_mentions is EqualUnmodifiableListView) return _mentions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final String? channel;
  @override
  @Uint8ListBase64Converter()
  final Uint8List? encryptedContent;
  @override
  @JsonKey()
  final bool isEncrypted;
  @override
  final DeliveryStatus? deliveryStatus;
  @override
  final int? powDifficulty;
  @override
  final int? rssi;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'BitchatMessage(id: $id, sender: $sender, content: $content, type: $type, timestamp: $timestamp, isRelay: $isRelay, originalSender: $originalSender, isPrivate: $isPrivate, recipientNickname: $recipientNickname, senderPeerID: $senderPeerID, mentions: $mentions, channel: $channel, encryptedContent: $encryptedContent, isEncrypted: $isEncrypted, deliveryStatus: $deliveryStatus, powDifficulty: $powDifficulty, rssi: $rssi)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'BitchatMessage'))
      ..add(DiagnosticsProperty('id', id))
      ..add(DiagnosticsProperty('sender', sender))
      ..add(DiagnosticsProperty('content', content))
      ..add(DiagnosticsProperty('type', type))
      ..add(DiagnosticsProperty('timestamp', timestamp))
      ..add(DiagnosticsProperty('isRelay', isRelay))
      ..add(DiagnosticsProperty('originalSender', originalSender))
      ..add(DiagnosticsProperty('isPrivate', isPrivate))
      ..add(DiagnosticsProperty('recipientNickname', recipientNickname))
      ..add(DiagnosticsProperty('senderPeerID', senderPeerID))
      ..add(DiagnosticsProperty('mentions', mentions))
      ..add(DiagnosticsProperty('channel', channel))
      ..add(DiagnosticsProperty('encryptedContent', encryptedContent))
      ..add(DiagnosticsProperty('isEncrypted', isEncrypted))
      ..add(DiagnosticsProperty('deliveryStatus', deliveryStatus))
      ..add(DiagnosticsProperty('powDifficulty', powDifficulty))
      ..add(DiagnosticsProperty('rssi', rssi));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BitchatMessageImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.sender, sender) || other.sender == sender) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.isRelay, isRelay) || other.isRelay == isRelay) &&
            (identical(other.originalSender, originalSender) ||
                other.originalSender == originalSender) &&
            (identical(other.isPrivate, isPrivate) ||
                other.isPrivate == isPrivate) &&
            (identical(other.recipientNickname, recipientNickname) ||
                other.recipientNickname == recipientNickname) &&
            (identical(other.senderPeerID, senderPeerID) ||
                other.senderPeerID == senderPeerID) &&
            const DeepCollectionEquality().equals(other._mentions, _mentions) &&
            (identical(other.channel, channel) || other.channel == channel) &&
            const DeepCollectionEquality()
                .equals(other.encryptedContent, encryptedContent) &&
            (identical(other.isEncrypted, isEncrypted) ||
                other.isEncrypted == isEncrypted) &&
            (identical(other.deliveryStatus, deliveryStatus) ||
                other.deliveryStatus == deliveryStatus) &&
            (identical(other.powDifficulty, powDifficulty) ||
                other.powDifficulty == powDifficulty) &&
            (identical(other.rssi, rssi) || other.rssi == rssi));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      sender,
      content,
      type,
      timestamp,
      isRelay,
      originalSender,
      isPrivate,
      recipientNickname,
      senderPeerID,
      const DeepCollectionEquality().hash(_mentions),
      channel,
      const DeepCollectionEquality().hash(encryptedContent),
      isEncrypted,
      deliveryStatus,
      powDifficulty,
      rssi);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$BitchatMessageImplCopyWith<_$BitchatMessageImpl> get copyWith =>
      __$$BitchatMessageImplCopyWithImpl<_$BitchatMessageImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BitchatMessageImplToJson(
      this,
    );
  }
}

abstract class _BitchatMessage implements BitchatMessage {
  const factory _BitchatMessage(
      {final String id,
      required final String sender,
      final String content,
      final BitchatMessageType type,
      required final DateTime timestamp,
      final bool isRelay,
      final String? originalSender,
      final bool isPrivate,
      final String? recipientNickname,
      final String? senderPeerID,
      final List<String>? mentions,
      final String? channel,
      @Uint8ListBase64Converter() final Uint8List? encryptedContent,
      final bool isEncrypted,
      final DeliveryStatus? deliveryStatus,
      final int? powDifficulty,
      final int? rssi}) = _$BitchatMessageImpl;

  factory _BitchatMessage.fromJson(Map<String, dynamic> json) =
      _$BitchatMessageImpl.fromJson;

  @override
  String get id;
  @override
  String get sender;
  @override
  String get content;
  @override
  BitchatMessageType get type;
  @override
  DateTime get timestamp;
  @override
  bool get isRelay;
  @override
  String? get originalSender;
  @override
  bool get isPrivate;
  @override
  String? get recipientNickname;
  @override
  String? get senderPeerID;
  @override
  List<String>? get mentions;
  @override
  String? get channel;
  @override
  @Uint8ListBase64Converter()
  Uint8List? get encryptedContent;
  @override
  bool get isEncrypted;
  @override
  DeliveryStatus? get deliveryStatus;
  @override
  int? get powDifficulty;
  @override
  int? get rssi;
  @override
  @JsonKey(ignore: true)
  _$$BitchatMessageImplCopyWith<_$BitchatMessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
