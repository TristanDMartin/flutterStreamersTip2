// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ml_score.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

MLScore _$MLScoreFromJson(Map<String, dynamic> json) {
  return _MLScore.fromJson(json);
}

/// @nodoc
mixin _$MLScore {
  double get value => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $MLScoreCopyWith<MLScore> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MLScoreCopyWith<$Res> {
  factory $MLScoreCopyWith(MLScore value, $Res Function(MLScore) then) =
      _$MLScoreCopyWithImpl<$Res, MLScore>;
  @useResult
  $Res call({double value, String type});
}

/// @nodoc
class _$MLScoreCopyWithImpl<$Res, $Val extends MLScore>
    implements $MLScoreCopyWith<$Res> {
  _$MLScoreCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? value = null,
    Object? type = null,
  }) {
    return _then(_value.copyWith(
      value: null == value
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as double,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MLScoreImplCopyWith<$Res> implements $MLScoreCopyWith<$Res> {
  factory _$$MLScoreImplCopyWith(
          _$MLScoreImpl value, $Res Function(_$MLScoreImpl) then) =
      __$$MLScoreImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({double value, String type});
}

/// @nodoc
class __$$MLScoreImplCopyWithImpl<$Res>
    extends _$MLScoreCopyWithImpl<$Res, _$MLScoreImpl>
    implements _$$MLScoreImplCopyWith<$Res> {
  __$$MLScoreImplCopyWithImpl(
      _$MLScoreImpl _value, $Res Function(_$MLScoreImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? value = null,
    Object? type = null,
  }) {
    return _then(_$MLScoreImpl(
      value: null == value
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as double,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MLScoreImpl implements _MLScore {
  const _$MLScoreImpl({required this.value, required this.type});

  factory _$MLScoreImpl.fromJson(Map<String, dynamic> json) =>
      _$$MLScoreImplFromJson(json);

  @override
  final double value;
  @override
  final String type;

  @override
  String toString() {
    return 'MLScore(value: $value, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MLScoreImpl &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.type, type) || other.type == type));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, value, type);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MLScoreImplCopyWith<_$MLScoreImpl> get copyWith =>
      __$$MLScoreImplCopyWithImpl<_$MLScoreImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MLScoreImplToJson(
      this,
    );
  }
}

abstract class _MLScore implements MLScore {
  const factory _MLScore(
      {required final double value,
      required final String type}) = _$MLScoreImpl;

  factory _MLScore.fromJson(Map<String, dynamic> json) = _$MLScoreImpl.fromJson;

  @override
  double get value;
  @override
  String get type;
  @override
  @JsonKey(ignore: true)
  _$$MLScoreImplCopyWith<_$MLScoreImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
