import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'tippy_onboarding_contract.dart';
import 'tippy_profile_draft.dart';

class TippyOnboardingGuestSession {
  TippyOnboardingGuestSession({
    required this.schemaVersion,
    required this.sessionId,
    required this.stage,
    required this.questionIndex,
    required this.answers,
    required this.trialIntent,
    required this.notificationsChoice,
    required this.landingChoice,
    required this.updatedAt,
    required this.completedQuestionsAt,
    this.hasSeenTippyIntro = false,
    TippyProfileDraft? profileDraft,
  }) : profileDraft = profileDraft ?? TippyProfileDraft();

  final int schemaVersion;
  final String sessionId;
  final String stage;
  final int questionIndex;
  final Map<String, dynamic> answers;
  final bool trialIntent;
  final String? notificationsChoice;
  final String? landingChoice;
  final DateTime updatedAt;
  final DateTime? completedQuestionsAt;
  final bool hasSeenTippyIntro;
  final TippyProfileDraft profileDraft;

  factory TippyOnboardingGuestSession.empty() {
    return TippyOnboardingGuestSession(
      schemaVersion: kTippyOnboardingSessionSchemaVersion,
      sessionId: _createSessionId(),
      stage: TippyOnboardingStages.welcome,
      questionIndex: 0,
      answers: <String, dynamic>{},
      trialIntent: false,
      notificationsChoice: null,
      landingChoice: null,
      updatedAt: DateTime.now().toUtc(),
      completedQuestionsAt: null,
      hasSeenTippyIntro: false,
      profileDraft: TippyProfileDraft(),
    );
  }

  TippyOnboardingGuestSession copyWith({
    String? stage,
    int? questionIndex,
    Map<String, dynamic>? answers,
    bool? trialIntent,
    String? notificationsChoice,
    bool clearNotificationsChoice = false,
    String? landingChoice,
    bool clearLandingChoice = false,
    DateTime? completedQuestionsAt,
    bool clearCompletedQuestionsAt = false,
    bool? hasSeenTippyIntro,
    TippyProfileDraft? profileDraft,
  }) {
    return TippyOnboardingGuestSession(
      schemaVersion: schemaVersion,
      sessionId: sessionId,
      stage: stage ?? this.stage,
      questionIndex: questionIndex ?? this.questionIndex,
      answers: answers ?? Map<String, dynamic>.from(this.answers),
      trialIntent: trialIntent ?? this.trialIntent,
      notificationsChoice: clearNotificationsChoice
          ? null
          : (notificationsChoice ?? this.notificationsChoice),
      landingChoice: clearLandingChoice
          ? null
          : (landingChoice ?? this.landingChoice),
      updatedAt: DateTime.now().toUtc(),
      completedQuestionsAt: clearCompletedQuestionsAt
          ? null
          : (completedQuestionsAt ?? this.completedQuestionsAt),
      hasSeenTippyIntro: hasSeenTippyIntro ?? this.hasSeenTippyIntro,
      profileDraft: profileDraft ?? this.profileDraft,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'sessionId': sessionId,
      'stage': stage,
      'questionIndex': questionIndex,
      'answers': answers,
      'trialIntent': trialIntent,
      'notificationsChoice': notificationsChoice,
      'landingChoice': landingChoice,
      'updatedAt': updatedAt.toIso8601String(),
      'completedQuestionsAt': completedQuestionsAt?.toIso8601String(),
      'hasSeenTippyIntro': hasSeenTippyIntro,
      'profileDraft': profileDraft.toJson(),
    };
  }

  factory TippyOnboardingGuestSession.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> rawAnswers =
        (json['answers'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    return TippyOnboardingGuestSession(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ??
          kTippyOnboardingSessionSchemaVersion,
      sessionId: (json['sessionId'] as String?)?.trim().isNotEmpty == true
          ? json['sessionId'] as String
          : _createSessionId(),
      stage: TippyOnboardingStages.normalize(json['stage'] as String?),
      questionIndex: (json['questionIndex'] as num?)?.toInt() ?? 0,
      answers: rawAnswers,
      trialIntent: json['trialIntent'] == true,
      notificationsChoice: json['notificationsChoice'] as String?,
      landingChoice: json['landingChoice'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '')
              ?.toUtc() ??
          DateTime.now().toUtc(),
      completedQuestionsAt:
          DateTime.tryParse(json['completedQuestionsAt'] as String? ?? '')
              ?.toUtc(),
      hasSeenTippyIntro: json['hasSeenTippyIntro'] == true,
      profileDraft: TippyProfileDraft.fromJson(
        (json['profileDraft'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }

  /// Rewind to Meet Tippy without wiping answered questions.
  TippyOnboardingGuestSession forceMeetTippyIntro() {
    return copyWith(
      stage: TippyOnboardingStages.welcome,
      questionIndex: 0,
      hasSeenTippyIntro: false,
    );
  }

  bool get hasCompletedQuestions =>
      completedQuestionsAt != null &&
      answers.length >= kTippyOnboardingTotalQuestions;

  /// Incomplete local Tippy session that sat idle too long.
  bool isInactiveExpired({DateTime? now}) {
    if (landingChoice != null) {
      return false;
    }
    final DateTime reference = (now ?? DateTime.now()).toUtc();
    return reference.difference(updatedAt.toUtc()) >=
        kTippyOnboardingInactivityRestart;
  }

  static String _createSessionId() {
    final Random random = Random.secure();
    final String hex = List<String>.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return 'tos_$hex';
  }
}

class TippyOnboardingSessionStore {
  TippyOnboardingSessionStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<TippyOnboardingGuestSession> loadOrCreate() async {
    final TippyOnboardingGuestSession? existing = await load();
    if (existing != null) {
      if (existing.isInactiveExpired()) {
        await clear();
        final TippyOnboardingGuestSession restarted =
            TippyOnboardingGuestSession.empty();
        await save(restarted);
        return restarted;
      }
      return existing;
    }
    final TippyOnboardingGuestSession created =
        TippyOnboardingGuestSession.empty();
    await save(created);
    return created;
  }

  /// Loads a session only if it is still active; clears stale incomplete ones.
  Future<TippyOnboardingGuestSession?> loadActive() async {
    final TippyOnboardingGuestSession? existing = await load();
    if (existing == null) {
      return null;
    }
    if (existing.isInactiveExpired()) {
      await clear();
      return null;
    }
    return existing;
  }

  Future<TippyOnboardingGuestSession?> load() async {
    try {
      final String? raw =
          await _storage.read(key: kTippyOnboardingSessionStorageKey);
      if (raw == null || raw.trim().isEmpty) {
        return null;
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return TippyOnboardingGuestSession.fromJson(
        decoded.cast<String, dynamic>(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(TippyOnboardingGuestSession session) async {
    await _storage.write(
      key: kTippyOnboardingSessionStorageKey,
      value: jsonEncode(session.toJson()),
    );
  }

  Future<void> clear() async {
    await _storage.delete(key: kTippyOnboardingSessionStorageKey);
  }
}
