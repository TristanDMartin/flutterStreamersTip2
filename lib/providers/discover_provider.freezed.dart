// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'discover_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DiscoverState {
  List<TrendingCreator> get trendingCreators;
  List<Category> get categories;
  List<RecommendedContent> get recommendedContent;
  List<SearchResult> get searchResults;
  bool get isSearching;
  List<VideoClip> get clips;
  bool get isLoadingTrendingCreators;
  bool get trendingCreatorsLoadFailed;
  Map<String, int> get userScrollBehavior;
  Map<String, double> get lowViewedRatio;

  /// Create a copy of DiscoverState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DiscoverStateCopyWith<DiscoverState> get copyWith =>
      _$DiscoverStateCopyWithImpl<DiscoverState>(
          this as DiscoverState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DiscoverState &&
            const DeepCollectionEquality()
                .equals(other.trendingCreators, trendingCreators) &&
            const DeepCollectionEquality()
                .equals(other.categories, categories) &&
            const DeepCollectionEquality()
                .equals(other.recommendedContent, recommendedContent) &&
            const DeepCollectionEquality()
                .equals(other.searchResults, searchResults) &&
            (identical(other.isSearching, isSearching) ||
                other.isSearching == isSearching) &&
            const DeepCollectionEquality().equals(other.clips, clips) &&
            (identical(other.isLoadingTrendingCreators,
                    isLoadingTrendingCreators) ||
                other.isLoadingTrendingCreators == isLoadingTrendingCreators) &&
            (identical(other.trendingCreatorsLoadFailed,
                    trendingCreatorsLoadFailed) ||
                other.trendingCreatorsLoadFailed ==
                    trendingCreatorsLoadFailed) &&
            const DeepCollectionEquality()
                .equals(other.userScrollBehavior, userScrollBehavior) &&
            const DeepCollectionEquality()
                .equals(other.lowViewedRatio, lowViewedRatio));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(trendingCreators),
      const DeepCollectionEquality().hash(categories),
      const DeepCollectionEquality().hash(recommendedContent),
      const DeepCollectionEquality().hash(searchResults),
      isSearching,
      const DeepCollectionEquality().hash(clips),
      isLoadingTrendingCreators,
      trendingCreatorsLoadFailed,
      const DeepCollectionEquality().hash(userScrollBehavior),
      const DeepCollectionEquality().hash(lowViewedRatio));

  @override
  String toString() {
    return 'DiscoverState(trendingCreators: $trendingCreators, categories: $categories, recommendedContent: $recommendedContent, searchResults: $searchResults, isSearching: $isSearching, clips: $clips, isLoadingTrendingCreators: $isLoadingTrendingCreators, trendingCreatorsLoadFailed: $trendingCreatorsLoadFailed, userScrollBehavior: $userScrollBehavior, lowViewedRatio: $lowViewedRatio)';
  }
}

/// @nodoc
abstract mixin class $DiscoverStateCopyWith<$Res> {
  factory $DiscoverStateCopyWith(
          DiscoverState value, $Res Function(DiscoverState) _then) =
      _$DiscoverStateCopyWithImpl;
  @useResult
  $Res call(
      {List<TrendingCreator> trendingCreators,
      List<Category> categories,
      List<RecommendedContent> recommendedContent,
      List<SearchResult> searchResults,
      bool isSearching,
      List<VideoClip> clips,
      bool isLoadingTrendingCreators,
      bool trendingCreatorsLoadFailed,
      Map<String, int> userScrollBehavior,
      Map<String, double> lowViewedRatio});
}

/// @nodoc
class _$DiscoverStateCopyWithImpl<$Res>
    implements $DiscoverStateCopyWith<$Res> {
  _$DiscoverStateCopyWithImpl(this._self, this._then);

  final DiscoverState _self;
  final $Res Function(DiscoverState) _then;

  /// Create a copy of DiscoverState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? trendingCreators = null,
    Object? categories = null,
    Object? recommendedContent = null,
    Object? searchResults = null,
    Object? isSearching = null,
    Object? clips = null,
    Object? isLoadingTrendingCreators = null,
    Object? trendingCreatorsLoadFailed = null,
    Object? userScrollBehavior = null,
    Object? lowViewedRatio = null,
  }) {
    return _then(_self.copyWith(
      trendingCreators: null == trendingCreators
          ? _self.trendingCreators
          : trendingCreators // ignore: cast_nullable_to_non_nullable
              as List<TrendingCreator>,
      categories: null == categories
          ? _self.categories
          : categories // ignore: cast_nullable_to_non_nullable
              as List<Category>,
      recommendedContent: null == recommendedContent
          ? _self.recommendedContent
          : recommendedContent // ignore: cast_nullable_to_non_nullable
              as List<RecommendedContent>,
      searchResults: null == searchResults
          ? _self.searchResults
          : searchResults // ignore: cast_nullable_to_non_nullable
              as List<SearchResult>,
      isSearching: null == isSearching
          ? _self.isSearching
          : isSearching // ignore: cast_nullable_to_non_nullable
              as bool,
      clips: null == clips
          ? _self.clips
          : clips // ignore: cast_nullable_to_non_nullable
              as List<VideoClip>,
      isLoadingTrendingCreators: null == isLoadingTrendingCreators
          ? _self.isLoadingTrendingCreators
          : isLoadingTrendingCreators // ignore: cast_nullable_to_non_nullable
              as bool,
      trendingCreatorsLoadFailed: null == trendingCreatorsLoadFailed
          ? _self.trendingCreatorsLoadFailed
          : trendingCreatorsLoadFailed // ignore: cast_nullable_to_non_nullable
              as bool,
      userScrollBehavior: null == userScrollBehavior
          ? _self.userScrollBehavior
          : userScrollBehavior // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      lowViewedRatio: null == lowViewedRatio
          ? _self.lowViewedRatio
          : lowViewedRatio // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
    ));
  }
}

/// Adds pattern-matching-related methods to [DiscoverState].
extension DiscoverStatePatterns on DiscoverState {
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
    TResult Function(_DiscoverState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DiscoverState() when $default != null:
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
    TResult Function(_DiscoverState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DiscoverState():
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
    TResult? Function(_DiscoverState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DiscoverState() when $default != null:
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
            List<TrendingCreator> trendingCreators,
            List<Category> categories,
            List<RecommendedContent> recommendedContent,
            List<SearchResult> searchResults,
            bool isSearching,
            List<VideoClip> clips,
            bool isLoadingTrendingCreators,
            bool trendingCreatorsLoadFailed,
            Map<String, int> userScrollBehavior,
            Map<String, double> lowViewedRatio)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DiscoverState() when $default != null:
        return $default(
            _that.trendingCreators,
            _that.categories,
            _that.recommendedContent,
            _that.searchResults,
            _that.isSearching,
            _that.clips,
            _that.isLoadingTrendingCreators,
            _that.trendingCreatorsLoadFailed,
            _that.userScrollBehavior,
            _that.lowViewedRatio);
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
            List<TrendingCreator> trendingCreators,
            List<Category> categories,
            List<RecommendedContent> recommendedContent,
            List<SearchResult> searchResults,
            bool isSearching,
            List<VideoClip> clips,
            bool isLoadingTrendingCreators,
            bool trendingCreatorsLoadFailed,
            Map<String, int> userScrollBehavior,
            Map<String, double> lowViewedRatio)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DiscoverState():
        return $default(
            _that.trendingCreators,
            _that.categories,
            _that.recommendedContent,
            _that.searchResults,
            _that.isSearching,
            _that.clips,
            _that.isLoadingTrendingCreators,
            _that.trendingCreatorsLoadFailed,
            _that.userScrollBehavior,
            _that.lowViewedRatio);
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
            List<TrendingCreator> trendingCreators,
            List<Category> categories,
            List<RecommendedContent> recommendedContent,
            List<SearchResult> searchResults,
            bool isSearching,
            List<VideoClip> clips,
            bool isLoadingTrendingCreators,
            bool trendingCreatorsLoadFailed,
            Map<String, int> userScrollBehavior,
            Map<String, double> lowViewedRatio)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DiscoverState() when $default != null:
        return $default(
            _that.trendingCreators,
            _that.categories,
            _that.recommendedContent,
            _that.searchResults,
            _that.isSearching,
            _that.clips,
            _that.isLoadingTrendingCreators,
            _that.trendingCreatorsLoadFailed,
            _that.userScrollBehavior,
            _that.lowViewedRatio);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _DiscoverState implements DiscoverState {
  const _DiscoverState(
      {final List<TrendingCreator> trendingCreators = const [],
      final List<Category> categories = const [],
      final List<RecommendedContent> recommendedContent = const [],
      final List<SearchResult> searchResults = const [],
      this.isSearching = false,
      final List<VideoClip> clips = const [],
      this.isLoadingTrendingCreators = false,
      this.trendingCreatorsLoadFailed = false,
      final Map<String, int> userScrollBehavior = const {},
      final Map<String, double> lowViewedRatio = const {}})
      : _trendingCreators = trendingCreators,
        _categories = categories,
        _recommendedContent = recommendedContent,
        _searchResults = searchResults,
        _clips = clips,
        _userScrollBehavior = userScrollBehavior,
        _lowViewedRatio = lowViewedRatio;

  final List<TrendingCreator> _trendingCreators;
  @override
  @JsonKey()
  List<TrendingCreator> get trendingCreators {
    if (_trendingCreators is EqualUnmodifiableListView)
      return _trendingCreators;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_trendingCreators);
  }

  final List<Category> _categories;
  @override
  @JsonKey()
  List<Category> get categories {
    if (_categories is EqualUnmodifiableListView) return _categories;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_categories);
  }

  final List<RecommendedContent> _recommendedContent;
  @override
  @JsonKey()
  List<RecommendedContent> get recommendedContent {
    if (_recommendedContent is EqualUnmodifiableListView)
      return _recommendedContent;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_recommendedContent);
  }

  final List<SearchResult> _searchResults;
  @override
  @JsonKey()
  List<SearchResult> get searchResults {
    if (_searchResults is EqualUnmodifiableListView) return _searchResults;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_searchResults);
  }

  @override
  @JsonKey()
  final bool isSearching;
  final List<VideoClip> _clips;
  @override
  @JsonKey()
  List<VideoClip> get clips {
    if (_clips is EqualUnmodifiableListView) return _clips;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_clips);
  }

  @override
  @JsonKey()
  final bool isLoadingTrendingCreators;
  @override
  @JsonKey()
  final bool trendingCreatorsLoadFailed;
  final Map<String, int> _userScrollBehavior;
  @override
  @JsonKey()
  Map<String, int> get userScrollBehavior {
    if (_userScrollBehavior is EqualUnmodifiableMapView)
      return _userScrollBehavior;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_userScrollBehavior);
  }

  final Map<String, double> _lowViewedRatio;
  @override
  @JsonKey()
  Map<String, double> get lowViewedRatio {
    if (_lowViewedRatio is EqualUnmodifiableMapView) return _lowViewedRatio;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_lowViewedRatio);
  }

  /// Create a copy of DiscoverState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$DiscoverStateCopyWith<_DiscoverState> get copyWith =>
      __$DiscoverStateCopyWithImpl<_DiscoverState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _DiscoverState &&
            const DeepCollectionEquality()
                .equals(other._trendingCreators, _trendingCreators) &&
            const DeepCollectionEquality()
                .equals(other._categories, _categories) &&
            const DeepCollectionEquality()
                .equals(other._recommendedContent, _recommendedContent) &&
            const DeepCollectionEquality()
                .equals(other._searchResults, _searchResults) &&
            (identical(other.isSearching, isSearching) ||
                other.isSearching == isSearching) &&
            const DeepCollectionEquality().equals(other._clips, _clips) &&
            (identical(other.isLoadingTrendingCreators,
                    isLoadingTrendingCreators) ||
                other.isLoadingTrendingCreators == isLoadingTrendingCreators) &&
            (identical(other.trendingCreatorsLoadFailed,
                    trendingCreatorsLoadFailed) ||
                other.trendingCreatorsLoadFailed ==
                    trendingCreatorsLoadFailed) &&
            const DeepCollectionEquality()
                .equals(other._userScrollBehavior, _userScrollBehavior) &&
            const DeepCollectionEquality()
                .equals(other._lowViewedRatio, _lowViewedRatio));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_trendingCreators),
      const DeepCollectionEquality().hash(_categories),
      const DeepCollectionEquality().hash(_recommendedContent),
      const DeepCollectionEquality().hash(_searchResults),
      isSearching,
      const DeepCollectionEquality().hash(_clips),
      isLoadingTrendingCreators,
      trendingCreatorsLoadFailed,
      const DeepCollectionEquality().hash(_userScrollBehavior),
      const DeepCollectionEquality().hash(_lowViewedRatio));

  @override
  String toString() {
    return 'DiscoverState(trendingCreators: $trendingCreators, categories: $categories, recommendedContent: $recommendedContent, searchResults: $searchResults, isSearching: $isSearching, clips: $clips, isLoadingTrendingCreators: $isLoadingTrendingCreators, trendingCreatorsLoadFailed: $trendingCreatorsLoadFailed, userScrollBehavior: $userScrollBehavior, lowViewedRatio: $lowViewedRatio)';
  }
}

/// @nodoc
abstract mixin class _$DiscoverStateCopyWith<$Res>
    implements $DiscoverStateCopyWith<$Res> {
  factory _$DiscoverStateCopyWith(
          _DiscoverState value, $Res Function(_DiscoverState) _then) =
      __$DiscoverStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {List<TrendingCreator> trendingCreators,
      List<Category> categories,
      List<RecommendedContent> recommendedContent,
      List<SearchResult> searchResults,
      bool isSearching,
      List<VideoClip> clips,
      bool isLoadingTrendingCreators,
      bool trendingCreatorsLoadFailed,
      Map<String, int> userScrollBehavior,
      Map<String, double> lowViewedRatio});
}

/// @nodoc
class __$DiscoverStateCopyWithImpl<$Res>
    implements _$DiscoverStateCopyWith<$Res> {
  __$DiscoverStateCopyWithImpl(this._self, this._then);

  final _DiscoverState _self;
  final $Res Function(_DiscoverState) _then;

  /// Create a copy of DiscoverState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? trendingCreators = null,
    Object? categories = null,
    Object? recommendedContent = null,
    Object? searchResults = null,
    Object? isSearching = null,
    Object? clips = null,
    Object? isLoadingTrendingCreators = null,
    Object? trendingCreatorsLoadFailed = null,
    Object? userScrollBehavior = null,
    Object? lowViewedRatio = null,
  }) {
    return _then(_DiscoverState(
      trendingCreators: null == trendingCreators
          ? _self._trendingCreators
          : trendingCreators // ignore: cast_nullable_to_non_nullable
              as List<TrendingCreator>,
      categories: null == categories
          ? _self._categories
          : categories // ignore: cast_nullable_to_non_nullable
              as List<Category>,
      recommendedContent: null == recommendedContent
          ? _self._recommendedContent
          : recommendedContent // ignore: cast_nullable_to_non_nullable
              as List<RecommendedContent>,
      searchResults: null == searchResults
          ? _self._searchResults
          : searchResults // ignore: cast_nullable_to_non_nullable
              as List<SearchResult>,
      isSearching: null == isSearching
          ? _self.isSearching
          : isSearching // ignore: cast_nullable_to_non_nullable
              as bool,
      clips: null == clips
          ? _self._clips
          : clips // ignore: cast_nullable_to_non_nullable
              as List<VideoClip>,
      isLoadingTrendingCreators: null == isLoadingTrendingCreators
          ? _self.isLoadingTrendingCreators
          : isLoadingTrendingCreators // ignore: cast_nullable_to_non_nullable
              as bool,
      trendingCreatorsLoadFailed: null == trendingCreatorsLoadFailed
          ? _self.trendingCreatorsLoadFailed
          : trendingCreatorsLoadFailed // ignore: cast_nullable_to_non_nullable
              as bool,
      userScrollBehavior: null == userScrollBehavior
          ? _self._userScrollBehavior
          : userScrollBehavior // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      lowViewedRatio: null == lowViewedRatio
          ? _self._lowViewedRatio
          : lowViewedRatio // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
    ));
  }
}

/// @nodoc
mixin _$SearchResult {
  String get id;
  String get title;
  String get subtitle;
  String? get metadata;
  String? get imageURL;
  ResultType get type;

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SearchResultCopyWith<SearchResult> get copyWith =>
      _$SearchResultCopyWithImpl<SearchResult>(
          this as SearchResult, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SearchResult &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.subtitle, subtitle) ||
                other.subtitle == subtitle) &&
            (identical(other.metadata, metadata) ||
                other.metadata == metadata) &&
            (identical(other.imageURL, imageURL) ||
                other.imageURL == imageURL) &&
            (identical(other.type, type) || other.type == type));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, id, title, subtitle, metadata, imageURL, type);

  @override
  String toString() {
    return 'SearchResult(id: $id, title: $title, subtitle: $subtitle, metadata: $metadata, imageURL: $imageURL, type: $type)';
  }
}

/// @nodoc
abstract mixin class $SearchResultCopyWith<$Res> {
  factory $SearchResultCopyWith(
          SearchResult value, $Res Function(SearchResult) _then) =
      _$SearchResultCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String title,
      String subtitle,
      String? metadata,
      String? imageURL,
      ResultType type});
}

/// @nodoc
class _$SearchResultCopyWithImpl<$Res> implements $SearchResultCopyWith<$Res> {
  _$SearchResultCopyWithImpl(this._self, this._then);

  final SearchResult _self;
  final $Res Function(SearchResult) _then;

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? subtitle = null,
    Object? metadata = freezed,
    Object? imageURL = freezed,
    Object? type = null,
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
      subtitle: null == subtitle
          ? _self.subtitle
          : subtitle // ignore: cast_nullable_to_non_nullable
              as String,
      metadata: freezed == metadata
          ? _self.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as String?,
      imageURL: freezed == imageURL
          ? _self.imageURL
          : imageURL // ignore: cast_nullable_to_non_nullable
              as String?,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as ResultType,
    ));
  }
}

/// Adds pattern-matching-related methods to [SearchResult].
extension SearchResultPatterns on SearchResult {
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
    TResult Function(_SearchResult value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SearchResult() when $default != null:
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
    TResult Function(_SearchResult value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SearchResult():
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
    TResult? Function(_SearchResult value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SearchResult() when $default != null:
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
    TResult Function(String id, String title, String subtitle, String? metadata,
            String? imageURL, ResultType type)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SearchResult() when $default != null:
        return $default(_that.id, _that.title, _that.subtitle, _that.metadata,
            _that.imageURL, _that.type);
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
    TResult Function(String id, String title, String subtitle, String? metadata,
            String? imageURL, ResultType type)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SearchResult():
        return $default(_that.id, _that.title, _that.subtitle, _that.metadata,
            _that.imageURL, _that.type);
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
    TResult? Function(String id, String title, String subtitle,
            String? metadata, String? imageURL, ResultType type)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SearchResult() when $default != null:
        return $default(_that.id, _that.title, _that.subtitle, _that.metadata,
            _that.imageURL, _that.type);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _SearchResult implements SearchResult {
  const _SearchResult(
      {required this.id,
      required this.title,
      required this.subtitle,
      this.metadata,
      this.imageURL,
      required this.type});

  @override
  final String id;
  @override
  final String title;
  @override
  final String subtitle;
  @override
  final String? metadata;
  @override
  final String? imageURL;
  @override
  final ResultType type;

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SearchResultCopyWith<_SearchResult> get copyWith =>
      __$SearchResultCopyWithImpl<_SearchResult>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SearchResult &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.subtitle, subtitle) ||
                other.subtitle == subtitle) &&
            (identical(other.metadata, metadata) ||
                other.metadata == metadata) &&
            (identical(other.imageURL, imageURL) ||
                other.imageURL == imageURL) &&
            (identical(other.type, type) || other.type == type));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, id, title, subtitle, metadata, imageURL, type);

  @override
  String toString() {
    return 'SearchResult(id: $id, title: $title, subtitle: $subtitle, metadata: $metadata, imageURL: $imageURL, type: $type)';
  }
}

/// @nodoc
abstract mixin class _$SearchResultCopyWith<$Res>
    implements $SearchResultCopyWith<$Res> {
  factory _$SearchResultCopyWith(
          _SearchResult value, $Res Function(_SearchResult) _then) =
      __$SearchResultCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String subtitle,
      String? metadata,
      String? imageURL,
      ResultType type});
}

/// @nodoc
class __$SearchResultCopyWithImpl<$Res>
    implements _$SearchResultCopyWith<$Res> {
  __$SearchResultCopyWithImpl(this._self, this._then);

  final _SearchResult _self;
  final $Res Function(_SearchResult) _then;

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? subtitle = null,
    Object? metadata = freezed,
    Object? imageURL = freezed,
    Object? type = null,
  }) {
    return _then(_SearchResult(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      subtitle: null == subtitle
          ? _self.subtitle
          : subtitle // ignore: cast_nullable_to_non_nullable
              as String,
      metadata: freezed == metadata
          ? _self.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as String?,
      imageURL: freezed == imageURL
          ? _self.imageURL
          : imageURL // ignore: cast_nullable_to_non_nullable
              as String?,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as ResultType,
    ));
  }
}

// dart format on
