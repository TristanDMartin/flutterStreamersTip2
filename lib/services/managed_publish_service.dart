import 'dart:async';

import 'package:streamers_tip/utils/secure_log.dart';

import '../providers/publish_provider.dart';
import '../utils/upload_error_classifier.dart';
import '../debug/agent_debug_log.dart';
import 'publish_transaction_trace.dart';
import 'upload_status_manager.dart';
import 'video_upload_service.dart';

/// Owns byte-upload + Mux processing after Share has already obtained a
/// [CanonicalPublishAck]. Navigation must never wait on this service.
class ManagedPublishService {
  ManagedPublishService._internal();

  static final ManagedPublishService instance =
      ManagedPublishService._internal();

  Future<PublishExecutionResult>? _activeFuture;
  String? _activePublishRequestId;

  bool get isPublishInFlight =>
      _activeFuture != null && _activePublishRequestId != null;

  String? get activePublishRequestId => _activePublishRequestId;

  /// Starts (or rejoins) background upload after canonical create succeeded.
  Future<PublishExecutionResult> handOffPublish({
    required String publishRequestId,
    required String videoId,
    required String fileUri,
    String? thumbUri,
    required String title,
    required List<String> categories,
    required Map<String, dynamic> jobMetadata,
    required PublishProvider publishController,
    required PublishNowRequest request,
    CanonicalPublishAck? preCreatedAck,
  }) {
    final String normalizedRequestId = publishRequestId.trim().isNotEmpty
        ? publishRequestId.trim()
        : videoId;
    if (_activeFuture != null &&
        _activePublishRequestId == normalizedRequestId) {
      secureLog(
        'ManagedPublishService: rejoining in-flight publish '
        '$normalizedRequestId',
      );
      return _activeFuture!;
    }
    final Map<String, dynamic>? meta = request.additionalMetadata;
    final Object? hasBakedRaw =
        meta?['hasBakedEdits'] ?? meta?['has_baked_edits'];
    final bool? hasBakedEdits = hasBakedRaw is bool
        ? hasBakedRaw
        : (hasBakedRaw == null ? null : hasBakedRaw == true);
    final PublishTransactionTrace? existingTrace =
        PublishTransactionTrace.active;
    final PublishTransactionTrace trace = existingTrace ??
        PublishTransactionTrace.begin(
          publishRequestId: normalizedRequestId,
          draftId:
              meta?['draftId'] as String? ?? meta?['draft_id'] as String?,
          videoId: videoId,
          hasBakedEdits: hasBakedEdits,
          sourcePath: meta?['sourcePath'] as String? ??
              meta?['sourceFilePath'] as String?,
          renderedPath: meta?['renderedPath'] as String? ??
              meta?['renderedFilePath'] as String? ??
              fileUri,
        );
    // #region agent log
    agentDebugLog(
      hypothesisId: 'E',
      location: 'managed_publish_service.dart:handOffPublish',
      message: 'managed_publish_begin',
      data: <String, Object?>{
        'publishRequestId': normalizedRequestId,
        'videoId': videoId,
        'hasBakedEdits': hasBakedEdits,
        'hasPreCreatedAck': preCreatedAck != null ||
            request.preCreatedAck != null,
      },
    );
    // #endregion
    final UploadStatusManager uploadStatus = UploadStatusManager();
    final Completer<PublishExecutionResult> completer =
        Completer<PublishExecutionResult>();
    final CanonicalPublishAck? ack =
        preCreatedAck ?? request.preCreatedAck;
    _activePublishRequestId = normalizedRequestId;
    _activeFuture = completer.future;
    unawaited(() async {
      try {
        await uploadStatus.beginInScreenUpload(
          fileUri: fileUri,
          thumbUri: thumbUri,
          title: title,
          categories: categories,
          videoId: ack?.videoId ?? videoId,
          metadata: <String, dynamic>{
            ...jobMetadata,
            'publishRequestId': normalizedRequestId,
            'source': 'managed_publish',
          },
        );
        final PublishExecutionResult execution =
            await publishController.publishNow(
          PublishNowRequest(
            videoId: ack?.videoId ?? request.videoId,
            publishRequestId: normalizedRequestId,
            videoFile: request.videoFile,
            caption: request.caption,
            hashtags: request.hashtags,
            privacy: request.privacy,
            allowComments: request.allowComments,
            crossPostRequests: request.crossPostRequests,
            additionalMetadata: <String, dynamic>{
              ...?request.additionalMetadata,
              'publishRequestId': normalizedRequestId,
            },
            onProgress: (double progress) {
              unawaited(uploadStatus.reportUploadProgress(progress));
              request.onProgress?.call(progress);
            },
            preCreatedAck: ack,
            skipModeration: ack != null || request.skipModeration,
          ),
        );
        final bool success =
            execution.publishResult?.streamerstipSuccess == true;
        if (success) {
          final String uploadedVideoId =
              execution.uploadedVideoId ?? ack?.videoId ?? videoId;
          uploadStatus.enterProcessing(uploadedVideoId);
          trace.ok('hand-off', detail: 'videoId=$uploadedVideoId');
        } else {
          final String raw =
              execution.publishResult?.streamerstipResult.error ??
                  publishController.errorDetails['streamerstip'] ??
                  'Failed to publish video';
          final String stage =
              execution.publishResult?.streamerstipResult.failureStage ??
                  'POST_UPLOAD';
          trace.fail(stage.toLowerCase(), detail: raw);
          await uploadStatus.markFailed(
            UploadFailureClassification.classify(raw).userMessage,
            stage: stage,
          );
        }
        if (!completer.isCompleted) {
          completer.complete(execution);
        }
      } catch (e, st) {
        secureLog('ManagedPublishService: publish failed: $e\n$st');
        trace.fail('post-upload', error: e);
        final String friendly =
            UploadFailureClassification.classify(e.toString()).userMessage;
        await uploadStatus.markFailed(friendly, stage: 'POST_UPLOAD');
        if (!completer.isCompleted) {
          completer.completeError(e, st);
        }
      } finally {
        if (_activePublishRequestId == normalizedRequestId) {
          _activePublishRequestId = null;
          _activeFuture = null;
        }
      }
    }());
    return completer.future;
  }
}
