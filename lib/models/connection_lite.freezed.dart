// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'connection_lite.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ConnectionLite _$ConnectionLiteFromJson(Map<String, dynamic> json) {
  return _ConnectionLite.fromJson(json);
}

/// @nodoc
mixin _$ConnectionLite {
  String get userId => throw _privateConstructorUsedError;
  String get handle => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  String get avatarUrl => throw _privateConstructorUsedError;
  bool get isOnline => throw _privateConstructorUsedError;
  int? get lastInteractedAt =>
      throw _privateConstructorUsedError; // timestamp for ranking
  bool get canDM =>
      throw _privateConstructorUsedError; // gate by privacy settings
  double get rankingScore => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ConnectionLiteCopyWith<ConnectionLite> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ConnectionLiteCopyWith<$Res> {
  factory $ConnectionLiteCopyWith(
          ConnectionLite value, $Res Function(ConnectionLite) then) =
      _$ConnectionLiteCopyWithImpl<$Res, ConnectionLite>;
  @useResult
  $Res call(
      {String userId,
      String handle,
      String displayName,
      String avatarUrl,
      bool isOnline,
      int? lastInteractedAt,
      bool canDM,
      double rankingScore});
}

/// @nodoc
class _$ConnectionLiteCopyWithImpl<$Res, $Val extends ConnectionLite>
    implements $ConnectionLiteCopyWith<$Res> {
  _$ConnectionLiteCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? handle = null,
    Object? displayName = null,
    Object? avatarUrl = null,
    Object? isOnline = null,
    Object? lastInteractedAt = freezed,
    Object? canDM = null,
    Object? rankingScore = null,
  }) {
    return _then(_value.copyWith(
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      handle: null == handle
          ? _value.handle
          : handle // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      avatarUrl: null == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String,
      isOnline: null == isOnline
          ? _value.isOnline
          : isOnline // ignore: cast_nullable_to_non_nullable
              as bool,
      lastInteractedAt: freezed == lastInteractedAt
          ? _value.lastInteractedAt
          : lastInteractedAt // ignore: cast_nullable_to_non_nullable
              as int?,
      canDM: null == canDM
          ? _value.canDM
          : canDM // ignore: cast_nullable_to_non_nullable
              as bool,
      rankingScore: null == rankingScore
          ? _value.rankingScore
          : rankingScore // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ConnectionLiteImplCopyWith<$Res>
    implements $ConnectionLiteCopyWith<$Res> {
  factory _$$ConnectionLiteImplCopyWith(_$ConnectionLiteImpl value,
          $Res Function(_$ConnectionLiteImpl) then) =
      __$$ConnectionLiteImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String userId,
      String handle,
      String displayName,
      String avatarUrl,
      bool isOnline,
      int? lastInteractedAt,
      bool canDM,
      double rankingScore});
}

/// @nodoc
class __$$ConnectionLiteImplCopyWithImpl<$Res>
    extends _$ConnectionLiteCopyWithImpl<$Res, _$ConnectionLiteImpl>
    implements _$$ConnectionLiteImplCopyWith<$Res> {
  __$$ConnectionLiteImplCopyWithImpl(
      _$ConnectionLiteImpl _value, $Res Function(_$ConnectionLiteImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? handle = null,
    Object? displayName = null,
    Object? avatarUrl = null,
    Object? isOnline = null,
    Object? lastInteractedAt = freezed,
    Object? canDM = null,
    Object? rankingScore = null,
  }) {
    return _then(_$ConnectionLiteImpl(
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      handle: null == handle
          ? _value.handle
          : handle // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      avatarUrl: null == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String,
      isOnline: null == isOnline
          ? _value.isOnline
          : isOnline // ignore: cast_nullable_to_non_nullable
              as bool,
      lastInteractedAt: freezed == lastInteractedAt
          ? _value.lastInteractedAt
          : lastInteractedAt // ignore: cast_nullable_to_non_nullable
              as int?,
      canDM: null == canDM
          ? _value.canDM
          : canDM // ignore: cast_nullable_to_non_nullable
              as bool,
      rankingScore: null == rankingScore
          ? _value.rankingScore
          : rankingScore // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ConnectionLiteImpl implements _ConnectionLite {
  const _$ConnectionLiteImpl(
      {required this.userId,
      required this.handle,
      required this.displayName,
      required this.avatarUrl,
      this.isOnline = false,
      this.lastInteractedAt,
      this.canDM = true,
      this.rankingScore = 0.0});

  factory _$ConnectionLiteImpl.fromJson(Map<String, dynamic> json) =>
      _$$ConnectionLiteImplFromJson(json);

  @override
  final String userId;
  @override
  final String handle;
  @override
  final String displayName;
  @override
  final String avatarUrl;
  @override
  @JsonKey()
  final bool isOnline;
  @override
  final int? lastInteractedAt;
// timestamp for ranking
  @override
  @JsonKey()
  final bool canDM;
// gate by privacy settings
  @override
  @JsonKey()
  final double rankingScore;

  @override
  String toString() {
    return 'ConnectionLite(userId: $userId, handle: $handle, displayName: $displayName, avatarUrl: $avatarUrl, isOnline: $isOnline, lastInteractedAt: $lastInteractedAt, canDM: $canDM, rankingScore: $rankingScore)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConnectionLiteImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.handle, handle) || other.handle == handle) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.isOnline, isOnline) ||
                other.isOnline == isOnline) &&
            (identical(other.lastInteractedAt, lastInteractedAt) ||
                other.lastInteractedAt == lastInteractedAt) &&
            (identical(other.canDM, canDM) || other.canDM == canDM) &&
            (identical(other.rankingScore, rankingScore) ||
                other.rankingScore == rankingScore));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, userId, handle, displayName,
      avatarUrl, isOnline, lastInteractedAt, canDM, rankingScore);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ConnectionLiteImplCopyWith<_$ConnectionLiteImpl> get copyWith =>
      __$$ConnectionLiteImplCopyWithImpl<_$ConnectionLiteImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ConnectionLiteImplToJson(
      this,
    );
  }
}

abstract class _ConnectionLite implements ConnectionLite {
  const factory _ConnectionLite(
      {required final String userId,
      required final String handle,
      required final String displayName,
      required final String avatarUrl,
      final bool isOnline,
      final int? lastInteractedAt,
      final bool canDM,
      final double rankingScore}) = _$ConnectionLiteImpl;

  factory _ConnectionLite.fromJson(Map<String, dynamic> json) =
      _$ConnectionLiteImpl.fromJson;

  @override
  String get userId;
  @override
  String get handle;
  @override
  String get displayName;
  @override
  String get avatarUrl;
  @override
  bool get isOnline;
  @override
  int? get lastInteractedAt;
  @override // timestamp for ranking
  bool get canDM;
  @override // gate by privacy settings
  double get rankingScore;
  @override
  @JsonKey(ignore: true)
  _$$ConnectionLiteImplCopyWith<_$ConnectionLiteImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
