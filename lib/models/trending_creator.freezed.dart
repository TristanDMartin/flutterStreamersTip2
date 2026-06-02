// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'trending_creator.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TrendingCreator {
  String get id;
  String get username;
  String? get displayName;
  String? get avatarURL;
  int get followerCount;
  bool get isActive;
  int get creatorLevel;
  String? get tierStatusLabel;
  bool get isFollowing;

  /// Create a copy of TrendingCreator
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TrendingCreatorCopyWith<TrendingCreator> get copyWith =>
      _$TrendingCreatorCopyWithImpl<TrendingCreator>(
          this as TrendingCreator, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TrendingCreator &&
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
                other.isActive == isActive) &&
            (identical(other.creatorLevel, creatorLevel) ||
                other.creatorLevel == creatorLevel) &&
            (identical(other.tierStatusLabel, tierStatusLabel) ||
                other.tierStatusLabel == tierStatusLabel) &&
            (identical(other.isFollowing, isFollowing) ||
                other.isFollowing == isFollowing));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      username,
      displayName,
      avatarURL,
      followerCount,
      isActive,
      creatorLevel,
      tierStatusLabel,
      isFollowing);

  @override
  String toString() {
    return 'TrendingCreator(id: $id, username: $username, displayName: $displayName, avatarURL: $avatarURL, followerCount: $followerCount, isActive: $isActive, creatorLevel: $creatorLevel, tierStatusLabel: $tierStatusLabel, isFollowing: $isFollowing)';
  }
}

/// @nodoc
abstract mixin class $TrendingCreatorCopyWith<$Res> {
  factory $TrendingCreatorCopyWith(
          TrendingCreator value, $Res Function(TrendingCreator) _then) =
      _$TrendingCreatorCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String username,
      String? displayName,
      String? avatarURL,
      int followerCount,
      bool isActive,
      int creatorLevel,
      String? tierStatusLabel,
      bool isFollowing});
}

/// @nodoc
class _$TrendingCreatorCopyWithImpl<$Res>
    implements $TrendingCreatorCopyWith<$Res> {
  _$TrendingCreatorCopyWithImpl(this._self, this._then);

  final TrendingCreator _self;
  final $Res Function(TrendingCreator) _then;

  /// Create a copy of TrendingCreator
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? username = null,
    Object? displayName = freezed,
    Object? avatarURL = freezed,
    Object? followerCount = null,
    Object? isActive = null,
    Object? creatorLevel = null,
    Object? tierStatusLabel = freezed,
    Object? isFollowing = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _self.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: freezed == displayName
          ? _self.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String?,
      avatarURL: freezed == avatarURL
          ? _self.avatarURL
          : avatarURL // ignore: cast_nullable_to_non_nullable
              as String?,
      followerCount: null == followerCount
          ? _self.followerCount
          : followerCount // ignore: cast_nullable_to_non_nullable
              as int,
      isActive: null == isActive
          ? _self.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      creatorLevel: null == creatorLevel
          ? _self.creatorLevel
          : creatorLevel // ignore: cast_nullable_to_non_nullable
              as int,
      tierStatusLabel: freezed == tierStatusLabel
          ? _self.tierStatusLabel
          : tierStatusLabel // ignore: cast_nullable_to_non_nullable
              as String?,
      isFollowing: null == isFollowing
          ? _self.isFollowing
          : isFollowing // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [TrendingCreator].
extension TrendingCreatorPatterns on TrendingCreator {
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
    TResult Function(_TrendingCreator value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TrendingCreator() when $default != null:
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
    TResult Function(_TrendingCreator value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TrendingCreator():
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
    TResult? Function(_TrendingCreator value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TrendingCreator() when $default != null:
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
            String id,
            String username,
            String? displayName,
            String? avatarURL,
            int followerCount,
            bool isActive,
            int creatorLevel,
            String? tierStatusLabel,
            bool isFollowing)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TrendingCreator() when $default != null:
        return $default(
            _that.id,
            _that.username,
            _that.displayName,
            _that.avatarURL,
            _that.followerCount,
            _that.isActive,
            _that.creatorLevel,
            _that.tierStatusLabel,
            _that.isFollowing);
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
            String id,
            String username,
            String? displayName,
            String? avatarURL,
            int followerCount,
            bool isActive,
            int creatorLevel,
            String? tierStatusLabel,
            bool isFollowing)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TrendingCreator():
        return $default(
            _that.id,
            _that.username,
            _that.displayName,
            _that.avatarURL,
            _that.followerCount,
            _that.isActive,
            _that.creatorLevel,
            _that.tierStatusLabel,
            _that.isFollowing);
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
            String id,
            String username,
            String? displayName,
            String? avatarURL,
            int followerCount,
            bool isActive,
            int creatorLevel,
            String? tierStatusLabel,
            bool isFollowing)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TrendingCreator() when $default != null:
        return $default(
            _that.id,
            _that.username,
            _that.displayName,
            _that.avatarURL,
            _that.followerCount,
            _that.isActive,
            _that.creatorLevel,
            _that.tierStatusLabel,
            _that.isFollowing);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _TrendingCreator implements TrendingCreator {
  const _TrendingCreator(
      {required this.id,
      required this.username,
      this.displayName,
      this.avatarURL,
      this.followerCount = 0,
      this.isActive = false,
      this.creatorLevel = 0,
      this.tierStatusLabel,
      this.isFollowing = false});

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
  @JsonKey()
  final int creatorLevel;
  @override
  final String? tierStatusLabel;
  @override
  @JsonKey()
  final bool isFollowing;

  /// Create a copy of TrendingCreator
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TrendingCreatorCopyWith<_TrendingCreator> get copyWith =>
      __$TrendingCreatorCopyWithImpl<_TrendingCreator>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TrendingCreator &&
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
                other.isActive == isActive) &&
            (identical(other.creatorLevel, creatorLevel) ||
                other.creatorLevel == creatorLevel) &&
            (identical(other.tierStatusLabel, tierStatusLabel) ||
                other.tierStatusLabel == tierStatusLabel) &&
            (identical(other.isFollowing, isFollowing) ||
                other.isFollowing == isFollowing));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      username,
      displayName,
      avatarURL,
      followerCount,
      isActive,
      creatorLevel,
      tierStatusLabel,
      isFollowing);

  @override
  String toString() {
    return 'TrendingCreator(id: $id, username: $username, displayName: $displayName, avatarURL: $avatarURL, followerCount: $followerCount, isActive: $isActive, creatorLevel: $creatorLevel, tierStatusLabel: $tierStatusLabel, isFollowing: $isFollowing)';
  }
}

/// @nodoc
abstract mixin class _$TrendingCreatorCopyWith<$Res>
    implements $TrendingCreatorCopyWith<$Res> {
  factory _$TrendingCreatorCopyWith(
          _TrendingCreator value, $Res Function(_TrendingCreator) _then) =
      __$TrendingCreatorCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String username,
      String? displayName,
      String? avatarURL,
      int followerCount,
      bool isActive,
      int creatorLevel,
      String? tierStatusLabel,
      bool isFollowing});
}

/// @nodoc
class __$TrendingCreatorCopyWithImpl<$Res>
    implements _$TrendingCreatorCopyWith<$Res> {
  __$TrendingCreatorCopyWithImpl(this._self, this._then);

  final _TrendingCreator _self;
  final $Res Function(_TrendingCreator) _then;

  /// Create a copy of TrendingCreator
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? username = null,
    Object? displayName = freezed,
    Object? avatarURL = freezed,
    Object? followerCount = null,
    Object? isActive = null,
    Object? creatorLevel = null,
    Object? tierStatusLabel = freezed,
    Object? isFollowing = null,
  }) {
    return _then(_TrendingCreator(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _self.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: freezed == displayName
          ? _self.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String?,
      avatarURL: freezed == avatarURL
          ? _self.avatarURL
          : avatarURL // ignore: cast_nullable_to_non_nullable
              as String?,
      followerCount: null == followerCount
          ? _self.followerCount
          : followerCount // ignore: cast_nullable_to_non_nullable
              as int,
      isActive: null == isActive
          ? _self.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      creatorLevel: null == creatorLevel
          ? _self.creatorLevel
          : creatorLevel // ignore: cast_nullable_to_non_nullable
              as int,
      tierStatusLabel: freezed == tierStatusLabel
          ? _self.tierStatusLabel
          : tierStatusLabel // ignore: cast_nullable_to_non_nullable
              as String?,
      isFollowing: null == isFollowing
          ? _self.isFollowing
          : isFollowing // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

// dart format on
