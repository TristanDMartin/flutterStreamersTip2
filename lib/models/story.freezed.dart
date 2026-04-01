// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'story.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Story {
  String get id;
  String get creatorId;
  String get creatorName;
  String? get creatorAvatarURL;
  String get mediaURL;
  MediaType get mediaType;
  DateTime get timestamp;
  double get duration;
  bool get isViewed;

  /// Create a copy of Story
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $StoryCopyWith<Story> get copyWith =>
      _$StoryCopyWithImpl<Story>(this as Story, _$identity);

  /// Serializes this Story to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Story &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, creatorId, creatorName,
      creatorAvatarURL, mediaURL, mediaType, timestamp, duration, isViewed);

  @override
  String toString() {
    return 'Story(id: $id, creatorId: $creatorId, creatorName: $creatorName, creatorAvatarURL: $creatorAvatarURL, mediaURL: $mediaURL, mediaType: $mediaType, timestamp: $timestamp, duration: $duration, isViewed: $isViewed)';
  }
}

/// @nodoc
abstract mixin class $StoryCopyWith<$Res> {
  factory $StoryCopyWith(Story value, $Res Function(Story) _then) =
      _$StoryCopyWithImpl;
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
class _$StoryCopyWithImpl<$Res> implements $StoryCopyWith<$Res> {
  _$StoryCopyWithImpl(this._self, this._then);

  final Story _self;
  final $Res Function(Story) _then;

  /// Create a copy of Story
  /// with the given fields replaced by the non-null parameter values.
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
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      creatorId: null == creatorId
          ? _self.creatorId
          : creatorId // ignore: cast_nullable_to_non_nullable
              as String,
      creatorName: null == creatorName
          ? _self.creatorName
          : creatorName // ignore: cast_nullable_to_non_nullable
              as String,
      creatorAvatarURL: freezed == creatorAvatarURL
          ? _self.creatorAvatarURL
          : creatorAvatarURL // ignore: cast_nullable_to_non_nullable
              as String?,
      mediaURL: null == mediaURL
          ? _self.mediaURL
          : mediaURL // ignore: cast_nullable_to_non_nullable
              as String,
      mediaType: null == mediaType
          ? _self.mediaType
          : mediaType // ignore: cast_nullable_to_non_nullable
              as MediaType,
      timestamp: null == timestamp
          ? _self.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      duration: null == duration
          ? _self.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as double,
      isViewed: null == isViewed
          ? _self.isViewed
          : isViewed // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [Story].
extension StoryPatterns on Story {
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
    TResult Function(_Story value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Story() when $default != null:
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
    TResult Function(_Story value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Story():
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
    TResult? Function(_Story value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Story() when $default != null:
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
            String creatorId,
            String creatorName,
            String? creatorAvatarURL,
            String mediaURL,
            MediaType mediaType,
            DateTime timestamp,
            double duration,
            bool isViewed)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Story() when $default != null:
        return $default(
            _that.id,
            _that.creatorId,
            _that.creatorName,
            _that.creatorAvatarURL,
            _that.mediaURL,
            _that.mediaType,
            _that.timestamp,
            _that.duration,
            _that.isViewed);
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
            String creatorId,
            String creatorName,
            String? creatorAvatarURL,
            String mediaURL,
            MediaType mediaType,
            DateTime timestamp,
            double duration,
            bool isViewed)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Story():
        return $default(
            _that.id,
            _that.creatorId,
            _that.creatorName,
            _that.creatorAvatarURL,
            _that.mediaURL,
            _that.mediaType,
            _that.timestamp,
            _that.duration,
            _that.isViewed);
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
            String creatorId,
            String creatorName,
            String? creatorAvatarURL,
            String mediaURL,
            MediaType mediaType,
            DateTime timestamp,
            double duration,
            bool isViewed)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Story() when $default != null:
        return $default(
            _that.id,
            _that.creatorId,
            _that.creatorName,
            _that.creatorAvatarURL,
            _that.mediaURL,
            _that.mediaType,
            _that.timestamp,
            _that.duration,
            _that.isViewed);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Story implements Story {
  const _Story(
      {required this.id,
      required this.creatorId,
      required this.creatorName,
      this.creatorAvatarURL,
      required this.mediaURL,
      required this.mediaType,
      required this.timestamp,
      required this.duration,
      this.isViewed = false});
  factory _Story.fromJson(Map<String, dynamic> json) => _$StoryFromJson(json);

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

  /// Create a copy of Story
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$StoryCopyWith<_Story> get copyWith =>
      __$StoryCopyWithImpl<_Story>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$StoryToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Story &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, creatorId, creatorName,
      creatorAvatarURL, mediaURL, mediaType, timestamp, duration, isViewed);

  @override
  String toString() {
    return 'Story(id: $id, creatorId: $creatorId, creatorName: $creatorName, creatorAvatarURL: $creatorAvatarURL, mediaURL: $mediaURL, mediaType: $mediaType, timestamp: $timestamp, duration: $duration, isViewed: $isViewed)';
  }
}

/// @nodoc
abstract mixin class _$StoryCopyWith<$Res> implements $StoryCopyWith<$Res> {
  factory _$StoryCopyWith(_Story value, $Res Function(_Story) _then) =
      __$StoryCopyWithImpl;
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
class __$StoryCopyWithImpl<$Res> implements _$StoryCopyWith<$Res> {
  __$StoryCopyWithImpl(this._self, this._then);

  final _Story _self;
  final $Res Function(_Story) _then;

  /// Create a copy of Story
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
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
    return _then(_Story(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      creatorId: null == creatorId
          ? _self.creatorId
          : creatorId // ignore: cast_nullable_to_non_nullable
              as String,
      creatorName: null == creatorName
          ? _self.creatorName
          : creatorName // ignore: cast_nullable_to_non_nullable
              as String,
      creatorAvatarURL: freezed == creatorAvatarURL
          ? _self.creatorAvatarURL
          : creatorAvatarURL // ignore: cast_nullable_to_non_nullable
              as String?,
      mediaURL: null == mediaURL
          ? _self.mediaURL
          : mediaURL // ignore: cast_nullable_to_non_nullable
              as String,
      mediaType: null == mediaType
          ? _self.mediaType
          : mediaType // ignore: cast_nullable_to_non_nullable
              as MediaType,
      timestamp: null == timestamp
          ? _self.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      duration: null == duration
          ? _self.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as double,
      isViewed: null == isViewed
          ? _self.isViewed
          : isViewed // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

// dart format on
