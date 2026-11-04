import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../models/game.dart';
import '../models/home_video.dart';
import '../models/user.dart';

class GameService {
  static final GameService _instance = GameService._internal();
  factory GameService() => _instance;
  GameService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;

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

      final videos = <HomeVideo>[];
      
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          
          if (data['isDeleted'] == true) continue;
          if (data['status'] != 'published' && data['status'] != 'ready') continue;
          
          final userDoc = await _firestore
              .collection('users')
              .doc(data['userId'] as String?)
              .get();
          
          if (!userDoc.exists) continue;
          
          final userData = userDoc.data()!;
          final user = User(
            id: userDoc.id,
            username: userData['username'] as String? ?? '',
            displayName: userData['displayName'] as String? ?? '',
            bio: userData['bio'] as String? ?? '',
            avatarURL: userData['avatarURL'] as String? ?? '',
          );
          
          videos.add(HomeVideo(
            id: doc.id,
            creator: user,
            videoURL: data['videoUrl'] as String? ?? data['videoURL'] as String? ?? '',
            thumbnailURL: data['thumbnailUrl'] as String? ?? data['thumbnailURL'] as String?,
            likes: data['likes'] as int? ?? data['likeCount'] as int? ?? 0,
            comments: data['comments'] as int? ?? data['commentCount'] as int? ?? 0,
            views: data['views'] as int? ?? data['viewCount'] as int? ?? 0,
            caption: data['caption'] as String? ?? '',
            isLiked: false,
            duration: (data['duration'] as num?)?.toDouble(),
            createdAt: data['createdAt'] as Timestamp?,
            status: data['status'] as String? ?? 'published',
            categoryId: data['categoryId'] as String? ?? '',
          ));
        } catch (e) {
          continue;
        }
      }
      
      return videos;
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
