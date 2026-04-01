// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'connection.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Connection {
  String get id;
  String get displayName;
  String get username;
  String get avatarUrl;
  bool get isOnline;
  DateTime get lastSeen;

  /// Create a copy of Connection
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ConnectionCopyWith<Connection> get copyWith =>
      _$ConnectionCopyWithImpl<Connection>(this as Connection, _$identity);

  /// Serializes this Connection to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Connection &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.isOnline, isOnline) ||
                other.isOnline == isOnline) &&
            (identical(other.lastSeen, lastSeen) ||
                other.lastSeen == lastSeen));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, displayName, username, avatarUrl, isOnline, lastSeen);

  @override
  String toString() {
    return 'Connection(id: $id, displayName: $displayName, username: $username, avatarUrl: $avatarUrl, isOnline: $isOnline, lastSeen: $lastSeen)';
  }
}

/// @nodoc
abstract mixin class $ConnectionCopyWith<$Res> {
  factory $ConnectionCopyWith(
          Connection value, $Res Function(Connection) _then) =
      _$ConnectionCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String displayName,
      String username,
      String avatarUrl,
      bool isOnline,
      DateTime lastSeen});
}

/// @nodoc
class _$ConnectionCopyWithImpl<$Res> implements $ConnectionCopyWith<$Res> {
  _$ConnectionCopyWithImpl(this._self, this._then);

  final Connection _self;
  final $Res Function(Connection) _then;

  /// Create a copy of Connection
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? displayName = null,
    Object? username = null,
    Object? avatarUrl = null,
    Object? isOnline = null,
    Object? lastSeen = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _self.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _self.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      avatarUrl: null == avatarUrl
          ? _self.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String,
      isOnline: null == isOnline
          ? _self.isOnline
          : isOnline // ignore: cast_nullable_to_non_nullable
              as bool,
      lastSeen: null == lastSeen
          ? _self.lastSeen
          : lastSeen // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// Adds pattern-matching-related methods to [Connection].
extension ConnectionPatterns on Connection {
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
    TResult Function(_Connection value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Connection() when $default != null:
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
    TResult Function(_Connection value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Connection():
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
    TResult? Function(_Connection value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Connection() when $default != null:
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
    TResult Function(String id, String displayName, String username,
            String avatarUrl, bool isOnline, DateTime lastSeen)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Connection() when $default != null:
        return $default(_that.id, _that.displayName, _that.username,
            _that.avatarUrl, _that.isOnline, _that.lastSeen);
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
    TResult Function(String id, String displayName, String username,
            String avatarUrl, bool isOnline, DateTime lastSeen)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Connection():
        return $default(_that.id, _that.displayName, _that.username,
            _that.avatarUrl, _that.isOnline, _that.lastSeen);
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
    TResult? Function(String id, String displayName, String username,
            String avatarUrl, bool isOnline, DateTime lastSeen)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Connection() when $default != null:
        return $default(_that.id, _that.displayName, _that.username,
            _that.avatarUrl, _that.isOnline, _that.lastSeen);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Connection implements Connection {
  const _Connection(
      {required this.id,
      required this.displayName,
      required this.username,
      required this.avatarUrl,
      required this.isOnline,
      required this.lastSeen});
  factory _Connection.fromJson(Map<String, dynamic> json) =>
      _$ConnectionFromJson(json);

  @override
  final String id;
  @override
  final String displayName;
  @override
  final String username;
  @override
  final String avatarUrl;
  @override
  final bool isOnline;
  @override
  final DateTime lastSeen;

  /// Create a copy of Connection
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ConnectionCopyWith<_Connection> get copyWith =>
      __$ConnectionCopyWithImpl<_Connection>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ConnectionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Connection &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.isOnline, isOnline) ||
                other.isOnline == isOnline) &&
            (identical(other.lastSeen, lastSeen) ||
                other.lastSeen == lastSeen));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, displayName, username, avatarUrl, isOnline, lastSeen);

  @override
  String toString() {
    return 'Connection(id: $id, displayName: $displayName, username: $username, avatarUrl: $avatarUrl, isOnline: $isOnline, lastSeen: $lastSeen)';
  }
}

/// @nodoc
abstract mixin class _$ConnectionCopyWith<$Res>
    implements $ConnectionCopyWith<$Res> {
  factory _$ConnectionCopyWith(
          _Connection value, $Res Function(_Connection) _then) =
      __$ConnectionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String displayName,
      String username,
      String avatarUrl,
      bool isOnline,
      DateTime lastSeen});
}

/// @nodoc
class __$ConnectionCopyWithImpl<$Res> implements _$ConnectionCopyWith<$Res> {
  __$ConnectionCopyWithImpl(this._self, this._then);

  final _Connection _self;
  final $Res Function(_Connection) _then;

  /// Create a copy of Connection
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? displayName = null,
    Object? username = null,
    Object? avatarUrl = null,
    Object? isOnline = null,
    Object? lastSeen = null,
  }) {
    return _then(_Connection(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _self.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _self.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      avatarUrl: null == avatarUrl
          ? _self.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String,
      isOnline: null == isOnline
          ? _self.isOnline
          : isOnline // ignore: cast_nullable_to_non_nullable
              as bool,
      lastSeen: null == lastSeen
          ? _self.lastSeen
          : lastSeen // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

// dart format on
