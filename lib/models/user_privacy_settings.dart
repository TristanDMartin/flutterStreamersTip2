enum ProfileVisibilityLevel {
  public,
  followers,
  private;

  static ProfileVisibilityLevel fromStored(String? raw) {
    switch ((raw ?? 'public').toLowerCase().trim()) {
      case 'followers':
        return ProfileVisibilityLevel.followers;
      case 'private':
        return ProfileVisibilityLevel.private;
      default:
        return ProfileVisibilityLevel.public;
    }
  }

  String get storageValue {
    switch (this) {
      case ProfileVisibilityLevel.public:
        return 'public';
      case ProfileVisibilityLevel.followers:
        return 'followers';
      case ProfileVisibilityLevel.private:
        return 'private';
    }
  }
}

enum AudienceRestriction {
  everyone,
  followers,
  nobody;

  static AudienceRestriction fromStored(String? raw) {
    switch ((raw ?? 'everyone').toLowerCase().trim()) {
      case 'followers':
        return AudienceRestriction.followers;
      case 'nobody':
        return AudienceRestriction.nobody;
      default:
        return AudienceRestriction.everyone;
    }
  }

  String get storageValue {
    switch (this) {
      case AudienceRestriction.everyone:
        return 'everyone';
      case AudienceRestriction.followers:
        return 'followers';
      case AudienceRestriction.nobody:
        return 'nobody';
    }
  }
}

class UserPrivacySettings {
  const UserPrivacySettings({
    this.profileVisibility = ProfileVisibilityLevel.public,
    this.videoPrivacy = ProfileVisibilityLevel.public,
    this.allowMentions = AudienceRestriction.everyone,
    this.allowTags = true,
    this.allowFollowers = true,
    this.allowMessagesFrom = AudienceRestriction.everyone,
    this.showOnlineStatus = true,
    this.readReceipts = true,
  });

  static const UserPrivacySettings defaults = UserPrivacySettings();

  final ProfileVisibilityLevel profileVisibility;
  final ProfileVisibilityLevel videoPrivacy;
  final AudienceRestriction allowMentions;
  final bool allowTags;
  final bool allowFollowers;
  final AudienceRestriction allowMessagesFrom;
  final bool showOnlineStatus;
  final bool readReceipts;

  factory UserPrivacySettings.fromMap(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return UserPrivacySettings.defaults;
    }
    return UserPrivacySettings(
      profileVisibility:
          ProfileVisibilityLevel.fromStored(data['profileVisibility'] as String?),
      videoPrivacy:
          ProfileVisibilityLevel.fromStored(data['videoPrivacy'] as String?),
      allowMentions:
          AudienceRestriction.fromStored(data['allowMentions'] as String?),
      allowTags: data['allowTags'] as bool? ?? true,
      allowFollowers: data['allowFollowers'] as bool? ?? true,
      allowMessagesFrom:
          AudienceRestriction.fromStored(data['allowMessagesFrom'] as String?),
      showOnlineStatus: data['showOnlineStatus'] as bool? ?? true,
      readReceipts: data['readReceipts'] as bool? ?? true,
    );
  }

  String videoPublishPrivacyLabel() {
    switch (videoPrivacy) {
      case ProfileVisibilityLevel.public:
        return 'Everyone';
      case ProfileVisibilityLevel.followers:
        return 'Followers';
      case ProfileVisibilityLevel.private:
        return 'Private';
    }
  }
}

enum PrivacyBlockCode {
  followDisabled,
  profilePrivate,
  profileFollowersOnly,
  messagesDisabled,
  messagesFollowersOnly,
  mentionsDisabled,
  mentionsFollowersOnly,
  tagsDisabled,
}

class PrivacySettingsBlockedException implements Exception {
  const PrivacySettingsBlockedException({
    required this.code,
    required this.message,
  });

  final PrivacyBlockCode code;
  final String message;

  @override
  String toString() => message;
}
