// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'video_thumbnails.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$VideoThumbnails {
  /// Thumbnail URLs by width (e.g., {360: "url1", 540: "url2", 720: "url3"})
  Map<int, String> get urls => throw _privateConstructorUsedError;

  /// Timestamp when thumbnails were generated (for cache busting)
  Timestamp? get generatedAt => throw _privateConstructorUsedError;

  /// Aspect ratio of the thumbnails (should be 9:16 for consistency)
  double get aspectRatio => throw _privateConstructorUsedError;

  /// Source frame timestamp (in seconds) used for thumbnail generation
  double get sourceTimestamp => throw _privateConstructorUsedError;

  /// Quality score of the thumbnail (0.0 - 1.0)
  double get qualityScore => throw _privateConstructorUsedError;

  /// Whether thumbnails are still being generated
  bool get isGenerating => throw _privateConstructorUsedError;

  /// Error message if thumbnail generation failed
  String? get errorMessage => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $VideoThumbnailsCopyWith<VideoThumbnails> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VideoThumbnailsCopyWith<$Res> {
  factory $VideoThumbnailsCopyWith(
          VideoThumbnails value, $Res Function(VideoThumbnails) then) =
      _$VideoThumbnailsCopyWithImpl<$Res, VideoThumbnails>;
  @useResult
  $Res call(
      {Map<int, String> urls,
      Timestamp? generatedAt,
      double aspectRatio,
      double sourceTimestamp,
      double qualityScore,
      bool isGenerating,
      String? errorMessage});
}

/// @nodoc
class _$VideoThumbnailsCopyWithImpl<$Res, $Val extends VideoThumbnails>
    implements $VideoThumbnailsCopyWith<$Res> {
  _$VideoThumbnailsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? urls = null,
    Object? generatedAt = freezed,
    Object? aspectRatio = null,
    Object? sourceTimestamp = null,
    Object? qualityScore = null,
    Object? isGenerating = null,
    Object? errorMessage = freezed,
  }) {
    return _then(_value.copyWith(
      urls: null == urls
          ? _value.urls
          : urls // ignore: cast_nullable_to_non_nullable
              as Map<int, String>,
      generatedAt: freezed == generatedAt
          ? _value.generatedAt
          : generatedAt // ignore: cast_nullable_to_non_nullable
              as Timestamp?,
      aspectRatio: null == aspectRatio
          ? _value.aspectRatio
          : aspectRatio // ignore: cast_nullable_to_non_nullable
              as double,
      sourceTimestamp: null == sourceTimestamp
          ? _value.sourceTimestamp
          : sourceTimestamp // ignore: cast_nullable_to_non_nullable
              as double,
      qualityScore: null == qualityScore
          ? _value.qualityScore
          : qualityScore // ignore: cast_nullable_to_non_nullable
              as double,
      isGenerating: null == isGenerating
          ? _value.isGenerating
          : isGenerating // ignore: cast_nullable_to_non_nullable
              as bool,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$VideoThumbnailsImplCopyWith<$Res>
    implements $VideoThumbnailsCopyWith<$Res> {
  factory _$$VideoThumbnailsImplCopyWith(_$VideoThumbnailsImpl value,
          $Res Function(_$VideoThumbnailsImpl) then) =
      __$$VideoThumbnailsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Map<int, String> urls,
      Timestamp? generatedAt,
      double aspectRatio,
      double sourceTimestamp,
      double qualityScore,
      bool isGenerating,
      String? errorMessage});
}

/// @nodoc
class __$$VideoThumbnailsImplCopyWithImpl<$Res>
    extends _$VideoThumbnailsCopyWithImpl<$Res, _$VideoThumbnailsImpl>
    implements _$$VideoThumbnailsImplCopyWith<$Res> {
  __$$VideoThumbnailsImplCopyWithImpl(
      _$VideoThumbnailsImpl _value, $Res Function(_$VideoThumbnailsImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? urls = null,
    Object? generatedAt = freezed,
    Object? aspectRatio = null,
    Object? sourceTimestamp = null,
    Object? qualityScore = null,
    Object? isGenerating = null,
    Object? errorMessage = freezed,
  }) {
    return _then(_$VideoThumbnailsImpl(
      urls: null == urls
          ? _value._urls
          : urls // ignore: cast_nullable_to_non_nullable
              as Map<int, String>,
      generatedAt: freezed == generatedAt
          ? _value.generatedAt
          : generatedAt // ignore: cast_nullable_to_non_nullable
              as Timestamp?,
      aspectRatio: null == aspectRatio
          ? _value.aspectRatio
          : aspectRatio // ignore: cast_nullable_to_non_nullable
              as double,
      sourceTimestamp: null == sourceTimestamp
          ? _value.sourceTimestamp
          : sourceTimestamp // ignore: cast_nullable_to_non_nullable
              as double,
      qualityScore: null == qualityScore
          ? _value.qualityScore
          : qualityScore // ignore: cast_nullable_to_non_nullable
              as double,
      isGenerating: null == isGenerating
          ? _value.isGenerating
          : isGenerating // ignore: cast_nullable_to_non_nullable
              as bool,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$VideoThumbnailsImpl implements _VideoThumbnails {
  const _$VideoThumbnailsImpl(
      {final Map<int, String> urls = const {},
      this.generatedAt,
      this.aspectRatio = 9.0 / 16.0,
      this.sourceTimestamp = 0.0,
      this.qualityScore = 1.0,
      this.isGenerating = false,
      this.errorMessage})
      : _urls = urls;

  /// Thumbnail URLs by width (e.g., {360: "url1", 540: "url2", 720: "url3"})
  final Map<int, String> _urls;

  /// Thumbnail URLs by width (e.g., {360: "url1", 540: "url2", 720: "url3"})
  @override
  @JsonKey()
  Map<int, String> get urls {
    if (_urls is EqualUnmodifiableMapView) return _urls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_urls);
  }

  /// Timestamp when thumbnails were generated (for cache busting)
  @override
  final Timestamp? generatedAt;

  /// Aspect ratio of the thumbnails (should be 9:16 for consistency)
  @override
  @JsonKey()
  final double aspectRatio;

  /// Source frame timestamp (in seconds) used for thumbnail generation
  @override
  @JsonKey()
  final double sourceTimestamp;

  /// Quality score of the thumbnail (0.0 - 1.0)
  @override
  @JsonKey()
  final double qualityScore;

  /// Whether thumbnails are still being generated
  @override
  @JsonKey()
  final bool isGenerating;

  /// Error message if thumbnail generation failed
  @override
  final String? errorMessage;

  @override
  String toString() {
    return 'VideoThumbnails(urls: $urls, generatedAt: $generatedAt, aspectRatio: $aspectRatio, sourceTimestamp: $sourceTimestamp, qualityScore: $qualityScore, isGenerating: $isGenerating, errorMessage: $errorMessage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VideoThumbnailsImpl &&
            const DeepCollectionEquality().equals(other._urls, _urls) &&
            (identical(other.generatedAt, generatedAt) ||
                other.generatedAt == generatedAt) &&
            (identical(other.aspectRatio, aspectRatio) ||
                other.aspectRatio == aspectRatio) &&
            (identical(other.sourceTimestamp, sourceTimestamp) ||
                other.sourceTimestamp == sourceTimestamp) &&
            (identical(other.qualityScore, qualityScore) ||
                other.qualityScore == qualityScore) &&
            (identical(other.isGenerating, isGenerating) ||
                other.isGenerating == isGenerating) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_urls),
      generatedAt,
      aspectRatio,
      sourceTimestamp,
      qualityScore,
      isGenerating,
      errorMessage);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$VideoThumbnailsImplCopyWith<_$VideoThumbnailsImpl> get copyWith =>
      __$$VideoThumbnailsImplCopyWithImpl<_$VideoThumbnailsImpl>(
          this, _$identity);
}

abstract class _VideoThumbnails implements VideoThumbnails {
  const factory _VideoThumbnails(
      {final Map<int, String> urls,
      final Timestamp? generatedAt,
      final double aspectRatio,
      final double sourceTimestamp,
      final double qualityScore,
      final bool isGenerating,
      final String? errorMessage}) = _$VideoThumbnailsImpl;

  @override

  /// Thumbnail URLs by width (e.g., {360: "url1", 540: "url2", 720: "url3"})
  Map<int, String> get urls;
  @override

  /// Timestamp when thumbnails were generated (for cache busting)
  Timestamp? get generatedAt;
  @override

  /// Aspect ratio of the thumbnails (should be 9:16 for consistency)
  double get aspectRatio;
  @override

  /// Source frame timestamp (in seconds) used for thumbnail generation
  double get sourceTimestamp;
  @override

  /// Quality score of the thumbnail (0.0 - 1.0)
  double get qualityScore;
  @override

  /// Whether thumbnails are still being generated
  bool get isGenerating;
  @override

  /// Error message if thumbnail generation failed
  String? get errorMessage;
  @override
  @JsonKey(ignore: true)
  _$$VideoThumbnailsImplCopyWith<_$VideoThumbnailsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
