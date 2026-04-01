import 'package:freezed_annotation/freezed_annotation.dart';

part 'connection.freezed.dart';
part 'connection.g.dart';

@freezed
sealed class Connection with _$Connection {
  const factory Connection({
    required String id,
    required String displayName,
    required String username,
    required String avatarUrl,
    required bool isOnline,
    required DateTime lastSeen,
  }) = _Connection;

  factory Connection.fromJson(Map<String, dynamic> json) =>
      _$ConnectionFromJson(json);
}
