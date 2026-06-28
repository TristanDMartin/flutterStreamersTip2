import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight hint that the last session ended signed-in — used to show Home
/// while Firebase is still initializing on cold start.
abstract final class AuthSessionHintStorage {
  static const String _hadSessionKey = 'streamerstip_had_auth_session';

  static Future<bool> readHadSession() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hadSessionKey) ?? false;
  }

  static Future<void> markHasSession() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hadSessionKey, true);
  }

  static Future<void> clearSession() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hadSessionKey);
  }
}
