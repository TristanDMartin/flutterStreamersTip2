import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/user_notification_settings.dart';

class NotificationSettingsService {
  NotificationSettingsService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  static final NotificationSettingsService instance =
      NotificationSettingsService();

  final FirebaseFirestore _firestore;
  final Map<String, _NotificationSettingsCacheEntry> _cache =
      <String, _NotificationSettingsCacheEntry>{};
  static const Duration _cacheTtl = Duration(minutes: 5);

  @visibleForTesting
  static void debugClearCache() {
    instance._cache.clear();
  }

  void invalidate(String userId) {
    _cache.remove(userId.trim());
  }

  Future<UserNotificationSettings> getSettings(String userId) async {
    final String normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return UserNotificationSettings.defaults;
    }
    final DateTime now = DateTime.now();
    final _NotificationSettingsCacheEntry? cached = _cache[normalizedUserId];
    if (cached != null && now.isBefore(cached.expiresAt)) {
      return cached.settings;
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
          .collection('users')
          .doc(normalizedUserId)
          .collection('notificationSettings')
          .doc('main')
          .get();
      final UserNotificationSettings settings = doc.exists
          ? UserNotificationSettings.fromMap(doc.data())
          : UserNotificationSettings.defaults;
      _cache[normalizedUserId] = _NotificationSettingsCacheEntry(
        settings: settings,
        expiresAt: now.add(_cacheTtl),
      );
      return settings;
    } catch (e) {
      debugPrint(
        'NotificationSettingsService: load failed for $normalizedUserId: $e',
      );
      return UserNotificationSettings.defaults;
    }
  }

  Future<bool> shouldDeliverInApp({
    required String userId,
    required NotificationDeliveryType type,
  }) async {
    final UserNotificationSettings settings = await getSettings(userId);
    return settings.allowsInApp(type);
  }

  Future<bool> shouldDeliverPush({
    required String userId,
    required NotificationDeliveryType type,
  }) async {
    final UserNotificationSettings settings = await getSettings(userId);
    return settings.pushNotifications && settings.allowsInApp(type);
  }

  Future<bool> shouldDeliverMentionNotifications(String userId) async {
    return shouldDeliverInApp(
      userId: userId,
      type: NotificationDeliveryType.mention,
    );
  }

  Future<bool> shouldDeliverTagNotifications(String userId) async {
    return shouldDeliverInApp(
      userId: userId,
      type: NotificationDeliveryType.tag,
    );
  }
}

class _NotificationSettingsCacheEntry {
  const _NotificationSettingsCacheEntry({
    required this.settings,
    required this.expiresAt,
  });

  final UserNotificationSettings settings;
  final DateTime expiresAt;
}
