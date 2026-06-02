import 'package:freezed_annotation/freezed_annotation.dart';

part 'suggested_connection.freezed.dart';
part 'suggested_connection.g.dart';

@freezed
sealed class SuggestedConnection with _$SuggestedConnection {
  const factory SuggestedConnection({
    required String id,
    required String username,
    required String avatarName,
  }) = _SuggestedConnection;

  factory SuggestedConnection.fromJson(Map<String, dynamic> json) =>
      _$SuggestedConnectionFromJson(json);
}
