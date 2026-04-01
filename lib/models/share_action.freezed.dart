// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'share_action.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ShareAction {
  String get id;
  String get name;
  String get iconName;
  @ColorConverter()
  Color get iconColor;
  @ColorConverter()
  Color get backgroundColor;

  /// Create a copy of ShareAction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ShareActionCopyWith<ShareAction> get copyWith =>
      _$ShareActionCopyWithImpl<ShareAction>(this as ShareAction, _$identity);

  /// Serializes this ShareAction to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ShareAction &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.iconName, iconName) ||
                other.iconName == iconName) &&
            (identical(other.iconColor, iconColor) ||
                other.iconColor == iconColor) &&
            (identical(other.backgroundColor, backgroundColor) ||
                other.backgroundColor == backgroundColor));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, name, iconName, iconColor, backgroundColor);

  @override
  String toString() {
    return 'ShareAction(id: $id, name: $name, iconName: $iconName, iconColor: $iconColor, backgroundColor: $backgroundColor)';
  }
}

/// @nodoc
abstract mixin class $ShareActionCopyWith<$Res> {
  factory $ShareActionCopyWith(
          ShareAction value, $Res Function(ShareAction) _then) =
      _$ShareActionCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String name,
      String iconName,
      @ColorConverter() Color iconColor,
      @ColorConverter() Color backgroundColor});
}

/// @nodoc
class _$ShareActionCopyWithImpl<$Res> implements $ShareActionCopyWith<$Res> {
  _$ShareActionCopyWithImpl(this._self, this._then);

  final ShareAction _self;
  final $Res Function(ShareAction) _then;

  /// Create a copy of ShareAction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? iconName = null,
    Object? iconColor = null,
    Object? backgroundColor = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      iconName: null == iconName
          ? _self.iconName
          : iconName // ignore: cast_nullable_to_non_nullable
              as String,
      iconColor: null == iconColor
          ? _self.iconColor
          : iconColor // ignore: cast_nullable_to_non_nullable
              as Color,
      backgroundColor: null == backgroundColor
          ? _self.backgroundColor
          : backgroundColor // ignore: cast_nullable_to_non_nullable
              as Color,
    ));
  }
}

/// Adds pattern-matching-related methods to [ShareAction].
extension ShareActionPatterns on ShareAction {
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
    TResult Function(_ShareAction value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ShareAction() when $default != null:
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
    TResult Function(_ShareAction value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ShareAction():
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
    TResult? Function(_ShareAction value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ShareAction() when $default != null:
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
            String name,
            String iconName,
            @ColorConverter() Color iconColor,
            @ColorConverter() Color backgroundColor)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ShareAction() when $default != null:
        return $default(_that.id, _that.name, _that.iconName, _that.iconColor,
            _that.backgroundColor);
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
            String name,
            String iconName,
            @ColorConverter() Color iconColor,
            @ColorConverter() Color backgroundColor)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ShareAction():
        return $default(_that.id, _that.name, _that.iconName, _that.iconColor,
            _that.backgroundColor);
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
            String name,
            String iconName,
            @ColorConverter() Color iconColor,
            @ColorConverter() Color backgroundColor)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ShareAction() when $default != null:
        return $default(_that.id, _that.name, _that.iconName, _that.iconColor,
            _that.backgroundColor);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ShareAction implements ShareAction {
  const _ShareAction(
      {required this.id,
      required this.name,
      required this.iconName,
      @ColorConverter() required this.iconColor,
      @ColorConverter() required this.backgroundColor});
  factory _ShareAction.fromJson(Map<String, dynamic> json) =>
      _$ShareActionFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String iconName;
  @override
  @ColorConverter()
  final Color iconColor;
  @override
  @ColorConverter()
  final Color backgroundColor;

  /// Create a copy of ShareAction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ShareActionCopyWith<_ShareAction> get copyWith =>
      __$ShareActionCopyWithImpl<_ShareAction>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ShareActionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ShareAction &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.iconName, iconName) ||
                other.iconName == iconName) &&
            (identical(other.iconColor, iconColor) ||
                other.iconColor == iconColor) &&
            (identical(other.backgroundColor, backgroundColor) ||
                other.backgroundColor == backgroundColor));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, name, iconName, iconColor, backgroundColor);

  @override
  String toString() {
    return 'ShareAction(id: $id, name: $name, iconName: $iconName, iconColor: $iconColor, backgroundColor: $backgroundColor)';
  }
}

/// @nodoc
abstract mixin class _$ShareActionCopyWith<$Res>
    implements $ShareActionCopyWith<$Res> {
  factory _$ShareActionCopyWith(
          _ShareAction value, $Res Function(_ShareAction) _then) =
      __$ShareActionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String iconName,
      @ColorConverter() Color iconColor,
      @ColorConverter() Color backgroundColor});
}

/// @nodoc
class __$ShareActionCopyWithImpl<$Res> implements _$ShareActionCopyWith<$Res> {
  __$ShareActionCopyWithImpl(this._self, this._then);

  final _ShareAction _self;
  final $Res Function(_ShareAction) _then;

  /// Create a copy of ShareAction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? iconName = null,
    Object? iconColor = null,
    Object? backgroundColor = null,
  }) {
    return _then(_ShareAction(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      iconName: null == iconName
          ? _self.iconName
          : iconName // ignore: cast_nullable_to_non_nullable
              as String,
      iconColor: null == iconColor
          ? _self.iconColor
          : iconColor // ignore: cast_nullable_to_non_nullable
              as Color,
      backgroundColor: null == backgroundColor
          ? _self.backgroundColor
          : backgroundColor // ignore: cast_nullable_to_non_nullable
              as Color,
    ));
  }
}

// dart format on
