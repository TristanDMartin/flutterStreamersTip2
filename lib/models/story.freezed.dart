// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'story.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Story _$StoryFromJson(Map<String, dynamic> json) {
  return _Story.fromJson(json);
}

/// @nodoc
mixin _$Story {
  String get id => throw _privateConstructorUsedError;
  String get creatorId => throw _privateConstructorUsedError;
  String get creatorName => throw _privateConstructorUsedError;
  String? get creatorAvatarURL => throw _privateConstructorUsedError;
  String get mediaURL => throw _privateConstructorUsedError;
  MediaType get mediaType => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  double get duration => throw _privateConstructorUsedError;
  bool get isViewed => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $StoryCopyWith<Story> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StoryCopyWith<$Res> {
  factory $StoryCopyWith(Story value, $Res Function(Story) then) =
      _$StoryCopyWithImpl<$Res, Story>;
  @useResult
  $Res call(
      {String id,
      String creatorId,
      String creatorName,
      String? creatorAvatarURL,
      String mediaURL,
      MediaType mediaType,
      DateTime timestamp,
      double duration,
      bool isViewed});
}

/// @nodoc
class _$StoryCopyWithImpl<$Res, $Val extends Story>
    implements $StoryCopyWith<$Res> {
  _$StoryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? creatorId = null,
    Object? creatorName = null,
    Object? creatorAvatarURL = freezed,
    Object? mediaURL = null,
    Object? mediaType = null,
    Object? timestamp = null,
    Object? duration = null,
    Object? isViewed = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      creatorId: null == creatorId
          ? _value.creatorId
          : creatorId // ignore: cast_nullable_to_non_nullable
              as String,
      creatorName: null == creatorName
          ? _value.creatorName
          : creatorName // ignore: cast_nullable_to_non_nullable
              as String,
      creatorAvatarURL: freezed == creatorAvatarURL
          ? _value.creatorAvatarURL
          : creatorAvatarURL // ignore: cast_nullable_to_non_nullable
              as String?,
      mediaURL: null == mediaURL
          ? _value.mediaURL
          : mediaURL // ignore: cast_nullable_to_non_nullable
              as String,
      mediaType: null == mediaType
          ? _value.mediaType
          : mediaType // ignore: cast_nullable_to_non_nullable
              as MediaType,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as double,
      isViewed: null == isViewed
          ? _value.isViewed
          : isViewed // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$StoryImplCopyWith<$Res> implements $StoryCopyWith<$Res> {
  factory _$$StoryImplCopyWith(
          _$StoryImpl value, $Res Function(_$StoryImpl) then) =
      __$$StoryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String creatorId,
      String creatorName,
      String? creatorAvatarURL,
      String mediaURL,
      MediaType mediaType,
      DateTime timestamp,
      double duration,
      bool isViewed});
}

/// @nodoc
class __$$StoryImplCopyWithImpl<$Res>
    extends _$StoryCopyWithImpl<$Res, _$StoryImpl>
    implements _$$StoryImplCopyWith<$Res> {
  __$$StoryImplCopyWithImpl(
      _$StoryImpl _value, $Res Function(_$StoryImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? creatorId = null,
    Object? creatorName = null,
    Object? creatorAvatarURL = freezed,
    Object? mediaURL = null,
    Object? mediaType = null,
    Object? timestamp = null,
    Object? duration = null,
    Object? isViewed = null,
  }) {
    return _then(_$StoryImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      creatorId: null == creatorId
          ? _value.creatorId
          : creatorId // ignore: cast_nullable_to_non_nullable
              as String,
      creatorName: null == creatorName
          ? _value.creatorName
          : creatorName // ignore: cast_nullable_to_non_nullable
              as String,
      creatorAvatarURL: freezed == creatorAvatarURL
          ? _value.creatorAvatarURL
          : creatorAvatarURL // ignore: cast_nullable_to_non_nullable
              as String?,
      mediaURL: null == mediaURL
          ? _value.mediaURL
          : mediaURL // ignore: cast_nullable_to_non_nullable
              as String,
      mediaType: null == mediaType
          ? _value.mediaType
          : mediaType // ignore: cast_nullable_to_non_nullable
              as MediaType,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as double,
      isViewed: null == isViewed
          ? _value.isViewed
          : isViewed // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$StoryImpl with DiagnosticableTreeMixin implements _Story {
  const _$StoryImpl(
      {required this.id,
      required this.creatorId,
      required this.creatorName,
      this.creatorAvatarURL,
      required this.mediaURL,
      required this.mediaType,
      required this.timestamp,
      required this.duration,
      this.isViewed = false});

  factory _$StoryImpl.fromJson(Map<String, dynamic> json) =>
      _$$StoryImplFromJson(json);

  @override
  final String id;
  @override
  final String creatorId;
  @override
  final String creatorName;
  @override
  final String? creatorAvatarURL;
  @override
  final String mediaURL;
  @override
  final MediaType mediaType;
  @override
  final DateTime timestamp;
  @override
  final double duration;
  @override
  @JsonKey()
  final bool isViewed;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'Story(id: $id, creatorId: $creatorId, creatorName: $creatorName, creatorAvatarURL: $creatorAvatarURL, mediaURL: $mediaURL, mediaType: $mediaType, timestamp: $timestamp, duration: $duration, isViewed: $isViewed)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'Story'))
      ..add(DiagnosticsProperty('id', id))
      ..add(DiagnosticsProperty('creatorId', creatorId))
      ..add(DiagnosticsProperty('creatorName', creatorName))
      ..add(DiagnosticsProperty('creatorAvatarURL', creatorAvatarURL))
      ..add(DiagnosticsProperty('mediaURL', mediaURL))
      ..add(DiagnosticsProperty('mediaType', mediaType))
      ..add(DiagnosticsProperty('timestamp', timestamp))
      ..add(DiagnosticsProperty('duration', duration))
      ..add(DiagnosticsProperty('isViewed', isViewed));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StoryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.creatorId, creatorId) ||
                other.creatorId == creatorId) &&
            (identical(other.creatorName, creatorName) ||
                other.creatorName == creatorName) &&
            (identical(other.creatorAvatarURL, creatorAvatarURL) ||
                other.creatorAvatarURL == creatorAvatarURL) &&
            (identical(other.mediaURL, mediaURL) ||
                other.mediaURL == mediaURL) &&
            (identical(other.mediaType, mediaType) ||
                other.mediaType == mediaType) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.isViewed, isViewed) ||
                other.isViewed == isViewed));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, creatorId, creatorName,
      creatorAvatarURL, mediaURL, mediaType, timestamp, duration, isViewed);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$StoryImplCopyWith<_$StoryImpl> get copyWith =>
      __$$StoryImplCopyWithImpl<_$StoryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StoryImplToJson(
      this,
    );
  }
}

abstract class _Story implements Story {
  const factory _Story(
      {required final String id,
      required final String creatorId,
      required final String creatorName,
      final String? creatorAvatarURL,
      required final String mediaURL,
      required final MediaType mediaType,
      required final DateTime timestamp,
      required final double duration,
      final bool isViewed}) = _$StoryImpl;

  factory _Story.fromJson(Map<String, dynamic> json) = _$StoryImpl.fromJson;

  @override
  String get id;
  @override
  String get creatorId;
  @override
  String get creatorName;
  @override
  String? get creatorAvatarURL;
  @override
  String get mediaURL;
  @override
  MediaType get mediaType;
  @override
  DateTime get timestamp;
  @override
  double get duration;
  @override
  bool get isViewed;
  @override
  @JsonKey(ignore: true)
  _$$StoryImplCopyWith<_$StoryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
