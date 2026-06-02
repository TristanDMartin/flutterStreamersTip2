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
