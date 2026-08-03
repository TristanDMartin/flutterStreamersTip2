import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../utils/avatar_url_resolver.dart';
import '../utils/interaction_diagnostics.dart';
import '../utils/like_interaction_boundary.dart';
import '../utils/profile_user_doc_fields.dart';
import '../utils/user_profile_firestore.dart';

/// Service to handle profile updates across all views
/// This ensures that ProfileView, ProfileBackView, StreamerCardView, and StreamerCardBackView
/// are all updated when user data changes in EditProfileView or from website
class ProfileUpdateService extends ChangeNotifier {
  static final ProfileUpdateService _instance =
      ProfileUpdateService._internal();
  factory ProfileUpdateService() => _instance;
  ProfileUpdateService._internal();

  firebase_auth.User? _currentUser;
  Map<String, dynamic>? _userData;
  bool _isLoading = false;
  DateTime? _lastNotificationTime;

  StreamSubscription<DocumentSnapshot>? _userDataSubscription;

  final List<VoidCallback> _profileViewListeners = [];
  final List<VoidCallback> _profileBackViewListeners = [];
  final List<VoidCallback> _streamerCardViewListeners = [];
  final List<VoidCallback> _streamerCardBackViewListeners = [];

  firebase_auth.User? get currentUser => _currentUser;
  Map<String, dynamic>? get userData => _userData;
  bool get isDataLoaded => _userData != null;

  Future<void> initialize() async {
    final firebase_auth.User? user =
        firebase_auth.FirebaseAuth.instance.currentUser;
    if (user != null &&
        _currentUser?.uid == user.uid &&
        _userDataSubscription != null) {
      debugPrint(
        '🔍 ProfileUpdateService: Already initialized for ${user.uid}, skipping',
      );
      return;
    }
    _currentUser = user;
    debugPrint(
      '🔍 ProfileUpdateService: Initializing with user: ${_currentUser?.uid}',
    );
    if (_currentUser != null) {
      await _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    if (_currentUser == null) return;
    if (_isLoading) {
      debugPrint(
          "🔍 ProfileUpdateService: Already loading user data, skipping...");
      return;
    }
    _isLoading = true;

    try {
      debugPrint(
          "🔍 ProfileUpdateService: Loading user data for UID: ${_currentUser!.uid}");

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      debugPrint("🔍 ProfileUpdateService: Document exists: ${doc.exists}");
      if (doc.exists) {
        final newData = doc.data();
        _userData = newData;
        debugPrint("🔍 ProfileUpdateService: Loaded initial user data");
        _notifyAllChannels(reason: 'initial_load');
        unawaited(_ensurePublicPlatformsMirror());
      }

      _userDataSubscription?.cancel();
      _userDataSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .snapshots()
          .listen(
        (snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            _handleUserDocumentSnapshot(snapshot.data()!);
          }
        },
        onError: (error) {
          debugPrint(
              '❌ ProfileUpdateService: Error in user data listener: $error');
        },
      );

      debugPrint("✅ ProfileUpdateService: Real-time listener set up");
    } catch (e) {
      debugPrint('❌ ProfileUpdateService: Error loading user data: $e');
    } finally {
      _isLoading = false;
    }
  }

  /// Peers only see publicUsers.platforms — heal mirror when owner opens app.
  Future<void> _ensurePublicPlatformsMirror() async {
    final String? uid = _currentUser?.uid;
    final Map<String, dynamic>? data = _userData;
    if (uid == null || data == null) {
      return;
    }
    final List<Map<String, dynamic>> platforms =
        UserProfileFirestore.parsePlatformsFromUserData(
      data,
      connectedOnly: true,
    );
    if (platforms.isEmpty) {
      return;
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> publicSnap =
          await FirebaseFirestore.instance
              .collection(UserProfileFirestore.publicUsersCollection)
              .doc(uid)
              .get();
      final List<Map<String, dynamic>> publicPlatforms =
          UserProfileFirestore.parsePlatformsFromUserData(
        publicSnap.data(),
        connectedOnly: true,
      );
      if (publicPlatforms.isNotEmpty &&
          publicPlatforms.length == platforms.length) {
        final String privateSignature = platforms
            .map(
              (Map<String, dynamic> p) =>
                  '${p['type']}|${p['username']}|${p['url']}',
            )
            .join(';');
        final String publicSignature = publicPlatforms
            .map(
              (Map<String, dynamic> p) =>
                  '${p['type']}|${p['username']}|${p['url']}',
            )
            .join(';');
        if (privateSignature == publicSignature) {
          return;
        }
      }
      await FirebaseFirestore.instance
          .collection(UserProfileFirestore.publicUsersCollection)
          .doc(uid)
          .set(
        <String, dynamic>{
          'uid': uid,
          UserProfileFirestore.platformsField:
              UserProfileFirestore.platformsForPublicMirror(platforms),
          UserProfileFirestore.linkedPlatformsField:
              UserProfileFirestore.platformsForPublicMirror(platforms),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      debugPrint(
        '✅ ProfileUpdateService: Healed publicUsers platforms mirror '
        '(${platforms.length})',
      );
    } catch (e) {
      debugPrint(
        '⚠️ ProfileUpdateService: publicUsers platforms heal failed: $e',
      );
    }
  }

  void _handleUserDocumentSnapshot(Map<String, dynamic> newData) {
    final Map<String, dynamic>? before = _userData;
    final String? newAvatarURL = resolveAvatarUrl(newData);
    final String? currentAvatarURL = resolveAvatarUrl(before);
    final bool avatarUrlChanged = newAvatarURL != currentAvatarURL &&
        (newAvatarURL != null || currentAvatarURL != null);

    final List<String> changedFields = ProfileUserDocFields.changedRelevantFields(
      before: before,
      after: newData,
    );

    InteractionDiagnostics.logUserDocChanged(
      changedFields: changedFields,
      notifiesProfile: ProfileUserDocFields.affectsProfileShell(changedFields) ||
          avatarUrlChanged,
    );

    if (ProfileUserDocFields.hasOnlyIgnoredChanges(
          before: before,
          after: newData,
        ) &&
        !avatarUrlChanged) {
      _userData = newData;
      return;
    }

    _userData = newData;

    if (changedFields.isEmpty && !avatarUrlChanged) {
      return;
    }

    if (avatarUrlChanged) {
      InteractionDiagnostics.logProfileRebuildTrigger(
        source: 'user_doc_avatar',
      );
      _notifyAvatarChannel(reason: 'avatar_change');
    }

    if (ProfileUserDocFields.affectsProfileShell(changedFields)) {
      InteractionDiagnostics.logProfileRebuildTrigger(
        source: 'user_doc_profile_shell',
      );
      debugPrint(
        '🔄 ProfileUpdateService: Profile shell fields changed: '
        '${changedFields.join(', ')}',
      );
      _notifyProfileShellChannel(reason: 'user_doc_change');
    }
  }

  Future<void> updateUserData(Map<String, dynamic> updates) async {
    final firebase_auth.User? authUser =
        firebase_auth.FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      throw StateError('Sign in to update your profile.');
    }
    if (_currentUser?.uid != authUser.uid) {
      await initialize();
    }
    if (_currentUser == null) {
      throw StateError('Sign in to update your profile.');
    }

    try {
      final Map<String, dynamic> normalizedUpdates =
          <String, dynamic>{...updates};
      final String? resolvedAvatar = resolveAvatarUrl(updates);
      if (resolvedAvatar != null) {
        normalizedUpdates['avatarURL'] = resolvedAvatar;
        normalizedUpdates['photoURL'] = resolvedAvatar;
      }
      if (normalizedUpdates.containsKey(UserProfileFirestore.platformsField)) {
        final Object? raw =
            normalizedUpdates[UserProfileFirestore.platformsField];
        final List<Map<String, dynamic>> platforms = raw is List
            ? raw
                .whereType<Map>()
                .map((Map e) => Map<String, dynamic>.from(e))
                .toList(growable: false)
            : const <Map<String, dynamic>>[];
        normalizedUpdates[UserProfileFirestore.linkedPlatformsField] = platforms;
      }

      // Apply locally first so ProfileBack / cache refresh instantly.
      final Map<String, dynamic>? previousUserData =
          _userData == null
              ? null
              : Map<String, dynamic>.from(_userData!);
      _userData = <String, dynamic>{...?_userData, ...normalizedUpdates};
      _notifyAllChannels(
        reason: 'edit_profile_update',
        force: true,
      );

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .update(normalizedUpdates);
      } catch (e) {
        _userData = previousUserData;
        _notifyAllChannels(
          reason: 'edit_profile_update_reverted',
          force: true,
        );
        rethrow;
      }

      if (normalizedUpdates.containsKey(
        UserProfileFirestore.platformsField,
      )) {
        final Object? raw = normalizedUpdates[UserProfileFirestore.platformsField];
        final List<Map<String, dynamic>> platforms = raw is List
            ? raw
                .whereType<Map>()
                .map((Map e) => Map<String, dynamic>.from(e))
                .toList(growable: false)
            : const <Map<String, dynamic>>[];
        UserProfileFirestore.logPlatformSave(
          uid: _currentUser!.uid,
          view: 'EditProfileView',
          count: platforms.length,
        );
        // Peer surfaces read publicUsers only — best-effort after users save.
        try {
          await FirebaseFirestore.instance
              .collection(UserProfileFirestore.publicUsersCollection)
              .doc(_currentUser!.uid)
              .set(
            <String, dynamic>{
              'uid': _currentUser!.uid,
              UserProfileFirestore.platformsField:
                  UserProfileFirestore.platformsForPublicMirror(platforms),
              UserProfileFirestore.linkedPlatformsField:
                  UserProfileFirestore.platformsForPublicMirror(platforms),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        } catch (e) {
          debugPrint(
            '⚠️ ProfileUpdateService: publicUsers platforms mirror failed: $e',
          );
        }
      }

      debugPrint('✅ ProfileUpdateService: User data updated successfully');
    } catch (e) {
      debugPrint('❌ ProfileUpdateService: Error updating user data: $e');
      rethrow;
    }
  }

  void addProfileViewListener(VoidCallback listener) {
    _profileViewListeners.add(listener);
  }

  void removeProfileViewListener(VoidCallback listener) {
    _profileViewListeners.remove(listener);
  }

  void addProfileBackViewListener(VoidCallback listener) {
    _profileBackViewListeners.add(listener);
  }

  void removeProfileBackViewListener(VoidCallback listener) {
    _profileBackViewListeners.remove(listener);
  }

  void addStreamerCardViewListener(VoidCallback listener) {
    _streamerCardViewListeners.add(listener);
  }

  void removeStreamerCardViewListener(VoidCallback listener) {
    _streamerCardViewListeners.remove(listener);
  }

  void addStreamerCardBackViewListener(VoidCallback listener) {
    _streamerCardBackViewListeners.add(listener);
  }

  void removeStreamerCardBackViewListener(VoidCallback listener) {
    _streamerCardBackViewListeners.remove(listener);
  }

  void _notifyAllChannels({
    required String reason,
    bool force = false,
  }) {
    _notifyProfileShellChannel(reason: reason, force: force);
    _notifyAvatarChannel(reason: reason);
    _notifyStreamerCardChannel(reason: reason, force: force);
  }

  void _notifyProfileShellChannel({
    required String reason,
    bool force = false,
  }) {
    void emit() {
      if (!force && !_shouldEmitNotification()) {
        return;
      }
      if (force) {
        _lastNotificationTime = DateTime.now();
      }
      InteractionDiagnostics.logProfileNotifyListeners(reason: reason);
      InteractionDiagnostics.logProfileNotify(reason: reason);
      _invokeListeners(_profileViewListeners, 'ProfileView');
      _invokeListeners(_profileBackViewListeners, 'ProfileBackView');
    }
    if (LikeInteractionBoundary.shouldDeferHeavyWork) {
      LikeInteractionBoundary.reportProfileRebuild(source: reason);
      LikeInteractionBoundary.runOrQueue(
        emit,
        reason: 'profile_shell_$reason',
      );
      return;
    }
    emit();
  }

  void _notifyAvatarChannel({required String reason}) {
    if (!_shouldEmitNotification()) {
      return;
    }
    InteractionDiagnostics.logProfileNotifyListeners(reason: 'avatar:$reason');
  }

  void _notifyStreamerCardChannel({
    required String reason,
    bool force = false,
  }) {
    if (!force && !_shouldEmitNotification()) {
      return;
    }
    if (force) {
      _lastNotificationTime = DateTime.now();
    }
    _invokeListeners(_streamerCardViewListeners, 'StreamerCardView');
    _invokeListeners(_streamerCardBackViewListeners, 'StreamerCardBackView');
  }

  bool _shouldEmitNotification() {
    final DateTime now = DateTime.now();
    if (_lastNotificationTime != null &&
        now.difference(_lastNotificationTime!).inMilliseconds < 1000) {
      debugPrint(
          "🔍 ProfileUpdateService: Debouncing notification (too frequent)");
      return false;
    }
    _lastNotificationTime = now;
    return true;
  }

  void _invokeListeners(List<VoidCallback> listeners, String label) {
    for (final VoidCallback listener in listeners) {
      try {
        listener();
      } catch (e) {
        debugPrint(
            '❌ ProfileUpdateService: Error notifying $label listener: $e');
      }
    }
  }

  dynamic getUserField(String field) {
    return _userData?[field];
  }

  void clearAllListeners() {
    _profileViewListeners.clear();
    _profileBackViewListeners.clear();
    _streamerCardViewListeners.clear();
    _streamerCardBackViewListeners.clear();
  }

  /// Stops Firestore user doc listener and clears cached session data on logout.
  void teardownUserSession() {
    _userDataSubscription?.cancel();
    _userDataSubscription = null;
    _currentUser = null;
    _userData = null;
    _isLoading = false;
    debugPrint('🧹 ProfileUpdateService: user session torn down');
  }

  @override
  void dispose() {
    _userDataSubscription?.cancel();
    _userDataSubscription = null;
    clearAllListeners();
    super.dispose();
  }
}
