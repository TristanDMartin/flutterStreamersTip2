import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/widgets/profile/editable_profile_field.dart';
import 'package:streamers_tip/widgets/profile/profile_field_update_helper.dart';

void main() {
  group('ProfileFieldUpdateHelper', () {
    test('display name update syncs username like edit profile', () {
      final ProfileFieldUpdateResult result =
          ProfileFieldUpdateHelper.applyLocalUpdate(
        user: <String, dynamic>{'displayName': '', 'username': ''},
        key: EditableProfileField.name.key,
        value: 'Cool Creator',
      );
      expect(result.isSuccess, isTrue);
      expect(result.updatedUser?['username'], 'coolcreator');
    });
  });
}
