import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/home_video.dart';
import '../models/user.dart';

class OfflineDataService {
  static final OfflineDataService _instance = OfflineDataService._internal();
  factory OfflineDataService() => _instance;
  OfflineDataService._internal();

  // Storage keys
  static const String _videosKey = 'offline_videos';
  static const String _favoritesKey = 'offline_favorites';
  static const String _followingKey = 'offline_following';
  static const String _userKey = 'offline_user';
  static const String _pendingActionsKey = 'pending_actions';

  /// Save videos for offline access
  Future<void> saveVideosOffline(List<HomeVideo> videos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Save basic video data without full serialization
      final videosData = videos.map((v) => {
        'id': v.id,
        'videoURL': v.videoURL,
        'caption': v.caption,
        'likes': v.likes,
        'comments': v.comments,
        'isLiked': v.isLiked,
        'isFavorited': v.isFavorited,
        'creatorId': v.creator.id,
        'creatorUsername': v.creator.username,
        'creatorDisplayName': v.creator.displayName,
        'creatorAvatarURL': v.creator.avatarURL,
      }).toList();
      await prefs.setString(_videosKey, json.encode(videosData));
      print('💾 Saved ${videos.length} videos offline');
    } catch (e) {
      print('❌ Error saving videos offline: $e');
    }
  }

  /// Load videos from offline storage
  Future<List<HomeVideo>> loadVideosOffline() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final videosJson = prefs.getString(_videosKey);
      
      if (videosJson != null) {
        final List<dynamic> videosList = json.decode(videosJson);
        final videos = videosList.map((v) {
          // Create User object for creator
          final creator = User(
            id: v['creatorId'] ?? '',
            username: v['creatorUsername'] ?? '',
            displayName: v['creatorDisplayName'] ?? '',
            avatarURL: v['creatorAvatarURL'] ?? '',
            bio: '', // Default values for offline data
            onlineStatus: 'offline',
            hashtags: [],
            aiSelf: '',
            postCount: 0,
            followerCount: 0,
            followingCount: 0,
          );
          
          // Create HomeVideo object
          return HomeVideo(
            id: v['id'] ?? '',
            creator: creator,
            videoURL: v['videoURL'] ?? '',
            thumbnailURL: null,
            likes: v['likes'] ?? 0,
            comments: v['comments'] ?? 0,
            views: 0,
            caption: v['caption'] ?? '',
            isLiked: v['isLiked'] ?? false,
            isFavorited: v['isFavorited'] ?? false,
            isDraft: false,
            mlScore: 0.5,
            categoryId: '',
          );
        }).toList().cast<HomeVideo>();
        print('📱 Loaded ${videos.length} videos from offline storage');
        return videos;
      }
    } catch (e) {
      print('❌ Error loading videos offline: $e');
    }
    
    return [];
  }

  /// Save favorites for offline access
  Future<void> saveFavoritesOffline(List<String> favoriteIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favoritesKey, favoriteIds);
      print('💾 Saved ${favoriteIds.length} favorites offline');
    } catch (e) {
      print('❌ Error saving favorites offline: $e');
    }
  }

  /// Load favorites from offline storage
  Future<List<String>> loadFavoritesOffline() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = prefs.getStringList(_favoritesKey) ?? [];
      print('📱 Loaded ${favorites.length} favorites from offline storage');
      return favorites;
    } catch (e) {
      print('❌ Error loading favorites offline: $e');
      return [];
    }
  }

  /// Save following list for offline access
  Future<void> saveFollowingOffline(List<String> followingIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_followingKey, followingIds);
      print('💾 Saved ${followingIds.length} following offline');
    } catch (e) {
      print('❌ Error saving following offline: $e');
    }
  }

  /// Load following list from offline storage
  Future<List<String>> loadFollowingOffline() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final following = prefs.getStringList(_followingKey) ?? [];
      print('📱 Loaded ${following.length} following from offline storage');
      return following;
    } catch (e) {
      print('❌ Error loading following offline: $e');
      return [];
    }
  }

  /// Save user data for offline access
  Future<void> saveUserOffline(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Save basic user data without full serialization
      final userData = {
        'id': user.id,
        'username': user.username,
        'displayName': user.displayName,
        'avatarURL': user.avatarURL,
        'bio': user.bio,
        'onlineStatus': user.onlineStatus,
        'postCount': user.postCount,
        'followerCount': user.followerCount,
        'followingCount': user.followingCount,
      };
      await prefs.setString(_userKey, json.encode(userData));
      print('💾 Saved user data offline');
    } catch (e) {
      print('❌ Error saving user offline: $e');
    }
  }

  /// Load user data from offline storage
  Future<User?> loadUserOffline() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      
      if (userJson != null) {
        final userData = json.decode(userJson);
        final user = User(
          id: userData['id'] ?? '',
          username: userData['username'] ?? '',
          displayName: userData['displayName'] ?? '',
          avatarURL: userData['avatarURL'] ?? '',
          bio: userData['bio'] ?? '',
          onlineStatus: userData['onlineStatus'] ?? 'offline',
          hashtags: [], // Default empty for offline data
          aiSelf: '', // Default empty for offline data
          postCount: userData['postCount'] ?? 0,
          followerCount: userData['followerCount'] ?? 0,
          followingCount: userData['followingCount'] ?? 0,
        );
        print('📱 Loaded user data from offline storage');
        return user;
      }
    } catch (e) {
      print('❌ Error loading user offline: $e');
    }
    
    return null;
  }

  /// Save pending action for later sync
  Future<void> savePendingAction(PendingAction action) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingActions = await loadPendingActions();
      existingActions.add(action);
      
      final actionsJson = existingActions.map((a) => a.toJson()).toList();
      await prefs.setString(_pendingActionsKey, json.encode(actionsJson));
      print('💾 Saved pending action: ${action.type}');
    } catch (e) {
      print('❌ Error saving pending action: $e');
    }
  }

  /// Load pending actions
  Future<List<PendingAction>> loadPendingActions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final actionsJson = prefs.getString(_pendingActionsKey);
      
      if (actionsJson != null) {
        final List<dynamic> actionsList = json.decode(actionsJson);
        final actions = actionsList.map((a) => PendingAction.fromJson(a)).toList();
        print('📱 Loaded ${actions.length} pending actions');
        return actions;
      }
    } catch (e) {
      print('❌ Error loading pending actions: $e');
    }
    
    return [];
  }

  /// Remove pending action after successful sync
  Future<void> removePendingAction(String actionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingActions = await loadPendingActions();
      existingActions.removeWhere((action) => action.id == actionId);
      
      final actionsJson = existingActions.map((a) => a.toJson()).toList();
      await prefs.setString(_pendingActionsKey, json.encode(actionsJson));
      print('🗑️ Removed pending action: $actionId');
    } catch (e) {
      print('❌ Error removing pending action: $e');
    }
  }

  /// Clear all offline data
  Future<void> clearOfflineData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_videosKey);
      await prefs.remove(_favoritesKey);
      await prefs.remove(_followingKey);
      await prefs.remove(_userKey);
      await prefs.remove(_pendingActionsKey);
      print('🗑️ Cleared all offline data');
    } catch (e) {
      print('❌ Error clearing offline data: $e');
    }
  }

  /// Get offline data statistics
  Future<OfflineDataStatistics> getOfflineDataStatistics() async {
    try {
      final videos = await loadVideosOffline();
      final favorites = await loadFavoritesOffline();
      final following = await loadFollowingOffline();
      final pendingActions = await loadPendingActions();
      
      return OfflineDataStatistics(
        videoCount: videos.length,
        favoriteCount: favorites.length,
        followingCount: following.length,
        pendingActionCount: pendingActions.length,
        hasUserData: await loadUserOffline() != null,
      );
    } catch (e) {
      print('❌ Error getting offline data statistics: $e');
      return OfflineDataStatistics(
        videoCount: 0,
        favoriteCount: 0,
        followingCount: 0,
        pendingActionCount: 0,
        hasUserData: false,
      );
    }
  }
}

/// Pending action data class
class PendingAction {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final int retryCount;

  PendingAction({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'retryCount': retryCount,
  };

  factory PendingAction.fromJson(Map<String, dynamic> json) => PendingAction(
    id: json['id'] as String,
    type: json['type'] as String,
    data: Map<String, dynamic>.from(json['data'] as Map),
    timestamp: DateTime.parse(json['timestamp'] as String),
    retryCount: json['retryCount'] as int? ?? 0,
  );

  PendingAction copyWith({
    String? id,
    String? type,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    int? retryCount,
  }) => PendingAction(
    id: id ?? this.id,
    type: type ?? this.type,
    data: data ?? this.data,
    timestamp: timestamp ?? this.timestamp,
    retryCount: retryCount ?? this.retryCount,
  );
}

/// Offline data statistics
class OfflineDataStatistics {
  final int videoCount;
  final int favoriteCount;
  final int followingCount;
  final int pendingActionCount;
  final bool hasUserData;

  OfflineDataStatistics({
    required this.videoCount,
    required this.favoriteCount,
    required this.followingCount,
    required this.pendingActionCount,
    required this.hasUserData,
  });

  int get totalItems => videoCount + favoriteCount + followingCount + pendingActionCount;
  bool get hasData => totalItems > 0 || hasUserData;
}
