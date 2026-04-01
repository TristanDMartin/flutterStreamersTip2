// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'shared_draft.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SharedDraft {
  String get id;
  String get draftId;
  String get senderId;
  String get receiverId;
  String get senderName;
  String get senderAvatar;
  String get draftTitle;
  String get draftThumbnailUrl;
  int get draftDuration;
  DateTime get sharedAt;
  SharedDraftStatus get status;
  String? get message;
  DateTime? get viewedAt;

  /// Create a copy of SharedDraft
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SharedDraftCopyWith<SharedDraft> get copyWith =>
      _$SharedDraftCopyWithImpl<SharedDraft>(this as SharedDraft, _$identity);

  /// Serializes this SharedDraft to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SharedDraft &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.draftId, draftId) || other.draftId == draftId) &&
            (identical(other.senderId, senderId) ||
                other.senderId == senderId) &&
            (identical(other.receiverId, receiverId) ||
                other.receiverId == receiverId) &&
            (identical(other.senderName, senderName) ||
                other.senderName == senderName) &&
            (identical(other.senderAvatar, senderAvatar) ||
                other.senderAvatar == senderAvatar) &&
            (identical(other.draftTitle, draftTitle) ||
                other.draftTitle == draftTitle) &&
            (identical(other.draftThumbnailUrl, draftThumbnailUrl) ||
                other.draftThumbnailUrl == draftThumbnailUrl) &&
            (identical(other.draftDuration, draftDuration) ||
                other.draftDuration == draftDuration) &&
            (identical(other.sharedAt, sharedAt) ||
                other.sharedAt == sharedAt) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.viewedAt, viewedAt) ||
                other.viewedAt == viewedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      draftId,
      senderId,
      receiverId,
      senderName,
      senderAvatar,
      draftTitle,
      draftThumbnailUrl,
      draftDuration,
      sharedAt,
      status,
      message,
      viewedAt);

  @override
  String toString() {
    return 'SharedDraft(id: $id, draftId: $draftId, senderId: $senderId, receiverId: $receiverId, senderName: $senderName, senderAvatar: $senderAvatar, draftTitle: $draftTitle, draftThumbnailUrl: $draftThumbnailUrl, draftDuration: $draftDuration, sharedAt: $sharedAt, status: $status, message: $message, viewedAt: $viewedAt)';
  }
}

/// @nodoc
abstract mixin class $SharedDraftCopyWith<$Res> {
  factory $SharedDraftCopyWith(
          SharedDraft value, $Res Function(SharedDraft) _then) =
      _$SharedDraftCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String draftId,
      String senderId,
      String receiverId,
      String senderName,
      String senderAvatar,
      String draftTitle,
      String draftThumbnailUrl,
      int draftDuration,
      DateTime sharedAt,
      SharedDraftStatus status,
      String? message,
      DateTime? viewedAt});
}

/// @nodoc
class _$SharedDraftCopyWithImpl<$Res> implements $SharedDraftCopyWith<$Res> {
  _$SharedDraftCopyWithImpl(this._self, this._then);

  final SharedDraft _self;
  final $Res Function(SharedDraft) _then;

  /// Create a copy of SharedDraft
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? draftId = null,
    Object? senderId = null,
    Object? receiverId = null,
    Object? senderName = null,
    Object? senderAvatar = null,
    Object? draftTitle = null,
    Object? draftThumbnailUrl = null,
    Object? draftDuration = null,
    Object? sharedAt = null,
    Object? status = null,
    Object? message = freezed,
    Object? viewedAt = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      draftId: null == draftId
          ? _self.draftId
          : draftId // ignore: cast_nullable_to_non_nullable
              as String,
      senderId: null == senderId
          ? _self.senderId
          : senderId // ignore: cast_nullable_to_non_nullable
              as String,
      receiverId: null == receiverId
          ? _self.receiverId
          : receiverId // ignore: cast_nullable_to_non_nullable
              as String,
      senderName: null == senderName
          ? _self.senderName
          : senderName // ignore: cast_nullable_to_non_nullable
              as String,
      senderAvatar: null == senderAvatar
          ? _self.senderAvatar
          : senderAvatar // ignore: cast_nullable_to_non_nullable
              as String,
      draftTitle: null == draftTitle
          ? _self.draftTitle
          : draftTitle // ignore: cast_nullable_to_non_nullable
              as String,
      draftThumbnailUrl: null == draftThumbnailUrl
          ? _self.draftThumbnailUrl
          : draftThumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String,
      draftDuration: null == draftDuration
          ? _self.draftDuration
          : draftDuration // ignore: cast_nullable_to_non_nullable
              as int,
      sharedAt: null == sharedAt
          ? _self.sharedAt
          : sharedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as SharedDraftStatus,
      message: freezed == message
          ? _self.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
      viewedAt: freezed == viewedAt
          ? _self.viewedAt
          : viewedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// Adds pattern-matching-related methods to [SharedDraft].
extension SharedDraftPatterns on SharedDraft {
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
    TResult Function(_SharedDraft value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SharedDraft() when $default != null:
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
    TResult Function(_SharedDraft value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SharedDraft():
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
    TResult? Function(_SharedDraft value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SharedDraft() when $default != null:
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
            String draftId,
            String senderId,
            String receiverId,
            String senderName,
            String senderAvatar,
            String draftTitle,
            String draftThumbnailUrl,
            int draftDuration,
            DateTime sharedAt,
            SharedDraftStatus status,
            String? message,
            DateTime? viewedAt)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SharedDraft() when $default != null:
        return $default(
            _that.id,
            _that.draftId,
            _that.senderId,
            _that.receiverId,
            _that.senderName,
            _that.senderAvatar,
            _that.draftTitle,
            _that.draftThumbnailUrl,
            _that.draftDuration,
            _that.sharedAt,
            _that.status,
            _that.message,
            _that.viewedAt);
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
            String draftId,
            String senderId,
            String receiverId,
            String senderName,
            String senderAvatar,
            String draftTitle,
            String draftThumbnailUrl,
            int draftDuration,
            DateTime sharedAt,
            SharedDraftStatus status,
            String? message,
            DateTime? viewedAt)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SharedDraft():
        return $default(
            _that.id,
            _that.draftId,
            _that.senderId,
            _that.receiverId,
            _that.senderName,
            _that.senderAvatar,
            _that.draftTitle,
            _that.draftThumbnailUrl,
            _that.draftDuration,
            _that.sharedAt,
            _that.status,
            _that.message,
            _that.viewedAt);
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
            String draftId,
            String senderId,
            String receiverId,
            String senderName,
            String senderAvatar,
            String draftTitle,
            String draftThumbnailUrl,
            int draftDuration,
            DateTime sharedAt,
            SharedDraftStatus status,
            String? message,
            DateTime? viewedAt)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SharedDraft() when $default != null:
        return $default(
            _that.id,
            _that.draftId,
            _that.senderId,
            _that.receiverId,
            _that.senderName,
            _that.senderAvatar,
            _that.draftTitle,
            _that.draftThumbnailUrl,
            _that.draftDuration,
            _that.sharedAt,
            _that.status,
            _that.message,
            _that.viewedAt);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SharedDraft implements SharedDraft {
  const _SharedDraft(
      {required this.id,
      required this.draftId,
      required this.senderId,
      required this.receiverId,
      required this.senderName,
      required this.senderAvatar,
      required this.draftTitle,
      required this.draftThumbnailUrl,
      required this.draftDuration,
      required this.sharedAt,
      required this.status,
      this.message,
      this.viewedAt});
  factory _SharedDraft.fromJson(Map<String, dynamic> json) =>
      _$SharedDraftFromJson(json);

  @override
  final String id;
  @override
  final String draftId;
  @override
  final String senderId;
  @override
  final String receiverId;
  @override
  final String senderName;
  @override
  final String senderAvatar;
  @override
  final String draftTitle;
  @override
  final String draftThumbnailUrl;
  @override
  final int draftDuration;
  @override
  final DateTime sharedAt;
  @override
  final SharedDraftStatus status;
  @override
  final String? message;
  @override
  final DateTime? viewedAt;

  /// Create a copy of SharedDraft
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SharedDraftCopyWith<_SharedDraft> get copyWith =>
      __$SharedDraftCopyWithImpl<_SharedDraft>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SharedDraftToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SharedDraft &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.draftId, draftId) || other.draftId == draftId) &&
            (identical(other.senderId, senderId) ||
                other.senderId == senderId) &&
            (identical(other.receiverId, receiverId) ||
                other.receiverId == receiverId) &&
            (identical(other.senderName, senderName) ||
                other.senderName == senderName) &&
            (identical(other.senderAvatar, senderAvatar) ||
                other.senderAvatar == senderAvatar) &&
            (identical(other.draftTitle, draftTitle) ||
                other.draftTitle == draftTitle) &&
            (identical(other.draftThumbnailUrl, draftThumbnailUrl) ||
                other.draftThumbnailUrl == draftThumbnailUrl) &&
            (identical(other.draftDuration, draftDuration) ||
                other.draftDuration == draftDuration) &&
            (identical(other.sharedAt, sharedAt) ||
                other.sharedAt == sharedAt) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.viewedAt, viewedAt) ||
                other.viewedAt == viewedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      draftId,
      senderId,
      receiverId,
      senderName,
      senderAvatar,
      draftTitle,
      draftThumbnailUrl,
      draftDuration,
      sharedAt,
      status,
      message,
      viewedAt);

  @override
  String toString() {
    return 'SharedDraft(id: $id, draftId: $draftId, senderId: $senderId, receiverId: $receiverId, senderName: $senderName, senderAvatar: $senderAvatar, draftTitle: $draftTitle, draftThumbnailUrl: $draftThumbnailUrl, draftDuration: $draftDuration, sharedAt: $sharedAt, status: $status, message: $message, viewedAt: $viewedAt)';
  }
}

/// @nodoc
abstract mixin class _$SharedDraftCopyWith<$Res>
    implements $SharedDraftCopyWith<$Res> {
  factory _$SharedDraftCopyWith(
          _SharedDraft value, $Res Function(_SharedDraft) _then) =
      __$SharedDraftCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String draftId,
      String senderId,
      String receiverId,
      String senderName,
      String senderAvatar,
      String draftTitle,
      String draftThumbnailUrl,
      int draftDuration,
      DateTime sharedAt,
      SharedDraftStatus status,
      String? message,
      DateTime? viewedAt});
}

/// @nodoc
class __$SharedDraftCopyWithImpl<$Res> implements _$SharedDraftCopyWith<$Res> {
  __$SharedDraftCopyWithImpl(this._self, this._then);

  final _SharedDraft _self;
  final $Res Function(_SharedDraft) _then;

  /// Create a copy of SharedDraft
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? draftId = null,
    Object? senderId = null,
    Object? receiverId = null,
    Object? senderName = null,
    Object? senderAvatar = null,
    Object? draftTitle = null,
    Object? draftThumbnailUrl = null,
    Object? draftDuration = null,
    Object? sharedAt = null,
    Object? status = null,
    Object? message = freezed,
    Object? viewedAt = freezed,
  }) {
    return _then(_SharedDraft(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      draftId: null == draftId
          ? _self.draftId
          : draftId // ignore: cast_nullable_to_non_nullable
              as String,
      senderId: null == senderId
          ? _self.senderId
          : senderId // ignore: cast_nullable_to_non_nullable
              as String,
      receiverId: null == receiverId
          ? _self.receiverId
          : receiverId // ignore: cast_nullable_to_non_nullable
              as String,
      senderName: null == senderName
          ? _self.senderName
          : senderName // ignore: cast_nullable_to_non_nullable
              as String,
      senderAvatar: null == senderAvatar
          ? _self.senderAvatar
          : senderAvatar // ignore: cast_nullable_to_non_nullable
              as String,
      draftTitle: null == draftTitle
          ? _self.draftTitle
          : draftTitle // ignore: cast_nullable_to_non_nullable
              as String,
      draftThumbnailUrl: null == draftThumbnailUrl
          ? _self.draftThumbnailUrl
          : draftThumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String,
      draftDuration: null == draftDuration
          ? _self.draftDuration
          : draftDuration // ignore: cast_nullable_to_non_nullable
              as int,
      sharedAt: null == sharedAt
          ? _self.sharedAt
          : sharedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as SharedDraftStatus,
      message: freezed == message
          ? _self.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
      viewedAt: freezed == viewedAt
          ? _self.viewedAt
          : viewedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

// dart format on
