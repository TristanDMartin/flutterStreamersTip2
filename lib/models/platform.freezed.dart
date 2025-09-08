// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'platform.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Platform _$PlatformFromJson(Map<String, dynamic> json) {
  return _Platform.fromJson(json);
}

/// @nodoc
mixin _$Platform {
  String get id => throw _privateConstructorUsedError;
  PlatformType get type => throw _privateConstructorUsedError;
  String get username => throw _privateConstructorUsedError;
  int get followers => throw _privateConstructorUsedError;
  String? get url => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $PlatformCopyWith<Platform> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlatformCopyWith<$Res> {
  factory $PlatformCopyWith(Platform value, $Res Function(Platform) then) =
      _$PlatformCopyWithImpl<$Res, Platform>;
  @useResult
  $Res call(
      {String id,
      PlatformType type,
      String username,
      int followers,
      String? url});
}

/// @nodoc
class _$PlatformCopyWithImpl<$Res, $Val extends Platform>
    implements $PlatformCopyWith<$Res> {
  _$PlatformCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? username = null,
    Object? followers = null,
    Object? url = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as PlatformType,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      followers: null == followers
          ? _value.followers
          : followers // ignore: cast_nullable_to_non_nullable
              as int,
      url: freezed == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PlatformImplCopyWith<$Res>
    implements $PlatformCopyWith<$Res> {
  factory _$$PlatformImplCopyWith(
          _$PlatformImpl value, $Res Function(_$PlatformImpl) then) =
      __$$PlatformImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      PlatformType type,
      String username,
      int followers,
      String? url});
}

/// @nodoc
class __$$PlatformImplCopyWithImpl<$Res>
    extends _$PlatformCopyWithImpl<$Res, _$PlatformImpl>
    implements _$$PlatformImplCopyWith<$Res> {
  __$$PlatformImplCopyWithImpl(
      _$PlatformImpl _value, $Res Function(_$PlatformImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? username = null,
    Object? followers = null,
    Object? url = freezed,
  }) {
    return _then(_$PlatformImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as PlatformType,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      followers: null == followers
          ? _value.followers
          : followers // ignore: cast_nullable_to_non_nullable
              as int,
      url: freezed == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PlatformImpl implements _Platform {
  const _$PlatformImpl(
      {required this.id,
      required this.type,
      required this.username,
      this.followers = 0,
      this.url});

  factory _$PlatformImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlatformImplFromJson(json);

  @override
  final String id;
  @override
  final PlatformType type;
  @override
  final String username;
  @override
  @JsonKey()
  final int followers;
  @override
  final String? url;

  @override
  String toString() {
    return 'Platform(id: $id, type: $type, username: $username, followers: $followers, url: $url)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlatformImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.followers, followers) ||
                other.followers == followers) &&
            (identical(other.url, url) || other.url == url));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, type, username, followers, url);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PlatformImplCopyWith<_$PlatformImpl> get copyWith =>
      __$$PlatformImplCopyWithImpl<_$PlatformImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PlatformImplToJson(
      this,
    );
  }
}

abstract class _Platform implements Platform {
  const factory _Platform(
      {required final String id,
      required final PlatformType type,
      required final String username,
      final int followers,
      final String? url}) = _$PlatformImpl;

  factory _Platform.fromJson(Map<String, dynamic> json) =
      _$PlatformImpl.fromJson;

  @override
  String get id;
  @override
  PlatformType get type;
  @override
  String get username;
  @override
  int get followers;
  @override
  String? get url;
  @override
  @JsonKey(ignore: true)
  _$$PlatformImplCopyWith<_$PlatformImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
