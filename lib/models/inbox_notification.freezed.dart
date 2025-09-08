// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'inbox_notification.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

InboxNotification _$InboxNotificationFromJson(Map<String, dynamic> json) {
  return _InboxNotification.fromJson(json);
}

/// @nodoc
mixin _$InboxNotification {
  String get id => throw _privateConstructorUsedError;
  String get text => throw _privateConstructorUsedError;
  String get timestamp => throw _privateConstructorUsedError;
  NotificationType get type => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $InboxNotificationCopyWith<InboxNotification> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $InboxNotificationCopyWith<$Res> {
  factory $InboxNotificationCopyWith(
          InboxNotification value, $Res Function(InboxNotification) then) =
      _$InboxNotificationCopyWithImpl<$Res, InboxNotification>;
  @useResult
  $Res call({String id, String text, String timestamp, NotificationType type});
}

/// @nodoc
class _$InboxNotificationCopyWithImpl<$Res, $Val extends InboxNotification>
    implements $InboxNotificationCopyWith<$Res> {
  _$InboxNotificationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? text = null,
    Object? timestamp = null,
    Object? type = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      text: null == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as NotificationType,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$InboxNotificationImplCopyWith<$Res>
    implements $InboxNotificationCopyWith<$Res> {
  factory _$$InboxNotificationImplCopyWith(_$InboxNotificationImpl value,
          $Res Function(_$InboxNotificationImpl) then) =
      __$$InboxNotificationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String text, String timestamp, NotificationType type});
}

/// @nodoc
class __$$InboxNotificationImplCopyWithImpl<$Res>
    extends _$InboxNotificationCopyWithImpl<$Res, _$InboxNotificationImpl>
    implements _$$InboxNotificationImplCopyWith<$Res> {
  __$$InboxNotificationImplCopyWithImpl(_$InboxNotificationImpl _value,
      $Res Function(_$InboxNotificationImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? text = null,
    Object? timestamp = null,
    Object? type = null,
  }) {
    return _then(_$InboxNotificationImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      text: null == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as NotificationType,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$InboxNotificationImpl
    with DiagnosticableTreeMixin
    implements _InboxNotification {
  const _$InboxNotificationImpl(
      {required this.id,
      required this.text,
      required this.timestamp,
      required this.type});

  factory _$InboxNotificationImpl.fromJson(Map<String, dynamic> json) =>
      _$$InboxNotificationImplFromJson(json);

  @override
  final String id;
  @override
  final String text;
  @override
  final String timestamp;
  @override
  final NotificationType type;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'InboxNotification(id: $id, text: $text, timestamp: $timestamp, type: $type)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'InboxNotification'))
      ..add(DiagnosticsProperty('id', id))
      ..add(DiagnosticsProperty('text', text))
      ..add(DiagnosticsProperty('timestamp', timestamp))
      ..add(DiagnosticsProperty('type', type));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InboxNotificationImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.type, type) || other.type == type));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, text, timestamp, type);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$InboxNotificationImplCopyWith<_$InboxNotificationImpl> get copyWith =>
      __$$InboxNotificationImplCopyWithImpl<_$InboxNotificationImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$InboxNotificationImplToJson(
      this,
    );
  }
}

abstract class _InboxNotification implements InboxNotification {
  const factory _InboxNotification(
      {required final String id,
      required final String text,
      required final String timestamp,
      required final NotificationType type}) = _$InboxNotificationImpl;

  factory _InboxNotification.fromJson(Map<String, dynamic> json) =
      _$InboxNotificationImpl.fromJson;

  @override
  String get id;
  @override
  String get text;
  @override
  String get timestamp;
  @override
  NotificationType get type;
  @override
  @JsonKey(ignore: true)
  _$$InboxNotificationImplCopyWith<_$InboxNotificationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
