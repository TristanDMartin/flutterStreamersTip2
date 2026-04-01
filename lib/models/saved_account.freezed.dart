// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'saved_account.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SavedAccount {
  String get id;
  String get userId;
  String get username;
  String get displayName;
  String? get email;
  String? get avatarURL;
  DateTime get lastLoginDate;

  /// Create a copy of SavedAccount
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SavedAccountCopyWith<SavedAccount> get copyWith =>
      _$SavedAccountCopyWithImpl<SavedAccount>(
          this as SavedAccount, _$identity);

  /// Serializes this SavedAccount to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SavedAccount &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.avatarURL, avatarURL) ||
                other.avatarURL == avatarURL) &&
            (identical(other.lastLoginDate, lastLoginDate) ||
                other.lastLoginDate == lastLoginDate));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, userId, username,
      displayName, email, avatarURL, lastLoginDate);

  @override
  String toString() {
    return 'SavedAccount(id: $id, userId: $userId, username: $username, displayName: $displayName, email: $email, avatarURL: $avatarURL, lastLoginDate: $lastLoginDate)';
  }
}

/// @nodoc
abstract mixin class $SavedAccountCopyWith<$Res> {
  factory $SavedAccountCopyWith(
          SavedAccount value, $Res Function(SavedAccount) _then) =
      _$SavedAccountCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String userId,
      String username,
      String displayName,
      String? email,
      String? avatarURL,
      DateTime lastLoginDate});
}

/// @nodoc
class _$SavedAccountCopyWithImpl<$Res> implements $SavedAccountCopyWith<$Res> {
  _$SavedAccountCopyWithImpl(this._self, this._then);

  final SavedAccount _self;
  final $Res Function(SavedAccount) _then;

  /// Create a copy of SavedAccount
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? username = null,
    Object? displayName = null,
    Object? email = freezed,
    Object? avatarURL = freezed,
    Object? lastLoginDate = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _self.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _self.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _self.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      email: freezed == email
          ? _self.email
          : email // ignore: cast_nullable_to_non_nullable
              as String?,
      avatarURL: freezed == avatarURL
          ? _self.avatarURL
          : avatarURL // ignore: cast_nullable_to_non_nullable
              as String?,
      lastLoginDate: null == lastLoginDate
          ? _self.lastLoginDate
          : lastLoginDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// Adds pattern-matching-related methods to [SavedAccount].
extension SavedAccountPatterns on SavedAccount {
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
    TResult Function(_SavedAccount value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SavedAccount() when $default != null:
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
    TResult Function(_SavedAccount value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SavedAccount():
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
    TResult? Function(_SavedAccount value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SavedAccount() when $default != null:
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
            String userId,
            String username,
            String displayName,
            String? email,
            String? avatarURL,
            DateTime lastLoginDate)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SavedAccount() when $default != null:
        return $default(
            _that.id,
            _that.userId,
            _that.username,
            _that.displayName,
            _that.email,
            _that.avatarURL,
            _that.lastLoginDate);
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
            String userId,
            String username,
            String displayName,
            String? email,
            String? avatarURL,
            DateTime lastLoginDate)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SavedAccount():
        return $default(
            _that.id,
            _that.userId,
            _that.username,
            _that.displayName,
            _that.email,
            _that.avatarURL,
            _that.lastLoginDate);
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
            String userId,
            String username,
            String displayName,
            String? email,
            String? avatarURL,
            DateTime lastLoginDate)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SavedAccount() when $default != null:
        return $default(
            _that.id,
            _that.userId,
            _that.username,
            _that.displayName,
            _that.email,
            _that.avatarURL,
            _that.lastLoginDate);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SavedAccount implements SavedAccount {
  const _SavedAccount(
      {required this.id,
      required this.userId,
      required this.username,
      required this.displayName,
      this.email,
      this.avatarURL,
      required this.lastLoginDate});
  factory _SavedAccount.fromJson(Map<String, dynamic> json) =>
      _$SavedAccountFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
  final String username;
  @override
  final String displayName;
  @override
  final String? email;
  @override
  final String? avatarURL;
  @override
  final DateTime lastLoginDate;

  /// Create a copy of SavedAccount
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SavedAccountCopyWith<_SavedAccount> get copyWith =>
      __$SavedAccountCopyWithImpl<_SavedAccount>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SavedAccountToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SavedAccount &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.avatarURL, avatarURL) ||
                other.avatarURL == avatarURL) &&
            (identical(other.lastLoginDate, lastLoginDate) ||
                other.lastLoginDate == lastLoginDate));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, userId, username,
      displayName, email, avatarURL, lastLoginDate);

  @override
  String toString() {
    return 'SavedAccount(id: $id, userId: $userId, username: $username, displayName: $displayName, email: $email, avatarURL: $avatarURL, lastLoginDate: $lastLoginDate)';
  }
}

/// @nodoc
abstract mixin class _$SavedAccountCopyWith<$Res>
    implements $SavedAccountCopyWith<$Res> {
  factory _$SavedAccountCopyWith(
          _SavedAccount value, $Res Function(_SavedAccount) _then) =
      __$SavedAccountCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String userId,
      String username,
      String displayName,
      String? email,
      String? avatarURL,
      DateTime lastLoginDate});
}

/// @nodoc
class __$SavedAccountCopyWithImpl<$Res>
    implements _$SavedAccountCopyWith<$Res> {
  __$SavedAccountCopyWithImpl(this._self, this._then);

  final _SavedAccount _self;
  final $Res Function(_SavedAccount) _then;

  /// Create a copy of SavedAccount
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? username = null,
    Object? displayName = null,
    Object? email = freezed,
    Object? avatarURL = freezed,
    Object? lastLoginDate = null,
  }) {
    return _then(_SavedAccount(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _self.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _self.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _self.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      email: freezed == email
          ? _self.email
          : email // ignore: cast_nullable_to_non_nullable
              as String?,
      avatarURL: freezed == avatarURL
          ? _self.avatarURL
          : avatarURL // ignore: cast_nullable_to_non_nullable
              as String?,
      lastLoginDate: null == lastLoginDate
          ? _self.lastLoginDate
          : lastLoginDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

// dart format on
