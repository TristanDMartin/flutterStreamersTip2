import 'firebase_app_check_startup.dart';

/// Builds HTTP headers for authenticated backend calls, attaching App Check
/// when the current build has App Check enabled.
Future<Map<String, String>> buildAuthenticatedHttpHeaders({
  required String idToken,
  Map<String, String>? extra,
  String? appCheckToken,
}) async {
  final Map<String, String> headers = <String, String>{
    'Authorization': 'Bearer $idToken',
    if (extra != null) ...extra,
  };
  final String? token = appCheckToken?.trim().isNotEmpty == true
      ? appCheckToken!.trim()
      : await fetchAppCheckHttpToken();
  if (token != null && token.isNotEmpty) {
    headers['X-Firebase-AppCheck'] = token;
  }
  return headers;
}
