import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class ProgressionPushNotificationService {
  ProgressionPushNotificationService._();

  static final ProgressionPushNotificationService instance =
      ProgressionPushNotificationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> maybePromptAfterCreatorAction(String uid) async {
    if (uid.trim().isEmpty) return;
    try {
      final DocumentReference<Map<String, dynamic>> settingsRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('notificationSettings')
          .doc('main');
      final DocumentSnapshot<Map<String, dynamic>> settingsSnap =
          await settingsRef.get();
      final Map<String, dynamic> settings =
          settingsSnap.data() ?? <String, dynamic>{};

      if (settings['progressionPermissionPrompted'] == true) {
        await registerTokenIfAllowed(uid);
        return;
      }
      if (settings['progressionNotifications'] == false ||
          settings['pushNotifications'] == false) {
        return;
      }

      final NotificationSettings current =
          await _messaging.getNotificationSettings();
      if (current.authorizationStatus == AuthorizationStatus.denied) {
        await settingsRef.set(<String, dynamic>{
          'progressionPermissionPrompted': true,
          'progressionPermissionPromptedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      }

      if (current.authorizationStatus == AuthorizationStatus.notDetermined) {
        final NotificationSettings requested =
            await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        await settingsRef.set(<String, dynamic>{
          'progressionPermissionPrompted': true,
          'progressionPermissionPromptedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (requested.authorizationStatus != AuthorizationStatus.authorized &&
            requested.authorizationStatus != AuthorizationStatus.provisional) {
          return;
        }
      }

      await registerTokenIfAllowed(uid);
    } catch (e) {
      debugPrint('Progression push permission prompt skipped: $e');
    }
  }

  Future<void> registerTokenIfAllowed(String uid) async {
    if (uid.trim().isEmpty) return;
    try {
      final NotificationSettings current =
          await _messaging.getNotificationSettings();
      if (current.authorizationStatus != AuthorizationStatus.authorized &&
          current.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }

      final String? token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;

      final DocumentReference<Map<String, dynamic>> tokenRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('deviceTokens')
          .doc(token);
      await tokenRef.set(<String, dynamic>{
        'token': token,
        'platform': _platformName(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
        'source': 'progression',
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Progression push token registration skipped: $e');
    }
  }

  String _platformName() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'unknown';
    }
  }
}
