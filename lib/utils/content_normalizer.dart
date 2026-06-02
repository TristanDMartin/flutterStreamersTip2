class ContentNormalizer {
  /// Normalize text for content moderation
  static String normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }

  /// Extract tokens from normalized text
  static List<String> extractTokens(String normalizedText) {
    return normalizedText
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList();
  }
}
