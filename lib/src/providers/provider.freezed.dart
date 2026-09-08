// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SecureSession _$SecureSessionFromJson(Map<String, dynamic> json) {
  return _SecureSession.fromJson(json);
}

/// @nodoc
mixin _$SecureSession {
  String get appId => throw _privateConstructorUsedError;
  String get channelId => throw _privateConstructorUsedError;
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $SecureSessionCopyWith<SecureSession> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SecureSessionCopyWith<$Res> {
  factory $SecureSessionCopyWith(
          SecureSession value, $Res Function(SecureSession) then) =
      _$SecureSessionCopyWithImpl<$Res, SecureSession>;
  @useResult
  $Res call({String appId, String channelId, String id, String userId});
}

/// @nodoc
class _$SecureSessionCopyWithImpl<$Res, $Val extends SecureSession>
    implements $SecureSessionCopyWith<$Res> {
  _$SecureSessionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? appId = null,
    Object? channelId = null,
    Object? id = null,
    Object? userId = null,
  }) {
    return _then(_value.copyWith(
      appId: null == appId
          ? _value.appId
          : appId // ignore: cast_nullable_to_non_nullable
              as String,
      channelId: null == channelId
          ? _value.channelId
          : channelId // ignore: cast_nullable_to_non_nullable
              as String,
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SecureSessionImplCopyWith<$Res>
    implements $SecureSessionCopyWith<$Res> {
  factory _$$SecureSessionImplCopyWith(
          _$SecureSessionImpl value, $Res Function(_$SecureSessionImpl) then) =
      __$$SecureSessionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String appId, String channelId, String id, String userId});
}

/// @nodoc
class __$$SecureSessionImplCopyWithImpl<$Res>
    extends _$SecureSessionCopyWithImpl<$Res, _$SecureSessionImpl>
    implements _$$SecureSessionImplCopyWith<$Res> {
  __$$SecureSessionImplCopyWithImpl(
      _$SecureSessionImpl _value, $Res Function(_$SecureSessionImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? appId = null,
    Object? channelId = null,
    Object? id = null,
    Object? userId = null,
  }) {
    return _then(_$SecureSessionImpl(
      appId: null == appId
          ? _value.appId
          : appId // ignore: cast_nullable_to_non_nullable
              as String,
      channelId: null == channelId
          ? _value.channelId
          : channelId // ignore: cast_nullable_to_non_nullable
              as String,
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SecureSessionImpl implements _SecureSession {
  const _$SecureSessionImpl(
      {required this.appId,
      required this.channelId,
      required this.id,
      required this.userId});

  factory _$SecureSessionImpl.fromJson(Map<String, dynamic> json) =>
      _$$SecureSessionImplFromJson(json);

  @override
  final String appId;
  @override
  final String channelId;
  @override
  final String id;
  @override
  final String userId;

  @override
  String toString() {
    return 'SecureSession(appId: $appId, channelId: $channelId, id: $id, userId: $userId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SecureSessionImpl &&
            (identical(other.appId, appId) || other.appId == appId) &&
            (identical(other.channelId, channelId) ||
                other.channelId == channelId) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, appId, channelId, id, userId);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SecureSessionImplCopyWith<_$SecureSessionImpl> get copyWith =>
      __$$SecureSessionImplCopyWithImpl<_$SecureSessionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SecureSessionImplToJson(
      this,
    );
  }
}

abstract class _SecureSession implements SecureSession {
  const factory _SecureSession(
      {required final String appId,
      required final String channelId,
      required final String id,
      required final String userId}) = _$SecureSessionImpl;

  factory _SecureSession.fromJson(Map<String, dynamic> json) =
      _$SecureSessionImpl.fromJson;

  @override
  String get appId;
  @override
  String get channelId;
  @override
  String get id;
  @override
  String get userId;
  @override
  @JsonKey(ignore: true)
  _$$SecureSessionImplCopyWith<_$SecureSessionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
