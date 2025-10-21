// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Message _$MessageFromJson(Map<String, dynamic> json) {
  return _Message.fromJson(json);
}

/// @nodoc
mixin _$Message {
  String? get id => throw _privateConstructorUsedError;
  String? get chatId => throw _privateConstructorUsedError;
  String get text => throw _privateConstructorUsedError;
  String get from => throw _privateConstructorUsedError;
  String get to => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime? get timestamp => throw _privateConstructorUsedError;
  bool get isRead => throw _privateConstructorUsedError;
  List<String> get recipients => throw _privateConstructorUsedError;
  List<String> get readBy => throw _privateConstructorUsedError;
  String? get gifUrl => throw _privateConstructorUsedError;
  String get messageType => throw _privateConstructorUsedError;
  bool get isDeviceGif => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $MessageCopyWith<Message> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MessageCopyWith<$Res> {
  factory $MessageCopyWith(Message value, $Res Function(Message) then) =
      _$MessageCopyWithImpl<$Res, Message>;
  @useResult
  $Res call(
      {String? id,
      String? chatId,
      String text,
      String from,
      String to,
      @TimestampConverter() DateTime? timestamp,
      bool isRead,
      List<String> recipients,
      List<String> readBy,
      String? gifUrl,
      String messageType,
      bool isDeviceGif});
}

/// @nodoc
class _$MessageCopyWithImpl<$Res, $Val extends Message>
    implements $MessageCopyWith<$Res> {
  _$MessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? chatId = freezed,
    Object? text = null,
    Object? from = null,
    Object? to = null,
    Object? timestamp = freezed,
    Object? isRead = null,
    Object? recipients = null,
    Object? readBy = null,
    Object? gifUrl = freezed,
    Object? messageType = null,
    Object? isDeviceGif = null,
  }) {
    return _then(_value.copyWith(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      chatId: freezed == chatId
          ? _value.chatId
          : chatId // ignore: cast_nullable_to_non_nullable
              as String?,
      text: null == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      from: null == from
          ? _value.from
          : from // ignore: cast_nullable_to_non_nullable
              as String,
      to: null == to
          ? _value.to
          : to // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: freezed == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      isRead: null == isRead
          ? _value.isRead
          : isRead // ignore: cast_nullable_to_non_nullable
              as bool,
      recipients: null == recipients
          ? _value.recipients
          : recipients // ignore: cast_nullable_to_non_nullable
              as List<String>,
      readBy: null == readBy
          ? _value.readBy
          : readBy // ignore: cast_nullable_to_non_nullable
              as List<String>,
      gifUrl: freezed == gifUrl
          ? _value.gifUrl
          : gifUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      messageType: null == messageType
          ? _value.messageType
          : messageType // ignore: cast_nullable_to_non_nullable
              as String,
      isDeviceGif: null == isDeviceGif
          ? _value.isDeviceGif
          : isDeviceGif // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MessageImplCopyWith<$Res> implements $MessageCopyWith<$Res> {
  factory _$$MessageImplCopyWith(
          _$MessageImpl value, $Res Function(_$MessageImpl) then) =
      __$$MessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String? id,
      String? chatId,
      String text,
      String from,
      String to,
      @TimestampConverter() DateTime? timestamp,
      bool isRead,
      List<String> recipients,
      List<String> readBy,
      String? gifUrl,
      String messageType,
      bool isDeviceGif});
}

/// @nodoc
class __$$MessageImplCopyWithImpl<$Res>
    extends _$MessageCopyWithImpl<$Res, _$MessageImpl>
    implements _$$MessageImplCopyWith<$Res> {
  __$$MessageImplCopyWithImpl(
      _$MessageImpl _value, $Res Function(_$MessageImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? chatId = freezed,
    Object? text = null,
    Object? from = null,
    Object? to = null,
    Object? timestamp = freezed,
    Object? isRead = null,
    Object? recipients = null,
    Object? readBy = null,
    Object? gifUrl = freezed,
    Object? messageType = null,
    Object? isDeviceGif = null,
  }) {
    return _then(_$MessageImpl(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      chatId: freezed == chatId
          ? _value.chatId
          : chatId // ignore: cast_nullable_to_non_nullable
              as String?,
      text: null == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      from: null == from
          ? _value.from
          : from // ignore: cast_nullable_to_non_nullable
              as String,
      to: null == to
          ? _value.to
          : to // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: freezed == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      isRead: null == isRead
          ? _value.isRead
          : isRead // ignore: cast_nullable_to_non_nullable
              as bool,
      recipients: null == recipients
          ? _value._recipients
          : recipients // ignore: cast_nullable_to_non_nullable
              as List<String>,
      readBy: null == readBy
          ? _value._readBy
          : readBy // ignore: cast_nullable_to_non_nullable
              as List<String>,
      gifUrl: freezed == gifUrl
          ? _value.gifUrl
          : gifUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      messageType: null == messageType
          ? _value.messageType
          : messageType // ignore: cast_nullable_to_non_nullable
              as String,
      isDeviceGif: null == isDeviceGif
          ? _value.isDeviceGif
          : isDeviceGif // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MessageImpl with DiagnosticableTreeMixin implements _Message {
  const _$MessageImpl(
      {this.id,
      this.chatId,
      this.text = '',
      this.from = '',
      this.to = '',
      @TimestampConverter() this.timestamp,
      this.isRead = false,
      final List<String> recipients = const [],
      final List<String> readBy = const [],
      this.gifUrl,
      this.messageType = 'text',
      this.isDeviceGif = false})
      : _recipients = recipients,
        _readBy = readBy;

  factory _$MessageImpl.fromJson(Map<String, dynamic> json) =>
      _$$MessageImplFromJson(json);

  @override
  final String? id;
  @override
  final String? chatId;
  @override
  @JsonKey()
  final String text;
  @override
  @JsonKey()
  final String from;
  @override
  @JsonKey()
  final String to;
  @override
  @TimestampConverter()
  final DateTime? timestamp;
  @override
  @JsonKey()
  final bool isRead;
  final List<String> _recipients;
  @override
  @JsonKey()
  List<String> get recipients {
    if (_recipients is EqualUnmodifiableListView) return _recipients;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_recipients);
  }

  final List<String> _readBy;
  @override
  @JsonKey()
  List<String> get readBy {
    if (_readBy is EqualUnmodifiableListView) return _readBy;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_readBy);
  }

  @override
  final String? gifUrl;
  @override
  @JsonKey()
  final String messageType;
  @override
  @JsonKey()
  final bool isDeviceGif;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'Message(id: $id, chatId: $chatId, text: $text, from: $from, to: $to, timestamp: $timestamp, isRead: $isRead, recipients: $recipients, readBy: $readBy, gifUrl: $gifUrl, messageType: $messageType, isDeviceGif: $isDeviceGif)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'Message'))
      ..add(DiagnosticsProperty('id', id))
      ..add(DiagnosticsProperty('chatId', chatId))
      ..add(DiagnosticsProperty('text', text))
      ..add(DiagnosticsProperty('from', from))
      ..add(DiagnosticsProperty('to', to))
      ..add(DiagnosticsProperty('timestamp', timestamp))
      ..add(DiagnosticsProperty('isRead', isRead))
      ..add(DiagnosticsProperty('recipients', recipients))
      ..add(DiagnosticsProperty('readBy', readBy))
      ..add(DiagnosticsProperty('gifUrl', gifUrl))
      ..add(DiagnosticsProperty('messageType', messageType))
      ..add(DiagnosticsProperty('isDeviceGif', isDeviceGif));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessageImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.chatId, chatId) || other.chatId == chatId) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.from, from) || other.from == from) &&
            (identical(other.to, to) || other.to == to) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.isRead, isRead) || other.isRead == isRead) &&
            const DeepCollectionEquality()
                .equals(other._recipients, _recipients) &&
            const DeepCollectionEquality().equals(other._readBy, _readBy) &&
            (identical(other.gifUrl, gifUrl) || other.gifUrl == gifUrl) &&
            (identical(other.messageType, messageType) ||
                other.messageType == messageType) &&
            (identical(other.isDeviceGif, isDeviceGif) ||
                other.isDeviceGif == isDeviceGif));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      chatId,
      text,
      from,
      to,
      timestamp,
      isRead,
      const DeepCollectionEquality().hash(_recipients),
      const DeepCollectionEquality().hash(_readBy),
      gifUrl,
      messageType,
      isDeviceGif);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MessageImplCopyWith<_$MessageImpl> get copyWith =>
      __$$MessageImplCopyWithImpl<_$MessageImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MessageImplToJson(
      this,
    );
  }
}

abstract class _Message implements Message {
  const factory _Message(
      {final String? id,
      final String? chatId,
      final String text,
      final String from,
      final String to,
      @TimestampConverter() final DateTime? timestamp,
      final bool isRead,
      final List<String> recipients,
      final List<String> readBy,
      final String? gifUrl,
      final String messageType,
      final bool isDeviceGif}) = _$MessageImpl;

  factory _Message.fromJson(Map<String, dynamic> json) = _$MessageImpl.fromJson;

  @override
  String? get id;
  @override
  String? get chatId;
  @override
  String get text;
  @override
  String get from;
  @override
  String get to;
  @override
  @TimestampConverter()
  DateTime? get timestamp;
  @override
  bool get isRead;
  @override
  List<String> get recipients;
  @override
  List<String> get readBy;
  @override
  String? get gifUrl;
  @override
  String get messageType;
  @override
  bool get isDeviceGif;
  @override
  @JsonKey(ignore: true)
  _$$MessageImplCopyWith<_$MessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
