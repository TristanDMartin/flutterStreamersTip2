// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'video_thumbnails.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VideoThumbnails {
  /// Thumbnail URLs by width (e.g., {360: "url1", 540: "url2", 720: "url3"})
  Map<int, String> get urls;

  /// Timestamp when thumbnails were generated (for cache busting)
  Timestamp? get generatedAt;

  /// Aspect ratio of the thumbnails (should be 9:16 for consistency)
  double get aspectRatio;

  /// Source frame timestamp (in seconds) used for thumbnail generation
  double get sourceTimestamp;

  /// Quality score of the thumbnail (0.0 - 1.0)
  double get qualityScore;

  /// Whether thumbnails are still being generated
  bool get isGenerating;

  /// Error message if thumbnail generation failed
  String? get errorMessage;

  /// Create a copy of VideoThumbnails
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $VideoThumbnailsCopyWith<VideoThumbnails> get copyWith =>
      _$VideoThumbnailsCopyWithImpl<VideoThumbnails>(
          this as VideoThumbnails, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is VideoThumbnails &&
            const DeepCollectionEquality().equals(other.urls, urls) &&
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
      const DeepCollectionEquality().hash(urls),
      generatedAt,
      aspectRatio,
      sourceTimestamp,
      qualityScore,
      isGenerating,
      errorMessage);

  @override
  String toString() {
    return 'VideoThumbnails(urls: $urls, generatedAt: $generatedAt, aspectRatio: $aspectRatio, sourceTimestamp: $sourceTimestamp, qualityScore: $qualityScore, isGenerating: $isGenerating, errorMessage: $errorMessage)';
  }
}

/// @nodoc
abstract mixin class $VideoThumbnailsCopyWith<$Res> {
  factory $VideoThumbnailsCopyWith(
          VideoThumbnails value, $Res Function(VideoThumbnails) _then) =
      _$VideoThumbnailsCopyWithImpl;
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
class _$VideoThumbnailsCopyWithImpl<$Res>
    implements $VideoThumbnailsCopyWith<$Res> {
  _$VideoThumbnailsCopyWithImpl(this._self, this._then);

  final VideoThumbnails _self;
  final $Res Function(VideoThumbnails) _then;

  /// Create a copy of VideoThumbnails
  /// with the given fields replaced by the non-null parameter values.
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
    return _then(_self.copyWith(
      urls: null == urls
          ? _self.urls
          : urls // ignore: cast_nullable_to_non_nullable
              as Map<int, String>,
      generatedAt: freezed == generatedAt
          ? _self.generatedAt
          : generatedAt // ignore: cast_nullable_to_non_nullable
              as Timestamp?,
      aspectRatio: null == aspectRatio
          ? _self.aspectRatio
          : aspectRatio // ignore: cast_nullable_to_non_nullable
              as double,
      sourceTimestamp: null == sourceTimestamp
          ? _self.sourceTimestamp
          : sourceTimestamp // ignore: cast_nullable_to_non_nullable
              as double,
      qualityScore: null == qualityScore
          ? _self.qualityScore
          : qualityScore // ignore: cast_nullable_to_non_nullable
              as double,
      isGenerating: null == isGenerating
          ? _self.isGenerating
          : isGenerating // ignore: cast_nullable_to_non_nullable
              as bool,
      errorMessage: freezed == errorMessage
          ? _self.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [VideoThumbnails].
extension VideoThumbnailsPatterns on VideoThumbnails {
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
    TResult Function(_VideoThumbnails value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _VideoThumbnails() when $default != null:
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
    TResult Function(_VideoThumbnails value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VideoThumbnails():
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
    TResult? Function(_VideoThumbnails value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VideoThumbnails() when $default != null:
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
            Map<int, String> urls,
            Timestamp? generatedAt,
            double aspectRatio,
            double sourceTimestamp,
            double qualityScore,
            bool isGenerating,
            String? errorMessage)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _VideoThumbnails() when $default != null:
        return $default(
            _that.urls,
            _that.generatedAt,
            _that.aspectRatio,
            _that.sourceTimestamp,
            _that.qualityScore,
            _that.isGenerating,
            _that.errorMessage);
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
            Map<int, String> urls,
            Timestamp? generatedAt,
            double aspectRatio,
            double sourceTimestamp,
            double qualityScore,
            bool isGenerating,
            String? errorMessage)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VideoThumbnails():
        return $default(
            _that.urls,
            _that.generatedAt,
            _that.aspectRatio,
            _that.sourceTimestamp,
            _that.qualityScore,
            _that.isGenerating,
            _that.errorMessage);
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
            Map<int, String> urls,
            Timestamp? generatedAt,
            double aspectRatio,
            double sourceTimestamp,
            double qualityScore,
            bool isGenerating,
            String? errorMessage)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VideoThumbnails() when $default != null:
        return $default(
            _that.urls,
            _that.generatedAt,
            _that.aspectRatio,
            _that.sourceTimestamp,
            _that.qualityScore,
            _that.isGenerating,
            _that.errorMessage);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _VideoThumbnails implements VideoThumbnails {
  const _VideoThumbnails(
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

  /// Create a copy of VideoThumbnails
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$VideoThumbnailsCopyWith<_VideoThumbnails> get copyWith =>
      __$VideoThumbnailsCopyWithImpl<_VideoThumbnails>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _VideoThumbnails &&
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

  @override
  String toString() {
    return 'VideoThumbnails(urls: $urls, generatedAt: $generatedAt, aspectRatio: $aspectRatio, sourceTimestamp: $sourceTimestamp, qualityScore: $qualityScore, isGenerating: $isGenerating, errorMessage: $errorMessage)';
  }
}

/// @nodoc
abstract mixin class _$VideoThumbnailsCopyWith<$Res>
    implements $VideoThumbnailsCopyWith<$Res> {
  factory _$VideoThumbnailsCopyWith(
          _VideoThumbnails value, $Res Function(_VideoThumbnails) _then) =
      __$VideoThumbnailsCopyWithImpl;
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
class __$VideoThumbnailsCopyWithImpl<$Res>
    implements _$VideoThumbnailsCopyWith<$Res> {
  __$VideoThumbnailsCopyWithImpl(this._self, this._then);

  final _VideoThumbnails _self;
  final $Res Function(_VideoThumbnails) _then;

  /// Create a copy of VideoThumbnails
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? urls = null,
    Object? generatedAt = freezed,
    Object? aspectRatio = null,
    Object? sourceTimestamp = null,
    Object? qualityScore = null,
    Object? isGenerating = null,
    Object? errorMessage = freezed,
  }) {
    return _then(_VideoThumbnails(
      urls: null == urls
          ? _self._urls
          : urls // ignore: cast_nullable_to_non_nullable
              as Map<int, String>,
      generatedAt: freezed == generatedAt
          ? _self.generatedAt
          : generatedAt // ignore: cast_nullable_to_non_nullable
              as Timestamp?,
      aspectRatio: null == aspectRatio
          ? _self.aspectRatio
          : aspectRatio // ignore: cast_nullable_to_non_nullable
              as double,
      sourceTimestamp: null == sourceTimestamp
          ? _self.sourceTimestamp
          : sourceTimestamp // ignore: cast_nullable_to_non_nullable
              as double,
      qualityScore: null == qualityScore
          ? _self.qualityScore
          : qualityScore // ignore: cast_nullable_to_non_nullable
              as double,
      isGenerating: null == isGenerating
          ? _self.isGenerating
          : isGenerating // ignore: cast_nullable_to_non_nullable
              as bool,
      errorMessage: freezed == errorMessage
          ? _self.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
