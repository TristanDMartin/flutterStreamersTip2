import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/widgets/profile/profile_username_utils.dart';

void main() {
  group('ProfileUsernameUtils.resolveUsername', () {
    test('uses root username when present', () {
      final String actual = ProfileUsernameUtils.resolveUsername(
        <String, dynamic>{'username': 'Creator_One'},
      );
      expect(actual, 'creator_one');
    });

    test('falls back to tippy pending username when root is empty', () {
      final String actual = ProfileUsernameUtils.resolveUsername(
        <String, dynamic>{
          'username': '',
          'onboarding': <String, dynamic>{
            'tippyPendingUsername': 'PendingHandle',
          },
        },
      );
      expect(actual, 'pendinghandle');
    });

    test('formatAtHandle never returns bare @', () {
      expect(
        ProfileUsernameUtils.formatAtHandle(<String, dynamic>{'username': ''}),
        '',
      );
      expect(
        ProfileUsernameUtils.formatAtHandle(
          <String, dynamic>{'username': 'tristan'},
        ),
        '@tristan',
      );
    });

    test('resolveDisplayName uses tippy pending when root missing', () {
      final String actual = ProfileUsernameUtils.resolveDisplayName(
        <String, dynamic>{
          'displayName': '  ',
          'onboarding': <String, dynamic>{
            'tippyPendingDisplayName': 'Tristan M',
          },
        },
      );
      expect(actual, 'Tristan M');
    });
  });
}
