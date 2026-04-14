String normalizeCategoryId(String value) {
  final trimmed = value.trim().toLowerCase();
  final normalizedWhitespace = trimmed.replaceAll(RegExp(r'[\s_]+'), '-');
  return normalizedWhitespace.replaceAll(RegExp(r'[^a-z0-9-]'), '');
}

Map<String, dynamic> buildCanonicalCategoryFields(String rawCategory) {
  final normalized = normalizeCategoryId(rawCategory);
  final categoryId = normalized.isEmpty ? 'all' : normalized;

  return {
    'category': categoryId,
    'categoryId': categoryId,
    'category_id': categoryId,
    'categories': [categoryId],
  };
}
