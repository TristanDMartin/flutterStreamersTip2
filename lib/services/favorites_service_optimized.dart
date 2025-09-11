import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesServiceOptimized {
  static final FavoritesServiceOptimized _instance = FavoritesServiceOptimized._internal();
  factory FavoritesServiceOptimized() => _instance;
  FavoritesServiceOptimized._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Local storage key
  static const String _favoritesKey = 'user_favorites';
  
  // Simple state management
  final Set<String> _favorites = <String>{};
  bool _isInitialized = false;

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesList = prefs.getStringList(_favoritesKey) ?? [];
      _favorites.addAll(favoritesList);
      _isInitialized = true;
    } catch (e) {
    // print('Error initializing favorites: $e');
    }
  }

  /// Check if video is favorited
  bool isFavorited(String videoId) {
    return _favorites.contains(videoId);
  }

  /// Get all favorite video IDs
  Set<String> getFavorites() {
    return Set.from(_favorites);
  }

  /// Toggle favorite status for a video
  Future<bool> toggleFavorite(String videoId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final isFavorited = _favorites.contains(videoId);
      
      if (isFavorited) {
        return await _removeFavorite(videoId, currentUser.uid);
      } else {
        return await _addFavorite(videoId, currentUser.uid);
      }
    } catch (e) {
    // print('Error toggling favorite: $e');
      return false;
    }
  }

  /// Add video to favorites
  Future<bool> _addFavorite(String videoId, String userId) async {
    try {
      final batch = _firestore.batch();
      
      // Add to user's favorites
      final userFavRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(videoId);
      batch.set(userFavRef, {
        'videoId': videoId,
        'favoritedAt': FieldValue.serverTimestamp(),
      });

      // Update video favorite count
      final videoRef = _firestore.collection('videos').doc(videoId);
      batch.update(videoRef, {
        'favoriteCount': FieldValue.increment(1),
        'isFavorited': true,
      });

      await batch.commit();
      
      // Update local state
      _favorites.add(videoId);
      await _saveLocalState();
      
      return true;
    } catch (e) {
    // print('Error adding favorite: $e');
      return false;
    }
  }

  /// Remove video from favorites
  Future<bool> _removeFavorite(String videoId, String userId) async {
    try {
      final batch = _firestore.batch();
      
      // Remove from user's favorites
      final userFavRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(videoId);
      batch.delete(userFavRef);

      // Update video favorite count
      final videoRef = _firestore.collection('videos').doc(videoId);
      batch.update(videoRef, {
        'favoriteCount': FieldValue.increment(-1),
        'isFavorited': false,
      });

      await batch.commit();
      
      // Update local state
      _favorites.remove(videoId);
      await _saveLocalState();
      
      return true;
    } catch (e) {
    // print('Error removing favorite: $e');
      return false;
    }
  }

  /// Save local state to SharedPreferences
  Future<void> _saveLocalState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favoritesKey, _favorites.toList());
    } catch (e) {
    // print('Error saving favorites: $e');
    }
  }

  /// Get favorite count for a video
  Future<int> getFavoriteCount(String videoId) async {
    try {
      final doc = await _firestore.collection('videos').doc(videoId).get();
      return doc.data()?['favoriteCount'] ?? 0;
    } catch (e) {
    // print('Error getting favorite count: $e');
      return 0;
    }
  }

  /// Clear all favorites (for logout)
  Future<void> clearFavorites() async {
    _favorites.clear();
    await _saveLocalState();
  }

  /// Force sync with Firebase
  Future<void> forceSync() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('favorites')
          .get();

      _favorites.clear();
      for (final doc in snapshot.docs) {
        _favorites.add(doc.id);
      }
      
      await _saveLocalState();
    } catch (e) {
    // print('Error syncing favorites: $e');
    }
  }
}
