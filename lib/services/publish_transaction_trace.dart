import 'package:flutter/foundation.dart';

/// One-line-per-step publish transaction log.
///
/// Filter device logs with: `adb logcat | grep PUBLISH`
class PublishTransactionTrace {
  PublishTransactionTrace._(this.publishId);

  final String publishId;
  final List<String> _summary = <String>[];
  int _lastProgressBucket = -1;

  static PublishTransactionTrace? _active;

  static PublishTransactionTrace? get active => _active;

  /// Starts a new publish transaction (ends any previous one).
  static PublishTransactionTrace begin({
    required String publishRequestId,
    String? draftId,
    String? videoId,
    bool? hasBakedEdits,
    String? sourcePath,
    String? renderedPath,
  }) {
    _active?.end(abandoned: true);
    final String id = publishRequestId.trim().isNotEmpty
        ? publishRequestId.trim()
        : (videoId?.trim().isNotEmpty == true
            ? videoId!.trim()
            : 'anon_${DateTime.now().millisecondsSinceEpoch}');
    final PublishTransactionTrace trace = PublishTransactionTrace._(id);
    _active = trace;
    debugPrint('========== PUBLISH #$id ==========');
    debugPrint(
      'PUBLISH_START'
      ' draftId=${draftId ?? '-'}'
      ' publishRequestId=$id'
      ' videoId=${videoId ?? '-'}'
      ' hasBakedEdits=${hasBakedEdits ?? '-'}'
      ' sourcePath=${sourcePath ?? '-'}'
      ' renderedPath=${renderedPath ?? '-'}',
    );
    return trace;
  }

  static PublishTransactionTrace? forId(String? publishRequestId) {
    final PublishTransactionTrace? active = _active;
    if (active == null || publishRequestId == null) {
      return active;
    }
    if (active.publishId == publishRequestId.trim()) {
      return active;
    }
    return active;
  }

  void event(String name, {String? detail}) {
    if (detail == null || detail.isEmpty) {
      debugPrint(name);
      return;
    }
    debugPrint('$name $detail');
  }

  /// Named publish stage (filter: `PUBLISH|CANONICAL|UPLOAD_PUT|MUX_`).
  void stage(
    String name, {
    String? videoId,
    String? authUid,
    String? detail,
  }) {
    final StringBuffer buffer = StringBuffer(name);
    if (videoId != null && videoId.isNotEmpty) {
      buffer.write(' videoId=$videoId');
    }
    if (authUid != null && authUid.isNotEmpty) {
      buffer.write(' AUTH_UID=$authUid');
    }
    if (detail != null && detail.isNotEmpty) {
      buffer.write(' $detail');
    }
    final String line = buffer.toString();
    _summary.add(line);
    debugPrint(line);
  }

  void publishFailed({
    required String stageName,
    String? videoId,
    int? httpStatus,
    Object? error,
    String? detail,
  }) {
    final StringBuffer buffer = StringBuffer('PUBLISH_FAILED');
    buffer.write(' stage=$stageName');
    if (videoId != null && videoId.isNotEmpty) {
      buffer.write(' videoId=$videoId');
    }
    if (httpStatus != null) {
      buffer.write(' httpStatus=$httpStatus');
    }
    if (detail != null && detail.isNotEmpty) {
      buffer.write(' $detail');
    }
    if (error != null) {
      buffer.write(' error=$error');
    }
    final String line = buffer.toString();
    _summary.add(line);
    debugPrint(line);
  }

  void ok(String step, {String? detail}) {
    final String line = detail == null || detail.isEmpty
        ? '✓ $step'
        : '✓ $step $detail';
    _summary.add(line);
    debugPrint(line);
  }

  void fail(String step, {String? detail, Object? error, int? statusCode}) {
    final StringBuffer buffer = StringBuffer('✗ $step');
    if (statusCode != null) {
      buffer.write(' statusCode=$statusCode');
    }
    if (detail != null && detail.isNotEmpty) {
      buffer.write(' $detail');
    }
    if (error != null) {
      buffer.write(' error=$error');
    }
    final String line = buffer.toString();
    _summary.add(line);
    debugPrint(line);
  }

  void progress(double value) {
    if (value.isNaN || value.isInfinite) {
      return;
    }
    final int bucket = (value.clamp(0.0, 1.0) * 4).floor();
    if (bucket == _lastProgressBucket && value < 0.99) {
      return;
    }
    _lastProgressBucket = bucket;
    debugPrint('UPLOAD_PROGRESS ${(value * 100).toStringAsFixed(0)}%');
  }

  void end({bool abandoned = false, bool success = false}) {
    debugPrint('---------- PUBLISH #$publishId SUMMARY ----------');
    if (_summary.isEmpty) {
      debugPrint(abandoned ? '(abandoned)' : '(no steps recorded)');
    } else {
      for (final String line in _summary) {
        debugPrint(line);
      }
    }
    if (!abandoned) {
      debugPrint(success ? 'PUBLISH_RESULT success' : 'PUBLISH_RESULT failed');
    }
    debugPrint('========== END PUBLISH #$publishId ==========');
    if (identical(_active, this)) {
      _active = null;
    }
  }
}
