import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/avatar_url_resolver.dart';
import '../utils/video_url_resolver.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/user.dart' as app_user;
import '../models/user_count_fields.dart';
import '../models/calendar_event.dart';
import '../models/home_video.dart';

class ProfileServiceOptimized {
  static final ProfileServiceOptimized _instance =
      ProfileServiceOptimized._internal();
  factory ProfileServiceOptimized() => _instance;
  ProfileServiceOptimized._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  // Cache for better performance
  final Map<String, app_user.User> _userCache = {};
  final Map<String, List<HomeVideo>> _videosCache = {};
  final Map<String, List<CalendarEvent>> _eventsCache = {};

  /// Get user profile
  Future<app_user.User?> getUserProfile(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final user = _mapUser(doc.id, doc.data()!);
        _userCache[userId] = user;
        return user;
      }
      return null;
    } catch (e) {
      // print('Error getting user profile: $e');
      return null;
    }
  }

  /// Get user's videos
  Future<List<HomeVideo>> getUserVideos(String userId) async {
    if (_videosCache.containsKey(userId)) {
      return _videosCache[userId]!;
    }

    try {
      final query = await _firestore
          .collection('videos')
          .where('creatorId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      final videos = <HomeVideo>[];
      for (final doc in query.docs) {
        final video = _mapVideo(doc.id, doc.data());
        videos.add(video);
      }

      _videosCache[userId] = videos;
      return videos;
    } catch (e) {
      // print('Error getting user videos: $e');
      return [];
    }
  }

  /// Get user's calendar events
  Future<List<CalendarEvent>> getUserEvents(String userId) async {
    if (_eventsCache.containsKey(userId)) {
      return _eventsCache[userId]!;
    }

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final events = <CalendarEvent>[];

        if (data['calendarEvents'] != null) {
          final eventsData = data['calendarEvents'] as List<dynamic>;
          for (final eventData in eventsData) {
            final eventMap = eventData as Map<String, dynamic>;
            events.add(CalendarEvent(
              id: eventMap['id'] as String,
              title: eventMap['title'] as String,
              description: eventMap['description'] as String,
              date: (eventMap['date'] as Timestamp).toDate(),
            ));
          }
        }

        _eventsCache[userId] = events;
        return events;
      }
      return [];
    } catch (e) {
      // print('Error getting user events: $e');
      return [];
    }
  }

  /// Get user's platforms
  Future<List<Map<String, dynamic>>> getUserPlatforms(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final platforms = <Map<String, dynamic>>[];

        if (data['platforms'] != null) {
          final platformsData = data['platforms'] as List<dynamic>;
          for (final platformData in platformsData) {
            final platformMap = platformData as Map<String, dynamic>;
            platforms.add({
              'id': platformMap['id'] ?? '',
              'type': platformMap['type'] ?? '',
              'username': platformMap['username'] ?? '',
              'followers': platformMap['followers'] ?? 0,
              'url': platformMap['url'],
            });
          }
        }

        return platforms;
      }
      return [];
    } catch (e) {
      // print('Error getting user platforms: $e');
      return [];
    }
  }

  /// Update user profile
  Future<bool> updateUserProfile(
      String userId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('users').doc(userId).update(updates);

      // Clear cache
      _userCache.remove(userId);

      return true;
    } catch (e) {
      // print('Error updating user profile: $e');
      return false;
    }
  }

  /// Follow a user
  Future<bool> followUser(String userId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final batch = _firestore.batch();

      // Create relationship document
      final relationshipRef = _firestore.collection('relationships').doc();
      batch.set(relationshipRef, {
        'followerId': currentUser.uid,
        'followingId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update follower count
      final userRef = _firestore.collection('users').doc(userId);
      batch.update(userRef, {
        'followerCount': FieldValue.increment(1),
      });

      // Update following count
      final currentUserRef =
          _firestore.collection('users').doc(currentUser.uid);
      batch.update(currentUserRef, {
        'followingCount': FieldValue.increment(1),
      });

      await batch.commit();

      // Clear cache
      _userCache.remove(userId);
      _userCache.remove(currentUser.uid);

      return true;
    } catch (e) {
      // print('Error following user: $e');
      return false;
    }
  }

  /// Unfollow a user
  Future<bool> unfollowUser(String userId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final batch = _firestore.batch();

      // Find and delete relationship
      final relationshipQuery = await _firestore
          .collection('relationships')
          .where('followerId', isEqualTo: currentUser.uid)
          .where('followingId', isEqualTo: userId)
          .get();

      for (final doc in relationshipQuery.docs) {
        batch.delete(doc.reference);
      }

      // Update follower count
      final userRef = _firestore.collection('users').doc(userId);
      batch.update(userRef, {
        'followerCount': FieldValue.increment(-1),
      });

      // Update following count
      final currentUserRef =
          _firestore.collection('users').doc(currentUser.uid);
      batch.update(currentUserRef, {
        'followingCount': FieldValue.increment(-1),
      });

      await batch.commit();

      // Clear cache
      _userCache.remove(userId);
      _userCache.remove(currentUser.uid);

      return true;
    } catch (e) {
      // print('Error unfollowing user: $e');
      return false;
    }
  }

  /// Check if user is following another user
  Future<bool> isFollowing(String userId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final query = await _firestore
          .collection('relationships')
          .where('followerId', isEqualTo: currentUser.uid)
          .where('followingId', isEqualTo: userId)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      // print('Error checking follow status: $e');
      return false;
    }
  }

  /// Listen to user profile changes
  Stream<app_user.User?> listenToUserProfile(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        final user = _mapUser(snapshot.id, snapshot.data()!);
        _userCache[userId] = user;
        return user;
      }
      return null;
    });
  }

  /// Map Firestore document to User model
  app_user.User _mapUser(String id, Map<String, dynamic> data) {
    return app_user.User(
      id: id,
      displayName: (data['displayName'] ?? 'User').toString(),
      username: (data['username'] ?? 'user').toString(),
      avatarURL: resolveAvatarUrl(data),
      onlineStatus: (data['onlineStatus'] ?? 'offline').toString(),
      hashtags: List<String>.from(data['hashtags'] ?? []),
      aiSelf: data['aiSelf']?.toString() ?? '',
      postCount: data['postCount'] ?? 0,
      followerCount: UserCountFields.readFollowersCount(data),
      followingCount: UserCountFields.readFollowingCount(data),
      calendarEvents: [],
    );
  }

  /// Map Firestore document to HomeVideo model
  HomeVideo _mapVideo(String id, Map<String, dynamic> data) {
    return HomeVideo(
      id: id,
      videoURL: resolveVideoUrl(data),
      thumbnailURL: data['thumbnailURL'] ?? '',
      caption: data['caption'] ?? '',
      creator: app_user.User(
        id: data['creatorId'] ?? '',
        displayName: data['creatorName'] ?? 'User',
        username: data['creatorUsername'] ?? 'user',
        avatarURL: data['creatorAvatar'],
        onlineStatus: 'offline',
        hashtags: [],
        aiSelf: '',
        postCount: 0,
        followerCount: 0,
        followingCount: 0,
        calendarEvents: [],
      ),
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
      isLiked: data['isLiked'] ?? false,
      isFavorited: data['isFavorited'] ?? false,
    );
  }

  /// Clear cache
  void clearCache() {
    _userCache.clear();
    _videosCache.clear();
    _eventsCache.clear();
  }

  /// Expose auth for external access
  firebase_auth.FirebaseAuth get auth => _auth;
}
