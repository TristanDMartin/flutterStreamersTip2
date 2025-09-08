/// Utility class for normalizing text content for content moderation
class ContentNormalizer {
  static const Map<String, String> _leetspeakMap = {
    '0': 'o',
    '1': 'l',
    '3': 'e',
    '4': 'a',
    '5': 's',
    '7': 't',
    '@': 'a',
    r'$': 's',
    '!': 'i',
    '|': 'l',
    '8': 'b',
    '9': 'g',
  };

  static const List<String> _zeroWidthChars = [
    '\u200B', // Zero Width Space
    '\u200C', // Zero Width Non-Joiner
    '\u200D', // Zero Width Joiner
    '\uFEFF', // Zero Width No-Break Space
  ];

  /// Normalizes text for content moderation analysis
  /// 
  /// Steps:
  /// 1. Convert to lowercase
  /// 2. Remove diacritics/accents
  /// 3. Collapse whitespace
  /// 4. Remove punctuation (except spaces)
  /// 5. Convert leetspeak
  /// 6. Remove zero-width characters
  /// 7. Trim and normalize
  static String normalize(String text) {
    if (text.isEmpty) return text;

    String normalized = text;

    // Step 1: Convert to lowercase
    normalized = normalized.toLowerCase();

    // Step 2: Remove diacritics/accents
    normalized = _removeDiacritics(normalized);

    // Step 3: Collapse whitespace
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');

    // Step 4: Remove punctuation (keep spaces)
    normalized = normalized.replaceAll(RegExp(r'[^\w\s]'), '');

    // Step 5: Convert leetspeak
    normalized = _convertLeetspeak(normalized);

    // Step 6: Remove zero-width characters
    for (String char in _zeroWidthChars) {
      normalized = normalized.replaceAll(char, '');
    }

    // Step 7: Final cleanup
    normalized = normalized.trim();

    return normalized;
  }

  /// Removes diacritics and accents from text
  static String _removeDiacritics(String text) {
    const diacritics = 'ÀÁÂÃÄÅàáâãäåĀāĂăĄąÇçĆćĈĉĊċČčĎďĐđÈÉÊËèéêëĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĦħÌÍÎÏìíîïĨĩĪīĬĭĮįİıĴĵĶķĸĹĺĻļĽľĿŀŁłÑñŃńŅņŇňŉŊŋÒÓÔÕÖØòóôõöøŌōŎŏŐőŔŕŖŗŘřŚśŜŝŞşŠšŢţŤťŦŧÙÚÛÜùúûüŨũŪūŬŭŮůŰűŲųŴŵŶŷŸŹźŻżŽž';
    const replacements = 'AAAAAAaaaaaaAaAaAaCcCcCcCcCcDdDdEEEEeeeeEeEeEeEeEeGgGgGgGgHhHhIIIIiiiiIiIiIiIiIiJjKkkLlLlLlLlLlNnNnNnNnnNnOOOOOOooooooOoOoOoRrRrRrSsSsSsSsTtTtTtUUUUuuuuUuUuUuUuUuUuWwYyYZzZzZz';

    String result = text;
    for (int i = 0; i < diacritics.length; i++) {
      result = result.replaceAll(diacritics[i], replacements[i]);
    }
    return result;
  }

  /// Converts leetspeak characters to their normal equivalents
  static String _convertLeetspeak(String text) {
    String result = text;
    _leetspeakMap.forEach((leetspeak, normal) {
      result = result.replaceAll(leetspeak, normal);
    });
    return result;
  }

  /// Extracts tokens from normalized text for context analysis
  static List<String> extractTokens(String normalizedText) {
    return normalizedText
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList();
  }

  /// Checks if two tokens are within a specified window distance
  static bool areTokensWithinWindow(
    List<String> tokens,
    String token1,
    String token2,
    int windowSize,
  ) {
    final index1 = tokens.indexOf(token1);
    final index2 = tokens.indexOf(token2);
    
    if (index1 == -1 || index2 == -1) return false;
    
    return (index1 - index2).abs() <= windowSize;
  }

  /// Finds all occurrences of a term in text with their positions
  static List<TextMatch> findMatches(String text, String term) {
    final normalizedText = normalize(text);
    final normalizedTerm = normalize(term);
    
    final matches = <TextMatch>[];
    int startIndex = 0;
    
    while (true) {
      final index = normalizedText.indexOf(normalizedTerm, startIndex);
      if (index == -1) break;
      
      matches.add(TextMatch(
        start: index,
        end: index + normalizedTerm.length,
        originalText: text.substring(
          _mapNormalizedToOriginal(text, index),
          _mapNormalizedToOriginal(text, index + normalizedTerm.length),
        ),
      ));
      
      startIndex = index + 1;
    }
    
    return matches;
  }

  /// Maps normalized text position back to original text position
  static int _mapNormalizedToOriginal(String originalText, int normalizedPosition) {
    // This is a simplified mapping - in practice, you'd want more sophisticated tracking
    return normalizedPosition.clamp(0, originalText.length);
  }
}

/// Represents a match found in text
class TextMatch {
  final int start;
  final int end;
  final String originalText;

  const TextMatch({
    required this.start,
    required this.end,
    required this.originalText,
  });
}
