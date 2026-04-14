import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../utils/avatar_url_resolver.dart';

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

  // Real-time Firestore listener for avatar and profile updates
  StreamSubscription<DocumentSnapshot>? _userDataSubscription;

  // Listeners for different views
  final List<VoidCallback> _profileViewListeners = [];
  final List<VoidCallback> _profileBackViewListeners = [];
  final List<VoidCallback> _streamerCardViewListeners = [];
  final List<VoidCallback> _streamerCardBackViewListeners = [];

  firebase_auth.User? get currentUser => _currentUser;
  Map<String, dynamic>? get userData => _userData;
  bool get isDataLoaded => _userData != null;

  /// Initialize the service with current user
  Future<void> initialize() async {
    _currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    debugPrint(
        "🔍 ProfileUpdateService: Initializing with user: ${_currentUser?.uid}");
    if (_currentUser != null) {
      await _loadUserData();
    }
  }

  /// Load user data from Firestore and set up real-time listener
  Future<void> _loadUserData() async {
    if (_currentUser == null) return;

    // Prevent infinite loops by checking if we're already loading
    if (_isLoading) {
      debugPrint(
          "🔍 ProfileUpdateService: Already loading user data, skipping...");
      return;
    }
    _isLoading = true;

    try {
      debugPrint(
          "🔍 ProfileUpdateService: Loading user data for UID: ${_currentUser!.uid}");

      // Load initial data
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      debugPrint("🔍 ProfileUpdateService: Document exists: ${doc.exists}");
      if (doc.exists) {
        final newData = doc.data();
        _userData = newData;
        debugPrint("🔍 ProfileUpdateService: Loaded initial user data");
        notifyAllListeners();
      }

      // Set up real-time listener for avatar and profile updates (from website or app)
      _userDataSubscription?.cancel();
      _userDataSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .snapshots()
          .listen(
        (snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            final newData = snapshot.data()!;

            // Check if avatar URL changed
            final newAvatarURL = resolveAvatarUrl(newData);
            final currentAvatarURL = resolveAvatarUrl(_userData);

            // Only notify if data has actually changed
            if (_userData == null || !_mapsEqual(_userData!, newData)) {
              _userData = newData;
              debugPrint(
                  "🔄 ProfileUpdateService: User data updated from Firestore (real-time)");
              debugPrint("   Avatar URL: ${newAvatarURL ?? 'null'}");
              notifyAllListeners();
            } else if (newAvatarURL != currentAvatarURL &&
                newAvatarURL != null) {
              // Avatar specifically changed, update and notify
              _userData = newData;
              debugPrint(
                  "🔄 ProfileUpdateService: Avatar updated from Firestore (real-time)");
              debugPrint("   Old: ${currentAvatarURL ?? 'null'}");
              debugPrint("   New: ${newAvatarURL}");
              notifyAllListeners();
            }
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

  /// Update user data and notify all views
  Future<void> updateUserData(Map<String, dynamic> updates) async {
    if (_currentUser == null) return;

    try {
      final normalizedUpdates = <String, dynamic>{...updates};
      final resolvedAvatar = resolveAvatarUrl(updates);
      if (resolvedAvatar != null) {
        normalizedUpdates['avatarURL'] = resolvedAvatar;
        normalizedUpdates['photoURL'] = resolvedAvatar;
      }

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .update(normalizedUpdates);

      // Update local data
      _userData = {...?_userData, ...normalizedUpdates};

      // Notify all listeners
      notifyAllListeners();

      debugPrint('✅ ProfileUpdateService: User data updated successfully');
    } catch (e) {
      debugPrint('❌ ProfileUpdateService: Error updating user data: $e');
      rethrow;
    }
  }

  /// Add listener for ProfileView updates
  void addProfileViewListener(VoidCallback listener) {
    _profileViewListeners.add(listener);
  }

  /// Remove listener for ProfileView updates
  void removeProfileViewListener(VoidCallback listener) {
    _profileViewListeners.remove(listener);
  }

  /// Add listener for ProfileBackView updates
  void addProfileBackViewListener(VoidCallback listener) {
    _profileBackViewListeners.add(listener);
  }

  /// Remove listener for ProfileBackView updates
  void removeProfileBackViewListener(VoidCallback listener) {
    _profileBackViewListeners.remove(listener);
  }

  /// Add listener for StreamerCardView updates
  void addStreamerCardViewListener(VoidCallback listener) {
    _streamerCardViewListeners.add(listener);
  }

  /// Remove listener for StreamerCardView updates
  void removeStreamerCardViewListener(VoidCallback listener) {
    _streamerCardViewListeners.remove(listener);
  }

  /// Add listener for StreamerCardBackView updates
  void addStreamerCardBackViewListener(VoidCallback listener) {
    _streamerCardBackViewListeners.add(listener);
  }

  /// Remove listener for StreamerCardBackView updates
  void removeStreamerCardBackViewListener(VoidCallback listener) {
    _streamerCardBackViewListeners.remove(listener);
  }

  /// Notify all listeners with debouncing to prevent excessive notifications
  void notifyAllListeners() {
    final now = DateTime.now();

    // Debounce notifications - only notify once every 1000ms (1 second)
    if (_lastNotificationTime != null &&
        now.difference(_lastNotificationTime!).inMilliseconds < 1000) {
      debugPrint(
          "🔍 ProfileUpdateService: Debouncing notification (too frequent)");
      return;
    }
    _lastNotificationTime = now;

    debugPrint(
        "🔍 ProfileUpdateService: Notifying ${_profileViewListeners.length} ProfileView listeners, ${_profileBackViewListeners.length} ProfileBackView listeners, ${_streamerCardViewListeners.length} StreamerCardView listeners");

    // Notify ProfileView listeners
    for (final listener in _profileViewListeners) {
      try {
        listener();
      } catch (e) {
        debugPrint(
            '❌ ProfileUpdateService: Error notifying ProfileView listener: $e');
      }
    }

    // Notify ProfileBackView listeners
    for (final listener in _profileBackViewListeners) {
      try {
        listener();
      } catch (e) {
        debugPrint(
            '❌ ProfileUpdateService: Error notifying ProfileBackView listener: $e');
      }
    }

    // Notify StreamerCardView listeners
    for (final listener in _streamerCardViewListeners) {
      try {
        listener();
      } catch (e) {
        debugPrint(
            '❌ ProfileUpdateService: Error notifying StreamerCardView listener: $e');
      }
    }

    // Notify StreamerCardBackView listeners
    for (final listener in _streamerCardBackViewListeners) {
      try {
        listener();
      } catch (e) {
        debugPrint(
            '❌ ProfileUpdateService: Error notifying StreamerCardBackView listener: $e');
      }
    }
  }

  /// Get user data for a specific field
  dynamic getUserField(String field) {
    return _userData?[field];
  }

  /// Clear all listeners (useful for cleanup)
  void clearAllListeners() {
    _profileViewListeners.clear();
    _profileBackViewListeners.clear();
    _streamerCardViewListeners.clear();
    _streamerCardBackViewListeners.clear();
  }

  /// Dispose the service and cancel subscriptions
  @override
  void dispose() {
    _userDataSubscription?.cancel();
    _userDataSubscription = null;
    clearAllListeners();
    super.dispose();
  }

  /// Helper method to compare two maps for equality
  bool _mapsEqual(Map<String, dynamic> map1, Map<String, dynamic> map2) {
    if (map1.length != map2.length) return false;

    for (final key in map1.keys) {
      if (!map2.containsKey(key)) return false;
      if (map1[key] != map2[key]) return false;
    }

    return true;
  }
}
