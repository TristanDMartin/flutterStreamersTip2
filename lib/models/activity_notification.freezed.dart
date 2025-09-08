// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'activity_notification.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ActivityNotification _$ActivityNotificationFromJson(Map<String, dynamic> json) {
  return _ActivityNotification.fromJson(json);
}

/// @nodoc
mixin _$ActivityNotification {
  String get id => throw _privateConstructorUsedError;
  ActivityNotificationType get type => throw _privateConstructorUsedError;
  @UserConverter()
  User get user => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get timestamp => throw _privateConstructorUsedError;
  String? get postThumbnailUrl => throw _privateConstructorUsedError;
  String? get commentText => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  String? get videoId => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ActivityNotificationCopyWith<ActivityNotification> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ActivityNotificationCopyWith<$Res> {
  factory $ActivityNotificationCopyWith(ActivityNotification value,
          $Res Function(ActivityNotification) then) =
      _$ActivityNotificationCopyWithImpl<$Res, ActivityNotification>;
  @useResult
  $Res call(
      {String id,
      ActivityNotificationType type,
      @UserConverter() User user,
      @TimestampConverter() DateTime timestamp,
      String? postThumbnailUrl,
      String? commentText,
      String status,
      String? videoId});
}

/// @nodoc
class _$ActivityNotificationCopyWithImpl<$Res,
        $Val extends ActivityNotification>
    implements $ActivityNotificationCopyWith<$Res> {
  _$ActivityNotificationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

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
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ActivityNotificationType,
      user: null == user
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as User,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      postThumbnailUrl: freezed == postThumbnailUrl
          ? _value.postThumbnailUrl
          : postThumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      commentText: freezed == commentText
          ? _value.commentText
          : commentText // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      videoId: freezed == videoId
          ? _value.videoId
          : videoId // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ActivityNotificationImplCopyWith<$Res>
    implements $ActivityNotificationCopyWith<$Res> {
  factory _$$ActivityNotificationImplCopyWith(_$ActivityNotificationImpl value,
          $Res Function(_$ActivityNotificationImpl) then) =
      __$$ActivityNotificationImplCopyWithImpl<$Res>;
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
      String? videoId});
}

/// @nodoc
class __$$ActivityNotificationImplCopyWithImpl<$Res>
    extends _$ActivityNotificationCopyWithImpl<$Res, _$ActivityNotificationImpl>
    implements _$$ActivityNotificationImplCopyWith<$Res> {
  __$$ActivityNotificationImplCopyWithImpl(_$ActivityNotificationImpl _value,
      $Res Function(_$ActivityNotificationImpl) _then)
      : super(_value, _then);

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
  }) {
    return _then(_$ActivityNotificationImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ActivityNotificationType,
      user: null == user
          ? _value.user
          : user // ignore: cast_nullable_to_non_nullable
              as User,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      postThumbnailUrl: freezed == postThumbnailUrl
          ? _value.postThumbnailUrl
          : postThumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      commentText: freezed == commentText
          ? _value.commentText
          : commentText // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      videoId: freezed == videoId
          ? _value.videoId
          : videoId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ActivityNotificationImpl implements _ActivityNotification {
  const _$ActivityNotificationImpl(
      {required this.id,
      required this.type,
      @UserConverter() required this.user,
      @TimestampConverter() required this.timestamp,
      this.postThumbnailUrl,
      this.commentText,
      this.status = 'pending',
      this.videoId});

  factory _$ActivityNotificationImpl.fromJson(Map<String, dynamic> json) =>
      _$$ActivityNotificationImplFromJson(json);

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
  String toString() {
    return 'ActivityNotification(id: $id, type: $type, user: $user, timestamp: $timestamp, postThumbnailUrl: $postThumbnailUrl, commentText: $commentText, status: $status, videoId: $videoId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ActivityNotificationImpl &&
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
            (identical(other.videoId, videoId) || other.videoId == videoId));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, type, user, timestamp,
      postThumbnailUrl, commentText, status, videoId);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ActivityNotificationImplCopyWith<_$ActivityNotificationImpl>
      get copyWith =>
          __$$ActivityNotificationImplCopyWithImpl<_$ActivityNotificationImpl>(
              this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ActivityNotificationImplToJson(
      this,
    );
  }
}

abstract class _ActivityNotification implements ActivityNotification {
  const factory _ActivityNotification(
      {required final String id,
      required final ActivityNotificationType type,
      @UserConverter() required final User user,
      @TimestampConverter() required final DateTime timestamp,
      final String? postThumbnailUrl,
      final String? commentText,
      final String status,
      final String? videoId}) = _$ActivityNotificationImpl;

  factory _ActivityNotification.fromJson(Map<String, dynamic> json) =
      _$ActivityNotificationImpl.fromJson;

  @override
  String get id;
  @override
  ActivityNotificationType get type;
  @override
  @UserConverter()
  User get user;
  @override
  @TimestampConverter()
  DateTime get timestamp;
  @override
  String? get postThumbnailUrl;
  @override
  String? get commentText;
  @override
  String get status;
  @override
  String? get videoId;
  @override
  @JsonKey(ignore: true)
  _$$ActivityNotificationImplCopyWith<_$ActivityNotificationImpl>
      get copyWith => throw _privateConstructorUsedError;
}
