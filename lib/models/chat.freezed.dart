// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Chat {
  String? get id;
  List<String> get participants;
  String? get lastMessage;
  @TimestampConverter()
  DateTime get lastTimestamp;
  String? get chatType; // 'direct' or 'group'
  String? get groupName;
  String? get groupAvatarURL;
  List<String> get mutedBy;
  List<String> get archivedBy;
  Map<String, dynamic>? get metadata;

  /// Create a copy of Chat
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ChatCopyWith<Chat> get copyWith =>
      _$ChatCopyWithImpl<Chat>(this as Chat, _$identity);

  /// Serializes this Chat to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Chat &&
            (identical(other.id, id) || other.id == id) &&
            const DeepCollectionEquality()
                .equals(other.participants, participants) &&
            (identical(other.lastMessage, lastMessage) ||
                other.lastMessage == lastMessage) &&
            (identical(other.lastTimestamp, lastTimestamp) ||
                other.lastTimestamp == lastTimestamp) &&
            (identical(other.chatType, chatType) ||
                other.chatType == chatType) &&
            (identical(other.groupName, groupName) ||
                other.groupName == groupName) &&
            (identical(other.groupAvatarURL, groupAvatarURL) ||
                other.groupAvatarURL == groupAvatarURL) &&
            const DeepCollectionEquality().equals(other.mutedBy, mutedBy) &&
            const DeepCollectionEquality()
                .equals(other.archivedBy, archivedBy) &&
            const DeepCollectionEquality().equals(other.metadata, metadata));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      const DeepCollectionEquality().hash(participants),
      lastMessage,
      lastTimestamp,
      chatType,
      groupName,
      groupAvatarURL,
      const DeepCollectionEquality().hash(mutedBy),
      const DeepCollectionEquality().hash(archivedBy),
      const DeepCollectionEquality().hash(metadata));

  @override
  String toString() {
    return 'Chat(id: $id, participants: $participants, lastMessage: $lastMessage, lastTimestamp: $lastTimestamp, chatType: $chatType, groupName: $groupName, groupAvatarURL: $groupAvatarURL, mutedBy: $mutedBy, archivedBy: $archivedBy, metadata: $metadata)';
  }
}

/// @nodoc
abstract mixin class $ChatCopyWith<$Res> {
  factory $ChatCopyWith(Chat value, $Res Function(Chat) _then) =
      _$ChatCopyWithImpl;
  @useResult
  $Res call(
      {String? id,
      List<String> participants,
      String? lastMessage,
      @TimestampConverter() DateTime lastTimestamp,
      String? chatType,
      String? groupName,
      String? groupAvatarURL,
      List<String> mutedBy,
      List<String> archivedBy,
      Map<String, dynamic>? metadata});
}

/// @nodoc
class _$ChatCopyWithImpl<$Res> implements $ChatCopyWith<$Res> {
  _$ChatCopyWithImpl(this._self, this._then);

  final Chat _self;
  final $Res Function(Chat) _then;

  /// Create a copy of Chat
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? participants = null,
    Object? lastMessage = freezed,
    Object? lastTimestamp = null,
    Object? chatType = freezed,
    Object? groupName = freezed,
    Object? groupAvatarURL = freezed,
    Object? mutedBy = null,
    Object? archivedBy = null,
    Object? metadata = freezed,
  }) {
    return _then(_self.copyWith(
      id: freezed == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      participants: null == participants
          ? _self.participants
          : participants // ignore: cast_nullable_to_non_nullable
              as List<String>,
      lastMessage: freezed == lastMessage
          ? _self.lastMessage
          : lastMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      lastTimestamp: null == lastTimestamp
          ? _self.lastTimestamp
          : lastTimestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      chatType: freezed == chatType
          ? _self.chatType
          : chatType // ignore: cast_nullable_to_non_nullable
              as String?,
      groupName: freezed == groupName
          ? _self.groupName
          : groupName // ignore: cast_nullable_to_non_nullable
              as String?,
      groupAvatarURL: freezed == groupAvatarURL
          ? _self.groupAvatarURL
          : groupAvatarURL // ignore: cast_nullable_to_non_nullable
              as String?,
      mutedBy: null == mutedBy
          ? _self.mutedBy
          : mutedBy // ignore: cast_nullable_to_non_nullable
              as List<String>,
      archivedBy: null == archivedBy
          ? _self.archivedBy
          : archivedBy // ignore: cast_nullable_to_non_nullable
              as List<String>,
      metadata: freezed == metadata
          ? _self.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// Adds pattern-matching-related methods to [Chat].
extension ChatPatterns on Chat {
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
    TResult Function(_Chat value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Chat() when $default != null:
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
    TResult Function(_Chat value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Chat():
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
    TResult? Function(_Chat value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Chat() when $default != null:
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
            List<String> participants,
            String? lastMessage,
            @TimestampConverter() DateTime lastTimestamp,
            String? chatType,
            String? groupName,
            String? groupAvatarURL,
            List<String> mutedBy,
            List<String> archivedBy,
            Map<String, dynamic>? metadata)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Chat() when $default != null:
        return $default(
            _that.id,
            _that.participants,
            _that.lastMessage,
            _that.lastTimestamp,
            _that.chatType,
            _that.groupName,
            _that.groupAvatarURL,
            _that.mutedBy,
            _that.archivedBy,
            _that.metadata);
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
            List<String> participants,
            String? lastMessage,
            @TimestampConverter() DateTime lastTimestamp,
            String? chatType,
            String? groupName,
            String? groupAvatarURL,
            List<String> mutedBy,
            List<String> archivedBy,
            Map<String, dynamic>? metadata)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Chat():
        return $default(
            _that.id,
            _that.participants,
            _that.lastMessage,
            _that.lastTimestamp,
            _that.chatType,
            _that.groupName,
            _that.groupAvatarURL,
            _that.mutedBy,
            _that.archivedBy,
            _that.metadata);
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
            List<String> participants,
            String? lastMessage,
            @TimestampConverter() DateTime lastTimestamp,
            String? chatType,
            String? groupName,
            String? groupAvatarURL,
            List<String> mutedBy,
            List<String> archivedBy,
            Map<String, dynamic>? metadata)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Chat() when $default != null:
        return $default(
            _that.id,
            _that.participants,
            _that.lastMessage,
            _that.lastTimestamp,
            _that.chatType,
            _that.groupName,
            _that.groupAvatarURL,
            _that.mutedBy,
            _that.archivedBy,
            _that.metadata);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Chat implements Chat {
  const _Chat(
      {this.id,
      required final List<String> participants,
      this.lastMessage,
      @TimestampConverter() required this.lastTimestamp,
      this.chatType,
      this.groupName,
      this.groupAvatarURL,
      final List<String> mutedBy = const [],
      final List<String> archivedBy = const [],
      final Map<String, dynamic>? metadata})
      : _participants = participants,
        _mutedBy = mutedBy,
        _archivedBy = archivedBy,
        _metadata = metadata;
  factory _Chat.fromJson(Map<String, dynamic> json) => _$ChatFromJson(json);

  @override
  final String? id;
  final List<String> _participants;
  @override
  List<String> get participants {
    if (_participants is EqualUnmodifiableListView) return _participants;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_participants);
  }

  @override
  final String? lastMessage;
  @override
  @TimestampConverter()
  final DateTime lastTimestamp;
  @override
  final String? chatType;
// 'direct' or 'group'
  @override
  final String? groupName;
  @override
  final String? groupAvatarURL;
  final List<String> _mutedBy;
  @override
  @JsonKey()
  List<String> get mutedBy {
    if (_mutedBy is EqualUnmodifiableListView) return _mutedBy;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_mutedBy);
  }

  final List<String> _archivedBy;
  @override
  @JsonKey()
  List<String> get archivedBy {
    if (_archivedBy is EqualUnmodifiableListView) return _archivedBy;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_archivedBy);
  }

  final Map<String, dynamic>? _metadata;
  @override
  Map<String, dynamic>? get metadata {
    final value = _metadata;
    if (value == null) return null;
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  /// Create a copy of Chat
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ChatCopyWith<_Chat> get copyWith =>
      __$ChatCopyWithImpl<_Chat>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ChatToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Chat &&
            (identical(other.id, id) || other.id == id) &&
            const DeepCollectionEquality()
                .equals(other._participants, _participants) &&
            (identical(other.lastMessage, lastMessage) ||
                other.lastMessage == lastMessage) &&
            (identical(other.lastTimestamp, lastTimestamp) ||
                other.lastTimestamp == lastTimestamp) &&
            (identical(other.chatType, chatType) ||
                other.chatType == chatType) &&
            (identical(other.groupName, groupName) ||
                other.groupName == groupName) &&
            (identical(other.groupAvatarURL, groupAvatarURL) ||
                other.groupAvatarURL == groupAvatarURL) &&
            const DeepCollectionEquality().equals(other._mutedBy, _mutedBy) &&
            const DeepCollectionEquality()
                .equals(other._archivedBy, _archivedBy) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      const DeepCollectionEquality().hash(_participants),
      lastMessage,
      lastTimestamp,
      chatType,
      groupName,
      groupAvatarURL,
      const DeepCollectionEquality().hash(_mutedBy),
      const DeepCollectionEquality().hash(_archivedBy),
      const DeepCollectionEquality().hash(_metadata));

  @override
  String toString() {
    return 'Chat(id: $id, participants: $participants, lastMessage: $lastMessage, lastTimestamp: $lastTimestamp, chatType: $chatType, groupName: $groupName, groupAvatarURL: $groupAvatarURL, mutedBy: $mutedBy, archivedBy: $archivedBy, metadata: $metadata)';
  }
}

/// @nodoc
abstract mixin class _$ChatCopyWith<$Res> implements $ChatCopyWith<$Res> {
  factory _$ChatCopyWith(_Chat value, $Res Function(_Chat) _then) =
      __$ChatCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String? id,
      List<String> participants,
      String? lastMessage,
      @TimestampConverter() DateTime lastTimestamp,
      String? chatType,
      String? groupName,
      String? groupAvatarURL,
      List<String> mutedBy,
      List<String> archivedBy,
      Map<String, dynamic>? metadata});
}

/// @nodoc
class __$ChatCopyWithImpl<$Res> implements _$ChatCopyWith<$Res> {
  __$ChatCopyWithImpl(this._self, this._then);

  final _Chat _self;
  final $Res Function(_Chat) _then;

  /// Create a copy of Chat
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = freezed,
    Object? participants = null,
    Object? lastMessage = freezed,
    Object? lastTimestamp = null,
    Object? chatType = freezed,
    Object? groupName = freezed,
    Object? groupAvatarURL = freezed,
    Object? mutedBy = null,
    Object? archivedBy = null,
    Object? metadata = freezed,
  }) {
    return _then(_Chat(
      id: freezed == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      participants: null == participants
          ? _self._participants
          : participants // ignore: cast_nullable_to_non_nullable
              as List<String>,
      lastMessage: freezed == lastMessage
          ? _self.lastMessage
          : lastMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      lastTimestamp: null == lastTimestamp
          ? _self.lastTimestamp
          : lastTimestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      chatType: freezed == chatType
          ? _self.chatType
          : chatType // ignore: cast_nullable_to_non_nullable
              as String?,
      groupName: freezed == groupName
          ? _self.groupName
          : groupName // ignore: cast_nullable_to_non_nullable
              as String?,
      groupAvatarURL: freezed == groupAvatarURL
          ? _self.groupAvatarURL
          : groupAvatarURL // ignore: cast_nullable_to_non_nullable
              as String?,
      mutedBy: null == mutedBy
          ? _self._mutedBy
          : mutedBy // ignore: cast_nullable_to_non_nullable
              as List<String>,
      archivedBy: null == archivedBy
          ? _self._archivedBy
          : archivedBy // ignore: cast_nullable_to_non_nullable
              as List<String>,
      metadata: freezed == metadata
          ? _self._metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

// dart format on
