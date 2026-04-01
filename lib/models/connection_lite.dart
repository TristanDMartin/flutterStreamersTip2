import 'package:freezed_annotation/freezed_annotation.dart';

part 'connection_lite.freezed.dart';
part 'connection_lite.g.dart';

/// ConnectionLite - Lightweight user connection data for share sheet
///
/// Optimized for fast rendering in horizontal scrollable connections row
@freezed
sealed class ConnectionLite with _$ConnectionLite {
  const factory ConnectionLite({
    required String userId,
    required String handle,
    required String displayName,
    required String avatarUrl,
    @Default(false) bool isOnline,
    int? lastInteractedAt, // timestamp for ranking
    @Default(true) bool canDM, // gate by privacy settings
    @Default(0.0) double rankingScore, // server-calculated ranking
  }) = _ConnectionLite;

  factory ConnectionLite.fromJson(Map<String, dynamic> json) =>
      _$ConnectionLiteFromJson(json);
}
