import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game.dart';
import '../models/home_video.dart';
import '../utils/video_document_rules.dart';

class GameService {
  static final GameService _instance = GameService._internal();
  factory GameService() => _instance;
  GameService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<Game>> getPopularGames({int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('games')
          .orderBy('clipCount', descending: true)
          .limit(limit)
          .get();

      if (snapshot.docs.isEmpty) {
        return GameExtension.samples;
      }

      return snapshot.docs
          .map((doc) => Game.fromFirestore(doc))
          .toList();
    } catch (e) {
      return GameExtension.samples;
    }
  }

  Future<List<Game>> searchGames(String query) async {
    if (query.isEmpty) {
      return [];
    }

    try {
      final queryLower = query.toLowerCase();
      
      final snapshot = await _firestore
          .collection('games')
          .orderBy('title')
          .limit(50)
          .get();

      final results = snapshot.docs
          .map((doc) => Game.fromFirestore(doc))
          .where((game) => game.title.toLowerCase().contains(queryLower))
          .toList();

      if (results.isEmpty) {
        return GameExtension.samples
            .where((game) => game.title.toLowerCase().contains(queryLower))
            .toList();
      }

      return results;
    } catch (e) {
      return GameExtension.samples
          .where((game) => game.title.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
  }

  Future<Game?> getGame(String gameId) async {
    try {
      final doc = await _firestore.collection('games').doc(gameId).get();
      
      if (!doc.exists) {
        return GameExtension.samples
            .where((game) => game.id == gameId)
            .firstOrNull;
      }

      return Game.fromFirestore(doc);
    } catch (e) {
      return GameExtension.samples
          .where((game) => game.id == gameId)
          .firstOrNull;
    }
  }

  Future<List<HomeVideo>> getGameVideos(
    String gameId, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('videos')
          .where('gameId', isEqualTo: gameId)
          .where('status', isEqualTo: 'ready')
          .where('isDeleted', isNotEqualTo: true)
          .orderBy('isDeleted')
          .orderBy('publishedAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) {
            try {
              return HomeVideo.fromFirestore(doc);
            } catch (e) {
              return null;
            }
          })
          .whereType<HomeVideo>()
          .where((video) => isVideoFeedEligible(doc: null, data: video.toJson()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> followGame(String gameId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('followedGames')
          .doc(gameId)
          .set({
        'followedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('games').doc(gameId).update({
        'followerCount': FieldValue.increment(1),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> unfollowGame(String gameId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('followedGames')
          .doc(gameId)
          .delete();

      await _firestore.collection('games').doc(gameId).update({
        'followerCount': FieldValue.increment(-1),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isGameFollowed(String gameId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('followedGames')
          .doc(gameId)
          .get();

      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  Future<List<Game>> getFollowedGames() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('followedGames')
          .orderBy('followedAt', descending: true)
          .get();

      final gameIds = snapshot.docs.map((doc) => doc.id).toList();

      if (gameIds.isEmpty) {
        return [];
      }

      final games = await Future.wait(
        gameIds.map((id) => getGame(id)),
      );

      return games.whereType<Game>().toList();
    } catch (e) {
      return [];
    }
  }
}
