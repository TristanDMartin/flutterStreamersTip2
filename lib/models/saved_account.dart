import 'package:freezed_annotation/freezed_annotation.dart';

part 'saved_account.freezed.dart';
part 'saved_account.g.dart';

@freezed
sealed class SavedAccount with _$SavedAccount {
  const factory SavedAccount({
    required String id,
    required String userId,
    required String username,
    required String displayName,
    String? email,
    String? avatarURL,
    required DateTime lastLoginDate,
  }) = _SavedAccount;

  factory SavedAccount.fromJson(Map<String, dynamic> json) =>
      _$SavedAccountFromJson(json);
}
