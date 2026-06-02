import 'dart:math' as math;

import '../../../utils/avatar_url_resolver.dart';

/// Firestore field name normalization for Discover views.
class DiscoverFieldMapper {
  const DiscoverFieldMapper._();

  static String getUserId(Map<String, dynamic> data) {
    return data['userId'] ?? data['creatorId'] ?? data['creator_id'] ?? '';
  }

  static String getDisplayName(Map<String, dynamic> data) {
    return data['displayName'] ?? data['username'] ?? 'Unknown';
  }

  static String getAvatarUrl(Map<String, dynamic> data) {
    return resolveAvatarUrl(data) ?? '';
  }

  static String getThumbnailUrl(Map<String, dynamic> data) {
    return data['thumbnailUrl'] ?? data['thumbnailURL'] ?? '';
  }

  static String getVideoUrl(Map<String, dynamic> data) {
    return data['videoUrl'] ?? data['videoURL'] ?? '';
  }

  static int safeInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static int safeCount(Map<String, dynamic> data, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = data[key];
      if (value is int) return math.max(0, value);
      if (value is num) return math.max(0, value.toInt());
      if (value is String) {
        final int? parsed = int.tryParse(value);
        if (parsed != null) return math.max(0, parsed);
      }
    }
    return 0;
  }

  static double safeDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static String safeString(dynamic value) {
    return value?.toString() ?? '';
  }
}
