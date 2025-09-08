// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'social_link.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$SocialLink {
  String get id => throw _privateConstructorUsedError;
  SocialLinkType get type => throw _privateConstructorUsedError;
  String get url => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $SocialLinkCopyWith<SocialLink> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SocialLinkCopyWith<$Res> {
  factory $SocialLinkCopyWith(
          SocialLink value, $Res Function(SocialLink) then) =
      _$SocialLinkCopyWithImpl<$Res, SocialLink>;
  @useResult
  $Res call({String id, SocialLinkType type, String url});
}

/// @nodoc
class _$SocialLinkCopyWithImpl<$Res, $Val extends SocialLink>
    implements $SocialLinkCopyWith<$Res> {
  _$SocialLinkCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? url = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as SocialLinkType,
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SocialLinkImplCopyWith<$Res>
    implements $SocialLinkCopyWith<$Res> {
  factory _$$SocialLinkImplCopyWith(
          _$SocialLinkImpl value, $Res Function(_$SocialLinkImpl) then) =
      __$$SocialLinkImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, SocialLinkType type, String url});
}

/// @nodoc
class __$$SocialLinkImplCopyWithImpl<$Res>
    extends _$SocialLinkCopyWithImpl<$Res, _$SocialLinkImpl>
    implements _$$SocialLinkImplCopyWith<$Res> {
  __$$SocialLinkImplCopyWithImpl(
      _$SocialLinkImpl _value, $Res Function(_$SocialLinkImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? url = null,
  }) {
    return _then(_$SocialLinkImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as SocialLinkType,
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$SocialLinkImpl implements _SocialLink {
  const _$SocialLinkImpl(
      {required this.id, required this.type, required this.url});

  @override
  final String id;
  @override
  final SocialLinkType type;
  @override
  final String url;

  @override
  String toString() {
    return 'SocialLink(id: $id, type: $type, url: $url)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SocialLinkImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.url, url) || other.url == url));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, type, url);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SocialLinkImplCopyWith<_$SocialLinkImpl> get copyWith =>
      __$$SocialLinkImplCopyWithImpl<_$SocialLinkImpl>(this, _$identity);
}

abstract class _SocialLink implements SocialLink {
  const factory _SocialLink(
      {required final String id,
      required final SocialLinkType type,
      required final String url}) = _$SocialLinkImpl;

  @override
  String get id;
  @override
  SocialLinkType get type;
  @override
  String get url;
  @override
  @JsonKey(ignore: true)
  _$$SocialLinkImplCopyWith<_$SocialLinkImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
