// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'activity_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ActivityState {
  Map<String, List<ActivityNotification>> get grouped =>
      throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  bool get isProcessing => throw _privateConstructorUsedError;
  int get processingCount => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $ActivityStateCopyWith<ActivityState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ActivityStateCopyWith<$Res> {
  factory $ActivityStateCopyWith(
          ActivityState value, $Res Function(ActivityState) then) =
      _$ActivityStateCopyWithImpl<$Res, ActivityState>;
  @useResult
  $Res call(
      {Map<String, List<ActivityNotification>> grouped,
      bool isLoading,
      bool isProcessing,
      int processingCount});
}

/// @nodoc
class _$ActivityStateCopyWithImpl<$Res, $Val extends ActivityState>
    implements $ActivityStateCopyWith<$Res> {
  _$ActivityStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? grouped = null,
    Object? isLoading = null,
    Object? isProcessing = null,
    Object? processingCount = null,
  }) {
    return _then(_value.copyWith(
      grouped: null == grouped
          ? _value.grouped
          : grouped // ignore: cast_nullable_to_non_nullable
              as Map<String, List<ActivityNotification>>,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      isProcessing: null == isProcessing
          ? _value.isProcessing
          : isProcessing // ignore: cast_nullable_to_non_nullable
              as bool,
      processingCount: null == processingCount
          ? _value.processingCount
          : processingCount // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ActivityStateImplCopyWith<$Res>
    implements $ActivityStateCopyWith<$Res> {
  factory _$$ActivityStateImplCopyWith(
          _$ActivityStateImpl value, $Res Function(_$ActivityStateImpl) then) =
      __$$ActivityStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Map<String, List<ActivityNotification>> grouped,
      bool isLoading,
      bool isProcessing,
      int processingCount});
}

/// @nodoc
class __$$ActivityStateImplCopyWithImpl<$Res>
    extends _$ActivityStateCopyWithImpl<$Res, _$ActivityStateImpl>
    implements _$$ActivityStateImplCopyWith<$Res> {
  __$$ActivityStateImplCopyWithImpl(
      _$ActivityStateImpl _value, $Res Function(_$ActivityStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? grouped = null,
    Object? isLoading = null,
    Object? isProcessing = null,
    Object? processingCount = null,
  }) {
    return _then(_$ActivityStateImpl(
      grouped: null == grouped
          ? _value._grouped
          : grouped // ignore: cast_nullable_to_non_nullable
              as Map<String, List<ActivityNotification>>,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      isProcessing: null == isProcessing
          ? _value.isProcessing
          : isProcessing // ignore: cast_nullable_to_non_nullable
              as bool,
      processingCount: null == processingCount
          ? _value.processingCount
          : processingCount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$ActivityStateImpl implements _ActivityState {
  const _$ActivityStateImpl(
      {final Map<String, List<ActivityNotification>> grouped = const {},
      this.isLoading = false,
      this.isProcessing = false,
      this.processingCount = 0})
      : _grouped = grouped;

  final Map<String, List<ActivityNotification>> _grouped;
  @override
  @JsonKey()
  Map<String, List<ActivityNotification>> get grouped {
    if (_grouped is EqualUnmodifiableMapView) return _grouped;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_grouped);
  }

  @override
  @JsonKey()
  final bool isLoading;
  @override
  @JsonKey()
  final bool isProcessing;
  @override
  @JsonKey()
  final int processingCount;

  @override
  String toString() {
    return 'ActivityState(grouped: $grouped, isLoading: $isLoading, isProcessing: $isProcessing, processingCount: $processingCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ActivityStateImpl &&
            const DeepCollectionEquality().equals(other._grouped, _grouped) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.isProcessing, isProcessing) ||
                other.isProcessing == isProcessing) &&
            (identical(other.processingCount, processingCount) ||
                other.processingCount == processingCount));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_grouped),
      isLoading,
      isProcessing,
      processingCount);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ActivityStateImplCopyWith<_$ActivityStateImpl> get copyWith =>
      __$$ActivityStateImplCopyWithImpl<_$ActivityStateImpl>(this, _$identity);
}

abstract class _ActivityState implements ActivityState {
  const factory _ActivityState(
      {final Map<String, List<ActivityNotification>> grouped,
      final bool isLoading,
      final bool isProcessing,
      final int processingCount}) = _$ActivityStateImpl;

  @override
  Map<String, List<ActivityNotification>> get grouped;
  @override
  bool get isLoading;
  @override
  bool get isProcessing;
  @override
  int get processingCount;
  @override
  @JsonKey(ignore: true)
  _$$ActivityStateImplCopyWith<_$ActivityStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
