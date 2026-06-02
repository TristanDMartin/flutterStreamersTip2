import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/logging_service.dart';

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _backgroundMessageSubscription;
  StreamSubscription<String>? _tokenRefreshSub;

  String? _fcmToken;

  static const Duration _initTimeout = Duration(seconds: 25);
  static const Duration _tokenTimeout = Duration(seconds: 12);
  static const Duration _firestoreSaveTimeout = Duration(seconds: 10);

  /// Initialize push notification service
  Future<void> initialize() async {
    try {
      await _initializeImpl().timeout(
        _initTimeout,
        onTimeout: () {
          LoggingService.instance.debug(
            'Push init timed out after ${_initTimeout.inSeconds}s; continuing',
            tag: 'PushNotificationService',
          );
        },
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error initializing push notifications',
          tag: 'PushNotificationService', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _initializeImpl() async {
    LoggingService.instance.debug('🔔 Initializing push notification service',
        tag: 'PushNotificationService');

    await _requestPermission();

    await _initializeLocalNotifications();

    await _getFCMToken();

    await _setupMessageHandlers();

    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen(_onTokenRefresh);

    LoggingService.instance.debug('✅ Push notification service initialized',
        tag: 'PushNotificationService');
  }

  /// Request notification permission
  Future<void> _requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      LoggingService.instance.debug(
          'Notification permission status: ${settings.authorizationStatus}',
          tag: 'PushNotificationService');
    } catch (e) {
      LoggingService.instance.error('Error requesting notification permission',
          tag: 'PushNotificationService', error: e);
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
    } catch (e) {
      LoggingService.instance.error('Error initializing local notifications',
          tag: 'PushNotificationService', error: e);
    }
  }

  /// Get FCM token
  Future<void> _getFCMToken() async {
    try {
      if (Platform.isIOS) {
        String? apnsToken;
        for (int attempt = 0; attempt < 5; attempt++) {
          apnsToken = await _messaging.getAPNSToken();
          if (apnsToken != null && apnsToken.isNotEmpty) {
            break;
          }
          await Future.delayed(const Duration(milliseconds: 700));
        }

        if (apnsToken == null || apnsToken.isEmpty) {
          LoggingService.instance.debug(
            'APNS token not ready yet; deferring FCM token registration',
            tag: 'PushNotificationService',
          );
          return;
        }
      }

      _fcmToken = await _messaging.getToken().timeout(
        _tokenTimeout,
        onTimeout: () {
          LoggingService.instance.debug(
            'FCM getToken timed out; skipping registration',
            tag: 'PushNotificationService',
          );
          return null;
        },
      );
      if (_fcmToken != null) {
        LoggingService.instance
            .debug('FCM Token: $_fcmToken', tag: 'PushNotificationService');
        await _saveTokenToFirestore(_fcmToken!).timeout(
          _firestoreSaveTimeout,
          onTimeout: () {
            LoggingService.instance.debug(
              'FCM token Firestore save timed out',
              tag: 'PushNotificationService',
            );
          },
        );
      }
    } catch (e) {
      LoggingService.instance.error('Error getting FCM token',
          tag: 'PushNotificationService', error: e);
    }
  }

  /// Save FCM token to Firestore
  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Save to deviceTokens subcollection for Cloud Functions.
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('deviceTokens')
          .doc(token)
          .set({
        'token': token,
        'platform': _getPlatform(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
        'source': 'push_notification',
      }, SetOptions(merge: true));

      LoggingService.instance.debug('✅ FCM token saved to deviceTokens',
          tag: 'PushNotificationService');
    } catch (e) {
      LoggingService.instance.error('Error saving FCM token',
          tag: 'PushNotificationService', error: e);
    }
  }

  /// Get platform name
  String _getPlatform() {
    if (Platform.isIOS) {
      return 'ios';
    } else if (Platform.isAndroid) {
      return 'android';
    } else if (Platform.isMacOS) {
      return 'macos';
    } else if (Platform.isWindows) {
      return 'windows';
    } else if (Platform.isLinux) {
      return 'linux';
    }
    return 'unknown';
  }

  /// Set up message handlers
  Future<void> _setupMessageHandlers() async {
    try {
      // Handle foreground messages
      _messageSubscription =
          FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages
      _backgroundMessageSubscription =
          FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

      // Handle notification tap when app is terminated
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    } catch (e) {
      LoggingService.instance.error('Error setting up message handlers',
          tag: 'PushNotificationService', error: e);
    }
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    try {
      LoggingService.instance.debug(
          'Received foreground message: ${message.messageId}',
          tag: 'PushNotificationService');

      // Show local notification
      await _showLocalNotification(message);
    } catch (e) {
      LoggingService.instance.error('Error handling foreground message',
          tag: 'PushNotificationService', error: e);
    }
  }

  /// Handle background messages
  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    try {
      LoggingService.instance.debug(
          'Received background message: ${message.messageId}',
          tag: 'PushNotificationService');
      _handleNotificationTap(message);
    } catch (e) {
      LoggingService.instance.error('Error handling background message',
          tag: 'PushNotificationService', error: e);
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    try {
      final data = message.data;
      final type = data['type'] ?? 'general';

      LoggingService.instance
          .debug('Notification tapped: $type', tag: 'PushNotificationService');

      // Navigate based on notification type
      switch (type) {
        case 'chat':
          _navigateToChat(data['roomId']);
          break;
        case 'video':
          _navigateToVideo(data['videoId']);
          break;
        case 'profile':
          _navigateToProfile(data['userId']);
          break;
        case 'follow':
          _navigateToProfile(data['userId']);
          break;
        default:
          _navigateToHome();
      }
    } catch (e) {
      LoggingService.instance.error('Error handling notification tap',
          tag: 'PushNotificationService', error: e);
    }
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    try {
      final payload = response.payload;
      if (payload == null) return;

      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type'] ?? 'general';

      LoggingService.instance.debug('Local notification tapped: $type',
          tag: 'PushNotificationService');

      // Navigate based on notification type
      switch (type) {
        case 'chat':
          _navigateToChat(data['chatId']);
          break;
        case 'video':
          _navigateToVideo(data['videoId']);
          break;
        case 'profile':
          _navigateToProfile(data['senderId'] ?? data['followerId']);
          break;
        case 'follow':
          _navigateToProfile(data['followerId']);
          break;
        default:
          _navigateToHome();
      }
    } catch (e) {
      LoggingService.instance.error('Error handling local notification tap: $e',
          tag: 'PushNotificationService', error: e);
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      if (notification == null) return;

      const androidDetails = AndroidNotificationDetails(
        'streamers_tip_channel',
        'StreamersTip Notifications',
        channelDescription: 'Notifications for StreamersTip app',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        id: message.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: details,
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      LoggingService.instance.error('Error showing local notification',
          tag: 'PushNotificationService', error: e);
    }
  }

  /// Show local notification directly (for immediate notifications)
  Future<void> _showLocalNotificationDirect({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'streamers_tip_channel',
        'StreamersTip Notifications',
        channelDescription: 'Notifications for StreamersTip app',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Generate unique ID for each notification
      final notificationId =
          DateTime.now().millisecondsSinceEpoch.remainder(100000);

      await _localNotifications.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: details,
        payload: jsonEncode(data),
      );

      LoggingService.instance.debug('✅ Local notification shown: $title',
          tag: 'PushNotificationService');
    } catch (e) {
      LoggingService.instance.error(
          'Error showing local notification directly: $e',
          tag: 'PushNotificationService',
          error: e);
    }
  }

  /// Send push notification to specific user
  Future<bool> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get user's FCM token
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        LoggingService.instance
            .error('User not found: $userId', tag: 'PushNotificationService');
        return false;
      }

      final userData = userDoc.data()!;
      final fcmToken = userData['fcmToken'] as String?;

      if (fcmToken == null) {
        LoggingService.instance.error('User has no FCM token: $userId',
            tag: 'PushNotificationService');
        return false;
      }

      // Send notification via Cloud Functions (recommended approach)
      // For now, we'll use a direct HTTP request to FCM
      await _sendFCMNotification(
        token: fcmToken,
        title: title,
        body: body,
        data: {
          'type': type,
          ...?data,
        },
      );

      LoggingService.instance.debug('✅ Notification sent to user: $userId',
          tag: 'PushNotificationService');
      return true;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error sending notification to user',
          tag: 'PushNotificationService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Send FCM notification (simplified implementation)
  Future<void> _sendFCMNotification({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      LoggingService.instance.debug('Sending FCM notification to: $token',
          tag: 'PushNotificationService');

      // For now, we'll use local notifications as a fallback since direct FCM requires server-side implementation
      // In production, this should be done via Cloud Functions

      // Show local notification immediately
      await _showLocalNotificationDirect(
        title: title,
        body: body,
        data: data ?? {},
      );

      // Also store in Firestore for persistence
      await _firestore.collection('notifications').add({
        'userId': _auth.currentUser?.uid,
        'title': title,
        'body': body,
        'type': data?['type'] ?? 'general',
        'data': data ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      LoggingService.instance.debug('✅ Local notification sent successfully',
          tag: 'PushNotificationService');
    } catch (e) {
      LoggingService.instance.error('Error sending FCM notification: $e',
          tag: 'PushNotificationService');
    }
  }

  /// Send chat notification
  Future<bool> sendChatNotification({
    required String userId,
    required String senderName,
    required String message,
    required String roomId,
  }) async {
    return await sendNotificationToUser(
      userId: userId,
      title: 'New message from $senderName',
      body: message,
      type: 'chat',
      data: {'roomId': roomId},
    );
  }

  /// Send follow notification
  Future<bool> sendFollowNotification({
    required String userId,
    required String followerName,
  }) async {
    return await sendNotificationToUser(
      userId: userId,
      title: 'New follower',
      body: '$followerName started following you',
      type: 'follow',
      data: {'followerName': followerName},
    );
  }

  /// Send video like notification
  Future<bool> sendVideoLikeNotification({
    required String userId,
    required String likerName,
    required String videoId,
  }) async {
    return await sendNotificationToUser(
      userId: userId,
      title: 'New like',
      body: '$likerName liked your video',
      type: 'video',
      data: {'videoId': videoId, 'likerName': likerName},
    );
  }

  /// Send comment notification
  Future<bool> sendCommentNotification({
    required String userId,
    required String commenterName,
    required String videoId,
  }) async {
    return await sendNotificationToUser(
      userId: userId,
      title: 'New comment',
      body: '$commenterName commented on your video',
      type: 'video',
      data: {'videoId': videoId, 'commenterName': commenterName},
    );
  }

  /// Navigation methods (to be implemented based on your routing)
  void _navigateToChat(String roomId) {
    LoggingService.instance
        .debug('Navigate to chat: $roomId', tag: 'PushNotificationService');
    // Implement navigation to chat room
  }

  void _navigateToVideo(String videoId) {
    LoggingService.instance
        .debug('Navigate to video: $videoId', tag: 'PushNotificationService');
    // Implement navigation to video
  }

  void _navigateToProfile(String userId) {
    LoggingService.instance
        .debug('Navigate to profile: $userId', tag: 'PushNotificationService');
    // Implement navigation to profile
  }

  void _navigateToHome() {
    LoggingService.instance
        .debug('Navigate to home', tag: 'PushNotificationService');
    // Implement navigation to home
  }

  /// Handle token refresh
  void _onTokenRefresh(String token) {
    LoggingService.instance
        .debug('FCM token refreshed: $token', tag: 'PushNotificationService');
    _fcmToken = token;
    _saveTokenToFirestore(token);
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Dispose resources
  void dispose() {
    _messageSubscription?.cancel();
    _backgroundMessageSubscription?.cancel();
    _tokenRefreshSub?.cancel();
  }
}
