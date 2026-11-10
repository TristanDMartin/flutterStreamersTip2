import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/services/admin_service.dart';

void main() {
  group('AdminService.userMapIndicatesAdmin', () {
    test('username never grants admin, including debug builds', () {
      const Map<String, dynamic> userData = <String, dynamic>{
        'username': 'technqs',
      };
      expect(AdminService.userMapIndicatesAdmin(userData), isFalse);
    });

    test('firestore admin fields work without username bootstrap', () {
      const Map<String, dynamic> userData = <String, dynamic>{
        'username': 'regular_user',
        'role': 'admin',
      };
      expect(AdminService.userMapIndicatesAdmin(userData), isTrue);
    });
  });
}
