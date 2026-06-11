import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/creator_profile_snapshot.dart';
import '../services/creator_cache_service.dart';
import '../utils/user_profile_firestore.dart';

@immutable
class StreamerCardProfileState {
  const StreamerCardProfileState({
    required this.isLoading,
    this.userData,
    this.error,
    this.resolvedUserDocId,
  });

  const StreamerCardProfileState.loading()
      : isLoading = true,
        userData = null,
        error = null,
        resolvedUserDocId = null;

  final bool isLoading;
  final Map<String, dynamic>? userData;
  final String? error;
  final String? resolvedUserDocId;

  bool get hasDisplayData {
    final Map<String, dynamic>? data = userData;
    if (data == null || data.isEmpty) {
      return false;
    }
    final String displayName = data['displayName'] as String? ?? '';
    final String username = data['username'] as String? ?? '';
    return displayName.isNotEmpty || username.isNotEmpty;
  }

  StreamerCardProfileState copyWith({
    bool? isLoading,
    Map<String, dynamic>? userData,
    String? error,
    String? resolvedUserDocId,
    bool clearUserData = false,
    bool clearError = false,
    bool clearResolvedUserDocId = false,
  }) {
    return StreamerCardProfileState(
      isLoading: isLoading ?? this.isLoading,
      userData: clearUserData ? null : (userData ?? this.userData),
      error: clearError ? null : (error ?? this.error),
      resolvedUserDocId: clearResolvedUserDocId
          ? null
          : (resolvedUserDocId ?? this.resolvedUserDocId),
    );
  }
}

class StreamerCardProfileController extends ChangeNotifier {
  StreamerCardProfileController({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  StreamerCardProfileState _state = const StreamerCardProfileState.loading();

  StreamerCardProfileState get state => _state;

  Future<void> load(
    String identifier, {
    CreatorProfileSnapshot? initialCreator,
  }) async {
    await _subscription?.cancel();
    _subscription = null;

    final CreatorProfileSnapshot? cached =
        CreatorCacheService.instance.get(identifier.trim());
    final CreatorProfileSnapshot? seed = initialCreator ?? cached;

    if (seed != null && seed.hasDisplayIdentity) {
      CreatorCacheService.instance.set(seed.creatorId, seed);
      final String resolvedGuess = seed.creatorId.trim().isNotEmpty
          ? seed.creatorId.trim()
          : identifier.trim();
      _setState(
        StreamerCardProfileState(
          isLoading: false,
          userData: seed.toUserDataMap(),
          error: null,
          resolvedUserDocId: resolvedGuess,
        ),
      );
    } else {
      _setState(const StreamerCardProfileState.loading());
    }

    unawaited(_attachLiveProfile(identifier.trim()));
  }

  Future<void> _attachLiveProfile(String identifier) async {
    try {
      final String? resolvedDocId = await _resolveUserDocumentId(identifier)
          .timeout(const Duration(seconds: 3));

      if (resolvedDocId == null || resolvedDocId.isEmpty) {
        if (!_state.hasDisplayData) {
          _setMissingUserState();
        }
        return;
      }

      _subscription?.cancel();
      _subscription = _firestore
          .collection('users')
          .doc(resolvedDocId)
          .snapshots()
          .listen(
        (DocumentSnapshot<Map<String, dynamic>> snapshot) {
          if (!snapshot.exists) {
            if (!_state.hasDisplayData) {
              _setMissingUserState();
            }
            return;
          }

          final Map<String, dynamic> fresh =
              Map<String, dynamic>.from(snapshot.data() ?? <String, dynamic>{});
          final CreatorProfileSnapshot? priorCache =
              CreatorCacheService.instance.get(resolvedDocId);
          final Map<String, dynamic> merged =
              UserProfileFirestore.mergeDisplayUserData(
            fresh: fresh,
            seed: priorCache?.toUserDataMap(),
          );
          final int platformCount = UserProfileFirestore.parsePlatformsFromUserData(
            merged,
          ).length;
          UserProfileFirestore.logPlatformRead(
            uid: resolvedDocId,
            view: 'StreamerCardBackView',
            count: platformCount,
          );
          UserProfileFirestore.logCalendarRead(
            uid: resolvedDocId,
            source: 'StreamerCardBackView',
            count: UserProfileFirestore.parseCalendarEventsFromUserData(merged)
                .length,
          );

          CreatorCacheService.instance.setFromUserData(resolvedDocId, merged);

          _setState(
            StreamerCardProfileState(
              isLoading: false,
              userData: merged,
              error: null,
              resolvedUserDocId: resolvedDocId,
            ),
          );
        },
        onError: (_) {
          if (!_state.hasDisplayData) {
            _setMissingUserState();
          }
        },
      );
    } on TimeoutException {
      if (!_state.hasDisplayData) {
        _setMissingUserState(
          message: 'Profile loading timed out. Please try again.',
        );
      }
    } catch (_) {
      if (!_state.hasDisplayData) {
        _setMissingUserState();
      }
    }
  }

  Future<void> _setMissingUserState({
    String message =
        'User not found. This account may not have completed profile setup yet.',
  }) async {
    _setState(
      StreamerCardProfileState(
        isLoading: false,
        userData: null,
        error: message,
        resolvedUserDocId: null,
      ),
    );
  }

  Future<String?> _resolveUserDocumentId(String rawIdentifier) async {
    final String identifier = rawIdentifier.trim();
    if (identifier.isEmpty) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> directDoc =
        await _firestore.collection('users').doc(identifier).get();
    if (directDoc.exists) {
      return directDoc.id;
    }

    final DocumentSnapshot<Map<String, dynamic>> usernameDoc =
        await _firestore.collection('usernames').doc(identifier).get();
    final String? mappedUid = usernameDoc.data()?['uid'] as String?;
    if (mappedUid != null && mappedUid.trim().isNotEmpty) {
      final DocumentSnapshot<Map<String, dynamic>> mappedDoc = await _firestore
          .collection('users')
          .doc(mappedUid.trim())
          .get();
      if (mappedDoc.exists) {
        return mappedDoc.id;
      }
    }

    final QuerySnapshot<Map<String, dynamic>> usernameQuery = await _firestore
        .collection('users')
        .where('username', isEqualTo: identifier)
        .limit(1)
        .get();
    if (usernameQuery.docs.isNotEmpty) {
      return usernameQuery.docs.first.id;
    }

    final QuerySnapshot<Map<String, dynamic>> displayNameQuery = await _firestore
        .collection('users')
        .where('displayName', isEqualTo: identifier)
        .limit(1)
        .get();
    if (displayNameQuery.docs.isNotEmpty) {
      return displayNameQuery.docs.first.id;
    }

    return null;
  }

  void _setState(StreamerCardProfileState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
