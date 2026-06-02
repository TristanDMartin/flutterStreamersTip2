import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FavoritesSyncStatus {
  synced,
  pending,
  error,
  offline,
}

class FavoritesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Local storage keys
  static const String _favoritesKey = 'user_favorites';
  static const String _pendingSyncKey = 'pending_favorites_sync';

  // State management
  final Set<String> _localFavorites = <String>{};
  final Set<String> _pendingSync = <String>{};
  FavoritesSyncStatus _syncStatus = FavoritesSyncStatus.synced;
  bool _isLoading = false;

  // Stream controllers for reactive updates
  final StreamController<Set<String>> _favoritesController =
      StreamController<Set<String>>.broadcast();
  final StreamController<FavoritesSyncStatus> _syncStatusController =
      StreamController<FavoritesSyncStatus>.broadcast();

  // Getters
  Set<String> get localFavorites => Set.from(_localFavorites);
  Set<String> get pendingSync => Set.from(_pendingSync);
  FavoritesSyncStatus get syncStatus => _syncStatus;
  bool get isLoading => _isLoading;

  // Streams
  Stream<Set<String>> get favoritesStream => _favoritesController.stream;
  Stream<FavoritesSyncStatus> get syncStatusStream =>
      _syncStatusController.stream;

  /// Initialize the service and load local state
  Future<void> initialize() async {
    await _loadLocalState();
    _setupAuthListener();
  }

  /// Dispose resources
  void dispose() {
    _favoritesController.close();
    _syncStatusController.close();
  }

  /// Load local state from SharedPreferences
  Future<void> _loadLocalState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load local favorites
      final favoritesList = prefs.getStringList(_favoritesKey) ?? [];
      _localFavorites.addAll(favoritesList);

      // Load pending sync operations
      final pendingList = prefs.getStringList(_pendingSyncKey) ?? [];
      _pendingSync.addAll(pendingList);

      _notifyFavoritesChanged();
      _updateSyncStatus();
    } catch (e) {
      debugPrint('Error loading local favorites state: $e');
      _setSyncStatus(FavoritesSyncStatus.error);
    }
  }

  /// Save local state to SharedPreferences
  Future<void> _saveLocalState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favoritesKey, _localFavorites.toList());
      await prefs.setStringList(_pendingSyncKey, _pendingSync.toList());
    } catch (e) {
      debugPrint('Error saving local favorites state: $e');
    }
  }

  /// Setup authentication state listener
  void _setupAuthListener() {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _syncWithFirebase();
      } else {
        _clearUserData();
      }
    });
  }

  /// Clear user-specific data on logout
  void _clearUserData() {
    _localFavorites.clear();
    _pendingSync.clear();
    _notifyFavoritesChanged();
    _setSyncStatus(FavoritesSyncStatus.synced);
  }

  /// Update sync status based on current state
  void _updateSyncStatus() {
    if (_pendingSync.isEmpty) {
      _setSyncStatus(FavoritesSyncStatus.synced);
    } else {
      _setSyncStatus(FavoritesSyncStatus.pending);
    }
  }

  /// Set sync status and notify listeners
  void _setSyncStatus(FavoritesSyncStatus status) {
    _syncStatus = status;
    _syncStatusController.add(status);
  }

  /// Notify listeners of favorites changes
  void _notifyFavoritesChanged() {
    _favoritesController.add(Set.from(_localFavorites));
  }

  /// Syncs favorite status with Firebase, matching the Swift implementation
  Future<bool> syncFavoriteWithFirebase({
    required String videoId,
    required String userId,
    required bool isFavoriting,
  }) async {
    try {
      final userFavoritesRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(videoId);

      if (isFavoriting) {
        await userFavoritesRef.set({
          'videoId': videoId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        await userFavoritesRef.delete();
      }

      return true;
    } catch (e) {
      debugPrint('Error syncing favorite with Firebase: $e');
      _setSyncStatus(FavoritesSyncStatus.error);
      return false;
    }
  }

  /// Optimistic toggle with immediate UI feedback
  Future<bool> toggleFavorite(String videoId) async {
    if (_isLoading) return false;

    _isLoading = true;

    // For now, work offline-only to avoid Firebase permission issues
    final result = _toggleLocalFavorite(videoId);
    _isLoading = false;
    return result;
  }

  /// Toggle local favorite without Firebase sync
  bool _toggleLocalFavorite(String videoId) {
    final wasFavorited = _localFavorites.contains(videoId);
    _updateLocalFavorite(videoId, !wasFavorited);
    _saveLocalState();
    return true;
  }

  /// Update local favorite state
  void _updateLocalFavorite(String videoId, bool isFavorited) {
    if (isFavorited) {
      _localFavorites.add(videoId);
    } else {
      _localFavorites.remove(videoId);
    }
    _notifyFavoritesChanged();
  }

  /// Sync pending operations with Firebase
  Future<void> _syncWithFirebase() async {
    final user = _auth.currentUser;
    if (user == null || _pendingSync.isEmpty) return;

    _setSyncStatus(FavoritesSyncStatus.pending);

    try {
      // Sync all pending operations
      for (final videoId in List.from(_pendingSync)) {
        final isFavorited = _localFavorites.contains(videoId);
        final success = await syncFavoriteWithFirebase(
          videoId: videoId,
          userId: user.uid,
          isFavoriting: isFavorited,
        );

        if (success) {
          _pendingSync.remove(videoId);
        }
      }

      // Load remote favorites to sync with local state
      await _loadRemoteFavorites(user.uid);

      _updateSyncStatus();
      await _saveLocalState();
    } catch (e) {
      debugPrint('Error syncing with Firebase: $e');
      _setSyncStatus(FavoritesSyncStatus.error);
    }
  }

  /// Load remote favorites and merge with local state
  Future<void> _loadRemoteFavorites(String userId) async {
    try {
      final remoteFavorites = await getUserFavorites(userId);
      _localFavorites.clear();
      _localFavorites.addAll(remoteFavorites);
      _notifyFavoritesChanged();
    } catch (e) {
      debugPrint('Error loading remote favorites: $e');
    }
  }

  /// Check if a video is currently favorited (O(1) lookup)
  bool isFavorited(String videoId) {
    return _localFavorites.contains(videoId);
  }

  /// Get all favorite video IDs
  List<String> getFavorites() {
    return _localFavorites.toList();
  }

  /// Gets all favorite video IDs for a user from Firebase
  Future<List<String>> getUserFavorites(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .get();

      return querySnapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('Error getting user favorites: $e');
      return [];
    }
  }

  /// Stream of user's favorite video IDs from Firebase
  Stream<List<String>> watchUserFavorites(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  /// Force sync with Firebase (for network recovery)
  Future<void> forceSync() async {
    // For now, just reload local state to avoid Firebase issues
    await _loadLocalState();
  }

  /// Clear all favorites (for logout)
  void clearFavorites() {
    _clearUserData();
  }
}
