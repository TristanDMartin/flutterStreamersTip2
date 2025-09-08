// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) {
  return _ChatMessage.fromJson(json);
}

/// @nodoc
mixin _$ChatMessage {
  String get id => throw _privateConstructorUsedError;
  @UserConverter()
  User get sender => throw _privateConstructorUsedError;
  MessageContent get content => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get timestamp => throw _privateConstructorUsedError;
  bool get isFromCurrentUser => throw _privateConstructorUsedError;
  bool get isRead => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ChatMessageCopyWith<ChatMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatMessageCopyWith<$Res> {
  factory $ChatMessageCopyWith(
          ChatMessage value, $Res Function(ChatMessage) then) =
      _$ChatMessageCopyWithImpl<$Res, ChatMessage>;
  @useResult
  $Res call(
      {String id,
      @UserConverter() User sender,
      MessageContent content,
      @TimestampConverter() DateTime timestamp,
      bool isFromCurrentUser,
      bool isRead});

  $MessageContentCopyWith<$Res> get content;
}

/// @nodoc
class _$ChatMessageCopyWithImpl<$Res, $Val extends ChatMessage>
    implements $ChatMessageCopyWith<$Res> {
  _$ChatMessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sender = null,
    Object? content = null,
    Object? timestamp = null,
    Object? isFromCurrentUser = null,
    Object? isRead = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      sender: null == sender
          ? _value.sender
          : sender // ignore: cast_nullable_to_non_nullable
              as User,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as MessageContent,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isFromCurrentUser: null == isFromCurrentUser
          ? _value.isFromCurrentUser
          : isFromCurrentUser // ignore: cast_nullable_to_non_nullable
              as bool,
      isRead: null == isRead
          ? _value.isRead
          : isRead // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $MessageContentCopyWith<$Res> get content {
    return $MessageContentCopyWith<$Res>(_value.content, (value) {
      return _then(_value.copyWith(content: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ChatMessageImplCopyWith<$Res>
    implements $ChatMessageCopyWith<$Res> {
  factory _$$ChatMessageImplCopyWith(
          _$ChatMessageImpl value, $Res Function(_$ChatMessageImpl) then) =
      __$$ChatMessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @UserConverter() User sender,
      MessageContent content,
      @TimestampConverter() DateTime timestamp,
      bool isFromCurrentUser,
      bool isRead});

  @override
  $MessageContentCopyWith<$Res> get content;
}

/// @nodoc
class __$$ChatMessageImplCopyWithImpl<$Res>
    extends _$ChatMessageCopyWithImpl<$Res, _$ChatMessageImpl>
    implements _$$ChatMessageImplCopyWith<$Res> {
  __$$ChatMessageImplCopyWithImpl(
      _$ChatMessageImpl _value, $Res Function(_$ChatMessageImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sender = null,
    Object? content = null,
    Object? timestamp = null,
    Object? isFromCurrentUser = null,
    Object? isRead = null,
  }) {
    return _then(_$ChatMessageImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      sender: null == sender
          ? _value.sender
          : sender // ignore: cast_nullable_to_non_nullable
              as User,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as MessageContent,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isFromCurrentUser: null == isFromCurrentUser
          ? _value.isFromCurrentUser
          : isFromCurrentUser // ignore: cast_nullable_to_non_nullable
              as bool,
      isRead: null == isRead
          ? _value.isRead
          : isRead // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChatMessageImpl with DiagnosticableTreeMixin implements _ChatMessage {
  const _$ChatMessageImpl(
      {required this.id,
      @UserConverter() required this.sender,
      required this.content,
      @TimestampConverter() required this.timestamp,
      this.isFromCurrentUser = false,
      this.isRead = false});

  factory _$ChatMessageImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChatMessageImplFromJson(json);

  @override
  final String id;
  @override
  @UserConverter()
  final User sender;
  @override
  final MessageContent content;
  @override
  @TimestampConverter()
  final DateTime timestamp;
  @override
  @JsonKey()
  final bool isFromCurrentUser;
  @override
  @JsonKey()
  final bool isRead;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'ChatMessage(id: $id, sender: $sender, content: $content, timestamp: $timestamp, isFromCurrentUser: $isFromCurrentUser, isRead: $isRead)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'ChatMessage'))
      ..add(DiagnosticsProperty('id', id))
      ..add(DiagnosticsProperty('sender', sender))
      ..add(DiagnosticsProperty('content', content))
      ..add(DiagnosticsProperty('timestamp', timestamp))
      ..add(DiagnosticsProperty('isFromCurrentUser', isFromCurrentUser))
      ..add(DiagnosticsProperty('isRead', isRead));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatMessageImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.sender, sender) || other.sender == sender) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.isFromCurrentUser, isFromCurrentUser) ||
                other.isFromCurrentUser == isFromCurrentUser) &&
            (identical(other.isRead, isRead) || other.isRead == isRead));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, sender, content, timestamp, isFromCurrentUser, isRead);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatMessageImplCopyWith<_$ChatMessageImpl> get copyWith =>
      __$$ChatMessageImplCopyWithImpl<_$ChatMessageImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChatMessageImplToJson(
      this,
    );
  }
}

abstract class _ChatMessage implements ChatMessage {
  const factory _ChatMessage(
      {required final String id,
      @UserConverter() required final User sender,
      required final MessageContent content,
      @TimestampConverter() required final DateTime timestamp,
      final bool isFromCurrentUser,
      final bool isRead}) = _$ChatMessageImpl;

  factory _ChatMessage.fromJson(Map<String, dynamic> json) =
      _$ChatMessageImpl.fromJson;

  @override
  String get id;
  @override
  @UserConverter()
  User get sender;
  @override
  MessageContent get content;
  @override
  @TimestampConverter()
  DateTime get timestamp;
  @override
  bool get isFromCurrentUser;
  @override
  bool get isRead;
  @override
  @JsonKey(ignore: true)
  _$$ChatMessageImplCopyWith<_$ChatMessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MessageContent _$MessageContentFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'text':
      return TextMessage.fromJson(json);
    case 'video':
      return VideoMessageContent.fromJson(json);
    case 'reaction':
      return ReactionMessage.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'MessageContent',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$MessageContent {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String text) text,
    required TResult Function(VideoMessage video) video,
    required TResult Function(String emoji) reaction,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String text)? text,
    TResult? Function(VideoMessage video)? video,
    TResult? Function(String emoji)? reaction,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String text)? text,
    TResult Function(VideoMessage video)? video,
    TResult Function(String emoji)? reaction,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(TextMessage value) text,
    required TResult Function(VideoMessageContent value) video,
    required TResult Function(ReactionMessage value) reaction,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(TextMessage value)? text,
    TResult? Function(VideoMessageContent value)? video,
    TResult? Function(ReactionMessage value)? reaction,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(TextMessage value)? text,
    TResult Function(VideoMessageContent value)? video,
    TResult Function(ReactionMessage value)? reaction,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MessageContentCopyWith<$Res> {
  factory $MessageContentCopyWith(
          MessageContent value, $Res Function(MessageContent) then) =
      _$MessageContentCopyWithImpl<$Res, MessageContent>;
}

/// @nodoc
class _$MessageContentCopyWithImpl<$Res, $Val extends MessageContent>
    implements $MessageContentCopyWith<$Res> {
  _$MessageContentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;
}

/// @nodoc
abstract class _$$TextMessageImplCopyWith<$Res> {
  factory _$$TextMessageImplCopyWith(
          _$TextMessageImpl value, $Res Function(_$TextMessageImpl) then) =
      __$$TextMessageImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String text});
}

/// @nodoc
class __$$TextMessageImplCopyWithImpl<$Res>
    extends _$MessageContentCopyWithImpl<$Res, _$TextMessageImpl>
    implements _$$TextMessageImplCopyWith<$Res> {
  __$$TextMessageImplCopyWithImpl(
      _$TextMessageImpl _value, $Res Function(_$TextMessageImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? text = null,
  }) {
    return _then(_$TextMessageImpl(
      null == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TextMessageImpl with DiagnosticableTreeMixin implements TextMessage {
  const _$TextMessageImpl(this.text, {final String? $type})
      : $type = $type ?? 'text';

  factory _$TextMessageImpl.fromJson(Map<String, dynamic> json) =>
      _$$TextMessageImplFromJson(json);

  @override
  final String text;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'MessageContent.text(text: $text)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'MessageContent.text'))
      ..add(DiagnosticsProperty('text', text));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TextMessageImpl &&
            (identical(other.text, text) || other.text == text));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, text);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$TextMessageImplCopyWith<_$TextMessageImpl> get copyWith =>
      __$$TextMessageImplCopyWithImpl<_$TextMessageImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String text) text,
    required TResult Function(VideoMessage video) video,
    required TResult Function(String emoji) reaction,
  }) {
    return text(this.text);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String text)? text,
    TResult? Function(VideoMessage video)? video,
    TResult? Function(String emoji)? reaction,
  }) {
    return text?.call(this.text);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String text)? text,
    TResult Function(VideoMessage video)? video,
    TResult Function(String emoji)? reaction,
    required TResult orElse(),
  }) {
    if (text != null) {
      return text(this.text);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(TextMessage value) text,
    required TResult Function(VideoMessageContent value) video,
    required TResult Function(ReactionMessage value) reaction,
  }) {
    return text(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(TextMessage value)? text,
    TResult? Function(VideoMessageContent value)? video,
    TResult? Function(ReactionMessage value)? reaction,
  }) {
    return text?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(TextMessage value)? text,
    TResult Function(VideoMessageContent value)? video,
    TResult Function(ReactionMessage value)? reaction,
    required TResult orElse(),
  }) {
    if (text != null) {
      return text(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$TextMessageImplToJson(
      this,
    );
  }
}

abstract class TextMessage implements MessageContent {
  const factory TextMessage(final String text) = _$TextMessageImpl;

  factory TextMessage.fromJson(Map<String, dynamic> json) =
      _$TextMessageImpl.fromJson;

  String get text;
  @JsonKey(ignore: true)
  _$$TextMessageImplCopyWith<_$TextMessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$VideoMessageContentImplCopyWith<$Res> {
  factory _$$VideoMessageContentImplCopyWith(_$VideoMessageContentImpl value,
          $Res Function(_$VideoMessageContentImpl) then) =
      __$$VideoMessageContentImplCopyWithImpl<$Res>;
  @useResult
  $Res call({VideoMessage video});

  $VideoMessageCopyWith<$Res> get video;
}

/// @nodoc
class __$$VideoMessageContentImplCopyWithImpl<$Res>
    extends _$MessageContentCopyWithImpl<$Res, _$VideoMessageContentImpl>
    implements _$$VideoMessageContentImplCopyWith<$Res> {
  __$$VideoMessageContentImplCopyWithImpl(_$VideoMessageContentImpl _value,
      $Res Function(_$VideoMessageContentImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? video = null,
  }) {
    return _then(_$VideoMessageContentImpl(
      null == video
          ? _value.video
          : video // ignore: cast_nullable_to_non_nullable
              as VideoMessage,
    ));
  }

  @override
  @pragma('vm:prefer-inline')
  $VideoMessageCopyWith<$Res> get video {
    return $VideoMessageCopyWith<$Res>(_value.video, (value) {
      return _then(_value.copyWith(video: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$VideoMessageContentImpl
    with DiagnosticableTreeMixin
    implements VideoMessageContent {
  const _$VideoMessageContentImpl(this.video, {final String? $type})
      : $type = $type ?? 'video';

  factory _$VideoMessageContentImpl.fromJson(Map<String, dynamic> json) =>
      _$$VideoMessageContentImplFromJson(json);

  @override
  final VideoMessage video;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'MessageContent.video(video: $video)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'MessageContent.video'))
      ..add(DiagnosticsProperty('video', video));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VideoMessageContentImpl &&
            (identical(other.video, video) || other.video == video));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, video);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$VideoMessageContentImplCopyWith<_$VideoMessageContentImpl> get copyWith =>
      __$$VideoMessageContentImplCopyWithImpl<_$VideoMessageContentImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String text) text,
    required TResult Function(VideoMessage video) video,
    required TResult Function(String emoji) reaction,
  }) {
    return video(this.video);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String text)? text,
    TResult? Function(VideoMessage video)? video,
    TResult? Function(String emoji)? reaction,
  }) {
    return video?.call(this.video);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String text)? text,
    TResult Function(VideoMessage video)? video,
    TResult Function(String emoji)? reaction,
    required TResult orElse(),
  }) {
    if (video != null) {
      return video(this.video);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(TextMessage value) text,
    required TResult Function(VideoMessageContent value) video,
    required TResult Function(ReactionMessage value) reaction,
  }) {
    return video(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(TextMessage value)? text,
    TResult? Function(VideoMessageContent value)? video,
    TResult? Function(ReactionMessage value)? reaction,
  }) {
    return video?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(TextMessage value)? text,
    TResult Function(VideoMessageContent value)? video,
    TResult Function(ReactionMessage value)? reaction,
    required TResult orElse(),
  }) {
    if (video != null) {
      return video(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$VideoMessageContentImplToJson(
      this,
    );
  }
}

abstract class VideoMessageContent implements MessageContent {
  const factory VideoMessageContent(final VideoMessage video) =
      _$VideoMessageContentImpl;

  factory VideoMessageContent.fromJson(Map<String, dynamic> json) =
      _$VideoMessageContentImpl.fromJson;

  VideoMessage get video;
  @JsonKey(ignore: true)
  _$$VideoMessageContentImplCopyWith<_$VideoMessageContentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ReactionMessageImplCopyWith<$Res> {
  factory _$$ReactionMessageImplCopyWith(_$ReactionMessageImpl value,
          $Res Function(_$ReactionMessageImpl) then) =
      __$$ReactionMessageImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String emoji});
}

/// @nodoc
class __$$ReactionMessageImplCopyWithImpl<$Res>
    extends _$MessageContentCopyWithImpl<$Res, _$ReactionMessageImpl>
    implements _$$ReactionMessageImplCopyWith<$Res> {
  __$$ReactionMessageImplCopyWithImpl(
      _$ReactionMessageImpl _value, $Res Function(_$ReactionMessageImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? emoji = null,
  }) {
    return _then(_$ReactionMessageImpl(
      null == emoji
          ? _value.emoji
          : emoji // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ReactionMessageImpl
    with DiagnosticableTreeMixin
    implements ReactionMessage {
  const _$ReactionMessageImpl(this.emoji, {final String? $type})
      : $type = $type ?? 'reaction';

  factory _$ReactionMessageImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReactionMessageImplFromJson(json);

  @override
  final String emoji;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'MessageContent.reaction(emoji: $emoji)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'MessageContent.reaction'))
      ..add(DiagnosticsProperty('emoji', emoji));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReactionMessageImpl &&
            (identical(other.emoji, emoji) || other.emoji == emoji));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, emoji);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ReactionMessageImplCopyWith<_$ReactionMessageImpl> get copyWith =>
      __$$ReactionMessageImplCopyWithImpl<_$ReactionMessageImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String text) text,
    required TResult Function(VideoMessage video) video,
    required TResult Function(String emoji) reaction,
  }) {
    return reaction(emoji);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String text)? text,
    TResult? Function(VideoMessage video)? video,
    TResult? Function(String emoji)? reaction,
  }) {
    return reaction?.call(emoji);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String text)? text,
    TResult Function(VideoMessage video)? video,
    TResult Function(String emoji)? reaction,
    required TResult orElse(),
  }) {
    if (reaction != null) {
      return reaction(emoji);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(TextMessage value) text,
    required TResult Function(VideoMessageContent value) video,
    required TResult Function(ReactionMessage value) reaction,
  }) {
    return reaction(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(TextMessage value)? text,
    TResult? Function(VideoMessageContent value)? video,
    TResult? Function(ReactionMessage value)? reaction,
  }) {
    return reaction?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(TextMessage value)? text,
    TResult Function(VideoMessageContent value)? video,
    TResult Function(ReactionMessage value)? reaction,
    required TResult orElse(),
  }) {
    if (reaction != null) {
      return reaction(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$ReactionMessageImplToJson(
      this,
    );
  }
}

abstract class ReactionMessage implements MessageContent {
  const factory ReactionMessage(final String emoji) = _$ReactionMessageImpl;

  factory ReactionMessage.fromJson(Map<String, dynamic> json) =
      _$ReactionMessageImpl.fromJson;

  String get emoji;
  @JsonKey(ignore: true)
  _$$ReactionMessageImplCopyWith<_$ReactionMessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

VideoMessage _$VideoMessageFromJson(Map<String, dynamic> json) {
  return _VideoMessage.fromJson(json);
}

/// @nodoc
mixin _$VideoMessage {
  String get videoURL => throw _privateConstructorUsedError;
  String? get thumbnailURL => throw _privateConstructorUsedError;
  String? get caption => throw _privateConstructorUsedError;
  double get duration => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $VideoMessageCopyWith<VideoMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VideoMessageCopyWith<$Res> {
  factory $VideoMessageCopyWith(
          VideoMessage value, $Res Function(VideoMessage) then) =
      _$VideoMessageCopyWithImpl<$Res, VideoMessage>;
  @useResult
  $Res call(
      {String videoURL,
      String? thumbnailURL,
      String? caption,
      double duration});
}

/// @nodoc
class _$VideoMessageCopyWithImpl<$Res, $Val extends VideoMessage>
    implements $VideoMessageCopyWith<$Res> {
  _$VideoMessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? videoURL = null,
    Object? thumbnailURL = freezed,
    Object? caption = freezed,
    Object? duration = null,
  }) {
    return _then(_value.copyWith(
      videoURL: null == videoURL
          ? _value.videoURL
          : videoURL // ignore: cast_nullable_to_non_nullable
              as String,
      thumbnailURL: freezed == thumbnailURL
          ? _value.thumbnailURL
          : thumbnailURL // ignore: cast_nullable_to_non_nullable
              as String?,
      caption: freezed == caption
          ? _value.caption
          : caption // ignore: cast_nullable_to_non_nullable
              as String?,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$VideoMessageImplCopyWith<$Res>
    implements $VideoMessageCopyWith<$Res> {
  factory _$$VideoMessageImplCopyWith(
          _$VideoMessageImpl value, $Res Function(_$VideoMessageImpl) then) =
      __$$VideoMessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String videoURL,
      String? thumbnailURL,
      String? caption,
      double duration});
}

/// @nodoc
class __$$VideoMessageImplCopyWithImpl<$Res>
    extends _$VideoMessageCopyWithImpl<$Res, _$VideoMessageImpl>
    implements _$$VideoMessageImplCopyWith<$Res> {
  __$$VideoMessageImplCopyWithImpl(
      _$VideoMessageImpl _value, $Res Function(_$VideoMessageImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? videoURL = null,
    Object? thumbnailURL = freezed,
    Object? caption = freezed,
    Object? duration = null,
  }) {
    return _then(_$VideoMessageImpl(
      videoURL: null == videoURL
          ? _value.videoURL
          : videoURL // ignore: cast_nullable_to_non_nullable
              as String,
      thumbnailURL: freezed == thumbnailURL
          ? _value.thumbnailURL
          : thumbnailURL // ignore: cast_nullable_to_non_nullable
              as String?,
      caption: freezed == caption
          ? _value.caption
          : caption // ignore: cast_nullable_to_non_nullable
              as String?,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$VideoMessageImpl with DiagnosticableTreeMixin implements _VideoMessage {
  const _$VideoMessageImpl(
      {required this.videoURL,
      this.thumbnailURL,
      this.caption,
      required this.duration});

  factory _$VideoMessageImpl.fromJson(Map<String, dynamic> json) =>
      _$$VideoMessageImplFromJson(json);

  @override
  final String videoURL;
  @override
  final String? thumbnailURL;
  @override
  final String? caption;
  @override
  final double duration;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'VideoMessage(videoURL: $videoURL, thumbnailURL: $thumbnailURL, caption: $caption, duration: $duration)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'VideoMessage'))
      ..add(DiagnosticsProperty('videoURL', videoURL))
      ..add(DiagnosticsProperty('thumbnailURL', thumbnailURL))
      ..add(DiagnosticsProperty('caption', caption))
      ..add(DiagnosticsProperty('duration', duration));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VideoMessageImpl &&
            (identical(other.videoURL, videoURL) ||
                other.videoURL == videoURL) &&
            (identical(other.thumbnailURL, thumbnailURL) ||
                other.thumbnailURL == thumbnailURL) &&
            (identical(other.caption, caption) || other.caption == caption) &&
            (identical(other.duration, duration) ||
                other.duration == duration));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, videoURL, thumbnailURL, caption, duration);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$VideoMessageImplCopyWith<_$VideoMessageImpl> get copyWith =>
      __$$VideoMessageImplCopyWithImpl<_$VideoMessageImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VideoMessageImplToJson(
      this,
    );
  }
}

abstract class _VideoMessage implements VideoMessage {
  const factory _VideoMessage(
      {required final String videoURL,
      final String? thumbnailURL,
      final String? caption,
      required final double duration}) = _$VideoMessageImpl;

  factory _VideoMessage.fromJson(Map<String, dynamic> json) =
      _$VideoMessageImpl.fromJson;

  @override
  String get videoURL;
  @override
  String? get thumbnailURL;
  @override
  String? get caption;
  @override
  double get duration;
  @override
  @JsonKey(ignore: true)
  _$$VideoMessageImplCopyWith<_$VideoMessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
