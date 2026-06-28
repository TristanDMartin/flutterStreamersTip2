class UserContentSettings {
  const UserContentSettings({
    this.autoPlay = true,
    this.soundEnabled = true,
    this.dataSaver = false,
    this.videoQuality = 'auto',
    this.downloadEnabled = true,
    this.contentVisibility = true,
    this.sensitiveContent = false,
    this.languagePreference = 'en',
  });

  static const UserContentSettings defaults = UserContentSettings();

  final bool autoPlay;
  final bool soundEnabled;
  final bool dataSaver;
  final String videoQuality;
  final bool downloadEnabled;
  final bool contentVisibility;
  final bool sensitiveContent;
  final String languagePreference;

  factory UserContentSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return UserContentSettings.defaults;
    }
    return UserContentSettings(
      autoPlay: data['autoPlay'] as bool? ?? true,
      soundEnabled: data['soundEnabled'] as bool? ?? true,
      dataSaver: data['dataSaver'] as bool? ?? false,
      videoQuality: data['videoQuality'] as String? ?? 'auto',
      downloadEnabled: data['downloadEnabled'] as bool? ?? true,
      contentVisibility: data['contentVisibility'] as bool? ?? true,
      sensitiveContent: data['sensitiveContent'] as bool? ?? false,
      languagePreference: data['languagePreference'] as String? ?? 'en',
    );
  }

  /// Returns 480, 720, 1080, or null when quality should stay automatic.
  String? preferredPlaybackResolutionLabel() {
    if (dataSaver) {
      return '480';
    }
    switch (videoQuality) {
      case 'high':
        return '1080';
      case 'medium':
        return '720';
      case 'low':
        return '480';
      default:
        return null;
    }
  }
}
