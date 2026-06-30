/// First non-empty trimmed [String] in [values], or null.
String? firstNonEmptyStringFromValues(List<Object?> values) {
  for (final Object? v in values) {
    if (v is String && v.trim().isNotEmpty) {
      return v.trim();
    }
  }
  return null;
}

/// Reads [key] from [map] when the value is a non-empty [String].
String? stringFieldFromMap(Map<String, dynamic>? map, String key) {
  if (map == null) {
    return null;
  }
  final Object? v = map[key];
  return v is String ? v : null;
}

int intFieldFromMapKeys(
  Map<String, dynamic> map,
  List<String> keys, {
  int fallback = 0,
}) {
  for (final String key in keys) {
    final Object? value = map[key];
    if (value is num) {
      return value.toInt().clamp(0, 1 << 31).toInt();
    }
    if (value is String) {
      final int? parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed.clamp(0, 1 << 31).toInt();
      }
    }
  }
  return fallback;
}

int readVideoLikeCountFromFirestore(Map<String, dynamic> data) {
  return intFieldFromMapKeys(
    data,
    const <String>['likeCount', 'likesCount', 'likes'],
  );
}

int readVideoCommentCountFromFirestore(Map<String, dynamic> data) {
  return intFieldFromMapKeys(
    data,
    const <String>['commentCount', 'commentsCount', 'comments'],
  );
}

int readVideoViewCountFromFirestore(Map<String, dynamic> data) {
  return intFieldFromMapKeys(
    data,
    const <String>['viewCount', 'viewsCount', 'views'],
  );
}
