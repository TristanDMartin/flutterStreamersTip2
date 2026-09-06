import 'dart:io';

import 'package:flutter/foundation.dart';

/// Stage-by-stage camera/draft file size audits (session debug).
void logCameraFileAudit({
  required String stage,
  String? path,
  int? bytes,
  String? source,
  int? sourceBytes,
  String? destination,
  int? destinationBytes,
  Map<String, Object?> extra = const <String, Object?>{},
}) {
  final StringBuffer line = StringBuffer('CAMERA_FILE_AUDIT stage=$stage');
  if (path != null) {
    line.write(' path=$path');
  }
  if (bytes != null) {
    line.write(' bytes=$bytes');
  }
  if (source != null) {
    line.write(' source=$source');
  }
  if (sourceBytes != null) {
    line.write(' sourceBytes=$sourceBytes');
  }
  if (destination != null) {
    line.write(' destination=$destination');
  }
  if (destinationBytes != null) {
    line.write(' destinationBytes=$destinationBytes');
  }
  for (final MapEntry<String, Object?> entry in extra.entries) {
    line.write(' ${entry.key}=${entry.value}');
  }
  debugPrint(line.toString());
}

Future<int> fileByteLengthOrZero(File file) async {
  try {
    if (!await file.exists()) {
      return 0;
    }
    return await file.length();
  } catch (_) {
    return 0;
  }
}

/// Poll until size stops changing (camera finalization can lag the XFile return).
Future<int> waitForStableFileBytes(
  File file, {
  int polls = 8,
  Duration interval = const Duration(milliseconds: 120),
}) async {
  int last = -1;
  int stable = 0;
  for (int i = 0; i < polls; i++) {
    final int now = await fileByteLengthOrZero(file);
    if (now > 0 && now == last) {
      stable++;
      if (stable >= 2) {
        return now;
      }
    } else {
      stable = 0;
    }
    last = now;
    await Future<void>.delayed(interval);
  }
  return last < 0 ? 0 : last;
}
