// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'home_video.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HomeVideo {
  String get id;
  User get creator;
  String get videoURL;
  String? get thumbnailURL; // Legacy field for backward compatibility
  VideoThumbnails? get thumbnails; // New multi-size thumbnail support
  int get likes;
  int get comments;
  int get views;
  String get caption;
  String get overlayCaption;
  bool get isLiked;
  bool get isFavorited;
  bool get isDraft;
  double get mlScore;
  String get categoryId;
  double? get duration; // Video duration in seconds
  Timestamp? get createdAt; // For sorting by upload date
  bool get allowSave; // Can viewers save/download
  bool get allowRemix; // Can viewers remix/duet/stitch
  String get visibility; // public, followers, private
  String get status; // draft, processing, published, blocked, deleted
  bool get isDeleted;
  Timestamp? get deletedAt;
  bool get isPinned; // Pinned to profile
  List<String> get tags; // Video tags
  List<String> get playlistIds;

  /// Create a copy of HomeVideo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HomeVideoCopyWith<HomeVideo> get copyWith =>
      _$HomeVideoCopyWithImpl<HomeVideo>(this as HomeVideo, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HomeVideo &&
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
            (identical(other.overlayCaption, overlayCaption) ||
                other.overlayCaption == overlayCaption) &&
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
            (identical(other.isDeleted, isDeleted) ||
                other.isDeleted == isDeleted) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt) &&
            (identical(other.isPinned, isPinned) ||
                other.isPinned == isPinned) &&
            const DeepCollectionEquality().equals(other.tags, tags) &&
            const DeepCollectionEquality()
                .equals(other.playlistIds, playlistIds));
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
        overlayCaption,
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
        isDeleted,
        deletedAt,
        isPinned,
        const DeepCollectionEquality().hash(tags),
        const DeepCollectionEquality().hash(playlistIds)
      ]);

  @override
  String toString() {
    return 'HomeVideo(id: $id, creator: $creator, videoURL: $videoURL, thumbnailURL: $thumbnailURL, thumbnails: $thumbnails, likes: $likes, comments: $comments, views: $views, caption: $caption, overlayCaption: $overlayCaption, isLiked: $isLiked, isFavorited: $isFavorited, isDraft: $isDraft, mlScore: $mlScore, categoryId: $categoryId, duration: $duration, createdAt: $createdAt, allowSave: $allowSave, allowRemix: $allowRemix, visibility: $visibility, status: $status, isDeleted: $isDeleted, deletedAt: $deletedAt, isPinned: $isPinned, tags: $tags, playlistIds: $playlistIds)';
  }
}

/// @nodoc
abstract mixin class $HomeVideoCopyWith<$Res> {
  factory $HomeVideoCopyWith(HomeVideo value, $Res Function(HomeVideo) _then) =
      _$HomeVideoCopyWithImpl;
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
      String overlayCaption,
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
      bool isDeleted,
      Timestamp? deletedAt,
      bool isPinned,
      List<String> tags,
      List<String> playlistIds});

  $VideoThumbnailsCopyWith<$Res>? get thumbnails;
}

/// @nodoc
class _$HomeVideoCopyWithImpl<$Res> implements $HomeVideoCopyWith<$Res> {
  _$HomeVideoCopyWithImpl(this._self, this._then);

  final HomeVideo _self;
  final $Res Function(HomeVideo) _then;

  /// Create a copy of HomeVideo
  /// with the given fields replaced by the non-null parameter values.
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
    Object? overlayCaption = null,
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
    Object? isDeleted = null,
    Object? deletedAt = freezed,
    Object? isPinned = null,
    Object? tags = null,
    Object? playlistIds = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      creator: null == creator
          ? _self.creator
          : creator // ignore: cast_nullable_to_non_nullable
              as User,
      videoURL: null == videoURL
          ? _self.videoURL
          : videoURL // ignore: cast_nullable_to_non_nullable
              as String,
      thumbnailURL: freezed == thumbnailURL
          ? _self.thumbnailURL
          : thumbnailURL // ignore: cast_nullable_to_non_nullable
              as String?,
      thumbnails: freezed == thumbnails
          ? _self.thumbnails
          : thumbnails // ignore: cast_nullable_to_non_nullable
              as VideoThumbnails?,
      likes: null == likes
          ? _self.likes
          : likes // ignore: cast_nullable_to_non_nullable
              as int,
      comments: null == comments
          ? _self.comments
          : comments // ignore: cast_nullable_to_non_nullable
              as int,
      views: null == views
          ? _self.views
          : views // ignore: cast_nullable_to_non_nullable
              as int,
      caption: null == caption
          ? _self.caption
          : caption // ignore: cast_nullable_to_non_nullable
              as String,
      overlayCaption: null == overlayCaption
          ? _self.overlayCaption
          : overlayCaption // ignore: cast_nullable_to_non_nullable
              as String,
      isLiked: null == isLiked
          ? _self.isLiked
          : isLiked // ignore: cast_nullable_to_non_nullable
              as bool,
      isFavorited: null == isFavorited
          ? _self.isFavorited
          : isFavorited // ignore: cast_nullable_to_non_nullable
              as bool,
      isDraft: null == isDraft
          ? _self.isDraft
          : isDraft // ignore: cast_nullable_to_non_nullable
              as bool,
      mlScore: null == mlScore
          ? _self.mlScore
          : mlScore // ignore: cast_nullable_to_non_nullable
              as double,
      categoryId: null == categoryId
          ? _self.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String,
      duration: freezed == duration
          ? _self.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as double?,
      createdAt: freezed == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as Timestamp?,
      allowSave: null == allowSave
          ? _self.allowSave
          : allowSave // ignore: cast_nullable_to_non_nullable
              as bool,
      allowRemix: null == allowRemix
          ? _self.allowRemix
          : allowRemix // ignore: cast_nullable_to_non_nullable
              as bool,
      visibility: null == visibility
          ? _self.visibility
          : visibility // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      isDeleted: null == isDeleted
          ? _self.isDeleted
          : isDeleted // ignore: cast_nullable_to_non_nullable
              as bool,
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as Timestamp?,
      isPinned: null == isPinned
          ? _self.isPinned
          : isPinned // ignore: cast_nullable_to_non_nullable
              as bool,
      tags: null == tags
          ? _self.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      playlistIds: null == playlistIds
          ? _self.playlistIds
          : playlistIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }

  /// Create a copy of HomeVideo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $VideoThumbnailsCopyWith<$Res>? get thumbnails {
    if (_self.thumbnails == null) {
      return null;
    }

    return $VideoThumbnailsCopyWith<$Res>(_self.thumbnails!, (value) {
      return _then(_self.copyWith(thumbnails: value));
    });
  }
}

/// Adds pattern-matching-related methods to [HomeVideo].
extension HomeVideoPatterns on HomeVideo {
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
    TResult Function(_HomeVideo value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HomeVideo() when $default != null:
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
    TResult Function(_HomeVideo value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HomeVideo():
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
    TResult? Function(_HomeVideo value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HomeVideo() when $default != null:
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
            User creator,
            String videoURL,
            String? thumbnailURL,
            VideoThumbnails? thumbnails,
            int likes,
            int comments,
            int views,
            String caption,
            String overlayCaption,
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
            bool isDeleted,
            Timestamp? deletedAt,
            bool isPinned,
            List<String> tags,
            List<String> playlistIds)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HomeVideo() when $default != null:
        return $default(
            _that.id,
            _that.creator,
            _that.videoURL,
            _that.thumbnailURL,
            _that.thumbnails,
            _that.likes,
            _that.comments,
            _that.views,
            _that.caption,
            _that.overlayCaption,
            _that.isLiked,
            _that.isFavorited,
            _that.isDraft,
            _that.mlScore,
            _that.categoryId,
            _that.duration,
            _that.createdAt,
            _that.allowSave,
            _that.allowRemix,
            _that.visibility,
            _that.status,
            _that.isDeleted,
            _that.deletedAt,
            _that.isPinned,
            _that.tags,
            _that.playlistIds);
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
            User creator,
            String videoURL,
            String? thumbnailURL,
            VideoThumbnails? thumbnails,
            int likes,
            int comments,
            int views,
            String caption,
            String overlayCaption,
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
            bool isDeleted,
            Timestamp? deletedAt,
            bool isPinned,
            List<String> tags,
            List<String> playlistIds)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HomeVideo():
        return $default(
            _that.id,
            _that.creator,
            _that.videoURL,
            _that.thumbnailURL,
            _that.thumbnails,
            _that.likes,
            _that.comments,
            _that.views,
            _that.caption,
            _that.overlayCaption,
            _that.isLiked,
            _that.isFavorited,
            _that.isDraft,
            _that.mlScore,
            _that.categoryId,
            _that.duration,
            _that.createdAt,
            _that.allowSave,
            _that.allowRemix,
            _that.visibility,
            _that.status,
            _that.isDeleted,
            _that.deletedAt,
            _that.isPinned,
            _that.tags,
            _that.playlistIds);
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
            User creator,
            String videoURL,
            String? thumbnailURL,
            VideoThumbnails? thumbnails,
            int likes,
            int comments,
            int views,
            String caption,
            String overlayCaption,
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
            bool isDeleted,
            Timestamp? deletedAt,
            bool isPinned,
            List<String> tags,
            List<String> playlistIds)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HomeVideo() when $default != null:
        return $default(
            _that.id,
            _that.creator,
            _that.videoURL,
            _that.thumbnailURL,
            _that.thumbnails,
            _that.likes,
            _that.comments,
            _that.views,
            _that.caption,
            _that.overlayCaption,
            _that.isLiked,
            _that.isFavorited,
            _that.isDraft,
            _that.mlScore,
            _that.categoryId,
            _that.duration,
            _that.createdAt,
            _that.allowSave,
            _that.allowRemix,
            _that.visibility,
            _that.status,
            _that.isDeleted,
            _that.deletedAt,
            _that.isPinned,
            _that.tags,
            _that.playlistIds);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _HomeVideo implements HomeVideo {
  const _HomeVideo(
      {required this.id,
      required this.creator,
      required this.videoURL,
      this.thumbnailURL,
      this.thumbnails,
      this.likes = 0,
      this.comments = 0,
      this.views = 0,
      this.caption = '',
      this.overlayCaption = '',
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
      this.isDeleted = false,
      this.deletedAt,
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
  final String overlayCaption;
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
  final bool isDeleted;
  @override
  final Timestamp? deletedAt;
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

  /// Create a copy of HomeVideo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$HomeVideoCopyWith<_HomeVideo> get copyWith =>
      __$HomeVideoCopyWithImpl<_HomeVideo>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _HomeVideo &&
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
            (identical(other.overlayCaption, overlayCaption) ||
                other.overlayCaption == overlayCaption) &&
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
            (identical(other.isDeleted, isDeleted) ||
                other.isDeleted == isDeleted) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt) &&
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
        overlayCaption,
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
        isDeleted,
        deletedAt,
        isPinned,
        const DeepCollectionEquality().hash(_tags),
        const DeepCollectionEquality().hash(_playlistIds)
      ]);

  @override
  String toString() {
    return 'HomeVideo(id: $id, creator: $creator, videoURL: $videoURL, thumbnailURL: $thumbnailURL, thumbnails: $thumbnails, likes: $likes, comments: $comments, views: $views, caption: $caption, overlayCaption: $overlayCaption, isLiked: $isLiked, isFavorited: $isFavorited, isDraft: $isDraft, mlScore: $mlScore, categoryId: $categoryId, duration: $duration, createdAt: $createdAt, allowSave: $allowSave, allowRemix: $allowRemix, visibility: $visibility, status: $status, isDeleted: $isDeleted, deletedAt: $deletedAt, isPinned: $isPinned, tags: $tags, playlistIds: $playlistIds)';
  }
}

/// @nodoc
abstract mixin class _$HomeVideoCopyWith<$Res>
    implements $HomeVideoCopyWith<$Res> {
  factory _$HomeVideoCopyWith(
          _HomeVideo value, $Res Function(_HomeVideo) _then) =
      __$HomeVideoCopyWithImpl;
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
      String overlayCaption,
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
      bool isDeleted,
      Timestamp? deletedAt,
      bool isPinned,
      List<String> tags,
      List<String> playlistIds});

  @override
  $VideoThumbnailsCopyWith<$Res>? get thumbnails;
}

/// @nodoc
class __$HomeVideoCopyWithImpl<$Res> implements _$HomeVideoCopyWith<$Res> {
  __$HomeVideoCopyWithImpl(this._self, this._then);

  final _HomeVideo _self;
  final $Res Function(_HomeVideo) _then;

  /// Create a copy of HomeVideo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
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
    Object? overlayCaption = null,
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
    Object? isDeleted = null,
    Object? deletedAt = freezed,
    Object? isPinned = null,
    Object? tags = null,
    Object? playlistIds = null,
  }) {
    return _then(_HomeVideo(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      creator: null == creator
          ? _self.creator
          : creator // ignore: cast_nullable_to_non_nullable
              as User,
      videoURL: null == videoURL
          ? _self.videoURL
          : videoURL // ignore: cast_nullable_to_non_nullable
              as String,
      thumbnailURL: freezed == thumbnailURL
          ? _self.thumbnailURL
          : thumbnailURL // ignore: cast_nullable_to_non_nullable
              as String?,
      thumbnails: freezed == thumbnails
          ? _self.thumbnails
          : thumbnails // ignore: cast_nullable_to_non_nullable
              as VideoThumbnails?,
      likes: null == likes
          ? _self.likes
          : likes // ignore: cast_nullable_to_non_nullable
              as int,
      comments: null == comments
          ? _self.comments
          : comments // ignore: cast_nullable_to_non_nullable
              as int,
      views: null == views
          ? _self.views
          : views // ignore: cast_nullable_to_non_nullable
              as int,
      caption: null == caption
          ? _self.caption
          : caption // ignore: cast_nullable_to_non_nullable
              as String,
      overlayCaption: null == overlayCaption
          ? _self.overlayCaption
          : overlayCaption // ignore: cast_nullable_to_non_nullable
              as String,
      isLiked: null == isLiked
          ? _self.isLiked
          : isLiked // ignore: cast_nullable_to_non_nullable
              as bool,
      isFavorited: null == isFavorited
          ? _self.isFavorited
          : isFavorited // ignore: cast_nullable_to_non_nullable
              as bool,
      isDraft: null == isDraft
          ? _self.isDraft
          : isDraft // ignore: cast_nullable_to_non_nullable
              as bool,
      mlScore: null == mlScore
          ? _self.mlScore
          : mlScore // ignore: cast_nullable_to_non_nullable
              as double,
      categoryId: null == categoryId
          ? _self.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String,
      duration: freezed == duration
          ? _self.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as double?,
      createdAt: freezed == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as Timestamp?,
      allowSave: null == allowSave
          ? _self.allowSave
          : allowSave // ignore: cast_nullable_to_non_nullable
              as bool,
      allowRemix: null == allowRemix
          ? _self.allowRemix
          : allowRemix // ignore: cast_nullable_to_non_nullable
              as bool,
      visibility: null == visibility
          ? _self.visibility
          : visibility // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      isDeleted: null == isDeleted
          ? _self.isDeleted
          : isDeleted // ignore: cast_nullable_to_non_nullable
              as bool,
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as Timestamp?,
      isPinned: null == isPinned
          ? _self.isPinned
          : isPinned // ignore: cast_nullable_to_non_nullable
              as bool,
      tags: null == tags
          ? _self._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      playlistIds: null == playlistIds
          ? _self._playlistIds
          : playlistIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }

  /// Create a copy of HomeVideo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $VideoThumbnailsCopyWith<$Res>? get thumbnails {
    if (_self.thumbnails == null) {
      return null;
    }

    return $VideoThumbnailsCopyWith<$Res>(_self.thumbnails!, (value) {
      return _then(_self.copyWith(thumbnails: value));
    });
  }
}

// dart format on
