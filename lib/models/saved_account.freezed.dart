// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'saved_account.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SavedAccount _$SavedAccountFromJson(Map<String, dynamic> json) {
  return _SavedAccount.fromJson(json);
}

/// @nodoc
mixin _$SavedAccount {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get username => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  String? get email => throw _privateConstructorUsedError;
  String? get avatarURL => throw _privateConstructorUsedError;
  DateTime get lastLoginDate => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $SavedAccountCopyWith<SavedAccount> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SavedAccountCopyWith<$Res> {
  factory $SavedAccountCopyWith(
          SavedAccount value, $Res Function(SavedAccount) then) =
      _$SavedAccountCopyWithImpl<$Res, SavedAccount>;
  @useResult
  $Res call(
      {String id,
      String userId,
      String username,
      String displayName,
      String? email,
      String? avatarURL,
      DateTime lastLoginDate});
}

/// @nodoc
class _$SavedAccountCopyWithImpl<$Res, $Val extends SavedAccount>
    implements $SavedAccountCopyWith<$Res> {
  _$SavedAccountCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? username = null,
    Object? displayName = null,
    Object? email = freezed,
    Object? avatarURL = freezed,
    Object? lastLoginDate = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      email: freezed == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String?,
      avatarURL: freezed == avatarURL
          ? _value.avatarURL
          : avatarURL // ignore: cast_nullable_to_non_nullable
              as String?,
      lastLoginDate: null == lastLoginDate
          ? _value.lastLoginDate
          : lastLoginDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SavedAccountImplCopyWith<$Res>
    implements $SavedAccountCopyWith<$Res> {
  factory _$$SavedAccountImplCopyWith(
          _$SavedAccountImpl value, $Res Function(_$SavedAccountImpl) then) =
      __$$SavedAccountImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String userId,
      String username,
      String displayName,
      String? email,
      String? avatarURL,
      DateTime lastLoginDate});
}

/// @nodoc
class __$$SavedAccountImplCopyWithImpl<$Res>
    extends _$SavedAccountCopyWithImpl<$Res, _$SavedAccountImpl>
    implements _$$SavedAccountImplCopyWith<$Res> {
  __$$SavedAccountImplCopyWithImpl(
      _$SavedAccountImpl _value, $Res Function(_$SavedAccountImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? username = null,
    Object? displayName = null,
    Object? email = freezed,
    Object? avatarURL = freezed,
    Object? lastLoginDate = null,
  }) {
    return _then(_$SavedAccountImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      email: freezed == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String?,
      avatarURL: freezed == avatarURL
          ? _value.avatarURL
          : avatarURL // ignore: cast_nullable_to_non_nullable
              as String?,
      lastLoginDate: null == lastLoginDate
          ? _value.lastLoginDate
          : lastLoginDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SavedAccountImpl with DiagnosticableTreeMixin implements _SavedAccount {
  const _$SavedAccountImpl(
      {required this.id,
      required this.userId,
      required this.username,
      required this.displayName,
      this.email,
      this.avatarURL,
      required this.lastLoginDate});

  factory _$SavedAccountImpl.fromJson(Map<String, dynamic> json) =>
      _$$SavedAccountImplFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
  final String username;
  @override
  final String displayName;
  @override
  final String? email;
  @override
  final String? avatarURL;
  @override
  final DateTime lastLoginDate;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'SavedAccount(id: $id, userId: $userId, username: $username, displayName: $displayName, email: $email, avatarURL: $avatarURL, lastLoginDate: $lastLoginDate)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'SavedAccount'))
      ..add(DiagnosticsProperty('id', id))
      ..add(DiagnosticsProperty('userId', userId))
      ..add(DiagnosticsProperty('username', username))
      ..add(DiagnosticsProperty('displayName', displayName))
      ..add(DiagnosticsProperty('email', email))
      ..add(DiagnosticsProperty('avatarURL', avatarURL))
      ..add(DiagnosticsProperty('lastLoginDate', lastLoginDate));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SavedAccountImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.avatarURL, avatarURL) ||
                other.avatarURL == avatarURL) &&
            (identical(other.lastLoginDate, lastLoginDate) ||
                other.lastLoginDate == lastLoginDate));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, userId, username,
      displayName, email, avatarURL, lastLoginDate);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SavedAccountImplCopyWith<_$SavedAccountImpl> get copyWith =>
      __$$SavedAccountImplCopyWithImpl<_$SavedAccountImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SavedAccountImplToJson(
      this,
    );
  }
}

abstract class _SavedAccount implements SavedAccount {
  const factory _SavedAccount(
      {required final String id,
      required final String userId,
      required final String username,
      required final String displayName,
      final String? email,
      final String? avatarURL,
      required final DateTime lastLoginDate}) = _$SavedAccountImpl;

  factory _SavedAccount.fromJson(Map<String, dynamic> json) =
      _$SavedAccountImpl.fromJson;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get username;
  @override
  String get displayName;
  @override
  String? get email;
  @override
  String? get avatarURL;
  @override
  DateTime get lastLoginDate;
  @override
  @JsonKey(ignore: true)
  _$$SavedAccountImplCopyWith<_$SavedAccountImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
