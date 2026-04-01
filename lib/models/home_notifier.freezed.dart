// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'home_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HomeNotifier {
  List<HomeVideo> get videos;
  bool get isLoading;
  String get error;

  /// Create a copy of HomeNotifier
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HomeNotifierCopyWith<HomeNotifier> get copyWith =>
      _$HomeNotifierCopyWithImpl<HomeNotifier>(
          this as HomeNotifier, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HomeNotifier &&
            const DeepCollectionEquality().equals(other.videos, videos) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(runtimeType,
      const DeepCollectionEquality().hash(videos), isLoading, error);

  @override
  String toString() {
    return 'HomeNotifier(videos: $videos, isLoading: $isLoading, error: $error)';
  }
}

/// @nodoc
abstract mixin class $HomeNotifierCopyWith<$Res> {
  factory $HomeNotifierCopyWith(
          HomeNotifier value, $Res Function(HomeNotifier) _then) =
      _$HomeNotifierCopyWithImpl;
  @useResult
  $Res call({List<HomeVideo> videos, bool isLoading, String error});
}

/// @nodoc
class _$HomeNotifierCopyWithImpl<$Res> implements $HomeNotifierCopyWith<$Res> {
  _$HomeNotifierCopyWithImpl(this._self, this._then);

  final HomeNotifier _self;
  final $Res Function(HomeNotifier) _then;

  /// Create a copy of HomeNotifier
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? videos = null,
    Object? isLoading = null,
    Object? error = null,
  }) {
    return _then(_self.copyWith(
      videos: null == videos
          ? _self.videos
          : videos // ignore: cast_nullable_to_non_nullable
              as List<HomeVideo>,
      isLoading: null == isLoading
          ? _self.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      error: null == error
          ? _self.error
          : error // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [HomeNotifier].
extension HomeNotifierPatterns on HomeNotifier {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_HomeNotifier value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HomeNotifier() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_HomeNotifier value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HomeNotifier():
        return $default(_that);
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_HomeNotifier value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HomeNotifier() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(List<HomeVideo> videos, bool isLoading, String error)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HomeNotifier() when $default != null:
        return $default(_that.videos, _that.isLoading, _that.error);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(List<HomeVideo> videos, bool isLoading, String error)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HomeNotifier():
        return $default(_that.videos, _that.isLoading, _that.error);
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(List<HomeVideo> videos, bool isLoading, String error)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HomeNotifier() when $default != null:
        return $default(_that.videos, _that.isLoading, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _HomeNotifier implements HomeNotifier {
  const _HomeNotifier(
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

  /// Create a copy of HomeNotifier
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$HomeNotifierCopyWith<_HomeNotifier> get copyWith =>
      __$HomeNotifierCopyWithImpl<_HomeNotifier>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _HomeNotifier &&
            const DeepCollectionEquality().equals(other._videos, _videos) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(runtimeType,
      const DeepCollectionEquality().hash(_videos), isLoading, error);

  @override
  String toString() {
    return 'HomeNotifier(videos: $videos, isLoading: $isLoading, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$HomeNotifierCopyWith<$Res>
    implements $HomeNotifierCopyWith<$Res> {
  factory _$HomeNotifierCopyWith(
          _HomeNotifier value, $Res Function(_HomeNotifier) _then) =
      __$HomeNotifierCopyWithImpl;
  @override
  @useResult
  $Res call({List<HomeVideo> videos, bool isLoading, String error});
}

/// @nodoc
class __$HomeNotifierCopyWithImpl<$Res>
    implements _$HomeNotifierCopyWith<$Res> {
  __$HomeNotifierCopyWithImpl(this._self, this._then);

  final _HomeNotifier _self;
  final $Res Function(_HomeNotifier) _then;

  /// Create a copy of HomeNotifier
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? videos = null,
    Object? isLoading = null,
    Object? error = null,
  }) {
    return _then(_HomeNotifier(
      videos: null == videos
          ? _self._videos
          : videos // ignore: cast_nullable_to_non_nullable
              as List<HomeVideo>,
      isLoading: null == isLoading
          ? _self.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      error: null == error
          ? _self.error
          : error // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
