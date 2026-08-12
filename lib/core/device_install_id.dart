import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Privacy-safe install id for signup abuse signals (matches web
/// `X-Device-Install-Id` / `st_device_install_id_v1`).
const String kDeviceInstallIdPrefsKey = 'st_device_install_id_v1';

Future<String> getOrCreateDeviceInstallId() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? existing = prefs.getString(kDeviceInstallIdPrefsKey);
  if (existing != null && existing.trim().length >= 8) {
    return existing.trim();
  }
  final String id = const Uuid().v4();
  await prefs.setString(kDeviceInstallIdPrefsKey, id);
  return id;
}
