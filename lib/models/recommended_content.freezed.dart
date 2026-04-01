// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recommended_content.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RecommendedContent {
  String get id;
  String get title;
  String get creator;
  String get description;
  String? get thumbnailURL;
  int get views;
  String get duration;
  String? get url;

  /// Create a copy of RecommendedContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $RecommendedContentCopyWith<RecommendedContent> get copyWith =>
      _$RecommendedContentCopyWithImpl<RecommendedContent>(
          this as RecommendedContent, _$identity);

  /// Serializes this RecommendedContent to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is RecommendedContent &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.creator, creator) || other.creator == creator) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.thumbnailURL, thumbnailURL) ||
                other.thumbnailURL == thumbnailURL) &&
            (identical(other.views, views) || other.views == views) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.url, url) || other.url == url));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, creator, description,
      thumbnailURL, views, duration, url);

  @override
  String toString() {
    return 'RecommendedContent(id: $id, title: $title, creator: $creator, description: $description, thumbnailURL: $thumbnailURL, views: $views, duration: $duration, url: $url)';
  }
}

/// @nodoc
abstract mixin class $RecommendedContentCopyWith<$Res> {
  factory $RecommendedContentCopyWith(
          RecommendedContent value, $Res Function(RecommendedContent) _then) =
      _$RecommendedContentCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String title,
      String creator,
      String description,
      String? thumbnailURL,
      int views,
      String duration,
      String? url});
}

/// @nodoc
class _$RecommendedContentCopyWithImpl<$Res>
    implements $RecommendedContentCopyWith<$Res> {
  _$RecommendedContentCopyWithImpl(this._self, this._then);

  final RecommendedContent _self;
  final $Res Function(RecommendedContent) _then;

  /// Create a copy of RecommendedContent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? creator = null,
    Object? description = null,
    Object? thumbnailURL = freezed,
    Object? views = null,
    Object? duration = null,
    Object? url = freezed,
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
      creator: null == creator
          ? _self.creator
          : creator // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      thumbnailURL: freezed == thumbnailURL
          ? _self.thumbnailURL
          : thumbnailURL // ignore: cast_nullable_to_non_nullable
              as String?,
      views: null == views
          ? _self.views
          : views // ignore: cast_nullable_to_non_nullable
              as int,
      duration: null == duration
          ? _self.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as String,
      url: freezed == url
          ? _self.url
          : url // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [RecommendedContent].
extension RecommendedContentPatterns on RecommendedContent {
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
    TResult Function(_RecommendedContent value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RecommendedContent() when $default != null:
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
    TResult Function(_RecommendedContent value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RecommendedContent():
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
    TResult? Function(_RecommendedContent value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RecommendedContent() when $default != null:
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
            String creator,
            String description,
            String? thumbnailURL,
            int views,
            String duration,
            String? url)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RecommendedContent() when $default != null:
        return $default(_that.id, _that.title, _that.creator, _that.description,
            _that.thumbnailURL, _that.views, _that.duration, _that.url);
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
            String creator,
            String description,
            String? thumbnailURL,
            int views,
            String duration,
            String? url)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RecommendedContent():
        return $default(_that.id, _that.title, _that.creator, _that.description,
            _that.thumbnailURL, _that.views, _that.duration, _that.url);
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
            String creator,
            String description,
            String? thumbnailURL,
            int views,
            String duration,
            String? url)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RecommendedContent() when $default != null:
        return $default(_that.id, _that.title, _that.creator, _that.description,
            _that.thumbnailURL, _that.views, _that.duration, _that.url);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _RecommendedContent implements RecommendedContent {
  const _RecommendedContent(
      {required this.id,
      required this.title,
      required this.creator,
      required this.description,
      this.thumbnailURL,
      this.views = 0,
      this.duration = '',
      this.url});
  factory _RecommendedContent.fromJson(Map<String, dynamic> json) =>
      _$RecommendedContentFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String creator;
  @override
  final String description;
  @override
  final String? thumbnailURL;
  @override
  @JsonKey()
  final int views;
  @override
  @JsonKey()
  final String duration;
  @override
  final String? url;

  /// Create a copy of RecommendedContent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$RecommendedContentCopyWith<_RecommendedContent> get copyWith =>
      __$RecommendedContentCopyWithImpl<_RecommendedContent>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$RecommendedContentToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _RecommendedContent &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.creator, creator) || other.creator == creator) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.thumbnailURL, thumbnailURL) ||
                other.thumbnailURL == thumbnailURL) &&
            (identical(other.views, views) || other.views == views) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.url, url) || other.url == url));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, creator, description,
      thumbnailURL, views, duration, url);

  @override
  String toString() {
    return 'RecommendedContent(id: $id, title: $title, creator: $creator, description: $description, thumbnailURL: $thumbnailURL, views: $views, duration: $duration, url: $url)';
  }
}

/// @nodoc
abstract mixin class _$RecommendedContentCopyWith<$Res>
    implements $RecommendedContentCopyWith<$Res> {
  factory _$RecommendedContentCopyWith(
          _RecommendedContent value, $Res Function(_RecommendedContent) _then) =
      __$RecommendedContentCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String creator,
      String description,
      String? thumbnailURL,
      int views,
      String duration,
      String? url});
}

/// @nodoc
class __$RecommendedContentCopyWithImpl<$Res>
    implements _$RecommendedContentCopyWith<$Res> {
  __$RecommendedContentCopyWithImpl(this._self, this._then);

  final _RecommendedContent _self;
  final $Res Function(_RecommendedContent) _then;

  /// Create a copy of RecommendedContent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? creator = null,
    Object? description = null,
    Object? thumbnailURL = freezed,
    Object? views = null,
    Object? duration = null,
    Object? url = freezed,
  }) {
    return _then(_RecommendedContent(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      creator: null == creator
          ? _self.creator
          : creator // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      thumbnailURL: freezed == thumbnailURL
          ? _self.thumbnailURL
          : thumbnailURL // ignore: cast_nullable_to_non_nullable
              as String?,
      views: null == views
          ? _self.views
          : views // ignore: cast_nullable_to_non_nullable
              as int,
      duration: null == duration
          ? _self.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as String,
      url: freezed == url
          ? _self.url
          : url // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
