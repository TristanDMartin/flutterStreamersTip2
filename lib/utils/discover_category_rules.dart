import 'package:flutter/foundation.dart';

import 'category_schema.dart';

bool isAllCategorySlug(String category) {
  return normalizeCategorySlug(category) == 'all';
}

/// Legacy slug extraction when [categoryId] is missing on old uploads.
Set<String> extractLegacyCategorySlugs(Map<String, dynamic> data) {
  final Set<String> slugs = <String>{};
  void addValue(Object? raw) {
    if (raw == null) {
      return;
    }
    if (raw is Iterable) {
      for (final Object? item in raw) {
        addValue(item);
      }
      return;
    }
    final String text = raw.toString().trim();
    if (text.isEmpty) {
      return;
    }
    slugs.add(normalizeCategorySlug(text));
  }

  addValue(data['categories']);
  if (data['metadata'] is Map) {
    final Map<dynamic, dynamic> meta =
        data['metadata'] as Map<dynamic, dynamic>;
    addValue(meta['categoryCanonical']);
    addValue(meta['categoryOriginal']);
  }
  return slugs;
}

bool matchesDiscoverCategory(
  Map<String, dynamic> data,
  String selectedCategory, {
  bool enableDiagnostics = false,
  String? videoId,
}) {
  if (isAllCategorySlug(selectedCategory)) {
    if (enableDiagnostics && kDebugMode) {
      logDiscoverCategoryDebug(
        videoId: videoId ?? (data['id'] as String?) ?? '',
        creator: discoverCreatorLabelFromData(data),
        categoryId: readCanonicalCategoryFromVideo(data).categoryId,
        categoryName: readCanonicalCategoryFromVideo(data).categoryName,
        selectedCategory: selectedCategory,
        matched: true,
      );
    }
    return true;
  }

  final String selectedSlug = normalizeCategorySlug(selectedCategory);
  final CanonicalCategory canonical = readCanonicalCategoryFromVideo(data);
  bool matched = false;
  if (canonical.isPopulated) {
    matched = canonical.categoryId == selectedSlug;
  } else {
    matched = extractLegacyCategorySlugs(data).contains(selectedSlug);
  }

  if (enableDiagnostics && kDebugMode) {
    logDiscoverCategoryDebug(
      videoId: videoId ?? (data['id'] as String?) ?? '',
      creator: discoverCreatorLabelFromData(data),
      categoryId: canonical.categoryId,
      categoryName: canonical.categoryName,
      selectedCategory: selectedCategory,
      matched: matched,
    );
  }
  return matched;
}

String discoverCreatorLabelFromData(Map<String, dynamic> data) {
  final String? username = data['creator_username'] as String? ??
      data['creatorUsername'] as String? ??
      data['username'] as String? ??
      data['creator'] as String?;
  if (username != null && username.trim().isNotEmpty) {
    return username.trim();
  }
  final String? displayName = data['creator_display_name'] as String? ??
      data['creatorDisplayName'] as String? ??
      data['displayName'] as String?;
  if (displayName != null && displayName.trim().isNotEmpty) {
    return displayName.trim();
  }
  final String? ownerId = data['userId'] as String? ??
      data['creatorId'] as String? ??
      data['creator_id'] as String?;
  if (ownerId != null && ownerId.trim().isNotEmpty) {
    return ownerId.trim();
  }
  return '';
}

void logDiscoverCategoryDebug({
  required String videoId,
  required String creator,
  required String categoryId,
  required String categoryName,
  required String selectedCategory,
  required bool matched,
}) {
  if (!kDebugMode) {
    return;
  }
  debugPrint(
    'DISCOVER_CATEGORY_DEBUG '
    'videoId=$videoId '
    'creator=$creator '
    'categoryId=$categoryId '
    'categoryName=$categoryName '
    'selectedCategory=$selectedCategory '
    'matched=$matched',
  );
}
