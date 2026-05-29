import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'sensitive_data_redactor.dart';

/// Drop-in replacement for [developer.log] that redacts sensitive data in
/// release builds.
void secureLog(
  String message, {
  int? level,
  Object? error,
  StackTrace? stackTrace,
  String? name,
}) {
  String output = message;
  if (name != null && name.isNotEmpty) {
    output = '[$name] $output';
  }
  if (error != null) {
    final String errText = '$error';
    output = '$output | Error: ${kReleaseMode ? SensitiveDataRedactor.redact(errText) : errText}';
  }
  if (stackTrace != null && kDebugMode) {
    output = '$output | Stack: $stackTrace';
  }
  if (kReleaseMode) {
    output = SensitiveDataRedactor.redact(output);
  }
  if (kDebugMode) {
    debugPrint(output);
    return;
  }
  developer.log(output, level: level ?? 0);
}
