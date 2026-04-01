// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'video_clip.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VideoClip {
  String get id;
  String get title;
  String get videoURL;
  String? get thumbnailURL;
  int get views;
  int get likes;
  int get comments;
  String get categoryId;
  String get description;
  String get creator;
  double get duration;
  List<String> get tags;
  double get score;

  /// Create a copy of VideoClip
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $VideoClipCopyWith<VideoClip> get copyWith =>
      _$VideoClipCopyWithImpl<VideoClip>(this as VideoClip, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is VideoClip &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.videoURL, videoURL) ||
                other.videoURL == videoURL) &&
            (identical(other.thumbnailURL, thumbnailURL) ||
                other.thumbnailURL == thumbnailURL) &&
            (identical(other.views, views) || other.views == views) &&
            (identical(other.likes, likes) || other.likes == likes) &&
            (identical(other.comments, comments) ||
                other.comments == comments) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.creator, creator) || other.creator == creator) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            const DeepCollectionEquality().equals(other.tags, tags) &&
            (identical(other.score, score) || other.score == score));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      title,
      videoURL,
      thumbnailURL,
      views,
      likes,
      comments,
      categoryId,
      description,
      creator,
      duration,
      const DeepCollectionEquality().hash(tags),
      score);

  @override
  String toString() {
    return 'VideoClip(id: $id, title: $title, videoURL: $videoURL, thumbnailURL: $thumbnailURL, views: $views, likes: $likes, comments: $comments, categoryId: $categoryId, description: $description, creator: $creator, duration: $duration, tags: $tags, score: $score)';
  }
}

/// @nodoc
abstract mixin class $VideoClipCopyWith<$Res> {
  factory $VideoClipCopyWith(VideoClip value, $Res Function(VideoClip) _then) =
      _$VideoClipCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String title,
      String videoURL,
      String? thumbnailURL,
      int views,
      int likes,
      int comments,
      String categoryId,
      String description,
      String creator,
      double duration,
      List<String> tags,
      double score});
}

/// @nodoc
class _$VideoClipCopyWithImpl<$Res> implements $VideoClipCopyWith<$Res> {
  _$VideoClipCopyWithImpl(this._self, this._then);

  final VideoClip _self;
  final $Res Function(VideoClip) _then;

  /// Create a copy of VideoClip
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? videoURL = null,
    Object? thumbnailURL = freezed,
    Object? views = null,
    Object? likes = null,
    Object? comments = null,
    Object? categoryId = null,
    Object? description = null,
    Object? creator = null,
    Object? duration = null,
    Object? tags = null,
    Object? score = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      videoURL: null == videoURL
          ? _self.videoURL
          : videoURL // ignore: cast_nullable_to_non_nullable
              as String,
      thumbnailURL: freezed == thumbnailURL
          ? _self.thumbnailURL
          : thumbnailURL // ignore: cast_nullable_to_non_nullable
              as String?,
      views: null == views
          ? _self.views
          : views // ignore: cast_nullable_to_non_nullable
              as int,
      likes: null == likes
          ? _self.likes
          : likes // ignore: cast_nullable_to_non_nullable
              as int,
      comments: null == comments
          ? _self.comments
          : comments // ignore: cast_nullable_to_non_nullable
              as int,
      categoryId: null == categoryId
          ? _self.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      creator: null == creator
          ? _self.creator
          : creator // ignore: cast_nullable_to_non_nullable
              as String,
      duration: null == duration
          ? _self.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as double,
      tags: null == tags
          ? _self.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      score: null == score
          ? _self.score
          : score // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// Adds pattern-matching-related methods to [VideoClip].
extension VideoClipPatterns on VideoClip {
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
    TResult Function(_VideoClip value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _VideoClip() when $default != null:
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
    TResult Function(_VideoClip value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VideoClip():
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
    TResult? Function(_VideoClip value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VideoClip() when $default != null:
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
            String title,
            String videoURL,
            String? thumbnailURL,
            int views,
            int likes,
            int comments,
            String categoryId,
            String description,
            String creator,
            double duration,
            List<String> tags,
            double score)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _VideoClip() when $default != null:
        return $default(
            _that.id,
            _that.title,
            _that.videoURL,
            _that.thumbnailURL,
            _that.views,
            _that.likes,
            _that.comments,
            _that.categoryId,
            _that.description,
            _that.creator,
            _that.duration,
            _that.tags,
            _that.score);
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
            String title,
            String videoURL,
            String? thumbnailURL,
            int views,
            int likes,
            int comments,
            String categoryId,
            String description,
            String creator,
            double duration,
            List<String> tags,
            double score)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VideoClip():
        return $default(
            _that.id,
            _that.title,
            _that.videoURL,
            _that.thumbnailURL,
            _that.views,
            _that.likes,
            _that.comments,
            _that.categoryId,
            _that.description,
            _that.creator,
            _that.duration,
            _that.tags,
            _that.score);
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
            String title,
            String videoURL,
            String? thumbnailURL,
            int views,
            int likes,
            int comments,
            String categoryId,
            String description,
            String creator,
            double duration,
            List<String> tags,
            double score)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VideoClip() when $default != null:
        return $default(
            _that.id,
            _that.title,
            _that.videoURL,
            _that.thumbnailURL,
            _that.views,
            _that.likes,
            _that.comments,
            _that.categoryId,
            _that.description,
            _that.creator,
            _that.duration,
            _that.tags,
            _that.score);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _VideoClip implements VideoClip {
  const _VideoClip(
      {required this.id,
      required this.title,
      required this.videoURL,
      this.thumbnailURL,
      this.views = 0,
      this.likes = 0,
      this.comments = 0,
      this.categoryId = '',
      this.description = '',
      required this.creator,
      this.duration = 0.0,
      final List<String> tags = const [],
      this.score = 0.0})
      : _tags = tags;

  @override
  final String id;
  @override
  final String title;
  @override
  final String videoURL;
  @override
  final String? thumbnailURL;
  @override
  @JsonKey()
  final int views;
  @override
  @JsonKey()
  final int likes;
  @override
  @JsonKey()
  final int comments;
  @override
  @JsonKey()
  final String categoryId;
  @override
  @JsonKey()
  final String description;
  @override
  final String creator;
  @override
  @JsonKey()
  final double duration;
  final List<String> _tags;
  @override
  @JsonKey()
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  @override
  @JsonKey()
  final double score;

  /// Create a copy of VideoClip
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$VideoClipCopyWith<_VideoClip> get copyWith =>
      __$VideoClipCopyWithImpl<_VideoClip>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _VideoClip &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.videoURL, videoURL) ||
                other.videoURL == videoURL) &&
            (identical(other.thumbnailURL, thumbnailURL) ||
                other.thumbnailURL == thumbnailURL) &&
            (identical(other.views, views) || other.views == views) &&
            (identical(other.likes, likes) || other.likes == likes) &&
            (identical(other.comments, comments) ||
                other.comments == comments) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.creator, creator) || other.creator == creator) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.score, score) || other.score == score));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      title,
      videoURL,
      thumbnailURL,
      views,
      likes,
      comments,
      categoryId,
      description,
      creator,
      duration,
      const DeepCollectionEquality().hash(_tags),
      score);

  @override
  String toString() {
    return 'VideoClip(id: $id, title: $title, videoURL: $videoURL, thumbnailURL: $thumbnailURL, views: $views, likes: $likes, comments: $comments, categoryId: $categoryId, description: $description, creator: $creator, duration: $duration, tags: $tags, score: $score)';
  }
}

/// @nodoc
abstract mixin class _$VideoClipCopyWith<$Res>
    implements $VideoClipCopyWith<$Res> {
  factory _$VideoClipCopyWith(
          _VideoClip value, $Res Function(_VideoClip) _then) =
      __$VideoClipCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String videoURL,
      String? thumbnailURL,
      int views,
      int likes,
      int comments,
      String categoryId,
      String description,
      String creator,
      double duration,
      List<String> tags,
      double score});
}

/// @nodoc
class __$VideoClipCopyWithImpl<$Res> implements _$VideoClipCopyWith<$Res> {
  __$VideoClipCopyWithImpl(this._self, this._then);

  final _VideoClip _self;
  final $Res Function(_VideoClip) _then;

  /// Create a copy of VideoClip
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? videoURL = null,
    Object? thumbnailURL = freezed,
    Object? views = null,
    Object? likes = null,
    Object? comments = null,
    Object? categoryId = null,
    Object? description = null,
    Object? creator = null,
    Object? duration = null,
    Object? tags = null,
    Object? score = null,
  }) {
    return _then(_VideoClip(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      videoURL: null == videoURL
          ? _self.videoURL
          : videoURL // ignore: cast_nullable_to_non_nullable
              as String,
      thumbnailURL: freezed == thumbnailURL
          ? _self.thumbnailURL
          : thumbnailURL // ignore: cast_nullable_to_non_nullable
              as String?,
      views: null == views
          ? _self.views
          : views // ignore: cast_nullable_to_non_nullable
              as int,
      likes: null == likes
          ? _self.likes
          : likes // ignore: cast_nullable_to_non_nullable
              as int,
      comments: null == comments
          ? _self.comments
          : comments // ignore: cast_nullable_to_non_nullable
              as int,
      categoryId: null == categoryId
          ? _self.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      creator: null == creator
          ? _self.creator
          : creator // ignore: cast_nullable_to_non_nullable
              as String,
      duration: null == duration
          ? _self.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as double,
      tags: null == tags
          ? _self._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      score: null == score
          ? _self.score
          : score // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

// dart format on
