import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../core/app_check_http_headers.dart';
import '../../core/backend/site_api_base.dart';

class CompleteOnboardingException implements Exception {
  const CompleteOnboardingException({
    required this.stage,
    required this.code,
    required this.message,
  });

  final String stage;
  final String code;
  final String message;

  @override
  String toString() => '$message ($stage)';
}

class CompleteOnboardingResult {
  const CompleteOnboardingResult({
    required this.username,
    required this.displayName,
    required this.profileUrl,
    required this.alreadyComplete,
    this.activationState,
    this.nextStage,
    this.tippyStageHint,
    this.allowApp = false,
  });

  final String username;
  final String displayName;
  final String profileUrl;
  final bool alreadyComplete;
  final String? activationState;
  final String? nextStage;
  final String? tippyStageHint;
  final bool allowApp;
}

Future<CompleteOnboardingResult> completeOnboarding({
  String? username,
  String? displayName,
  String? bio,
  String? avatarUrl,
  bool skippedAvatar = false,
  List<Map<String, String?>>? platforms,
  List<String>? platformIds,
  List<String>? categoryIds,
  Map<String, dynamic>? answers,
  String? sessionId,
  bool allowUsernameChange = false,
  bool startedFromWelcome = false,
  bool finalize = true,
}) async {
  final User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw const CompleteOnboardingException(
      stage: 'AUTH',
      code: 'AUTH_REQUIRED',
      message: 'Sign in to finish setting up your profile.',
    );
  }
  final String idToken = await user.getIdToken(true) ?? '';
  final Map<String, String> headers = await buildAuthenticatedHttpHeaders(
    idToken: idToken,
    extra: const <String, String>{'Content-Type': 'application/json'},
  );
  final http.Response response = await http.post(
    Uri.parse(siteOnboardingCompleteUrl()),
    headers: headers,
    body: jsonEncode(<String, dynamic>{
      if (username != null) 'username': username,
      if (displayName != null) 'displayName': displayName,
      if (bio != null) 'bio': bio,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'skippedAvatar': skippedAvatar,
      if (platforms != null) 'platforms': platforms,
      if (platformIds != null) 'platformIds': platformIds,
      if (categoryIds != null) 'categoryIds': categoryIds,
      if (answers != null) 'answers': answers,
      if (sessionId != null) 'sessionId': sessionId,
      'allowUsernameChange': allowUsernameChange,
      'startedFromWelcome': startedFromWelcome,
      'finalize': finalize,
      'platform': 'mobile',
    }),
  );
  Map<String, dynamic> data = <String, dynamic>{};
  try {
    final Object? parsed = jsonDecode(response.body);
    if (parsed is Map) {
      data = parsed.cast<String, dynamic>();
    }
  } catch (_) {}
  if (response.statusCode < 200 ||
      response.statusCode >= 300 ||
      data['ok'] != true) {
    throw CompleteOnboardingException(
      stage: (data['stage'] as String?) ?? 'DONE',
      code: (data['code'] as String?) ?? 'PROFILE_FINALIZE_FAILED',
      message: (data['message'] as String?) ??
          'Could not finish creating your profile. Please try again.',
    );
  }
  final Map<String, dynamic> card =
      (data['creatorCard'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
  return CompleteOnboardingResult(
    username: (data['username'] as String?) ??
        (card['username'] as String?) ??
        username ??
        '',
    displayName: (card['displayName'] as String?) ?? displayName ?? '',
    profileUrl: (card['profileUrl'] as String?) ?? '',
    alreadyComplete: data['alreadyComplete'] == true,
    activationState: data['activationState'] as String?,
    nextStage: data['nextStage'] as String?,
    tippyStageHint: data['tippyStageHint'] as String?,
    allowApp: data['allowApp'] == true,
  );
}
