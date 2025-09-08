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
  String? get avatarURL => throw _privateConstructorUsedError;
  int get followers => throw _privateConstructorUsedError;
  bool get isOnline => throw _privateConstructorUsedError;

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
      String? avatarURL,
      int followers,
      bool isOnline});
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
    Object? avatarURL = freezed,
    Object? followers = null,
    Object? isOnline = null,
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
      avatarURL: freezed == avatarURL
          ? _value.avatarURL
          : avatarURL // ignore: cast_nullable_to_non_nullable
              as String?,
      followers: null == followers
          ? _value.followers
          : followers // ignore: cast_nullable_to_non_nullable
              as int,
      isOnline: null == isOnline
          ? _value.isOnline
          : isOnline // ignore: cast_nullable_to_non_nullable
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
      String? avatarURL,
      int followers,
      bool isOnline});
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
    Object? avatarURL = freezed,
    Object? followers = null,
    Object? isOnline = null,
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
      avatarURL: freezed == avatarURL
          ? _value.avatarURL
          : avatarURL // ignore: cast_nullable_to_non_nullable
              as String?,
      followers: null == followers
          ? _value.followers
          : followers // ignore: cast_nullable_to_non_nullable
              as int,
      isOnline: null == isOnline
          ? _value.isOnline
          : isOnline // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$TrendingCreatorImpl implements _TrendingCreator {
  const _$TrendingCreatorImpl(
      {required this.id,
      required this.username,
      this.avatarURL,
      this.followers = 0,
      this.isOnline = false});

  @override
  final String id;
  @override
  final String username;
  @override
  final String? avatarURL;
  @override
  @JsonKey()
  final int followers;
  @override
  @JsonKey()
  final bool isOnline;

  @override
  String toString() {
    return 'TrendingCreator(id: $id, username: $username, avatarURL: $avatarURL, followers: $followers, isOnline: $isOnline)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TrendingCreatorImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.avatarURL, avatarURL) ||
                other.avatarURL == avatarURL) &&
            (identical(other.followers, followers) ||
                other.followers == followers) &&
            (identical(other.isOnline, isOnline) ||
                other.isOnline == isOnline));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, id, username, avatarURL, followers, isOnline);

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
      final String? avatarURL,
      final int followers,
      final bool isOnline}) = _$TrendingCreatorImpl;

  @override
  String get id;
  @override
  String get username;
  @override
  String? get avatarURL;
  @override
  int get followers;
  @override
  bool get isOnline;
  @override
  @JsonKey(ignore: true)
  _$$TrendingCreatorImplCopyWith<_$TrendingCreatorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
