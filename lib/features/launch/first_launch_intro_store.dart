import 'package:shared_preferences/shared_preferences.dart';

abstract class FirstLaunchIntroStore {
  Future<bool> hasSeen();

  Future<void> markSeen();
}

class SharedPrefsFirstLaunchIntroStore implements FirstLaunchIntroStore {
  SharedPrefsFirstLaunchIntroStore({SharedPreferences? preferences})
      : _preferences = preferences;

  static const String storageKey = 'st_first_launch_intro_seen_v1';

  final SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async {
    final SharedPreferences? injected = _preferences;
    if (injected != null) {
      return injected;
    }
    return SharedPreferences.getInstance();
  }

  @override
  Future<bool> hasSeen() async {
    final SharedPreferences prefs = await _prefs();
    return prefs.getBool(storageKey) ?? false;
  }

  @override
  Future<void> markSeen() async {
    final SharedPreferences prefs = await _prefs();
    await prefs.setBool(storageKey, true);
  }
}
