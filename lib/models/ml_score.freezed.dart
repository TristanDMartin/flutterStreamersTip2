// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ml_score.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MLScore {
  double get value;
  String get type;

  /// Create a copy of MLScore
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MLScoreCopyWith<MLScore> get copyWith =>
      _$MLScoreCopyWithImpl<MLScore>(this as MLScore, _$identity);

  /// Serializes this MLScore to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MLScore &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.type, type) || other.type == type));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, value, type);

  @override
  String toString() {
    return 'MLScore(value: $value, type: $type)';
  }
}

/// @nodoc
abstract mixin class $MLScoreCopyWith<$Res> {
  factory $MLScoreCopyWith(MLScore value, $Res Function(MLScore) _then) =
      _$MLScoreCopyWithImpl;
  @useResult
  $Res call({double value, String type});
}

/// @nodoc
class _$MLScoreCopyWithImpl<$Res> implements $MLScoreCopyWith<$Res> {
  _$MLScoreCopyWithImpl(this._self, this._then);

  final MLScore _self;
  final $Res Function(MLScore) _then;

  /// Create a copy of MLScore
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? value = null,
    Object? type = null,
  }) {
    return _then(_self.copyWith(
      value: null == value
          ? _self.value
          : value // ignore: cast_nullable_to_non_nullable
              as double,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [MLScore].
extension MLScorePatterns on MLScore {
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
    TResult Function(_MLScore value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MLScore() when $default != null:
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
    TResult Function(_MLScore value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MLScore():
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
    TResult? Function(_MLScore value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MLScore() when $default != null:
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
    TResult Function(double value, String type)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MLScore() when $default != null:
        return $default(_that.value, _that.type);
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
    TResult Function(double value, String type) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MLScore():
        return $default(_that.value, _that.type);
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
    TResult? Function(double value, String type)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MLScore() when $default != null:
        return $default(_that.value, _that.type);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _MLScore implements MLScore {
  const _MLScore({required this.value, required this.type});
  factory _MLScore.fromJson(Map<String, dynamic> json) =>
      _$MLScoreFromJson(json);

  @override
  final double value;
  @override
  final String type;

  /// Create a copy of MLScore
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MLScoreCopyWith<_MLScore> get copyWith =>
      __$MLScoreCopyWithImpl<_MLScore>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$MLScoreToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _MLScore &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.type, type) || other.type == type));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, value, type);

  @override
  String toString() {
    return 'MLScore(value: $value, type: $type)';
  }
}

/// @nodoc
abstract mixin class _$MLScoreCopyWith<$Res> implements $MLScoreCopyWith<$Res> {
  factory _$MLScoreCopyWith(_MLScore value, $Res Function(_MLScore) _then) =
      __$MLScoreCopyWithImpl;
  @override
  @useResult
  $Res call({double value, String type});
}

/// @nodoc
class __$MLScoreCopyWithImpl<$Res> implements _$MLScoreCopyWith<$Res> {
  __$MLScoreCopyWithImpl(this._self, this._then);

  final _MLScore _self;
  final $Res Function(_MLScore) _then;

  /// Create a copy of MLScore
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? value = null,
    Object? type = null,
  }) {
    return _then(_MLScore(
      value: null == value
          ? _self.value
          : value // ignore: cast_nullable_to_non_nullable
              as double,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
