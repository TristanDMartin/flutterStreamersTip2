// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scheduled_post.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ScheduledPost {
  String get id;
  String get authorId;
  PostStatus get status;
  String get caption;
  List<String> get tags;
  PostVisibility get visibility;
  List<PostMedia> get media;
  List<PlatformConfig> get platforms;
  PostSchedule? get schedule;
  Map<String, dynamic> get analyticsHints;
  String? get idempotencyKey;
  DateTime get createdAt;
  DateTime get updatedAt;

  /// Create a copy of ScheduledPost
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ScheduledPostCopyWith<ScheduledPost> get copyWith =>
      _$ScheduledPostCopyWithImpl<ScheduledPost>(
          this as ScheduledPost, _$identity);

  /// Serializes this ScheduledPost to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ScheduledPost &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.authorId, authorId) ||
                other.authorId == authorId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.caption, caption) || other.caption == caption) &&
            const DeepCollectionEquality().equals(other.tags, tags) &&
            (identical(other.visibility, visibility) ||
                other.visibility == visibility) &&
            const DeepCollectionEquality().equals(other.media, media) &&
            const DeepCollectionEquality().equals(other.platforms, platforms) &&
            (identical(other.schedule, schedule) ||
                other.schedule == schedule) &&
            const DeepCollectionEquality()
                .equals(other.analyticsHints, analyticsHints) &&
            (identical(other.idempotencyKey, idempotencyKey) ||
                other.idempotencyKey == idempotencyKey) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      authorId,
      status,
      caption,
      const DeepCollectionEquality().hash(tags),
      visibility,
      const DeepCollectionEquality().hash(media),
      const DeepCollectionEquality().hash(platforms),
      schedule,
      const DeepCollectionEquality().hash(analyticsHints),
      idempotencyKey,
      createdAt,
      updatedAt);

  @override
  String toString() {
    return 'ScheduledPost(id: $id, authorId: $authorId, status: $status, caption: $caption, tags: $tags, visibility: $visibility, media: $media, platforms: $platforms, schedule: $schedule, analyticsHints: $analyticsHints, idempotencyKey: $idempotencyKey, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}

/// @nodoc
abstract mixin class $ScheduledPostCopyWith<$Res> {
  factory $ScheduledPostCopyWith(
          ScheduledPost value, $Res Function(ScheduledPost) _then) =
      _$ScheduledPostCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String authorId,
      PostStatus status,
      String caption,
      List<String> tags,
      PostVisibility visibility,
      List<PostMedia> media,
      List<PlatformConfig> platforms,
      PostSchedule? schedule,
      Map<String, dynamic> analyticsHints,
      String? idempotencyKey,
      DateTime createdAt,
      DateTime updatedAt});

  $PostScheduleCopyWith<$Res>? get schedule;
}

/// @nodoc
class _$ScheduledPostCopyWithImpl<$Res>
    implements $ScheduledPostCopyWith<$Res> {
  _$ScheduledPostCopyWithImpl(this._self, this._then);

  final ScheduledPost _self;
  final $Res Function(ScheduledPost) _then;

  /// Create a copy of ScheduledPost
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? authorId = null,
    Object? status = null,
    Object? caption = null,
    Object? tags = null,
    Object? visibility = null,
    Object? media = null,
    Object? platforms = null,
    Object? schedule = freezed,
    Object? analyticsHints = null,
    Object? idempotencyKey = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      authorId: null == authorId
          ? _self.authorId
          : authorId // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as PostStatus,
      caption: null == caption
          ? _self.caption
          : caption // ignore: cast_nullable_to_non_nullable
              as String,
      tags: null == tags
          ? _self.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      visibility: null == visibility
          ? _self.visibility
          : visibility // ignore: cast_nullable_to_non_nullable
              as PostVisibility,
      media: null == media
          ? _self.media
          : media // ignore: cast_nullable_to_non_nullable
              as List<PostMedia>,
      platforms: null == platforms
          ? _self.platforms
          : platforms // ignore: cast_nullable_to_non_nullable
              as List<PlatformConfig>,
      schedule: freezed == schedule
          ? _self.schedule
          : schedule // ignore: cast_nullable_to_non_nullable
              as PostSchedule?,
      analyticsHints: null == analyticsHints
          ? _self.analyticsHints
          : analyticsHints // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      idempotencyKey: freezed == idempotencyKey
          ? _self.idempotencyKey
          : idempotencyKey // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }

  /// Create a copy of ScheduledPost
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PostScheduleCopyWith<$Res>? get schedule {
    if (_self.schedule == null) {
      return null;
    }

    return $PostScheduleCopyWith<$Res>(_self.schedule!, (value) {
      return _then(_self.copyWith(schedule: value));
    });
  }
}

/// Adds pattern-matching-related methods to [ScheduledPost].
extension ScheduledPostPatterns on ScheduledPost {
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
    TResult Function(_ScheduledPost value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ScheduledPost() when $default != null:
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
    TResult Function(_ScheduledPost value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ScheduledPost():
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
    TResult? Function(_ScheduledPost value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ScheduledPost() when $default != null:
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
            String authorId,
            PostStatus status,
            String caption,
            List<String> tags,
            PostVisibility visibility,
            List<PostMedia> media,
            List<PlatformConfig> platforms,
            PostSchedule? schedule,
            Map<String, dynamic> analyticsHints,
            String? idempotencyKey,
            DateTime createdAt,
            DateTime updatedAt)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ScheduledPost() when $default != null:
        return $default(
            _that.id,
            _that.authorId,
            _that.status,
            _that.caption,
            _that.tags,
            _that.visibility,
            _that.media,
            _that.platforms,
            _that.schedule,
            _that.analyticsHints,
            _that.idempotencyKey,
            _that.createdAt,
            _that.updatedAt);
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
            String authorId,
            PostStatus status,
            String caption,
            List<String> tags,
            PostVisibility visibility,
            List<PostMedia> media,
            List<PlatformConfig> platforms,
            PostSchedule? schedule,
            Map<String, dynamic> analyticsHints,
            String? idempotencyKey,
            DateTime createdAt,
            DateTime updatedAt)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ScheduledPost():
        return $default(
            _that.id,
            _that.authorId,
            _that.status,
            _that.caption,
            _that.tags,
            _that.visibility,
            _that.media,
            _that.platforms,
            _that.schedule,
            _that.analyticsHints,
            _that.idempotencyKey,
            _that.createdAt,
            _that.updatedAt);
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
            String authorId,
            PostStatus status,
            String caption,
            List<String> tags,
            PostVisibility visibility,
            List<PostMedia> media,
            List<PlatformConfig> platforms,
            PostSchedule? schedule,
            Map<String, dynamic> analyticsHints,
            String? idempotencyKey,
            DateTime createdAt,
            DateTime updatedAt)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ScheduledPost() when $default != null:
        return $default(
            _that.id,
            _that.authorId,
            _that.status,
            _that.caption,
            _that.tags,
            _that.visibility,
            _that.media,
            _that.platforms,
            _that.schedule,
            _that.analyticsHints,
            _that.idempotencyKey,
            _that.createdAt,
            _that.updatedAt);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ScheduledPost implements ScheduledPost {
  const _ScheduledPost(
      {required this.id,
      required this.authorId,
      required this.status,
      required this.caption,
      final List<String> tags = const [],
      this.visibility = PostVisibility.public,
      final List<PostMedia> media = const [],
      final List<PlatformConfig> platforms = const [],
      this.schedule,
      final Map<String, dynamic> analyticsHints = const {},
      this.idempotencyKey,
      required this.createdAt,
      required this.updatedAt})
      : _tags = tags,
        _media = media,
        _platforms = platforms,
        _analyticsHints = analyticsHints;
  factory _ScheduledPost.fromJson(Map<String, dynamic> json) =>
      _$ScheduledPostFromJson(json);

  @override
  final String id;
  @override
  final String authorId;
  @override
  final PostStatus status;
  @override
  final String caption;
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
  final PostVisibility visibility;
  final List<PostMedia> _media;
  @override
  @JsonKey()
  List<PostMedia> get media {
    if (_media is EqualUnmodifiableListView) return _media;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_media);
  }

  final List<PlatformConfig> _platforms;
  @override
  @JsonKey()
  List<PlatformConfig> get platforms {
    if (_platforms is EqualUnmodifiableListView) return _platforms;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_platforms);
  }

  @override
  final PostSchedule? schedule;
  final Map<String, dynamic> _analyticsHints;
  @override
  @JsonKey()
  Map<String, dynamic> get analyticsHints {
    if (_analyticsHints is EqualUnmodifiableMapView) return _analyticsHints;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_analyticsHints);
  }

  @override
  final String? idempotencyKey;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  /// Create a copy of ScheduledPost
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ScheduledPostCopyWith<_ScheduledPost> get copyWith =>
      __$ScheduledPostCopyWithImpl<_ScheduledPost>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ScheduledPostToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ScheduledPost &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.authorId, authorId) ||
                other.authorId == authorId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.caption, caption) || other.caption == caption) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.visibility, visibility) ||
                other.visibility == visibility) &&
            const DeepCollectionEquality().equals(other._media, _media) &&
            const DeepCollectionEquality()
                .equals(other._platforms, _platforms) &&
            (identical(other.schedule, schedule) ||
                other.schedule == schedule) &&
            const DeepCollectionEquality()
                .equals(other._analyticsHints, _analyticsHints) &&
            (identical(other.idempotencyKey, idempotencyKey) ||
                other.idempotencyKey == idempotencyKey) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      authorId,
      status,
      caption,
      const DeepCollectionEquality().hash(_tags),
      visibility,
      const DeepCollectionEquality().hash(_media),
      const DeepCollectionEquality().hash(_platforms),
      schedule,
      const DeepCollectionEquality().hash(_analyticsHints),
      idempotencyKey,
      createdAt,
      updatedAt);

  @override
  String toString() {
    return 'ScheduledPost(id: $id, authorId: $authorId, status: $status, caption: $caption, tags: $tags, visibility: $visibility, media: $media, platforms: $platforms, schedule: $schedule, analyticsHints: $analyticsHints, idempotencyKey: $idempotencyKey, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}

/// @nodoc
abstract mixin class _$ScheduledPostCopyWith<$Res>
    implements $ScheduledPostCopyWith<$Res> {
  factory _$ScheduledPostCopyWith(
          _ScheduledPost value, $Res Function(_ScheduledPost) _then) =
      __$ScheduledPostCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String authorId,
      PostStatus status,
      String caption,
      List<String> tags,
      PostVisibility visibility,
      List<PostMedia> media,
      List<PlatformConfig> platforms,
      PostSchedule? schedule,
      Map<String, dynamic> analyticsHints,
      String? idempotencyKey,
      DateTime createdAt,
      DateTime updatedAt});

  @override
  $PostScheduleCopyWith<$Res>? get schedule;
}

/// @nodoc
class __$ScheduledPostCopyWithImpl<$Res>
    implements _$ScheduledPostCopyWith<$Res> {
  __$ScheduledPostCopyWithImpl(this._self, this._then);

  final _ScheduledPost _self;
  final $Res Function(_ScheduledPost) _then;

  /// Create a copy of ScheduledPost
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? authorId = null,
    Object? status = null,
    Object? caption = null,
    Object? tags = null,
    Object? visibility = null,
    Object? media = null,
    Object? platforms = null,
    Object? schedule = freezed,
    Object? analyticsHints = null,
    Object? idempotencyKey = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_ScheduledPost(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      authorId: null == authorId
          ? _self.authorId
          : authorId // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as PostStatus,
      caption: null == caption
          ? _self.caption
          : caption // ignore: cast_nullable_to_non_nullable
              as String,
      tags: null == tags
          ? _self._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      visibility: null == visibility
          ? _self.visibility
          : visibility // ignore: cast_nullable_to_non_nullable
              as PostVisibility,
      media: null == media
          ? _self._media
          : media // ignore: cast_nullable_to_non_nullable
              as List<PostMedia>,
      platforms: null == platforms
          ? _self._platforms
          : platforms // ignore: cast_nullable_to_non_nullable
              as List<PlatformConfig>,
      schedule: freezed == schedule
          ? _self.schedule
          : schedule // ignore: cast_nullable_to_non_nullable
              as PostSchedule?,
      analyticsHints: null == analyticsHints
          ? _self._analyticsHints
          : analyticsHints // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      idempotencyKey: freezed == idempotencyKey
          ? _self.idempotencyKey
          : idempotencyKey // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }

  /// Create a copy of ScheduledPost
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PostScheduleCopyWith<$Res>? get schedule {
    if (_self.schedule == null) {
      return null;
    }

    return $PostScheduleCopyWith<$Res>(_self.schedule!, (value) {
      return _then(_self.copyWith(schedule: value));
    });
  }
}

/// @nodoc
mixin _$PostMedia {
  String get id;
  MediaType get type;
  String get src;
  double get aspectRatio;
  int? get durationMs;
  List<MediaVariant> get variants;

  /// Create a copy of PostMedia
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PostMediaCopyWith<PostMedia> get copyWith =>
      _$PostMediaCopyWithImpl<PostMedia>(this as PostMedia, _$identity);

  /// Serializes this PostMedia to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PostMedia &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.src, src) || other.src == src) &&
            (identical(other.aspectRatio, aspectRatio) ||
                other.aspectRatio == aspectRatio) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            const DeepCollectionEquality().equals(other.variants, variants));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, type, src, aspectRatio,
      durationMs, const DeepCollectionEquality().hash(variants));

  @override
  String toString() {
    return 'PostMedia(id: $id, type: $type, src: $src, aspectRatio: $aspectRatio, durationMs: $durationMs, variants: $variants)';
  }
}

/// @nodoc
abstract mixin class $PostMediaCopyWith<$Res> {
  factory $PostMediaCopyWith(PostMedia value, $Res Function(PostMedia) _then) =
      _$PostMediaCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      MediaType type,
      String src,
      double aspectRatio,
      int? durationMs,
      List<MediaVariant> variants});
}

/// @nodoc
class _$PostMediaCopyWithImpl<$Res> implements $PostMediaCopyWith<$Res> {
  _$PostMediaCopyWithImpl(this._self, this._then);

  final PostMedia _self;
  final $Res Function(PostMedia) _then;

  /// Create a copy of PostMedia
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? src = null,
    Object? aspectRatio = null,
    Object? durationMs = freezed,
    Object? variants = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as MediaType,
      src: null == src
          ? _self.src
          : src // ignore: cast_nullable_to_non_nullable
              as String,
      aspectRatio: null == aspectRatio
          ? _self.aspectRatio
          : aspectRatio // ignore: cast_nullable_to_non_nullable
              as double,
      durationMs: freezed == durationMs
          ? _self.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int?,
      variants: null == variants
          ? _self.variants
          : variants // ignore: cast_nullable_to_non_nullable
              as List<MediaVariant>,
    ));
  }
}

/// Adds pattern-matching-related methods to [PostMedia].
extension PostMediaPatterns on PostMedia {
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
    TResult Function(_PostMedia value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PostMedia() when $default != null:
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
    TResult Function(_PostMedia value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PostMedia():
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
    TResult? Function(_PostMedia value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PostMedia() when $default != null:
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
    TResult Function(String id, MediaType type, String src, double aspectRatio,
            int? durationMs, List<MediaVariant> variants)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PostMedia() when $default != null:
        return $default(_that.id, _that.type, _that.src, _that.aspectRatio,
            _that.durationMs, _that.variants);
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
    TResult Function(String id, MediaType type, String src, double aspectRatio,
            int? durationMs, List<MediaVariant> variants)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PostMedia():
        return $default(_that.id, _that.type, _that.src, _that.aspectRatio,
            _that.durationMs, _that.variants);
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
    TResult? Function(String id, MediaType type, String src, double aspectRatio,
            int? durationMs, List<MediaVariant> variants)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PostMedia() when $default != null:
        return $default(_that.id, _that.type, _that.src, _that.aspectRatio,
            _that.durationMs, _that.variants);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PostMedia implements PostMedia {
  const _PostMedia(
      {required this.id,
      required this.type,
      required this.src,
      required this.aspectRatio,
      this.durationMs,
      final List<MediaVariant> variants = const []})
      : _variants = variants;
  factory _PostMedia.fromJson(Map<String, dynamic> json) =>
      _$PostMediaFromJson(json);

  @override
  final String id;
  @override
  final MediaType type;
  @override
  final String src;
  @override
  final double aspectRatio;
  @override
  final int? durationMs;
  final List<MediaVariant> _variants;
  @override
  @JsonKey()
  List<MediaVariant> get variants {
    if (_variants is EqualUnmodifiableListView) return _variants;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_variants);
  }

  /// Create a copy of PostMedia
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PostMediaCopyWith<_PostMedia> get copyWith =>
      __$PostMediaCopyWithImpl<_PostMedia>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PostMediaToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PostMedia &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.src, src) || other.src == src) &&
            (identical(other.aspectRatio, aspectRatio) ||
                other.aspectRatio == aspectRatio) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            const DeepCollectionEquality().equals(other._variants, _variants));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, type, src, aspectRatio,
      durationMs, const DeepCollectionEquality().hash(_variants));

  @override
  String toString() {
    return 'PostMedia(id: $id, type: $type, src: $src, aspectRatio: $aspectRatio, durationMs: $durationMs, variants: $variants)';
  }
}

/// @nodoc
abstract mixin class _$PostMediaCopyWith<$Res>
    implements $PostMediaCopyWith<$Res> {
  factory _$PostMediaCopyWith(
          _PostMedia value, $Res Function(_PostMedia) _then) =
      __$PostMediaCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      MediaType type,
      String src,
      double aspectRatio,
      int? durationMs,
      List<MediaVariant> variants});
}

/// @nodoc
class __$PostMediaCopyWithImpl<$Res> implements _$PostMediaCopyWith<$Res> {
  __$PostMediaCopyWithImpl(this._self, this._then);

  final _PostMedia _self;
  final $Res Function(_PostMedia) _then;

  /// Create a copy of PostMedia
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? src = null,
    Object? aspectRatio = null,
    Object? durationMs = freezed,
    Object? variants = null,
  }) {
    return _then(_PostMedia(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as MediaType,
      src: null == src
          ? _self.src
          : src // ignore: cast_nullable_to_non_nullable
              as String,
      aspectRatio: null == aspectRatio
          ? _self.aspectRatio
          : aspectRatio // ignore: cast_nullable_to_non_nullable
              as double,
      durationMs: freezed == durationMs
          ? _self.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int?,
      variants: null == variants
          ? _self._variants
          : variants // ignore: cast_nullable_to_non_nullable
              as List<MediaVariant>,
    ));
  }
}

/// @nodoc
mixin _$MediaVariant {
  String get platform;
  String get src;
  double get aspectRatio;
  int? get durationMs;
  Map<String, dynamic>? get metadata;

  /// Create a copy of MediaVariant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MediaVariantCopyWith<MediaVariant> get copyWith =>
      _$MediaVariantCopyWithImpl<MediaVariant>(
          this as MediaVariant, _$identity);

  /// Serializes this MediaVariant to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MediaVariant &&
            (identical(other.platform, platform) ||
                other.platform == platform) &&
            (identical(other.src, src) || other.src == src) &&
            (identical(other.aspectRatio, aspectRatio) ||
                other.aspectRatio == aspectRatio) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            const DeepCollectionEquality().equals(other.metadata, metadata));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, platform, src, aspectRatio,
      durationMs, const DeepCollectionEquality().hash(metadata));

  @override
  String toString() {
    return 'MediaVariant(platform: $platform, src: $src, aspectRatio: $aspectRatio, durationMs: $durationMs, metadata: $metadata)';
  }
}

/// @nodoc
abstract mixin class $MediaVariantCopyWith<$Res> {
  factory $MediaVariantCopyWith(
          MediaVariant value, $Res Function(MediaVariant) _then) =
      _$MediaVariantCopyWithImpl;
  @useResult
  $Res call(
      {String platform,
      String src,
      double aspectRatio,
      int? durationMs,
      Map<String, dynamic>? metadata});
}

/// @nodoc
class _$MediaVariantCopyWithImpl<$Res> implements $MediaVariantCopyWith<$Res> {
  _$MediaVariantCopyWithImpl(this._self, this._then);

  final MediaVariant _self;
  final $Res Function(MediaVariant) _then;

  /// Create a copy of MediaVariant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? platform = null,
    Object? src = null,
    Object? aspectRatio = null,
    Object? durationMs = freezed,
    Object? metadata = freezed,
  }) {
    return _then(_self.copyWith(
      platform: null == platform
          ? _self.platform
          : platform // ignore: cast_nullable_to_non_nullable
              as String,
      src: null == src
          ? _self.src
          : src // ignore: cast_nullable_to_non_nullable
              as String,
      aspectRatio: null == aspectRatio
          ? _self.aspectRatio
          : aspectRatio // ignore: cast_nullable_to_non_nullable
              as double,
      durationMs: freezed == durationMs
          ? _self.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int?,
      metadata: freezed == metadata
          ? _self.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// Adds pattern-matching-related methods to [MediaVariant].
extension MediaVariantPatterns on MediaVariant {
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
    TResult Function(_MediaVariant value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MediaVariant() when $default != null:
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
    TResult Function(_MediaVariant value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MediaVariant():
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
    TResult? Function(_MediaVariant value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MediaVariant() when $default != null:
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
    TResult Function(String platform, String src, double aspectRatio,
            int? durationMs, Map<String, dynamic>? metadata)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MediaVariant() when $default != null:
        return $default(_that.platform, _that.src, _that.aspectRatio,
            _that.durationMs, _that.metadata);
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
    TResult Function(String platform, String src, double aspectRatio,
            int? durationMs, Map<String, dynamic>? metadata)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MediaVariant():
        return $default(_that.platform, _that.src, _that.aspectRatio,
            _that.durationMs, _that.metadata);
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
    TResult? Function(String platform, String src, double aspectRatio,
            int? durationMs, Map<String, dynamic>? metadata)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MediaVariant() when $default != null:
        return $default(_that.platform, _that.src, _that.aspectRatio,
            _that.durationMs, _that.metadata);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _MediaVariant implements MediaVariant {
  const _MediaVariant(
      {required this.platform,
      required this.src,
      required this.aspectRatio,
      this.durationMs,
      final Map<String, dynamic>? metadata})
      : _metadata = metadata;
  factory _MediaVariant.fromJson(Map<String, dynamic> json) =>
      _$MediaVariantFromJson(json);

  @override
  final String platform;
  @override
  final String src;
  @override
  final double aspectRatio;
  @override
  final int? durationMs;
  final Map<String, dynamic>? _metadata;
  @override
  Map<String, dynamic>? get metadata {
    final value = _metadata;
    if (value == null) return null;
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  /// Create a copy of MediaVariant
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MediaVariantCopyWith<_MediaVariant> get copyWith =>
      __$MediaVariantCopyWithImpl<_MediaVariant>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$MediaVariantToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _MediaVariant &&
            (identical(other.platform, platform) ||
                other.platform == platform) &&
            (identical(other.src, src) || other.src == src) &&
            (identical(other.aspectRatio, aspectRatio) ||
                other.aspectRatio == aspectRatio) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, platform, src, aspectRatio,
      durationMs, const DeepCollectionEquality().hash(_metadata));

  @override
  String toString() {
    return 'MediaVariant(platform: $platform, src: $src, aspectRatio: $aspectRatio, durationMs: $durationMs, metadata: $metadata)';
  }
}

/// @nodoc
abstract mixin class _$MediaVariantCopyWith<$Res>
    implements $MediaVariantCopyWith<$Res> {
  factory _$MediaVariantCopyWith(
          _MediaVariant value, $Res Function(_MediaVariant) _then) =
      __$MediaVariantCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String platform,
      String src,
      double aspectRatio,
      int? durationMs,
      Map<String, dynamic>? metadata});
}

/// @nodoc
class __$MediaVariantCopyWithImpl<$Res>
    implements _$MediaVariantCopyWith<$Res> {
  __$MediaVariantCopyWithImpl(this._self, this._then);

  final _MediaVariant _self;
  final $Res Function(_MediaVariant) _then;

  /// Create a copy of MediaVariant
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? platform = null,
    Object? src = null,
    Object? aspectRatio = null,
    Object? durationMs = freezed,
    Object? metadata = freezed,
  }) {
    return _then(_MediaVariant(
      platform: null == platform
          ? _self.platform
          : platform // ignore: cast_nullable_to_non_nullable
              as String,
      src: null == src
          ? _self.src
          : src // ignore: cast_nullable_to_non_nullable
              as String,
      aspectRatio: null == aspectRatio
          ? _self.aspectRatio
          : aspectRatio // ignore: cast_nullable_to_non_nullable
              as double,
      durationMs: freezed == durationMs
          ? _self.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int?,
      metadata: freezed == metadata
          ? _self._metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
mixin _$PlatformConfig {
  String get key;
  bool get enabled;
  Map<String, dynamic>? get payload;
  PlatformStatus? get status;
  String? get error;
  DateTime? get scheduledAtUtc;

  /// Create a copy of PlatformConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PlatformConfigCopyWith<PlatformConfig> get copyWith =>
      _$PlatformConfigCopyWithImpl<PlatformConfig>(
          this as PlatformConfig, _$identity);

  /// Serializes this PlatformConfig to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PlatformConfig &&
            (identical(other.key, key) || other.key == key) &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            const DeepCollectionEquality().equals(other.payload, payload) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.scheduledAtUtc, scheduledAtUtc) ||
                other.scheduledAtUtc == scheduledAtUtc));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      key,
      enabled,
      const DeepCollectionEquality().hash(payload),
      status,
      error,
      scheduledAtUtc);

  @override
  String toString() {
    return 'PlatformConfig(key: $key, enabled: $enabled, payload: $payload, status: $status, error: $error, scheduledAtUtc: $scheduledAtUtc)';
  }
}

/// @nodoc
abstract mixin class $PlatformConfigCopyWith<$Res> {
  factory $PlatformConfigCopyWith(
          PlatformConfig value, $Res Function(PlatformConfig) _then) =
      _$PlatformConfigCopyWithImpl;
  @useResult
  $Res call(
      {String key,
      bool enabled,
      Map<String, dynamic>? payload,
      PlatformStatus? status,
      String? error,
      DateTime? scheduledAtUtc});
}

/// @nodoc
class _$PlatformConfigCopyWithImpl<$Res>
    implements $PlatformConfigCopyWith<$Res> {
  _$PlatformConfigCopyWithImpl(this._self, this._then);

  final PlatformConfig _self;
  final $Res Function(PlatformConfig) _then;

  /// Create a copy of PlatformConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? key = null,
    Object? enabled = null,
    Object? payload = freezed,
    Object? status = freezed,
    Object? error = freezed,
    Object? scheduledAtUtc = freezed,
  }) {
    return _then(_self.copyWith(
      key: null == key
          ? _self.key
          : key // ignore: cast_nullable_to_non_nullable
              as String,
      enabled: null == enabled
          ? _self.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      payload: freezed == payload
          ? _self.payload
          : payload // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      status: freezed == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as PlatformStatus?,
      error: freezed == error
          ? _self.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      scheduledAtUtc: freezed == scheduledAtUtc
          ? _self.scheduledAtUtc
          : scheduledAtUtc // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// Adds pattern-matching-related methods to [PlatformConfig].
extension PlatformConfigPatterns on PlatformConfig {
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
    TResult Function(_PlatformConfig value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PlatformConfig() when $default != null:
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
    TResult Function(_PlatformConfig value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PlatformConfig():
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
    TResult? Function(_PlatformConfig value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PlatformConfig() when $default != null:
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
    TResult Function(String key, bool enabled, Map<String, dynamic>? payload,
            PlatformStatus? status, String? error, DateTime? scheduledAtUtc)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PlatformConfig() when $default != null:
        return $default(_that.key, _that.enabled, _that.payload, _that.status,
            _that.error, _that.scheduledAtUtc);
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
    TResult Function(String key, bool enabled, Map<String, dynamic>? payload,
            PlatformStatus? status, String? error, DateTime? scheduledAtUtc)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PlatformConfig():
        return $default(_that.key, _that.enabled, _that.payload, _that.status,
            _that.error, _that.scheduledAtUtc);
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
    TResult? Function(String key, bool enabled, Map<String, dynamic>? payload,
            PlatformStatus? status, String? error, DateTime? scheduledAtUtc)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PlatformConfig() when $default != null:
        return $default(_that.key, _that.enabled, _that.payload, _that.status,
            _that.error, _that.scheduledAtUtc);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PlatformConfig implements PlatformConfig {
  const _PlatformConfig(
      {required this.key,
      required this.enabled,
      final Map<String, dynamic>? payload,
      this.status,
      this.error,
      this.scheduledAtUtc})
      : _payload = payload;
  factory _PlatformConfig.fromJson(Map<String, dynamic> json) =>
      _$PlatformConfigFromJson(json);

  @override
  final String key;
  @override
  final bool enabled;
  final Map<String, dynamic>? _payload;
  @override
  Map<String, dynamic>? get payload {
    final value = _payload;
    if (value == null) return null;
    if (_payload is EqualUnmodifiableMapView) return _payload;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final PlatformStatus? status;
  @override
  final String? error;
  @override
  final DateTime? scheduledAtUtc;

  /// Create a copy of PlatformConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PlatformConfigCopyWith<_PlatformConfig> get copyWith =>
      __$PlatformConfigCopyWithImpl<_PlatformConfig>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PlatformConfigToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PlatformConfig &&
            (identical(other.key, key) || other.key == key) &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            const DeepCollectionEquality().equals(other._payload, _payload) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.scheduledAtUtc, scheduledAtUtc) ||
                other.scheduledAtUtc == scheduledAtUtc));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      key,
      enabled,
      const DeepCollectionEquality().hash(_payload),
      status,
      error,
      scheduledAtUtc);

  @override
  String toString() {
    return 'PlatformConfig(key: $key, enabled: $enabled, payload: $payload, status: $status, error: $error, scheduledAtUtc: $scheduledAtUtc)';
  }
}

/// @nodoc
abstract mixin class _$PlatformConfigCopyWith<$Res>
    implements $PlatformConfigCopyWith<$Res> {
  factory _$PlatformConfigCopyWith(
          _PlatformConfig value, $Res Function(_PlatformConfig) _then) =
      __$PlatformConfigCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String key,
      bool enabled,
      Map<String, dynamic>? payload,
      PlatformStatus? status,
      String? error,
      DateTime? scheduledAtUtc});
}

/// @nodoc
class __$PlatformConfigCopyWithImpl<$Res>
    implements _$PlatformConfigCopyWith<$Res> {
  __$PlatformConfigCopyWithImpl(this._self, this._then);

  final _PlatformConfig _self;
  final $Res Function(_PlatformConfig) _then;

  /// Create a copy of PlatformConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? key = null,
    Object? enabled = null,
    Object? payload = freezed,
    Object? status = freezed,
    Object? error = freezed,
    Object? scheduledAtUtc = freezed,
  }) {
    return _then(_PlatformConfig(
      key: null == key
          ? _self.key
          : key // ignore: cast_nullable_to_non_nullable
              as String,
      enabled: null == enabled
          ? _self.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      payload: freezed == payload
          ? _self._payload
          : payload // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      status: freezed == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as PlatformStatus?,
      error: freezed == error
          ? _self.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      scheduledAtUtc: freezed == scheduledAtUtc
          ? _self.scheduledAtUtc
          : scheduledAtUtc // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
mixin _$PostSchedule {
  DateTime get scheduledAtUtc;
  String get timezone;
  Map<String, PlatformSchedule> get perPlatform;
  DateTime get createdAtUtc;
  DateTime get updatedAtUtc;

  /// Create a copy of PostSchedule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PostScheduleCopyWith<PostSchedule> get copyWith =>
      _$PostScheduleCopyWithImpl<PostSchedule>(
          this as PostSchedule, _$identity);

  /// Serializes this PostSchedule to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PostSchedule &&
            (identical(other.scheduledAtUtc, scheduledAtUtc) ||
                other.scheduledAtUtc == scheduledAtUtc) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
            const DeepCollectionEquality()
                .equals(other.perPlatform, perPlatform) &&
            (identical(other.createdAtUtc, createdAtUtc) ||
                other.createdAtUtc == createdAtUtc) &&
            (identical(other.updatedAtUtc, updatedAtUtc) ||
                other.updatedAtUtc == updatedAtUtc));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      scheduledAtUtc,
      timezone,
      const DeepCollectionEquality().hash(perPlatform),
      createdAtUtc,
      updatedAtUtc);

  @override
  String toString() {
    return 'PostSchedule(scheduledAtUtc: $scheduledAtUtc, timezone: $timezone, perPlatform: $perPlatform, createdAtUtc: $createdAtUtc, updatedAtUtc: $updatedAtUtc)';
  }
}

/// @nodoc
abstract mixin class $PostScheduleCopyWith<$Res> {
  factory $PostScheduleCopyWith(
          PostSchedule value, $Res Function(PostSchedule) _then) =
      _$PostScheduleCopyWithImpl;
  @useResult
  $Res call(
      {DateTime scheduledAtUtc,
      String timezone,
      Map<String, PlatformSchedule> perPlatform,
      DateTime createdAtUtc,
      DateTime updatedAtUtc});
}

/// @nodoc
class _$PostScheduleCopyWithImpl<$Res> implements $PostScheduleCopyWith<$Res> {
  _$PostScheduleCopyWithImpl(this._self, this._then);

  final PostSchedule _self;
  final $Res Function(PostSchedule) _then;

  /// Create a copy of PostSchedule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? scheduledAtUtc = null,
    Object? timezone = null,
    Object? perPlatform = null,
    Object? createdAtUtc = null,
    Object? updatedAtUtc = null,
  }) {
    return _then(_self.copyWith(
      scheduledAtUtc: null == scheduledAtUtc
          ? _self.scheduledAtUtc
          : scheduledAtUtc // ignore: cast_nullable_to_non_nullable
              as DateTime,
      timezone: null == timezone
          ? _self.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String,
      perPlatform: null == perPlatform
          ? _self.perPlatform
          : perPlatform // ignore: cast_nullable_to_non_nullable
              as Map<String, PlatformSchedule>,
      createdAtUtc: null == createdAtUtc
          ? _self.createdAtUtc
          : createdAtUtc // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAtUtc: null == updatedAtUtc
          ? _self.updatedAtUtc
          : updatedAtUtc // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// Adds pattern-matching-related methods to [PostSchedule].
extension PostSchedulePatterns on PostSchedule {
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
    TResult Function(_PostSchedule value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PostSchedule() when $default != null:
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
    TResult Function(_PostSchedule value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PostSchedule():
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
    TResult? Function(_PostSchedule value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PostSchedule() when $default != null:
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
            DateTime scheduledAtUtc,
            String timezone,
            Map<String, PlatformSchedule> perPlatform,
            DateTime createdAtUtc,
            DateTime updatedAtUtc)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PostSchedule() when $default != null:
        return $default(_that.scheduledAtUtc, _that.timezone, _that.perPlatform,
            _that.createdAtUtc, _that.updatedAtUtc);
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
            DateTime scheduledAtUtc,
            String timezone,
            Map<String, PlatformSchedule> perPlatform,
            DateTime createdAtUtc,
            DateTime updatedAtUtc)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PostSchedule():
        return $default(_that.scheduledAtUtc, _that.timezone, _that.perPlatform,
            _that.createdAtUtc, _that.updatedAtUtc);
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
            DateTime scheduledAtUtc,
            String timezone,
            Map<String, PlatformSchedule> perPlatform,
            DateTime createdAtUtc,
            DateTime updatedAtUtc)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PostSchedule() when $default != null:
        return $default(_that.scheduledAtUtc, _that.timezone, _that.perPlatform,
            _that.createdAtUtc, _that.updatedAtUtc);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PostSchedule implements PostSchedule {
  const _PostSchedule(
      {required this.scheduledAtUtc,
      required this.timezone,
      final Map<String, PlatformSchedule> perPlatform = const {},
      required this.createdAtUtc,
      required this.updatedAtUtc})
      : _perPlatform = perPlatform;
  factory _PostSchedule.fromJson(Map<String, dynamic> json) =>
      _$PostScheduleFromJson(json);

  @override
  final DateTime scheduledAtUtc;
  @override
  final String timezone;
  final Map<String, PlatformSchedule> _perPlatform;
  @override
  @JsonKey()
  Map<String, PlatformSchedule> get perPlatform {
    if (_perPlatform is EqualUnmodifiableMapView) return _perPlatform;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_perPlatform);
  }

  @override
  final DateTime createdAtUtc;
  @override
  final DateTime updatedAtUtc;

  /// Create a copy of PostSchedule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PostScheduleCopyWith<_PostSchedule> get copyWith =>
      __$PostScheduleCopyWithImpl<_PostSchedule>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PostScheduleToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PostSchedule &&
            (identical(other.scheduledAtUtc, scheduledAtUtc) ||
                other.scheduledAtUtc == scheduledAtUtc) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
            const DeepCollectionEquality()
                .equals(other._perPlatform, _perPlatform) &&
            (identical(other.createdAtUtc, createdAtUtc) ||
                other.createdAtUtc == createdAtUtc) &&
            (identical(other.updatedAtUtc, updatedAtUtc) ||
                other.updatedAtUtc == updatedAtUtc));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      scheduledAtUtc,
      timezone,
      const DeepCollectionEquality().hash(_perPlatform),
      createdAtUtc,
      updatedAtUtc);

  @override
  String toString() {
    return 'PostSchedule(scheduledAtUtc: $scheduledAtUtc, timezone: $timezone, perPlatform: $perPlatform, createdAtUtc: $createdAtUtc, updatedAtUtc: $updatedAtUtc)';
  }
}

/// @nodoc
abstract mixin class _$PostScheduleCopyWith<$Res>
    implements $PostScheduleCopyWith<$Res> {
  factory _$PostScheduleCopyWith(
          _PostSchedule value, $Res Function(_PostSchedule) _then) =
      __$PostScheduleCopyWithImpl;
  @override
  @useResult
  $Res call(
      {DateTime scheduledAtUtc,
      String timezone,
      Map<String, PlatformSchedule> perPlatform,
      DateTime createdAtUtc,
      DateTime updatedAtUtc});
}

/// @nodoc
class __$PostScheduleCopyWithImpl<$Res>
    implements _$PostScheduleCopyWith<$Res> {
  __$PostScheduleCopyWithImpl(this._self, this._then);

  final _PostSchedule _self;
  final $Res Function(_PostSchedule) _then;

  /// Create a copy of PostSchedule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? scheduledAtUtc = null,
    Object? timezone = null,
    Object? perPlatform = null,
    Object? createdAtUtc = null,
    Object? updatedAtUtc = null,
  }) {
    return _then(_PostSchedule(
      scheduledAtUtc: null == scheduledAtUtc
          ? _self.scheduledAtUtc
          : scheduledAtUtc // ignore: cast_nullable_to_non_nullable
              as DateTime,
      timezone: null == timezone
          ? _self.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String,
      perPlatform: null == perPlatform
          ? _self._perPlatform
          : perPlatform // ignore: cast_nullable_to_non_nullable
              as Map<String, PlatformSchedule>,
      createdAtUtc: null == createdAtUtc
          ? _self.createdAtUtc
          : createdAtUtc // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAtUtc: null == updatedAtUtc
          ? _self.updatedAtUtc
          : updatedAtUtc // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
mixin _$PlatformSchedule {
  DateTime get scheduledAtUtc;
  String? get timezone;

  /// Create a copy of PlatformSchedule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PlatformScheduleCopyWith<PlatformSchedule> get copyWith =>
      _$PlatformScheduleCopyWithImpl<PlatformSchedule>(
          this as PlatformSchedule, _$identity);

  /// Serializes this PlatformSchedule to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PlatformSchedule &&
            (identical(other.scheduledAtUtc, scheduledAtUtc) ||
                other.scheduledAtUtc == scheduledAtUtc) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, scheduledAtUtc, timezone);

  @override
  String toString() {
    return 'PlatformSchedule(scheduledAtUtc: $scheduledAtUtc, timezone: $timezone)';
  }
}

/// @nodoc
abstract mixin class $PlatformScheduleCopyWith<$Res> {
  factory $PlatformScheduleCopyWith(
          PlatformSchedule value, $Res Function(PlatformSchedule) _then) =
      _$PlatformScheduleCopyWithImpl;
  @useResult
  $Res call({DateTime scheduledAtUtc, String? timezone});
}

/// @nodoc
class _$PlatformScheduleCopyWithImpl<$Res>
    implements $PlatformScheduleCopyWith<$Res> {
  _$PlatformScheduleCopyWithImpl(this._self, this._then);

  final PlatformSchedule _self;
  final $Res Function(PlatformSchedule) _then;

  /// Create a copy of PlatformSchedule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? scheduledAtUtc = null,
    Object? timezone = freezed,
  }) {
    return _then(_self.copyWith(
      scheduledAtUtc: null == scheduledAtUtc
          ? _self.scheduledAtUtc
          : scheduledAtUtc // ignore: cast_nullable_to_non_nullable
              as DateTime,
      timezone: freezed == timezone
          ? _self.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [PlatformSchedule].
extension PlatformSchedulePatterns on PlatformSchedule {
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
    TResult Function(_PlatformSchedule value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PlatformSchedule() when $default != null:
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
    TResult Function(_PlatformSchedule value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PlatformSchedule():
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
    TResult? Function(_PlatformSchedule value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PlatformSchedule() when $default != null:
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
    TResult Function(DateTime scheduledAtUtc, String? timezone)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PlatformSchedule() when $default != null:
        return $default(_that.scheduledAtUtc, _that.timezone);
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
    TResult Function(DateTime scheduledAtUtc, String? timezone) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PlatformSchedule():
        return $default(_that.scheduledAtUtc, _that.timezone);
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
    TResult? Function(DateTime scheduledAtUtc, String? timezone)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PlatformSchedule() when $default != null:
        return $default(_that.scheduledAtUtc, _that.timezone);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PlatformSchedule implements PlatformSchedule {
  const _PlatformSchedule({required this.scheduledAtUtc, this.timezone});
  factory _PlatformSchedule.fromJson(Map<String, dynamic> json) =>
      _$PlatformScheduleFromJson(json);

  @override
  final DateTime scheduledAtUtc;
  @override
  final String? timezone;

  /// Create a copy of PlatformSchedule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PlatformScheduleCopyWith<_PlatformSchedule> get copyWith =>
      __$PlatformScheduleCopyWithImpl<_PlatformSchedule>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PlatformScheduleToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PlatformSchedule &&
            (identical(other.scheduledAtUtc, scheduledAtUtc) ||
                other.scheduledAtUtc == scheduledAtUtc) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, scheduledAtUtc, timezone);

  @override
  String toString() {
    return 'PlatformSchedule(scheduledAtUtc: $scheduledAtUtc, timezone: $timezone)';
  }
}

/// @nodoc
abstract mixin class _$PlatformScheduleCopyWith<$Res>
    implements $PlatformScheduleCopyWith<$Res> {
  factory _$PlatformScheduleCopyWith(
          _PlatformSchedule value, $Res Function(_PlatformSchedule) _then) =
      __$PlatformScheduleCopyWithImpl;
  @override
  @useResult
  $Res call({DateTime scheduledAtUtc, String? timezone});
}

/// @nodoc
class __$PlatformScheduleCopyWithImpl<$Res>
    implements _$PlatformScheduleCopyWith<$Res> {
  __$PlatformScheduleCopyWithImpl(this._self, this._then);

  final _PlatformSchedule _self;
  final $Res Function(_PlatformSchedule) _then;

  /// Create a copy of PlatformSchedule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? scheduledAtUtc = null,
    Object? timezone = freezed,
  }) {
    return _then(_PlatformSchedule(
      scheduledAtUtc: null == scheduledAtUtc
          ? _self.scheduledAtUtc
          : scheduledAtUtc // ignore: cast_nullable_to_non_nullable
              as DateTime,
      timezone: freezed == timezone
          ? _self.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
