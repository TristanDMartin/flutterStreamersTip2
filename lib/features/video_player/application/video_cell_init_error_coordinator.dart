import 'dart:async' show TimeoutException;

import 'video_cell_init_error_classifier.dart';

class VideoCellInitErrorPlan {
  const VideoCellInitErrorPlan({
    required this.kind,
    this.userMessage,
    this.retryDelay,
    this.quarantineVideo = false,
    this.logFormatUnplayable = false,
    this.unplayableReason,
    this.showErrorAfterDelay = false,
    this.resetRetryCount = false,
    this.clearControllerReference = false,
    this.incrementControllerVersion = false,
  });

  final VideoCellInitErrorKind kind;
  final String? userMessage;
  final Duration? retryDelay;
  final bool quarantineVideo;
  final bool logFormatUnplayable;
  final String? unplayableReason;
  final bool showErrorAfterDelay;
  final bool resetRetryCount;
  final bool clearControllerReference;
  final bool incrementControllerVersion;
}

/// Maps init exceptions to widget-side actions.
class VideoCellInitErrorCoordinator {
  const VideoCellInitErrorCoordinator({
    VideoCellInitErrorClassifier classifier = const VideoCellInitErrorClassifier(),
  }) : _classifier = classifier;

  final VideoCellInitErrorClassifier _classifier;

  VideoCellInitErrorPlan planForTimeout() {
    return const VideoCellInitErrorPlan(
      kind: VideoCellInitErrorKind.timeout,
      userMessage: 'Video took too long to load. Check connection and retry.',
      clearControllerReference: true,
      incrementControllerVersion: true,
      resetRetryCount: true,
    );
  }

  VideoCellInitErrorPlan planForError({
    required Object error,
    required int retryCount,
    required int maxRetries,
    required Duration baseRetryDelay,
  }) {
    final VideoCellInitErrorKind kind = _classifier.classify(error);
    switch (kind) {
      case VideoCellInitErrorKind.timeout:
        return planForTimeout();
      case VideoCellInitErrorKind.outOfMemory:
        return VideoCellInitErrorPlan(
          kind: kind,
          userMessage: 'Device memory too low for video playback. '
              'Try closing other apps.',
          clearControllerReference: true,
          resetRetryCount: true,
        );
      case VideoCellInitErrorKind.format:
        return VideoCellInitErrorPlan(
          kind: kind,
          quarantineVideo: true,
          logFormatUnplayable: true,
          unplayableReason: 'format_not_supported',
          clearControllerReference: true,
          incrementControllerVersion: true,
          resetRetryCount: true,
        );
      case VideoCellInitErrorKind.permanentSource:
        return VideoCellInitErrorPlan(
          kind: kind,
          quarantineVideo: true,
          unplayableReason: '404_source_not_found',
          userMessage: 'Video unavailable',
          clearControllerReference: true,
          incrementControllerVersion: true,
          resetRetryCount: true,
        );
      case VideoCellInitErrorKind.networkRetry:
        if (retryCount < maxRetries) {
          final int nextRetry = retryCount + 1;
          return VideoCellInitErrorPlan(
            kind: kind,
            retryDelay: Duration(
              seconds: baseRetryDelay.inSeconds * nextRetry,
            ),
            clearControllerReference: true,
          );
        }
        return VideoCellInitErrorPlan(
          kind: VideoCellInitErrorKind.generic,
          userMessage: _classifier.userFriendlyMessage(error),
          showErrorAfterDelay: true,
          clearControllerReference: true,
          resetRetryCount: true,
        );
      case VideoCellInitErrorKind.generic:
        return VideoCellInitErrorPlan(
          kind: kind,
          userMessage: _classifier.userFriendlyMessage(error),
          showErrorAfterDelay: true,
          clearControllerReference: true,
          resetRetryCount: true,
        );
    }
  }

  bool isTimeout(Object error) => error is TimeoutException;
}
