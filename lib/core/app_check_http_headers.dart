import 'firebase_app_check_startup.dart';

/// Builds HTTP headers for authenticated backend calls, attaching App Check
/// when the current build has App Check enabled.
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
  return headers;
}
