import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/services/profile_link_service.dart';
import 'package:streamers_tip/utils/sensitive_data_redactor.dart';

void main() {
  group('ProfileLinkService.publicProfileUrl', () {
    test('prefers username over uid', () {
      const String uid = 'abcdefghijklmnopqrstuvwxyz12';
      final String url = ProfileLinkService.publicProfileUrl(
        username: 'coolcreator',
        userId: uid,
      );
      expect(url, contains('/streamer/coolcreator'));
      expect(url, isNot(contains(uid)));
    });

    test('falls back to streamer path when only uid is known', () {
      const String uid = 'abcdefghijklmnopqrstuvwxyz12';
      final String url = ProfileLinkService.publicProfileUrl(userId: uid);
      expect(url, contains('/streamer/'));
      expect(url, contains(uid));
    });

    test('does not treat uid-shaped username as handle', () {
      const String uid = 'abcdefghijklmnopqrstuvwxyz12';
      final String url = ProfileLinkService.publicProfileUrl(username: uid);
      expect(
        SensitiveDataRedactor.looksLikeFirebaseUid(uid),
        isTrue,
      );
      expect(url, contains('/streamer/'));
    });
  });
}
