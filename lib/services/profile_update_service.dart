import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

/// Service to handle profile updates across all views
/// This ensures that ProfileView, ProfileBackView, StreamerCardView, and StreamerCardBackView
/// are all updated when user data changes in EditProfileView
class ProfileUpdateService extends ChangeNotifier {
  static final ProfileUpdateService _instance = ProfileUpdateService._internal();
  factory ProfileUpdateService() => _instance;
  ProfileUpdateService._internal();

  firebase_auth.User? _currentUser;
  Map<String, dynamic>? _userData;
  
  // Listeners for different views
  final List<VoidCallback> _profileViewListeners = [];
  final List<VoidCallback> _profileBackViewListeners = [];
  final List<VoidCallback> _streamerCardViewListeners = [];
  final List<VoidCallback> _streamerCardBackViewListeners = [];

  firebase_auth.User? get currentUser => _currentUser;
  Map<String, dynamic>? get userData => _userData;

  /// Initialize the service with current user
  Future<void> initialize() async {
    _currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      await _loadUserData();
    }
  }

  /// Load user data from Firestore
  Future<void> _loadUserData() async {
    if (_currentUser == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();
      
      if (doc.exists) {
        _userData = doc.data();
        notifyAllListeners();
      }
    } catch (e) {
      debugPrint('❌ ProfileUpdateService: Error loading user data: $e');
    }
  }

  /// Update user data and notify all views
  Future<void> updateUserData(Map<String, dynamic> updates) async {
    if (_currentUser == null) return;

    try {
      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .update(updates);

      // Update local data
      _userData = {...?_userData, ...updates};
      
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

  /// Notify all listeners
  void notifyAllListeners() {
    // Notify ProfileView listeners
    for (final listener in _profileViewListeners) {
      try {
        listener();
      } catch (e) {
        debugPrint('❌ ProfileUpdateService: Error notifying ProfileView listener: $e');
      }
    }

    // Notify ProfileBackView listeners
    for (final listener in _profileBackViewListeners) {
      try {
        listener();
      } catch (e) {
        debugPrint('❌ ProfileUpdateService: Error notifying ProfileBackView listener: $e');
      }
    }

    // Notify StreamerCardView listeners
    for (final listener in _streamerCardViewListeners) {
      try {
        listener();
      } catch (e) {
        debugPrint('❌ ProfileUpdateService: Error notifying StreamerCardView listener: $e');
      }
    }

    // Notify StreamerCardBackView listeners
    for (final listener in _streamerCardBackViewListeners) {
      try {
        listener();
      } catch (e) {
        debugPrint('❌ ProfileUpdateService: Error notifying StreamerCardBackView listener: $e');
      }
    }
  }

  /// Get user data for a specific field
  dynamic getUserField(String field) {
    return _userData?[field];
  }

  /// Check if user data is loaded
  bool get isDataLoaded => _userData != null;

  /// Clear all listeners (useful for cleanup)
  void clearAllListeners() {
    _profileViewListeners.clear();
    _profileBackViewListeners.clear();
    _streamerCardViewListeners.clear();
    _streamerCardBackViewListeners.clear();
  }
}
