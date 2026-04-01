import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

const String _workerBaseUrl =
    'https://streamerstip-mux-api.streamerstip.workers.dev';

/// Uploads avatars and chat media to Cloudflare R2 via Worker.
class R2MediaService {
  R2MediaService._();
  static final R2MediaService instance = R2MediaService._();

  final Dio _dio = Dio(BaseOptions(
    sendTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 30),
  ));

  /// Upload avatar image. Returns public URL or throws.
  Future<String> uploadAvatar(File imageFile) async {
    final url = await _uploadMedia(imageFile, 'avatar');
    return url;
  }

  /// Upload chat GIF. Returns public URL or throws.
  Future<String> uploadChatGif(File gifFile) async {
    final url = await _uploadMedia(gifFile, 'chat');
    return url;
  }

  Future<String> _uploadMedia(File file, String type) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    if (!await file.exists()) {
      throw Exception('File does not exist');
    }
    final idToken = await user.getIdToken(true);
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Failed to get auth token');
    }
    final uri = Uri.parse('$_workerBaseUrl/media/upload');
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      uri.toString(),
      data: formData,
      options: Options(
        headers: {
          'Authorization': 'Bearer ${idToken.trim()}',
          'X-Upload-Type': type,
        },
      ),
    );
    final data = response.data;
    if (data == null) {
      throw Exception('Empty response from media upload');
    }
    final url = data['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception(data['error'] as String? ?? 'No URL returned');
    }
    if (kDebugMode) {
      debugPrint('R2MediaService: Uploaded $type, URL: $url');
    }
    return url;
  }
}
