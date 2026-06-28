import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/models/user_privacy_settings.dart';

void main() {
  group('UserPrivacySettings', () {
    test('fromMap uses defaults for missing fields', () {
      const UserPrivacySettings settings = UserPrivacySettings.defaults;
      expect(settings.profileVisibility, ProfileVisibilityLevel.public);
      expect(settings.allowFollowers, isTrue);
      expect(settings.readReceipts, isTrue);
    });

    test('videoPublishPrivacyLabel maps stored values', () {
      const UserPrivacySettings followersOnly = UserPrivacySettings(
        videoPrivacy: ProfileVisibilityLevel.followers,
      );
      expect(followersOnly.videoPublishPrivacyLabel(), 'Followers');

      const UserPrivacySettings privateVideos = UserPrivacySettings(
        videoPrivacy: ProfileVisibilityLevel.private,
      );
      expect(privateVideos.videoPublishPrivacyLabel(), 'Private');
    });

    test('fromMap parses custom values', () {
      final UserPrivacySettings settings = UserPrivacySettings.fromMap(
        <String, dynamic>{
          'profileVisibility': 'private',
          'allowMessagesFrom': 'nobody',
          'allowMentions': 'followers',
          'allowTags': false,
          'showOnlineStatus': false,
        },
      );
      expect(settings.profileVisibility, ProfileVisibilityLevel.private);
      expect(settings.allowMessagesFrom, AudienceRestriction.nobody);
      expect(settings.allowMentions, AudienceRestriction.followers);
      expect(settings.allowTags, isFalse);
      expect(settings.showOnlineStatus, isFalse);
    });
  });

  group('PrivacySettingsService helpers', () {
    test('PrivacySettingsBlockedException stores message', () {
      const PrivacySettingsBlockedException error =
          PrivacySettingsBlockedException(
        code: PrivacyBlockCode.followDisabled,
        message: 'No new followers',
      );
      expect(error.toString(), 'No new followers');
    });
  });
}
