import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tippy_onboarding_contract.dart';
import 'tippy_profile_draft.dart';

List<Map<String, String>> _parseCheckupProfiles(Object? raw) {
  if (raw is! List<dynamic>) {
    return const <Map<String, String>>[];
  }
  final List<Map<String, String>> out = <Map<String, String>>[];
  for (final Object? row in raw) {
    if (row is! Map) {
      continue;
    }
    final String platform = '${row['platform'] ?? ''}'.trim();
    final String handle = '${row['handleOrUrl'] ?? row['profileUrl'] ?? ''}'
        .trim();
    if (platform.isEmpty || handle.isEmpty) {
      continue;
    }
    out.add(<String, String>{
      'platform': platform,
      'handleOrUrl': handle,
    });
  }
  return out;
}

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
    this.firstMissionChoice,
    required this.updatedAt,
    required this.completedQuestionsAt,
    this.hasSeenTippyIntro = false,
    this.startedFromCheckup = false,
    this.checkupSessionId,
    this.checkupIntention,
    this.checkupProfiles = const <Map<String, String>>[],
    this.checkupSuggestedAnswers = const <String, dynamic>{},
    this.checkupConfirmedAnswers = const <String, dynamic>{},
    this.checkupHandoffConfirmResolved = false,
    this.checkupPresenceSummary,
    this.twitchConnectionStatus,
    DateTime? startedAt,
    this.firstResultAt,
    TippyProfileDraft? profileDraft,
  })  : profileDraft = profileDraft ?? TippyProfileDraft(),
        startedAt = startedAt ?? updatedAt;

  final int schemaVersion;
  final String sessionId;
  final String stage;
  final int questionIndex;
  final Map<String, dynamic> answers;
  final bool trialIntent;
  final String? notificationsChoice;
  final String? landingChoice;
  final String? firstMissionChoice;
  final DateTime updatedAt;
  final DateTime? completedQuestionsAt;
  final bool hasSeenTippyIntro;
  final bool startedFromCheckup;
  final String? checkupSessionId;
  final String? checkupIntention;
  final List<Map<String, String>> checkupProfiles;
  final Map<String, dynamic> checkupSuggestedAnswers;
  final Map<String, dynamic> checkupConfirmedAnswers;
  final bool checkupHandoffConfirmResolved;
  final String? checkupPresenceSummary;
  /// SKIPPED | CONNECTED — Tippy Twitch OAuth, not platform handles.
  final String? twitchConnectionStatus;
  final DateTime startedAt;
  final DateTime? firstResultAt;
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
      firstMissionChoice: null,
      twitchConnectionStatus: null,
      updatedAt: DateTime.now().toUtc(),
      completedQuestionsAt: null,
      hasSeenTippyIntro: false,
      startedAt: DateTime.now().toUtc(),
      firstResultAt: null,
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
    String? firstMissionChoice,
    bool clearFirstMissionChoice = false,
    String? twitchConnectionStatus,
    bool clearTwitchConnectionStatus = false,
    DateTime? completedQuestionsAt,
    bool clearCompletedQuestionsAt = false,
    bool? hasSeenTippyIntro,
    bool? startedFromCheckup,
    String? checkupSessionId,
    bool clearCheckupSessionId = false,
    String? checkupIntention,
    bool clearCheckupIntention = false,
    List<Map<String, String>>? checkupProfiles,
    Map<String, dynamic>? checkupSuggestedAnswers,
    Map<String, dynamic>? checkupConfirmedAnswers,
    bool? checkupHandoffConfirmResolved,
    String? checkupPresenceSummary,
    bool clearCheckupPresenceSummary = false,
    DateTime? startedAt,
    DateTime? firstResultAt,
    bool clearFirstResultAt = false,
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
      firstMissionChoice: clearFirstMissionChoice
          ? null
          : (firstMissionChoice ?? this.firstMissionChoice),
      twitchConnectionStatus: clearTwitchConnectionStatus
          ? null
          : (twitchConnectionStatus ?? this.twitchConnectionStatus),
      updatedAt: DateTime.now().toUtc(),
      completedQuestionsAt: clearCompletedQuestionsAt
          ? null
          : (completedQuestionsAt ?? this.completedQuestionsAt),
      hasSeenTippyIntro: hasSeenTippyIntro ?? this.hasSeenTippyIntro,
      startedFromCheckup: startedFromCheckup ?? this.startedFromCheckup,
      checkupSessionId: clearCheckupSessionId
          ? null
          : (checkupSessionId ?? this.checkupSessionId),
      checkupIntention: clearCheckupIntention
          ? null
          : (checkupIntention ?? this.checkupIntention),
      checkupProfiles: checkupProfiles ?? this.checkupProfiles,
      checkupSuggestedAnswers:
          checkupSuggestedAnswers ?? this.checkupSuggestedAnswers,
      checkupConfirmedAnswers:
          checkupConfirmedAnswers ?? this.checkupConfirmedAnswers,
      checkupHandoffConfirmResolved:
          checkupHandoffConfirmResolved ?? this.checkupHandoffConfirmResolved,
      checkupPresenceSummary: clearCheckupPresenceSummary
          ? null
          : (checkupPresenceSummary ?? this.checkupPresenceSummary),
      startedAt: startedAt ?? this.startedAt,
      firstResultAt: clearFirstResultAt
          ? null
          : (firstResultAt ?? this.firstResultAt),
      profileDraft: profileDraft ?? this.profileDraft,
    );
  }

  TippyOnboardingGuestSession withReservedUsername(String? username) {
    return copyWith(profileDraft: profileDraft.withReservedUsername(username));
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
      'firstMissionChoice': firstMissionChoice,
      'twitchConnectionStatus': twitchConnectionStatus,
      'updatedAt': updatedAt.toIso8601String(),
      'completedQuestionsAt': completedQuestionsAt?.toIso8601String(),
      'hasSeenTippyIntro': hasSeenTippyIntro,
      'startedFromCheckup': startedFromCheckup,
      'checkupSessionId': checkupSessionId,
      'checkupIntention': checkupIntention,
      'checkupProfiles': checkupProfiles,
      'checkupSuggestedAnswers': checkupSuggestedAnswers,
      'checkupConfirmedAnswers': checkupConfirmedAnswers,
      'checkupHandoffConfirmResolved': checkupHandoffConfirmResolved,
      'checkupPresenceSummary': checkupPresenceSummary,
      'startedAt': startedAt.toIso8601String(),
      'firstResultAt': firstResultAt?.toIso8601String(),
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
      firstMissionChoice: json['firstMissionChoice'] as String?,
      twitchConnectionStatus: json['twitchConnectionStatus'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '')
              ?.toUtc() ??
          DateTime.now().toUtc(),
      completedQuestionsAt:
          DateTime.tryParse(json['completedQuestionsAt'] as String? ?? '')
              ?.toUtc(),
      hasSeenTippyIntro: json['hasSeenTippyIntro'] == true,
      startedFromCheckup: json['startedFromCheckup'] == true,
      checkupSessionId: json['checkupSessionId'] as String?,
      checkupIntention: json['checkupIntention'] as String?,
      checkupProfiles: _parseCheckupProfiles(json['checkupProfiles']),
      checkupSuggestedAnswers:
          (json['checkupSuggestedAnswers'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{},
      checkupConfirmedAnswers:
          (json['checkupConfirmedAnswers'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{},
      checkupHandoffConfirmResolved:
          json['checkupHandoffConfirmResolved'] == true,
      checkupPresenceSummary: json['checkupPresenceSummary'] as String?,
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '')
              ?.toUtc() ??
          DateTime.tryParse(json['updatedAt'] as String? ?? '')?.toUtc(),
      firstResultAt:
          DateTime.tryParse(json['firstResultAt'] as String? ?? '')?.toUtc(),
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

  /// True when the user has answered at least one DNA question.
  bool get hasMeaningfulProgress =>
      answers.isNotEmpty || questionIndex > 0 || hasCompletedQuestions;

  /// Idle wipe disabled — always resume exact step until complete.
  bool isInactiveExpired({DateTime? now}) => false;

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
  }) : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;
  static TippyOnboardingGuestSession? _cached;

  Future<TippyOnboardingGuestSession> loadOrCreate() async {
    final TippyOnboardingGuestSession? existing = await load();
    if (existing != null) {
      return existing;
    }
    final TippyOnboardingGuestSession created =
        TippyOnboardingGuestSession.empty();
    await save(created);
    return created;
  }

  /// Loads any persisted session (progress is never wiped by idle timeout).
  Future<TippyOnboardingGuestSession?> loadActive() async {
    return load();
  }

  Future<TippyOnboardingGuestSession?> load() async {
    if (await _consumeForceFreshFlag()) {
      await clear();
      return null;
    }
    TippyOnboardingGuestSession? session = _cached ??
        await _loadFromPrefs() ??
        await _loadFromSecure();
    if (session == null) {
      return null;
    }
    _cached = session;
    unawaited(_writePrefs(session));
    final String? floor = await peekSignupClosedFloor();
    final String stage = TippyOnboardingStages.clampVisibleStage(
      storedStage: session.stage,
      floor: floor,
    );
    if (stage == session.stage) {
      return session;
    }
    return session.copyWith(stage: stage);
  }

  Future<({String? stage, String? uid, String? username})>
      _readSignupClosedFloor() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(kTippySignupClosedFloorKey);
      if (raw == null || raw.trim().isEmpty) {
        return (stage: null, uid: null, username: null);
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return (
          stage: TippyOnboardingStages.verifyEmail,
          uid: null,
          username: null,
        );
      }
      final Object? stageRaw = decoded['stage'];
      final Object? uidRaw = decoded['uid'];
      final Object? usernameRaw = decoded['username'];
      final String? uid =
          uidRaw is String && uidRaw.trim().isNotEmpty ? uidRaw.trim() : null;
      final String? username = usernameRaw is String &&
              usernameRaw.trim().isNotEmpty
          ? tippyIdentityFromUsername(usernameRaw).username
          : null;
      if (stageRaw is String && stageRaw.trim().isNotEmpty) {
        return (
          stage: TippyOnboardingStages.normalize(stageRaw),
          uid: uid,
          username: username,
        );
      }
      return (
        stage: TippyOnboardingStages.verifyEmail,
        uid: uid,
        username: username,
      );
    } catch (_) {
      return (stage: null, uid: null, username: null);
    }
  }

  Future<String?> peekSignupClosedFloor() async {
    return (await _readSignupClosedFloor()).stage;
  }

  Future<String?> peekSignupClosedFloorUid() async {
    return (await _readSignupClosedFloor()).uid;
  }

  Future<void> persistReservedSignupUsername({
    required String uid,
    required String username,
  }) async {
    final String handle = tippyIdentityFromUsername(username).username;
    if (uid.trim().isEmpty || handle.isEmpty) {
      return;
    }
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        kTippyReservedSignupUsernameKey,
        jsonEncode(<String, String>{
          'uid': uid.trim(),
          'username': handle,
        }),
      );
    } catch (_) {}
  }

  Future<String?> peekReservedSignupUsername({String? uid}) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(kTippyReservedSignupUsernameKey);
      if (raw == null || raw.trim().isEmpty) {
        return null;
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final String storedUid = (decoded['uid'] as String? ?? '').trim();
      final String handle = tippyIdentityFromUsername(
        decoded['username'] as String? ?? '',
      ).username;
      if (handle.isEmpty) {
        return null;
      }
      final String wanted = (uid ?? '').trim();
      if (wanted.isNotEmpty && storedUid.isNotEmpty && storedUid != wanted) {
        return null;
      }
      return handle;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearReservedSignupUsername() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(kTippyReservedSignupUsernameKey);
    } catch (_) {}
  }

  Future<String?> peekSignupUsername({String? uid}) async {
    final ({String? stage, String? uid, String? username}) floor =
        await _readSignupClosedFloor();
    if (floor.username != null && floor.username!.isNotEmpty) {
      return floor.username;
    }
    final String? durable = await peekReservedSignupUsername(
      uid: uid ?? floor.uid,
    );
    if (durable != null && durable.isNotEmpty) {
      return durable;
    }
    final String cached = tippyIdentityFromUsername(
      _cached?.profileDraft.username ?? '',
    ).username;
    if (cached.isNotEmpty) {
      return cached;
    }
    final TippyOnboardingGuestSession? stored = await _loadFromPrefs();
    final String draft = tippyIdentityFromUsername(
      stored?.profileDraft.username ?? '',
    ).username;
    return draft.isEmpty ? null : draft;
  }

  Future<void> persistSignupClosedFloor({
    required String uid,
    String? username,
  }) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(kTippyVerifyFloorReleasedKey);
      final String requested = tippyIdentityFromUsername(username ?? '').username;
      final String handle = requested.isNotEmpty
          ? requested
          : ((await _readSignupClosedFloor()).username ?? '');
      await prefs.setString(
        kTippySignupClosedFloorKey,
        jsonEncode(<String, String>{
          'uid': uid,
          'stage': TippyOnboardingStages.verifyEmail,
          if (handle.isNotEmpty) 'username': handle,
        }),
      );
      if (handle.isNotEmpty) {
        await persistReservedSignupUsername(uid: uid, username: handle);
      }
    } catch (_) {}
  }

  /// Web `persistSignupClosedAtVerifyEmail` — call immediately after createUser
  /// so a shell remount cannot reopen the account-creation CTA.
  Future<void> lockSignupAtVerifyEmail({
    required String uid,
    String? username,
  }) async {
    await persistSignupClosedFloor(uid: uid, username: username);
    final TippyOnboardingGuestSession? session = await load();
    if (session == null) {
      return;
    }
    final String handle = tippyIdentityFromUsername(username ?? '').username;
    TippyOnboardingGuestSession next = session;
    if (handle.isNotEmpty) {
      final TippyProfileDraft draft = session.profileDraft;
      next = session.copyWith(
        profileDraft: draft.copyWith(
          username: handle,
          displayName: draft.displayName.trim().isNotEmpty
              ? draft.displayName
              : handle,
        ),
      );
    }
    if (!TippyOnboardingStages.isAtOrAfter(
      next.stage,
      TippyOnboardingStages.verifyEmail,
    )) {
      next = next.copyWith(stage: TippyOnboardingStages.verifyEmail);
    }
    await save(next);
  }

  Future<void> clearSignupClosedFloor() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(kTippySignupClosedFloorKey);
    } catch (_) {}
  }

  Future<void> persistVerifyFloorReleased() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kTippyVerifyFloorReleasedKey, true);
      await prefs.remove(kTippySignupClosedFloorKey);
    } catch (_) {}
  }

  Future<bool> peekVerifyFloorReleased() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool(kTippyVerifyFloorReleasedKey) == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> clearVerifyFloorReleased() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(kTippyVerifyFloorReleasedKey);
    } catch (_) {}
  }

  Future<void> save(TippyOnboardingGuestSession session) async {
    final String? floor = await peekSignupClosedFloor();
    final String stage = TippyOnboardingStages.clampVisibleStage(
      storedStage: session.stage,
      floor: floor,
    );
    final String incoming = tippyIdentityFromUsername(
      session.profileDraft.username,
    ).username;
    final String reserved = incoming.isNotEmpty
        ? incoming
        : (await peekSignupUsername() ?? '');
    final TippyOnboardingGuestSession staged =
        stage == session.stage ? session : session.copyWith(stage: stage);
    final TippyOnboardingGuestSession floored =
        staged.withReservedUsername(reserved);
    _cached = floored;
    final String encoded = jsonEncode(floored.toJson());
    await _writePrefs(floored, encoded: encoded);
    try {
      await _storage.write(
        key: kTippyOnboardingSessionStorageKey,
        value: encoded,
      );
    } catch (_) {}
  }

  Future<void> clear() async {
    _cached = null;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(kTippyOnboardingSessionStorageKey);
      await prefs.remove(kTippyOnboardingV1SessionStorageKey);
    } catch (_) {}
    try {
      await _storage.delete(key: kTippyOnboardingSessionStorageKey);
    } catch (_) {}
    try {
      await _storage.delete(key: kTippyOnboardingV1SessionStorageKey);
    } catch (_) {}
  }

  Future<TippyOnboardingGuestSession?> _loadFromPrefs() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return _sessionFromRaw(
        prefs.getString(kTippyOnboardingSessionStorageKey) ??
            prefs.getString(kTippyOnboardingV1SessionStorageKey),
      );
    } catch (_) {
      return null;
    }
  }

  Future<TippyOnboardingGuestSession?> _loadFromSecure() async {
    try {
      return _sessionFromRaw(
        await _storage.read(key: kTippyOnboardingSessionStorageKey) ??
            await _storage.read(key: kTippyOnboardingV1SessionStorageKey),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writePrefs(
    TippyOnboardingGuestSession session, {
    String? encoded,
  }) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        kTippyOnboardingSessionStorageKey,
        encoded ?? jsonEncode(session.toJson()),
      );
    } catch (_) {}
  }

  static TippyOnboardingGuestSession? _sessionFromRaw(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
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

  /// Hard rule: deleted accounts must never resume prior Tippy progress.
  Future<void> invalidateAfterAccountDeletion() async {
    await clear();
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kTippyForceFreshAfterAccountDeletionKey, true);
      await prefs.setBool(kTippyStartedFromWelcomeAfterDeletionKey, true);
      await prefs.remove(kTippySignupClosedFloorKey);
      await prefs.remove(kTippyReservedSignupUsernameKey);
      await prefs.remove(kTippyVerifyFloorReleasedKey);
    } catch (_) {}
  }

  Future<bool> peekForceFreshAfterAccountDeletion() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool(kTippyForceFreshAfterAccountDeletionKey) == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> markStartedFromWelcome() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kTippyStartedFromWelcomeAfterDeletionKey, true);
    } catch (_) {}
  }

  Future<bool> peekStartedFromWelcome() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool(kTippyStartedFromWelcomeAfterDeletionKey) == true;
    } catch (_) {
      return false;
    }
  }

  /// Sticky peek — do not clear until first-mission attach succeeds.
  Future<bool> consumeStartedFromWelcomeAfterDeletion() async {
    return peekStartedFromWelcome();
  }

  Future<void> clearStartedFromWelcomeAfterDeletion() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(kTippyStartedFromWelcomeAfterDeletionKey);
    } catch (_) {}
  }

  Future<bool> _consumeForceFreshFlag() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool forceFresh =
          prefs.getBool(kTippyForceFreshAfterAccountDeletionKey) == true;
      if (!forceFresh) {
        return false;
      }
      await prefs.remove(kTippyForceFreshAfterAccountDeletionKey);
      await prefs.setBool(kTippyStartedFromWelcomeAfterDeletionKey, true);
      return true;
    } catch (_) {
      return false;
    }
  }
}
