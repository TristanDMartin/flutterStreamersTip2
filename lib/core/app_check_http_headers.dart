import 'device_install_id.dart';
import 'firebase_app_check_startup.dart';

/// Builds HTTP headers for authenticated backend calls, attaching App Check
/// and a privacy-safe device install id when available.
Future<Map<String, String>> buildAuthenticatedHttpHeaders({
  required String idToken,
  Map<String, String>? extra,
}) async {
  final Map<String, String> headers = <String, String>{
    'Authorization': 'Bearer $idToken',
    if (extra != null) ...extra,
  };
  final String? appCheckToken = await fetchAppCheckHttpToken();
  if (appCheckToken != null && appCheckToken.isNotEmpty) {
    headers['X-Firebase-AppCheck'] = appCheckToken;
  }
  try {
    final String deviceId = await getOrCreateDeviceInstallId();
    if (deviceId.isNotEmpty) {
      headers['X-Device-Install-Id'] = deviceId;
    }
  } catch (_) {
    // Prefer request without device id over failing the call.
  }
  return headers;
}
