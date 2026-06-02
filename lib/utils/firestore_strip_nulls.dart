/// Removes null entries from Firestore write maps (rules reject null fields).
Map<String, dynamic> stripNullFieldsDeep(Map<String, dynamic> source) {
  final Map<String, dynamic> result = <String, dynamic>{};
  source.forEach((String key, dynamic value) {
    if (value == null) {
      return;
    }
    if (value is Map<String, dynamic>) {
      final Map<String, dynamic> nested = stripNullFieldsDeep(value);
      if (nested.isNotEmpty) {
        result[key] = nested;
      }
      return;
    }
    if (value is Map) {
      final Map<String, dynamic> nested = stripNullFieldsDeep(
        Map<String, dynamic>.from(value),
      );
      if (nested.isNotEmpty) {
        result[key] = nested;
      }
      return;
    }
    result[key] = value;
  });
  return result;
}
