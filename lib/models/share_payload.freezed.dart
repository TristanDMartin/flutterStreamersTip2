// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'share_payload.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SharePayload {
  String get videoId;
  ShareLinks get links;
  SharePermissions get permissions;
  ShareMetadata get metadata;
  String? get trackingToken;
  Map<String, int> get platformUsageRanking;

  /// Create a copy of SharePayload
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SharePayloadCopyWith<SharePayload> get copyWith =>
      _$SharePayloadCopyWithImpl<SharePayload>(
          this as SharePayload, _$identity);

  /// Serializes this SharePayload to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SharePayload &&
            (identical(other.videoId, videoId) || other.videoId == videoId) &&
            (identical(other.links, links) || other.links == links) &&
            (identical(other.permissions, permissions) ||
                other.permissions == permissions) &&
            (identical(other.metadata, metadata) ||
                other.metadata == metadata) &&
            (identical(other.trackingToken, trackingToken) ||
                other.trackingToken == trackingToken) &&
            const DeepCollectionEquality()
                .equals(other.platformUsageRanking, platformUsageRanking));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      videoId,
      links,
      permissions,
      metadata,
      trackingToken,
      const DeepCollectionEquality().hash(platformUsageRanking));

  @override
  String toString() {
    return 'SharePayload(videoId: $videoId, links: $links, permissions: $permissions, metadata: $metadata, trackingToken: $trackingToken, platformUsageRanking: $platformUsageRanking)';
  }
}

/// @nodoc
abstract mixin class $SharePayloadCopyWith<$Res> {
  factory $SharePayloadCopyWith(
          SharePayload value, $Res Function(SharePayload) _then) =
      _$SharePayloadCopyWithImpl;
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
class _$SharePayloadCopyWithImpl<$Res> implements $SharePayloadCopyWith<$Res> {
  _$SharePayloadCopyWithImpl(this._self, this._then);

  final SharePayload _self;
  final $Res Function(SharePayload) _then;

  /// Create a copy of SharePayload
  /// with the given fields replaced by the non-null parameter values.
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
    return _then(_self.copyWith(
      videoId: null == videoId
          ? _self.videoId
          : videoId // ignore: cast_nullable_to_non_nullable
              as String,
      links: null == links
          ? _self.links
          : links // ignore: cast_nullable_to_non_nullable
              as ShareLinks,
      permissions: null == permissions
          ? _self.permissions
          : permissions // ignore: cast_nullable_to_non_nullable
              as SharePermissions,
      metadata: null == metadata
          ? _self.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as ShareMetadata,
      trackingToken: freezed == trackingToken
          ? _self.trackingToken
          : trackingToken // ignore: cast_nullable_to_non_nullable
              as String?,
      platformUsageRanking: null == platformUsageRanking
          ? _self.platformUsageRanking
          : platformUsageRanking // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
    ));
  }

  /// Create a copy of SharePayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ShareLinksCopyWith<$Res> get links {
    return $ShareLinksCopyWith<$Res>(_self.links, (value) {
      return _then(_self.copyWith(links: value));
    });
  }

  /// Create a copy of SharePayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SharePermissionsCopyWith<$Res> get permissions {
    return $SharePermissionsCopyWith<$Res>(_self.permissions, (value) {
      return _then(_self.copyWith(permissions: value));
    });
  }

  /// Create a copy of SharePayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ShareMetadataCopyWith<$Res> get metadata {
    return $ShareMetadataCopyWith<$Res>(_self.metadata, (value) {
      return _then(_self.copyWith(metadata: value));
    });
  }
}

/// Adds pattern-matching-related methods to [SharePayload].
extension SharePayloadPatterns on SharePayload {
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
    TResult Function(_SharePayload value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SharePayload() when $default != null:
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
    TResult Function(_SharePayload value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SharePayload():
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
    TResult? Function(_SharePayload value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SharePayload() when $default != null:
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
            String videoId,
            ShareLinks links,
            SharePermissions permissions,
            ShareMetadata metadata,
            String? trackingToken,
            Map<String, int> platformUsageRanking)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SharePayload() when $default != null:
        return $default(_that.videoId, _that.links, _that.permissions,
            _that.metadata, _that.trackingToken, _that.platformUsageRanking);
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
            String videoId,
            ShareLinks links,
            SharePermissions permissions,
            ShareMetadata metadata,
            String? trackingToken,
            Map<String, int> platformUsageRanking)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SharePayload():
        return $default(_that.videoId, _that.links, _that.permissions,
            _that.metadata, _that.trackingToken, _that.platformUsageRanking);
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
            String videoId,
            ShareLinks links,
            SharePermissions permissions,
            ShareMetadata metadata,
            String? trackingToken,
            Map<String, int> platformUsageRanking)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SharePayload() when $default != null:
        return $default(_that.videoId, _that.links, _that.permissions,
            _that.metadata, _that.trackingToken, _that.platformUsageRanking);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SharePayload implements SharePayload {
  const _SharePayload(
      {required this.videoId,
      required this.links,
      required this.permissions,
      required this.metadata,
      this.trackingToken,
      final Map<String, int> platformUsageRanking = const {}})
      : _platformUsageRanking = platformUsageRanking;
  factory _SharePayload.fromJson(Map<String, dynamic> json) =>
      _$SharePayloadFromJson(json);

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

  /// Create a copy of SharePayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SharePayloadCopyWith<_SharePayload> get copyWith =>
      __$SharePayloadCopyWithImpl<_SharePayload>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SharePayloadToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SharePayload &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      videoId,
      links,
      permissions,
      metadata,
      trackingToken,
      const DeepCollectionEquality().hash(_platformUsageRanking));

  @override
  String toString() {
    return 'SharePayload(videoId: $videoId, links: $links, permissions: $permissions, metadata: $metadata, trackingToken: $trackingToken, platformUsageRanking: $platformUsageRanking)';
  }
}

/// @nodoc
abstract mixin class _$SharePayloadCopyWith<$Res>
    implements $SharePayloadCopyWith<$Res> {
  factory _$SharePayloadCopyWith(
          _SharePayload value, $Res Function(_SharePayload) _then) =
      __$SharePayloadCopyWithImpl;
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
class __$SharePayloadCopyWithImpl<$Res>
    implements _$SharePayloadCopyWith<$Res> {
  __$SharePayloadCopyWithImpl(this._self, this._then);

  final _SharePayload _self;
  final $Res Function(_SharePayload) _then;

  /// Create a copy of SharePayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? videoId = null,
    Object? links = null,
    Object? permissions = null,
    Object? metadata = null,
    Object? trackingToken = freezed,
    Object? platformUsageRanking = null,
  }) {
    return _then(_SharePayload(
      videoId: null == videoId
          ? _self.videoId
          : videoId // ignore: cast_nullable_to_non_nullable
              as String,
      links: null == links
          ? _self.links
          : links // ignore: cast_nullable_to_non_nullable
              as ShareLinks,
      permissions: null == permissions
          ? _self.permissions
          : permissions // ignore: cast_nullable_to_non_nullable
              as SharePermissions,
      metadata: null == metadata
          ? _self.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as ShareMetadata,
      trackingToken: freezed == trackingToken
          ? _self.trackingToken
          : trackingToken // ignore: cast_nullable_to_non_nullable
              as String?,
      platformUsageRanking: null == platformUsageRanking
          ? _self._platformUsageRanking
          : platformUsageRanking // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
    ));
  }

  /// Create a copy of SharePayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ShareLinksCopyWith<$Res> get links {
    return $ShareLinksCopyWith<$Res>(_self.links, (value) {
      return _then(_self.copyWith(links: value));
    });
  }

  /// Create a copy of SharePayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SharePermissionsCopyWith<$Res> get permissions {
    return $SharePermissionsCopyWith<$Res>(_self.permissions, (value) {
      return _then(_self.copyWith(permissions: value));
    });
  }

  /// Create a copy of SharePayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ShareMetadataCopyWith<$Res> get metadata {
    return $ShareMetadataCopyWith<$Res>(_self.metadata, (value) {
      return _then(_self.copyWith(metadata: value));
    });
  }
}

/// @nodoc
mixin _$ShareLinks {
  String get webShareUrl;
  String? get deepLink;
  String? get downloadUrl;
  String? get embedCode;

  /// Create a copy of ShareLinks
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ShareLinksCopyWith<ShareLinks> get copyWith =>
      _$ShareLinksCopyWithImpl<ShareLinks>(this as ShareLinks, _$identity);

  /// Serializes this ShareLinks to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ShareLinks &&
            (identical(other.webShareUrl, webShareUrl) ||
                other.webShareUrl == webShareUrl) &&
            (identical(other.deepLink, deepLink) ||
                other.deepLink == deepLink) &&
            (identical(other.downloadUrl, downloadUrl) ||
                other.downloadUrl == downloadUrl) &&
            (identical(other.embedCode, embedCode) ||
                other.embedCode == embedCode));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, webShareUrl, deepLink, downloadUrl, embedCode);

  @override
  String toString() {
    return 'ShareLinks(webShareUrl: $webShareUrl, deepLink: $deepLink, downloadUrl: $downloadUrl, embedCode: $embedCode)';
  }
}

/// @nodoc
abstract mixin class $ShareLinksCopyWith<$Res> {
  factory $ShareLinksCopyWith(
          ShareLinks value, $Res Function(ShareLinks) _then) =
      _$ShareLinksCopyWithImpl;
  @useResult
  $Res call(
      {String webShareUrl,
      String? deepLink,
      String? downloadUrl,
      String? embedCode});
}

/// @nodoc
class _$ShareLinksCopyWithImpl<$Res> implements $ShareLinksCopyWith<$Res> {
  _$ShareLinksCopyWithImpl(this._self, this._then);

  final ShareLinks _self;
  final $Res Function(ShareLinks) _then;

  /// Create a copy of ShareLinks
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? webShareUrl = null,
    Object? deepLink = freezed,
    Object? downloadUrl = freezed,
    Object? embedCode = freezed,
  }) {
    return _then(_self.copyWith(
      webShareUrl: null == webShareUrl
          ? _self.webShareUrl
          : webShareUrl // ignore: cast_nullable_to_non_nullable
              as String,
      deepLink: freezed == deepLink
          ? _self.deepLink
          : deepLink // ignore: cast_nullable_to_non_nullable
              as String?,
      downloadUrl: freezed == downloadUrl
          ? _self.downloadUrl
          : downloadUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      embedCode: freezed == embedCode
          ? _self.embedCode
          : embedCode // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [ShareLinks].
extension ShareLinksPatterns on ShareLinks {
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
    TResult Function(_ShareLinks value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ShareLinks() when $default != null:
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
    TResult Function(_ShareLinks value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ShareLinks():
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
    TResult? Function(_ShareLinks value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ShareLinks() when $default != null:
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
    TResult Function(String webShareUrl, String? deepLink, String? downloadUrl,
            String? embedCode)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ShareLinks() when $default != null:
        return $default(_that.webShareUrl, _that.deepLink, _that.downloadUrl,
            _that.embedCode);
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
    TResult Function(String webShareUrl, String? deepLink, String? downloadUrl,
            String? embedCode)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ShareLinks():
        return $default(_that.webShareUrl, _that.deepLink, _that.downloadUrl,
            _that.embedCode);
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
    TResult? Function(String webShareUrl, String? deepLink, String? downloadUrl,
            String? embedCode)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ShareLinks() when $default != null:
        return $default(_that.webShareUrl, _that.deepLink, _that.downloadUrl,
            _that.embedCode);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ShareLinks implements ShareLinks {
  const _ShareLinks(
      {required this.webShareUrl,
      this.deepLink,
      this.downloadUrl,
      this.embedCode});
  factory _ShareLinks.fromJson(Map<String, dynamic> json) =>
      _$ShareLinksFromJson(json);

  @override
  final String webShareUrl;
  @override
  final String? deepLink;
  @override
  final String? downloadUrl;
  @override
  final String? embedCode;

  /// Create a copy of ShareLinks
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ShareLinksCopyWith<_ShareLinks> get copyWith =>
      __$ShareLinksCopyWithImpl<_ShareLinks>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ShareLinksToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ShareLinks &&
            (identical(other.webShareUrl, webShareUrl) ||
                other.webShareUrl == webShareUrl) &&
            (identical(other.deepLink, deepLink) ||
                other.deepLink == deepLink) &&
            (identical(other.downloadUrl, downloadUrl) ||
                other.downloadUrl == downloadUrl) &&
            (identical(other.embedCode, embedCode) ||
                other.embedCode == embedCode));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, webShareUrl, deepLink, downloadUrl, embedCode);

  @override
  String toString() {
    return 'ShareLinks(webShareUrl: $webShareUrl, deepLink: $deepLink, downloadUrl: $downloadUrl, embedCode: $embedCode)';
  }
}

/// @nodoc
abstract mixin class _$ShareLinksCopyWith<$Res>
    implements $ShareLinksCopyWith<$Res> {
  factory _$ShareLinksCopyWith(
          _ShareLinks value, $Res Function(_ShareLinks) _then) =
      __$ShareLinksCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String webShareUrl,
      String? deepLink,
      String? downloadUrl,
      String? embedCode});
}

/// @nodoc
class __$ShareLinksCopyWithImpl<$Res> implements _$ShareLinksCopyWith<$Res> {
  __$ShareLinksCopyWithImpl(this._self, this._then);

  final _ShareLinks _self;
  final $Res Function(_ShareLinks) _then;

  /// Create a copy of ShareLinks
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? webShareUrl = null,
    Object? deepLink = freezed,
    Object? downloadUrl = freezed,
    Object? embedCode = freezed,
  }) {
    return _then(_ShareLinks(
      webShareUrl: null == webShareUrl
          ? _self.webShareUrl
          : webShareUrl // ignore: cast_nullable_to_non_nullable
              as String,
      deepLink: freezed == deepLink
          ? _self.deepLink
          : deepLink // ignore: cast_nullable_to_non_nullable
              as String?,
      downloadUrl: freezed == downloadUrl
          ? _self.downloadUrl
          : downloadUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      embedCode: freezed == embedCode
          ? _self.embedCode
          : embedCode // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
mixin _$SharePermissions {
  bool get canShare;
  bool get canDownload;
  bool get canDuet;
  bool get canRemix;
  bool get canRepost;
  String? get restrictionReason;

  /// Create a copy of SharePermissions
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SharePermissionsCopyWith<SharePermissions> get copyWith =>
      _$SharePermissionsCopyWithImpl<SharePermissions>(
          this as SharePermissions, _$identity);

  /// Serializes this SharePermissions to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SharePermissions &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, canShare, canDownload, canDuet,
      canRemix, canRepost, restrictionReason);

  @override
  String toString() {
    return 'SharePermissions(canShare: $canShare, canDownload: $canDownload, canDuet: $canDuet, canRemix: $canRemix, canRepost: $canRepost, restrictionReason: $restrictionReason)';
  }
}

/// @nodoc
abstract mixin class $SharePermissionsCopyWith<$Res> {
  factory $SharePermissionsCopyWith(
          SharePermissions value, $Res Function(SharePermissions) _then) =
      _$SharePermissionsCopyWithImpl;
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
class _$SharePermissionsCopyWithImpl<$Res>
    implements $SharePermissionsCopyWith<$Res> {
  _$SharePermissionsCopyWithImpl(this._self, this._then);

  final SharePermissions _self;
  final $Res Function(SharePermissions) _then;

  /// Create a copy of SharePermissions
  /// with the given fields replaced by the non-null parameter values.
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
    return _then(_self.copyWith(
      canShare: null == canShare
          ? _self.canShare
          : canShare // ignore: cast_nullable_to_non_nullable
              as bool,
      canDownload: null == canDownload
          ? _self.canDownload
          : canDownload // ignore: cast_nullable_to_non_nullable
              as bool,
      canDuet: null == canDuet
          ? _self.canDuet
          : canDuet // ignore: cast_nullable_to_non_nullable
              as bool,
      canRemix: null == canRemix
          ? _self.canRemix
          : canRemix // ignore: cast_nullable_to_non_nullable
              as bool,
      canRepost: null == canRepost
          ? _self.canRepost
          : canRepost // ignore: cast_nullable_to_non_nullable
              as bool,
      restrictionReason: freezed == restrictionReason
          ? _self.restrictionReason
          : restrictionReason // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [SharePermissions].
extension SharePermissionsPatterns on SharePermissions {
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
    TResult Function(_SharePermissions value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SharePermissions() when $default != null:
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
    TResult Function(_SharePermissions value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SharePermissions():
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
    TResult? Function(_SharePermissions value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SharePermissions() when $default != null:
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
    TResult Function(bool canShare, bool canDownload, bool canDuet,
            bool canRemix, bool canRepost, String? restrictionReason)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SharePermissions() when $default != null:
        return $default(_that.canShare, _that.canDownload, _that.canDuet,
            _that.canRemix, _that.canRepost, _that.restrictionReason);
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
    TResult Function(bool canShare, bool canDownload, bool canDuet,
            bool canRemix, bool canRepost, String? restrictionReason)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SharePermissions():
        return $default(_that.canShare, _that.canDownload, _that.canDuet,
            _that.canRemix, _that.canRepost, _that.restrictionReason);
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
    TResult? Function(bool canShare, bool canDownload, bool canDuet,
            bool canRemix, bool canRepost, String? restrictionReason)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SharePermissions() when $default != null:
        return $default(_that.canShare, _that.canDownload, _that.canDuet,
            _that.canRemix, _that.canRepost, _that.restrictionReason);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SharePermissions implements SharePermissions {
  const _SharePermissions(
      {this.canShare = true,
      this.canDownload = true,
      this.canDuet = true,
      this.canRemix = true,
      this.canRepost = true,
      this.restrictionReason});
  factory _SharePermissions.fromJson(Map<String, dynamic> json) =>
      _$SharePermissionsFromJson(json);

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

  /// Create a copy of SharePermissions
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SharePermissionsCopyWith<_SharePermissions> get copyWith =>
      __$SharePermissionsCopyWithImpl<_SharePermissions>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SharePermissionsToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SharePermissions &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, canShare, canDownload, canDuet,
      canRemix, canRepost, restrictionReason);

  @override
  String toString() {
    return 'SharePermissions(canShare: $canShare, canDownload: $canDownload, canDuet: $canDuet, canRemix: $canRemix, canRepost: $canRepost, restrictionReason: $restrictionReason)';
  }
}

/// @nodoc
abstract mixin class _$SharePermissionsCopyWith<$Res>
    implements $SharePermissionsCopyWith<$Res> {
  factory _$SharePermissionsCopyWith(
          _SharePermissions value, $Res Function(_SharePermissions) _then) =
      __$SharePermissionsCopyWithImpl;
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
class __$SharePermissionsCopyWithImpl<$Res>
    implements _$SharePermissionsCopyWith<$Res> {
  __$SharePermissionsCopyWithImpl(this._self, this._then);

  final _SharePermissions _self;
  final $Res Function(_SharePermissions) _then;

  /// Create a copy of SharePermissions
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? canShare = null,
    Object? canDownload = null,
    Object? canDuet = null,
    Object? canRemix = null,
    Object? canRepost = null,
    Object? restrictionReason = freezed,
  }) {
    return _then(_SharePermissions(
      canShare: null == canShare
          ? _self.canShare
          : canShare // ignore: cast_nullable_to_non_nullable
              as bool,
      canDownload: null == canDownload
          ? _self.canDownload
          : canDownload // ignore: cast_nullable_to_non_nullable
              as bool,
      canDuet: null == canDuet
          ? _self.canDuet
          : canDuet // ignore: cast_nullable_to_non_nullable
              as bool,
      canRemix: null == canRemix
          ? _self.canRemix
          : canRemix // ignore: cast_nullable_to_non_nullable
              as bool,
      canRepost: null == canRepost
          ? _self.canRepost
          : canRepost // ignore: cast_nullable_to_non_nullable
              as bool,
      restrictionReason: freezed == restrictionReason
          ? _self.restrictionReason
          : restrictionReason // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
mixin _$ShareMetadata {
  String get creatorUsername;
  String get creatorDisplayName;
  String? get caption;
  String? get thumbnailUrl;
  List<String> get hashtags;
  DateTime? get createdAt;

  /// Create a copy of ShareMetadata
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ShareMetadataCopyWith<ShareMetadata> get copyWith =>
      _$ShareMetadataCopyWithImpl<ShareMetadata>(
          this as ShareMetadata, _$identity);

  /// Serializes this ShareMetadata to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ShareMetadata &&
            (identical(other.creatorUsername, creatorUsername) ||
                other.creatorUsername == creatorUsername) &&
            (identical(other.creatorDisplayName, creatorDisplayName) ||
                other.creatorDisplayName == creatorDisplayName) &&
            (identical(other.caption, caption) || other.caption == caption) &&
            (identical(other.thumbnailUrl, thumbnailUrl) ||
                other.thumbnailUrl == thumbnailUrl) &&
            const DeepCollectionEquality().equals(other.hashtags, hashtags) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      creatorUsername,
      creatorDisplayName,
      caption,
      thumbnailUrl,
      const DeepCollectionEquality().hash(hashtags),
      createdAt);

  @override
  String toString() {
    return 'ShareMetadata(creatorUsername: $creatorUsername, creatorDisplayName: $creatorDisplayName, caption: $caption, thumbnailUrl: $thumbnailUrl, hashtags: $hashtags, createdAt: $createdAt)';
  }
}

/// @nodoc
abstract mixin class $ShareMetadataCopyWith<$Res> {
  factory $ShareMetadataCopyWith(
          ShareMetadata value, $Res Function(ShareMetadata) _then) =
      _$ShareMetadataCopyWithImpl;
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
class _$ShareMetadataCopyWithImpl<$Res>
    implements $ShareMetadataCopyWith<$Res> {
  _$ShareMetadataCopyWithImpl(this._self, this._then);

  final ShareMetadata _self;
  final $Res Function(ShareMetadata) _then;

  /// Create a copy of ShareMetadata
  /// with the given fields replaced by the non-null parameter values.
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
    return _then(_self.copyWith(
      creatorUsername: null == creatorUsername
          ? _self.creatorUsername
          : creatorUsername // ignore: cast_nullable_to_non_nullable
              as String,
      creatorDisplayName: null == creatorDisplayName
          ? _self.creatorDisplayName
          : creatorDisplayName // ignore: cast_nullable_to_non_nullable
              as String,
      caption: freezed == caption
          ? _self.caption
          : caption // ignore: cast_nullable_to_non_nullable
              as String?,
      thumbnailUrl: freezed == thumbnailUrl
          ? _self.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      hashtags: null == hashtags
          ? _self.hashtags
          : hashtags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      createdAt: freezed == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// Adds pattern-matching-related methods to [ShareMetadata].
extension ShareMetadataPatterns on ShareMetadata {
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
    TResult Function(_ShareMetadata value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ShareMetadata() when $default != null:
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
    TResult Function(_ShareMetadata value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ShareMetadata():
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
    TResult? Function(_ShareMetadata value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ShareMetadata() when $default != null:
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
            String creatorUsername,
            String creatorDisplayName,
            String? caption,
            String? thumbnailUrl,
            List<String> hashtags,
            DateTime? createdAt)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ShareMetadata() when $default != null:
        return $default(_that.creatorUsername, _that.creatorDisplayName,
            _that.caption, _that.thumbnailUrl, _that.hashtags, _that.createdAt);
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
            String creatorUsername,
            String creatorDisplayName,
            String? caption,
            String? thumbnailUrl,
            List<String> hashtags,
            DateTime? createdAt)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ShareMetadata():
        return $default(_that.creatorUsername, _that.creatorDisplayName,
            _that.caption, _that.thumbnailUrl, _that.hashtags, _that.createdAt);
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
            String creatorUsername,
            String creatorDisplayName,
            String? caption,
            String? thumbnailUrl,
            List<String> hashtags,
            DateTime? createdAt)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ShareMetadata() when $default != null:
        return $default(_that.creatorUsername, _that.creatorDisplayName,
            _that.caption, _that.thumbnailUrl, _that.hashtags, _that.createdAt);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ShareMetadata implements ShareMetadata {
  const _ShareMetadata(
      {required this.creatorUsername,
      required this.creatorDisplayName,
      this.caption,
      this.thumbnailUrl,
      final List<String> hashtags = const [],
      this.createdAt})
      : _hashtags = hashtags;
  factory _ShareMetadata.fromJson(Map<String, dynamic> json) =>
      _$ShareMetadataFromJson(json);

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

  /// Create a copy of ShareMetadata
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ShareMetadataCopyWith<_ShareMetadata> get copyWith =>
      __$ShareMetadataCopyWithImpl<_ShareMetadata>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ShareMetadataToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ShareMetadata &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      creatorUsername,
      creatorDisplayName,
      caption,
      thumbnailUrl,
      const DeepCollectionEquality().hash(_hashtags),
      createdAt);

  @override
  String toString() {
    return 'ShareMetadata(creatorUsername: $creatorUsername, creatorDisplayName: $creatorDisplayName, caption: $caption, thumbnailUrl: $thumbnailUrl, hashtags: $hashtags, createdAt: $createdAt)';
  }
}

/// @nodoc
abstract mixin class _$ShareMetadataCopyWith<$Res>
    implements $ShareMetadataCopyWith<$Res> {
  factory _$ShareMetadataCopyWith(
          _ShareMetadata value, $Res Function(_ShareMetadata) _then) =
      __$ShareMetadataCopyWithImpl;
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
class __$ShareMetadataCopyWithImpl<$Res>
    implements _$ShareMetadataCopyWith<$Res> {
  __$ShareMetadataCopyWithImpl(this._self, this._then);

  final _ShareMetadata _self;
  final $Res Function(_ShareMetadata) _then;

  /// Create a copy of ShareMetadata
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? creatorUsername = null,
    Object? creatorDisplayName = null,
    Object? caption = freezed,
    Object? thumbnailUrl = freezed,
    Object? hashtags = null,
    Object? createdAt = freezed,
  }) {
    return _then(_ShareMetadata(
      creatorUsername: null == creatorUsername
          ? _self.creatorUsername
          : creatorUsername // ignore: cast_nullable_to_non_nullable
              as String,
      creatorDisplayName: null == creatorDisplayName
          ? _self.creatorDisplayName
          : creatorDisplayName // ignore: cast_nullable_to_non_nullable
              as String,
      caption: freezed == caption
          ? _self.caption
          : caption // ignore: cast_nullable_to_non_nullable
              as String?,
      thumbnailUrl: freezed == thumbnailUrl
          ? _self.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      hashtags: null == hashtags
          ? _self._hashtags
          : hashtags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      createdAt: freezed == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

// dart format on
