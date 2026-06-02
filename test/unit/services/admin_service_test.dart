import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/services/admin_service.dart';

void main() {
  group('AdminService.userMapIndicatesAdmin', () {
    test('username bootstrap only applies in debug mode', () {
      const Map<String, dynamic> userData = <String, dynamic>{
        'username': 'technqs',
      };
      final bool isAdmin = AdminService.userMapIndicatesAdmin(userData);
      if (kDebugMode) {
        expect(isAdmin, isTrue);
      } else {
        expect(isAdmin, isFalse);
      }
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
