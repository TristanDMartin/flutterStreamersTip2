// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scheduled_post.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ScheduledPost _$ScheduledPostFromJson(Map<String, dynamic> json) {
  return _ScheduledPost.fromJson(json);
}

/// @nodoc
mixin _$ScheduledPost {
  String get id => throw _privateConstructorUsedError;
  String get authorId => throw _privateConstructorUsedError;
  PostStatus get status => throw _privateConstructorUsedError;
  String get caption => throw _privateConstructorUsedError;
  List<String> get tags => throw _privateConstructorUsedError;
  PostVisibility get visibility => throw _privateConstructorUsedError;
  List<PostMedia> get media => throw _privateConstructorUsedError;
  List<PlatformConfig> get platforms => throw _privateConstructorUsedError;
  PostSchedule get schedule => throw _privateConstructorUsedError;
  Map<String, dynamic> get analyticsHints => throw _privateConstructorUsedError;
  String? get idempotencyKey => throw _privateConstructorUsedError;
  DateTime? get createdAtUtc => throw _privateConstructorUsedError;
  DateTime? get updatedAtUtc => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ScheduledPostCopyWith<ScheduledPost> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ScheduledPostCopyWith<$Res> {
  factory $ScheduledPostCopyWith(
          ScheduledPost value, $Res Function(ScheduledPost) then) =
      _$ScheduledPostCopyWithImpl<$Res, ScheduledPost>;
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
      PostSchedule schedule,
      Map<String, dynamic> analyticsHints,
      String? idempotencyKey,
      DateTime? createdAtUtc,
      DateTime? updatedAtUtc});

  $PostScheduleCopyWith<$Res> get schedule;
}

/// @nodoc
class _$ScheduledPostCopyWithImpl<$Res, $Val extends ScheduledPost>
    implements $ScheduledPostCopyWith<$Res> {
  _$ScheduledPostCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

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
    Object? schedule = null,
    Object? analyticsHints = null,
    Object? idempotencyKey = freezed,
    Object? createdAtUtc = freezed,
    Object? updatedAtUtc = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      authorId: null == authorId
          ? _value.authorId
          : authorId // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as PostStatus,
      caption: null == caption
          ? _value.caption
          : caption // ignore: cast_nullable_to_non_nullable
              as String,
      tags: null == tags
          ? _value.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      visibility: null == visibility
          ? _value.visibility
          : visibility // ignore: cast_nullable_to_non_nullable
              as PostVisibility,
      media: null == media
          ? _value.media
          : media // ignore: cast_nullable_to_non_nullable
              as List<PostMedia>,
      platforms: null == platforms
          ? _value.platforms
          : platforms // ignore: cast_nullable_to_non_nullable
              as List<PlatformConfig>,
      schedule: null == schedule
          ? _value.schedule
          : schedule // ignore: cast_nullable_to_non_nullable
              as PostSchedule,
      analyticsHints: null == analyticsHints
          ? _value.analyticsHints
          : analyticsHints // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      idempotencyKey: freezed == idempotencyKey
          ? _value.idempotencyKey
          : idempotencyKey // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAtUtc: freezed == createdAtUtc
          ? _value.createdAtUtc
          : createdAtUtc // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAtUtc: freezed == updatedAtUtc
          ? _value.updatedAtUtc
          : updatedAtUtc // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $PostScheduleCopyWith<$Res> get schedule {
    return $PostScheduleCopyWith<$Res>(_value.schedule, (value) {
      return _then(_value.copyWith(schedule: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ScheduledPostImplCopyWith<$Res>
    implements $ScheduledPostCopyWith<$Res> {
  factory _$$ScheduledPostImplCopyWith(
          _$ScheduledPostImpl value, $Res Function(_$ScheduledPostImpl) then) =
      __$$ScheduledPostImplCopyWithImpl<$Res>;
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
      PostSchedule schedule,
      Map<String, dynamic> analyticsHints,
      String? idempotencyKey,
      DateTime? createdAtUtc,
      DateTime? updatedAtUtc});

  @override
  $PostScheduleCopyWith<$Res> get schedule;
}

/// @nodoc
class __$$ScheduledPostImplCopyWithImpl<$Res>
    extends _$ScheduledPostCopyWithImpl<$Res, _$ScheduledPostImpl>
    implements _$$ScheduledPostImplCopyWith<$Res> {
  __$$ScheduledPostImplCopyWithImpl(
      _$ScheduledPostImpl _value, $Res Function(_$ScheduledPostImpl) _then)
      : super(_value, _then);

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
    Object? schedule = null,
    Object? analyticsHints = null,
    Object? idempotencyKey = freezed,
    Object? createdAtUtc = freezed,
    Object? updatedAtUtc = freezed,
  }) {
    return _then(_$ScheduledPostImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      authorId: null == authorId
          ? _value.authorId
          : authorId // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as PostStatus,
      caption: null == caption
          ? _value.caption
          : caption // ignore: cast_nullable_to_non_nullable
              as String,
      tags: null == tags
          ? _value._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      visibility: null == visibility
          ? _value.visibility
          : visibility // ignore: cast_nullable_to_non_nullable
              as PostVisibility,
      media: null == media
          ? _value._media
          : media // ignore: cast_nullable_to_non_nullable
              as List<PostMedia>,
      platforms: null == platforms
          ? _value._platforms
          : platforms // ignore: cast_nullable_to_non_nullable
              as List<PlatformConfig>,
      schedule: null == schedule
          ? _value.schedule
          : schedule // ignore: cast_nullable_to_non_nullable
              as PostSchedule,
      analyticsHints: null == analyticsHints
          ? _value._analyticsHints
          : analyticsHints // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      idempotencyKey: freezed == idempotencyKey
          ? _value.idempotencyKey
          : idempotencyKey // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAtUtc: freezed == createdAtUtc
          ? _value.createdAtUtc
          : createdAtUtc // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAtUtc: freezed == updatedAtUtc
          ? _value.updatedAtUtc
          : updatedAtUtc // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ScheduledPostImpl implements _ScheduledPost {
  const _$ScheduledPostImpl(
      {required this.id,
      required this.authorId,
      required this.status,
      required this.caption,
      final List<String> tags = const [],
      this.visibility = PostVisibility.public,
      final List<PostMedia> media = const [],
      final List<PlatformConfig> platforms = const [],
      required this.schedule,
      final Map<String, dynamic> analyticsHints = const {},
      this.idempotencyKey,
      this.createdAtUtc,
      this.updatedAtUtc})
      : _tags = tags,
        _media = media,
        _platforms = platforms,
        _analyticsHints = analyticsHints;

  factory _$ScheduledPostImpl.fromJson(Map<String, dynamic> json) =>
      _$$ScheduledPostImplFromJson(json);

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
  final PostSchedule schedule;
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
  final DateTime? createdAtUtc;
  @override
  final DateTime? updatedAtUtc;

  @override
  String toString() {
    return 'ScheduledPost(id: $id, authorId: $authorId, status: $status, caption: $caption, tags: $tags, visibility: $visibility, media: $media, platforms: $platforms, schedule: $schedule, analyticsHints: $analyticsHints, idempotencyKey: $idempotencyKey, createdAtUtc: $createdAtUtc, updatedAtUtc: $updatedAtUtc)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ScheduledPostImpl &&
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
            (identical(other.createdAtUtc, createdAtUtc) ||
                other.createdAtUtc == createdAtUtc) &&
            (identical(other.updatedAtUtc, updatedAtUtc) ||
                other.updatedAtUtc == updatedAtUtc));
  }

  @JsonKey(ignore: true)
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
      createdAtUtc,
      updatedAtUtc);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ScheduledPostImplCopyWith<_$ScheduledPostImpl> get copyWith =>
      __$$ScheduledPostImplCopyWithImpl<_$ScheduledPostImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ScheduledPostImplToJson(
      this,
    );
  }
}

abstract class _ScheduledPost implements ScheduledPost {
  const factory _ScheduledPost(
      {required final String id,
      required final String authorId,
      required final PostStatus status,
      required final String caption,
      final List<String> tags,
      final PostVisibility visibility,
      final List<PostMedia> media,
      final List<PlatformConfig> platforms,
      required final PostSchedule schedule,
      final Map<String, dynamic> analyticsHints,
      final String? idempotencyKey,
      final DateTime? createdAtUtc,
      final DateTime? updatedAtUtc}) = _$ScheduledPostImpl;

  factory _ScheduledPost.fromJson(Map<String, dynamic> json) =
      _$ScheduledPostImpl.fromJson;

  @override
  String get id;
  @override
  String get authorId;
  @override
  PostStatus get status;
  @override
  String get caption;
  @override
  List<String> get tags;
  @override
  PostVisibility get visibility;
  @override
  List<PostMedia> get media;
  @override
  List<PlatformConfig> get platforms;
  @override
  PostSchedule get schedule;
  @override
  Map<String, dynamic> get analyticsHints;
  @override
  String? get idempotencyKey;
  @override
  DateTime? get createdAtUtc;
  @override
  DateTime? get updatedAtUtc;
  @override
  @JsonKey(ignore: true)
  _$$ScheduledPostImplCopyWith<_$ScheduledPostImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PostMedia _$PostMediaFromJson(Map<String, dynamic> json) {
  return _PostMedia.fromJson(json);
}

/// @nodoc
mixin _$PostMedia {
  String get id => throw _privateConstructorUsedError;
  MediaType get type => throw _privateConstructorUsedError;
  String get src => throw _privateConstructorUsedError;
  double get aspectRatio => throw _privateConstructorUsedError;
  int? get durationMs => throw _privateConstructorUsedError;
  List<MediaVariant> get variants => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $PostMediaCopyWith<PostMedia> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PostMediaCopyWith<$Res> {
  factory $PostMediaCopyWith(PostMedia value, $Res Function(PostMedia) then) =
      _$PostMediaCopyWithImpl<$Res, PostMedia>;
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
class _$PostMediaCopyWithImpl<$Res, $Val extends PostMedia>
    implements $PostMediaCopyWith<$Res> {
  _$PostMediaCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

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
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as MediaType,
      src: null == src
          ? _value.src
          : src // ignore: cast_nullable_to_non_nullable
              as String,
      aspectRatio: null == aspectRatio
          ? _value.aspectRatio
          : aspectRatio // ignore: cast_nullable_to_non_nullable
              as double,
      durationMs: freezed == durationMs
          ? _value.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int?,
      variants: null == variants
          ? _value.variants
          : variants // ignore: cast_nullable_to_non_nullable
              as List<MediaVariant>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PostMediaImplCopyWith<$Res>
    implements $PostMediaCopyWith<$Res> {
  factory _$$PostMediaImplCopyWith(
          _$PostMediaImpl value, $Res Function(_$PostMediaImpl) then) =
      __$$PostMediaImplCopyWithImpl<$Res>;
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
class __$$PostMediaImplCopyWithImpl<$Res>
    extends _$PostMediaCopyWithImpl<$Res, _$PostMediaImpl>
    implements _$$PostMediaImplCopyWith<$Res> {
  __$$PostMediaImplCopyWithImpl(
      _$PostMediaImpl _value, $Res Function(_$PostMediaImpl) _then)
      : super(_value, _then);

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
    return _then(_$PostMediaImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as MediaType,
      src: null == src
          ? _value.src
          : src // ignore: cast_nullable_to_non_nullable
              as String,
      aspectRatio: null == aspectRatio
          ? _value.aspectRatio
          : aspectRatio // ignore: cast_nullable_to_non_nullable
              as double,
      durationMs: freezed == durationMs
          ? _value.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int?,
      variants: null == variants
          ? _value._variants
          : variants // ignore: cast_nullable_to_non_nullable
              as List<MediaVariant>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PostMediaImpl implements _PostMedia {
  const _$PostMediaImpl(
      {required this.id,
      required this.type,
      required this.src,
      required this.aspectRatio,
      this.durationMs,
      final List<MediaVariant> variants = const []})
      : _variants = variants;

  factory _$PostMediaImpl.fromJson(Map<String, dynamic> json) =>
      _$$PostMediaImplFromJson(json);

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

  @override
  String toString() {
    return 'PostMedia(id: $id, type: $type, src: $src, aspectRatio: $aspectRatio, durationMs: $durationMs, variants: $variants)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PostMediaImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.src, src) || other.src == src) &&
            (identical(other.aspectRatio, aspectRatio) ||
                other.aspectRatio == aspectRatio) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            const DeepCollectionEquality().equals(other._variants, _variants));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, type, src, aspectRatio,
      durationMs, const DeepCollectionEquality().hash(_variants));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PostMediaImplCopyWith<_$PostMediaImpl> get copyWith =>
      __$$PostMediaImplCopyWithImpl<_$PostMediaImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PostMediaImplToJson(
      this,
    );
  }
}

abstract class _PostMedia implements PostMedia {
  const factory _PostMedia(
      {required final String id,
      required final MediaType type,
      required final String src,
      required final double aspectRatio,
      final int? durationMs,
      final List<MediaVariant> variants}) = _$PostMediaImpl;

  factory _PostMedia.fromJson(Map<String, dynamic> json) =
      _$PostMediaImpl.fromJson;

  @override
  String get id;
  @override
  MediaType get type;
  @override
  String get src;
  @override
  double get aspectRatio;
  @override
  int? get durationMs;
  @override
  List<MediaVariant> get variants;
  @override
  @JsonKey(ignore: true)
  _$$PostMediaImplCopyWith<_$PostMediaImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MediaVariant _$MediaVariantFromJson(Map<String, dynamic> json) {
  return _MediaVariant.fromJson(json);
}

/// @nodoc
mixin _$MediaVariant {
  String get platform => throw _privateConstructorUsedError;
  String get src => throw _privateConstructorUsedError;
  double get aspectRatio => throw _privateConstructorUsedError;
  int? get durationMs => throw _privateConstructorUsedError;
  Map<String, dynamic>? get metadata => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $MediaVariantCopyWith<MediaVariant> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MediaVariantCopyWith<$Res> {
  factory $MediaVariantCopyWith(
          MediaVariant value, $Res Function(MediaVariant) then) =
      _$MediaVariantCopyWithImpl<$Res, MediaVariant>;
  @useResult
  $Res call(
      {String platform,
      String src,
      double aspectRatio,
      int? durationMs,
      Map<String, dynamic>? metadata});
}

/// @nodoc
class _$MediaVariantCopyWithImpl<$Res, $Val extends MediaVariant>
    implements $MediaVariantCopyWith<$Res> {
  _$MediaVariantCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? platform = null,
    Object? src = null,
    Object? aspectRatio = null,
    Object? durationMs = freezed,
    Object? metadata = freezed,
  }) {
    return _then(_value.copyWith(
      platform: null == platform
          ? _value.platform
          : platform // ignore: cast_nullable_to_non_nullable
              as String,
      src: null == src
          ? _value.src
          : src // ignore: cast_nullable_to_non_nullable
              as String,
      aspectRatio: null == aspectRatio
          ? _value.aspectRatio
          : aspectRatio // ignore: cast_nullable_to_non_nullable
              as double,
      durationMs: freezed == durationMs
          ? _value.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int?,
      metadata: freezed == metadata
          ? _value.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MediaVariantImplCopyWith<$Res>
    implements $MediaVariantCopyWith<$Res> {
  factory _$$MediaVariantImplCopyWith(
          _$MediaVariantImpl value, $Res Function(_$MediaVariantImpl) then) =
      __$$MediaVariantImplCopyWithImpl<$Res>;
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
class __$$MediaVariantImplCopyWithImpl<$Res>
    extends _$MediaVariantCopyWithImpl<$Res, _$MediaVariantImpl>
    implements _$$MediaVariantImplCopyWith<$Res> {
  __$$MediaVariantImplCopyWithImpl(
      _$MediaVariantImpl _value, $Res Function(_$MediaVariantImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? platform = null,
    Object? src = null,
    Object? aspectRatio = null,
    Object? durationMs = freezed,
    Object? metadata = freezed,
  }) {
    return _then(_$MediaVariantImpl(
      platform: null == platform
          ? _value.platform
          : platform // ignore: cast_nullable_to_non_nullable
              as String,
      src: null == src
          ? _value.src
          : src // ignore: cast_nullable_to_non_nullable
              as String,
      aspectRatio: null == aspectRatio
          ? _value.aspectRatio
          : aspectRatio // ignore: cast_nullable_to_non_nullable
              as double,
      durationMs: freezed == durationMs
          ? _value.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int?,
      metadata: freezed == metadata
          ? _value._metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MediaVariantImpl implements _MediaVariant {
  const _$MediaVariantImpl(
      {required this.platform,
      required this.src,
      required this.aspectRatio,
      this.durationMs,
      final Map<String, dynamic>? metadata})
      : _metadata = metadata;

  factory _$MediaVariantImpl.fromJson(Map<String, dynamic> json) =>
      _$$MediaVariantImplFromJson(json);

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

  @override
  String toString() {
    return 'MediaVariant(platform: $platform, src: $src, aspectRatio: $aspectRatio, durationMs: $durationMs, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MediaVariantImpl &&
            (identical(other.platform, platform) ||
                other.platform == platform) &&
            (identical(other.src, src) || other.src == src) &&
            (identical(other.aspectRatio, aspectRatio) ||
                other.aspectRatio == aspectRatio) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, platform, src, aspectRatio,
      durationMs, const DeepCollectionEquality().hash(_metadata));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MediaVariantImplCopyWith<_$MediaVariantImpl> get copyWith =>
      __$$MediaVariantImplCopyWithImpl<_$MediaVariantImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MediaVariantImplToJson(
      this,
    );
  }
}

abstract class _MediaVariant implements MediaVariant {
  const factory _MediaVariant(
      {required final String platform,
      required final String src,
      required final double aspectRatio,
      final int? durationMs,
      final Map<String, dynamic>? metadata}) = _$MediaVariantImpl;

  factory _MediaVariant.fromJson(Map<String, dynamic> json) =
      _$MediaVariantImpl.fromJson;

  @override
  String get platform;
  @override
  String get src;
  @override
  double get aspectRatio;
  @override
  int? get durationMs;
  @override
  Map<String, dynamic>? get metadata;
  @override
  @JsonKey(ignore: true)
  _$$MediaVariantImplCopyWith<_$MediaVariantImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PlatformConfig _$PlatformConfigFromJson(Map<String, dynamic> json) {
  return _PlatformConfig.fromJson(json);
}

/// @nodoc
mixin _$PlatformConfig {
  String get key => throw _privateConstructorUsedError;
  bool get enabled => throw _privateConstructorUsedError;
  Map<String, dynamic>? get payload => throw _privateConstructorUsedError;
  PlatformStatus? get status => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;
  DateTime? get scheduledAtUtc => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $PlatformConfigCopyWith<PlatformConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlatformConfigCopyWith<$Res> {
  factory $PlatformConfigCopyWith(
          PlatformConfig value, $Res Function(PlatformConfig) then) =
      _$PlatformConfigCopyWithImpl<$Res, PlatformConfig>;
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
class _$PlatformConfigCopyWithImpl<$Res, $Val extends PlatformConfig>
    implements $PlatformConfigCopyWith<$Res> {
  _$PlatformConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

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
    return _then(_value.copyWith(
      key: null == key
          ? _value.key
          : key // ignore: cast_nullable_to_non_nullable
              as String,
      enabled: null == enabled
          ? _value.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      payload: freezed == payload
          ? _value.payload
          : payload // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as PlatformStatus?,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      scheduledAtUtc: freezed == scheduledAtUtc
          ? _value.scheduledAtUtc
          : scheduledAtUtc // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PlatformConfigImplCopyWith<$Res>
    implements $PlatformConfigCopyWith<$Res> {
  factory _$$PlatformConfigImplCopyWith(_$PlatformConfigImpl value,
          $Res Function(_$PlatformConfigImpl) then) =
      __$$PlatformConfigImplCopyWithImpl<$Res>;
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
class __$$PlatformConfigImplCopyWithImpl<$Res>
    extends _$PlatformConfigCopyWithImpl<$Res, _$PlatformConfigImpl>
    implements _$$PlatformConfigImplCopyWith<$Res> {
  __$$PlatformConfigImplCopyWithImpl(
      _$PlatformConfigImpl _value, $Res Function(_$PlatformConfigImpl) _then)
      : super(_value, _then);

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
    return _then(_$PlatformConfigImpl(
      key: null == key
          ? _value.key
          : key // ignore: cast_nullable_to_non_nullable
              as String,
      enabled: null == enabled
          ? _value.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      payload: freezed == payload
          ? _value._payload
          : payload // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as PlatformStatus?,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      scheduledAtUtc: freezed == scheduledAtUtc
          ? _value.scheduledAtUtc
          : scheduledAtUtc // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PlatformConfigImpl implements _PlatformConfig {
  const _$PlatformConfigImpl(
      {required this.key,
      required this.enabled,
      final Map<String, dynamic>? payload,
      this.status,
      this.error,
      this.scheduledAtUtc})
      : _payload = payload;

  factory _$PlatformConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlatformConfigImplFromJson(json);

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

  @override
  String toString() {
    return 'PlatformConfig(key: $key, enabled: $enabled, payload: $payload, status: $status, error: $error, scheduledAtUtc: $scheduledAtUtc)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlatformConfigImpl &&
            (identical(other.key, key) || other.key == key) &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            const DeepCollectionEquality().equals(other._payload, _payload) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.scheduledAtUtc, scheduledAtUtc) ||
                other.scheduledAtUtc == scheduledAtUtc));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      key,
      enabled,
      const DeepCollectionEquality().hash(_payload),
      status,
      error,
      scheduledAtUtc);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PlatformConfigImplCopyWith<_$PlatformConfigImpl> get copyWith =>
      __$$PlatformConfigImplCopyWithImpl<_$PlatformConfigImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PlatformConfigImplToJson(
      this,
    );
  }
}

abstract class _PlatformConfig implements PlatformConfig {
  const factory _PlatformConfig(
      {required final String key,
      required final bool enabled,
      final Map<String, dynamic>? payload,
      final PlatformStatus? status,
      final String? error,
      final DateTime? scheduledAtUtc}) = _$PlatformConfigImpl;

  factory _PlatformConfig.fromJson(Map<String, dynamic> json) =
      _$PlatformConfigImpl.fromJson;

  @override
  String get key;
  @override
  bool get enabled;
  @override
  Map<String, dynamic>? get payload;
  @override
  PlatformStatus? get status;
  @override
  String? get error;
  @override
  DateTime? get scheduledAtUtc;
  @override
  @JsonKey(ignore: true)
  _$$PlatformConfigImplCopyWith<_$PlatformConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PostSchedule _$PostScheduleFromJson(Map<String, dynamic> json) {
  return _PostSchedule.fromJson(json);
}

/// @nodoc
mixin _$PostSchedule {
  DateTime get scheduledAtUtc => throw _privateConstructorUsedError;
  String get timezone => throw _privateConstructorUsedError;
  Map<String, PlatformSchedule> get perPlatform =>
      throw _privateConstructorUsedError;
  DateTime get createdAtUtc => throw _privateConstructorUsedError;
  DateTime get updatedAtUtc => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $PostScheduleCopyWith<PostSchedule> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PostScheduleCopyWith<$Res> {
  factory $PostScheduleCopyWith(
          PostSchedule value, $Res Function(PostSchedule) then) =
      _$PostScheduleCopyWithImpl<$Res, PostSchedule>;
  @useResult
  $Res call(
      {DateTime scheduledAtUtc,
      String timezone,
      Map<String, PlatformSchedule> perPlatform,
      DateTime createdAtUtc,
      DateTime updatedAtUtc});
}

/// @nodoc
class _$PostScheduleCopyWithImpl<$Res, $Val extends PostSchedule>
    implements $PostScheduleCopyWith<$Res> {
  _$PostScheduleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? scheduledAtUtc = null,
    Object? timezone = null,
    Object? perPlatform = null,
    Object? createdAtUtc = null,
    Object? updatedAtUtc = null,
  }) {
    return _then(_value.copyWith(
      scheduledAtUtc: null == scheduledAtUtc
          ? _value.scheduledAtUtc
          : scheduledAtUtc // ignore: cast_nullable_to_non_nullable
              as DateTime,
      timezone: null == timezone
          ? _value.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String,
      perPlatform: null == perPlatform
          ? _value.perPlatform
          : perPlatform // ignore: cast_nullable_to_non_nullable
              as Map<String, PlatformSchedule>,
      createdAtUtc: null == createdAtUtc
          ? _value.createdAtUtc
          : createdAtUtc // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAtUtc: null == updatedAtUtc
          ? _value.updatedAtUtc
          : updatedAtUtc // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PostScheduleImplCopyWith<$Res>
    implements $PostScheduleCopyWith<$Res> {
  factory _$$PostScheduleImplCopyWith(
          _$PostScheduleImpl value, $Res Function(_$PostScheduleImpl) then) =
      __$$PostScheduleImplCopyWithImpl<$Res>;
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
class __$$PostScheduleImplCopyWithImpl<$Res>
    extends _$PostScheduleCopyWithImpl<$Res, _$PostScheduleImpl>
    implements _$$PostScheduleImplCopyWith<$Res> {
  __$$PostScheduleImplCopyWithImpl(
      _$PostScheduleImpl _value, $Res Function(_$PostScheduleImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? scheduledAtUtc = null,
    Object? timezone = null,
    Object? perPlatform = null,
    Object? createdAtUtc = null,
    Object? updatedAtUtc = null,
  }) {
    return _then(_$PostScheduleImpl(
      scheduledAtUtc: null == scheduledAtUtc
          ? _value.scheduledAtUtc
          : scheduledAtUtc // ignore: cast_nullable_to_non_nullable
              as DateTime,
      timezone: null == timezone
          ? _value.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String,
      perPlatform: null == perPlatform
          ? _value._perPlatform
          : perPlatform // ignore: cast_nullable_to_non_nullable
              as Map<String, PlatformSchedule>,
      createdAtUtc: null == createdAtUtc
          ? _value.createdAtUtc
          : createdAtUtc // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAtUtc: null == updatedAtUtc
          ? _value.updatedAtUtc
          : updatedAtUtc // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PostScheduleImpl implements _PostSchedule {
  const _$PostScheduleImpl(
      {required this.scheduledAtUtc,
      required this.timezone,
      final Map<String, PlatformSchedule> perPlatform = const {},
      required this.createdAtUtc,
      required this.updatedAtUtc})
      : _perPlatform = perPlatform;

  factory _$PostScheduleImpl.fromJson(Map<String, dynamic> json) =>
      _$$PostScheduleImplFromJson(json);

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

  @override
  String toString() {
    return 'PostSchedule(scheduledAtUtc: $scheduledAtUtc, timezone: $timezone, perPlatform: $perPlatform, createdAtUtc: $createdAtUtc, updatedAtUtc: $updatedAtUtc)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PostScheduleImpl &&
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

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      scheduledAtUtc,
      timezone,
      const DeepCollectionEquality().hash(_perPlatform),
      createdAtUtc,
      updatedAtUtc);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PostScheduleImplCopyWith<_$PostScheduleImpl> get copyWith =>
      __$$PostScheduleImplCopyWithImpl<_$PostScheduleImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PostScheduleImplToJson(
      this,
    );
  }
}

abstract class _PostSchedule implements PostSchedule {
  const factory _PostSchedule(
      {required final DateTime scheduledAtUtc,
      required final String timezone,
      final Map<String, PlatformSchedule> perPlatform,
      required final DateTime createdAtUtc,
      required final DateTime updatedAtUtc}) = _$PostScheduleImpl;

  factory _PostSchedule.fromJson(Map<String, dynamic> json) =
      _$PostScheduleImpl.fromJson;

  @override
  DateTime get scheduledAtUtc;
  @override
  String get timezone;
  @override
  Map<String, PlatformSchedule> get perPlatform;
  @override
  DateTime get createdAtUtc;
  @override
  DateTime get updatedAtUtc;
  @override
  @JsonKey(ignore: true)
  _$$PostScheduleImplCopyWith<_$PostScheduleImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PlatformSchedule _$PlatformScheduleFromJson(Map<String, dynamic> json) {
  return _PlatformSchedule.fromJson(json);
}

/// @nodoc
mixin _$PlatformSchedule {
  DateTime get scheduledAtUtc => throw _privateConstructorUsedError;
  String? get timezone => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $PlatformScheduleCopyWith<PlatformSchedule> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlatformScheduleCopyWith<$Res> {
  factory $PlatformScheduleCopyWith(
          PlatformSchedule value, $Res Function(PlatformSchedule) then) =
      _$PlatformScheduleCopyWithImpl<$Res, PlatformSchedule>;
  @useResult
  $Res call({DateTime scheduledAtUtc, String? timezone});
}

/// @nodoc
class _$PlatformScheduleCopyWithImpl<$Res, $Val extends PlatformSchedule>
    implements $PlatformScheduleCopyWith<$Res> {
  _$PlatformScheduleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? scheduledAtUtc = null,
    Object? timezone = freezed,
  }) {
    return _then(_value.copyWith(
      scheduledAtUtc: null == scheduledAtUtc
          ? _value.scheduledAtUtc
          : scheduledAtUtc // ignore: cast_nullable_to_non_nullable
              as DateTime,
      timezone: freezed == timezone
          ? _value.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PlatformScheduleImplCopyWith<$Res>
    implements $PlatformScheduleCopyWith<$Res> {
  factory _$$PlatformScheduleImplCopyWith(_$PlatformScheduleImpl value,
          $Res Function(_$PlatformScheduleImpl) then) =
      __$$PlatformScheduleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({DateTime scheduledAtUtc, String? timezone});
}

/// @nodoc
class __$$PlatformScheduleImplCopyWithImpl<$Res>
    extends _$PlatformScheduleCopyWithImpl<$Res, _$PlatformScheduleImpl>
    implements _$$PlatformScheduleImplCopyWith<$Res> {
  __$$PlatformScheduleImplCopyWithImpl(_$PlatformScheduleImpl _value,
      $Res Function(_$PlatformScheduleImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? scheduledAtUtc = null,
    Object? timezone = freezed,
  }) {
    return _then(_$PlatformScheduleImpl(
      scheduledAtUtc: null == scheduledAtUtc
          ? _value.scheduledAtUtc
          : scheduledAtUtc // ignore: cast_nullable_to_non_nullable
              as DateTime,
      timezone: freezed == timezone
          ? _value.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PlatformScheduleImpl implements _PlatformSchedule {
  const _$PlatformScheduleImpl({required this.scheduledAtUtc, this.timezone});

  factory _$PlatformScheduleImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlatformScheduleImplFromJson(json);

  @override
  final DateTime scheduledAtUtc;
  @override
  final String? timezone;

  @override
  String toString() {
    return 'PlatformSchedule(scheduledAtUtc: $scheduledAtUtc, timezone: $timezone)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlatformScheduleImpl &&
            (identical(other.scheduledAtUtc, scheduledAtUtc) ||
                other.scheduledAtUtc == scheduledAtUtc) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, scheduledAtUtc, timezone);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PlatformScheduleImplCopyWith<_$PlatformScheduleImpl> get copyWith =>
      __$$PlatformScheduleImplCopyWithImpl<_$PlatformScheduleImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PlatformScheduleImplToJson(
      this,
    );
  }
}

abstract class _PlatformSchedule implements PlatformSchedule {
  const factory _PlatformSchedule(
      {required final DateTime scheduledAtUtc,
      final String? timezone}) = _$PlatformScheduleImpl;

  factory _PlatformSchedule.fromJson(Map<String, dynamic> json) =
      _$PlatformScheduleImpl.fromJson;

  @override
  DateTime get scheduledAtUtc;
  @override
  String? get timezone;
  @override
  @JsonKey(ignore: true)
  _$$PlatformScheduleImplCopyWith<_$PlatformScheduleImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
