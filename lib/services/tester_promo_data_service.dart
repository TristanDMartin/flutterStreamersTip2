import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/onboarding/onboarding_tester_config.dart';
import '../providers/follow_refresh_provider.dart';
import '../providers/main_tab_provider.dart';
import '../providers/video_service_provider.dart' as video_providers;
import '../qa/qa_runtime.dart';
import 'profile_update_service.dart';
import 'package:streamers_tip/utils/secure_log.dart';

class TesterPromoIdentity {
  const TesterPromoIdentity({
    required this.userId,
    this.email,
    this.username,
    this.displayName,
    this.promoEligibleFromFirestore = false,
    this.storedPromoVersion = 0,
  });

  final String userId;
  final String? email;
  final String? username;
  final String? displayName;
  final bool promoEligibleFromFirestore;
  final int storedPromoVersion;
}

class TesterPromoDataResult {
  const TesterPromoDataResult({
    required this.skipped,
    this.version,
    this.connections,
    this.followers,
    this.following,
    this.chats,
    this.videos,
    this.errorMessage,
  });

  final bool skipped;
  final int? version;
  final int? connections;
  final int? followers;
  final int? following;
  final int? chats;
  final int? videos;
  final String? errorMessage;

  bool get isSuccess => errorMessage == null;
}

class TesterPromoDataService {
  TesterPromoDataService({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
    firebase_auth.FirebaseAuth? auth,
  })  : _functionsOverride = functions,
        _firestoreOverride = firestore,
        _authOverride = auth;

  static final TesterPromoDataService instance = TesterPromoDataService();

  final FirebaseFunctions? _functionsOverride;
  final FirebaseFirestore? _firestoreOverride;
  final firebase_auth.FirebaseAuth? _authOverride;
  FirebaseFunctions? _functions;

  FirebaseFunctions get _resolvedFunctions {
    return _functionsOverride ??
        (_functions ??= FirebaseFunctions.instanceFor(region: 'us-central1'));
  }

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  firebase_auth.FirebaseAuth get _auth =>
      _authOverride ?? firebase_auth.FirebaseAuth.instance;

  Future<TesterPromoDataResult>? _inFlight;

  static const bool enablePromoSeed = bool.fromEnvironment(
    'STREAMERSTIP_ENABLE_TESTER_PROMO_DATA',
    defaultValue: false,
  );

  Future<TesterPromoIdentity?> resolveCurrentIdentity() async {
    final firebase_auth.User? authUser = _auth.currentUser;
    if (authUser == null || authUser.uid.isEmpty) {
      return null;
    }
    String? username;
    String? displayName;
    String? email = authUser.email;
    bool promoEligibleFromFirestore = false;
    int storedPromoVersion = 0;
    try {
      final DocumentSnapshot<Map<String, dynamic>> userDoc =
          await _firestore.collection('users').doc(authUser.uid).get();
      final Map<String, dynamic>? data = userDoc.data();
      if (data != null) {
        username = data['username']?.toString();
        displayName = data['displayName']?.toString();
        email ??= data['email']?.toString();
        promoEligibleFromFirestore = data['testerPromoEligible'] == true;
        storedPromoVersion =
            (data['testerPromoDataVersion'] as num?)?.toInt() ?? 0;
      }
    } catch (error) {
      secureLog('⚠️ TesterPromoDataService: identity lookup failed: $error');
    }
    displayName ??= authUser.displayName;
    return TesterPromoIdentity(
      userId: authUser.uid,
      email: email,
      username: username,
      displayName: displayName,
      promoEligibleFromFirestore: promoEligibleFromFirestore,
      storedPromoVersion: storedPromoVersion,
    );
  }

  Future<TesterPromoDataResult> ensureSeededForCurrentUser({
    bool force = false,
    WidgetRef? refreshRef,
  }) async {
    final TesterPromoIdentity? identity = await resolveCurrentIdentity();
    if (identity == null) {
      return const TesterPromoDataResult(
        skipped: true,
        errorMessage: 'No signed-in user',
      );
    }
    return ensureSeeded(
      userId: identity.userId,
      email: identity.email,
      username: identity.username,
      displayName: identity.displayName,
      promoEligibleFromFirestore: identity.promoEligibleFromFirestore,
      storedPromoVersion: identity.storedPromoVersion,
      force: force,
      refreshRef: refreshRef,
    );
  }

  Future<TesterPromoDataResult> ensureSeeded({
    required String userId,
    String? email,
    String? username,
    String? displayName,
    bool? promoEligibleFromFirestore,
    int? storedPromoVersion,
    bool force = false,
    WidgetRef? refreshRef,
  }) {
    final Future<TesterPromoDataResult>? existing = _inFlight;
    if (existing != null) {
      return existing;
    }
    final Future<TesterPromoDataResult> run = _ensureSeededInternal(
      userId: userId,
      email: email,
      username: username,
      displayName: displayName,
      promoEligibleFromFirestore: promoEligibleFromFirestore,
      storedPromoVersion: storedPromoVersion,
      force: force,
      refreshRef: refreshRef,
    );
    _inFlight = run;
    return run.whenComplete(() {
      if (identical(_inFlight, run)) {
        _inFlight = null;
      }
    });
  }

  Future<TesterPromoDataResult> _ensureSeededInternal({
    required String userId,
    String? email,
    String? username,
    String? displayName,
    bool? promoEligibleFromFirestore,
    int? storedPromoVersion,
    required bool force,
    WidgetRef? refreshRef,
  }) async {
    if (!enablePromoSeed || QaRuntime.isMobileFeedE2e) {
      return const TesterPromoDataResult(skipped: true);
    }
    final bool isTester = OnboardingTesterConfig.isPromoDataTester(
      userId: userId,
      email: email,
      username: username,
      displayName: displayName,
      promoEligibleFromFirestore: promoEligibleFromFirestore,
    );
    if (!isTester) {
      secureLog(
        'ℹ️ TesterPromoDataService: skipped — account not promo-eligible '
        '(email=${email ?? 'null'}, username=${username ?? 'null'})',
      );
      return const TesterPromoDataResult(skipped: true);
    }
    final int versionOnServer = storedPromoVersion ?? 0;
    final bool needsForce = force ||
        versionOnServer < OnboardingTesterConfig.promoDataVersion ||
        !await _hasPromoData(userId);
    TesterPromoDataResult result = await _invokeSeed(force: needsForce);
    if (result.errorMessage != null) {
      secureLog(
        '❌ TesterPromoDataService: seed failed — ${result.errorMessage}',
      );
      return result;
    }
    if (result.skipped && !await _hasPromoData(userId)) {
      secureLog('🔄 TesterPromoDataService: retrying seed with force=true');
      result = await _invokeSeed(force: true);
    }
    if (result.isSuccess && !result.skipped) {
      secureLog(
        '✅ TesterPromoDataService: seeded v${result.version} '
        '(${result.connections} connections, ${result.chats} chats, '
        '${result.videos} videos)',
      );
      if (refreshRef != null) {
        refreshPromoSurfaces(refreshRef, userId);
      }
    } else if (result.skipped && await _hasPromoData(userId)) {
      secureLog(
        'ℹ️ TesterPromoDataService: promo data already present '
        '(v${result.version ?? versionOnServer})',
      );
      if (refreshRef != null) {
        refreshPromoSurfaces(refreshRef, userId);
      }
    }
    return result;
  }

  Future<TesterPromoDataResult> _invokeSeed({required bool force}) async {
    try {
      final HttpsCallable callable =
          _resolvedFunctions.httpsCallable('seedTesterPromoData');
      final HttpsCallableResult<dynamic> response = await callable.call(
        <String, dynamic>{'force': force},
      );
      final Map<String, dynamic> data = _asMap(response.data);
      if (data['skipped'] == true) {
        return TesterPromoDataResult(
          skipped: true,
          version: _readInt(data['version']),
        );
      }
      return TesterPromoDataResult(
        skipped: false,
        version: _readInt(data['version']),
        connections: _readInt(data['connections']),
        followers: _readInt(data['followers']),
        following: _readInt(data['following']),
        chats: _readInt(data['chats']),
        videos: _readInt(data['videos']),
      );
    } on FirebaseFunctionsException catch (error) {
      return TesterPromoDataResult(
        skipped: true,
        errorMessage: '${error.code}: ${error.message ?? 'unknown'}',
      );
    } catch (error) {
      return TesterPromoDataResult(
        skipped: true,
        errorMessage: error.toString(),
      );
    }
  }

  Future<bool> _hasPromoData(String userId) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> userDoc =
          await _firestore.collection('users').doc(userId).get();
      final Map<String, dynamic>? userData = userDoc.data();
      final int version =
          (userData?['testerPromoDataVersion'] as num?)?.toInt() ?? 0;
      if (version < OnboardingTesterConfig.promoDataVersion) {
        return false;
      }
      final QuerySnapshot<Map<String, dynamic>> followsSnapshot =
          await _firestore
              .collection('follows')
              .where('targetUserId', isEqualTo: userId)
              .limit(1)
              .get();
      if (followsSnapshot.docs.isEmpty) {
        return false;
      }
      final QuerySnapshot<Map<String, dynamic>> videosSnapshot =
          await _firestore
              .collection('videos')
              .where('userId', isEqualTo: userId)
              .limit(20)
              .get();
      final int promoVideoCount = videosSnapshot.docs
          .where(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                doc.data()['isPromoFixture'] == true,
          )
          .length;
      if (promoVideoCount < 3) {
        return false;
      }
      final QuerySnapshot<Map<String, dynamic>> chatsSnapshot =
          await _firestore
              .collection('chats')
              .where('participants', arrayContains: userId)
              .limit(1)
              .get();
      return chatsSnapshot.docs.isNotEmpty;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('⚠️ TesterPromoDataService: verify failed: $error');
      }
      return false;
    }
  }

  static void refreshPromoSurfaces(WidgetRef ref, String userId) {
    ref.read(followRefreshProvider.notifier).state++;
    ref.read(networkTabBackgroundRefreshProvider.notifier).requestRefresh();
    ref.read(inboxTabBackgroundRefreshProvider.notifier).requestRefresh();
    ref.invalidate(video_providers.userVideosProvider(userId));
    unawaited(
      ref
          .read(video_providers.videoServiceStateProvider.notifier)
          .mergeProfileVideosForUser(userId),
    );
    unawaited(ProfileUpdateService().initialize());
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }
}
