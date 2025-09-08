// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'share_action.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ShareAction _$ShareActionFromJson(Map<String, dynamic> json) {
  return _ShareAction.fromJson(json);
}

/// @nodoc
mixin _$ShareAction {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get iconName => throw _privateConstructorUsedError;
  @ColorConverter()
  Color get iconColor => throw _privateConstructorUsedError;
  @ColorConverter()
  Color get backgroundColor => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ShareActionCopyWith<ShareAction> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ShareActionCopyWith<$Res> {
  factory $ShareActionCopyWith(
          ShareAction value, $Res Function(ShareAction) then) =
      _$ShareActionCopyWithImpl<$Res, ShareAction>;
  @useResult
  $Res call(
      {String id,
      String name,
      String iconName,
      @ColorConverter() Color iconColor,
      @ColorConverter() Color backgroundColor});
}

/// @nodoc
class _$ShareActionCopyWithImpl<$Res, $Val extends ShareAction>
    implements $ShareActionCopyWith<$Res> {
  _$ShareActionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? iconName = null,
    Object? iconColor = null,
    Object? backgroundColor = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      iconName: null == iconName
          ? _value.iconName
          : iconName // ignore: cast_nullable_to_non_nullable
              as String,
      iconColor: null == iconColor
          ? _value.iconColor
          : iconColor // ignore: cast_nullable_to_non_nullable
              as Color,
      backgroundColor: null == backgroundColor
          ? _value.backgroundColor
          : backgroundColor // ignore: cast_nullable_to_non_nullable
              as Color,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ShareActionImplCopyWith<$Res>
    implements $ShareActionCopyWith<$Res> {
  factory _$$ShareActionImplCopyWith(
          _$ShareActionImpl value, $Res Function(_$ShareActionImpl) then) =
      __$$ShareActionImplCopyWithImpl<$Res>;
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
class __$$ShareActionImplCopyWithImpl<$Res>
    extends _$ShareActionCopyWithImpl<$Res, _$ShareActionImpl>
    implements _$$ShareActionImplCopyWith<$Res> {
  __$$ShareActionImplCopyWithImpl(
      _$ShareActionImpl _value, $Res Function(_$ShareActionImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? iconName = null,
    Object? iconColor = null,
    Object? backgroundColor = null,
  }) {
    return _then(_$ShareActionImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      iconName: null == iconName
          ? _value.iconName
          : iconName // ignore: cast_nullable_to_non_nullable
              as String,
      iconColor: null == iconColor
          ? _value.iconColor
          : iconColor // ignore: cast_nullable_to_non_nullable
              as Color,
      backgroundColor: null == backgroundColor
          ? _value.backgroundColor
          : backgroundColor // ignore: cast_nullable_to_non_nullable
              as Color,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ShareActionImpl with DiagnosticableTreeMixin implements _ShareAction {
  const _$ShareActionImpl(
      {required this.id,
      required this.name,
      required this.iconName,
      @ColorConverter() required this.iconColor,
      @ColorConverter() required this.backgroundColor});

  factory _$ShareActionImpl.fromJson(Map<String, dynamic> json) =>
      _$$ShareActionImplFromJson(json);

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

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'ShareAction(id: $id, name: $name, iconName: $iconName, iconColor: $iconColor, backgroundColor: $backgroundColor)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'ShareAction'))
      ..add(DiagnosticsProperty('id', id))
      ..add(DiagnosticsProperty('name', name))
      ..add(DiagnosticsProperty('iconName', iconName))
      ..add(DiagnosticsProperty('iconColor', iconColor))
      ..add(DiagnosticsProperty('backgroundColor', backgroundColor));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ShareActionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.iconName, iconName) ||
                other.iconName == iconName) &&
            (identical(other.iconColor, iconColor) ||
                other.iconColor == iconColor) &&
            (identical(other.backgroundColor, backgroundColor) ||
                other.backgroundColor == backgroundColor));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, name, iconName, iconColor, backgroundColor);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ShareActionImplCopyWith<_$ShareActionImpl> get copyWith =>
      __$$ShareActionImplCopyWithImpl<_$ShareActionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ShareActionImplToJson(
      this,
    );
  }
}

abstract class _ShareAction implements ShareAction {
  const factory _ShareAction(
          {required final String id,
          required final String name,
          required final String iconName,
          @ColorConverter() required final Color iconColor,
          @ColorConverter() required final Color backgroundColor}) =
      _$ShareActionImpl;

  factory _ShareAction.fromJson(Map<String, dynamic> json) =
      _$ShareActionImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get iconName;
  @override
  @ColorConverter()
  Color get iconColor;
  @override
  @ColorConverter()
  Color get backgroundColor;
  @override
  @JsonKey(ignore: true)
  _$$ShareActionImplCopyWith<_$ShareActionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
