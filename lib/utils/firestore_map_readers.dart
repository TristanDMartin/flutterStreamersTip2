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
  int maxCount = fallback;
  bool found = false;
  for (final String key in keys) {
    final Object? value = map[key];
    int? parsed;
    if (value is num) {
      parsed = value.toInt();
    } else if (value is String) {
      parsed = int.tryParse(value);
    }
    if (parsed == null) {
      continue;
    }
    final int clamped = parsed.clamp(0, 1 << 31).toInt();
    if (!found || clamped > maxCount) {
      maxCount = clamped;
      found = true;
    }
  }
  return found ? maxCount : fallback;
}

int readVideoLikeCountFromFirestore(Map<String, dynamic> data) {
  return intFieldFromMapKeys(
    data,
    const <String>['likes', 'likeCount', 'likesCount'],
  );
}

int readVideoCommentCountFromFirestore(Map<String, dynamic> data) {
  return intFieldFromMapKeys(
    data,
    const <String>['comments', 'commentCount', 'commentsCount'],
  );
}

int readVideoBookmarkCountFromFirestore(Map<String, dynamic> data) {
  return intFieldFromMapKeys(
    data,
    const <String>[
      'bookmarkCount',
      'bookmarks',
      'favorites',
      'favoriteCount',
      'bookmarksCount',
      'savesCount',
    ],
  );
}

int readVideoViewCountFromFirestore(Map<String, dynamic> data) {
  return intFieldFromMapKeys(
    data,
    const <String>['views', 'viewCount', 'viewsCount'],
  );
}
