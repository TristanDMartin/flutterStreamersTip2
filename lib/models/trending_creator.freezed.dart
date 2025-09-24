// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'trending_creator.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$TrendingCreator {
  String get id => throw _privateConstructorUsedError;
  String get username => throw _privateConstructorUsedError;
  String? get displayName => throw _privateConstructorUsedError;
  String? get avatarURL => throw _privateConstructorUsedError;
  int get followerCount => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $TrendingCreatorCopyWith<TrendingCreator> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TrendingCreatorCopyWith<$Res> {
  factory $TrendingCreatorCopyWith(
          TrendingCreator value, $Res Function(TrendingCreator) then) =
      _$TrendingCreatorCopyWithImpl<$Res, TrendingCreator>;
  @useResult
  $Res call(
      {String id,
      String username,
      String? displayName,
      String? avatarURL,
      int followerCount,
      bool isActive});
}

/// @nodoc
class _$TrendingCreatorCopyWithImpl<$Res, $Val extends TrendingCreator>
    implements $TrendingCreatorCopyWith<$Res> {
  _$TrendingCreatorCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? username = null,
    Object? displayName = freezed,
    Object? avatarURL = freezed,
    Object? followerCount = null,
    Object? isActive = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: freezed == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String?,
      avatarURL: freezed == avatarURL
          ? _value.avatarURL
          : avatarURL // ignore: cast_nullable_to_non_nullable
              as String?,
      followerCount: null == followerCount
          ? _value.followerCount
          : followerCount // ignore: cast_nullable_to_non_nullable
              as int,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TrendingCreatorImplCopyWith<$Res>
    implements $TrendingCreatorCopyWith<$Res> {
  factory _$$TrendingCreatorImplCopyWith(_$TrendingCreatorImpl value,
          $Res Function(_$TrendingCreatorImpl) then) =
      __$$TrendingCreatorImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String username,
      String? displayName,
      String? avatarURL,
      int followerCount,
      bool isActive});
}

/// @nodoc
class __$$TrendingCreatorImplCopyWithImpl<$Res>
    extends _$TrendingCreatorCopyWithImpl<$Res, _$TrendingCreatorImpl>
    implements _$$TrendingCreatorImplCopyWith<$Res> {
  __$$TrendingCreatorImplCopyWithImpl(
      _$TrendingCreatorImpl _value, $Res Function(_$TrendingCreatorImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? username = null,
    Object? displayName = freezed,
    Object? avatarURL = freezed,
    Object? followerCount = null,
    Object? isActive = null,
  }) {
    return _then(_$TrendingCreatorImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: freezed == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String?,
      avatarURL: freezed == avatarURL
          ? _value.avatarURL
          : avatarURL // ignore: cast_nullable_to_non_nullable
              as String?,
      followerCount: null == followerCount
          ? _value.followerCount
          : followerCount // ignore: cast_nullable_to_non_nullable
              as int,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$TrendingCreatorImpl implements _TrendingCreator {
  const _$TrendingCreatorImpl(
      {required this.id,
      required this.username,
      this.displayName,
      this.avatarURL,
      this.followerCount = 0,
      this.isActive = false});

  @override
  final String id;
  @override
  final String username;
  @override
  final String? displayName;
  @override
  final String? avatarURL;
  @override
  @JsonKey()
  final int followerCount;
  @override
  @JsonKey()
  final bool isActive;

  @override
  String toString() {
    return 'TrendingCreator(id: $id, username: $username, displayName: $displayName, avatarURL: $avatarURL, followerCount: $followerCount, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TrendingCreatorImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.avatarURL, avatarURL) ||
                other.avatarURL == avatarURL) &&
            (identical(other.followerCount, followerCount) ||
                other.followerCount == followerCount) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, username, displayName,
      avatarURL, followerCount, isActive);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$TrendingCreatorImplCopyWith<_$TrendingCreatorImpl> get copyWith =>
      __$$TrendingCreatorImplCopyWithImpl<_$TrendingCreatorImpl>(
          this, _$identity);
}

abstract class _TrendingCreator implements TrendingCreator {
  const factory _TrendingCreator(
      {required final String id,
      required final String username,
      final String? displayName,
      final String? avatarURL,
      final int followerCount,
      final bool isActive}) = _$TrendingCreatorImpl;

  @override
  String get id;
  @override
  String get username;
  @override
  String? get displayName;
  @override
  String? get avatarURL;
  @override
  int get followerCount;
  @override
  bool get isActive;
  @override
  @JsonKey(ignore: true)
  _$$TrendingCreatorImplCopyWith<_$TrendingCreatorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
