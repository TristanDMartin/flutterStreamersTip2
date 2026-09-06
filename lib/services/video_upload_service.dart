import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'video_moderation_service.dart';
import 'enhanced_error_handling_service.dart';
import 'video_processing_service.dart';
import 'tag_mention_service.dart';
import 'mux_upload_service.dart';
import 'cross_post_service.dart';
import '../features/gamification/daily_activity_service.dart';
import '../features/gamification/emit_gamification_event.dart';
import '../features/gamification/gamification_event_types.dart';
import '../core/firebase_app_check_startup.dart';
import '../utils/upload_error_classifier.dart';
import '../utils/video_caption_resolver.dart';
import '../debug/agent_debug_log.dart';
import 'publish_transaction_trace.dart';
import 'video_publish_finalize_service.dart';
import 'optimistic_video_service.dart';

class VideoUploadResult {
  final bool success;
  final String? videoUrl;
  final String? thumbnailUrl;
  final String? error;
  final Map<String, dynamic>? metadata;

  /// Named publish stage when [success] is false (never blame UPLOAD_PUT
  /// for post-PUT failures).
  final String? failureStage;

  const VideoUploadResult({
    required this.success,
    this.videoUrl,
    this.thumbnailUrl,
    this.error,
    this.metadata,
    this.failureStage,
  });
}

/// Proof that Worker accepted publish and `videos/{videoId}` is uploading.
class CanonicalPublishAck {
  const CanonicalPublishAck({
    required this.videoId,
    required this.authUid,
    required this.ownerId,
    required this.status,
    required this.uploadUrl,
    required this.muxUploadId,
    this.userId,
    this.creatorId,
    this.httpStatusCode,
    this.verifiedFromFirestore = false,
  });

  final String videoId;
  final String authUid;
  final String ownerId;
  final String status;
  final String uploadUrl;
  final String muxUploadId;
  final String? userId;
  final String? creatorId;
  final int? httpStatusCode;
  final bool verifiedFromFirestore;

  String get canonicalDocPath => 'videos/$videoId';
}

/// @deprecated Use [CanonicalPublishAck].
typedef CanonicalCreateProof = CanonicalPublishAck;

class CrossPublishResult {
  final VideoUploadResult streamerstipResult;
  final List<CrossPostResult> crossPostResults;

  const CrossPublishResult({
    required this.streamerstipResult,
    required this.crossPostResults,
  });

  bool get streamerstipSuccess => streamerstipResult.success;
  List<CrossPostResult> get successfulPlatforms =>
      crossPostResults.where((r) => r.isSuccess).toList();
  List<CrossPostResult> get failedPlatforms =>
      crossPostResults.where((r) => !r.isSuccess).toList();
}

class VideoUploadService {
  static final VideoUploadService _instance = VideoUploadService._internal();
  factory VideoUploadService() => _instance;
  VideoUploadService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final VideoModerationService _moderationService = VideoModerationService();
  final EnhancedErrorHandlingService _errorHandler =
      EnhancedErrorHandlingService();
  final TagMentionService _tagMentionService = TagMentionService();

  static const String _muxPlaceholderThumbnailUrl =
      'https://placehold.co/720x1280/1a1a2e/ffffff?text=Processing';

  /// One in-flight canonical create per videoId (Share + reconcile join).
  final Map<String, Future<CanonicalPublishAck>> _canonicalInFlight =
      <String, Future<CanonicalPublishAck>>{};

  /// Fast path: Worker create + optional short Firestore verify.
  ///
  /// Resolves when (and only when) the upload session is allocated and the
  /// canonical `videos/{id}` uploading record is acknowledged. Does **not**
  /// wait for byte PUT or Mux READY.
  ///
  /// Concurrent calls for the same [videoId] share one in-flight future.
  Future<CanonicalPublishAck> createCanonicalPublish({
    required String videoId,
    required String caption,
    required List<String> hashtags,
    required String privacy,
    required bool allowComments,
    Map<String, dynamic>? additionalMetadata,
    bool isDraft = false,
    bool verifyFirestore = true,
  }) {
    final String key = videoId.trim();
    final Future<CanonicalPublishAck>? existing = _canonicalInFlight[key];
    if (existing != null) {
      debugPrint('CANONICAL_REQUEST_JOIN videoId=$key (in-flight)');
      return existing;
    }
    final Future<CanonicalPublishAck> created = _createCanonicalPublishImpl(
      videoId: key,
      caption: caption,
      hashtags: hashtags,
      privacy: privacy,
      allowComments: allowComments,
      additionalMetadata: additionalMetadata,
      isDraft: isDraft,
      verifyFirestore: verifyFirestore,
    ).whenComplete(() {
      _canonicalInFlight.remove(key);
    });
    _canonicalInFlight[key] = created;
    return created;
  }

  Future<CanonicalPublishAck> _createCanonicalPublishImpl({
    required String videoId,
    required String caption,
    required List<String> hashtags,
    required String privacy,
    required bool allowComments,
    Map<String, dynamic>? additionalMetadata,
    bool isDraft = false,
    bool verifyFirestore = true,
  }) async {
    final PublishTransactionTrace? trace = PublishTransactionTrace.active;
    final Stopwatch totalSw = Stopwatch()..start();
    trace?.stage('CANONICAL_REQUEST_START', videoId: videoId);
    debugPrint('CANONICAL_REQUEST_START videoId=$videoId');
    final AppCheckReadiness appCheck = await ensureAppCheckReadyForFirestore();
    if (!appCheck.isReady) {
      trace?.publishFailed(
        stageName: 'APP_CHECK',
        videoId: videoId,
        detail: appCheck.detail,
      );
      debugPrint(
        'PUBLISH_FAILED stage=APP_CHECK videoId=$videoId '
        'detail=${appCheck.detail}',
      );
      throw StateError('App Check not ready: ${appCheck.detail}');
    }
    debugPrint('APP_CHECK_TOKEN_SUCCESS detail=${appCheck.detail}');
    final User? user = _auth.currentUser;
    if (user == null) {
      trace?.publishFailed(
        stageName: 'CANONICAL_HTTP_REQUEST',
        videoId: videoId,
        error: 'not signed in',
      );
      throw StateError('User not authenticated');
    }
    final String? idToken = await user.getIdToken(true).timeout(
      const Duration(seconds: 10),
    );
    if (idToken == null || idToken.isEmpty) {
      trace?.publishFailed(
        stageName: 'CANONICAL_HTTP_REQUEST',
        videoId: videoId,
        error: 'empty id token',
      );
      throw StateError('Failed to get authentication token');
    }
    final String authUid = user.uid;
    final String resolvedCaption = resolveUploadCaption(
      caption: caption,
      additionalMetadata: additionalMetadata,
    );
    final String? rawCategory = additionalMetadata?['category'] as String?;
    final String category = (rawCategory != null && rawCategory.isNotEmpty)
        ? rawCategory
        : _detectCategoryFromContent(resolvedCaption, hashtags);
    final _CanonicalPublishMetadata publishMeta =
        _resolveCanonicalPublishMetadata(
      caption: resolvedCaption,
      additionalMetadata: additionalMetadata,
    );
    MuxDirectUploadResult muxResult;
    try {
      muxResult = await MuxUploadService.instance.createDirectUpload(
        videoId: videoId,
        userId: authUid,
        idToken: idToken,
        caption: resolvedCaption,
        title: publishMeta.title,
        description: publishMeta.description,
        hashtags: hashtags,
        privacy: privacy,
        allowComments: allowComments,
        category: category,
        thumbnailUrl: publishMeta.thumbnailUrl,
        isDraft: isDraft,
      );
    } on TimeoutException catch (e) {
      final CanonicalPublishAck? recovered =
          await _reconcileCanonicalAfterTimeout(
        videoId: videoId,
        expectedOwnerId: authUid,
        caption: resolvedCaption,
        hashtags: hashtags,
        privacy: privacy,
        allowComments: allowComments,
        category: category,
        isDraft: isDraft,
        idToken: idToken,
      );
      if (recovered != null) {
        return recovered;
      }
      trace?.publishFailed(
        stageName: 'CANONICAL_HTTP_REQUEST',
        videoId: videoId,
        error: e,
      );
      rethrow;
    } on WorkerMuxUploadException catch (e) {
      if (e.statusCode == null ||
          e.message.toLowerCase().contains('timeout')) {
        final CanonicalPublishAck? recovered =
            await _reconcileCanonicalAfterTimeout(
          videoId: videoId,
          expectedOwnerId: authUid,
          caption: resolvedCaption,
          hashtags: hashtags,
          privacy: privacy,
          allowComments: allowComments,
          category: category,
          isDraft: isDraft,
          idToken: idToken,
        );
        if (recovered != null) {
          return recovered;
        }
      }
      trace?.publishFailed(
        stageName: 'CANONICAL_HTTP_REQUEST',
        videoId: videoId,
        httpStatus: e.statusCode,
        error: e.message,
      );
      rethrow;
    }
    final String canonicalVideoId = muxResult.videoId.trim().isNotEmpty
        ? muxResult.videoId.trim()
        : videoId;
    final String ownerId = (muxResult.ownerId ?? authUid).trim();
    final String status = (muxResult.status ?? 'uploading').trim().isEmpty
        ? 'uploading'
        : (muxResult.status ?? 'uploading').trim();
    if (ownerId != authUid) {
      trace?.publishFailed(
        stageName: 'CANONICAL_HTTP_REQUEST',
        videoId: canonicalVideoId,
        detail: 'ownerId=$ownerId expected=$authUid',
      );
      throw StateError(
        'Worker ownerId mismatch (got $ownerId, expected $authUid)',
      );
    }
    debugPrint(
      'CANONICAL_CREATE_SUCCESS videoId=$canonicalVideoId '
      'ownerId=$ownerId status=$status '
      'httpStatus=${muxResult.httpStatusCode ?? '-'}',
    );
    trace?.stage(
      'CANONICAL_CREATE_SUCCESS',
      videoId: canonicalVideoId,
      authUid: authUid,
      detail: 'ownerId=$ownerId status=$status',
    );
    CanonicalPublishAck ack = CanonicalPublishAck(
      videoId: canonicalVideoId,
      authUid: authUid,
      ownerId: ownerId,
      status: status,
      uploadUrl: muxResult.uploadUrl,
      muxUploadId: muxResult.uploadId,
      userId: ownerId,
      creatorId: ownerId,
      httpStatusCode: muxResult.httpStatusCode,
    );
    if (verifyFirestore) {
      try {
        final CanonicalPublishAck verified = await _proveCanonicalVideoDoc(
          videoId: canonicalVideoId,
          expectedOwnerId: authUid,
          uploadUrl: muxResult.uploadUrl,
          muxUploadId: muxResult.uploadId,
          httpStatusCode: muxResult.httpStatusCode,
        ).timeout(const Duration(seconds: 5));
        ack = verified;
        debugPrint(
          'CANONICAL_VERIFY_SUCCESS videoId=${ack.videoId} '
          'elapsedMs=${totalSw.elapsedMilliseconds}',
        );
        trace?.stage(
          'CANONICAL_VERIFY_SUCCESS',
          videoId: ack.videoId,
          detail: 'elapsedMs=${totalSw.elapsedMilliseconds}',
        );
      } catch (e) {
        // Worker HTTP ack is authoritative; verify is best-effort.
        debugPrint(
          'CANONICAL_VERIFY_SKIPPED videoId=$canonicalVideoId error=$e '
          '(Worker HTTP ack retained)',
        );
      }
    }
    if (canonicalVideoId != videoId) {
      OptimisticVideoService().bindServerVideoId(
        clientVideoId: videoId,
        serverVideoId: canonicalVideoId,
      );
    } else {
      OptimisticVideoService().attachServerListener(canonicalVideoId);
    }
    return ack;
  }

  Future<CanonicalPublishAck?> _reconcileCanonicalAfterTimeout({
    required String videoId,
    required String expectedOwnerId,
    required String caption,
    required List<String> hashtags,
    required String privacy,
    required bool allowComments,
    required String category,
    required bool isDraft,
    required String idToken,
  }) async {
    final PublishTransactionTrace? trace = PublishTransactionTrace.active;
    debugPrint(
      'CANONICAL_RECONCILE_START videoId=$videoId AUTH_UID=$expectedOwnerId',
    );
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap =
          await _firestore.collection('videos').doc(videoId).get(
                const GetOptions(source: Source.server),
              ).timeout(const Duration(seconds: 5));
      if (!snap.exists || snap.data() == null) {
        debugPrint('CANONICAL_RECONCILE not_found videoId=$videoId');
        return null;
      }
      final Map<String, dynamic> data = snap.data()!;
      final String? ownerId = data['ownerId'] as String?;
      final String? userIdField = data['userId'] as String?;
      final bool ownerOk =
          ownerId == expectedOwnerId || userIdField == expectedOwnerId;
      if (!ownerOk) {
        debugPrint(
          'CANONICAL_RECONCILE owner_mismatch videoId=$videoId '
          'ownerId=$ownerId userId=$userIdField',
        );
        return null;
      }
      // Doc exists — fetch a fresh Mux URL via idempotent Worker create.
      final MuxDirectUploadResult muxResult =
          await MuxUploadService.instance.createDirectUpload(
        videoId: videoId,
        userId: expectedOwnerId,
        idToken: idToken,
        caption: caption,
        hashtags: hashtags,
        privacy: privacy,
        allowComments: allowComments,
        category: category,
        isDraft: isDraft,
      );
      final CanonicalPublishAck ack = CanonicalPublishAck(
        videoId: muxResult.videoId.trim().isNotEmpty
            ? muxResult.videoId.trim()
            : videoId,
        authUid: expectedOwnerId,
        ownerId: muxResult.ownerId ?? ownerId ?? expectedOwnerId,
        status: muxResult.status ??
            (data['status'] as String?) ??
            'uploading',
        uploadUrl: muxResult.uploadUrl,
        muxUploadId: muxResult.uploadId,
        userId: userIdField,
        creatorId: data['creatorId'] as String?,
        httpStatusCode: muxResult.httpStatusCode,
        verifiedFromFirestore: true,
      );
      trace?.stage(
        'CANONICAL_CREATE_SUCCESS',
        videoId: ack.videoId,
        authUid: expectedOwnerId,
        detail: 'via=reconcile ownerId=${ack.ownerId} status=${ack.status}',
      );
      return ack;
    } catch (e) {
      debugPrint('CANONICAL_RECONCILE_FAILED videoId=$videoId error=$e');
      return null;
    }
  }

  /// Upload video with comprehensive moderation checks
  Future<VideoUploadResult> uploadVideo({
    required File videoFile,
    required String caption,
    required List<String> hashtags,
    required String privacy,
    required bool allowComments,
    String? videoId,
    Map<String, dynamic>? additionalMetadata,
    bool isDraft = false,
    void Function(double)? onProgress,
    void Function(CanonicalPublishAck proof)? onCanonicalCreated,
    CanonicalPublishAck? preCreatedAck,
    bool skipModeration = false,
  }) async {
    String? activeVideoId = videoId;
    try {
      debugPrint('🚀 Starting video upload process...');
      // #region agent log
      agentDebugLog(
        hypothesisId: 'F',
        location: 'video_upload_service.dart:uploadVideo',
        message: 'upload_file_check',
        data: <String, Object?>{
          'path': videoFile.path,
          'exists': await videoFile.exists(),
          'videoId': videoId,
        },
        runId: 'post-fix',
      );
      // #endregion

      // 0. Validate file exists and is readable
      if (!await videoFile.exists()) {
        return const VideoUploadResult(
          success: false,
          error: 'Video file not found',
        );
      }

      final fileSize = await videoFile.length();
      debugPrint(
          '📁 Video file size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      // Extract video duration
      final videoProcessingService = VideoProcessingService();
      final duration = await videoProcessingService.getVideoDuration(videoFile);
      final durationSeconds = duration.inSeconds.toDouble();
      debugPrint('⏱️ Video duration: $durationSeconds seconds');

      final String resolvedCaption = resolveUploadCaption(
        caption: caption,
        additionalMetadata: additionalMetadata,
      );

      // 1. Pre-upload moderation check (skipped when Share already moderated)
      VideoModerationResult? moderationResult;
      if (!skipModeration && preCreatedAck == null) {
        debugPrint('🔍 Starting video moderation...');
        moderationResult = await _moderationService.moderateVideo(
          videoFile: videoFile,
          caption: resolvedCaption,
          hashtags: hashtags,
          metadata: additionalMetadata,
        );
        if (!moderationResult.isApproved) {
          debugPrint(
              '❌ Video rejected by moderation: ${moderationResult.reason}');
          return VideoUploadResult(
            success: false,
            error: 'Content rejected: ${moderationResult.reason}',
            metadata: {
              'moderation_result': {
                'approved': false,
                'violations': moderationResult.violations,
                'reason': moderationResult.reason,
                'confidence': moderationResult.confidence,
              }
            },
          );
        }
        debugPrint('✅ Video passed moderation checks');
      } else {
        debugPrint('✅ VideoUploadService: moderation skipped (pre-canonical)');
      }

      final PublishTransactionTrace? trace = PublishTransactionTrace.active;
      final AppCheckReadiness appCheck =
          await ensureAppCheckReadyForFirestore();
      // #region agent log
      agentDebugLog(
        hypothesisId: 'C',
        location: 'video_upload_service.dart:appCheck',
        message: 'app_check_preflight',
        data: <String, Object?>{
          'isReady': appCheck.isReady,
          'detail': appCheck.detail,
          'providerInstalled': isAppCheckProviderInstalled,
        },
      );
      // #endregion
      if (!appCheck.isReady) {
        final UploadFailureClassification failure =
            UploadFailureClassification.classify(appCheck.detail);
        trace?.fail('app-check', detail: appCheck.detail);
        trace?.event('APP_CHECK_FAILED', detail: appCheck.detail);
        debugPrint(
          '❌ VideoUploadService [App Check] ${failure.userMessage}',
        );
        return VideoUploadResult(
          success: false,
          error: failure.userMessage,
        );
      }
      trace?.ok('app-check', detail: appCheck.detail);
      trace?.event('APP_CHECK_TOKEN_READY', detail: appCheck.detail);

      // 2. Get current user
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ VideoUploadService: User not authenticated');
        trace?.fail('auth', detail: 'not signed in');
        return const VideoUploadResult(
          success: false,
          error: 'User not authenticated',
        );
      }

      debugPrint('✅ VideoUploadService: User authenticated - UID: ${user.uid}');
      debugPrint('✅ VideoUploadService: User email: ${user.email}');

      // Force refresh auth token
      String? idToken;
      try {
        idToken = await user.getIdToken(true);
        debugPrint(
            '✅ VideoUploadService: Auth token refreshed - Length: ${idToken?.length ?? 0}');
        trace?.ok('auth', detail: 'uid=${user.uid}');
      } catch (e) {
        debugPrint('❌ VideoUploadService: Failed to refresh auth token: $e');
        trace?.fail('auth', error: e);
        return VideoUploadResult(
          success: false,
          error: 'Authentication token refresh failed: $e',
        );
      }
      if (idToken == null || idToken.isEmpty) {
        trace?.fail('auth', detail: 'empty id token');
        return const VideoUploadResult(
          success: false,
          error: 'Failed to get authentication token',
        );
      }

      final String? clientHintId = activeVideoId?.trim().isNotEmpty == true
          ? activeVideoId!.trim()
          : null;
      final userId = user.uid;
      final rawCategory = additionalMetadata?['category'] as String?;
      final category = (rawCategory != null && rawCategory.isNotEmpty)
          ? rawCategory
          : _detectCategoryFromContent(resolvedCaption, hashtags);
      final _CanonicalPublishMetadata publishMeta =
          _resolveCanonicalPublishMetadata(
        caption: resolvedCaption,
        additionalMetadata: additionalMetadata,
      );

      // 3–4. Use pre-created canonical ack OR Worker create, then PUT bytes.
      String? videoUrl;
      String? thumbnailUrl = publishMeta.thumbnailUrl;
      try {
        late final MuxDirectUploadResult muxResult;
        if (preCreatedAck != null &&
            preCreatedAck.uploadUrl.trim().isNotEmpty) {
          muxResult = MuxDirectUploadResult(
            uploadUrl: preCreatedAck.uploadUrl,
            uploadId: preCreatedAck.muxUploadId,
            videoId: preCreatedAck.videoId,
            ownerId: preCreatedAck.ownerId,
            status: preCreatedAck.status,
            httpStatusCode: preCreatedAck.httpStatusCode,
          );
          activeVideoId = preCreatedAck.videoId;
          onCanonicalCreated?.call(preCreatedAck);
          trace?.stage(
            'CANONICAL_CREATE_SUCCESS',
            videoId: preCreatedAck.videoId,
            authUid: userId,
            detail: 'via=preCreatedAck status=${preCreatedAck.status}',
          );
        } else {
          trace?.stage(
            'CANONICAL_CREATE_REQUEST',
            videoId: clientHintId,
            authUid: userId,
          );
          debugPrint('UPLOAD_URL_REQUEST videoIdHint=$clientHintId');
          muxResult = await MuxUploadService.instance.createDirectUpload(
            videoId: clientHintId,
            userId: userId,
            idToken: idToken,
            caption: resolvedCaption,
            title: publishMeta.title,
            description: publishMeta.description,
            hashtags: hashtags,
            privacy: privacy,
            allowComments: allowComments,
            category: category,
            thumbnailUrl: publishMeta.thumbnailUrl,
            isDraft: isDraft,
          );
          final String canonicalVideoId = muxResult.videoId.trim();
          if (canonicalVideoId.isEmpty) {
            trace?.publishFailed(
              stageName: 'CANONICAL_HTTP_REQUEST',
              videoId: clientHintId,
              error: 'empty videoId',
            );
            return const VideoUploadResult(
              success: false,
              error: 'Upload service did not return a video ID',
            );
          }
          activeVideoId = canonicalVideoId;
          if (clientHintId != null && clientHintId != canonicalVideoId) {
            debugPrint(
              '🎬 VideoUploadService: Worker replaced client id '
              '$clientHintId → $canonicalVideoId',
            );
            OptimisticVideoService().bindServerVideoId(
              clientVideoId: clientHintId,
              serverVideoId: canonicalVideoId,
            );
          } else if (clientHintId != null) {
            OptimisticVideoService().attachServerListener(canonicalVideoId);
          }
          final CanonicalPublishAck proof = await _proveCanonicalVideoDoc(
            videoId: canonicalVideoId,
            expectedOwnerId: userId,
            uploadUrl: muxResult.uploadUrl,
            muxUploadId: muxResult.uploadId,
            httpStatusCode: muxResult.httpStatusCode,
          );
          onCanonicalCreated?.call(proof);
        }
        final String canonicalVideoId = muxResult.videoId.trim();
        activeVideoId = canonicalVideoId;
        debugPrint('🎬 Using canonical video ID: $canonicalVideoId');
        debugPrint('UPLOAD_URL_RECEIVED videoId=$canonicalVideoId');
        trace?.stage(
          'UPLOAD_PUT_STARTED',
          videoId: canonicalVideoId,
          detail: 'bytes=$fileSize',
        );
        debugPrint('UPLOAD_PUT_START videoId=$canonicalVideoId bytes=$fileSize');
        debugPrint('📤 Uploading video to Mux...');
        await MuxUploadService.instance.uploadToMux(
          videoFile: videoFile,
          uploadUrl: muxResult.uploadUrl,
          onProgress: (double progress) {
            trace?.progress(progress);
            debugPrint(
              'UPLOAD_PROGRESS bytesSent=${(progress * fileSize).round()}'
              '/totalBytes=$fileSize',
            );
            onProgress?.call(progress);
          },
        );
        trace?.stage('UPLOAD_PUT_COMPLETE', videoId: canonicalVideoId);
        debugPrint('UPLOAD_PUT_COMPLETE videoId=$canonicalVideoId');
        videoUrl = null;
        thumbnailUrl ??= _muxPlaceholderThumbnailUrl;
        trace?.stage('MUX_PROCESSING', videoId: canonicalVideoId);
        debugPrint('✅ Video uploaded to Mux (webhook will set playback URL)');
      } on WorkerMuxUploadException catch (e) {
        debugPrint('⚠️ Mux Worker upload failed: $e');
        trace?.publishFailed(
          stageName: 'CANONICAL_HTTP_REQUEST',
          videoId: activeVideoId ?? clientHintId,
          httpStatus: e.statusCode,
          error: e.message,
        );
        final UploadFailureClassification failure =
            UploadFailureClassification.classify(e);
        if (activeVideoId != null && activeVideoId.isNotEmpty) {
          await _markVideoUploadFailed(
            videoId: activeVideoId,
            userId: userId,
            errorMessage: failure.userMessage,
          );
        }
        return VideoUploadResult(
          success: false,
          error: failure.userMessage,
          failureStage: 'CANONICAL_HTTP_REQUEST',
          metadata: activeVideoId == null ? null : {'videoId': activeVideoId},
        );
      } catch (e) {
        debugPrint('⚠️ Mux upload failed: $e');
        final String putStage = activeVideoId == null
            ? 'CANONICAL_HTTP_REQUEST'
            : 'UPLOAD_PUT';
        trace?.publishFailed(
          stageName: putStage,
          videoId: activeVideoId ?? clientHintId,
          error: e,
        );
        final UploadFailureClassification failure =
            UploadFailureClassification.classify(e);
        if (activeVideoId != null && activeVideoId.isNotEmpty) {
          await _markVideoUploadFailed(
            videoId: activeVideoId,
            userId: userId,
            errorMessage: failure.userMessage,
          );
        }
        return VideoUploadResult(
          success: false,
          error: failure.userMessage,
          failureStage: putStage,
          metadata: activeVideoId == null ? null : {'videoId': activeVideoId},
        );
      }

      final String resolvedVideoId = activeVideoId.trim();
      if (resolvedVideoId.isEmpty) {
        return const VideoUploadResult(
          success: false,
          error: 'Missing canonical video id after Mux upload',
          failureStage: 'UPLOAD_PUT',
        );
      }
      final String canonicalThumbnailUrl =
          _withSizingParams(thumbnailUrl, width: 720);

      // Worker already created videos/{id} at CANONICAL_CREATE. Do not
      // client-create/update that doc after Mux PUT — rules reject it when
      // isReadyForFeed is present, and Worker/webhook own the document.
      debugPrint(
        'SKIP_FIRESTORE_VIDEO_CREATE videoId=$resolvedVideoId '
        'reason=worker_owns_canonical',
      );
      PublishTransactionTrace.active?.ok(
        'canonical-owned',
        detail: 'videoId=$resolvedVideoId skip=FIRESTORE_VIDEO_CREATE',
      );
      PublishTransactionTrace.active?.event('MUX_PROCESSING');

      unawaited(_syncUserVideoMirror(
        videoId: resolvedVideoId,
        userId: userId,
        privacy: privacy,
        category: category,
        caption: resolvedCaption,
      ));
      scheduleGamificationEvent(
        GamificationEventTypes.contentVideoUploaded,
        entityType: 'video',
        entityId: resolvedVideoId,
        eventId: 'content.video_uploaded_$resolvedVideoId',
      );
      unawaited(
        VideoPublishFinalizeService.instance.waitUntilDiscoverable(
          videoId: resolvedVideoId,
          userId: userId,
          privacy: privacy,
          category: category,
          caption: resolvedCaption,
        ),
      );
      unawaited(() async {
        try {
          await _tagMentionService.processVideoTagsAndMentions(
            videoId: resolvedVideoId,
            videoOwnerId: userId,
            caption: resolvedCaption,
            postThumbnailUrl: canonicalThumbnailUrl,
          );
        } catch (e) {
          debugPrint('⚠️ Failed to process tags and mentions: $e');
        }
      }());

      debugPrint(
        '🎉 Video bytes uploaded — waiting for Mux/Firestore finalization',
      );
      return VideoUploadResult(
        success: true,
        videoUrl: videoUrl,
        thumbnailUrl: canonicalThumbnailUrl,
        metadata: {
          'videoId': resolvedVideoId,
          'publishPhase': 'processing',
          'isVisibleReady': false,
          'moderation_result': {
            'approved': true,
            'confidence': moderationResult?.confidence ?? 0.0,
            'violations': [],
          },
        },
      );
    } catch (e) {
      debugPrint('❌ Video upload failed with exception: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
      final userId = _auth.currentUser?.uid;
      if (activeVideoId != null && userId != null) {
        await _markVideoUploadFailed(
          videoId: activeVideoId,
          userId: userId,
          errorMessage: e.toString(),
        );
      }

      await _errorHandler.handleUploadError(
        operation: 'video_upload',
        error: e,
        context: {
          'file_size': await videoFile.length(),
          'caption_length': caption.length,
          'hashtags_count': hashtags.length,
          'privacy': privacy,
        },
      );

      // Provide more specific error messages based on the error type
      String errorMessage = 'Upload failed: ${e.toString()}';
      if (e.toString().contains('permission-denied')) {
        errorMessage = 'Permission denied. Please check your account status.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('storage')) {
        errorMessage = 'Storage error. Please try again.';
      } else if (e.toString().contains('firestore')) {
        errorMessage = 'Database error. Please try again.';
      }

      return VideoUploadResult(
        success: false,
        error: errorMessage,
        metadata: activeVideoId == null ? null : {'videoId': activeVideoId},
      );
    }
  }

  /// Server-read proof that Worker created `videos/{id}` with correct owner.
  Future<CanonicalPublishAck> _proveCanonicalVideoDoc({
    required String videoId,
    required String expectedOwnerId,
    required String uploadUrl,
    required String muxUploadId,
    int? httpStatusCode,
  }) async {
    final PublishTransactionTrace? trace = PublishTransactionTrace.active;
    final DocumentSnapshot<Map<String, dynamic>> snap =
        await _firestore.collection('videos').doc(videoId).get(
              const GetOptions(source: Source.server),
            );
    if (!snap.exists || snap.data() == null) {
      trace?.publishFailed(
        stageName: 'CANONICAL_VERIFY',
        videoId: videoId,
        error: 'videos/$videoId missing after Worker create',
      );
      throw StateError(
        'Canonical videos/$videoId does not exist after direct-upload create',
      );
    }
    final Map<String, dynamic> data = snap.data()!;
    final String? ownerId = data['ownerId'] as String?;
    final String? userIdField = data['userId'] as String?;
    final String? creatorId = data['creatorId'] as String?;
    final String status =
        ((data['status'] as String?)?.trim().isNotEmpty == true)
            ? (data['status'] as String).trim()
            : 'uploading';
    debugPrint('AUTH_UID=$expectedOwnerId');
    debugPrint('VIDEO_ID=$videoId');
    debugPrint('CANONICAL_DOC_PATH=videos/$videoId');
    debugPrint(
      'OWNER_FIELDS: ownerId=$ownerId creatorId=$creatorId '
      'userId=$userIdField status=$status',
    );
    final bool ownerMatches = ownerId == expectedOwnerId;
    final bool legacyMatches = userIdField == expectedOwnerId ||
        creatorId == expectedOwnerId;
    if (!ownerMatches && !legacyMatches) {
      trace?.publishFailed(
        stageName: 'CANONICAL_VERIFY',
        videoId: videoId,
        detail: 'expected=$expectedOwnerId ownerId=$ownerId '
            'userId=$userIdField creatorId=$creatorId',
      );
      throw StateError(
        'Canonical videos/$videoId owner mismatch '
        '(expected $expectedOwnerId, ownerId=$ownerId)',
      );
    }
    if (!ownerMatches) {
      debugPrint(
        '⚠️ CANONICAL_OWNER: ownerId missing/mismatched but legacy '
        'userId/creatorId matched auth uid — new uploads should set ownerId',
      );
    }
    return CanonicalPublishAck(
      videoId: videoId,
      authUid: expectedOwnerId,
      ownerId: ownerId ?? expectedOwnerId,
      status: status,
      uploadUrl: uploadUrl,
      muxUploadId: muxUploadId,
      userId: userIdField,
      creatorId: creatorId,
      httpStatusCode: httpStatusCode,
      verifiedFromFirestore: true,
    );
  }

  Future<void> _markVideoUploadFailed({
    required String videoId,
    required String userId,
    required String errorMessage,
  }) async {
    // Do not write isReadyForFeed / mux / status on videos/{id} — those are
    // server-owned. Mirror failure on the owner subcollection only.
    debugPrint(
      'JOB_STATE FAILED reason=$errorMessage videoId=$videoId',
    );
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('videos')
          .doc(videoId)
          .set(<String, dynamic>{
        'videoId': videoId,
        'userId': userId,
        'status': 'failed',
        'visible': false,
        'uploadError': errorMessage,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('✅ VideoUploadService: Marked failed upload mirror: $videoId');
    } catch (markError) {
      debugPrint(
          '⚠️ VideoUploadService: Failed to mark upload failed for $videoId: $markError');
    }
  }

  Future<void> _syncUserVideoMirror({
    required String videoId,
    required String userId,
    required String privacy,
    required String category,
    required String caption,
  }) async {
    try {
      final String trimmedCaption = caption.trim();
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('videos')
          .doc(videoId)
          .set(<String, dynamic>{
        'videoId': videoId,
        'userId': userId,
        'status': 'processing',
        'visible': false,
        'privacy': privacy,
        'category': category,
        if (trimmedCaption.isNotEmpty) 'caption': trimmedCaption,
        if (trimmedCaption.isNotEmpty) 'description': trimmedCaption,
        if (trimmedCaption.isNotEmpty) 'title': trimmedCaption,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ VideoUploadService: users/…/videos mirror failed: $e');
    }
  }

  /// Upload to StreamersTip AND cross-post to external platforms concurrently.
  ///
  /// StreamersTip upload is always primary. Cross-post failures never block it.
  /// Uses [Future.wait] with [eagerError: false] so both actions run to
  /// completion regardless of individual failures.
  Future<CrossPublishResult> publishWithCrossPost({
    required File videoFile,
    required String caption,
    required List<String> hashtags,
    required String privacy,
    required bool allowComments,
    required List<CrossPostRequest> crossPostRequests,
    String? videoId,
    Map<String, dynamic>? additionalMetadata,
    DateTime? scheduleAt,
    void Function(double)? onProgress,
    void Function(CanonicalPublishAck proof)? onCanonicalCreated,
    CanonicalPublishAck? preCreatedAck,
    bool skipModeration = false,
  }) async {
    // Fire both concurrently; eagerError: false keeps both running.
    final futures = await Future.wait(
      [
        uploadVideo(
          videoFile: videoFile,
          caption: caption,
          hashtags: hashtags,
          privacy: privacy,
          allowComments: allowComments,
          videoId: videoId,
          additionalMetadata: additionalMetadata,
          onProgress: onProgress,
          onCanonicalCreated: onCanonicalCreated,
          preCreatedAck: preCreatedAck,
          skipModeration: skipModeration || preCreatedAck != null,
        ),
        if (crossPostRequests.isNotEmpty)
          CrossPostService.instance.publishToAll(
            requests: crossPostRequests,
          )
        else
          Future.value(<CrossPostResult>[]),
      ],
      eagerError: false,
    );

    final stResult = futures[0] as VideoUploadResult;
    final cpResults = futures[1] as List<CrossPostResult>;
    return CrossPublishResult(
      streamerstipResult: stResult,
      crossPostResults: cpResults,
    );
  }

  String _withSizingParams(String url, {int width = 720}) {
    try {
      final uri = Uri.parse(url);
      final params = Map<String, String>.from(uri.queryParameters);
      params['w'] = '$width';
      params.remove('h');
      params.remove('fit');
      params.remove('crop');
      return uri.replace(queryParameters: params).toString();
    } catch (_) {
      return url;
    }
  }

  /// Save video as draft (uses Mux; webhook sets status 'draft').
  Future<VideoUploadResult> saveAsDraft({
    required File videoFile,
    required String caption,
    required List<String> hashtags,
    required String privacy,
    required bool allowComments,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    return uploadVideo(
      videoFile: videoFile,
      caption: caption,
      hashtags: hashtags,
      privacy: privacy,
      allowComments: allowComments,
      additionalMetadata: additionalMetadata,
      isDraft: true,
    );
  }

  /// Add video to appropriate feeds based on privacy setting
  Future<void> _addToFeeds(String videoId, String privacy, String userId,
      {String? category}) async {
    try {
      switch (privacy) {
        case 'Everyone':
          // Add to public feeds (For You feed)
          await _firestore
              .collection('feeds')
              .doc('for_you')
              .collection('videos')
              .doc(videoId)
              .set({
            'videoId': videoId,
            'userId': userId,
            'privacy': privacy,
            'addedAt': FieldValue.serverTimestamp(),
          });

          // Add to following feed for user's followers
          await _firestore
              .collection('feeds')
              .doc('following')
              .collection('videos')
              .doc(videoId)
              .set({
            'videoId': videoId,
            'userId': userId,
            'privacy': privacy,
            'addedAt': FieldValue.serverTimestamp(),
          });

          // Add to category feed if category is specified
          if (category != null && category.isNotEmpty) {
            await _firestore
                .collection('feeds')
                .doc('categories')
                .collection(category)
                .doc(videoId)
                .set({
              'videoId': videoId,
              'userId': userId,
              'category': category,
              'privacy': privacy,
              'addedAt': FieldValue.serverTimestamp(),
            });
          }
          break;

        case 'Connections':
          // Add only to following feed (connections can see)
          await _firestore
              .collection('feeds')
              .doc('following')
              .collection('videos')
              .doc(videoId)
              .set({
            'videoId': videoId,
            'userId': userId,
            'privacy': privacy,
            'addedAt': FieldValue.serverTimestamp(),
          });

          // Add to connections-only category feed if category is specified
          if (category != null && category.isNotEmpty) {
            await _firestore
                .collection('feeds')
                .doc('connections_categories')
                .collection(category)
                .doc(videoId)
                .set({
              'videoId': videoId,
              'userId': userId,
              'category': category,
              'privacy': privacy,
              'addedAt': FieldValue.serverTimestamp(),
            });
          }
          break;

        case 'Private':
          // Add only to user's private collection (not in any public feeds)
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('private_videos')
              .doc(videoId)
              .set({
            'videoId': videoId,
            'userId': userId,
            'privacy': privacy,
            'addedAt': FieldValue.serverTimestamp(),
          });
          break;

        default:
          // Default to private if unknown privacy setting
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('private_videos')
              .doc(videoId)
              .set({
            'videoId': videoId,
            'userId': userId,
            'privacy': privacy,
            'addedAt': FieldValue.serverTimestamp(),
          });
          break;
      }
    } catch (e) {
      debugPrint('Error adding to feeds: $e');
    }
  }

  /// Detect category from caption and hashtags (website parity).
  String _detectCategoryFromContent(
    String caption,
    List<String> hashtags,
  ) {
    final content = '$caption ${hashtags.join(' ')}'.toLowerCase();
    const keywords = {
      'Gaming': [
        'game',
        'gaming',
        'gamer',
        'play',
        'stream',
        'twitch',
        'esports',
        'fortnite',
        'minecraft',
        'valorant',
        'apex',
        'cod',
        'fifa',
        'nba2k',
      ],
      'Art': [
        'art',
        'drawing',
        'paint',
        'sketch',
        'artist',
        'artwork',
        'digital art',
        'illustration',
        'design',
      ],
      'Music': [
        'music',
        'song',
        'sing',
        'rap',
        'beat',
        'producer',
        'dj',
        'audio',
      ],
      'Tech': [
        'tech',
        'coding',
        'programming',
        'software',
        'app',
        'computer',
        'review',
        'unboxing',
      ],
      'Sports': [
        'sport',
        'football',
        'basketball',
        'soccer',
        'workout',
        'athlete',
      ],
      'Food': [
        'food',
        'cooking',
        'recipe',
        'eat',
        'restaurant',
        'chef',
        'meal',
      ],
      'Travel': [
        'travel',
        'trip',
        'vacation',
        'journey',
        'adventure',
        'explore',
      ],
      'Fashion': [
        'fashion',
        'style',
        'outfit',
        'clothing',
        'wear',
        'dress',
      ],
      'Comedy': [
        'funny',
        'comedy',
        'joke',
        'laugh',
        'humor',
        'meme',
        'prank',
      ],
      'Education': [
        'learn',
        'education',
        'tutorial',
        'teach',
        'study',
        'how to',
      ],
      'Fitness': [
        'fitness',
        'gym',
        'workout',
        'exercise',
        'health',
        'yoga',
      ],
      'Lifestyle': [
        'lifestyle',
        'daily',
        'vlog',
        'routine',
        'morning',
        'life',
      ],
    };
    for (final entry in keywords.entries) {
      if (entry.value.any((k) => content.contains(k))) return entry.key;
    }
    return 'Other';
  }

  /// Get user's videos
  Future<List<Map<String, dynamic>>> getUserVideos(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      // appLog('Error getting user videos: $e');
      return [];
    }
  }

  /// Get user's drafts
  Future<List<Map<String, dynamic>>> getUserDrafts(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'draft')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      // appLog('Error getting user drafts: $e');
      return [];
    }
  }

  /// Publish draft video
  Future<VideoUploadResult> publishDraft(String videoId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return const VideoUploadResult(
          success: false,
          error: 'User not authenticated',
        );
      }

      // Get draft video
      final doc = await _firestore.collection('videos').doc(videoId).get();
      if (!doc.exists) {
        return const VideoUploadResult(
          success: false,
          error: 'Draft not found',
        );
      }

      final videoData = doc.data()!;
      final videoFile =
          File(videoData['videoUrl']); // This would need proper file handling

      // Re-run moderation
      final moderationResult = await _moderationService.moderateVideo(
        videoFile: videoFile,
        caption: videoData['caption'],
        hashtags: List<String>.from(videoData['hashtags'] ?? []),
        metadata: videoData['metadata'],
      );

      if (!moderationResult.isApproved) {
        return VideoUploadResult(
          success: false,
          error: 'Content rejected: ${moderationResult.reason}',
        );
      }

      // Update video status
      await _firestore.collection('videos').doc(videoId).update({
        'status': 'published',
        'moderation': {
          'approved': true,
          'checkedAt': FieldValue.serverTimestamp(),
          'confidence': moderationResult.confidence,
          'violations': [],
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add to feeds
      final category = videoData['metadata']?['category'] as String?;
      await _addToFeeds(videoId, videoData['privacy'], user.uid,
          category: category);
      scheduleGamificationEvent(
        GamificationEventTypes.contentPublished,
        entityType: 'video',
        entityId: videoId,
        eventId: 'content.published_$videoId',
      );
      DailyActivityService.instance.maybeEmitDayQualified(
        source: 'publish',
      );
      return VideoUploadResult(
        success: true,
        videoUrl: videoData['videoUrl'],
        thumbnailUrl: videoData['thumbnailUrl'],
        metadata: {'videoId': videoId, 'status': 'published'},
      );
    } catch (e) {
      return VideoUploadResult(
        success: false,
        error: 'Publish failed: ${e.toString()}',
      );
    }
  }
}

class _CanonicalPublishMetadata {
  const _CanonicalPublishMetadata({
    required this.title,
    required this.description,
    this.thumbnailUrl,
  });

  final String title;
  final String description;
  final String? thumbnailUrl;
}

_CanonicalPublishMetadata _resolveCanonicalPublishMetadata({
  required String caption,
  Map<String, dynamic>? additionalMetadata,
}) {
  final String trimmedCaption = caption.trim();
  final String title = ((additionalMetadata?['title'] as String?) ??
          trimmedCaption)
      .trim();
  final String description = ((additionalMetadata?['description'] as String?) ??
          trimmedCaption)
      .trim();
  final String? thumb = ((additionalMetadata?['thumbnailUrl'] as String?) ??
          (additionalMetadata?['thumbnailURL'] as String?) ??
          (additionalMetadata?['thumbnail_url'] as String?))
      ?.trim();
  return _CanonicalPublishMetadata(
    title: title.isNotEmpty ? title : 'Untitled Video',
    description: description.isNotEmpty
        ? description
        : (title.isNotEmpty ? title : 'Untitled Video'),
    thumbnailUrl: (thumb != null && thumb.isNotEmpty) ? thumb : null,
  );
}
