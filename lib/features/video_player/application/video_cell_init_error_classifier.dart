import 'dart:async' show TimeoutException;

/// Classifies init failures for retry, quarantine, or user messaging.
enum VideoCellInitErrorKind {
  timeout,
  outOfMemory,
  format,
  permanentSource,
  networkRetry,
  generic,
}

class VideoCellInitErrorClassifier {
  const VideoCellInitErrorClassifier();

  VideoCellInitErrorKind classify(Object error) {
    if (error is TimeoutException) {
      return VideoCellInitErrorKind.timeout;
    }
    final String errorString = error.toString().toLowerCase();
    if (_isOutOfMemory(errorString)) {
      return VideoCellInitErrorKind.outOfMemory;
    }
    if (_isFormatError(errorString)) {
      return VideoCellInitErrorKind.format;
    }
    if (_isPermanentSourceError(errorString)) {
      return VideoCellInitErrorKind.permanentSource;
    }
    if (_isNetworkError(errorString)) {
      return VideoCellInitErrorKind.networkRetry;
    }
    return VideoCellInitErrorKind.generic;
  }

  String userFriendlyMessage(Object error) {
    final String errorString = error.toString().toLowerCase();
    if (errorString.contains('402') ||
        errorString.contains('invalidresponsecode') ||
        errorString.contains('payment required')) {
      return 'Video unavailable. Storage limit exceeded.';
    }
    if (errorString.contains('unrecognizedinputformat') ||
        errorString.contains('could read the stream') ||
        errorString.contains('extractor')) {
      return 'Video format not supported.';
    }
    if (_isOutOfMemory(errorString)) {
      return 'Device memory too low for video playback. '
          'Video resolution may be too high for this device.';
    }
    if (errorString.contains('timeout')) {
      return 'Video took too long to load';
    }
    if (errorString.contains('network') ||
        errorString.contains('connection')) {
      return 'Network connection issue';
    }
    if (errorString.contains('format') || errorString.contains('codec')) {
      return 'Video format not supported';
    }
    if (errorString.contains('permission')) {
      return 'Permission denied';
    }
    return 'Unable to play video';
  }

  bool _isNetworkError(String errorString) {
    return errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('socket') ||
        errorString.contains('failed host lookup');
  }

  bool _isPermanentSourceError(String errorString) {
    return errorString.contains('response code: 404') ||
        errorString.contains('invalidresponsecodeexception') ||
        errorString.contains('source error');
  }

  bool _isOutOfMemory(String errorString) {
    return errorString.contains('outofmemory') ||
        errorString.contains('out of memory') ||
        errorString.contains('no_memory') ||
        (errorString.contains('memory') &&
            errorString.contains('allocation')) ||
        (errorString.contains('mediacodec') &&
            errorString.contains('bufferinfo')) ||
        errorString.contains('illegalstateexception');
  }

  bool _isFormatError(String errorString) {
    return errorString.contains('format') ||
        errorString.contains('unsupported') ||
        errorString.contains('codec') ||
        errorString.contains('mime type') ||
        errorString.contains('not supported') ||
        errorString.contains('unable to instantiate decoder');
  }
}
