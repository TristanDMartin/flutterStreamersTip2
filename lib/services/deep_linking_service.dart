import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/home_video.dart';
import '../models/user_count_fields.dart';
import '../models/user.dart' as app_user;
import '../routing/app_routes.dart';
import '../utils/video_url_resolver.dart';
import '../widgets/player_screen.dart';
import 'profile_link_service.dart';
import 'logging_service.dart';

class DeepLinkingService {
  static final DeepLinkingService _instance = DeepLinkingService._internal();
  factory DeepLinkingService() => _instance;
  DeepLinkingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  /// Initialize deep linking
  void initialize() {
    // This would typically be called in main.dart
    LoggingService.instance
        .debug('Deep linking service initialized', tag: 'DeepLinkingService');
  }

  /// Handle incoming deep link
  Future<void> handleDeepLink(String link, BuildContext context) async {
    try {
      LoggingService.instance
          .debug('Handling deep link: $link', tag: 'DeepLinkingService');

      final uri = Uri.parse(link);
      final path = uri.path;
      final queryParams = uri.queryParameters;

      // Handle different deep link patterns
      if (path.startsWith('/invite/')) {
        await _handleInviteLink(path, queryParams, context);
      } else if (path.startsWith('/user/')) {
        await _handleUserLink(path, queryParams, context);
      } else if (path.startsWith('/profile/')) {
        await _handleProfileLink(path, queryParams, context);
      } else if (path.startsWith('/video/')) {
        await _handleVideoLink(path, queryParams, context);
      } else if (path.startsWith('/hashtag/')) {
        await _handleHashtagLink(path, queryParams, context);
      } else {
        LoggingService.instance.warning('Unknown deep link pattern: $path',
            tag: 'DeepLinkingService');
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error handling deep link',
          tag: 'DeepLinkingService', error: e, stackTrace: stackTrace);
      if (context.mounted) {
        _showDeepLinkError(context, 'Failed to open link');
      }
    }
  }

  /// Handle invite deep link
  Future<void> _handleInviteLink(String path, Map<String, String> queryParams,
      BuildContext context) async {
    try {
      final inviteCode = path.split('/invite/')[1];
      if (inviteCode.isEmpty) {
        throw Exception('Invalid invite code');
      }

      // Check if user is authenticated
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        // Store invite code for later processing after login
        await _storePendingInviteCode(inviteCode);

        // Navigate to login with invite code
        if (context.mounted) {
          _replaceWithNamedRoute(context, AppRoutes.auth);
        }
        return;
      }

      // Process the invite code
      final success = await _processInviteCode(inviteCode, currentUser.uid);

      if (context.mounted) {
        if (success) {
          _showDeepLinkSuccess(
              context, 'Welcome! You\'ve joined with an invite code.');
          _replaceWithNamedRoute(context, AppRoutes.home);
        } else {
          _showDeepLinkError(context, 'Invalid or expired invite code');
          _replaceWithNamedRoute(context, AppRoutes.home);
        }
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error handling invite link',
          tag: 'DeepLinkingService', error: e, stackTrace: stackTrace);
      if (context.mounted) {
        _showDeepLinkError(context, 'Failed to process invite');
      }
    }
  }

  /// Handle user profile deep link
  Future<void> _handleUserLink(String path, Map<String, String> queryParams,
      BuildContext context) async {
    try {
      final username = path.split('/user/')[1];
      if (username.isEmpty) {
        throw Exception('Invalid username');
      }

      // Find user by username
      final userQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        throw Exception('User not found');
      }

      final userDoc = userQuery.docs.first;
      final userId = userDoc.id;
      final user = _buildUser(userDoc.data(), userId);

      if (context.mounted) {
        Navigator.of(context).pushNamed(
          AppRoutes.profile,
          arguments: ProfileRouteArgs(
            user: user,
            isCurrentUser: _auth.currentUser?.uid == userId,
          ),
        );
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error handling user link',
          tag: 'DeepLinkingService', error: e, stackTrace: stackTrace);
      if (context.mounted) {
        _showDeepLinkError(context, 'User not found');
      }
    }
  }

  /// Handle video deep link
  Future<void> _handleVideoLink(String path, Map<String, String> queryParams,
      BuildContext context) async {
    try {
      final videoId = path.split('/video/')[1];
      if (videoId.isEmpty) {
        throw Exception('Invalid video ID');
      }

      // Check if video exists
      final videoDoc = await _firestore.collection('videos').doc(videoId).get();
      if (!videoDoc.exists) {
        throw Exception('Video not found');
      }

      final homeVideo = _buildHomeVideo(videoDoc.data()!, videoId);

      if (context.mounted) {
        Navigator.of(context).pushNamed(
          AppRoutes.player,
          arguments: PlayerRouteArgs(
            mode: PlayerMode.homeFeed,
            initialIndex: 0,
            videoIds: [videoId],
            videos: [homeVideo],
          ),
        );
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error handling video link',
          tag: 'DeepLinkingService', error: e, stackTrace: stackTrace);
      if (context.mounted) {
        _showDeepLinkError(context, 'Video not found');
      }
    }
  }

  Future<void> _handleProfileLink(String path, Map<String, String> queryParams,
      BuildContext context) async {
    try {
      final identifier = path.split('/profile/')[1];
      if (identifier.isEmpty) {
        throw Exception('Invalid profile identifier');
      }

      if (identifier.length >= 20) {
        final userDoc = await _firestore.collection('users').doc(identifier).get();
        if (!userDoc.exists) {
          throw Exception('User not found');
        }
        final user = _buildUser(userDoc.data()!, userDoc.id);
        if (context.mounted) {
          Navigator.of(context).pushNamed(
            AppRoutes.profile,
            arguments: ProfileRouteArgs(
              user: user,
              isCurrentUser: _auth.currentUser?.uid == userDoc.id,
            ),
          );
        }
        return;
      }

      await _handleUserLink('/user/$identifier', queryParams, context);
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error handling profile link',
          tag: 'DeepLinkingService', error: e, stackTrace: stackTrace);
      if (context.mounted) {
        _showDeepLinkError(context, 'Profile not found');
      }
    }
  }

  /// Handle hashtag deep link
  Future<void> _handleHashtagLink(String path, Map<String, String> queryParams,
      BuildContext context) async {
    try {
      final hashtag = path.split('/hashtag/')[1];
      if (hashtag.isEmpty) {
        throw Exception('Invalid hashtag');
      }

      if (context.mounted) {
        Navigator.of(context).pushNamed(AppRoutes.discover);
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error handling hashtag link',
          tag: 'DeepLinkingService', error: e, stackTrace: stackTrace);
      if (context.mounted) {
        _showDeepLinkError(context, 'Hashtag not found');
      }
    }
  }

  /// Process invite code
  Future<bool> _processInviteCode(String inviteCode, String userId) async {
    try {
      // Find the invite
      final inviteQuery = await _firestore
          .collection('invites')
          .where('inviteCode', isEqualTo: inviteCode)
          .where('status', isEqualTo: 'sent')
          .limit(1)
          .get();

      if (inviteQuery.docs.isEmpty) {
        return false;
      }

      final inviteDoc = inviteQuery.docs.first;
      final inviteData = inviteDoc.data();
      final inviterId = inviteData['inviterId'] as String;

      // Update invite status
      await inviteDoc.reference.update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'acceptedBy': userId,
      });

      // Create relationship
      await _createInviteRelationship(inviterId, userId);

      // Award points to inviter
      await _awardInvitePoints(inviterId);

      LoggingService.instance.debug('Processed invite code: $inviteCode',
          tag: 'DeepLinkingService');
      return true;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error processing invite code',
          tag: 'DeepLinkingService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Store pending invite code for later processing
  Future<void> _storePendingInviteCode(String inviteCode) async {
    try {
      // Store in local storage or shared preferences
      // This is a simplified version - in production, use proper local storage
      LoggingService.instance.debug('Stored pending invite code: $inviteCode',
          tag: 'DeepLinkingService');
    } catch (e) {
      LoggingService.instance.error('Error storing pending invite code',
          tag: 'DeepLinkingService', error: e);
    }
  }

  /// Create relationship between inviter and invitee
  Future<void> _createInviteRelationship(
      String inviterId, String inviteeId) async {
    try {
      final batch = _firestore.batch();

      // Add invitee to inviter's connections
      final inviterConnectionsRef = _firestore
          .collection('users')
          .doc(inviterId)
          .collection('connections')
          .doc(inviteeId);

      batch.set(inviterConnectionsRef, {
        'userId': inviteeId,
        'type': 'invited',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Add inviter to invitee's connections
      final inviteeConnectionsRef = _firestore
          .collection('users')
          .doc(inviteeId)
          .collection('connections')
          .doc(inviterId);

      batch.set(inviteeConnectionsRef, {
        'userId': inviterId,
        'type': 'inviter',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      LoggingService.instance.error('Error creating invite relationship',
          tag: 'DeepLinkingService', error: e);
    }
  }

  /// Award points to inviter
  Future<void> _awardInvitePoints(String inviterId) async {
    try {
      const pointsToAward = 100;

      await _firestore.collection('users').doc(inviterId).update({
        'points': FieldValue.increment(pointsToAward),
        'totalInvites': FieldValue.increment(1),
        'lastInviteAwardedAt': FieldValue.serverTimestamp(),
      });

      LoggingService.instance.debug(
          'Awarded $pointsToAward points to inviter: $inviterId',
          tag: 'DeepLinkingService');
    } catch (e) {
      LoggingService.instance.error('Error awarding invite points',
          tag: 'DeepLinkingService', error: e);
    }
  }

  /// Show deep link success message
  void _showDeepLinkSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show deep link error message
  void _showDeepLinkError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Generate deep link for invite
  String generateInviteLink(String inviteCode) {
    return 'https://streamerstip.app/invite/$inviteCode';
  }

  /// Generate deep link for user profile
  String generateUserLink(String userIdOrUsername) {
    return ProfileLinkService.publicProfileUrl(
      username: userIdOrUsername.length < 20 ? userIdOrUsername : null,
      userId: userIdOrUsername.length >= 20 ? userIdOrUsername : null,
    );
  }

  /// Generate deep link for video
  String generateVideoLink(String videoId) {
    return 'https://streamerstip.app/video/$videoId';
  }

  /// Generate deep link for hashtag
  String generateHashtagLink(String hashtag) {
    return 'https://streamerstip.app/hashtag/${Uri.encodeComponent(hashtag)}';
  }

  void _replaceWithNamedRoute(BuildContext context, String routeName) {
    Navigator.of(context).pushNamedAndRemoveUntil(routeName, (route) => false);
  }

  app_user.User _buildUser(Map<String, dynamic> data, String userId) {
    return app_user.User.fromMap({
      ...data,
      'id': userId,
      'uid': userId,
    });
  }

  HomeVideo _buildHomeVideo(Map<String, dynamic> data, String videoId) {
    final followerCount = UserCountFields.readFollowersCount(data);
    final followingCount = UserCountFields.readFollowingCount(data);
    return HomeVideo(
      id: videoId,
      creator: _buildUser({
        'id': data['userId'] ?? '',
        'uid': data['userId'] ?? '',
        'displayName': data['displayName'] ?? 'Unknown',
        'username': data['username'] ?? 'unknown',
        'avatarURL': data['userAvatarUrl'] ?? data['avatarURL'],
        'bio': data['bio'] ?? '',
        'onlineStatus': data['onlineStatus'] ?? 'offline',
        'hashtags': data['hashtags'] ?? const <String>[],
        'followerCount': followerCount,
        'followersCount': followerCount,
        'followingCount': followingCount,
        'postCount': data['postCount'] ?? 0,
      }, data['userId'] ?? ''),
      videoURL: resolveVideoUrl(data),
      thumbnailURL: data['thumbnailUrl'] ?? data['thumbnailURL'],
      likes: data['likeCount'] ?? 0,
      comments: data['commentCount'] ?? 0,
      views: data['viewCount'] ?? 0,
      caption: data['caption'] ?? '',
      categoryId: data['category'] ?? 'general',
      createdAt: data['timestamp'] as Timestamp?,
    );
  }
}
