// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'share_payload.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SharePayload _$SharePayloadFromJson(Map<String, dynamic> json) {
  return _SharePayload.fromJson(json);
}

/// @nodoc
mixin _$SharePayload {
  String get videoId => throw _privateConstructorUsedError;
  ShareLinks get links => throw _privateConstructorUsedError;
  SharePermissions get permissions => throw _privateConstructorUsedError;
  ShareMetadata get metadata => throw _privateConstructorUsedError;
  String? get trackingToken => throw _privateConstructorUsedError;
  Map<String, int> get platformUsageRanking =>
      throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $SharePayloadCopyWith<SharePayload> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SharePayloadCopyWith<$Res> {
  factory $SharePayloadCopyWith(
          SharePayload value, $Res Function(SharePayload) then) =
      _$SharePayloadCopyWithImpl<$Res, SharePayload>;
  @useResult
  $Res call(
      {String videoId,
      ShareLinks links,
      SharePermissions permissions,
      ShareMetadata metadata,
      String? trackingToken,
      Map<String, int> platformUsageRanking});

  $ShareLinksCopyWith<$Res> get links;
  $SharePermissionsCopyWith<$Res> get permissions;
  $ShareMetadataCopyWith<$Res> get metadata;
}

/// @nodoc
class _$SharePayloadCopyWithImpl<$Res, $Val extends SharePayload>
    implements $SharePayloadCopyWith<$Res> {
  _$SharePayloadCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? videoId = null,
    Object? links = null,
    Object? permissions = null,
    Object? metadata = null,
    Object? trackingToken = freezed,
    Object? platformUsageRanking = null,
  }) {
    return _then(_value.copyWith(
      videoId: null == videoId
          ? _value.videoId
          : videoId // ignore: cast_nullable_to_non_nullable
              as String,
      links: null == links
          ? _value.links
          : links // ignore: cast_nullable_to_non_nullable
              as ShareLinks,
      permissions: null == permissions
          ? _value.permissions
          : permissions // ignore: cast_nullable_to_non_nullable
              as SharePermissions,
      metadata: null == metadata
          ? _value.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as ShareMetadata,
      trackingToken: freezed == trackingToken
          ? _value.trackingToken
          : trackingToken // ignore: cast_nullable_to_non_nullable
              as String?,
      platformUsageRanking: null == platformUsageRanking
          ? _value.platformUsageRanking
          : platformUsageRanking // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $ShareLinksCopyWith<$Res> get links {
    return $ShareLinksCopyWith<$Res>(_value.links, (value) {
      return _then(_value.copyWith(links: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $SharePermissionsCopyWith<$Res> get permissions {
    return $SharePermissionsCopyWith<$Res>(_value.permissions, (value) {
      return _then(_value.copyWith(permissions: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $ShareMetadataCopyWith<$Res> get metadata {
    return $ShareMetadataCopyWith<$Res>(_value.metadata, (value) {
      return _then(_value.copyWith(metadata: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$SharePayloadImplCopyWith<$Res>
    implements $SharePayloadCopyWith<$Res> {
  factory _$$SharePayloadImplCopyWith(
          _$SharePayloadImpl value, $Res Function(_$SharePayloadImpl) then) =
      __$$SharePayloadImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String videoId,
      ShareLinks links,
      SharePermissions permissions,
      ShareMetadata metadata,
      String? trackingToken,
      Map<String, int> platformUsageRanking});

  @override
  $ShareLinksCopyWith<$Res> get links;
  @override
  $SharePermissionsCopyWith<$Res> get permissions;
  @override
  $ShareMetadataCopyWith<$Res> get metadata;
}

/// @nodoc
class __$$SharePayloadImplCopyWithImpl<$Res>
    extends _$SharePayloadCopyWithImpl<$Res, _$SharePayloadImpl>
    implements _$$SharePayloadImplCopyWith<$Res> {
  __$$SharePayloadImplCopyWithImpl(
      _$SharePayloadImpl _value, $Res Function(_$SharePayloadImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? videoId = null,
    Object? links = null,
    Object? permissions = null,
    Object? metadata = null,
    Object? trackingToken = freezed,
    Object? platformUsageRanking = null,
  }) {
    return _then(_$SharePayloadImpl(
      videoId: null == videoId
          ? _value.videoId
          : videoId // ignore: cast_nullable_to_non_nullable
              as String,
      links: null == links
          ? _value.links
          : links // ignore: cast_nullable_to_non_nullable
              as ShareLinks,
      permissions: null == permissions
          ? _value.permissions
          : permissions // ignore: cast_nullable_to_non_nullable
              as SharePermissions,
      metadata: null == metadata
          ? _value.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as ShareMetadata,
      trackingToken: freezed == trackingToken
          ? _value.trackingToken
          : trackingToken // ignore: cast_nullable_to_non_nullable
              as String?,
      platformUsageRanking: null == platformUsageRanking
          ? _value._platformUsageRanking
          : platformUsageRanking // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SharePayloadImpl implements _SharePayload {
  const _$SharePayloadImpl(
      {required this.videoId,
      required this.links,
      required this.permissions,
      required this.metadata,
      this.trackingToken,
      final Map<String, int> platformUsageRanking = const {}})
      : _platformUsageRanking = platformUsageRanking;

  factory _$SharePayloadImpl.fromJson(Map<String, dynamic> json) =>
      _$$SharePayloadImplFromJson(json);

  @override
  final String videoId;
  @override
  final ShareLinks links;
  @override
  final SharePermissions permissions;
  @override
  final ShareMetadata metadata;
  @override
  final String? trackingToken;
  final Map<String, int> _platformUsageRanking;
  @override
  @JsonKey()
  Map<String, int> get platformUsageRanking {
    if (_platformUsageRanking is EqualUnmodifiableMapView)
      return _platformUsageRanking;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_platformUsageRanking);
  }

  @override
  String toString() {
    return 'SharePayload(videoId: $videoId, links: $links, permissions: $permissions, metadata: $metadata, trackingToken: $trackingToken, platformUsageRanking: $platformUsageRanking)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SharePayloadImpl &&
            (identical(other.videoId, videoId) || other.videoId == videoId) &&
            (identical(other.links, links) || other.links == links) &&
            (identical(other.permissions, permissions) ||
                other.permissions == permissions) &&
            (identical(other.metadata, metadata) ||
                other.metadata == metadata) &&
            (identical(other.trackingToken, trackingToken) ||
                other.trackingToken == trackingToken) &&
            const DeepCollectionEquality()
                .equals(other._platformUsageRanking, _platformUsageRanking));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      videoId,
      links,
      permissions,
      metadata,
      trackingToken,
      const DeepCollectionEquality().hash(_platformUsageRanking));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SharePayloadImplCopyWith<_$SharePayloadImpl> get copyWith =>
      __$$SharePayloadImplCopyWithImpl<_$SharePayloadImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SharePayloadImplToJson(
      this,
    );
  }
}

abstract class _SharePayload implements SharePayload {
  const factory _SharePayload(
      {required final String videoId,
      required final ShareLinks links,
      required final SharePermissions permissions,
      required final ShareMetadata metadata,
      final String? trackingToken,
      final Map<String, int> platformUsageRanking}) = _$SharePayloadImpl;

  factory _SharePayload.fromJson(Map<String, dynamic> json) =
      _$SharePayloadImpl.fromJson;

  @override
  String get videoId;
  @override
  ShareLinks get links;
  @override
  SharePermissions get permissions;
  @override
  ShareMetadata get metadata;
  @override
  String? get trackingToken;
  @override
  Map<String, int> get platformUsageRanking;
  @override
  @JsonKey(ignore: true)
  _$$SharePayloadImplCopyWith<_$SharePayloadImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ShareLinks _$ShareLinksFromJson(Map<String, dynamic> json) {
  return _ShareLinks.fromJson(json);
}

/// @nodoc
mixin _$ShareLinks {
  String get webShareUrl => throw _privateConstructorUsedError;
  String? get deepLink => throw _privateConstructorUsedError;
  String? get downloadUrl => throw _privateConstructorUsedError;
  String? get embedCode => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ShareLinksCopyWith<ShareLinks> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ShareLinksCopyWith<$Res> {
  factory $ShareLinksCopyWith(
          ShareLinks value, $Res Function(ShareLinks) then) =
      _$ShareLinksCopyWithImpl<$Res, ShareLinks>;
  @useResult
  $Res call(
      {String webShareUrl,
      String? deepLink,
      String? downloadUrl,
      String? embedCode});
}

/// @nodoc
class _$ShareLinksCopyWithImpl<$Res, $Val extends ShareLinks>
    implements $ShareLinksCopyWith<$Res> {
  _$ShareLinksCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? webShareUrl = null,
    Object? deepLink = freezed,
    Object? downloadUrl = freezed,
    Object? embedCode = freezed,
  }) {
    return _then(_value.copyWith(
      webShareUrl: null == webShareUrl
          ? _value.webShareUrl
          : webShareUrl // ignore: cast_nullable_to_non_nullable
              as String,
      deepLink: freezed == deepLink
          ? _value.deepLink
          : deepLink // ignore: cast_nullable_to_non_nullable
              as String?,
      downloadUrl: freezed == downloadUrl
          ? _value.downloadUrl
          : downloadUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      embedCode: freezed == embedCode
          ? _value.embedCode
          : embedCode // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ShareLinksImplCopyWith<$Res>
    implements $ShareLinksCopyWith<$Res> {
  factory _$$ShareLinksImplCopyWith(
          _$ShareLinksImpl value, $Res Function(_$ShareLinksImpl) then) =
      __$$ShareLinksImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String webShareUrl,
      String? deepLink,
      String? downloadUrl,
      String? embedCode});
}

/// @nodoc
class __$$ShareLinksImplCopyWithImpl<$Res>
    extends _$ShareLinksCopyWithImpl<$Res, _$ShareLinksImpl>
    implements _$$ShareLinksImplCopyWith<$Res> {
  __$$ShareLinksImplCopyWithImpl(
      _$ShareLinksImpl _value, $Res Function(_$ShareLinksImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? webShareUrl = null,
    Object? deepLink = freezed,
    Object? downloadUrl = freezed,
    Object? embedCode = freezed,
  }) {
    return _then(_$ShareLinksImpl(
      webShareUrl: null == webShareUrl
          ? _value.webShareUrl
          : webShareUrl // ignore: cast_nullable_to_non_nullable
              as String,
      deepLink: freezed == deepLink
          ? _value.deepLink
          : deepLink // ignore: cast_nullable_to_non_nullable
              as String?,
      downloadUrl: freezed == downloadUrl
          ? _value.downloadUrl
          : downloadUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      embedCode: freezed == embedCode
          ? _value.embedCode
          : embedCode // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ShareLinksImpl implements _ShareLinks {
  const _$ShareLinksImpl(
      {required this.webShareUrl,
      this.deepLink,
      this.downloadUrl,
      this.embedCode});

  factory _$ShareLinksImpl.fromJson(Map<String, dynamic> json) =>
      _$$ShareLinksImplFromJson(json);

  @override
  final String webShareUrl;
  @override
  final String? deepLink;
  @override
  final String? downloadUrl;
  @override
  final String? embedCode;

  @override
  String toString() {
    return 'ShareLinks(webShareUrl: $webShareUrl, deepLink: $deepLink, downloadUrl: $downloadUrl, embedCode: $embedCode)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ShareLinksImpl &&
            (identical(other.webShareUrl, webShareUrl) ||
                other.webShareUrl == webShareUrl) &&
            (identical(other.deepLink, deepLink) ||
                other.deepLink == deepLink) &&
            (identical(other.downloadUrl, downloadUrl) ||
                other.downloadUrl == downloadUrl) &&
            (identical(other.embedCode, embedCode) ||
                other.embedCode == embedCode));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, webShareUrl, deepLink, downloadUrl, embedCode);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ShareLinksImplCopyWith<_$ShareLinksImpl> get copyWith =>
      __$$ShareLinksImplCopyWithImpl<_$ShareLinksImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ShareLinksImplToJson(
      this,
    );
  }
}

abstract class _ShareLinks implements ShareLinks {
  const factory _ShareLinks(
      {required final String webShareUrl,
      final String? deepLink,
      final String? downloadUrl,
      final String? embedCode}) = _$ShareLinksImpl;

  factory _ShareLinks.fromJson(Map<String, dynamic> json) =
      _$ShareLinksImpl.fromJson;

  @override
  String get webShareUrl;
  @override
  String? get deepLink;
  @override
  String? get downloadUrl;
  @override
  String? get embedCode;
  @override
  @JsonKey(ignore: true)
  _$$ShareLinksImplCopyWith<_$ShareLinksImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SharePermissions _$SharePermissionsFromJson(Map<String, dynamic> json) {
  return _SharePermissions.fromJson(json);
}

/// @nodoc
mixin _$SharePermissions {
  bool get canShare => throw _privateConstructorUsedError;
  bool get canDownload => throw _privateConstructorUsedError;
  bool get canDuet => throw _privateConstructorUsedError;
  bool get canRemix => throw _privateConstructorUsedError;
  bool get canRepost => throw _privateConstructorUsedError;
  String? get restrictionReason => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $SharePermissionsCopyWith<SharePermissions> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SharePermissionsCopyWith<$Res> {
  factory $SharePermissionsCopyWith(
          SharePermissions value, $Res Function(SharePermissions) then) =
      _$SharePermissionsCopyWithImpl<$Res, SharePermissions>;
  @useResult
  $Res call(
      {bool canShare,
      bool canDownload,
      bool canDuet,
      bool canRemix,
      bool canRepost,
      String? restrictionReason});
}

/// @nodoc
class _$SharePermissionsCopyWithImpl<$Res, $Val extends SharePermissions>
    implements $SharePermissionsCopyWith<$Res> {
  _$SharePermissionsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? canShare = null,
    Object? canDownload = null,
    Object? canDuet = null,
    Object? canRemix = null,
    Object? canRepost = null,
    Object? restrictionReason = freezed,
  }) {
    return _then(_value.copyWith(
      canShare: null == canShare
          ? _value.canShare
          : canShare // ignore: cast_nullable_to_non_nullable
              as bool,
      canDownload: null == canDownload
          ? _value.canDownload
          : canDownload // ignore: cast_nullable_to_non_nullable
              as bool,
      canDuet: null == canDuet
          ? _value.canDuet
          : canDuet // ignore: cast_nullable_to_non_nullable
              as bool,
      canRemix: null == canRemix
          ? _value.canRemix
          : canRemix // ignore: cast_nullable_to_non_nullable
              as bool,
      canRepost: null == canRepost
          ? _value.canRepost
          : canRepost // ignore: cast_nullable_to_non_nullable
              as bool,
      restrictionReason: freezed == restrictionReason
          ? _value.restrictionReason
          : restrictionReason // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SharePermissionsImplCopyWith<$Res>
    implements $SharePermissionsCopyWith<$Res> {
  factory _$$SharePermissionsImplCopyWith(_$SharePermissionsImpl value,
          $Res Function(_$SharePermissionsImpl) then) =
      __$$SharePermissionsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool canShare,
      bool canDownload,
      bool canDuet,
      bool canRemix,
      bool canRepost,
      String? restrictionReason});
}

/// @nodoc
class __$$SharePermissionsImplCopyWithImpl<$Res>
    extends _$SharePermissionsCopyWithImpl<$Res, _$SharePermissionsImpl>
    implements _$$SharePermissionsImplCopyWith<$Res> {
  __$$SharePermissionsImplCopyWithImpl(_$SharePermissionsImpl _value,
      $Res Function(_$SharePermissionsImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? canShare = null,
    Object? canDownload = null,
    Object? canDuet = null,
    Object? canRemix = null,
    Object? canRepost = null,
    Object? restrictionReason = freezed,
  }) {
    return _then(_$SharePermissionsImpl(
      canShare: null == canShare
          ? _value.canShare
          : canShare // ignore: cast_nullable_to_non_nullable
              as bool,
      canDownload: null == canDownload
          ? _value.canDownload
          : canDownload // ignore: cast_nullable_to_non_nullable
              as bool,
      canDuet: null == canDuet
          ? _value.canDuet
          : canDuet // ignore: cast_nullable_to_non_nullable
              as bool,
      canRemix: null == canRemix
          ? _value.canRemix
          : canRemix // ignore: cast_nullable_to_non_nullable
              as bool,
      canRepost: null == canRepost
          ? _value.canRepost
          : canRepost // ignore: cast_nullable_to_non_nullable
              as bool,
      restrictionReason: freezed == restrictionReason
          ? _value.restrictionReason
          : restrictionReason // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SharePermissionsImpl implements _SharePermissions {
  const _$SharePermissionsImpl(
      {this.canShare = true,
      this.canDownload = true,
      this.canDuet = true,
      this.canRemix = true,
      this.canRepost = true,
      this.restrictionReason});

  factory _$SharePermissionsImpl.fromJson(Map<String, dynamic> json) =>
      _$$SharePermissionsImplFromJson(json);

  @override
  @JsonKey()
  final bool canShare;
  @override
  @JsonKey()
  final bool canDownload;
  @override
  @JsonKey()
  final bool canDuet;
  @override
  @JsonKey()
  final bool canRemix;
  @override
  @JsonKey()
  final bool canRepost;
  @override
  final String? restrictionReason;

  @override
  String toString() {
    return 'SharePermissions(canShare: $canShare, canDownload: $canDownload, canDuet: $canDuet, canRemix: $canRemix, canRepost: $canRepost, restrictionReason: $restrictionReason)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SharePermissionsImpl &&
            (identical(other.canShare, canShare) ||
                other.canShare == canShare) &&
            (identical(other.canDownload, canDownload) ||
                other.canDownload == canDownload) &&
            (identical(other.canDuet, canDuet) || other.canDuet == canDuet) &&
            (identical(other.canRemix, canRemix) ||
                other.canRemix == canRemix) &&
            (identical(other.canRepost, canRepost) ||
                other.canRepost == canRepost) &&
            (identical(other.restrictionReason, restrictionReason) ||
                other.restrictionReason == restrictionReason));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, canShare, canDownload, canDuet,
      canRemix, canRepost, restrictionReason);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SharePermissionsImplCopyWith<_$SharePermissionsImpl> get copyWith =>
      __$$SharePermissionsImplCopyWithImpl<_$SharePermissionsImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SharePermissionsImplToJson(
      this,
    );
  }
}

abstract class _SharePermissions implements SharePermissions {
  const factory _SharePermissions(
      {final bool canShare,
      final bool canDownload,
      final bool canDuet,
      final bool canRemix,
      final bool canRepost,
      final String? restrictionReason}) = _$SharePermissionsImpl;

  factory _SharePermissions.fromJson(Map<String, dynamic> json) =
      _$SharePermissionsImpl.fromJson;

  @override
  bool get canShare;
  @override
  bool get canDownload;
  @override
  bool get canDuet;
  @override
  bool get canRemix;
  @override
  bool get canRepost;
  @override
  String? get restrictionReason;
  @override
  @JsonKey(ignore: true)
  _$$SharePermissionsImplCopyWith<_$SharePermissionsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ShareMetadata _$ShareMetadataFromJson(Map<String, dynamic> json) {
  return _ShareMetadata.fromJson(json);
}

/// @nodoc
mixin _$ShareMetadata {
  String get creatorUsername => throw _privateConstructorUsedError;
  String get creatorDisplayName => throw _privateConstructorUsedError;
  String? get caption => throw _privateConstructorUsedError;
  String? get thumbnailUrl => throw _privateConstructorUsedError;
  List<String> get hashtags => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ShareMetadataCopyWith<ShareMetadata> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ShareMetadataCopyWith<$Res> {
  factory $ShareMetadataCopyWith(
          ShareMetadata value, $Res Function(ShareMetadata) then) =
      _$ShareMetadataCopyWithImpl<$Res, ShareMetadata>;
  @useResult
  $Res call(
      {String creatorUsername,
      String creatorDisplayName,
      String? caption,
      String? thumbnailUrl,
      List<String> hashtags,
      DateTime? createdAt});
}

/// @nodoc
class _$ShareMetadataCopyWithImpl<$Res, $Val extends ShareMetadata>
    implements $ShareMetadataCopyWith<$Res> {
  _$ShareMetadataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? creatorUsername = null,
    Object? creatorDisplayName = null,
    Object? caption = freezed,
    Object? thumbnailUrl = freezed,
    Object? hashtags = null,
    Object? createdAt = freezed,
  }) {
    return _then(_value.copyWith(
      creatorUsername: null == creatorUsername
          ? _value.creatorUsername
          : creatorUsername // ignore: cast_nullable_to_non_nullable
              as String,
      creatorDisplayName: null == creatorDisplayName
          ? _value.creatorDisplayName
          : creatorDisplayName // ignore: cast_nullable_to_non_nullable
              as String,
      caption: freezed == caption
          ? _value.caption
          : caption // ignore: cast_nullable_to_non_nullable
              as String?,
      thumbnailUrl: freezed == thumbnailUrl
          ? _value.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      hashtags: null == hashtags
          ? _value.hashtags
          : hashtags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ShareMetadataImplCopyWith<$Res>
    implements $ShareMetadataCopyWith<$Res> {
  factory _$$ShareMetadataImplCopyWith(
          _$ShareMetadataImpl value, $Res Function(_$ShareMetadataImpl) then) =
      __$$ShareMetadataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String creatorUsername,
      String creatorDisplayName,
      String? caption,
      String? thumbnailUrl,
      List<String> hashtags,
      DateTime? createdAt});
}

/// @nodoc
class __$$ShareMetadataImplCopyWithImpl<$Res>
    extends _$ShareMetadataCopyWithImpl<$Res, _$ShareMetadataImpl>
    implements _$$ShareMetadataImplCopyWith<$Res> {
  __$$ShareMetadataImplCopyWithImpl(
      _$ShareMetadataImpl _value, $Res Function(_$ShareMetadataImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? creatorUsername = null,
    Object? creatorDisplayName = null,
    Object? caption = freezed,
    Object? thumbnailUrl = freezed,
    Object? hashtags = null,
    Object? createdAt = freezed,
  }) {
    return _then(_$ShareMetadataImpl(
      creatorUsername: null == creatorUsername
          ? _value.creatorUsername
          : creatorUsername // ignore: cast_nullable_to_non_nullable
              as String,
      creatorDisplayName: null == creatorDisplayName
          ? _value.creatorDisplayName
          : creatorDisplayName // ignore: cast_nullable_to_non_nullable
              as String,
      caption: freezed == caption
          ? _value.caption
          : caption // ignore: cast_nullable_to_non_nullable
              as String?,
      thumbnailUrl: freezed == thumbnailUrl
          ? _value.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      hashtags: null == hashtags
          ? _value._hashtags
          : hashtags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ShareMetadataImpl implements _ShareMetadata {
  const _$ShareMetadataImpl(
      {required this.creatorUsername,
      required this.creatorDisplayName,
      this.caption,
      this.thumbnailUrl,
      final List<String> hashtags = const [],
      this.createdAt})
      : _hashtags = hashtags;

  factory _$ShareMetadataImpl.fromJson(Map<String, dynamic> json) =>
      _$$ShareMetadataImplFromJson(json);

  @override
  final String creatorUsername;
  @override
  final String creatorDisplayName;
  @override
  final String? caption;
  @override
  final String? thumbnailUrl;
  final List<String> _hashtags;
  @override
  @JsonKey()
  List<String> get hashtags {
    if (_hashtags is EqualUnmodifiableListView) return _hashtags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_hashtags);
  }

  @override
  final DateTime? createdAt;

  @override
  String toString() {
    return 'ShareMetadata(creatorUsername: $creatorUsername, creatorDisplayName: $creatorDisplayName, caption: $caption, thumbnailUrl: $thumbnailUrl, hashtags: $hashtags, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ShareMetadataImpl &&
            (identical(other.creatorUsername, creatorUsername) ||
                other.creatorUsername == creatorUsername) &&
            (identical(other.creatorDisplayName, creatorDisplayName) ||
                other.creatorDisplayName == creatorDisplayName) &&
            (identical(other.caption, caption) || other.caption == caption) &&
            (identical(other.thumbnailUrl, thumbnailUrl) ||
                other.thumbnailUrl == thumbnailUrl) &&
            const DeepCollectionEquality().equals(other._hashtags, _hashtags) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      creatorUsername,
      creatorDisplayName,
      caption,
      thumbnailUrl,
      const DeepCollectionEquality().hash(_hashtags),
      createdAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ShareMetadataImplCopyWith<_$ShareMetadataImpl> get copyWith =>
      __$$ShareMetadataImplCopyWithImpl<_$ShareMetadataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ShareMetadataImplToJson(
      this,
    );
  }
}

abstract class _ShareMetadata implements ShareMetadata {
  const factory _ShareMetadata(
      {required final String creatorUsername,
      required final String creatorDisplayName,
      final String? caption,
      final String? thumbnailUrl,
      final List<String> hashtags,
      final DateTime? createdAt}) = _$ShareMetadataImpl;

  factory _ShareMetadata.fromJson(Map<String, dynamic> json) =
      _$ShareMetadataImpl.fromJson;

  @override
  String get creatorUsername;
  @override
  String get creatorDisplayName;
  @override
  String? get caption;
  @override
  String? get thumbnailUrl;
  @override
  List<String> get hashtags;
  @override
  DateTime? get createdAt;
  @override
  @JsonKey(ignore: true)
  _$$ShareMetadataImplCopyWith<_$ShareMetadataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
