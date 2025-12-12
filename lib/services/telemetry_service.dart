import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Lightweight telemetry logger; posts to TELEMETRY_WEBHOOK_URL if set
/// (can be passed via --dart-define or environment), else logs locally.
class TelemetryService {
  TelemetryService._();

  static const String _webhook =
      String.fromEnvironment('TELEMETRY_WEBHOOK_URL', defaultValue: '');

  static Future<void> logEvent(
    String eventType, {
    Map<String, Object?> payload = const {},
  }) async {
    final body = {
      'eventType': eventType,
      'payload': payload,
      'source': 'flutter_client',
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (_webhook.isEmpty) {
      if (kDebugMode) {
        debugPrint('[telemetry] ${jsonEncode(body)}');
      }
      return;
    }

    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 2);
      final uri = Uri.parse(_webhook);
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.write(jsonEncode(body));
      await request.close();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ telemetry post failed: $e');
      }
    }
  }
}
