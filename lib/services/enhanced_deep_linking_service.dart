import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/chat.dart';
import '../models/home_video.dart';
import '../models/user_count_fields.dart';
import '../models/user.dart' as app_user;
import '../routing/app_routes.dart';
import '../services/pending_auth_redirect_service.dart';
import 'profile_link_service.dart';
import '../routing/app_navigator.dart';
import '../utils/video_url_resolver.dart';
import '../utils/video_document_rules.dart';
import '../widgets/player_screen.dart';
import '../utils/sensitive_data_redactor.dart';
import 'logging_service.dart';

class EnhancedDeepLinkingService {
  static final EnhancedDeepLinkingService _instance =
      EnhancedDeepLinkingService._internal();
  factory EnhancedDeepLinkingService() => _instance;
  EnhancedDeepLinkingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  // Stream controller for deep link events
  final StreamController<DeepLinkEvent> _deepLinkController =
      StreamController<DeepLinkEvent>.broadcast();
  Stream<DeepLinkEvent> get deepLinkStream => _deepLinkController.stream;

  // Pending deep link storage
  String? _pendingDeepLink;

  /// Initialize enhanced deep linking
  void initialize() {
    LoggingService.instance.info(
      '🔗 EnhancedDeepLinkingService: Initializing enhanced deep linking',
      tag: 'EnhancedDeepLinkingService',
    );
  }

  /// Handle incoming deep link with enhanced processing
  Future<void> handleDeepLink(String link, BuildContext context) async {
    try {
      LoggingService.instance.info(
        '🔗 EnhancedDeepLinkingService: Handling deep link: '
        '${SensitiveDataRedactor.redact(link)}',
        tag: 'EnhancedDeepLinkingService',
      );

      final uri = Uri.parse(link);
      final path = uri.path;
      final queryParams = uri.queryParameters;

      // Emit deep link event
      _deepLinkController.add(DeepLinkEvent(
        link: link,
        path: path,
        queryParams: queryParams,
        timestamp: DateTime.now(),
      ));

      // Handle different deep link patterns with enhanced processing
      if (path.startsWith('/invite/')) {
        await _handleInviteLink(path, queryParams, context);
      } else if (path.startsWith('/user/')) {
        await _handleUserLink(path, queryParams, context);
      } else if (path.startsWith('/video/')) {
        await _handleVideoLink(path, queryParams, context);
      } else if (path.startsWith('/hashtag/')) {
        await _handleHashtagLink(path, queryParams, context);
      } else if (path.startsWith('/profile/')) {
        await _handleProfileLink(path, queryParams, context);
      } else if (path.startsWith('/chat/')) {
        await _handleChatLink(path, queryParams, context);
      } else if (path.startsWith('/discover')) {
        await _handleDiscoverLink(path, queryParams, context);
      } else {
        LoggingService.instance.warning(
          'Unknown deep link pattern: $path',
          tag: 'EnhancedDeepLinkingService',
        );
        await _handleUnknownLink(link, context);
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Error handling deep link',
        tag: 'EnhancedDeepLinkingService',
        error: e,
        stackTrace: stackTrace,
      );
      if (context.mounted) {
        await _showDeepLinkError(
            context, 'Failed to open link: ${e.toString()}');
      }
    }
  }

  /// Handle invite deep link with enhanced validation
  Future<void> _handleInviteLink(String path, Map<String, String> queryParams,
      BuildContext context) async {
    try {
      final inviteCode = path.split('/invite/')[1];
      if (inviteCode.isEmpty) {
        throw Exception('Invalid invite code');
      }

      LoggingService.instance.info(
        '🎫 EnhancedDeepLinkingService: Processing invite code: $inviteCode',
        tag: 'EnhancedDeepLinkingService',
      );

      // Check if user is authenticated
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        // Store invite code for later processing after login
        await _storePendingInviteCode(inviteCode);

        if (context.mounted) {
          _replaceWithNamedRoute(context, AppRoutes.auth);
        }
        return;
      }

      // Process the invite code
      final success = await _processInviteCode(inviteCode, currentUser.uid);

      if (context.mounted) {
        if (success) {
          await _showDeepLinkSuccess(
            context,
            'Welcome! You\'ve joined with an invite code.',
          );
          if (context.mounted) {
            _replaceWithNamedRoute(context, AppRoutes.home);
          }
        } else {
          await _showDeepLinkError(context, 'Invalid or expired invite code');
          if (context.mounted) {
            _replaceWithNamedRoute(context, AppRoutes.home);
          }
        }
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Error handling invite link',
        tag: 'EnhancedDeepLinkingService',
        error: e,
        stackTrace: stackTrace,
      );
      if (context.mounted) {
        await _showDeepLinkError(context, 'Failed to process invite');
      }
    }
  }

  /// Handle user profile deep link with enhanced validation
  Future<void> _handleUserLink(String path, Map<String, String> queryParams,
      BuildContext context) async {
    try {
      final username = path.split('/user/')[1];
      if (username.isEmpty) {
        throw Exception('Invalid username');
      }

      LoggingService.instance.info(
        '👤 EnhancedDeepLinkingService: Processing user link: $username',
        tag: 'EnhancedDeepLinkingService',
      );

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
      LoggingService.instance.error(
        'Error handling user link',
        tag: 'EnhancedDeepLinkingService',
        error: e,
        stackTrace: stackTrace,
      );
      if (context.mounted) {
        await _showDeepLinkError(context, 'User not found');
      }
    }
  }

  /// Handle video deep link with enhanced validation and analytics
  Future<void> _handleVideoLink(String path, Map<String, String> queryParams,
      BuildContext context) async {
    try {
      final videoId = path.split('/video/')[1];
      if (videoId.isEmpty) {
        throw Exception('Invalid video ID');
      }

      LoggingService.instance.info(
        '🎬 EnhancedDeepLinkingService: Processing video link: $videoId',
        tag: 'EnhancedDeepLinkingService',
      );

      // Check if video exists and is accessible
      final videoDoc = await _firestore.collection('videos').doc(videoId).get();
      if (!videoDoc.exists) {
        throw Exception('Video not found');
      }

      final videoData = videoDoc.data()!;

      if (!isVideoVisibleInFeed(videoData)) {
        if (context.mounted) {
          await AppNavigator.openVideoUnavailable(context, videoId: videoId);
        }
        return;
      }

      // Check if video is public or user has access
      final privacy = videoData['privacy'] as String?;
      final currentUser = _auth.currentUser;

      if (privacy == 'private' && currentUser == null) {
        throw Exception('Video is private and requires authentication');
      }

      // Track video view from deep link
      await _trackVideoViewFromDeepLink(videoId, queryParams);

      final homeVideo = _buildHomeVideo(videoData, videoId);

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
      LoggingService.instance.error(
        'Error handling video link',
        tag: 'EnhancedDeepLinkingService',
        error: e,
        stackTrace: stackTrace,
      );
      if (context.mounted) {
        await _showDeepLinkError(context, 'Video not found or inaccessible');
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

      LoggingService.instance.info(
        '🏷️ EnhancedDeepLinkingService: Processing hashtag link: $hashtag',
        tag: 'EnhancedDeepLinkingService',
      );

      if (context.mounted) {
        Navigator.of(context).pushNamed(AppRoutes.discover);
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Error handling hashtag link',
        tag: 'EnhancedDeepLinkingService',
        error: e,
        stackTrace: stackTrace,
      );
      if (context.mounted) {
        await _showDeepLinkError(context, 'Hashtag not found');
      }
    }
  }

  /// Handle profile deep link (alternative to user link)
  Future<void> _handleProfileLink(String path, Map<String, String> queryParams,
      BuildContext context) async {
    try {
      final String identifier = Uri.decodeComponent(
        path.split('/profile/')[1].split('?').first,
      );
      if (identifier.isEmpty) {
        throw Exception('Invalid profile identifier');
      }

      LoggingService.instance.info(
        '👤 EnhancedDeepLinkingService: Processing profile link: '
        '${SensitiveDataRedactor.maskId(identifier)}',
        tag: 'EnhancedDeepLinkingService',
      );

      if (!SensitiveDataRedactor.looksLikeFirebaseUid(identifier)) {
        await _handleUserLink('/user/$identifier', queryParams, context);
        return;
      }

      final userDoc =
          await _firestore.collection('users').doc(identifier).get();
      if (!userDoc.exists) {
        throw Exception('Profile not found');
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
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Error handling profile link',
        tag: 'EnhancedDeepLinkingService',
        error: e,
        stackTrace: stackTrace,
      );
      if (context.mounted) {
        await _showDeepLinkError(context, 'Profile not found');
      }
    }
  }

  /// Handle chat deep link
  Future<void> _handleChatLink(String path, Map<String, String> queryParams,
      BuildContext context) async {
    try {
      final chatId = path.split('/chat/')[1];
      if (chatId.isEmpty) {
        throw Exception('Invalid chat ID');
      }

      LoggingService.instance.info(
        '💬 EnhancedDeepLinkingService: Processing chat link: $chatId',
        tag: 'EnhancedDeepLinkingService',
      );

      // Check if user is authenticated
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        if (context.mounted) {
          PendingAuthRedirectService.instance.setAction((redirectContext) {
            return _handleChatLink(
                '/chat/$chatId', queryParams, redirectContext);
          });
          if (context.mounted) {
            _replaceWithNamedRoute(context, AppRoutes.auth);
          }
        }
        return;
      }

      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) {
        throw Exception('Chat not found');
      }

      final chat = Chat.fromJson({
        ...chatDoc.data()!,
        'id': chatDoc.id,
      });

      final otherUserId = chat.participants.firstWhere(
        (participantId) => participantId != currentUser.uid,
        orElse: () => currentUser.uid,
      );

      String otherUserName = 'Messages';
      String? otherUserAvatarUrl;
      bool otherUserIsOnline = false;

      if (otherUserId != currentUser.uid) {
        final otherUserDoc =
            await _firestore.collection('users').doc(otherUserId).get();
        final otherUserData = otherUserDoc.data();
        if (otherUserData != null) {
          otherUserName = (otherUserData['displayName'] ??
                  otherUserData['username'] ??
                  'Messages')
              .toString();
          otherUserAvatarUrl =
              (otherUserData['avatarURL'] ?? otherUserData['userAvatarUrl'])
                  ?.toString();
          otherUserIsOnline = otherUserData['onlineStatus'] == 'online';
        }
      }

      if (context.mounted) {
        Navigator.of(context).pushNamed(
          AppRoutes.chat,
          arguments: ChatRouteArgs(
            chat: chat,
            otherUserId: otherUserId,
            otherUserName: otherUserName,
            otherUserAvatarUrl: otherUserAvatarUrl,
            otherUserIsOnline: otherUserIsOnline,
          ),
        );
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Error handling chat link',
        tag: 'EnhancedDeepLinkingService',
        error: e,
        stackTrace: stackTrace,
      );
      if (context.mounted) {
        await _showDeepLinkError(context, 'Chat not found');
      }
    }
  }

  /// Handle discover deep link
  Future<void> _handleDiscoverLink(String path, Map<String, String> queryParams,
      BuildContext context) async {
    try {
      LoggingService.instance.info(
        '🔍 EnhancedDeepLinkingService: Processing discover link',
        tag: 'EnhancedDeepLinkingService',
      );

      if (context.mounted) {
        Navigator.of(context).pushNamed(AppRoutes.discover);
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Error handling discover link',
        tag: 'EnhancedDeepLinkingService',
        error: e,
        stackTrace: stackTrace,
      );
      if (context.mounted) {
        await _showDeepLinkError(context, 'Failed to open discover');
      }
    }
  }

  /// Handle unknown deep link patterns
  Future<void> _handleUnknownLink(String link, BuildContext context) async {
    try {
      LoggingService.instance.warning(
        '❓ EnhancedDeepLinkingService: Unknown deep link pattern: $link',
        tag: 'EnhancedDeepLinkingService',
      );

      // Try to extract video ID from various patterns
      final videoIdMatch =
          RegExp(r'video[\/\?]([a-zA-Z0-9_-]+)').firstMatch(link);
      if (videoIdMatch != null) {
        final videoId = videoIdMatch.group(1)!;
        await _handleVideoLink('/video/$videoId', {}, context);
        return;
      }

      // Try to extract user ID from various patterns
      final userIdMatch =
          RegExp(r'user[\/\?]([a-zA-Z0-9_-]+)').firstMatch(link);
      if (userIdMatch != null) {
        final userId = userIdMatch.group(1)!;
        await _handleUserLink('/user/$userId', {}, context);
        return;
      }

      // Default to home
      if (context.mounted) {
        _replaceWithNamedRoute(context, AppRoutes.home);
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Error handling unknown link',
        tag: 'EnhancedDeepLinkingService',
        error: e,
        stackTrace: stackTrace,
      );
      if (context.mounted) {
        _replaceWithNamedRoute(context, AppRoutes.home);
      }
    }
  }

  /// Process invite code with enhanced validation
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

      LoggingService.instance.info(
        '✅ EnhancedDeepLinkingService: Processed invite code: $inviteCode',
        tag: 'EnhancedDeepLinkingService',
      );
      return true;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Error processing invite code',
        tag: 'EnhancedDeepLinkingService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Store pending invite code for later processing
  Future<void> _storePendingInviteCode(String inviteCode) async {
    try {
      _pendingDeepLink = '/invite/$inviteCode';
      LoggingService.instance.info(
        '💾 EnhancedDeepLinkingService: Stored pending invite code: $inviteCode',
        tag: 'EnhancedDeepLinkingService',
      );
    } catch (e) {
      LoggingService.instance.error(
        'Error storing pending invite code',
        tag: 'EnhancedDeepLinkingService',
        error: e,
      );
    }
  }

  /// Get pending deep link
  String? getPendingDeepLink() {
    return _pendingDeepLink;
  }

  /// Clear pending deep link
  void clearPendingDeepLink() {
    _pendingDeepLink = null;
  }

  /// Track video view from deep link
  Future<void> _trackVideoViewFromDeepLink(
      String videoId, Map<String, String> queryParams) async {
    try {
      // Track analytics for deep link video views
      await _firestore.collection('analytics').add({
        'type': 'video_view_deep_link',
        'videoId': videoId,
        'queryParams': queryParams,
        'timestamp': FieldValue.serverTimestamp(),
        'source': queryParams['utm_source'] ?? 'unknown',
        'medium': queryParams['utm_medium'] ?? 'unknown',
      });

      LoggingService.instance.info(
        '📊 EnhancedDeepLinkingService: Tracked video view from deep link: $videoId',
        tag: 'EnhancedDeepLinkingService',
      );
    } catch (e) {
      LoggingService.instance.error(
        'Error tracking video view from deep link',
        tag: 'EnhancedDeepLinkingService',
        error: e,
      );
    }
  }

  /// Create invite relationship
  Future<void> _createInviteRelationship(
      String inviterId, String userId) async {
    try {
      await _firestore.collection('relationships').add({
        'type': 'invite',
        'fromUserId': inviterId,
        'toUserId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      LoggingService.instance.error(
        'Error creating invite relationship',
        tag: 'EnhancedDeepLinkingService',
        error: e,
      );
    }
  }

  /// Award invite points
  Future<void> _awardInvitePoints(String inviterId) async {
    try {
      await _firestore.collection('users').doc(inviterId).update({
        'points':
            FieldValue.increment(100), // Award 100 points for successful invite
        'inviteCount': FieldValue.increment(1),
      });
    } catch (e) {
      LoggingService.instance.error(
        'Error awarding invite points',
        tag: 'EnhancedDeepLinkingService',
        error: e,
      );
    }
  }

  /// Show deep link success message
  Future<void> _showDeepLinkSuccess(
      BuildContext context, String message) async {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show deep link error message
  Future<void> _showDeepLinkError(BuildContext context, String message) async {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Generate shareable deep link
  String generateDeepLink({
    required String type,
    required String id,
    Map<String, String>? queryParams,
    String? username,
  }) {
    final String baseUrl = ProfileLinkService.webBaseUrl;
    final String path = _sharePathForType(
      type: type,
      id: id,
      username: username,
    );
    final String url = '$baseUrl$path';
    if (queryParams == null || queryParams.isEmpty) {
      return url;
    }
    final String queryString = queryParams.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$url?$queryString';
  }

  /// Generate app deep link
  String generateAppDeepLink({
    required String type,
    required String id,
    Map<String, String>? queryParams,
    String? username,
  }) {
    final String path = _sharePathForType(
      type: type,
      id: id,
      username: username,
    ).replaceFirst('/', '');
    final String url = '${ProfileLinkService.appScheme}$path';
    if (queryParams == null || queryParams.isEmpty) {
      return url;
    }
    final String queryString = queryParams.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$url?$queryString';
  }

  static String _sharePathForType({
    required String type,
    required String id,
    String? username,
  }) {
    final String normalized =
        type == 'user' || type == 'profile' ? 'profile' : type;
    if (normalized == 'profile') {
      final String? cleanUsername = username?.trim();
      if (cleanUsername != null &&
          cleanUsername.isNotEmpty &&
          !SensitiveDataRedactor.looksLikeFirebaseUid(cleanUsername)) {
        return '/user/${Uri.encodeComponent(cleanUsername)}';
      }
      if (!SensitiveDataRedactor.looksLikeFirebaseUid(id)) {
        return '/user/${Uri.encodeComponent(id)}';
      }
      return '/profile/${Uri.encodeComponent(id)}';
    }
    return '/$normalized/${Uri.encodeComponent(id)}';
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

  /// Dispose resources
  void dispose() {
    _deepLinkController.close();
  }
}

/// Deep link event model
class DeepLinkEvent {
  final String link;
  final String path;
  final Map<String, String> queryParams;
  final DateTime timestamp;

  DeepLinkEvent({
    required this.link,
    required this.path,
    required this.queryParams,
    required this.timestamp,
  });
}
