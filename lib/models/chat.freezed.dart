// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Chat _$ChatFromJson(Map<String, dynamic> json) {
  return _Chat.fromJson(json);
}

/// @nodoc
mixin _$Chat {
  String? get id => throw _privateConstructorUsedError;
  List<String> get participants => throw _privateConstructorUsedError;
  String? get lastMessage => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get lastTimestamp => throw _privateConstructorUsedError;
  String? get chatType =>
      throw _privateConstructorUsedError; // 'direct' or 'group'
  String? get groupName => throw _privateConstructorUsedError;
  String? get groupAvatarURL => throw _privateConstructorUsedError;
  List<String> get mutedBy => throw _privateConstructorUsedError;
  List<String> get archivedBy => throw _privateConstructorUsedError;
  Map<String, dynamic>? get metadata => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ChatCopyWith<Chat> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatCopyWith<$Res> {
  factory $ChatCopyWith(Chat value, $Res Function(Chat) then) =
      _$ChatCopyWithImpl<$Res, Chat>;
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
class _$ChatCopyWithImpl<$Res, $Val extends Chat>
    implements $ChatCopyWith<$Res> {
  _$ChatCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

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
    return _then(_value.copyWith(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      participants: null == participants
          ? _value.participants
          : participants // ignore: cast_nullable_to_non_nullable
              as List<String>,
      lastMessage: freezed == lastMessage
          ? _value.lastMessage
          : lastMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      lastTimestamp: null == lastTimestamp
          ? _value.lastTimestamp
          : lastTimestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      chatType: freezed == chatType
          ? _value.chatType
          : chatType // ignore: cast_nullable_to_non_nullable
              as String?,
      groupName: freezed == groupName
          ? _value.groupName
          : groupName // ignore: cast_nullable_to_non_nullable
              as String?,
      groupAvatarURL: freezed == groupAvatarURL
          ? _value.groupAvatarURL
          : groupAvatarURL // ignore: cast_nullable_to_non_nullable
              as String?,
      mutedBy: null == mutedBy
          ? _value.mutedBy
          : mutedBy // ignore: cast_nullable_to_non_nullable
              as List<String>,
      archivedBy: null == archivedBy
          ? _value.archivedBy
          : archivedBy // ignore: cast_nullable_to_non_nullable
              as List<String>,
      metadata: freezed == metadata
          ? _value.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChatImplCopyWith<$Res> implements $ChatCopyWith<$Res> {
  factory _$$ChatImplCopyWith(
          _$ChatImpl value, $Res Function(_$ChatImpl) then) =
      __$$ChatImplCopyWithImpl<$Res>;
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
class __$$ChatImplCopyWithImpl<$Res>
    extends _$ChatCopyWithImpl<$Res, _$ChatImpl>
    implements _$$ChatImplCopyWith<$Res> {
  __$$ChatImplCopyWithImpl(_$ChatImpl _value, $Res Function(_$ChatImpl) _then)
      : super(_value, _then);

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
    return _then(_$ChatImpl(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      participants: null == participants
          ? _value._participants
          : participants // ignore: cast_nullable_to_non_nullable
              as List<String>,
      lastMessage: freezed == lastMessage
          ? _value.lastMessage
          : lastMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      lastTimestamp: null == lastTimestamp
          ? _value.lastTimestamp
          : lastTimestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      chatType: freezed == chatType
          ? _value.chatType
          : chatType // ignore: cast_nullable_to_non_nullable
              as String?,
      groupName: freezed == groupName
          ? _value.groupName
          : groupName // ignore: cast_nullable_to_non_nullable
              as String?,
      groupAvatarURL: freezed == groupAvatarURL
          ? _value.groupAvatarURL
          : groupAvatarURL // ignore: cast_nullable_to_non_nullable
              as String?,
      mutedBy: null == mutedBy
          ? _value._mutedBy
          : mutedBy // ignore: cast_nullable_to_non_nullable
              as List<String>,
      archivedBy: null == archivedBy
          ? _value._archivedBy
          : archivedBy // ignore: cast_nullable_to_non_nullable
              as List<String>,
      metadata: freezed == metadata
          ? _value._metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChatImpl implements _Chat {
  const _$ChatImpl(
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

  factory _$ChatImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChatImplFromJson(json);

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

  @override
  String toString() {
    return 'Chat(id: $id, participants: $participants, lastMessage: $lastMessage, lastTimestamp: $lastTimestamp, chatType: $chatType, groupName: $groupName, groupAvatarURL: $groupAvatarURL, mutedBy: $mutedBy, archivedBy: $archivedBy, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatImpl &&
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

  @JsonKey(ignore: true)
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

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatImplCopyWith<_$ChatImpl> get copyWith =>
      __$$ChatImplCopyWithImpl<_$ChatImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChatImplToJson(
      this,
    );
  }
}

abstract class _Chat implements Chat {
  const factory _Chat(
      {final String? id,
      required final List<String> participants,
      final String? lastMessage,
      @TimestampConverter() required final DateTime lastTimestamp,
      final String? chatType,
      final String? groupName,
      final String? groupAvatarURL,
      final List<String> mutedBy,
      final List<String> archivedBy,
      final Map<String, dynamic>? metadata}) = _$ChatImpl;

  factory _Chat.fromJson(Map<String, dynamic> json) = _$ChatImpl.fromJson;

  @override
  String? get id;
  @override
  List<String> get participants;
  @override
  String? get lastMessage;
  @override
  @TimestampConverter()
  DateTime get lastTimestamp;
  @override
  String? get chatType;
  @override // 'direct' or 'group'
  String? get groupName;
  @override
  String? get groupAvatarURL;
  @override
  List<String> get mutedBy;
  @override
  List<String> get archivedBy;
  @override
  Map<String, dynamic>? get metadata;
  @override
  @JsonKey(ignore: true)
  _$$ChatImplCopyWith<_$ChatImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
