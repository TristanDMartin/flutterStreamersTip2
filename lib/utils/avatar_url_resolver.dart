String? resolveAvatarUrl(Map<String, dynamic>? data) {
  if (data == null) return null;
  const List<String> keys = <String>[
    'avatarURL',
    'avatarUrl',
    'avatar_url',
    'avatar',
    'photoURL',
    'photoUrl',
    'photo_url',
    'profilePhotoURL',
    'profilePhotoUrl',
    'profile_photo_url',
    'profileImageURL',
    'profileImageUrl',
    'profile_image_url',
    'profile_image',
    'profilePicture',
    'profile_picture',
    'picture',
    'pictureURL',
    'pictureUrl',
    'image',
    'imageURL',
    'imageUrl',
    'image_url',
    'userAvatarUrl',
    'user_avatar_url',
    'sharerAvatarUrl',
    'fromAvatarUrl',
  ];
  for (final String key in keys) {
    final Object? value = data[key];
    final String? normalized = _normalizeAvatarValue(value);
    if (normalized != null) return normalized;
  }
  const List<String> nestedKeys = <String>[
    'user',
    'author',
    'creator',
    'owner',
    'profile',
  ];
  for (final String nestedKey in nestedKeys) {
    final Object? nested = data[nestedKey];
    if (nested is! Map<String, dynamic>) continue;
    final String? nestedAvatar = resolveAvatarUrl(nested);
    if (nestedAvatar != null && nestedAvatar.isNotEmpty) return nestedAvatar;
  }
  return null;
}

String? resolveUserAvatar(Map<String, dynamic>? user) {
  return resolveAvatarUrl(user);
}

String? _normalizeAvatarValue(Object? value) {
  if (value is String) return _normalizeAvatarString(value);
  if (value is Map<String, dynamic>) {
    const List<String> mapKeys = <String>[
      'url',
      'src',
      'avatarURL',
      'avatarUrl',
      'photoURL',
      'photoUrl',
      'profileImageUrl',
      'profilePhotoUrl',
      'pictureUrl',
      'imageUrl',
    ];
    for (final String key in mapKeys) {
      final Object? nestedValue = value[key];
      if (nestedValue is! String) continue;
      final String? normalized = _normalizeAvatarString(nestedValue);
      if (normalized != null) return normalized;
    }
  }
  return null;
}

/// Normalizes a bare avatar URL from a single string field.
String? normalizeAvatarPhotoUrl(String? raw) {
  if (raw == null) {
    return null;
  }
  return _normalizeAvatarString(raw);
}

String? _normalizeAvatarString(String input) {
  final String trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  final String lowered = trimmed.toLowerCase();
  if (lowered == 'null' || lowered == 'undefined' || lowered == 'none') {
    return null;
  }
  if (trimmed.startsWith('//')) return 'https:$trimmed';
  if (trimmed.startsWith('www.')) return 'https://$trimmed';
  return trimmed;
}

/// True when the user profile already stores a custom avatar URL.
bool hasPersistedAvatarUrl(Map<String, dynamic>? data) {
  if (data == null) {
    return false;
  }
  const List<String> avatarKeys = <String>['avatarURL', 'avatarUrl'];
  for (final String key in avatarKeys) {
    final Object? value = data[key];
    if (value is String && normalizeAvatarPhotoUrl(value) != null) {
      return true;
    }
  }
  return false;
}

/// Avatar fields to merge from an OAuth provider on first profile creation.
Map<String, String> buildProviderAvatarMergeFields({
  required String? providerPhotoUrl,
  required Map<String, dynamic>? existingData,
}) {
  if (hasPersistedAvatarUrl(existingData)) {
    return const <String, String>{};
  }
  final String? normalized = normalizeAvatarPhotoUrl(providerPhotoUrl);
  if (normalized == null) {
    return const <String, String>{};
  }
  return <String, String>{
    'avatarURL': normalized,
    'avatarUrl': normalized,
    'photoURL': normalized,
  };
}
