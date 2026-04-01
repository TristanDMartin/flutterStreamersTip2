// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'activity_notification.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ActivityNotification {
  String get id;
  ActivityNotificationType get type;
  @UserConverter()
  User get user;
  @TimestampConverter()
  DateTime get timestamp;
  String? get postThumbnailUrl;
  String? get commentText;
  String get status;
  String? get videoId;
  String? get chatId;
  String? get milestoneType;
  int? get milestoneValue;
  String? get parentCommentId;

  /// Create a copy of ActivityNotification
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ActivityNotificationCopyWith<ActivityNotification> get copyWith =>
      _$ActivityNotificationCopyWithImpl<ActivityNotification>(
          this as ActivityNotification, _$identity);

  /// Serializes this ActivityNotification to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ActivityNotification &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.postThumbnailUrl, postThumbnailUrl) ||
                other.postThumbnailUrl == postThumbnailUrl) &&
            (identical(other.commentText, commentText) ||
                other.commentText == commentText) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.videoId, videoId) || other.videoId == videoId) &&
            (identical(other.chatId, chatId) || other.chatId == chatId) &&
            (identical(other.milestoneType, milestoneType) ||
                other.milestoneType == milestoneType) &&
            (identical(other.milestoneValue, milestoneValue) ||
                other.milestoneValue == milestoneValue) &&
            (identical(other.parentCommentId, parentCommentId) ||
                other.parentCommentId == parentCommentId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      type,
      user,
      timestamp,
      postThumbnailUrl,
      commentText,
      status,
      videoId,
      chatId,
      milestoneType,
      milestoneValue,
      parentCommentId);

  @override
  String toString() {
    return 'ActivityNotification(id: $id, type: $type, user: $user, timestamp: $timestamp, postThumbnailUrl: $postThumbnailUrl, commentText: $commentText, status: $status, videoId: $videoId, chatId: $chatId, milestoneType: $milestoneType, milestoneValue: $milestoneValue, parentCommentId: $parentCommentId)';
  }
}

/// @nodoc
abstract mixin class $ActivityNotificationCopyWith<$Res> {
  factory $ActivityNotificationCopyWith(ActivityNotification value,
          $Res Function(ActivityNotification) _then) =
      _$ActivityNotificationCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      ActivityNotificationType type,
      @UserConverter() User user,
      @TimestampConverter() DateTime timestamp,
      String? postThumbnailUrl,
      String? commentText,
      String status,
      String? videoId,
      String? chatId,
      String? milestoneType,
      int? milestoneValue,
      String? parentCommentId});
}

/// @nodoc
class _$ActivityNotificationCopyWithImpl<$Res>
    implements $ActivityNotificationCopyWith<$Res> {
  _$ActivityNotificationCopyWithImpl(this._self, this._then);

  final ActivityNotification _self;
  final $Res Function(ActivityNotification) _then;

  /// Create a copy of ActivityNotification
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? user = null,
    Object? timestamp = null,
    Object? postThumbnailUrl = freezed,
    Object? commentText = freezed,
    Object? status = null,
    Object? videoId = freezed,
    Object? chatId = freezed,
    Object? milestoneType = freezed,
    Object? milestoneValue = freezed,
    Object? parentCommentId = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as ActivityNotificationType,
      user: null == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as User,
      timestamp: null == timestamp
          ? _self.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      postThumbnailUrl: freezed == postThumbnailUrl
          ? _self.postThumbnailUrl
          : postThumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      commentText: freezed == commentText
          ? _self.commentText
          : commentText // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      videoId: freezed == videoId
          ? _self.videoId
          : videoId // ignore: cast_nullable_to_non_nullable
              as String?,
      chatId: freezed == chatId
          ? _self.chatId
          : chatId // ignore: cast_nullable_to_non_nullable
              as String?,
      milestoneType: freezed == milestoneType
          ? _self.milestoneType
          : milestoneType // ignore: cast_nullable_to_non_nullable
              as String?,
      milestoneValue: freezed == milestoneValue
          ? _self.milestoneValue
          : milestoneValue // ignore: cast_nullable_to_non_nullable
              as int?,
      parentCommentId: freezed == parentCommentId
          ? _self.parentCommentId
          : parentCommentId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [ActivityNotification].
extension ActivityNotificationPatterns on ActivityNotification {
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
    TResult Function(_ActivityNotification value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ActivityNotification() when $default != null:
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
    TResult Function(_ActivityNotification value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ActivityNotification():
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
    TResult? Function(_ActivityNotification value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ActivityNotification() when $default != null:
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
            ActivityNotificationType type,
            @UserConverter() User user,
            @TimestampConverter() DateTime timestamp,
            String? postThumbnailUrl,
            String? commentText,
            String status,
            String? videoId,
            String? chatId,
            String? milestoneType,
            int? milestoneValue,
            String? parentCommentId)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ActivityNotification() when $default != null:
        return $default(
            _that.id,
            _that.type,
            _that.user,
            _that.timestamp,
            _that.postThumbnailUrl,
            _that.commentText,
            _that.status,
            _that.videoId,
            _that.chatId,
            _that.milestoneType,
            _that.milestoneValue,
            _that.parentCommentId);
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
            ActivityNotificationType type,
            @UserConverter() User user,
            @TimestampConverter() DateTime timestamp,
            String? postThumbnailUrl,
            String? commentText,
            String status,
            String? videoId,
            String? chatId,
            String? milestoneType,
            int? milestoneValue,
            String? parentCommentId)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ActivityNotification():
        return $default(
            _that.id,
            _that.type,
            _that.user,
            _that.timestamp,
            _that.postThumbnailUrl,
            _that.commentText,
            _that.status,
            _that.videoId,
            _that.chatId,
            _that.milestoneType,
            _that.milestoneValue,
            _that.parentCommentId);
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
            ActivityNotificationType type,
            @UserConverter() User user,
            @TimestampConverter() DateTime timestamp,
            String? postThumbnailUrl,
            String? commentText,
            String status,
            String? videoId,
            String? chatId,
            String? milestoneType,
            int? milestoneValue,
            String? parentCommentId)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ActivityNotification() when $default != null:
        return $default(
            _that.id,
            _that.type,
            _that.user,
            _that.timestamp,
            _that.postThumbnailUrl,
            _that.commentText,
            _that.status,
            _that.videoId,
            _that.chatId,
            _that.milestoneType,
            _that.milestoneValue,
            _that.parentCommentId);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ActivityNotification implements ActivityNotification {
  const _ActivityNotification(
      {required this.id,
      required this.type,
      @UserConverter() required this.user,
      @TimestampConverter() required this.timestamp,
      this.postThumbnailUrl,
      this.commentText,
      this.status = 'pending',
      this.videoId,
      this.chatId,
      this.milestoneType,
      this.milestoneValue,
      this.parentCommentId});
  factory _ActivityNotification.fromJson(Map<String, dynamic> json) =>
      _$ActivityNotificationFromJson(json);

  @override
  final String id;
  @override
  final ActivityNotificationType type;
  @override
  @UserConverter()
  final User user;
  @override
  @TimestampConverter()
  final DateTime timestamp;
  @override
  final String? postThumbnailUrl;
  @override
  final String? commentText;
  @override
  @JsonKey()
  final String status;
  @override
  final String? videoId;
  @override
  final String? chatId;
  @override
  final String? milestoneType;
  @override
  final int? milestoneValue;
  @override
  final String? parentCommentId;

  /// Create a copy of ActivityNotification
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ActivityNotificationCopyWith<_ActivityNotification> get copyWith =>
      __$ActivityNotificationCopyWithImpl<_ActivityNotification>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ActivityNotificationToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ActivityNotification &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.postThumbnailUrl, postThumbnailUrl) ||
                other.postThumbnailUrl == postThumbnailUrl) &&
            (identical(other.commentText, commentText) ||
                other.commentText == commentText) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.videoId, videoId) || other.videoId == videoId) &&
            (identical(other.chatId, chatId) || other.chatId == chatId) &&
            (identical(other.milestoneType, milestoneType) ||
                other.milestoneType == milestoneType) &&
            (identical(other.milestoneValue, milestoneValue) ||
                other.milestoneValue == milestoneValue) &&
            (identical(other.parentCommentId, parentCommentId) ||
                other.parentCommentId == parentCommentId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      type,
      user,
      timestamp,
      postThumbnailUrl,
      commentText,
      status,
      videoId,
      chatId,
      milestoneType,
      milestoneValue,
      parentCommentId);

  @override
  String toString() {
    return 'ActivityNotification(id: $id, type: $type, user: $user, timestamp: $timestamp, postThumbnailUrl: $postThumbnailUrl, commentText: $commentText, status: $status, videoId: $videoId, chatId: $chatId, milestoneType: $milestoneType, milestoneValue: $milestoneValue, parentCommentId: $parentCommentId)';
  }
}

/// @nodoc
abstract mixin class _$ActivityNotificationCopyWith<$Res>
    implements $ActivityNotificationCopyWith<$Res> {
  factory _$ActivityNotificationCopyWith(_ActivityNotification value,
          $Res Function(_ActivityNotification) _then) =
      __$ActivityNotificationCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      ActivityNotificationType type,
      @UserConverter() User user,
      @TimestampConverter() DateTime timestamp,
      String? postThumbnailUrl,
      String? commentText,
      String status,
      String? videoId,
      String? chatId,
      String? milestoneType,
      int? milestoneValue,
      String? parentCommentId});
}

/// @nodoc
class __$ActivityNotificationCopyWithImpl<$Res>
    implements _$ActivityNotificationCopyWith<$Res> {
  __$ActivityNotificationCopyWithImpl(this._self, this._then);

  final _ActivityNotification _self;
  final $Res Function(_ActivityNotification) _then;

  /// Create a copy of ActivityNotification
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? user = null,
    Object? timestamp = null,
    Object? postThumbnailUrl = freezed,
    Object? commentText = freezed,
    Object? status = null,
    Object? videoId = freezed,
    Object? chatId = freezed,
    Object? milestoneType = freezed,
    Object? milestoneValue = freezed,
    Object? parentCommentId = freezed,
  }) {
    return _then(_ActivityNotification(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as ActivityNotificationType,
      user: null == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as User,
      timestamp: null == timestamp
          ? _self.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      postThumbnailUrl: freezed == postThumbnailUrl
          ? _self.postThumbnailUrl
          : postThumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      commentText: freezed == commentText
          ? _self.commentText
          : commentText // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      videoId: freezed == videoId
          ? _self.videoId
          : videoId // ignore: cast_nullable_to_non_nullable
              as String?,
      chatId: freezed == chatId
          ? _self.chatId
          : chatId // ignore: cast_nullable_to_non_nullable
              as String?,
      milestoneType: freezed == milestoneType
          ? _self.milestoneType
          : milestoneType // ignore: cast_nullable_to_non_nullable
              as String?,
      milestoneValue: freezed == milestoneValue
          ? _self.milestoneValue
          : milestoneValue // ignore: cast_nullable_to_non_nullable
              as int?,
      parentCommentId: freezed == parentCommentId
          ? _self.parentCommentId
          : parentCommentId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
