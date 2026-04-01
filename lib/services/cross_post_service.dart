import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

const String _workerBaseUrl =
    'https://streamerstip-mux-api.streamerstip.workers.dev';

enum CrossPostResultStatus { success, failed }

class CrossPostResult {
  final String platformName;
  final CrossPostResultStatus status;
  final String? errorMessage;

  const CrossPostResult({
    required this.platformName,
    required this.status,
    this.errorMessage,
  });

  bool get isSuccess => status == CrossPostResultStatus.success;
}

class CrossPostRequest {
  final String platformName;
  final String caption;
  final String? videoId;
  final DateTime? scheduleAt;

  const CrossPostRequest({
    required this.platformName,
    required this.caption,
    this.videoId,
    this.scheduleAt,
  });
}

/// Calls the Cloudflare Worker `/api/crosspost` endpoint for each platform.
/// Never throws — returns a result per platform.
class CrossPostService {
  CrossPostService._();
  static final CrossPostService instance = CrossPostService._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  /// Post to all requested platforms concurrently (eagerError: false).
  Future<List<CrossPostResult>> publishToAll({
    required List<CrossPostRequest> requests,
    String? idToken,
  }) async {
    final token = idToken ?? await _getIdToken();
    final futures = requests.map((r) => _postToPlatform(r, token));
    final results = await Future.wait(futures, eagerError: false);
    return results;
  }

  Future<CrossPostResult> _postToPlatform(
    CrossPostRequest request,
    String? idToken,
  ) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      // Same endpoint as the website — Worker accepts Firebase ID tokens
      // (Bearer) from the app and session/JWT from the web. Both callers
      // use the same payload schema.
      await _dio.post<Map<String, dynamic>>(
        '$_workerBaseUrl/api/crosspost/publish',
        options: Options(headers: {
          if (idToken != null) 'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
          // Signal to the Worker that this request originates from the
          // Flutter app so it can select the correct auth strategy if needed.
          'X-Client': 'flutter-mobile',
        }),
        data: {
          'platform': request.platformName.toLowerCase(),
          'caption': request.caption,
          if (request.videoId != null) 'videoId': request.videoId,
          if (userId != null) 'userId': userId,
          if (request.scheduleAt != null)
            'scheduleAt': request.scheduleAt!.toIso8601String(),
        },
      );
      return CrossPostResult(
        platformName: request.platformName,
        status: CrossPostResultStatus.success,
      );
    } catch (e) {
      final message = _extractError(e);
      return CrossPostResult(
        platformName: request.platformName,
        status: CrossPostResultStatus.failed,
        errorMessage: message,
      );
    }
  }

  String _extractError(Object e) {
    if (e is DioException) {
      final body = e.response?.data;
      if (body is Map && body['error'] != null) {
        return body['error'].toString();
      }
      return 'HTTP ${e.response?.statusCode ?? 'error'}';
    }
    return e.toString();
  }

  Future<String?> _getIdToken() async {
    try {
      return await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (_) {
      return null;
    }
  }
}
