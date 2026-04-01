// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'suggested_connection.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SuggestedConnection {
  String get id;
  String get username;
  String get avatarName;

  /// Create a copy of SuggestedConnection
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SuggestedConnectionCopyWith<SuggestedConnection> get copyWith =>
      _$SuggestedConnectionCopyWithImpl<SuggestedConnection>(
          this as SuggestedConnection, _$identity);

  /// Serializes this SuggestedConnection to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SuggestedConnection &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.avatarName, avatarName) ||
                other.avatarName == avatarName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, username, avatarName);

  @override
  String toString() {
    return 'SuggestedConnection(id: $id, username: $username, avatarName: $avatarName)';
  }
}

/// @nodoc
abstract mixin class $SuggestedConnectionCopyWith<$Res> {
  factory $SuggestedConnectionCopyWith(
          SuggestedConnection value, $Res Function(SuggestedConnection) _then) =
      _$SuggestedConnectionCopyWithImpl;
  @useResult
  $Res call({String id, String username, String avatarName});
}

/// @nodoc
class _$SuggestedConnectionCopyWithImpl<$Res>
    implements $SuggestedConnectionCopyWith<$Res> {
  _$SuggestedConnectionCopyWithImpl(this._self, this._then);

  final SuggestedConnection _self;
  final $Res Function(SuggestedConnection) _then;

  /// Create a copy of SuggestedConnection
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? username = null,
    Object? avatarName = null,
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
      avatarName: null == avatarName
          ? _self.avatarName
          : avatarName // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [SuggestedConnection].
extension SuggestedConnectionPatterns on SuggestedConnection {
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
    TResult Function(_SuggestedConnection value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SuggestedConnection() when $default != null:
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
    TResult Function(_SuggestedConnection value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SuggestedConnection():
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
    TResult? Function(_SuggestedConnection value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SuggestedConnection() when $default != null:
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
    TResult Function(String id, String username, String avatarName)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SuggestedConnection() when $default != null:
        return $default(_that.id, _that.username, _that.avatarName);
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
    TResult Function(String id, String username, String avatarName) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SuggestedConnection():
        return $default(_that.id, _that.username, _that.avatarName);
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
    TResult? Function(String id, String username, String avatarName)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SuggestedConnection() when $default != null:
        return $default(_that.id, _that.username, _that.avatarName);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SuggestedConnection implements SuggestedConnection {
  const _SuggestedConnection(
      {required this.id, required this.username, required this.avatarName});
  factory _SuggestedConnection.fromJson(Map<String, dynamic> json) =>
      _$SuggestedConnectionFromJson(json);

  @override
  final String id;
  @override
  final String username;
  @override
  final String avatarName;

  /// Create a copy of SuggestedConnection
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SuggestedConnectionCopyWith<_SuggestedConnection> get copyWith =>
      __$SuggestedConnectionCopyWithImpl<_SuggestedConnection>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SuggestedConnectionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SuggestedConnection &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.avatarName, avatarName) ||
                other.avatarName == avatarName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, username, avatarName);

  @override
  String toString() {
    return 'SuggestedConnection(id: $id, username: $username, avatarName: $avatarName)';
  }
}

/// @nodoc
abstract mixin class _$SuggestedConnectionCopyWith<$Res>
    implements $SuggestedConnectionCopyWith<$Res> {
  factory _$SuggestedConnectionCopyWith(_SuggestedConnection value,
          $Res Function(_SuggestedConnection) _then) =
      __$SuggestedConnectionCopyWithImpl;
  @override
  @useResult
  $Res call({String id, String username, String avatarName});
}

/// @nodoc
class __$SuggestedConnectionCopyWithImpl<$Res>
    implements _$SuggestedConnectionCopyWith<$Res> {
  __$SuggestedConnectionCopyWithImpl(this._self, this._then);

  final _SuggestedConnection _self;
  final $Res Function(_SuggestedConnection) _then;

  /// Create a copy of SuggestedConnection
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? username = null,
    Object? avatarName = null,
  }) {
    return _then(_SuggestedConnection(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _self.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      avatarName: null == avatarName
          ? _self.avatarName
          : avatarName // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
