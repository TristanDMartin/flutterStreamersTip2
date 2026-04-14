String? resolveAvatarUrl(Map<String, dynamic>? data) {
  if (data == null) return null;

  const keys = <String>[
    'avatarURL',
    'avatarUrl',
    'avatar_url',
    'photoURL',
    'photoUrl',
    'profileImageURL',
    'profileImageUrl',
    'imageURL',
    'imageUrl',
  ];

  for (final key in keys) {
    final value = data[key];
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty && trimmed.toLowerCase() != 'null') {
        return trimmed;
      }
    }
  }

  return null;
}
