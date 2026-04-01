// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'inbox_notification.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$InboxNotification {
  String get id;
  String get text;
  String get timestamp;
  NotificationType get type;

  /// Create a copy of InboxNotification
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $InboxNotificationCopyWith<InboxNotification> get copyWith =>
      _$InboxNotificationCopyWithImpl<InboxNotification>(
          this as InboxNotification, _$identity);

  /// Serializes this InboxNotification to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is InboxNotification &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.type, type) || other.type == type));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, text, timestamp, type);

  @override
  String toString() {
    return 'InboxNotification(id: $id, text: $text, timestamp: $timestamp, type: $type)';
  }
}

/// @nodoc
abstract mixin class $InboxNotificationCopyWith<$Res> {
  factory $InboxNotificationCopyWith(
          InboxNotification value, $Res Function(InboxNotification) _then) =
      _$InboxNotificationCopyWithImpl;
  @useResult
  $Res call({String id, String text, String timestamp, NotificationType type});
}

/// @nodoc
class _$InboxNotificationCopyWithImpl<$Res>
    implements $InboxNotificationCopyWith<$Res> {
  _$InboxNotificationCopyWithImpl(this._self, this._then);

  final InboxNotification _self;
  final $Res Function(InboxNotification) _then;

  /// Create a copy of InboxNotification
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? text = null,
    Object? timestamp = null,
    Object? type = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      text: null == text
          ? _self.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _self.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as NotificationType,
    ));
  }
}

/// Adds pattern-matching-related methods to [InboxNotification].
extension InboxNotificationPatterns on InboxNotification {
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
    TResult Function(_InboxNotification value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _InboxNotification() when $default != null:
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
    TResult Function(_InboxNotification value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _InboxNotification():
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
    TResult? Function(_InboxNotification value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _InboxNotification() when $default != null:
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
            String id, String text, String timestamp, NotificationType type)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _InboxNotification() when $default != null:
        return $default(_that.id, _that.text, _that.timestamp, _that.type);
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
            String id, String text, String timestamp, NotificationType type)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _InboxNotification():
        return $default(_that.id, _that.text, _that.timestamp, _that.type);
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
            String id, String text, String timestamp, NotificationType type)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _InboxNotification() when $default != null:
        return $default(_that.id, _that.text, _that.timestamp, _that.type);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _InboxNotification implements InboxNotification {
  const _InboxNotification(
      {required this.id,
      required this.text,
      required this.timestamp,
      required this.type});
  factory _InboxNotification.fromJson(Map<String, dynamic> json) =>
      _$InboxNotificationFromJson(json);

  @override
  final String id;
  @override
  final String text;
  @override
  final String timestamp;
  @override
  final NotificationType type;

  /// Create a copy of InboxNotification
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$InboxNotificationCopyWith<_InboxNotification> get copyWith =>
      __$InboxNotificationCopyWithImpl<_InboxNotification>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$InboxNotificationToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _InboxNotification &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.type, type) || other.type == type));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, text, timestamp, type);

  @override
  String toString() {
    return 'InboxNotification(id: $id, text: $text, timestamp: $timestamp, type: $type)';
  }
}

/// @nodoc
abstract mixin class _$InboxNotificationCopyWith<$Res>
    implements $InboxNotificationCopyWith<$Res> {
  factory _$InboxNotificationCopyWith(
          _InboxNotification value, $Res Function(_InboxNotification) _then) =
      __$InboxNotificationCopyWithImpl;
  @override
  @useResult
  $Res call({String id, String text, String timestamp, NotificationType type});
}

/// @nodoc
class __$InboxNotificationCopyWithImpl<$Res>
    implements _$InboxNotificationCopyWith<$Res> {
  __$InboxNotificationCopyWithImpl(this._self, this._then);

  final _InboxNotification _self;
  final $Res Function(_InboxNotification) _then;

  /// Create a copy of InboxNotification
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? text = null,
    Object? timestamp = null,
    Object? type = null,
  }) {
    return _then(_InboxNotification(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      text: null == text
          ? _self.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _self.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as NotificationType,
    ));
  }
}

// dart format on
