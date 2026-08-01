/// Canonical video category fields for upload, finalize, and Discover.
const String kDefaultCategoryId = 'general';
const String kDefaultCategoryName = 'General';

/// Normalized slug (e.g. `Just Chatting` → `just-chatting`).
String normalizeCategoryId(String value) {
  final String trimmed = value.trim().toLowerCase();
  final String normalizedWhitespace =
      trimmed.replaceAll(RegExp(r'[\s_]+'), '-');
  return normalizedWhitespace.replaceAll(RegExp(r'[^a-z0-9-]'), '');
}

const Map<String, String> _categorySlugAliases = <String, String>{
  'game': 'gaming',
  'games': 'gaming',
  'gameplay': 'gaming',
  'shooter': 'fps',
  'chat': 'just-chatting',
  'chatting': 'just-chatting',
  // Website Discover Title Case / legacy labels → Flutter canonical slugs.
  'other': 'general',
  'uncategorized': 'general',
  'education': 'tutorials',
  'howto': 'tutorials',
  'how-to': 'tutorials',
  'lifestyle': 'irl',
  'travel': 'irl',
  'comedy': 'just-chatting',
};

/// Discover + legacy matching: maps synonyms to canonical upload slugs.
String normalizeCategorySlug(String value) {
  final String id = normalizeCategoryId(value);
  if (id.isEmpty) {
    return id;
  }
  return _categorySlugAliases[id] ?? id;
}

/// Canonical slug for a Firestore video doc (never empty).
String categoryIdFromVideoDocument(Map<String, dynamic> data) {
  final CanonicalCategory canonical = readCanonicalCategoryFromVideo(data);
  if (canonical.isPopulated) {
    return canonical.categoryId;
  }
  return kDefaultCategoryId;
}

/// Publish-time category: never empty; defaults to [kDefaultCategoryId].
String resolveCategoryIdForPublish(String? rawCategory) {
  final String normalized = normalizeCategoryId(rawCategory ?? '');
  if (normalized.isEmpty || normalized == 'all') {
    return kDefaultCategoryId;
  }
  return normalized;
}

/// Human-readable label for a canonical [categoryId].
String categoryDisplayNameForId(String categoryId) {
  final String id = normalizeCategoryId(categoryId);
  if (id.isEmpty) {
    return kDefaultCategoryName;
  }
  const Map<String, String> labels = <String, String>{
    'general': 'General',
    'gaming': 'Gaming',
    'fps': 'FPS',
    'apex': 'Apex',
    'art': 'Art',
    'music': 'Music',
    'tech': 'Tech',
    'sports': 'Sports',
    'food': 'Food',
    'just-chatting': 'Just Chatting',
    'tutorials': 'Tutorials',
    'fitness': 'Fitness',
    'podcasts': 'Podcasts',
    'fashion': 'Fashion',
    'roleplay': 'Roleplay',
    'irl': 'IRL',
  };
  if (labels.containsKey(id)) {
    return labels[id]!;
  }
  if (id.contains('-')) {
    return id
        .split('-')
        .map(
          (String part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }
  return id[0].toUpperCase() + id.substring(1);
}

class CanonicalCategory {
  const CanonicalCategory({
    required this.categoryId,
    required this.categoryName,
  });

  final String categoryId;
  final String categoryName;

  bool get isPopulated => categoryId.isNotEmpty;
}

/// Reads canonical fields from a Firestore video document (with legacy fallback).
CanonicalCategory readCanonicalCategoryFromVideo(Map<String, dynamic> data) {
  String? categoryId = _firstNonEmptyString(<String?>[
    data['categoryId'] as String?,
    data['category_id'] as String?,
  ]);
  String? categoryName = _firstNonEmptyString(<String?>[
    data['categoryName'] as String?,
    data['category_name'] as String?,
  ]);
  final String? legacyCategory = _firstNonEmptyString(<String?>[
    data['category'] as String?,
  ]);
  if (categoryId == null && legacyCategory != null) {
    categoryId = normalizeCategorySlug(legacyCategory);
    if (categoryName == null &&
        legacyCategory != categoryId &&
        legacyCategory.contains(RegExp(r'[A-Z ]'))) {
      categoryName = legacyCategory.trim();
    }
  }
  if (categoryId == null || categoryId.isEmpty) {
    return const CanonicalCategory(categoryId: '', categoryName: '');
  }
  final String canonicalId = normalizeCategorySlug(categoryId);
  final String name = categoryName?.trim().isNotEmpty == true
      ? categoryName!.trim()
      : categoryDisplayNameForId(canonicalId);
  return CanonicalCategory(
    categoryId: canonicalId,
    categoryName: name,
  );
}

String? _firstNonEmptyString(List<String?> values) {
  for (final String? value in values) {
    if (value != null && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

bool videoHasCanonicalCategoryFields(Map<String, dynamic> data) {
  final CanonicalCategory canonical = readCanonicalCategoryFromVideo(data);
  return canonical.isPopulated &&
      data['categoryName'] != null &&
      (data['categoryName'] as String).trim().isNotEmpty;
}

/// Firestore patch: always writes [categoryId] + [categoryName] (+ legacy mirrors).
Map<String, dynamic> buildCanonicalCategoryFields(String rawCategory) {
  final String categoryId = resolveCategoryIdForPublish(rawCategory);
  final String categoryName = categoryDisplayNameForId(categoryId);
  return <String, dynamic>{
    'categoryId': categoryId,
    'categoryName': categoryName,
    'category': categoryId,
    'category_id': categoryId,
    'categories': <String>[categoryId],
  };
}
