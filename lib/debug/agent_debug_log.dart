import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Debug-mode NDJSON ingest (session 7a372d). Safe: no secrets/PII.
void agentDebugLog({
  required String hypothesisId,
  required String location,
  required String message,
  Map<String, Object?> data = const <String, Object?>{},
  String runId = 'pre-fix',
}) {
  // #region agent log
  final Map<String, Object?> payload = <String, Object?>{
    'sessionId': '7a372d',
    'runId': runId,
    'hypothesisId': hypothesisId,
    'location': location,
    'message': message,
    'data': data,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  };
  debugPrint('AGENT_DEBUG ${jsonEncode(payload)}');
  unawaited(_postAgentDebugLog(payload));
  // #endregion
}

Future<void> _postAgentDebugLog(Map<String, Object?> payload) async {
  try {
    await http
        .post(
          Uri.parse(
            'http://127.0.0.1:7829/ingest/cccdfc25-62f2-46aa-9ff1-481dde0700b7',
          ),
          headers: const <String, String>{
            'Content-Type': 'application/json',
            'X-Debug-Session-Id': '7a372d',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(milliseconds: 800));
  } catch (_) {}
}
