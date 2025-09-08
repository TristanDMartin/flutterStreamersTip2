// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recommended_content.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

RecommendedContent _$RecommendedContentFromJson(Map<String, dynamic> json) {
  return _RecommendedContent.fromJson(json);
}

/// @nodoc
mixin _$RecommendedContent {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get creator => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String? get thumbnailURL => throw _privateConstructorUsedError;
  int get views => throw _privateConstructorUsedError;
  String get duration => throw _privateConstructorUsedError;
  String? get url => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $RecommendedContentCopyWith<RecommendedContent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecommendedContentCopyWith<$Res> {
  factory $RecommendedContentCopyWith(
          RecommendedContent value, $Res Function(RecommendedContent) then) =
      _$RecommendedContentCopyWithImpl<$Res, RecommendedContent>;
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
class _$RecommendedContentCopyWithImpl<$Res, $Val extends RecommendedContent>
    implements $RecommendedContentCopyWith<$Res> {
  _$RecommendedContentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

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
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      creator: null == creator
          ? _value.creator
          : creator // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      thumbnailURL: freezed == thumbnailURL
          ? _value.thumbnailURL
          : thumbnailURL // ignore: cast_nullable_to_non_nullable
              as String?,
      views: null == views
          ? _value.views
          : views // ignore: cast_nullable_to_non_nullable
              as int,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as String,
      url: freezed == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RecommendedContentImplCopyWith<$Res>
    implements $RecommendedContentCopyWith<$Res> {
  factory _$$RecommendedContentImplCopyWith(_$RecommendedContentImpl value,
          $Res Function(_$RecommendedContentImpl) then) =
      __$$RecommendedContentImplCopyWithImpl<$Res>;
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
class __$$RecommendedContentImplCopyWithImpl<$Res>
    extends _$RecommendedContentCopyWithImpl<$Res, _$RecommendedContentImpl>
    implements _$$RecommendedContentImplCopyWith<$Res> {
  __$$RecommendedContentImplCopyWithImpl(_$RecommendedContentImpl _value,
      $Res Function(_$RecommendedContentImpl) _then)
      : super(_value, _then);

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
    return _then(_$RecommendedContentImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      creator: null == creator
          ? _value.creator
          : creator // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      thumbnailURL: freezed == thumbnailURL
          ? _value.thumbnailURL
          : thumbnailURL // ignore: cast_nullable_to_non_nullable
              as String?,
      views: null == views
          ? _value.views
          : views // ignore: cast_nullable_to_non_nullable
              as int,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as String,
      url: freezed == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RecommendedContentImpl implements _RecommendedContent {
  const _$RecommendedContentImpl(
      {required this.id,
      required this.title,
      required this.creator,
      required this.description,
      this.thumbnailURL,
      this.views = 0,
      this.duration = '',
      this.url});

  factory _$RecommendedContentImpl.fromJson(Map<String, dynamic> json) =>
      _$$RecommendedContentImplFromJson(json);

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

  @override
  String toString() {
    return 'RecommendedContent(id: $id, title: $title, creator: $creator, description: $description, thumbnailURL: $thumbnailURL, views: $views, duration: $duration, url: $url)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecommendedContentImpl &&
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

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, creator, description,
      thumbnailURL, views, duration, url);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$RecommendedContentImplCopyWith<_$RecommendedContentImpl> get copyWith =>
      __$$RecommendedContentImplCopyWithImpl<_$RecommendedContentImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RecommendedContentImplToJson(
      this,
    );
  }
}

abstract class _RecommendedContent implements RecommendedContent {
  const factory _RecommendedContent(
      {required final String id,
      required final String title,
      required final String creator,
      required final String description,
      final String? thumbnailURL,
      final int views,
      final String duration,
      final String? url}) = _$RecommendedContentImpl;

  factory _RecommendedContent.fromJson(Map<String, dynamic> json) =
      _$RecommendedContentImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get creator;
  @override
  String get description;
  @override
  String? get thumbnailURL;
  @override
  int get views;
  @override
  String get duration;
  @override
  String? get url;
  @override
  @JsonKey(ignore: true)
  _$$RecommendedContentImplCopyWith<_$RecommendedContentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
