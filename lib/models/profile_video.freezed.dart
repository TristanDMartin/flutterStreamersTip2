// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile_video.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProfileVideo {
  String get id;
  User get creator;
  String get videoURL;
  String? get thumbnailURL;
  double get duration; // Duration in seconds
  String get caption;
  DateTime get createdAt; // When the video was posted
  int get likes;
  int get comments;
  int get views;
  int get shares;
  bool get isLiked;
  bool get isFavorited;
  bool get isDraft;
  double get mlScore;
  String get categoryId;

  /// Create a copy of ProfileVideo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ProfileVideoCopyWith<ProfileVideo> get copyWith =>
      _$ProfileVideoCopyWithImpl<ProfileVideo>(
          this as ProfileVideo, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ProfileVideo &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.creator, creator) || other.creator == creator) &&
            (identical(other.videoURL, videoURL) ||
                other.videoURL == videoURL) &&
            (identical(other.thumbnailURL, thumbnailURL) ||
                other.thumbnailURL == thumbnailURL) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.caption, caption) || other.caption == caption) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.likes, likes) || other.likes == likes) &&
            (identical(other.comments, comments) ||
                other.comments == comments) &&
            (identical(other.views, views) || other.views == views) &&
            (identical(other.shares, shares) || other.shares == shares) &&
            (identical(other.isLiked, isLiked) || other.isLiked == isLiked) &&
            (identical(other.isFavorited, isFavorited) ||
                other.isFavorited == isFavorited) &&
            (identical(other.isDraft, isDraft) || other.isDraft == isDraft) &&
            (identical(other.mlScore, mlScore) || other.mlScore == mlScore) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      creator,
      videoURL,
      thumbnailURL,
      duration,
      caption,
      createdAt,
      likes,
      comments,
      views,
      shares,
      isLiked,
      isFavorited,
      isDraft,
      mlScore,
      categoryId);

  @override
  String toString() {
    return 'ProfileVideo(id: $id, creator: $creator, videoURL: $videoURL, thumbnailURL: $thumbnailURL, duration: $duration, caption: $caption, createdAt: $createdAt, likes: $likes, comments: $comments, views: $views, shares: $shares, isLiked: $isLiked, isFavorited: $isFavorited, isDraft: $isDraft, mlScore: $mlScore, categoryId: $categoryId)';
  }
}

/// @nodoc
abstract mixin class $ProfileVideoCopyWith<$Res> {
  factory $ProfileVideoCopyWith(
          ProfileVideo value, $Res Function(ProfileVideo) _then) =
      _$ProfileVideoCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      User creator,
      String videoURL,
      String? thumbnailURL,
      double duration,
      String caption,
      DateTime createdAt,
      int likes,
      int comments,
      int views,
      int shares,
      bool isLiked,
      bool isFavorited,
      bool isDraft,
      double mlScore,
      String categoryId});
}

/// @nodoc
class _$ProfileVideoCopyWithImpl<$Res> implements $ProfileVideoCopyWith<$Res> {
  _$ProfileVideoCopyWithImpl(this._self, this._then);

  final ProfileVideo _self;
  final $Res Function(ProfileVideo) _then;

  /// Create a copy of ProfileVideo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? creator = null,
    Object? videoURL = null,
    Object? thumbnailURL = freezed,
    Object? duration = null,
    Object? caption = null,
    Object? createdAt = null,
    Object? likes = null,
    Object? comments = null,
    Object? views = null,
    Object? shares = null,
    Object? isLiked = null,
    Object? isFavorited = null,
    Object? isDraft = null,
    Object? mlScore = null,
    Object? categoryId = null,
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
      duration: null == duration
          ? _self.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as double,
      caption: null == caption
          ? _self.caption
          : caption // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
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
      shares: null == shares
          ? _self.shares
          : shares // ignore: cast_nullable_to_non_nullable
              as int,
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
    ));
  }
}

/// Adds pattern-matching-related methods to [ProfileVideo].
extension ProfileVideoPatterns on ProfileVideo {
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
    TResult Function(_ProfileVideo value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ProfileVideo() when $default != null:
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
    TResult Function(_ProfileVideo value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProfileVideo():
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
    TResult? Function(_ProfileVideo value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProfileVideo() when $default != null:
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
            double duration,
            String caption,
            DateTime createdAt,
            int likes,
            int comments,
            int views,
            int shares,
            bool isLiked,
            bool isFavorited,
            bool isDraft,
            double mlScore,
            String categoryId)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ProfileVideo() when $default != null:
        return $default(
            _that.id,
            _that.creator,
            _that.videoURL,
            _that.thumbnailURL,
            _that.duration,
            _that.caption,
            _that.createdAt,
            _that.likes,
            _that.comments,
            _that.views,
            _that.shares,
            _that.isLiked,
            _that.isFavorited,
            _that.isDraft,
            _that.mlScore,
            _that.categoryId);
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
            double duration,
            String caption,
            DateTime createdAt,
            int likes,
            int comments,
            int views,
            int shares,
            bool isLiked,
            bool isFavorited,
            bool isDraft,
            double mlScore,
            String categoryId)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProfileVideo():
        return $default(
            _that.id,
            _that.creator,
            _that.videoURL,
            _that.thumbnailURL,
            _that.duration,
            _that.caption,
            _that.createdAt,
            _that.likes,
            _that.comments,
            _that.views,
            _that.shares,
            _that.isLiked,
            _that.isFavorited,
            _that.isDraft,
            _that.mlScore,
            _that.categoryId);
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
            double duration,
            String caption,
            DateTime createdAt,
            int likes,
            int comments,
            int views,
            int shares,
            bool isLiked,
            bool isFavorited,
            bool isDraft,
            double mlScore,
            String categoryId)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProfileVideo() when $default != null:
        return $default(
            _that.id,
            _that.creator,
            _that.videoURL,
            _that.thumbnailURL,
            _that.duration,
            _that.caption,
            _that.createdAt,
            _that.likes,
            _that.comments,
            _that.views,
            _that.shares,
            _that.isLiked,
            _that.isFavorited,
            _that.isDraft,
            _that.mlScore,
            _that.categoryId);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ProfileVideo implements ProfileVideo {
  const _ProfileVideo(
      {required this.id,
      required this.creator,
      required this.videoURL,
      this.thumbnailURL,
      this.duration = 0.0,
      this.caption = '',
      required this.createdAt,
      this.likes = 0,
      this.comments = 0,
      this.views = 0,
      this.shares = 0,
      this.isLiked = false,
      this.isFavorited = false,
      this.isDraft = false,
      this.mlScore = 0.0,
      this.categoryId = ''});

  @override
  final String id;
  @override
  final User creator;
  @override
  final String videoURL;
  @override
  final String? thumbnailURL;
  @override
  @JsonKey()
  final double duration;
// Duration in seconds
  @override
  @JsonKey()
  final String caption;
  @override
  final DateTime createdAt;
// When the video was posted
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
  final int shares;
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

  /// Create a copy of ProfileVideo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ProfileVideoCopyWith<_ProfileVideo> get copyWith =>
      __$ProfileVideoCopyWithImpl<_ProfileVideo>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ProfileVideo &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.creator, creator) || other.creator == creator) &&
            (identical(other.videoURL, videoURL) ||
                other.videoURL == videoURL) &&
            (identical(other.thumbnailURL, thumbnailURL) ||
                other.thumbnailURL == thumbnailURL) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.caption, caption) || other.caption == caption) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.likes, likes) || other.likes == likes) &&
            (identical(other.comments, comments) ||
                other.comments == comments) &&
            (identical(other.views, views) || other.views == views) &&
            (identical(other.shares, shares) || other.shares == shares) &&
            (identical(other.isLiked, isLiked) || other.isLiked == isLiked) &&
            (identical(other.isFavorited, isFavorited) ||
                other.isFavorited == isFavorited) &&
            (identical(other.isDraft, isDraft) || other.isDraft == isDraft) &&
            (identical(other.mlScore, mlScore) || other.mlScore == mlScore) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      creator,
      videoURL,
      thumbnailURL,
      duration,
      caption,
      createdAt,
      likes,
      comments,
      views,
      shares,
      isLiked,
      isFavorited,
      isDraft,
      mlScore,
      categoryId);

  @override
  String toString() {
    return 'ProfileVideo(id: $id, creator: $creator, videoURL: $videoURL, thumbnailURL: $thumbnailURL, duration: $duration, caption: $caption, createdAt: $createdAt, likes: $likes, comments: $comments, views: $views, shares: $shares, isLiked: $isLiked, isFavorited: $isFavorited, isDraft: $isDraft, mlScore: $mlScore, categoryId: $categoryId)';
  }
}

/// @nodoc
abstract mixin class _$ProfileVideoCopyWith<$Res>
    implements $ProfileVideoCopyWith<$Res> {
  factory _$ProfileVideoCopyWith(
          _ProfileVideo value, $Res Function(_ProfileVideo) _then) =
      __$ProfileVideoCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      User creator,
      String videoURL,
      String? thumbnailURL,
      double duration,
      String caption,
      DateTime createdAt,
      int likes,
      int comments,
      int views,
      int shares,
      bool isLiked,
      bool isFavorited,
      bool isDraft,
      double mlScore,
      String categoryId});
}

/// @nodoc
class __$ProfileVideoCopyWithImpl<$Res>
    implements _$ProfileVideoCopyWith<$Res> {
  __$ProfileVideoCopyWithImpl(this._self, this._then);

  final _ProfileVideo _self;
  final $Res Function(_ProfileVideo) _then;

  /// Create a copy of ProfileVideo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? creator = null,
    Object? videoURL = null,
    Object? thumbnailURL = freezed,
    Object? duration = null,
    Object? caption = null,
    Object? createdAt = null,
    Object? likes = null,
    Object? comments = null,
    Object? views = null,
    Object? shares = null,
    Object? isLiked = null,
    Object? isFavorited = null,
    Object? isDraft = null,
    Object? mlScore = null,
    Object? categoryId = null,
  }) {
    return _then(_ProfileVideo(
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
      duration: null == duration
          ? _self.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as double,
      caption: null == caption
          ? _self.caption
          : caption // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
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
      shares: null == shares
          ? _self.shares
          : shares // ignore: cast_nullable_to_non_nullable
              as int,
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
    ));
  }
}

// dart format on
