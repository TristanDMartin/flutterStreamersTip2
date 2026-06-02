import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../models/home_video.dart';

final favoritesManagerProvider =
    ChangeNotifierProvider<FavoritesManager>((ref) {
  final manager = FavoritesManager();
  ref.onDispose(manager.dispose);
  return manager..initialize();
});

enum FavoriteAction {
  added,
  removed,
  error,
}

class FavoritesManager extends ChangeNotifier {
  FavoritesManager();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _favSub;

  // Core state matching Swift architecture
  Set<String> _favoriteVideoIDs = <String>{};
  FavoriteAction? _lastAction;
  bool _isLoading = false;

  // Getters matching Swift @Published properties
  Set<String> get favoriteVideoIDs => Set.from(_favoriteVideoIDs);
  FavoriteAction? get lastAction => _lastAction;
  bool get isLoading => _isLoading;

  // Core methods matching Swift interface
  bool isFavorited(HomeVideo video) => _favoriteVideoIDs.contains(video.id);

  List<HomeVideo> favoriteVideos(List<HomeVideo> allVideos) {
    return allVideos.where((video) => isFavorited(video)).toList();
  }

  Future<void> toggleFavorite(HomeVideo video) async {
    if (_isLoading) return;

    _setLoading(true);
    _lastAction = null;

    try {
      final fb.User? user = _auth.currentUser;
      if (user == null) {
        _lastAction = FavoriteAction.error;
        notifyListeners();
        return;
      }

      final bool wasFavorited = isFavorited(video);
      final DocumentReference<Map<String, dynamic>> doc = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('favorite_videos')
          .doc(video.id);

      if (wasFavorited) {
        // Remove from favorites
        await doc.delete();
        _favoriteVideoIDs.remove(video.id);
        _lastAction = FavoriteAction.removed;
      } else {
        // Add to favorites
        await doc.set({
          'videoId': video.id,
          'favoritedAt': FieldValue.serverTimestamp(),
          'videoData': {
            'title': video.caption,
            'creatorId': video.creator.id,
            'creatorUsername': video.creator.username,
            'videoURL': video.videoURL,
            'likes': video.likes,
            'comments': video.comments,
          },
        });
        _favoriteVideoIDs.add(video.id);
        _lastAction = FavoriteAction.added;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      _lastAction = FavoriteAction.error;
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> initialize() async {
    final fb.User? user = _auth.currentUser;
    if (user == null) return;

    _setLoading(true);
    _favSub?.cancel();

    try {
      _favSub = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('favorite_videos')
          .snapshots()
          .listen((QuerySnapshot<Map<String, dynamic>> snap) {
        _favoriteVideoIDs = snap.docs.map((d) => d.id).toSet();
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Error initializing favorites: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Helper method to update loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Legacy method for backward compatibility
  bool isFavorite(String contentId) => _favoriteVideoIDs.contains(contentId);

  int get favoritesCount => _favoriteVideoIDs.length;

  @override
  void dispose() {
    _favSub?.cancel();
    super.dispose();
  }
}
