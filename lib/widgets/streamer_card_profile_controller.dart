import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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

  Future<void> load(String identifier) async {
    await _subscription?.cancel();
    _subscription = null;
    _setState(const StreamerCardProfileState.loading());

    try {
      final resolvedDocId = await _resolveUserDocumentId(identifier)
          .timeout(const Duration(seconds: 3));

      if (resolvedDocId == null || resolvedDocId.isEmpty) {
        _setMissingUserState();
        return;
      }

      _subscription = _firestore
          .collection('users')
          .doc(resolvedDocId)
          .snapshots()
          .listen(
        (snapshot) {
          if (!snapshot.exists) {
            _setMissingUserState();
            return;
          }

          _setState(
            StreamerCardProfileState(
              isLoading: false,
              userData: snapshot.data(),
              error: null,
              resolvedUserDocId: resolvedDocId,
            ),
          );
        },
        onError: (_) {
          _setMissingUserState();
        },
      );
    } on TimeoutException {
      _setMissingUserState(
        message: 'Profile loading timed out. Please try again.',
      );
    } catch (_) {
      _setMissingUserState();
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
    final identifier = rawIdentifier.trim();
    if (identifier.isEmpty) return null;

    final directDoc = await _firestore.collection('users').doc(identifier).get();
    if (directDoc.exists) {
      return directDoc.id;
    }

    final usernameDoc = await _firestore.collection('usernames').doc(identifier).get();
    final mappedUid = usernameDoc.data()?['uid'] as String?;
    if (mappedUid != null && mappedUid.trim().isNotEmpty) {
      final mappedDoc =
          await _firestore.collection('users').doc(mappedUid.trim()).get();
      if (mappedDoc.exists) {
        return mappedDoc.id;
      }
    }

    final usernameQuery = await _firestore
        .collection('users')
        .where('username', isEqualTo: identifier)
        .limit(1)
        .get();
    if (usernameQuery.docs.isNotEmpty) {
      return usernameQuery.docs.first.id;
    }

    final displayNameQuery = await _firestore
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
