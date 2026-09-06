import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';

import '../core/app_check_http_headers.dart';
import '../core/firebase_app_check_startup.dart';
import '../debug/agent_debug_log.dart';
import '../utils/video_ready_contract.dart';
import 'publish_transaction_trace.dart';

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
    String? title,
    String? description,
    List<String>? hashtags,
    String? privacy,
    bool? allowComments,
    String? category,
    String? thumbnailUrl,
    bool isDraft = false,
  }) async {
    final String endpoint = '$muxWorkerBaseUrl/mux/direct-upload';
    final PublishTransactionTrace? trace = PublishTransactionTrace.active;
    try {
      final Map<String, String> headers = await buildAuthenticatedHttpHeaders(
        idToken: idToken,
        extra: const <String, String>{
          'Content-Type': 'application/json',
        },
      );
      final bool hasAppCheck =
          headers.containsKey('X-Firebase-AppCheck');
      if (!isAppCheckEnabledForBuild()) {
        trace?.event('APP_CHECK_TOKEN_READY', detail: 'disabled for build');
      } else if (hasAppCheck) {
        trace?.ok('app-check-http', detail: 'header attached');
        trace?.event('APP_CHECK_TOKEN_READY');
      } else {
        trace?.fail(
          'app-check-http',
          detail: 'missing X-Firebase-AppCheck header',
        );
        trace?.event('APP_CHECK_FAILED', detail: 'no token for HTTP');
      }
      trace?.event('DIRECT_UPLOAD_REQUEST', detail: endpoint);
      debugPrint('MuxUploadService: POST $endpoint');
      debugPrint(
        'CANONICAL_CREATE_REQUEST endpoint=$endpoint '
        'userId=$userId videoIdHint=${videoId ?? '-'}',
      );
      // #region agent log
      agentDebugLog(
        hypothesisId: 'D',
        location: 'mux_upload_service.dart:createDirectUpload',
        message: 'direct_upload_request',
        data: <String, Object?>{
          'hasAppCheckHeader': hasAppCheck,
          'hasUserId': userId.isNotEmpty,
          'hasVideoIdHint': videoId != null && videoId.trim().isNotEmpty,
        },
      );
      // #endregion
      final Stopwatch httpSw = Stopwatch()..start();
      final Response<Map<String, dynamic>> res =
          await _dio.post<Map<String, dynamic>>(
        endpoint,
        options: Options(
          headers: headers,
          // Canonical create must stay interactive — not Mux READY.
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
        data: <String, dynamic>{
          if (videoId != null && videoId.trim().isNotEmpty)
            'videoId': videoId.trim(),
          'userId': userId,
          'isDraft': isDraft,
          if (caption != null) 'caption': caption.trim(),
          if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
          if (hashtags != null) 'hashtags': hashtags,
          if (privacy != null && privacy.trim().isNotEmpty)
            'privacy': privacy.trim(),
          if (privacy != null && privacy.trim().isNotEmpty)
            'visibility': privacy.trim(),
          if (allowComments != null) 'allowComments': allowComments,
          if (category != null && category.trim().isNotEmpty)
            'category': category.trim(),
          if (thumbnailUrl != null && thumbnailUrl.trim().isNotEmpty)
            'thumbnailUrl': thumbnailUrl.trim(),
        },
      );
      httpSw.stop();
      trace?.event(
        'CANONICAL_HTTP_RESPONSE',
        detail:
            'statusCode=${res.statusCode} elapsedMs=${httpSw.elapsedMilliseconds}',
      );
      trace?.event(
        'DIRECT_UPLOAD_RESPONSE',
        detail: 'statusCode=${res.statusCode}',
      );
      // #region agent log
      agentDebugLog(
        hypothesisId: 'D',
        location: 'mux_upload_service.dart:createDirectUpload',
        message: 'direct_upload_response',
        data: <String, Object?>{
          'statusCode': res.statusCode,
          'hasUploadUrl': (res.data?['uploadUrl'] as String?)?.isNotEmpty == true,
          'hasVideoId': (res.data?['videoId'] as String?)?.isNotEmpty == true,
        },
      );
      // #endregion
      final Map<String, dynamic>? data = res.data;
      if (data == null || data.isEmpty) {
        trace?.fail(
          'direct-upload',
          statusCode: res.statusCode,
          detail: 'empty body',
        );
        throw const WorkerMuxUploadException(
          message: 'Worker returned an empty response.',
          endpoint: muxWorkerBaseUrl,
        );
      }
      final String? uploadUrl = data['uploadUrl'] as String?;
      final String? uploadId =
          (data['uploadId'] as String?) ?? (data['muxUploadId'] as String?);
      final String vid = data['videoId'] as String? ??
          data['canonicalVideoId'] as String? ??
          videoId ??
          '';
      final String? ownerId =
          data['ownerId'] as String? ?? data['userId'] as String?;
      final String status =
          (data['status'] as String?)?.trim().isNotEmpty == true
              ? (data['status'] as String).trim()
              : 'uploading';
      if (uploadUrl == null || uploadUrl.isEmpty) {
        final String message = _readWorkerErrorMessage(data) ??
            'Worker did not return an upload URL.';
        trace?.publishFailed(
          stageName: 'CANONICAL_HTTP_REQUEST',
          videoId: vid.isEmpty ? videoId : vid,
          httpStatus: res.statusCode,
          error: message,
        );
        throw WorkerMuxUploadException(
          message: message,
          statusCode: res.statusCode,
          endpoint: endpoint,
        );
      }
      final int? code = res.statusCode;
      final bool httpOk = code != null && code >= 200 && code < 300;
      if (!httpOk) {
        trace?.publishFailed(
          stageName: 'CANONICAL_HTTP_REQUEST',
          videoId: vid,
          httpStatus: code,
          error: 'unexpected status',
        );
        throw WorkerMuxUploadException(
          message: 'Unexpected status $code from upload service',
          statusCode: code,
          endpoint: endpoint,
        );
      }
      trace?.ok(
        'direct-upload',
        detail: 'statusCode=${res.statusCode} videoId=$vid',
      );
      debugPrint(
        'DIRECT_UPLOAD_CREATED videoId=$vid uploadId=${uploadId ?? '-'} '
        'statusCode=${res.statusCode} ownerId=${ownerId ?? '-'}',
      );
      return MuxDirectUploadResult(
        uploadUrl: uploadUrl,
        uploadId: uploadId ?? '',
        videoId: vid,
        ownerId: ownerId ?? userId,
        status: status,
        ok: true,
        httpStatusCode: res.statusCode,
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
    String? bodySnippet;
    if (body is Map) {
      final Map<String, dynamic> map = Map<String, dynamic>.from(body);
      final String? fromBody = _readWorkerErrorMessage(map);
      if (fromBody != null && fromBody.isNotEmpty) {
        message = fromBody;
      }
      bodySnippet = map.toString();
    } else if (body != null) {
      bodySnippet = body.toString();
      if (bodySnippet.length > 240) {
        bodySnippet = '${bodySnippet.substring(0, 240)}…';
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
    PublishTransactionTrace.active?.fail(
      'direct-upload',
      statusCode: statusCode,
      detail: bodySnippet ?? message,
    );
    PublishTransactionTrace.active?.event(
      'DIRECT_UPLOAD_RESPONSE',
      detail: 'statusCode=${statusCode ?? 'none'} body=${bodySnippet ?? '-'}',
    );
    // #region agent log
    agentDebugLog(
      hypothesisId: 'D',
      location: 'mux_upload_service.dart:_mapDioToWorkerException',
      message: 'direct_upload_http_error',
      data: <String, Object?>{
        'statusCode': statusCode,
        'message': message,
        'bodySnippet': bodySnippet,
      },
    );
    // #endregion
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
    final PublishTransactionTrace? trace = PublishTransactionTrace.active;
    trace?.event('UPLOAD_STARTED');
    debugPrint('MuxUploadService: PUT to Mux (${uploadUrl.length} chars)');
    final int fileLength = await videoFile.length();
    try {
      debugPrint('MUX_UPLOAD_STARTED sizeBytes=$fileLength');
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
          if (total > 0) {
            final double progress = sent / total;
            trace?.progress(progress);
            onProgress?.call(progress);
          }
        },
      );
      debugPrint('MUX_UPLOAD_COMPLETE sizeBytes=$fileLength');
      trace?.ok('put');
      trace?.event('UPLOAD_COMPLETED');
    } on DioException catch (e) {
      final int? code = e.response?.statusCode;
      final String body = e.response?.data?.toString() ?? e.message ?? '';
      trace?.fail(
        'put',
        statusCode: code,
        detail: body.isEmpty ? null : body,
      );
      trace?.event(
        'UPLOAD_FAILED',
        detail: 'statusCode=${code ?? 'none'}',
      );
      // #region agent log
      agentDebugLog(
        hypothesisId: 'E',
        location: 'mux_upload_service.dart:uploadToMux',
        message: 'mux_put_failed',
        data: <String, Object?>{
          'statusCode': code,
        },
      );
      // #endregion
      throw WorkerMuxUploadException(
        message: code != null
            ? 'Mux rejected the video file (HTTP $code).'
            : 'Network error while sending video to Mux.',
        statusCode: code,
      );
    }
  }

  /// Wait until Worker/webhook marks Mux playback ready (canonical contract).
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
      if (videoStatusIsFailed(data)) {
        sub.cancel();
        timer.cancel();
        completer.completeError(
          Exception(
            data['transcodingError'] as String? ??
                data['uploadError'] as String? ??
                'Transcoding failed',
          ),
        );
        return;
      }
      // Require playable Mux media + ready status. Do not treat status=ready
      // alone as done (legacy docs can be ready with null playback).
      if (!isCanonicalPlaybackReady(data)) {
        return;
      }
      sub.cancel();
      timer.cancel();
      final String? playbackId = data['muxPlaybackId'] as String?;
      final String hlsUrl = data['hlsUrl'] as String? ??
          data['hls_url'] as String? ??
          data['canonicalPlaybackUrl'] as String? ??
          (playbackId != null && playbackId.isNotEmpty
              ? 'https://stream.mux.com/$playbackId.m3u8'
              : '');
      final String thumbnailUrl = data['thumbnailUrl'] as String? ??
          data['thumbnailURL'] as String? ??
          (playbackId != null && playbackId.isNotEmpty
              ? 'https://image.mux.com/$playbackId/thumbnail.jpg?width=720&time=0'
              : '');
      debugPrint(
        'CANONICAL_READY videoId=$videoId '
        'feedReady=${isCanonicalFeedReady(data)} '
        'muxPlaybackId=$playbackId',
      );
      completer.complete(MuxReadyResult(
        hlsUrl: hlsUrl,
        thumbnailUrl: thumbnailUrl,
        muxPlaybackId: playbackId ?? '',
      ));
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
    this.ownerId,
    this.status,
    this.ok = true,
    this.httpStatusCode,
  });

  final String uploadUrl;
  final String uploadId;
  final String videoId;
  final String? ownerId;
  final String? status;
  final bool ok;
  final int? httpStatusCode;
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
