// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserState {
  String? get currentUserId;
  User? get currentUser;
  Map<String, User> get users;
  String? get error;

  /// Create a copy of UserState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $UserStateCopyWith<UserState> get copyWith =>
      _$UserStateCopyWithImpl<UserState>(this as UserState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is UserState &&
            (identical(other.currentUserId, currentUserId) ||
                other.currentUserId == currentUserId) &&
            (identical(other.currentUser, currentUser) ||
                other.currentUser == currentUser) &&
            const DeepCollectionEquality().equals(other.users, users) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(runtimeType, currentUserId, currentUser,
      const DeepCollectionEquality().hash(users), error);

  @override
  String toString() {
    return 'UserState(currentUserId: $currentUserId, currentUser: $currentUser, users: $users, error: $error)';
  }
}

/// @nodoc
abstract mixin class $UserStateCopyWith<$Res> {
  factory $UserStateCopyWith(UserState value, $Res Function(UserState) _then) =
      _$UserStateCopyWithImpl;
  @useResult
  $Res call(
      {String? currentUserId,
      User? currentUser,
      Map<String, User> users,
      String? error});
}

/// @nodoc
class _$UserStateCopyWithImpl<$Res> implements $UserStateCopyWith<$Res> {
  _$UserStateCopyWithImpl(this._self, this._then);

  final UserState _self;
  final $Res Function(UserState) _then;

  /// Create a copy of UserState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? currentUserId = freezed,
    Object? currentUser = freezed,
    Object? users = null,
    Object? error = freezed,
  }) {
    return _then(_self.copyWith(
      currentUserId: freezed == currentUserId
          ? _self.currentUserId
          : currentUserId // ignore: cast_nullable_to_non_nullable
              as String?,
      currentUser: freezed == currentUser
          ? _self.currentUser
          : currentUser // ignore: cast_nullable_to_non_nullable
              as User?,
      users: null == users
          ? _self.users
          : users // ignore: cast_nullable_to_non_nullable
              as Map<String, User>,
      error: freezed == error
          ? _self.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [UserState].
extension UserStatePatterns on UserState {
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
    TResult Function(_UserState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _UserState() when $default != null:
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
    TResult Function(_UserState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserState():
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
    TResult? Function(_UserState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserState() when $default != null:
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
    TResult Function(String? currentUserId, User? currentUser,
            Map<String, User> users, String? error)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _UserState() when $default != null:
        return $default(
            _that.currentUserId, _that.currentUser, _that.users, _that.error);
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
    TResult Function(String? currentUserId, User? currentUser,
            Map<String, User> users, String? error)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserState():
        return $default(
            _that.currentUserId, _that.currentUser, _that.users, _that.error);
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
    TResult? Function(String? currentUserId, User? currentUser,
            Map<String, User> users, String? error)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserState() when $default != null:
        return $default(
            _that.currentUserId, _that.currentUser, _that.users, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _UserState implements UserState {
  const _UserState(
      {this.currentUserId,
      this.currentUser,
      final Map<String, User> users = const {},
      this.error})
      : _users = users;

  @override
  final String? currentUserId;
  @override
  final User? currentUser;
  final Map<String, User> _users;
  @override
  @JsonKey()
  Map<String, User> get users {
    if (_users is EqualUnmodifiableMapView) return _users;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_users);
  }

  @override
  final String? error;

  /// Create a copy of UserState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$UserStateCopyWith<_UserState> get copyWith =>
      __$UserStateCopyWithImpl<_UserState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _UserState &&
            (identical(other.currentUserId, currentUserId) ||
                other.currentUserId == currentUserId) &&
            (identical(other.currentUser, currentUser) ||
                other.currentUser == currentUser) &&
            const DeepCollectionEquality().equals(other._users, _users) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(runtimeType, currentUserId, currentUser,
      const DeepCollectionEquality().hash(_users), error);

  @override
  String toString() {
    return 'UserState(currentUserId: $currentUserId, currentUser: $currentUser, users: $users, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$UserStateCopyWith<$Res>
    implements $UserStateCopyWith<$Res> {
  factory _$UserStateCopyWith(
          _UserState value, $Res Function(_UserState) _then) =
      __$UserStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String? currentUserId,
      User? currentUser,
      Map<String, User> users,
      String? error});
}

/// @nodoc
class __$UserStateCopyWithImpl<$Res> implements _$UserStateCopyWith<$Res> {
  __$UserStateCopyWithImpl(this._self, this._then);

  final _UserState _self;
  final $Res Function(_UserState) _then;

  /// Create a copy of UserState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? currentUserId = freezed,
    Object? currentUser = freezed,
    Object? users = null,
    Object? error = freezed,
  }) {
    return _then(_UserState(
      currentUserId: freezed == currentUserId
          ? _self.currentUserId
          : currentUserId // ignore: cast_nullable_to_non_nullable
              as String?,
      currentUser: freezed == currentUser
          ? _self.currentUser
          : currentUser // ignore: cast_nullable_to_non_nullable
              as User?,
      users: null == users
          ? _self._users
          : users // ignore: cast_nullable_to_non_nullable
              as Map<String, User>,
      error: freezed == error
          ? _self.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
