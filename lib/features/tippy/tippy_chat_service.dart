import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:streamers_tip/utils/secure_log.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../core/app_check_http_headers.dart';
import '../../core/backend/firebase_https_function_url.dart';
import '../../core/backend/site_api_base.dart';
import '../../services/production_monitoring_service.dart';
import '../../services/performance_monitoring_service.dart';
import 'models/tippy_ui_payload.dart';

typedef TippyTokenProvider = Future<String?> Function();

class TippyChatService {
  TippyChatService({
    String? apiBase,
    http.Client? httpClient,
    TippyTokenProvider? tokenProvider,
    Duration requestTimeout = _defaultRequestTimeout,
  })  : _apiBase = resolveFirebaseHttpsFunctionUrl(
          explicitOverride: apiBase,
          envDefineValue: _envApiBase,
          functionName: _tippyHttpFunctionName,
          region: _functionsRegion,
        ),
        _client = httpClient ?? http.Client(),
        _tokenProvider = tokenProvider,
        _requestTimeout = requestTimeout {
    _validateConfiguration();
  }

  static const String _functionsRegion = 'us-central1';
  static const String _tippyHttpFunctionName = 'tippyApi';
  static const String _envApiBase = String.fromEnvironment(
    'TIPPY_API_BASE',
    defaultValue: '',
  );

  static const Duration _defaultRequestTimeout = Duration(seconds: 35);
  static const Set<String> _knownErrorCodes = <String>{
    'AUTH_REQUIRED',
    'TOKEN_EXPIRED',
    'INVALID_TOKEN',
    'INVALID_ARGUMENT',
    'INSUFFICIENT_CREDITS',
    'UPGRADE_REQUIRED',
    'CONTENT_PLAN_LIMIT',
    'RATE_LIMITED',
    'AI_PROVIDER_ERROR',
    'INTERNAL_ERROR',
    'SERVICE_UNAVAILABLE',
    'TIPPY_DISABLED',
    'CONSENT_REQUIRED',
    'APP_CHECK_REQUIRED',
    'APP_CHECK_INVALID',
  };

  final String _apiBase;
  final http.Client _client;
  final TippyTokenProvider? _tokenProvider;
  final Duration _requestTimeout;
  TippyCreditsInfo? _creditsCache;

  bool get hasApiBase => _apiBase.trim().isNotEmpty;
  bool get isStagingMode => _apiBase.toLowerCase().contains('staging');

  Future<TippyCreditsInfo> fetchCreditsInfo() async {
    if (_creditsCache != null) {
      return _creditsCache!;
    }
    const String fallbackGreeting = 'Hey creator, what are we building today?';
    try {
      final Map<String, String> headers = await _buildHeaders();
      final http.Response response = await _executeRequest(
        () => _client.get(
          Uri.parse(siteTippyCreditsUrl()),
          headers: headers,
        ),
      );
      final Map<String, dynamic>? body = _tryDecodeMap(response.body);
      if (body == null || response.statusCode >= 300) {
        return const TippyCreditsInfo(greeting: fallbackGreeting);
      }
      final TippyCreditsInfo info = TippyCreditsInfo(
        greeting: fallbackGreeting,
        creditsRemaining: _readInt(body['creditsRemaining']),
        tier: _readString(body['tier'] ?? body['effectiveTier']),
      );
      _creditsCache = info;
      return info;
    } on TippyAuthException {
      rethrow;
    } catch (_) {
      return const TippyCreditsInfo(greeting: fallbackGreeting);
    }
  }

  Future<String?> fetchNudge() async {
    final TippyCreditsInfo info = await fetchCreditsInfo();
    final String? nudge = info.nudge;
    if (nudge == null || nudge.trim().isEmpty) {
      return null;
    }
    return nudge.trim();
  }

  Future<TippyChatResult> sendMessage({
    required List<TippyChatMessage> messages,
    String? chatId,
    String? clientMessageId,
    String platform = 'android',
  }) async {
    final String text = messages.isEmpty ? '' : messages.last.content.trim();
    if (text.isEmpty) {
      throw const TippyChatException('Message is required.');
    }
    return sendPersistedMessage(
      message: text,
      chatId: chatId,
      clientMessageId: (clientMessageId != null && clientMessageId.trim().isNotEmpty)
          ? clientMessageId.trim()
          : 'flt_${DateTime.now().millisecondsSinceEpoch}_${text.hashCode}',
      platform: platform,
    );
  }

  /// Persisted Ask Tippy send — writes to `users/{uid}/tippyChats` on the server.
  Future<TippyChatResult> sendPersistedMessage({
    required String message,
    String? chatId,
    required String clientMessageId,
    String platform = 'android',
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    secureLog('frontend_send_persisted_click', name: 'TippyLatency');
    final Uri uri = Uri.parse(siteTippyChatUrl());
    final Map<String, String> headers = await _buildHeaders();
    final Map<String, dynamic> payload = <String, dynamic>{
      'message': message.trim(),
      'clientMessageId': clientMessageId,
      'platform': platform,
      if (chatId != null && chatId.trim().isNotEmpty) 'chatId': chatId.trim(),
    };
    final http.Response response = await _executeRequest(
      () => _client.post(
        uri,
        headers: headers,
        body: jsonEncode(payload),
      ),
    );
    PerformanceMonitoringService().trackNetworkRequest(
      '/api/tippy/chat',
      stopwatch.elapsed,
      statusCode: response.statusCode,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final Map<String, dynamic>? errBody = _tryDecodeMap(response.body);
      final String? errMsg = _readString(errBody?['error']);
      final String? errCode = _readString(errBody?['code']);
      final String? errDetail = _readString(errBody?['detail']);
      final String? errName = _readString(errBody?['errorName']);
      final String? requestId = _readString(errBody?['requestId']);
      secureLog(
        'frontend_send_persisted_failed status=${response.statusCode} '
        'code=${errCode ?? 'none'} error=${errMsg ?? 'none'} '
        'detail=${errDetail ?? 'none'} errorName=${errName ?? 'none'} '
        'requestId=${requestId ?? 'none'}',
        name: 'TippyLatency',
      );
    }
    final TippyChatResult result = _parseSiteChatResponse(response);
    _creditsCache = _creditsCache?.copyWith(
      creditsRemaining: result.creditsRemaining,
    );
    return result;
  }

  Future<String> createChat({
    String title = 'New chat',
    String platform = 'android',
  }) async {
    final Uri uri = Uri.parse(siteTippyChatsUrl());
    final Map<String, String> headers = await _buildHeaders();
    final http.Response response = await _executeRequest(
      () => _client.post(
        uri,
        headers: headers,
        body: jsonEncode(<String, dynamic>{
          'title': title,
          'platform': platform,
        }),
      ),
    );
    final Map<String, dynamic>? body = _tryDecodeMap(response.body);
    if (body == null || response.statusCode < 200 || response.statusCode >= 300) {
      throw TippyChatException(
        _readString(body?['error']) ?? 'Failed to create chat.',
        status: response.statusCode,
      );
    }
    final String? id = _readString(body['chatId']);
    if (id == null || id.isEmpty) {
      throw const TippyChatException('Failed to create chat.');
    }
    return id;
  }

  Future<void> renameChat({
    required String chatId,
    required String title,
  }) async {
    final Uri uri = Uri.parse(siteTippyChatByIdUrl(chatId));
    final Map<String, String> headers = await _buildHeaders();
    final http.Response response = await _executeRequest(
      () => _client.patch(
        uri,
        headers: headers,
        body: jsonEncode(<String, dynamic>{'title': title.trim()}),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final Map<String, dynamic>? body = _tryDecodeMap(response.body);
      throw TippyChatException(
        _readString(body?['error']) ?? 'Failed to rename chat.',
        status: response.statusCode,
      );
    }
  }

  Future<void> deleteChat({required String chatId}) async {
    final Uri uri = Uri.parse(siteTippyChatByIdUrl(chatId));
    final Map<String, String> headers = await _buildHeaders();
    final http.Response response = await _executeRequest(
      () => _client.delete(uri, headers: headers),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final Map<String, dynamic>? body = _tryDecodeMap(response.body);
      throw TippyChatException(
        _readString(body?['error']) ?? 'Failed to delete chat.',
        status: response.statusCode,
      );
    }
  }

  TippyChatResult _parseSiteChatResponse(http.Response response) {
    final Map<String, dynamic>? raw = _tryDecodeMap(response.body);
    if (raw == null) {
      throw TippyChatException(
        'Unexpected response format.',
        status: response.statusCode,
      );
    }
    final Map<String, dynamic> nestedError =
        raw['error'] is Map<String, dynamic>
            ? raw['error'] as Map<String, dynamic>
            : <String, dynamic>{};
    final Map<String, dynamic> data =
        raw['success'] == true && raw['data'] is Map<String, dynamic>
            ? <String, dynamic>{
                ...raw,
                ...Map<String, dynamic>.from(raw['data'] as Map),
              }
            : raw;
    final String? errorMessage = _readString(raw['error']) ??
        _readString(nestedError['message']) ??
        _readString(data['error']);
    final String? errorCode =
        _readString(nestedError['code']) ?? _readString(data['code']);
    final bool failed = raw['success'] == false ||
        response.statusCode < 200 ||
        response.statusCode >= 300;
    final String requestId = _readString(raw['requestId']) ??
        _readString(data['requestId']) ??
        '';
    if (failed) {
      if (response.statusCode == 401) {
        throw TippyAuthException(
          errorMessage ?? 'Authentication required.',
          code: errorCode ?? 'AUTH_REQUIRED',
          status: response.statusCode,
          requestId: requestId,
        );
      }
      if (response.statusCode == 402 || errorCode == 'INSUFFICIENT_CREDITS') {
        throw TippyUpgradeRequiredException(
          errorMessage ?? "You've used your Tippy credits.",
          code: errorCode ?? 'INSUFFICIENT_CREDITS',
          status: 402,
          requestId: requestId,
        );
      }
      final String baseMessage =
          errorMessage ?? 'Tippy request failed (${response.statusCode}).';
      throw TippyChatException(
        requestId.isEmpty ? baseMessage : '$baseMessage (ref: $requestId)',
        code: errorCode != null && _knownErrorCodes.contains(errorCode)
            ? errorCode
            : (errorCode == null ? 'INTERNAL_ERROR' : 'UNKNOWN_BACKEND_ERROR'),
        status: response.statusCode,
        requestId: requestId,
      );
    }
    final String? assistantText = _readString(data['message']) ??
        _readString(_readMap(data['assistantMessage'])?['content']) ??
        _readString(data['assistantMessage']);
    final String cleaned = _cleanPublicAiText(assistantText);
    if (cleaned.isEmpty) {
      throw const TippyChatException('Tippy returned an empty response.');
    }
    final int? creditsRemaining = _readInt(data['creditsRemaining']) ??
        _readInt(_readMap(data['credits'])?['remaining']);
    return TippyChatResult(
      message: cleaned,
      creditsRemaining: creditsRemaining,
      ui: TippyUiPayload.fromJson(data['ui']),
      chatId: _readString(data['chatId']),
    );
  }

  Future<TippyContextSnapshot> fetchContext() async {
    const String fallbackGreeting = 'Hey creator, what are we building today?';
    try {
      final Map<String, String> headers = await _buildHeaders();
      final http.Response response = await _executeRequest(
        () => _client.get(
          Uri.parse(siteTippyCreatorMemoryUrl()),
          headers: headers,
        ),
      );
      final Map<String, dynamic>? body = _tryDecodeMap(response.body);
      if (body == null || body['success'] != true) {
        return const TippyContextSnapshot(
          memoryReady: false,
          greeting: fallbackGreeting,
          ui: TippyUiPayload.empty,
        );
      }
      final Map<String, dynamic> memory =
          _readMap(body['memory']) ?? <String, dynamic>{};
      final Map<String, dynamic> identity =
          _readMap(memory['identity']) ?? <String, dynamic>{};
      final Map<String, dynamic> goals =
          _readMap(memory['goals']) ?? <String, dynamic>{};
      final String? niche = _readString(identity['niche']);
      final bool memoryReady =
          (niche ?? '').isNotEmpty || goals['goalIds'] != null;
      final TippyUiPayload parsedUi = TippyUiPayload.fromJson(body['ui']);
      final TippyContextStripData strip = parsedUi.contextStrip.hasContent
          ? parsedUi.contextStrip
          : TippyContextStripData(
              nicheLabel: niche,
              memoryReady: memoryReady,
            );
      return TippyContextSnapshot(
        memoryReady: memoryReady,
        greeting: fallbackGreeting,
        ui: TippyUiPayload(
          contextStrip: strip,
          cards: parsedUi.cards,
          suggestedPrompts: parsedUi.suggestedPrompts,
        ),
      );
    } catch (_) {
      return const TippyContextSnapshot(
        memoryReady: false,
        greeting: fallbackGreeting,
        ui: TippyUiPayload.empty,
      );
    }
  }

  Future<Map<String, dynamic>> saveCreatorGoal(
    Map<String, dynamic> payload,
  ) async {
    final TippySuccessEnvelope envelope = await _authedPost(
      '/tippy/goals',
      payload,
    );
    return envelope.data;
  }

  Future<TippyHookIdeasResult> fetchHookIdeas({required String prompt}) async {
    final TippySuccessEnvelope envelope = await _authedPost(
      '/tippy/hook-ideas',
      <String, dynamic>{
        'prompt': prompt,
        'messages': <Map<String, String>>[
          <String, String>{'role': 'user', 'content': prompt},
        ],
      },
    );
    return TippyHookIdeasResult(
      hooks: _readStringList(envelope.data['hooks']),
      message: _readString(envelope.data['message']),
      creditsRemaining: envelope.credits?.remaining,
    );
  }

  Future<TippyMissionResult> generateDailyMission() async {
    final TippySuccessEnvelope envelope = await _authedPost(
      '/tippy/generate-mission',
      <String, dynamic>{},
    );
    final Map<String, dynamic>? mission =
        envelope.data['mission'] is Map<String, dynamic>
            ? envelope.data['mission'] as Map<String, dynamic>
            : null;
    return TippyMissionResult(
      title: _readString(mission?['title']) ??
          _readString(envelope.data['message']) ??
          'Complete today\'s creator mission',
      description: _readString(mission?['description']),
      actionSurface: _readString(mission?['actionSurface']),
      creditsRemaining: envelope.credits?.remaining,
    );
  }

  Future<TippyScheduleProposalResult> proposeSchedule({
    required String prompt,
  }) async {
    throw const TippyChatException(
      'Schedule proposals from this screen are disabled. Ask Tippy in chat instead.',
    );
  }

  Future<void> approveScheduleProposal({required String proposalId}) async {
    throw const TippyChatException(
      'Legacy schedule approval is disabled. Confirm in Tippy chat instead.',
    );
  }

  Future<TippyPlanResult> startGrowthProgram() async {
    final TippySuccessEnvelope envelope = await _authedPost(
      '/tippy/growth-program',
      <String, dynamic>{},
    );
    _creditsCache = _creditsCache?.copyWith(
      creditsRemaining: envelope.credits?.remaining,
      tier: envelope.credits?.tier,
    );
    return TippyPlanResult(
      planId: _readString(envelope.data['planId']),
      itemCount: _readInt(envelope.data['itemCount']),
      message: _readString(envelope.data['message']),
      programId: _readString(envelope.data['programId']),
      creditsRemaining: envelope.credits?.remaining,
      ui: TippyUiPayload.fromJson(envelope.data['ui']),
    );
  }

  Future<TippyPlanResult> createPlan({
    required List<TippyChatMessage> messages,
    String? prompt,
  }) async {
    throw const TippyChatException(
      'Plan creation from this screen is disabled. Ask Tippy in chat instead.',
    );
  }

  Future<TippyCaptionResult> createCaption({required String prompt}) async {
    final TippySuccessEnvelope envelope = await _authedPost(
      '/tippy/ai-caption',
      <String, dynamic>{'prompt': prompt},
    );
    final String caption = _readString(
          envelope.data['caption'] ??
              envelope.data['bestCaption'] ??
              envelope.data['message'],
        ) ??
        '';
    final List<String> hashtags = _readStringList(
      envelope.data['hashtags'] ?? envelope.data['suggestedHashtags'],
    );
    final String title = _readString(envelope.data['title']) ?? '';
    _updateCreditsCache(envelope.credits);
    return TippyCaptionResult(
      caption: caption.trim(),
      hashtags: hashtags,
      title: title.trim().isEmpty ? null : title.trim(),
      creditsRemaining: envelope.credits?.remaining,
    );
  }

  Future<void> deletePromptHistory() async {
    await _authedPost('/tippy/delete-history', <String, dynamic>{});
  }

  Future<TippyAnalyzeContentResult> analyzeContent({
    required String content,
  }) async {
    final TippySuccessEnvelope envelope = await _authedPost(
      '/tippy/analyze-content',
      <String, dynamic>{'content': content},
    );
    _updateCreditsCache(envelope.credits);
    return TippyAnalyzeContentResult(
      summary: _readString(envelope.data['summary']) ?? '',
      actionItems: _readStringList(envelope.data['actionItems']),
      creditsRemaining: envelope.credits?.remaining,
      ui: TippyUiPayload.fromJson(envelope.data['ui']),
    );
  }

  Future<TippySuccessEnvelope> _authedPost(
    String endpoint,
    Map<String, dynamic> payload,
  ) async {
    final Uri uri = _buildUri(endpoint);
    final Map<String, String> headers = await _buildHeaders();
    final http.Response response = await _executeRequest(
      () => _client.post(
        uri,
        headers: headers,
        body: jsonEncode(payload),
      ),
    );
    return _parseEnvelope(response);
  }

  Uri _buildUri(String endpoint) {
    final String cleanBase = _apiBase.replaceAll(RegExp(r'/$'), '');
    final String cleanEndpoint =
        endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return Uri.parse('$cleanBase$cleanEndpoint');
  }

  Future<Map<String, String>> _buildHeaders() async {
    final String? idToken = await _resolveIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const TippyAuthException('Authentication required.');
    }
    return buildAuthenticatedHttpHeaders(
      idToken: idToken,
      extra: const <String, String>{'Content-Type': 'application/json'},
    );
  }

  Future<String?> _resolveIdToken() async {
    if (_tokenProvider != null) {
      return _tokenProvider!.call();
    }
    final User? user = FirebaseAuth.instance.currentUser;
    return user?.getIdToken(false);
  }

  TippySuccessEnvelope _parseEnvelope(http.Response response) {
    final Map<String, dynamic>? body = _tryDecodeMap(response.body);
    final String requestId = _readString(body?['requestId']) ?? '';
    if (body == null) {
      throw TippyChatException(
        'Unexpected response format.',
        code: 'INTERNAL_ERROR',
        status: response.statusCode,
        requestId: requestId,
      );
    }
    final bool isSuccess = body['success'] == true;
    if (isSuccess && response.statusCode >= 200 && response.statusCode < 300) {
      return TippySuccessEnvelope(
        data: _readMap(body['data']) ?? <String, dynamic>{},
        credits: _parseCredits(body['credits']),
        requestId: requestId,
      );
    }
    final Map<String, dynamic> error =
        _readMap(body['error']) ?? <String, dynamic>{};
    final String rawCode =
        _readString(error['code']) ?? 'UNKNOWN_BACKEND_ERROR';
    final bool isKnownCode = _knownErrorCodes.contains(rawCode);
    final String code = isKnownCode ? rawCode : 'UNKNOWN_BACKEND_ERROR';
    final String message = _readString(error['message']) ??
        'Tippy request failed (${response.statusCode}).';
    final int status = _readInt(error['status']) ?? response.statusCode;
    final bool retryable = error['retryable'] == true;
    if (!isKnownCode) {
      secureLog(
        'Unknown Tippy backend error code: $rawCode, requestId=$requestId',
        name: 'TippyChatService',
      );
    }
    if (status == 401) {
      if (code == 'APP_CHECK_REQUIRED' || code == 'APP_CHECK_INVALID') {
        ProductionMonitoringService.instance.recordAppCheckBlocked('tippy_http');
      }
      throw TippyAuthException(
        message,
        code: code,
        status: status,
        requestId: requestId,
        retryable: retryable,
      );
    }
    if (status == 402) {
      throw TippyUpgradeRequiredException(
        message,
        code: code,
        status: status,
        requestId: requestId,
        retryable: retryable,
      );
    }
    throw TippyChatException(
      message,
      code: code,
      status: status,
      requestId: requestId,
      retryable: retryable,
    );
  }

  void dispose() {
    _client.close();
  }

  void _updateCreditsCache(TippyCreditsSnapshot? credits) {
    if (credits == null) {
      return;
    }
    _creditsCache = _creditsCache?.copyWith(
      creditsRemaining: credits.remaining,
      tier: credits.tier,
    );
  }

  void _validateConfiguration() {
    if (!hasApiBase) {
      throw const TippyChatException(
        'Tippy API URL is not configured. Use Firebase with a projectId, or '
        'pass --dart-define=TIPPY_API_BASE=https://REGION-PROJECT.'
        'cloudfunctions.net/tippyApi',
        code: 'INTERNAL_ERROR',
        status: 500,
      );
    }
  }

  Future<http.Response> _executeRequest(
    Future<http.Response> Function() request, {
    int maxAttempts = 3,
  }) async {
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        final http.Response response =
            await request().timeout(_requestTimeout);
        final bool isRetryableStatus =
            response.statusCode == 502 || response.statusCode == 503;
        if (isRetryableStatus && attempt < maxAttempts) {
          await Future<void>.delayed(
            Duration(milliseconds: 400 * attempt),
          );
          continue;
        }
        return response;
      } on SocketException {
        if (attempt >= maxAttempts) {
          throw const TippyNetworkException();
        }
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      } on TimeoutException {
        if (attempt >= maxAttempts) {
          throw const TippyNetworkException(message: 'Request timed out.');
        }
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
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
    this.ui = TippyUiPayload.empty,
    this.chatId,
  });

  final String message;
  final int? creditsRemaining;
  final TippyUiPayload ui;
  final String? chatId;
}

class TippyContextSnapshot {
  const TippyContextSnapshot({
    required this.memoryReady,
    required this.greeting,
    required this.ui,
  });

  final bool memoryReady;
  final String greeting;
  final TippyUiPayload ui;

  factory TippyContextSnapshot.fromMap(Map<String, dynamic> data) {
    return TippyContextSnapshot(
      memoryReady: data['memoryReady'] == true,
      greeting: _readString(data['greeting']) ??
          'Hey creator, what are we building today?',
      ui: TippyUiPayload.fromJson(data['ui']),
    );
  }
}

class TippyHookIdeasResult {
  const TippyHookIdeasResult({
    required this.hooks,
    this.message,
    this.creditsRemaining,
  });

  final List<String> hooks;
  final String? message;
  final int? creditsRemaining;
}

class TippyMissionResult {
  const TippyMissionResult({
    required this.title,
    this.description,
    this.actionSurface,
    this.creditsRemaining,
  });

  final String title;
  final String? description;
  final String? actionSurface;
  final int? creditsRemaining;
}

class TippyScheduleProposalResult {
  const TippyScheduleProposalResult({
    required this.proposals,
    this.message,
    this.ui = TippyUiPayload.empty,
    this.creditsRemaining,
  });

  final List<Map<String, dynamic>> proposals;
  final String? message;
  final TippyUiPayload ui;
  final int? creditsRemaining;
}

class TippyCreditsInfo {
  const TippyCreditsInfo({
    required this.greeting,
    this.creditsRemaining,
    this.tier,
    this.nudge,
    this.memoryReady = false,
  });

  final String greeting;
  final int? creditsRemaining;
  final String? tier;
  final String? nudge;
  final bool memoryReady;

  TippyCreditsInfo copyWith({
    String? greeting,
    int? creditsRemaining,
    String? tier,
    String? nudge,
    bool? memoryReady,
  }) {
    return TippyCreditsInfo(
      greeting: greeting ?? this.greeting,
      creditsRemaining: creditsRemaining ?? this.creditsRemaining,
      tier: tier ?? this.tier,
      nudge: nudge ?? this.nudge,
      memoryReady: memoryReady ?? this.memoryReady,
    );
  }
}

class TippyPlanResult {
  const TippyPlanResult({
    this.planId,
    this.itemCount,
    this.message,
    this.programId,
    this.creditsRemaining,
    this.ui = TippyUiPayload.empty,
  });
  final String? planId;
  final int? itemCount;
  final String? message;
  final String? programId;
  final int? creditsRemaining;
  final TippyUiPayload ui;
}

class TippyCaptionResult {
  const TippyCaptionResult({
    required this.caption,
    this.hashtags = const <String>[],
    this.title,
    this.creditsRemaining,
  });

  final String caption;
  final List<String> hashtags;
  final String? title;
  final int? creditsRemaining;
}

class TippyAnalyzeContentResult {
  const TippyAnalyzeContentResult({
    required this.summary,
    required this.actionItems,
    this.creditsRemaining,
    this.ui = TippyUiPayload.empty,
  });

  final String summary;
  final List<String> actionItems;
  final int? creditsRemaining;
  final TippyUiPayload ui;
}

class TippySuccessEnvelope {
  const TippySuccessEnvelope({
    required this.data,
    required this.requestId,
    this.credits,
  });

  final Map<String, dynamic> data;
  final TippyCreditsSnapshot? credits;
  final String requestId;
}

class TippyCreditsSnapshot {
  const TippyCreditsSnapshot({
    required this.remaining,
    required this.used,
    required this.limit,
    required this.tier,
  });

  final int remaining;
  final int used;
  final int limit;
  final String tier;
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

String? _readString(Object? raw) {
  if (raw is String) {
    return raw;
  }
  return null;
}

String _cleanPublicAiText(String? raw) {
  final List<String> lines = (raw ?? '').split(RegExp(r'\r?\n'));
  final RegExp metadataLine = RegExp(
    r'^\s*(model|provider|system|assistant)\s*:\s*[-\w.]+\s*$',
    caseSensitive: false,
  );
  while (lines.isNotEmpty && metadataLine.hasMatch(lines.first)) {
    lines.removeAt(0);
  }
  return lines.join('\n').trim();
}

Map<String, dynamic>? _readMap(Object? raw) {
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  return null;
}

TippyCreditsSnapshot? _parseCredits(Object? raw) {
  final Map<String, dynamic>? credits = _readMap(raw);
  if (credits == null) {
    return null;
  }
  final int? remaining = _readInt(credits['remaining']);
  final int? used = _readInt(credits['used']);
  final int? limit = _readInt(credits['limit']);
  final String? tier = _readString(credits['tier']);
  if (remaining == null || used == null || limit == null || tier == null) {
    return null;
  }
  return TippyCreditsSnapshot(
    remaining: remaining,
    used: used,
    limit: limit,
    tier: tier,
  );
}

List<String> _readStringList(Object? raw) {
  if (raw is! List<dynamic>) {
    return const <String>[];
  }
  return raw.map((dynamic item) => item.toString()).toList(growable: false);
}

class TippyChatException implements Exception {
  const TippyChatException(
    this.message, {
    this.code = 'INTERNAL_ERROR',
    this.status = 500,
    this.retryable = false,
    this.requestId = '',
  });
  final String message;
  final String code;
  final int status;
  final bool retryable;
  final String requestId;

  @override
  String toString() => '[$code] $message';
}

class TippyAuthException extends TippyChatException {
  const TippyAuthException(
    super.message, {
    super.code = 'AUTH_REQUIRED',
    super.status = 401,
    super.retryable = false,
    super.requestId = '',
  });
}

class TippyUpgradeRequiredException extends TippyChatException {
  const TippyUpgradeRequiredException(
    super.message, {
    super.code = 'INSUFFICIENT_CREDITS',
    super.status = 402,
    super.retryable = false,
    super.requestId = '',
  });
}

class TippyNetworkException extends TippyChatException {
  const TippyNetworkException({
    String message = 'Network unavailable. Please try again.',
  }) : super(
          message,
          code: 'SERVICE_UNAVAILABLE',
          status: 503,
          retryable: true,
        );
}
