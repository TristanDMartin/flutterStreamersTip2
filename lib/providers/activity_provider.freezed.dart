// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'activity_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ActivityState implements DiagnosticableTreeMixin {
  Map<String, List<ActivityNotification>> get grouped;
  bool get isLoading;
  bool get isProcessing;
  int get processingCount;
  String? get error;
  bool get hasError;

  /// Create a copy of ActivityState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ActivityStateCopyWith<ActivityState> get copyWith =>
      _$ActivityStateCopyWithImpl<ActivityState>(
          this as ActivityState, _$identity);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
      ..add(DiagnosticsProperty('type', 'ActivityState'))
      ..add(DiagnosticsProperty('grouped', grouped))
      ..add(DiagnosticsProperty('isLoading', isLoading))
      ..add(DiagnosticsProperty('isProcessing', isProcessing))
      ..add(DiagnosticsProperty('processingCount', processingCount))
      ..add(DiagnosticsProperty('error', error))
      ..add(DiagnosticsProperty('hasError', hasError));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ActivityState &&
            const DeepCollectionEquality().equals(other.grouped, grouped) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.isProcessing, isProcessing) ||
                other.isProcessing == isProcessing) &&
            (identical(other.processingCount, processingCount) ||
                other.processingCount == processingCount) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.hasError, hasError) ||
                other.hasError == hasError));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(grouped),
      isLoading,
      isProcessing,
      processingCount,
      error,
      hasError);

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'ActivityState(grouped: $grouped, isLoading: $isLoading, isProcessing: $isProcessing, processingCount: $processingCount, error: $error, hasError: $hasError)';
  }
}

/// @nodoc
abstract mixin class $ActivityStateCopyWith<$Res> {
  factory $ActivityStateCopyWith(
          ActivityState value, $Res Function(ActivityState) _then) =
      _$ActivityStateCopyWithImpl;
  @useResult
  $Res call(
      {Map<String, List<ActivityNotification>> grouped,
      bool isLoading,
      bool isProcessing,
      int processingCount,
      String? error,
      bool hasError});
}

/// @nodoc
class _$ActivityStateCopyWithImpl<$Res>
    implements $ActivityStateCopyWith<$Res> {
  _$ActivityStateCopyWithImpl(this._self, this._then);

  final ActivityState _self;
  final $Res Function(ActivityState) _then;

  /// Create a copy of ActivityState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? grouped = null,
    Object? isLoading = null,
    Object? isProcessing = null,
    Object? processingCount = null,
    Object? error = freezed,
    Object? hasError = null,
  }) {
    return _then(_self.copyWith(
      grouped: null == grouped
          ? _self.grouped
          : grouped // ignore: cast_nullable_to_non_nullable
              as Map<String, List<ActivityNotification>>,
      isLoading: null == isLoading
          ? _self.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      isProcessing: null == isProcessing
          ? _self.isProcessing
          : isProcessing // ignore: cast_nullable_to_non_nullable
              as bool,
      processingCount: null == processingCount
          ? _self.processingCount
          : processingCount // ignore: cast_nullable_to_non_nullable
              as int,
      error: freezed == error
          ? _self.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      hasError: null == hasError
          ? _self.hasError
          : hasError // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [ActivityState].
extension ActivityStatePatterns on ActivityState {
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
    TResult Function(_ActivityState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ActivityState() when $default != null:
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
    TResult Function(_ActivityState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ActivityState():
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
    TResult? Function(_ActivityState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ActivityState() when $default != null:
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
    TResult Function(
            Map<String, List<ActivityNotification>> grouped,
            bool isLoading,
            bool isProcessing,
            int processingCount,
            String? error,
            bool hasError)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ActivityState() when $default != null:
        return $default(_that.grouped, _that.isLoading, _that.isProcessing,
            _that.processingCount, _that.error, _that.hasError);
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
    TResult Function(
            Map<String, List<ActivityNotification>> grouped,
            bool isLoading,
            bool isProcessing,
            int processingCount,
            String? error,
            bool hasError)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ActivityState():
        return $default(_that.grouped, _that.isLoading, _that.isProcessing,
            _that.processingCount, _that.error, _that.hasError);
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
    TResult? Function(
            Map<String, List<ActivityNotification>> grouped,
            bool isLoading,
            bool isProcessing,
            int processingCount,
            String? error,
            bool hasError)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ActivityState() when $default != null:
        return $default(_that.grouped, _that.isLoading, _that.isProcessing,
            _that.processingCount, _that.error, _that.hasError);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ActivityState with DiagnosticableTreeMixin implements ActivityState {
  const _ActivityState(
      {final Map<String, List<ActivityNotification>> grouped = const {},
      this.isLoading = false,
      this.isProcessing = false,
      this.processingCount = 0,
      this.error,
      this.hasError = false})
      : _grouped = grouped;

  final Map<String, List<ActivityNotification>> _grouped;
  @override
  @JsonKey()
  Map<String, List<ActivityNotification>> get grouped {
    if (_grouped is EqualUnmodifiableMapView) return _grouped;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_grouped);
  }

  @override
  @JsonKey()
  final bool isLoading;
  @override
  @JsonKey()
  final bool isProcessing;
  @override
  @JsonKey()
  final int processingCount;
  @override
  final String? error;
  @override
  @JsonKey()
  final bool hasError;

  /// Create a copy of ActivityState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ActivityStateCopyWith<_ActivityState> get copyWith =>
      __$ActivityStateCopyWithImpl<_ActivityState>(this, _$identity);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
      ..add(DiagnosticsProperty('type', 'ActivityState'))
      ..add(DiagnosticsProperty('grouped', grouped))
      ..add(DiagnosticsProperty('isLoading', isLoading))
      ..add(DiagnosticsProperty('isProcessing', isProcessing))
      ..add(DiagnosticsProperty('processingCount', processingCount))
      ..add(DiagnosticsProperty('error', error))
      ..add(DiagnosticsProperty('hasError', hasError));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ActivityState &&
            const DeepCollectionEquality().equals(other._grouped, _grouped) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.isProcessing, isProcessing) ||
                other.isProcessing == isProcessing) &&
            (identical(other.processingCount, processingCount) ||
                other.processingCount == processingCount) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.hasError, hasError) ||
                other.hasError == hasError));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_grouped),
      isLoading,
      isProcessing,
      processingCount,
      error,
      hasError);

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'ActivityState(grouped: $grouped, isLoading: $isLoading, isProcessing: $isProcessing, processingCount: $processingCount, error: $error, hasError: $hasError)';
  }
}

/// @nodoc
abstract mixin class _$ActivityStateCopyWith<$Res>
    implements $ActivityStateCopyWith<$Res> {
  factory _$ActivityStateCopyWith(
          _ActivityState value, $Res Function(_ActivityState) _then) =
      __$ActivityStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {Map<String, List<ActivityNotification>> grouped,
      bool isLoading,
      bool isProcessing,
      int processingCount,
      String? error,
      bool hasError});
}

/// @nodoc
class __$ActivityStateCopyWithImpl<$Res>
    implements _$ActivityStateCopyWith<$Res> {
  __$ActivityStateCopyWithImpl(this._self, this._then);

  final _ActivityState _self;
  final $Res Function(_ActivityState) _then;

  /// Create a copy of ActivityState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? grouped = null,
    Object? isLoading = null,
    Object? isProcessing = null,
    Object? processingCount = null,
    Object? error = freezed,
    Object? hasError = null,
  }) {
    return _then(_ActivityState(
      grouped: null == grouped
          ? _self._grouped
          : grouped // ignore: cast_nullable_to_non_nullable
              as Map<String, List<ActivityNotification>>,
      isLoading: null == isLoading
          ? _self.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      isProcessing: null == isProcessing
          ? _self.isProcessing
          : isProcessing // ignore: cast_nullable_to_non_nullable
              as bool,
      processingCount: null == processingCount
          ? _self.processingCount
          : processingCount // ignore: cast_nullable_to_non_nullable
              as int,
      error: freezed == error
          ? _self.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      hasError: null == hasError
          ? _self.hasError
          : hasError // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

// dart format on
