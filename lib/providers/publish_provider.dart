import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/scheduled_post.dart';
import '../services/cross_post_service.dart';
import '../services/firestore_scheduled_post_service.dart';
import '../services/video_upload_service.dart';

enum StreamersTipState { idle, uploading, processing, success, failed }

enum CrossPostState { idle, sending, success, failed }

enum OverallPublishState {
  idle,
  inProgress,
  allSuccess,
  streamerstipOnlySuccess,
  partialSuccess,
  failed,
}

class PublishNowRequest {
  final File videoFile;
  final String caption;
  final List<String> hashtags;
  final String privacy;
  final bool allowComments;
  final List<CrossPostRequest> crossPostRequests;
  final Map<String, dynamic>? additionalMetadata;
  final void Function(double progress)? onProgress;

  const PublishNowRequest({
    required this.videoFile,
    required this.caption,
    required this.hashtags,
    required this.privacy,
    required this.allowComments,
    required this.crossPostRequests,
    this.additionalMetadata,
    this.onProgress,
  });
}

class SchedulePublishRequest {
  final String videoId;
  final String videoUrl;
  final String thumbnailUrl;
  final String caption;
  final List<String> hashtags;
  final String category;
  final String privacy;
  final bool allowComments;
  final PostSchedule schedule;
  final Map<String, dynamic> metadata;
  final List<CrossPostRequest> crossPostRequests;

  const SchedulePublishRequest({
    required this.videoId,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.caption,
    required this.hashtags,
    required this.category,
    required this.privacy,
    required this.allowComments,
    required this.schedule,
    required this.metadata,
    required this.crossPostRequests,
  });
}

class PublishExecutionResult {
  final CrossPublishResult? publishResult;
  final String? scheduledPostId;
  final String? uploadedVideoId;
  final OverallPublishState overallState;

  const PublishExecutionResult({
    required this.overallState,
    this.publishResult,
    this.scheduledPostId,
    this.uploadedVideoId,
  });
}

final publishControllerProvider =
    ChangeNotifierProvider<PublishProvider>((ref) {
  return PublishProvider(
    uploadService: VideoUploadService(),
    scheduledPostService: FirestoreScheduledPostService(),
  );
});

class PublishProvider extends ChangeNotifier {
  PublishProvider({
    required VideoUploadService uploadService,
    required FirestoreScheduledPostService scheduledPostService,
  })  : _uploadService = uploadService,
        _scheduledPostService = scheduledPostService;

  final VideoUploadService _uploadService;
  final FirestoreScheduledPostService _scheduledPostService;

  StreamersTipState _streamerstipState = StreamersTipState.idle;
  final Map<String, CrossPostState> _crossPostResults = {};
  final Map<String, String> _errorDetails = {};
  String? _uploadedVideoId;
  String? _scheduledPostId;

  StreamersTipState get streamerstipState => _streamerstipState;
  Map<String, CrossPostState> get crossPostResults =>
      Map.unmodifiable(_crossPostResults);
  Map<String, String> get errorDetails => Map.unmodifiable(_errorDetails);
  String? get uploadedVideoId => _uploadedVideoId;
  String? get scheduledPostId => _scheduledPostId;

  OverallPublishState get overallState {
    if (_streamerstipState == StreamersTipState.failed) {
      return OverallPublishState.failed;
    }
    if (_streamerstipState == StreamersTipState.idle &&
        _crossPostResults.isEmpty) {
      return OverallPublishState.idle;
    }
    if (_streamerstipState == StreamersTipState.uploading ||
        _streamerstipState == StreamersTipState.processing ||
        _crossPostResults.values.any((s) => s == CrossPostState.sending)) {
      return OverallPublishState.inProgress;
    }
    if (_streamerstipState == StreamersTipState.success) {
      if (_crossPostResults.isEmpty) {
        return OverallPublishState.allSuccess;
      }
      final allOk =
          _crossPostResults.values.every((s) => s == CrossPostState.success);
      if (allOk) return OverallPublishState.allSuccess;
      final allFailed =
          _crossPostResults.values.every((s) => s == CrossPostState.failed);
      if (allFailed) return OverallPublishState.streamerstipOnlySuccess;
      return OverallPublishState.partialSuccess;
    }
    return OverallPublishState.idle;
  }

  List<String> get successfulPlatforms => _crossPostResults.entries
      .where((e) => e.value == CrossPostState.success)
      .map((e) => e.key)
      .toList();

  List<String> get failedPlatforms => _crossPostResults.entries
      .where((e) => e.value == CrossPostState.failed)
      .map((e) => e.key)
      .toList();

  Future<PublishExecutionResult> publishNow(PublishNowRequest request) async {
    _startPublish(request.crossPostRequests);

    try {
      final result = await _uploadService.publishWithCrossPost(
        videoFile: request.videoFile,
        caption: request.caption,
        hashtags: request.hashtags,
        privacy: request.privacy,
        allowComments: request.allowComments,
        crossPostRequests: request.crossPostRequests,
        additionalMetadata: request.additionalMetadata,
        onProgress: request.onProgress,
      );

      final uploadedVideoId =
          result.streamerstipResult.metadata?['videoId'] as String?;
      _uploadedVideoId = uploadedVideoId;

      if (result.streamerstipSuccess) {
        if (uploadedVideoId != null && uploadedVideoId.isNotEmpty) {
          _streamerstipState = StreamersTipState.processing;
          notifyListeners();
        }
        _streamerstipState = StreamersTipState.success;
      } else {
        _streamerstipState = StreamersTipState.failed;
        final rawError =
            result.streamerstipResult.error ?? 'Failed to publish video';
        _errorDetails['streamerstip'] = rawError;
      }

      _applyCrossPostResults(result.crossPostResults);
      if (result.streamerstipSuccess &&
          _uploadedVideoId != null &&
          _hasRecoverableCrossPostState()) {
        try {
          _scheduledPostId =
              await _scheduledPostService.saveImmediatePublishFollowUp(
            videoId: _uploadedVideoId!,
            videoUrl: result.streamerstipResult.videoUrl,
            thumbnailUrl: result.streamerstipResult.thumbnailUrl,
            caption: request.caption,
            hashtags: request.hashtags,
            category: request.additionalMetadata?['category'] as String? ?? '',
            privacy: request.privacy,
            allowComments: request.allowComments,
            metadata: request.additionalMetadata ?? const {},
            crossPostRequests: request.crossPostRequests,
            crossPostResults: result.crossPostResults,
          );
        } catch (e) {
          debugPrint('Failed to persist publish follow-up record: $e');
        }
      }
      notifyListeners();

      return PublishExecutionResult(
        publishResult: result,
        scheduledPostId: _scheduledPostId,
        uploadedVideoId: _uploadedVideoId,
        overallState: overallState,
      );
    } catch (e) {
      _streamerstipState = StreamersTipState.failed;
      _errorDetails['streamerstip'] = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<PublishExecutionResult> saveScheduledPublish(
    SchedulePublishRequest request,
  ) async {
    _startPublish(request.crossPostRequests);
    _streamerstipState = StreamersTipState.processing;
    _uploadedVideoId = request.videoId;
    notifyListeners();

    try {
      final scheduledPostId = await _scheduledPostService.saveScheduledPost(
        videoId: request.videoId,
        videoUrl: request.videoUrl,
        thumbnailUrl: request.thumbnailUrl,
        caption: request.caption,
        hashtags: request.hashtags,
        category: request.category,
        privacy: request.privacy,
        allowComments: request.allowComments,
        schedule: request.schedule,
        metadata: request.metadata,
        platforms: _buildPlatformConfigs(
          request.crossPostRequests,
          request.schedule,
        ),
      );

      _scheduledPostId = scheduledPostId;
      _streamerstipState = StreamersTipState.success;
      for (final request in request.crossPostRequests) {
        _crossPostResults[request.platformName] = CrossPostState.idle;
      }
      notifyListeners();

      return PublishExecutionResult(
        scheduledPostId: scheduledPostId,
        uploadedVideoId: request.videoId,
        overallState: overallState,
      );
    } catch (e) {
      _streamerstipState = StreamersTipState.failed;
      _errorDetails['streamerstip'] = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void reset() {
    _streamerstipState = StreamersTipState.idle;
    _crossPostResults.clear();
    _errorDetails.clear();
    _uploadedVideoId = null;
    _scheduledPostId = null;
    notifyListeners();
  }

  Future<List<CrossPostResult>> retryCrossPosts({
    required String videoId,
    required List<CrossPostRequest> requests,
  }) async {
    if (requests.isEmpty) return const [];

    for (final request in requests) {
      _crossPostResults[request.platformName] = CrossPostState.sending;
      _errorDetails.remove(request.platformName);
    }
    notifyListeners();

    if (_scheduledPostId != null) {
      await _scheduledPostService.updatePlatformStatuses(
        _scheduledPostId!,
        status: PlatformStatus.publishing,
        platformKeys: requests.map((request) => request.platformName.toLowerCase()).toList(),
        clearErrors: true,
      );
    }

    final results = await CrossPostService.instance.publishToAll(
      requests: requests
          .map(
            (request) => CrossPostRequest(
              platformName: request.platformName,
              caption: request.caption,
              videoId: videoId,
              scheduleAt: request.scheduleAt,
            ),
          )
          .toList(),
    );
    _applyCrossPostResults(results);
    if (_scheduledPostId != null) {
      await _scheduledPostService.applyCrossPostResults(_scheduledPostId!, results);
    }
    notifyListeners();
    return results;
  }

  void _startPublish(List<CrossPostRequest> crossPostRequests) {
    _streamerstipState = StreamersTipState.uploading;
    _crossPostResults.clear();
    _errorDetails.clear();
    _uploadedVideoId = null;
    _scheduledPostId = null;
    for (final request in crossPostRequests) {
      _crossPostResults[request.platformName] = CrossPostState.sending;
    }
    notifyListeners();
  }

  void _applyCrossPostResults(List<CrossPostResult> results) {
    for (final result in results) {
      if (result.isSuccess) {
        _crossPostResults[result.platformName] = CrossPostState.success;
      } else {
        _crossPostResults[result.platformName] = CrossPostState.failed;
        _errorDetails[result.platformName] =
            result.errorMessage ?? 'Unknown cross-post error';
      }
    }
  }

  bool _hasRecoverableCrossPostState() {
    if (_crossPostResults.isEmpty) {
      return false;
    }
    return _crossPostResults.values.any((state) => state == CrossPostState.failed);
  }

  List<PlatformConfig> _buildPlatformConfigs(
    List<CrossPostRequest> requests,
    PostSchedule schedule,
  ) {
    return requests
        .map(
          (request) => PlatformConfig(
            key: request.platformName.toLowerCase(),
            enabled: true,
            payload: {
              'caption': request.caption,
            },
            status: PlatformStatus.pending,
            error: null,
            scheduledAtUtc: request.scheduleAt ?? schedule.scheduledAtUtc,
          ),
        )
        .toList();
  }
}
