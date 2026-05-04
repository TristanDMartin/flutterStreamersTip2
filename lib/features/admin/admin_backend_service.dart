import 'package:cloud_functions/cloud_functions.dart';

/// Callable Cloud Functions (`us-central1`): server accepts JWT `admin`
/// claim or Firestore user-doc admin fields (same as security rules).
class AdminBackendService {
  AdminBackendService._();

  static final FirebaseFunctions _fn =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  static Future<Map<String, dynamic>> execute(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final HttpsCallable callable = _fn.httpsCallable('adminExecute');
    final HttpsCallableResult result = await callable.call(<String, dynamic>{
      'action': action,
      'payload': payload,
    });
    final Object? data = result.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> dashboardStats() async {
    final HttpsCallable callable = _fn.httpsCallable('adminDashboardStats');
    final HttpsCallableResult result = await callable.call();
    final Object? data = result.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }
}
