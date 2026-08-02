/// Guided post-auth creator profile draft for Tippy onboarding.
class TippyProfileDraft {
  TippyProfileDraft({
    this.avatarUrl,
    this.localAvatarPath,
    this.displayName = '',
    this.username = '',
    this.bio = '',
    this.platformIds = const <String>[],
    this.platformHandles = const <String, String>{},
    this.platformUrls = const <String, String>{},
    this.categoryIds = const <String>[],
    this.skippedAvatar = false,
    this.skippedBio = false,
  });

  final String? avatarUrl;
  final String? localAvatarPath;
  final String displayName;
  final String username;
  final String bio;
  final List<String> platformIds;
  final Map<String, String> platformHandles;
  final Map<String, String> platformUrls;
  final List<String> categoryIds;
  final bool skippedAvatar;
  final bool skippedBio;

  bool get hasEssentialIdentity =>
      displayName.trim().isNotEmpty && username.trim().isNotEmpty;

  TippyProfileDraft copyWith({
    String? avatarUrl,
    String? localAvatarPath,
    bool clearLocalAvatarPath = false,
    String? displayName,
    String? username,
    String? bio,
    List<String>? platformIds,
    Map<String, String>? platformHandles,
    Map<String, String>? platformUrls,
    List<String>? categoryIds,
    bool? skippedAvatar,
    bool? skippedBio,
  }) {
    return TippyProfileDraft(
      avatarUrl: avatarUrl ?? this.avatarUrl,
      localAvatarPath: clearLocalAvatarPath
          ? null
          : (localAvatarPath ?? this.localAvatarPath),
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      platformIds: platformIds ?? List<String>.from(this.platformIds),
      platformHandles:
          platformHandles ?? Map<String, String>.from(this.platformHandles),
      platformUrls: platformUrls ?? Map<String, String>.from(this.platformUrls),
      categoryIds: categoryIds ?? List<String>.from(this.categoryIds),
      skippedAvatar: skippedAvatar ?? this.skippedAvatar,
      skippedBio: skippedBio ?? this.skippedBio,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'avatarUrl': avatarUrl,
      'localAvatarPath': localAvatarPath,
      'displayName': displayName,
      'username': username,
      'bio': bio,
      'platformIds': platformIds,
      'platformHandles': platformHandles,
      'platformUrls': platformUrls,
      'categoryIds': categoryIds,
      'skippedAvatar': skippedAvatar,
      'skippedBio': skippedBio,
    };
  }

  factory TippyProfileDraft.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return TippyProfileDraft();
    }
    return TippyProfileDraft(
      avatarUrl: json['avatarUrl'] as String?,
      localAvatarPath: json['localAvatarPath'] as String?,
      displayName: (json['displayName'] as String?)?.trim() ?? '',
      username: (json['username'] as String?)?.trim() ?? '',
      bio: (json['bio'] as String?)?.trim() ?? '',
      platformIds: (json['platformIds'] as List?)
              ?.whereType<String>()
              .toList() ??
          <String>[],
      platformHandles: _stringMap(json['platformHandles']),
      platformUrls: _stringMap(json['platformUrls']),
      categoryIds: (json['categoryIds'] as List?)
              ?.whereType<String>()
              .toList() ??
          <String>[],
      skippedAvatar: json['skippedAvatar'] == true,
      skippedBio: json['skippedBio'] == true,
    );
  }

  static Map<String, String> _stringMap(Object? raw) {
    final Map<String, String> out = <String, String>{};
    if (raw is! Map) {
      return out;
    }
    raw.forEach((Object? key, Object? value) {
      if (key is String && value is String) {
        out[key] = value;
      }
    });
    return out;
  }
}

abstract final class TippyGuidedProfileOptions {
  static const List<({String id, String label})> platforms =
      <({String id, String label})>[
    (id: 'twitch', label: 'Twitch'),
    (id: 'youtube', label: 'YouTube'),
    (id: 'tiktok', label: 'TikTok'),
    (id: 'instagram', label: 'Instagram'),
    (id: 'kick', label: 'Kick'),
    (id: 'facebook', label: 'Facebook'),
    (id: 'x', label: 'X'),
    (id: 'discord', label: 'Discord'),
    (id: 'other', label: 'Other'),
  ];

  static const List<({String id, String label})> categories =
      <({String id, String label})>[
    (id: 'gaming', label: 'Gaming'),
    (id: 'streaming', label: 'Streaming'),
    (id: 'commentary', label: 'Commentary'),
    (id: 'education', label: 'Education'),
    (id: 'lifestyle', label: 'Lifestyle'),
    (id: 'music', label: 'Music'),
    (id: 'art', label: 'Art'),
    (id: 'technology', label: 'Technology'),
    (id: 'fitness', label: 'Fitness'),
    (id: 'beauty', label: 'Beauty'),
    (id: 'podcasts', label: 'Podcasts'),
    (id: 'comedy', label: 'Comedy'),
  ];

  static const int displayNameMaxLength = 40;
  static const int bioMaxLength = 160;
  static const int usernameMinLength = 3;
  static const int usernameMaxLength = 30;
}
