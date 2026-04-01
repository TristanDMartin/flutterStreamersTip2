// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'connection_lite.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ConnectionLite {
  String get userId;
  String get handle;
  String get displayName;
  String get avatarUrl;
  bool get isOnline;
  int? get lastInteractedAt; // timestamp for ranking
  bool get canDM; // gate by privacy settings
  double get rankingScore;

  /// Create a copy of ConnectionLite
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ConnectionLiteCopyWith<ConnectionLite> get copyWith =>
      _$ConnectionLiteCopyWithImpl<ConnectionLite>(
          this as ConnectionLite, _$identity);

  /// Serializes this ConnectionLite to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ConnectionLite &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, userId, handle, displayName,
      avatarUrl, isOnline, lastInteractedAt, canDM, rankingScore);

  @override
  String toString() {
    return 'ConnectionLite(userId: $userId, handle: $handle, displayName: $displayName, avatarUrl: $avatarUrl, isOnline: $isOnline, lastInteractedAt: $lastInteractedAt, canDM: $canDM, rankingScore: $rankingScore)';
  }
}

/// @nodoc
abstract mixin class $ConnectionLiteCopyWith<$Res> {
  factory $ConnectionLiteCopyWith(
          ConnectionLite value, $Res Function(ConnectionLite) _then) =
      _$ConnectionLiteCopyWithImpl;
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
class _$ConnectionLiteCopyWithImpl<$Res>
    implements $ConnectionLiteCopyWith<$Res> {
  _$ConnectionLiteCopyWithImpl(this._self, this._then);

  final ConnectionLite _self;
  final $Res Function(ConnectionLite) _then;

  /// Create a copy of ConnectionLite
  /// with the given fields replaced by the non-null parameter values.
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
    return _then(_self.copyWith(
      userId: null == userId
          ? _self.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      handle: null == handle
          ? _self.handle
          : handle // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _self.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      avatarUrl: null == avatarUrl
          ? _self.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String,
      isOnline: null == isOnline
          ? _self.isOnline
          : isOnline // ignore: cast_nullable_to_non_nullable
              as bool,
      lastInteractedAt: freezed == lastInteractedAt
          ? _self.lastInteractedAt
          : lastInteractedAt // ignore: cast_nullable_to_non_nullable
              as int?,
      canDM: null == canDM
          ? _self.canDM
          : canDM // ignore: cast_nullable_to_non_nullable
              as bool,
      rankingScore: null == rankingScore
          ? _self.rankingScore
          : rankingScore // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// Adds pattern-matching-related methods to [ConnectionLite].
extension ConnectionLitePatterns on ConnectionLite {
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
    TResult Function(_ConnectionLite value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ConnectionLite() when $default != null:
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
    TResult Function(_ConnectionLite value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ConnectionLite():
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
    TResult? Function(_ConnectionLite value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ConnectionLite() when $default != null:
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
            String userId,
            String handle,
            String displayName,
            String avatarUrl,
            bool isOnline,
            int? lastInteractedAt,
            bool canDM,
            double rankingScore)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ConnectionLite() when $default != null:
        return $default(
            _that.userId,
            _that.handle,
            _that.displayName,
            _that.avatarUrl,
            _that.isOnline,
            _that.lastInteractedAt,
            _that.canDM,
            _that.rankingScore);
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
            String userId,
            String handle,
            String displayName,
            String avatarUrl,
            bool isOnline,
            int? lastInteractedAt,
            bool canDM,
            double rankingScore)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ConnectionLite():
        return $default(
            _that.userId,
            _that.handle,
            _that.displayName,
            _that.avatarUrl,
            _that.isOnline,
            _that.lastInteractedAt,
            _that.canDM,
            _that.rankingScore);
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
            String userId,
            String handle,
            String displayName,
            String avatarUrl,
            bool isOnline,
            int? lastInteractedAt,
            bool canDM,
            double rankingScore)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ConnectionLite() when $default != null:
        return $default(
            _that.userId,
            _that.handle,
            _that.displayName,
            _that.avatarUrl,
            _that.isOnline,
            _that.lastInteractedAt,
            _that.canDM,
            _that.rankingScore);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ConnectionLite implements ConnectionLite {
  const _ConnectionLite(
      {required this.userId,
      required this.handle,
      required this.displayName,
      required this.avatarUrl,
      this.isOnline = false,
      this.lastInteractedAt,
      this.canDM = true,
      this.rankingScore = 0.0});
  factory _ConnectionLite.fromJson(Map<String, dynamic> json) =>
      _$ConnectionLiteFromJson(json);

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

  /// Create a copy of ConnectionLite
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ConnectionLiteCopyWith<_ConnectionLite> get copyWith =>
      __$ConnectionLiteCopyWithImpl<_ConnectionLite>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ConnectionLiteToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ConnectionLite &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, userId, handle, displayName,
      avatarUrl, isOnline, lastInteractedAt, canDM, rankingScore);

  @override
  String toString() {
    return 'ConnectionLite(userId: $userId, handle: $handle, displayName: $displayName, avatarUrl: $avatarUrl, isOnline: $isOnline, lastInteractedAt: $lastInteractedAt, canDM: $canDM, rankingScore: $rankingScore)';
  }
}

/// @nodoc
abstract mixin class _$ConnectionLiteCopyWith<$Res>
    implements $ConnectionLiteCopyWith<$Res> {
  factory _$ConnectionLiteCopyWith(
          _ConnectionLite value, $Res Function(_ConnectionLite) _then) =
      __$ConnectionLiteCopyWithImpl;
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
class __$ConnectionLiteCopyWithImpl<$Res>
    implements _$ConnectionLiteCopyWith<$Res> {
  __$ConnectionLiteCopyWithImpl(this._self, this._then);

  final _ConnectionLite _self;
  final $Res Function(_ConnectionLite) _then;

  /// Create a copy of ConnectionLite
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
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
    return _then(_ConnectionLite(
      userId: null == userId
          ? _self.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      handle: null == handle
          ? _self.handle
          : handle // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _self.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      avatarUrl: null == avatarUrl
          ? _self.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String,
      isOnline: null == isOnline
          ? _self.isOnline
          : isOnline // ignore: cast_nullable_to_non_nullable
              as bool,
      lastInteractedAt: freezed == lastInteractedAt
          ? _self.lastInteractedAt
          : lastInteractedAt // ignore: cast_nullable_to_non_nullable
              as int?,
      canDM: null == canDM
          ? _self.canDM
          : canDM // ignore: cast_nullable_to_non_nullable
              as bool,
      rankingScore: null == rankingScore
          ? _self.rankingScore
          : rankingScore // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

// dart format on
