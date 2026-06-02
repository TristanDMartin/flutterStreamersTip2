import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';

/// Cloudflare Worker base URL for Mux upload + webhooks (no Cloud Functions).
const String muxWorkerBaseUrl =
    'https://streamerstip-mux-api.streamerstip.workers.dev';

/// Thrown when the Mux Cloudflare Worker rejects or fails a direct-upload request.
class WorkerMuxUploadException implements Exception {
  const WorkerMuxUploadException({
    required this.message,
    this.statusCode,
    this.endpoint,
  });

  final String message;
  final int? statusCode;
  final String? endpoint;

  @override
  String toString() {
    final String code = statusCode != null ? ' (HTTP $statusCode)' : '';
    return 'Mux upload service unavailable$code: $message';
  }
}

/// Handles Mux direct upload: Worker signed URL → PUT to Mux → Firestore ready.
class MuxUploadService {
  MuxUploadService._();
  static final MuxUploadService instance = MuxUploadService._();

  final Dio _dio = Dio(BaseOptions(
    sendTimeout: const Duration(minutes: 30),
    receiveTimeout: const Duration(minutes: 30),
  ));

  /// Signed Mux direct-upload URL from the Cloudflare Worker only.
  Future<MuxDirectUploadResult> createDirectUpload({
    String? videoId,
    required String userId,
    required String idToken,
    String? caption,
    List<String>? hashtags,
    String? privacy,
    bool? allowComments,
    String? category,
    bool isDraft = false,
  }) async {
    final String endpoint = '$muxWorkerBaseUrl/mux/direct-upload';
    try {
      debugPrint('MuxUploadService: POST $endpoint');
      final Response<Map<String, dynamic>> res =
          await _dio.post<Map<String, dynamic>>(
        endpoint,
        options: Options(
          headers: <String, String>{
            'Authorization': 'Bearer ${idToken.trim()}',
            'Content-Type': 'application/json',
          },
        ),
        data: <String, dynamic>{
          if (videoId != null && videoId.trim().isNotEmpty)
            'videoId': videoId.trim(),
          'userId': userId,
          'isDraft': isDraft,
          if (caption != null) 'caption': caption.trim(),
          if (hashtags != null) 'hashtags': hashtags,
          if (privacy != null && privacy.trim().isNotEmpty)
            'privacy': privacy.trim(),
          if (privacy != null && privacy.trim().isNotEmpty)
            'visibility': privacy.trim(),
          if (allowComments != null) 'allowComments': allowComments,
          if (category != null && category.trim().isNotEmpty)
            'category': category.trim(),
        },
      );
      final Map<String, dynamic>? data = res.data;
      if (data == null || data.isEmpty) {
        throw const WorkerMuxUploadException(
          message: 'Worker returned an empty response.',
          endpoint: muxWorkerBaseUrl,
        );
      }
      final String? uploadUrl = data['uploadUrl'] as String?;
      final String? uploadId = data['uploadId'] as String?;
      final String vid = data['videoId'] as String? ?? videoId ?? '';
      if (uploadUrl == null || uploadUrl.isEmpty) {
        throw WorkerMuxUploadException(
          message: _readWorkerErrorMessage(data) ??
              'Worker did not return an upload URL.',
          statusCode: res.statusCode,
          endpoint: endpoint,
        );
      }
      return MuxDirectUploadResult(
        uploadUrl: uploadUrl,
        uploadId: uploadId ?? '',
        videoId: vid,
      );
    } on WorkerMuxUploadException {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioToWorkerException(e, endpoint);
    }
  }

  WorkerMuxUploadException _mapDioToWorkerException(
    DioException error,
    String endpoint,
  ) {
    final int? statusCode = error.response?.statusCode;
    final Object? body = error.response?.data;
    String message = 'Could not reach the Mux upload service.';
    if (body is Map) {
      final String? fromBody = _readWorkerErrorMessage(
        Map<String, dynamic>.from(body),
      );
      if (fromBody != null && fromBody.isNotEmpty) {
        message = fromBody;
      }
    } else if (error.message != null && error.message!.isNotEmpty) {
      message = error.message!;
    }
    if (statusCode == 401 || statusCode == 403) {
      message =
          'Upload auth failed ($statusCode). Sign out and back in, then retry.';
    } else if (statusCode == 429) {
      message = 'Upload rate limit exceeded. Wait a minute and try again.';
    } else if (statusCode != null && statusCode >= 500) {
      message = 'Mux upload service error ($statusCode): $message. '
          'Ensure the Cloudflare Worker is deployed and Mux credentials are set.';
    } else if (statusCode == 404) {
      message =
          'Mux upload endpoint not found (404). Deploy the Cloudflare Worker '
          'or check muxWorkerBaseUrl.';
    }
    debugPrint(
      '❌ MuxUploadService: Worker direct-upload failed '
      '(${statusCode ?? 'no status'}): $message',
    );
    return WorkerMuxUploadException(
      message: message,
      statusCode: statusCode,
      endpoint: endpoint,
    );
  }

  String? _readWorkerErrorMessage(Map<String, dynamic> data) {
    final Object? error = data['error'];
    if (error is String && error.trim().isNotEmpty) {
      return error.trim();
    }
    final Object? message = data['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
    return null;
  }

  /// PUT video file to Mux signed URL.
  Future<void> uploadToMux({
    required File videoFile,
    required String uploadUrl,
    void Function(double)? onProgress,
  }) async {
    debugPrint('MuxUploadService: PUT to Mux (${uploadUrl.length} chars)');
    final int fileLength = await videoFile.length();
    try {
      await _dio.put(
        uploadUrl,
        data: videoFile.openRead(),
        options: Options(
          headers: <String, String>{
            'Content-Type': 'video/mp4',
            'Content-Length': fileLength.toString(),
          },
          contentType: 'video/mp4',
        ),
        onSendProgress: (int sent, int total) {
          if (total > 0 && onProgress != null) {
            onProgress(sent / total);
          }
        },
      );
    } on DioException catch (e) {
      final int? code = e.response?.statusCode;
      throw WorkerMuxUploadException(
        message: code != null
            ? 'Mux rejected the video file (HTTP $code).'
            : 'Network error while sending video to Mux.',
        statusCode: code,
      );
    }
  }

  /// Wait for Firestore video doc status `active` / `ready`.
  Future<MuxReadyResult> waitForReady({
    required String videoId,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final Completer<MuxReadyResult> completer = Completer<MuxReadyResult>();
    late StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> sub;
    final Timer timer = Timer(timeout, () {
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
        .listen((DocumentSnapshot<Map<String, dynamic>> snap) {
      if (completer.isCompleted) return;
      final Map<String, dynamic>? data = snap.data();
      if (data == null) return;
      final String? status = data['status'] as String?;
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
        final String? playbackId = data['muxPlaybackId'] as String?;
        final String? hlsUrl = data['hlsUrl'] as String? ??
            data['hls_url'] as String? ??
            (playbackId != null
                ? 'https://stream.mux.com/$playbackId.m3u8'
                : null);
        final String? thumbnailUrl = data['thumbnailUrl'] as String? ??
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
    }, onError: (Object e) {
      if (!completer.isCompleted) {
        timer.cancel();
        completer.completeError(e);
      }
    });
    return completer.future;
  }
}

class MuxDirectUploadResult {
  const MuxDirectUploadResult({
    required this.uploadUrl,
    required this.uploadId,
    required this.videoId,
  });

  final String uploadUrl;
  final String uploadId;
  final String videoId;
}

class MuxReadyResult {
  const MuxReadyResult({
    required this.hlsUrl,
    required this.thumbnailUrl,
    required this.muxPlaybackId,
  });

  final String hlsUrl;
  final String thumbnailUrl;
  final String muxPlaybackId;
}
