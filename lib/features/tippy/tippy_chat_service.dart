import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class TippyChatService {
  TippyChatService({
    String? apiBase,
    http.Client? httpClient,
  })  : _apiBase = apiBase ?? _envApiBase,
        _client = httpClient ?? http.Client();

  static const String _envApiBase = String.fromEnvironment(
    'TIPPY_API_BASE',
    defaultValue: '',
  );

  final String _apiBase;
  final http.Client _client;

  bool get hasApiBase => _apiBase.trim().isNotEmpty;

  Future<TippyCreditsInfo> fetchCreditsInfo() async {
    final Map<String, dynamic> body = await _authedGet('/api/user/credits');
    final String greeting = body['greeting'] as String? ??
        body['personalizedGreeting'] as String? ??
        'Hey creator, what are we building today?';
    return TippyCreditsInfo(
      greeting: greeting,
      creditsRemaining: _readInt(
        body['creditsRemaining'] ?? body['credits'] ?? body['remaining'],
      ),
    );
  }

  Future<String?> fetchNudge() async {
    final Map<String, dynamic> body = await _authedGet('/api/tippy/nudge');
    final String? nudge = body['nudge'] as String?;
    if (nudge == null || nudge.trim().isEmpty) {
      return null;
    }
    return nudge.trim();
  }

  Future<TippyChatResult> sendMessage({
    required List<TippyChatMessage> messages,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'messages': messages
          .take(20)
          .map(
            (TippyChatMessage m) => <String, String>{
              'role': m.role,
              'content': m.content,
            },
          )
          .toList(growable: false),
    };
    final Map<String, dynamic> body = await _authedPost('/api/tippy', payload);
    final String? assistantText = body['message'] as String?;
    if (assistantText == null || assistantText.trim().isEmpty) {
      throw const TippyChatException('Tippy returned an empty response.');
    }
    return TippyChatResult(
      message: assistantText.trim(),
      creditsRemaining: body['creditsRemaining'] as int?,
    );
  }

  Future<TippyPlanResult> createPlan() async {
    final Map<String, dynamic> body = await _authedPost(
      '/api/tippy/create-plan',
      <String, dynamic>{},
    );
    final bool success = body['success'] as bool? ?? false;
    if (!success) {
      throw const TippyChatException('Failed to create content plan.');
    }
    return TippyPlanResult(planId: body['planId'] as String?);
  }

  Future<TippyCaptionResult> createCaption({required String prompt}) async {
    final Map<String, dynamic> body = await _authedPost(
      '/api/ai-caption',
      <String, dynamic>{'prompt': prompt},
    );
    final String caption = body['caption'] as String? ??
        body['bestCaption'] as String? ??
        body['message'] as String? ??
        '';
    final List<String> hashtags = _readStringList(
      body['hashtags'] ?? body['suggestedHashtags'],
    );
    final String title = body['title'] as String? ?? '';
    return TippyCaptionResult(
      caption: caption.trim(),
      hashtags: hashtags,
      title: title.trim().isEmpty ? null : title.trim(),
    );
  }

  Future<Map<String, dynamic>> _authedGet(String endpoint) async {
    final Uri uri = _buildUri(endpoint);
    final Map<String, String> headers = await _buildHeaders();
    final http.Response response = await _client.get(uri, headers: headers);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _authedPost(
    String endpoint,
    Map<String, dynamic> payload,
  ) async {
    final Uri uri = _buildUri(endpoint);
    final Map<String, String> headers = await _buildHeaders();
    final http.Response response = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode(payload),
    );
    return _handleResponse(response);
  }

  Uri _buildUri(String endpoint) {
    if (!hasApiBase) {
      throw const TippyChatException(
        'Missing TIPPY_API_BASE. Run with '
        '--dart-define=TIPPY_API_BASE=https://your-domain.com',
      );
    }
    final String cleanBase = _apiBase.replaceAll(RegExp(r'/$'), '');
    final String cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return Uri.parse('$cleanBase$cleanEndpoint');
  }

  Future<Map<String, String>> _buildHeaders() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? idToken = await user?.getIdToken();
    final Map<String, String> headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (idToken != null && idToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $idToken';
    }
    return headers;
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final Map<String, dynamic>? body = _tryDecodeMap(response.body);
    if (response.statusCode == 402) {
      throw TippyUpgradeRequiredException(
        body?['error'] as String? ?? 'Insufficient credits.',
      );
    }
    if (response.statusCode == 401) {
      throw TippyAuthException(
        body?['error'] as String? ??
            'Authentication required for more Tippy usage.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TippyChatException(
        body?['error'] as String? ??
            body?['message'] as String? ??
            'Tippy request failed (${response.statusCode}).',
      );
    }
    return body ?? <String, dynamic>{};
  }

  void dispose() {
    _client.close();
  }
}

class TippyChatMessage {
  const TippyChatMessage({
    required this.role,
    required this.content,
  });

  final String role;
  final String content;
}

class TippyChatResult {
  const TippyChatResult({
    required this.message,
    this.creditsRemaining,
  });

  final String message;
  final int? creditsRemaining;
}

class TippyCreditsInfo {
  const TippyCreditsInfo({
    required this.greeting,
    this.creditsRemaining,
  });

  final String greeting;
  final int? creditsRemaining;
}

class TippyPlanResult {
  const TippyPlanResult({this.planId});
  final String? planId;
}

class TippyCaptionResult {
  const TippyCaptionResult({
    required this.caption,
    this.hashtags = const <String>[],
    this.title,
  });

  final String caption;
  final List<String> hashtags;
  final String? title;
}

Map<String, dynamic>? _tryDecodeMap(String body) {
  try {
    final Object? decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return null;
  } on FormatException {
    return null;
  }
}

int? _readInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw);
  return null;
}

List<String> _readStringList(Object? raw) {
  if (raw is! List<dynamic>) {
    return const <String>[];
  }
  return raw.map((dynamic item) => item.toString()).toList(growable: false);
}

class TippyChatException implements Exception {
  const TippyChatException(this.message);
  final String message;

  @override
  String toString() => message;
}

class TippyAuthException extends TippyChatException {
  const TippyAuthException(super.message);
}

class TippyUpgradeRequiredException extends TippyChatException {
  const TippyUpgradeRequiredException(super.message);
}
