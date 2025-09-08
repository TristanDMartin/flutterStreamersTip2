// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'home_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$HomeNotifier {
  List<HomeVideo> get videos => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  String get error => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $HomeNotifierCopyWith<HomeNotifier> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HomeNotifierCopyWith<$Res> {
  factory $HomeNotifierCopyWith(
          HomeNotifier value, $Res Function(HomeNotifier) then) =
      _$HomeNotifierCopyWithImpl<$Res, HomeNotifier>;
  @useResult
  $Res call({List<HomeVideo> videos, bool isLoading, String error});
}

/// @nodoc
class _$HomeNotifierCopyWithImpl<$Res, $Val extends HomeNotifier>
    implements $HomeNotifierCopyWith<$Res> {
  _$HomeNotifierCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? videos = null,
    Object? isLoading = null,
    Object? error = null,
  }) {
    return _then(_value.copyWith(
      videos: null == videos
          ? _value.videos
          : videos // ignore: cast_nullable_to_non_nullable
              as List<HomeVideo>,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      error: null == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$HomeNotifierImplCopyWith<$Res>
    implements $HomeNotifierCopyWith<$Res> {
  factory _$$HomeNotifierImplCopyWith(
          _$HomeNotifierImpl value, $Res Function(_$HomeNotifierImpl) then) =
      __$$HomeNotifierImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<HomeVideo> videos, bool isLoading, String error});
}

/// @nodoc
class __$$HomeNotifierImplCopyWithImpl<$Res>
    extends _$HomeNotifierCopyWithImpl<$Res, _$HomeNotifierImpl>
    implements _$$HomeNotifierImplCopyWith<$Res> {
  __$$HomeNotifierImplCopyWithImpl(
      _$HomeNotifierImpl _value, $Res Function(_$HomeNotifierImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? videos = null,
    Object? isLoading = null,
    Object? error = null,
  }) {
    return _then(_$HomeNotifierImpl(
      videos: null == videos
          ? _value._videos
          : videos // ignore: cast_nullable_to_non_nullable
              as List<HomeVideo>,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      error: null == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$HomeNotifierImpl implements _HomeNotifier {
  const _$HomeNotifierImpl(
      {final List<HomeVideo> videos = const [],
      this.isLoading = false,
      this.error = ''})
      : _videos = videos;

  final List<HomeVideo> _videos;
  @override
  @JsonKey()
  List<HomeVideo> get videos {
    if (_videos is EqualUnmodifiableListView) return _videos;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_videos);
  }

  @override
  @JsonKey()
  final bool isLoading;
  @override
  @JsonKey()
  final String error;

  @override
  String toString() {
    return 'HomeNotifier(videos: $videos, isLoading: $isLoading, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HomeNotifierImpl &&
            const DeepCollectionEquality().equals(other._videos, _videos) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(runtimeType,
      const DeepCollectionEquality().hash(_videos), isLoading, error);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$HomeNotifierImplCopyWith<_$HomeNotifierImpl> get copyWith =>
      __$$HomeNotifierImplCopyWithImpl<_$HomeNotifierImpl>(this, _$identity);
}

abstract class _HomeNotifier implements HomeNotifier {
  const factory _HomeNotifier(
      {final List<HomeVideo> videos,
      final bool isLoading,
      final String error}) = _$HomeNotifierImpl;

  @override
  List<HomeVideo> get videos;
  @override
  bool get isLoading;
  @override
  String get error;
  @override
  @JsonKey(ignore: true)
  _$$HomeNotifierImplCopyWith<_$HomeNotifierImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
