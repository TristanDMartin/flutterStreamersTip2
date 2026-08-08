// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Message implements DiagnosticableTreeMixin {
  String? get id;
  String? get chatId;
  String get text;
  String get from;
  String get to;
  @TimestampConverter()
  DateTime? get timestamp;
  bool get isRead;
  List<String> get recipients;
  List<String> get readBy;
  String? get gifUrl;
  String get messageType;
  bool get isDeviceGif; // Video share fields
  String? get videoId;
  String? get shareToken;
  String? get videoThumbnailUrl;
  String? get videoTitle;
  String? get replyToMessageId;
  String? get replyToSenderId;
  String? get replyToSenderName;
  String? get replyToType;
  String? get replyPreviewText;
  String? get replyThumbnailUrl;
  String? get replyVideoId;
  bool get deletedForEveryone;

  /// Map of uid → { userId, reaction, timestamp } (web/Flutter shared schema).
  Map<String, dynamic> get reactions;
  bool get edited;
  @TimestampConverter()
  DateTime? get editedAt;

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MessageCopyWith<Message> get copyWith =>
      _$MessageCopyWithImpl<Message>(this as Message, _$identity);

  /// Serializes this Message to a JSON map.
  Map<String, dynamic> toJson();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
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
      ..add(DiagnosticsProperty('isDeviceGif', isDeviceGif))
      ..add(DiagnosticsProperty('videoId', videoId))
      ..add(DiagnosticsProperty('shareToken', shareToken))
      ..add(DiagnosticsProperty('videoThumbnailUrl', videoThumbnailUrl))
      ..add(DiagnosticsProperty('videoTitle', videoTitle))
      ..add(DiagnosticsProperty('replyToMessageId', replyToMessageId))
      ..add(DiagnosticsProperty('replyToSenderId', replyToSenderId))
      ..add(DiagnosticsProperty('replyToSenderName', replyToSenderName))
      ..add(DiagnosticsProperty('replyToType', replyToType))
      ..add(DiagnosticsProperty('replyPreviewText', replyPreviewText))
      ..add(DiagnosticsProperty('replyThumbnailUrl', replyThumbnailUrl))
      ..add(DiagnosticsProperty('replyVideoId', replyVideoId))
      ..add(DiagnosticsProperty('deletedForEveryone', deletedForEveryone))
      ..add(DiagnosticsProperty('reactions', reactions))
      ..add(DiagnosticsProperty('edited', edited))
      ..add(DiagnosticsProperty('editedAt', editedAt));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Message &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.chatId, chatId) || other.chatId == chatId) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.from, from) || other.from == from) &&
            (identical(other.to, to) || other.to == to) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.isRead, isRead) || other.isRead == isRead) &&
            const DeepCollectionEquality()
                .equals(other.recipients, recipients) &&
            const DeepCollectionEquality().equals(other.readBy, readBy) &&
            (identical(other.gifUrl, gifUrl) || other.gifUrl == gifUrl) &&
            (identical(other.messageType, messageType) ||
                other.messageType == messageType) &&
            (identical(other.isDeviceGif, isDeviceGif) ||
                other.isDeviceGif == isDeviceGif) &&
            (identical(other.videoId, videoId) || other.videoId == videoId) &&
            (identical(other.shareToken, shareToken) ||
                other.shareToken == shareToken) &&
            (identical(other.videoThumbnailUrl, videoThumbnailUrl) ||
                other.videoThumbnailUrl == videoThumbnailUrl) &&
            (identical(other.videoTitle, videoTitle) ||
                other.videoTitle == videoTitle) &&
            (identical(other.replyToMessageId, replyToMessageId) ||
                other.replyToMessageId == replyToMessageId) &&
            (identical(other.replyToSenderId, replyToSenderId) ||
                other.replyToSenderId == replyToSenderId) &&
            (identical(other.replyToSenderName, replyToSenderName) ||
                other.replyToSenderName == replyToSenderName) &&
            (identical(other.replyToType, replyToType) ||
                other.replyToType == replyToType) &&
            (identical(other.replyPreviewText, replyPreviewText) ||
                other.replyPreviewText == replyPreviewText) &&
            (identical(other.replyThumbnailUrl, replyThumbnailUrl) ||
                other.replyThumbnailUrl == replyThumbnailUrl) &&
            (identical(other.replyVideoId, replyVideoId) ||
                other.replyVideoId == replyVideoId) &&
            (identical(other.deletedForEveryone, deletedForEveryone) ||
                other.deletedForEveryone == deletedForEveryone) &&
            const DeepCollectionEquality().equals(other.reactions, reactions) &&
            (identical(other.edited, edited) || other.edited == edited) &&
            (identical(other.editedAt, editedAt) ||
                other.editedAt == editedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        chatId,
        text,
        from,
        to,
        timestamp,
        isRead,
        const DeepCollectionEquality().hash(recipients),
        const DeepCollectionEquality().hash(readBy),
        gifUrl,
        messageType,
        isDeviceGif,
        videoId,
        shareToken,
        videoThumbnailUrl,
        videoTitle,
        replyToMessageId,
        replyToSenderId,
        replyToSenderName,
        replyToType,
        replyPreviewText,
        replyThumbnailUrl,
        replyVideoId,
        deletedForEveryone,
        const DeepCollectionEquality().hash(reactions),
        edited,
        editedAt
      ]);

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'Message(id: $id, chatId: $chatId, text: $text, from: $from, to: $to, timestamp: $timestamp, isRead: $isRead, recipients: $recipients, readBy: $readBy, gifUrl: $gifUrl, messageType: $messageType, isDeviceGif: $isDeviceGif, videoId: $videoId, shareToken: $shareToken, videoThumbnailUrl: $videoThumbnailUrl, videoTitle: $videoTitle, replyToMessageId: $replyToMessageId, replyToSenderId: $replyToSenderId, replyToSenderName: $replyToSenderName, replyToType: $replyToType, replyPreviewText: $replyPreviewText, replyThumbnailUrl: $replyThumbnailUrl, replyVideoId: $replyVideoId, deletedForEveryone: $deletedForEveryone, reactions: $reactions, edited: $edited, editedAt: $editedAt)';
  }
}

/// @nodoc
abstract mixin class $MessageCopyWith<$Res> {
  factory $MessageCopyWith(Message value, $Res Function(Message) _then) =
      _$MessageCopyWithImpl;
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
      bool isDeviceGif,
      String? videoId,
      String? shareToken,
      String? videoThumbnailUrl,
      String? videoTitle,
      String? replyToMessageId,
      String? replyToSenderId,
      String? replyToSenderName,
      String? replyToType,
      String? replyPreviewText,
      String? replyThumbnailUrl,
      String? replyVideoId,
      bool deletedForEveryone,
      Map<String, dynamic> reactions,
      bool edited,
      @TimestampConverter() DateTime? editedAt});
}

/// @nodoc
class _$MessageCopyWithImpl<$Res> implements $MessageCopyWith<$Res> {
  _$MessageCopyWithImpl(this._self, this._then);

  final Message _self;
  final $Res Function(Message) _then;

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
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
    Object? videoId = freezed,
    Object? shareToken = freezed,
    Object? videoThumbnailUrl = freezed,
    Object? videoTitle = freezed,
    Object? replyToMessageId = freezed,
    Object? replyToSenderId = freezed,
    Object? replyToSenderName = freezed,
    Object? replyToType = freezed,
    Object? replyPreviewText = freezed,
    Object? replyThumbnailUrl = freezed,
    Object? replyVideoId = freezed,
    Object? deletedForEveryone = null,
    Object? reactions = null,
    Object? edited = null,
    Object? editedAt = freezed,
  }) {
    return _then(_self.copyWith(
      id: freezed == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      chatId: freezed == chatId
          ? _self.chatId
          : chatId // ignore: cast_nullable_to_non_nullable
              as String?,
      text: null == text
          ? _self.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      from: null == from
          ? _self.from
          : from // ignore: cast_nullable_to_non_nullable
              as String,
      to: null == to
          ? _self.to
          : to // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: freezed == timestamp
          ? _self.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      isRead: null == isRead
          ? _self.isRead
          : isRead // ignore: cast_nullable_to_non_nullable
              as bool,
      recipients: null == recipients
          ? _self.recipients
          : recipients // ignore: cast_nullable_to_non_nullable
              as List<String>,
      readBy: null == readBy
          ? _self.readBy
          : readBy // ignore: cast_nullable_to_non_nullable
              as List<String>,
      gifUrl: freezed == gifUrl
          ? _self.gifUrl
          : gifUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      messageType: null == messageType
          ? _self.messageType
          : messageType // ignore: cast_nullable_to_non_nullable
              as String,
      isDeviceGif: null == isDeviceGif
          ? _self.isDeviceGif
          : isDeviceGif // ignore: cast_nullable_to_non_nullable
              as bool,
      videoId: freezed == videoId
          ? _self.videoId
          : videoId // ignore: cast_nullable_to_non_nullable
              as String?,
      shareToken: freezed == shareToken
          ? _self.shareToken
          : shareToken // ignore: cast_nullable_to_non_nullable
              as String?,
      videoThumbnailUrl: freezed == videoThumbnailUrl
          ? _self.videoThumbnailUrl
          : videoThumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      videoTitle: freezed == videoTitle
          ? _self.videoTitle
          : videoTitle // ignore: cast_nullable_to_non_nullable
              as String?,
      replyToMessageId: freezed == replyToMessageId
          ? _self.replyToMessageId
          : replyToMessageId // ignore: cast_nullable_to_non_nullable
              as String?,
      replyToSenderId: freezed == replyToSenderId
          ? _self.replyToSenderId
          : replyToSenderId // ignore: cast_nullable_to_non_nullable
              as String?,
      replyToSenderName: freezed == replyToSenderName
          ? _self.replyToSenderName
          : replyToSenderName // ignore: cast_nullable_to_non_nullable
              as String?,
      replyToType: freezed == replyToType
          ? _self.replyToType
          : replyToType // ignore: cast_nullable_to_non_nullable
              as String?,
      replyPreviewText: freezed == replyPreviewText
          ? _self.replyPreviewText
          : replyPreviewText // ignore: cast_nullable_to_non_nullable
              as String?,
      replyThumbnailUrl: freezed == replyThumbnailUrl
          ? _self.replyThumbnailUrl
          : replyThumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      replyVideoId: freezed == replyVideoId
          ? _self.replyVideoId
          : replyVideoId // ignore: cast_nullable_to_non_nullable
              as String?,
      deletedForEveryone: null == deletedForEveryone
          ? _self.deletedForEveryone
          : deletedForEveryone // ignore: cast_nullable_to_non_nullable
              as bool,
      reactions: null == reactions
          ? _self.reactions
          : reactions // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      edited: null == edited
          ? _self.edited
          : edited // ignore: cast_nullable_to_non_nullable
              as bool,
      editedAt: freezed == editedAt
          ? _self.editedAt
          : editedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// Adds pattern-matching-related methods to [Message].
extension MessagePatterns on Message {
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
    TResult Function(_Message value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Message() when $default != null:
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
    TResult Function(_Message value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Message():
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
    TResult? Function(_Message value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Message() when $default != null:
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
            String? id,
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
            bool isDeviceGif,
            String? videoId,
            String? shareToken,
            String? videoThumbnailUrl,
            String? videoTitle,
            String? replyToMessageId,
            String? replyToSenderId,
            String? replyToSenderName,
            String? replyToType,
            String? replyPreviewText,
            String? replyThumbnailUrl,
            String? replyVideoId,
            bool deletedForEveryone,
            Map<String, dynamic> reactions,
            bool edited,
            @TimestampConverter() DateTime? editedAt)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Message() when $default != null:
        return $default(
            _that.id,
            _that.chatId,
            _that.text,
            _that.from,
            _that.to,
            _that.timestamp,
            _that.isRead,
            _that.recipients,
            _that.readBy,
            _that.gifUrl,
            _that.messageType,
            _that.isDeviceGif,
            _that.videoId,
            _that.shareToken,
            _that.videoThumbnailUrl,
            _that.videoTitle,
            _that.replyToMessageId,
            _that.replyToSenderId,
            _that.replyToSenderName,
            _that.replyToType,
            _that.replyPreviewText,
            _that.replyThumbnailUrl,
            _that.replyVideoId,
            _that.deletedForEveryone,
            _that.reactions,
            _that.edited,
            _that.editedAt);
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
            String? id,
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
            bool isDeviceGif,
            String? videoId,
            String? shareToken,
            String? videoThumbnailUrl,
            String? videoTitle,
            String? replyToMessageId,
            String? replyToSenderId,
            String? replyToSenderName,
            String? replyToType,
            String? replyPreviewText,
            String? replyThumbnailUrl,
            String? replyVideoId,
            bool deletedForEveryone,
            Map<String, dynamic> reactions,
            bool edited,
            @TimestampConverter() DateTime? editedAt)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Message():
        return $default(
            _that.id,
            _that.chatId,
            _that.text,
            _that.from,
            _that.to,
            _that.timestamp,
            _that.isRead,
            _that.recipients,
            _that.readBy,
            _that.gifUrl,
            _that.messageType,
            _that.isDeviceGif,
            _that.videoId,
            _that.shareToken,
            _that.videoThumbnailUrl,
            _that.videoTitle,
            _that.replyToMessageId,
            _that.replyToSenderId,
            _that.replyToSenderName,
            _that.replyToType,
            _that.replyPreviewText,
            _that.replyThumbnailUrl,
            _that.replyVideoId,
            _that.deletedForEveryone,
            _that.reactions,
            _that.edited,
            _that.editedAt);
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
            String? id,
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
            bool isDeviceGif,
            String? videoId,
            String? shareToken,
            String? videoThumbnailUrl,
            String? videoTitle,
            String? replyToMessageId,
            String? replyToSenderId,
            String? replyToSenderName,
            String? replyToType,
            String? replyPreviewText,
            String? replyThumbnailUrl,
            String? replyVideoId,
            bool deletedForEveryone,
            Map<String, dynamic> reactions,
            bool edited,
            @TimestampConverter() DateTime? editedAt)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Message() when $default != null:
        return $default(
            _that.id,
            _that.chatId,
            _that.text,
            _that.from,
            _that.to,
            _that.timestamp,
            _that.isRead,
            _that.recipients,
            _that.readBy,
            _that.gifUrl,
            _that.messageType,
            _that.isDeviceGif,
            _that.videoId,
            _that.shareToken,
            _that.videoThumbnailUrl,
            _that.videoTitle,
            _that.replyToMessageId,
            _that.replyToSenderId,
            _that.replyToSenderName,
            _that.replyToType,
            _that.replyPreviewText,
            _that.replyThumbnailUrl,
            _that.replyVideoId,
            _that.deletedForEveryone,
            _that.reactions,
            _that.edited,
            _that.editedAt);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Message with DiagnosticableTreeMixin implements Message {
  const _Message(
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
      this.isDeviceGif = false,
      this.videoId,
      this.shareToken,
      this.videoThumbnailUrl,
      this.videoTitle,
      this.replyToMessageId,
      this.replyToSenderId,
      this.replyToSenderName,
      this.replyToType,
      this.replyPreviewText,
      this.replyThumbnailUrl,
      this.replyVideoId,
      this.deletedForEveryone = false,
      final Map<String, dynamic> reactions = const <String, dynamic>{},
      this.edited = false,
      @TimestampConverter() this.editedAt})
      : _recipients = recipients,
        _readBy = readBy,
        _reactions = reactions;
  factory _Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);

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
// Video share fields
  @override
  final String? videoId;
  @override
  final String? shareToken;
  @override
  final String? videoThumbnailUrl;
  @override
  final String? videoTitle;
  @override
  final String? replyToMessageId;
  @override
  final String? replyToSenderId;
  @override
  final String? replyToSenderName;
  @override
  final String? replyToType;
  @override
  final String? replyPreviewText;
  @override
  final String? replyThumbnailUrl;
  @override
  final String? replyVideoId;
  @override
  @JsonKey()
  final bool deletedForEveryone;

  /// Map of uid → { userId, reaction, timestamp } (web/Flutter shared schema).
  final Map<String, dynamic> _reactions;

  /// Map of uid → { userId, reaction, timestamp } (web/Flutter shared schema).
  @override
  @JsonKey()
  Map<String, dynamic> get reactions {
    if (_reactions is EqualUnmodifiableMapView) return _reactions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_reactions);
  }

  @override
  @JsonKey()
  final bool edited;
  @override
  @TimestampConverter()
  final DateTime? editedAt;

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MessageCopyWith<_Message> get copyWith =>
      __$MessageCopyWithImpl<_Message>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$MessageToJson(
      this,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
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
      ..add(DiagnosticsProperty('isDeviceGif', isDeviceGif))
      ..add(DiagnosticsProperty('videoId', videoId))
      ..add(DiagnosticsProperty('shareToken', shareToken))
      ..add(DiagnosticsProperty('videoThumbnailUrl', videoThumbnailUrl))
      ..add(DiagnosticsProperty('videoTitle', videoTitle))
      ..add(DiagnosticsProperty('replyToMessageId', replyToMessageId))
      ..add(DiagnosticsProperty('replyToSenderId', replyToSenderId))
      ..add(DiagnosticsProperty('replyToSenderName', replyToSenderName))
      ..add(DiagnosticsProperty('replyToType', replyToType))
      ..add(DiagnosticsProperty('replyPreviewText', replyPreviewText))
      ..add(DiagnosticsProperty('replyThumbnailUrl', replyThumbnailUrl))
      ..add(DiagnosticsProperty('replyVideoId', replyVideoId))
      ..add(DiagnosticsProperty('deletedForEveryone', deletedForEveryone))
      ..add(DiagnosticsProperty('reactions', reactions))
      ..add(DiagnosticsProperty('edited', edited))
      ..add(DiagnosticsProperty('editedAt', editedAt));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Message &&
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
                other.isDeviceGif == isDeviceGif) &&
            (identical(other.videoId, videoId) || other.videoId == videoId) &&
            (identical(other.shareToken, shareToken) ||
                other.shareToken == shareToken) &&
            (identical(other.videoThumbnailUrl, videoThumbnailUrl) ||
                other.videoThumbnailUrl == videoThumbnailUrl) &&
            (identical(other.videoTitle, videoTitle) ||
                other.videoTitle == videoTitle) &&
            (identical(other.replyToMessageId, replyToMessageId) ||
                other.replyToMessageId == replyToMessageId) &&
            (identical(other.replyToSenderId, replyToSenderId) ||
                other.replyToSenderId == replyToSenderId) &&
            (identical(other.replyToSenderName, replyToSenderName) ||
                other.replyToSenderName == replyToSenderName) &&
            (identical(other.replyToType, replyToType) ||
                other.replyToType == replyToType) &&
            (identical(other.replyPreviewText, replyPreviewText) ||
                other.replyPreviewText == replyPreviewText) &&
            (identical(other.replyThumbnailUrl, replyThumbnailUrl) ||
                other.replyThumbnailUrl == replyThumbnailUrl) &&
            (identical(other.replyVideoId, replyVideoId) ||
                other.replyVideoId == replyVideoId) &&
            (identical(other.deletedForEveryone, deletedForEveryone) ||
                other.deletedForEveryone == deletedForEveryone) &&
            const DeepCollectionEquality()
                .equals(other._reactions, _reactions) &&
            (identical(other.edited, edited) || other.edited == edited) &&
            (identical(other.editedAt, editedAt) ||
                other.editedAt == editedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
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
        isDeviceGif,
        videoId,
        shareToken,
        videoThumbnailUrl,
        videoTitle,
        replyToMessageId,
        replyToSenderId,
        replyToSenderName,
        replyToType,
        replyPreviewText,
        replyThumbnailUrl,
        replyVideoId,
        deletedForEveryone,
        const DeepCollectionEquality().hash(_reactions),
        edited,
        editedAt
      ]);

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'Message(id: $id, chatId: $chatId, text: $text, from: $from, to: $to, timestamp: $timestamp, isRead: $isRead, recipients: $recipients, readBy: $readBy, gifUrl: $gifUrl, messageType: $messageType, isDeviceGif: $isDeviceGif, videoId: $videoId, shareToken: $shareToken, videoThumbnailUrl: $videoThumbnailUrl, videoTitle: $videoTitle, replyToMessageId: $replyToMessageId, replyToSenderId: $replyToSenderId, replyToSenderName: $replyToSenderName, replyToType: $replyToType, replyPreviewText: $replyPreviewText, replyThumbnailUrl: $replyThumbnailUrl, replyVideoId: $replyVideoId, deletedForEveryone: $deletedForEveryone, reactions: $reactions, edited: $edited, editedAt: $editedAt)';
  }
}

/// @nodoc
abstract mixin class _$MessageCopyWith<$Res> implements $MessageCopyWith<$Res> {
  factory _$MessageCopyWith(_Message value, $Res Function(_Message) _then) =
      __$MessageCopyWithImpl;
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
      bool isDeviceGif,
      String? videoId,
      String? shareToken,
      String? videoThumbnailUrl,
      String? videoTitle,
      String? replyToMessageId,
      String? replyToSenderId,
      String? replyToSenderName,
      String? replyToType,
      String? replyPreviewText,
      String? replyThumbnailUrl,
      String? replyVideoId,
      bool deletedForEveryone,
      Map<String, dynamic> reactions,
      bool edited,
      @TimestampConverter() DateTime? editedAt});
}

/// @nodoc
class __$MessageCopyWithImpl<$Res> implements _$MessageCopyWith<$Res> {
  __$MessageCopyWithImpl(this._self, this._then);

  final _Message _self;
  final $Res Function(_Message) _then;

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
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
    Object? videoId = freezed,
    Object? shareToken = freezed,
    Object? videoThumbnailUrl = freezed,
    Object? videoTitle = freezed,
    Object? replyToMessageId = freezed,
    Object? replyToSenderId = freezed,
    Object? replyToSenderName = freezed,
    Object? replyToType = freezed,
    Object? replyPreviewText = freezed,
    Object? replyThumbnailUrl = freezed,
    Object? replyVideoId = freezed,
    Object? deletedForEveryone = null,
    Object? reactions = null,
    Object? edited = null,
    Object? editedAt = freezed,
  }) {
    return _then(_Message(
      id: freezed == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      chatId: freezed == chatId
          ? _self.chatId
          : chatId // ignore: cast_nullable_to_non_nullable
              as String?,
      text: null == text
          ? _self.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      from: null == from
          ? _self.from
          : from // ignore: cast_nullable_to_non_nullable
              as String,
      to: null == to
          ? _self.to
          : to // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: freezed == timestamp
          ? _self.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      isRead: null == isRead
          ? _self.isRead
          : isRead // ignore: cast_nullable_to_non_nullable
              as bool,
      recipients: null == recipients
          ? _self._recipients
          : recipients // ignore: cast_nullable_to_non_nullable
              as List<String>,
      readBy: null == readBy
          ? _self._readBy
          : readBy // ignore: cast_nullable_to_non_nullable
              as List<String>,
      gifUrl: freezed == gifUrl
          ? _self.gifUrl
          : gifUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      messageType: null == messageType
          ? _self.messageType
          : messageType // ignore: cast_nullable_to_non_nullable
              as String,
      isDeviceGif: null == isDeviceGif
          ? _self.isDeviceGif
          : isDeviceGif // ignore: cast_nullable_to_non_nullable
              as bool,
      videoId: freezed == videoId
          ? _self.videoId
          : videoId // ignore: cast_nullable_to_non_nullable
              as String?,
      shareToken: freezed == shareToken
          ? _self.shareToken
          : shareToken // ignore: cast_nullable_to_non_nullable
              as String?,
      videoThumbnailUrl: freezed == videoThumbnailUrl
          ? _self.videoThumbnailUrl
          : videoThumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      videoTitle: freezed == videoTitle
          ? _self.videoTitle
          : videoTitle // ignore: cast_nullable_to_non_nullable
              as String?,
      replyToMessageId: freezed == replyToMessageId
          ? _self.replyToMessageId
          : replyToMessageId // ignore: cast_nullable_to_non_nullable
              as String?,
      replyToSenderId: freezed == replyToSenderId
          ? _self.replyToSenderId
          : replyToSenderId // ignore: cast_nullable_to_non_nullable
              as String?,
      replyToSenderName: freezed == replyToSenderName
          ? _self.replyToSenderName
          : replyToSenderName // ignore: cast_nullable_to_non_nullable
              as String?,
      replyToType: freezed == replyToType
          ? _self.replyToType
          : replyToType // ignore: cast_nullable_to_non_nullable
              as String?,
      replyPreviewText: freezed == replyPreviewText
          ? _self.replyPreviewText
          : replyPreviewText // ignore: cast_nullable_to_non_nullable
              as String?,
      replyThumbnailUrl: freezed == replyThumbnailUrl
          ? _self.replyThumbnailUrl
          : replyThumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      replyVideoId: freezed == replyVideoId
          ? _self.replyVideoId
          : replyVideoId // ignore: cast_nullable_to_non_nullable
              as String?,
      deletedForEveryone: null == deletedForEveryone
          ? _self.deletedForEveryone
          : deletedForEveryone // ignore: cast_nullable_to_non_nullable
              as bool,
      reactions: null == reactions
          ? _self._reactions
          : reactions // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      edited: null == edited
          ? _self.edited
          : edited // ignore: cast_nullable_to_non_nullable
              as bool,
      editedAt: freezed == editedAt
          ? _self.editedAt
          : editedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

// dart format on
