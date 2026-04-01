import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';

/// Mux direct upload via Cloudflare Worker (no Firebase Cloud Functions).
const String _workerBaseUrl =
    'https://streamerstip-mux-api.streamerstip.workers.dev';

/// Handles Mux direct upload: get signed URL from Worker, PUT to Mux, listen for ready.
class MuxUploadService {
  MuxUploadService._();
  static final MuxUploadService instance = MuxUploadService._();

  final Dio _dio = Dio(BaseOptions(
    sendTimeout: const Duration(minutes: 30),
    receiveTimeout: const Duration(minutes: 30),
  ));

  /// Get signed Mux direct upload URL from Worker. Requires Firebase ID token.
  Future<MuxDirectUploadResult> createDirectUpload({
    required String videoId,
    required String userId,
    required String idToken,
    bool isDraft = false,
  }) async {
    final url = '$_workerBaseUrl/mux/direct-upload';
    debugPrint('MuxUploadService: POST $url');
    final res = await _dio.post<Map<String, dynamic>>(
      url,
      options: Options(
        headers: {
          'Authorization': 'Bearer ${idToken.trim()}',
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'videoId': videoId,
        'userId': userId,
        'isDraft': isDraft,
      },
    );
    final data = res.data;
    if (data == null || data.isEmpty) {
      throw Exception('Worker returned empty response');
    }
    final uploadUrl = data['uploadUrl'] as String?;
    final uploadId = data['uploadId'] as String?;
    final vid = data['videoId'] as String? ?? videoId;
    if (uploadUrl == null || uploadUrl.isEmpty) {
      throw Exception(data['error'] as String? ?? 'No upload URL from Worker');
    }
    return MuxDirectUploadResult(
      uploadUrl: uploadUrl,
      uploadId: uploadId ?? '',
      videoId: vid,
    );
  }

  /// PUT video file to Mux signed URL.
  Future<void> uploadToMux({
    required File videoFile,
    required String uploadUrl,
    void Function(double)? onProgress,
  }) async {
    debugPrint('MuxUploadService: PUT to Mux (${uploadUrl.length} chars)');
    final fileLength = await videoFile.length();
    await _dio.put(
      uploadUrl,
      data: videoFile.openRead(),
      options: Options(
        headers: {
          'Content-Type': 'video/mp4',
          'Content-Length': fileLength.toString(),
        },
        contentType: 'video/mp4',
      ),
      onSendProgress: (sent, total) {
        if (total > 0 && onProgress != null) {
          onProgress(sent / total);
        }
      },
    );
  }

  /// Wait for Firestore video doc status 'active'/'ready'. Uses realtime listener first;
  /// falls back to polling only if listener fails. Reduces Firestore reads.
  Future<MuxReadyResult> waitForReady({
    required String videoId,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final completer = Completer<MuxReadyResult>();
    late StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> sub;
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        sub.cancel();
        completer.completeError(
          Exception('Timeout waiting for video to be ready'),
        );
      }
    });
    sub = FirebaseFirestore.instance
        .collection('videos')
        .doc(videoId)
        .snapshots()
        .listen((snap) {
      if (completer.isCompleted) return;
      final data = snap.data();
      if (data == null) return;
      final status = data['status'] as String?;
      if (status == 'failed' || (data['transcodingError'] as String?) != null) {
        sub.cancel();
        timer.cancel();
        completer.completeError(
          Exception(
            data['transcodingError'] as String? ?? 'Transcoding failed',
          ),
        );
        return;
      }
      if (status == 'ready' || status == 'active') {
        sub.cancel();
        timer.cancel();
        final playbackId = data['muxPlaybackId'] as String?;
        final hlsUrl = data['hlsUrl'] as String? ??
            data['hls_url'] as String? ??
            (playbackId != null
                ? 'https://stream.mux.com/$playbackId.m3u8'
                : null);
        final thumbnailUrl = data['thumbnailUrl'] as String? ??
            data['thumbnailURL'] as String? ??
            (playbackId != null
                ? 'https://image.mux.com/$playbackId/thumbnail.jpg?width=720&time=0'
                : null);
        completer.complete(MuxReadyResult(
          hlsUrl: hlsUrl ?? '',
          thumbnailUrl: thumbnailUrl ?? '',
          muxPlaybackId: playbackId ?? '',
        ));
      }
    }, onError: (e) {
      if (!completer.isCompleted) {
        timer.cancel();
        completer.completeError(e);
      }
    });
    return completer.future;
  }
}

class MuxDirectUploadResult {
  final String uploadUrl;
  final String uploadId;
  final String videoId;

  const MuxDirectUploadResult({
    required this.uploadUrl,
    required this.uploadId,
    required this.videoId,
  });
}

class MuxReadyResult {
  final String hlsUrl;
  final String thumbnailUrl;
  final String muxPlaybackId;

  const MuxReadyResult({
    required this.hlsUrl,
    required this.thumbnailUrl,
    required this.muxPlaybackId,
  });
}
