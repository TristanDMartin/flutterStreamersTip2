import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/widgets/profile/profile_streamer_card_visibility.dart';

void main() {
  group('ProfileStreamerCardVisibility', () {
    test('shows for technqs and buzzz usernames', () {
      expect(
        ProfileStreamerCardVisibility.canShowStreamerCardButton(
          <String, dynamic>{'username': 'technqs'},
        ),
        isTrue,
      );
      expect(
        ProfileStreamerCardVisibility.canShowStreamerCardButton(
          <String, dynamic>{'username': 'BuZzZ'},
        ),
        isTrue,
      );
    });

    test('shows for isAdmin and role admin', () {
      expect(
        ProfileStreamerCardVisibility.canShowStreamerCardButton(
          <String, dynamic>{'username': 'other', 'isAdmin': true},
        ),
        isTrue,
      );
      expect(
        ProfileStreamerCardVisibility.canShowStreamerCardButton(
          <String, dynamic>{'username': 'other', 'role': 'admin'},
        ),
        isTrue,
      );
    });

    test('hides for regular users', () {
      expect(
        ProfileStreamerCardVisibility.canShowStreamerCardButton(
          <String, dynamic>{'username': 'regularcreator'},
        ),
        isFalse,
      );
    });
  });
}
