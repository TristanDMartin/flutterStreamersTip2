// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'home_video.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$HomeVideo {
  String get id => throw _privateConstructorUsedError;
  User get creator => throw _privateConstructorUsedError;
  String get videoURL => throw _privateConstructorUsedError;
  String? get thumbnailURL =>
      throw _privateConstructorUsedError; // Legacy field for backward compatibility
  VideoThumbnails? get thumbnails =>
      throw _privateConstructorUsedError; // New multi-size thumbnail support
  int get likes => throw _privateConstructorUsedError;
  int get comments => throw _privateConstructorUsedError;
  int get views => throw _privateConstructorUsedError;
  String get caption => throw _privateConstructorUsedError;
  bool get isLiked => throw _privateConstructorUsedError;
  bool get isFavorited => throw _privateConstructorUsedError;
  bool get isDraft => throw _privateConstructorUsedError;
  double get mlScore => throw _privateConstructorUsedError;
  String get categoryId => throw _privateConstructorUsedError;
  double? get duration =>
      throw _privateConstructorUsedError; // Video duration in seconds
  Timestamp? get createdAt =>
      throw _privateConstructorUsedError; // For sorting by upload date
  bool get allowSave =>
      throw _privateConstructorUsedError; // Can viewers save/download
  bool get allowRemix =>
      throw _privateConstructorUsedError; // Can viewers remix/duet/stitch
  String get visibility =>
      throw _privateConstructorUsedError; // public, followers, private
  String get status =>
      throw _privateConstructorUsedError; // draft, processing, published, blocked, deleted
  bool get isPinned => throw _privateConstructorUsedError; // Pinned to profile
  List<String> get tags => throw _privateConstructorUsedError; // Video tags
  List<String> get playlistIds => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $HomeVideoCopyWith<HomeVideo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HomeVideoCopyWith<$Res> {
  factory $HomeVideoCopyWith(HomeVideo value, $Res Function(HomeVideo) then) =
      _$HomeVideoCopyWithImpl<$Res, HomeVideo>;
  @useResult
  $Res call(
      {String id,
      User creator,
      String videoURL,
      String? thumbnailURL,
      VideoThumbnails? thumbnails,
      int likes,
      int comments,
      int views,
      String caption,
      bool isLiked,
      bool isFavorited,
      bool isDraft,
      double mlScore,
      String categoryId,
      double? duration,
      Timestamp? createdAt,
      bool allowSave,
      bool allowRemix,
      String visibility,
      String status,
      bool isPinned,
      List<String> tags,
      List<String> playlistIds});

  $VideoThumbnailsCopyWith<$Res>? get thumbnails;
}

/// @nodoc
class _$HomeVideoCopyWithImpl<$Res, $Val extends HomeVideo>
    implements $HomeVideoCopyWith<$Res> {
  _$HomeVideoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? creator = null,
    Object? videoURL = null,
    Object? thumbnailURL = freezed,
    Object? thumbnails = freezed,
    Object? likes = null,
    Object? comments = null,
    Object? views = null,
    Object? caption = null,
    Object? isLiked = null,
    Object? isFavorited = null,
    Object? isDraft = null,
    Object? mlScore = null,
    Object? categoryId = null,
    Object? duration = freezed,
    Object? createdAt = freezed,
    Object? allowSave = null,
    Object? allowRemix = null,
    Object? visibility = null,
    Object? status = null,
    Object? isPinned = null,
    Object? tags = null,
    Object? playlistIds = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      creator: null == creator
          ? _value.creator
          : creator // ignore: cast_nullable_to_non_nullable
              as User,
      videoURL: null == videoURL
          ? _value.videoURL
          : videoURL // ignore: cast_nullable_to_non_nullable
              as String,
      thumbnailURL: freezed == thumbnailURL
          ? _value.thumbnailURL
          : thumbnailURL // ignore: cast_nullable_to_non_nullable
              as String?,
      thumbnails: freezed == thumbnails
          ? _value.thumbnails
          : thumbnails // ignore: cast_nullable_to_non_nullable
              as VideoThumbnails?,
      likes: null == likes
          ? _value.likes
          : likes // ignore: cast_nullable_to_non_nullable
              as int,
      comments: null == comments
          ? _value.comments
          : comments // ignore: cast_nullable_to_non_nullable
              as int,
      views: null == views
          ? _value.views
          : views // ignore: cast_nullable_to_non_nullable
              as int,
      caption: null == caption
          ? _value.caption
          : caption // ignore: cast_nullable_to_non_nullable
              as String,
      isLiked: null == isLiked
          ? _value.isLiked
          : isLiked // ignore: cast_nullable_to_non_nullable
              as bool,
      isFavorited: null == isFavorited
          ? _value.isFavorited
          : isFavorited // ignore: cast_nullable_to_non_nullable
              as bool,
      isDraft: null == isDraft
          ? _value.isDraft
          : isDraft // ignore: cast_nullable_to_non_nullable
              as bool,
      mlScore: null == mlScore
          ? _value.mlScore
          : mlScore // ignore: cast_nullable_to_non_nullable
              as double,
      categoryId: null == categoryId
          ? _value.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String,
      duration: freezed == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as double?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as Timestamp?,
      allowSave: null == allowSave
          ? _value.allowSave
          : allowSave // ignore: cast_nullable_to_non_nullable
              as bool,
      allowRemix: null == allowRemix
          ? _value.allowRemix
          : allowRemix // ignore: cast_nullable_to_non_nullable
              as bool,
      visibility: null == visibility
          ? _value.visibility
          : visibility // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      isPinned: null == isPinned
          ? _value.isPinned
          : isPinned // ignore: cast_nullable_to_non_nullable
              as bool,
      tags: null == tags
          ? _value.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      playlistIds: null == playlistIds
          ? _value.playlistIds
          : playlistIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $VideoThumbnailsCopyWith<$Res>? get thumbnails {
    if (_value.thumbnails == null) {
      return null;
    }

    return $VideoThumbnailsCopyWith<$Res>(_value.thumbnails!, (value) {
      return _then(_value.copyWith(thumbnails: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$HomeVideoImplCopyWith<$Res>
    implements $HomeVideoCopyWith<$Res> {
  factory _$$HomeVideoImplCopyWith(
          _$HomeVideoImpl value, $Res Function(_$HomeVideoImpl) then) =
      __$$HomeVideoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      User creator,
      String videoURL,
      String? thumbnailURL,
      VideoThumbnails? thumbnails,
      int likes,
      int comments,
      int views,
      String caption,
      bool isLiked,
      bool isFavorited,
      bool isDraft,
      double mlScore,
      String categoryId,
      double? duration,
      Timestamp? createdAt,
      bool allowSave,
      bool allowRemix,
      String visibility,
      String status,
      bool isPinned,
      List<String> tags,
      List<String> playlistIds});

  @override
  $VideoThumbnailsCopyWith<$Res>? get thumbnails;
}

/// @nodoc
class __$$HomeVideoImplCopyWithImpl<$Res>
    extends _$HomeVideoCopyWithImpl<$Res, _$HomeVideoImpl>
    implements _$$HomeVideoImplCopyWith<$Res> {
  __$$HomeVideoImplCopyWithImpl(
      _$HomeVideoImpl _value, $Res Function(_$HomeVideoImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? creator = null,
    Object? videoURL = null,
    Object? thumbnailURL = freezed,
    Object? thumbnails = freezed,
    Object? likes = null,
    Object? comments = null,
    Object? views = null,
    Object? caption = null,
    Object? isLiked = null,
    Object? isFavorited = null,
    Object? isDraft = null,
    Object? mlScore = null,
    Object? categoryId = null,
    Object? duration = freezed,
    Object? createdAt = freezed,
    Object? allowSave = null,
    Object? allowRemix = null,
    Object? visibility = null,
    Object? status = null,
    Object? isPinned = null,
    Object? tags = null,
    Object? playlistIds = null,
  }) {
    return _then(_$HomeVideoImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      creator: null == creator
          ? _value.creator
          : creator // ignore: cast_nullable_to_non_nullable
              as User,
      videoURL: null == videoURL
          ? _value.videoURL
          : videoURL // ignore: cast_nullable_to_non_nullable
              as String,
      thumbnailURL: freezed == thumbnailURL
          ? _value.thumbnailURL
          : thumbnailURL // ignore: cast_nullable_to_non_nullable
              as String?,
      thumbnails: freezed == thumbnails
          ? _value.thumbnails
          : thumbnails // ignore: cast_nullable_to_non_nullable
              as VideoThumbnails?,
      likes: null == likes
          ? _value.likes
          : likes // ignore: cast_nullable_to_non_nullable
              as int,
      comments: null == comments
          ? _value.comments
          : comments // ignore: cast_nullable_to_non_nullable
              as int,
      views: null == views
          ? _value.views
          : views // ignore: cast_nullable_to_non_nullable
              as int,
      caption: null == caption
          ? _value.caption
          : caption // ignore: cast_nullable_to_non_nullable
              as String,
      isLiked: null == isLiked
          ? _value.isLiked
          : isLiked // ignore: cast_nullable_to_non_nullable
              as bool,
      isFavorited: null == isFavorited
          ? _value.isFavorited
          : isFavorited // ignore: cast_nullable_to_non_nullable
              as bool,
      isDraft: null == isDraft
          ? _value.isDraft
          : isDraft // ignore: cast_nullable_to_non_nullable
              as bool,
      mlScore: null == mlScore
          ? _value.mlScore
          : mlScore // ignore: cast_nullable_to_non_nullable
              as double,
      categoryId: null == categoryId
          ? _value.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String,
      duration: freezed == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as double?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as Timestamp?,
      allowSave: null == allowSave
          ? _value.allowSave
          : allowSave // ignore: cast_nullable_to_non_nullable
              as bool,
      allowRemix: null == allowRemix
          ? _value.allowRemix
          : allowRemix // ignore: cast_nullable_to_non_nullable
              as bool,
      visibility: null == visibility
          ? _value.visibility
          : visibility // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      isPinned: null == isPinned
          ? _value.isPinned
          : isPinned // ignore: cast_nullable_to_non_nullable
              as bool,
      tags: null == tags
          ? _value._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      playlistIds: null == playlistIds
          ? _value._playlistIds
          : playlistIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc

class _$HomeVideoImpl implements _HomeVideo {
  const _$HomeVideoImpl(
      {required this.id,
      required this.creator,
      required this.videoURL,
      this.thumbnailURL,
      this.thumbnails,
      this.likes = 0,
      this.comments = 0,
      this.views = 0,
      this.caption = '',
      this.isLiked = false,
      this.isFavorited = false,
      this.isDraft = false,
      this.mlScore = 0.0,
      this.categoryId = '',
      this.duration = 0.0,
      this.createdAt,
      this.allowSave = true,
      this.allowRemix = true,
      this.visibility = 'public',
      this.status = 'published',
      this.isPinned = false,
      final List<String> tags = const [],
      final List<String> playlistIds = const []})
      : _tags = tags,
        _playlistIds = playlistIds;

  @override
  final String id;
  @override
  final User creator;
  @override
  final String videoURL;
  @override
  final String? thumbnailURL;
// Legacy field for backward compatibility
  @override
  final VideoThumbnails? thumbnails;
// New multi-size thumbnail support
  @override
  @JsonKey()
  final int likes;
  @override
  @JsonKey()
  final int comments;
  @override
  @JsonKey()
  final int views;
  @override
  @JsonKey()
  final String caption;
  @override
  @JsonKey()
  final bool isLiked;
  @override
  @JsonKey()
  final bool isFavorited;
  @override
  @JsonKey()
  final bool isDraft;
  @override
  @JsonKey()
  final double mlScore;
  @override
  @JsonKey()
  final String categoryId;
  @override
  @JsonKey()
  final double? duration;
// Video duration in seconds
  @override
  final Timestamp? createdAt;
// For sorting by upload date
  @override
  @JsonKey()
  final bool allowSave;
// Can viewers save/download
  @override
  @JsonKey()
  final bool allowRemix;
// Can viewers remix/duet/stitch
  @override
  @JsonKey()
  final String visibility;
// public, followers, private
  @override
  @JsonKey()
  final String status;
// draft, processing, published, blocked, deleted
  @override
  @JsonKey()
  final bool isPinned;
// Pinned to profile
  final List<String> _tags;
// Pinned to profile
  @override
  @JsonKey()
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

// Video tags
  final List<String> _playlistIds;
// Video tags
  @override
  @JsonKey()
  List<String> get playlistIds {
    if (_playlistIds is EqualUnmodifiableListView) return _playlistIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_playlistIds);
  }

  @override
  String toString() {
    return 'HomeVideo(id: $id, creator: $creator, videoURL: $videoURL, thumbnailURL: $thumbnailURL, thumbnails: $thumbnails, likes: $likes, comments: $comments, views: $views, caption: $caption, isLiked: $isLiked, isFavorited: $isFavorited, isDraft: $isDraft, mlScore: $mlScore, categoryId: $categoryId, duration: $duration, createdAt: $createdAt, allowSave: $allowSave, allowRemix: $allowRemix, visibility: $visibility, status: $status, isPinned: $isPinned, tags: $tags, playlistIds: $playlistIds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HomeVideoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.creator, creator) || other.creator == creator) &&
            (identical(other.videoURL, videoURL) ||
                other.videoURL == videoURL) &&
            (identical(other.thumbnailURL, thumbnailURL) ||
                other.thumbnailURL == thumbnailURL) &&
            (identical(other.thumbnails, thumbnails) ||
                other.thumbnails == thumbnails) &&
            (identical(other.likes, likes) || other.likes == likes) &&
            (identical(other.comments, comments) ||
                other.comments == comments) &&
            (identical(other.views, views) || other.views == views) &&
            (identical(other.caption, caption) || other.caption == caption) &&
            (identical(other.isLiked, isLiked) || other.isLiked == isLiked) &&
            (identical(other.isFavorited, isFavorited) ||
                other.isFavorited == isFavorited) &&
            (identical(other.isDraft, isDraft) || other.isDraft == isDraft) &&
            (identical(other.mlScore, mlScore) || other.mlScore == mlScore) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.allowSave, allowSave) ||
                other.allowSave == allowSave) &&
            (identical(other.allowRemix, allowRemix) ||
                other.allowRemix == allowRemix) &&
            (identical(other.visibility, visibility) ||
                other.visibility == visibility) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.isPinned, isPinned) ||
                other.isPinned == isPinned) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            const DeepCollectionEquality()
                .equals(other._playlistIds, _playlistIds));
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        creator,
        videoURL,
        thumbnailURL,
        thumbnails,
        likes,
        comments,
        views,
        caption,
        isLiked,
        isFavorited,
        isDraft,
        mlScore,
        categoryId,
        duration,
        createdAt,
        allowSave,
        allowRemix,
        visibility,
        status,
        isPinned,
        const DeepCollectionEquality().hash(_tags),
        const DeepCollectionEquality().hash(_playlistIds)
      ]);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$HomeVideoImplCopyWith<_$HomeVideoImpl> get copyWith =>
      __$$HomeVideoImplCopyWithImpl<_$HomeVideoImpl>(this, _$identity);
}

abstract class _HomeVideo implements HomeVideo {
  const factory _HomeVideo(
      {required final String id,
      required final User creator,
      required final String videoURL,
      final String? thumbnailURL,
      final VideoThumbnails? thumbnails,
      final int likes,
      final int comments,
      final int views,
      final String caption,
      final bool isLiked,
      final bool isFavorited,
      final bool isDraft,
      final double mlScore,
      final String categoryId,
      final double? duration,
      final Timestamp? createdAt,
      final bool allowSave,
      final bool allowRemix,
      final String visibility,
      final String status,
      final bool isPinned,
      final List<String> tags,
      final List<String> playlistIds}) = _$HomeVideoImpl;

  @override
  String get id;
  @override
  User get creator;
  @override
  String get videoURL;
  @override
  String? get thumbnailURL;
  @override // Legacy field for backward compatibility
  VideoThumbnails? get thumbnails;
  @override // New multi-size thumbnail support
  int get likes;
  @override
  int get comments;
  @override
  int get views;
  @override
  String get caption;
  @override
  bool get isLiked;
  @override
  bool get isFavorited;
  @override
  bool get isDraft;
  @override
  double get mlScore;
  @override
  String get categoryId;
  @override
  double? get duration;
  @override // Video duration in seconds
  Timestamp? get createdAt;
  @override // For sorting by upload date
  bool get allowSave;
  @override // Can viewers save/download
  bool get allowRemix;
  @override // Can viewers remix/duet/stitch
  String get visibility;
  @override // public, followers, private
  String get status;
  @override // draft, processing, published, blocked, deleted
  bool get isPinned;
  @override // Pinned to profile
  List<String> get tags;
  @override // Video tags
  List<String> get playlistIds;
  @override
  @JsonKey(ignore: true)
  _$$HomeVideoImplCopyWith<_$HomeVideoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
