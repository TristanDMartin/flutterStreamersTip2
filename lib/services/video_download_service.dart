import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

class VideoDownloadService {
  static final VideoDownloadService _instance = VideoDownloadService._internal();
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
      // Check if user has permission to download
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        throw Exception('Storage permission denied');
      }

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

  /// Request storage permission
  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      // For Android 13+ (API 33+), we don't need storage permission for Downloads
      // But we'll still try to request it for older devices
      try {
        final status = await Permission.storage.status;
        if (status.isDenied) {
          final result = await Permission.storage.request();
          // For Android 13+, permission might be denied but Downloads still works
          // So we'll proceed anyway
          return result.isGranted || result.isPermanentlyDenied;
        }
        return status.isGranted;
      } catch (e) {
        // If permission check fails, proceed anyway (Android 13+ behavior)
        if (kDebugMode) {
          debugPrint('⚠️ Permission check failed, proceeding: $e');
        }
        return true;
      }
    } else if (Platform.isIOS) {
      // iOS doesn't require explicit permission for Documents directory
      return true;
    }
    return true;
  }

  /// Get download directory based on platform
  Future<Directory?> _getDownloadDirectory() async {
    try {
      if (Platform.isAndroid) {
        // Try to get external storage Downloads directory
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // Navigate to Downloads folder
          // Path structure: /storage/emulated/0/Android/data/... -> /storage/emulated/0/Download
          final basePath = externalDir.path.split('Android')[0];
          final downloadsPath = path.join(basePath, 'Download');
          final downloadsDir = Directory(downloadsPath);
          
          // Try to create directory (might fail on Android 13+ without permission, but Downloads folder usually exists)
          try {
            if (!await downloadsDir.exists()) {
              await downloadsDir.create(recursive: true);
            }
          } catch (e) {
            // If creation fails, try to use it anyway (might already exist)
            if (kDebugMode) {
              debugPrint('⚠️ Could not create Downloads directory, trying to use existing: $e');
            }
          }
          
          // Check if directory is accessible
          if (await downloadsDir.exists()) {
            return downloadsDir;
          }
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

