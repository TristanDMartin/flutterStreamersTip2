import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

class VideoDownloadService {
  static final VideoDownloadService _instance =
      VideoDownloadService._internal();
  factory VideoDownloadService() => _instance;
  VideoDownloadService._internal();

  final Dio _dio = Dio();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  /// Download video with progress callback
  Future<String?> downloadVideo(
    String videoId,
    String videoUrl, {
    Function(int received, int total)? onProgress,
  }) async {
    try {
      // Check if video allows downloads
      final videoDoc = await _firestore.collection('videos').doc(videoId).get();
      if (videoDoc.exists) {
        final data = videoDoc.data()!;
        final ownerUid = data['userId'] as String?;
        final allowSave = data['allowSave'] as bool? ?? true;
        final currentUserId = _auth.currentUser?.uid;

        if (currentUserId != ownerUid && !allowSave) {
          throw Exception('Video owner has disabled downloads');
        }
      }

      // Get download directory
      final downloadDir = await _getDownloadDirectory();
      if (downloadDir == null) {
        throw Exception('Could not access download directory');
      }

      // Generate filename
      final fileName = _generateFileName(videoId, videoUrl);
      final filePath = path.join(downloadDir.path, fileName);

      // Check if file already exists
      final existingFile = File(filePath);
      if (await existingFile.exists()) {
        if (kDebugMode) {
          debugPrint('✅ Video already downloaded: $filePath');
        }
        return filePath;
      }

      if (kDebugMode) {
        debugPrint('📥 Downloading video to: $filePath');
      }

      // Download with progress
      await _dio.download(
        videoUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (onProgress != null && total > 0) {
            onProgress(received, total);
          }
        },
      );

      if (kDebugMode) {
        debugPrint('✅ Video downloaded successfully: $filePath');
      }

      return filePath;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error downloading video: $e');
      }
      rethrow;
    }
  }

  /// Get download directory based on platform
  Future<Directory?> _getDownloadDirectory() async {
    try {
      if (Platform.isAndroid) {
        // Use app-scoped external storage so modern Android releases do not
        // rely on deprecated broad storage permissions.
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          final downloadsPath = path.join(externalDir.path, 'Downloads');
          final downloadsDir = Directory(downloadsPath);

          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }
          return downloadsDir;
        }
        // Fallback to app documents directory
        final appDir = await getApplicationDocumentsDirectory();
        final downloadsDir = Directory(path.join(appDir.path, 'Downloads'));
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        return downloadsDir;
      } else if (Platform.isIOS) {
        // iOS: Save to Documents directory
        final appDir = await getApplicationDocumentsDirectory();
        final downloadsDir = Directory(path.join(appDir.path, 'Downloads'));
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        return downloadsDir;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error getting download directory: $e');
      }
      return null;
    }
  }

  /// Generate filename for downloaded video
  String _generateFileName(String videoId, String videoUrl) {
    final extension = path.extension(videoUrl).split('?').first;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'video_${videoId}_$timestamp${extension.isNotEmpty ? extension : '.mp4'}';
  }

  /// Check if video is already downloaded
  Future<bool> isVideoDownloaded(String videoId) async {
    try {
      final downloadDir = await _getDownloadDirectory();
      if (downloadDir == null) return false;

      final files = downloadDir.listSync();
      for (final file in files) {
        if (file is File && file.path.contains(videoId)) {
          return true;
        }
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error checking if video is downloaded: $e');
      }
      return false;
    }
  }
}
