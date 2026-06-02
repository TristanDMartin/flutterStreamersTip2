import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/activity_notification.dart';
import '../models/user_model.dart' as user_model;

class OfflineService {
  static const String _notificationsKey = 'cached_notifications';
  static const String _usersKey = 'cached_users';
  static const String _lastSyncKey = 'last_sync_timestamp';

  static OfflineService? _instance;
  static OfflineService get instance => _instance ??= OfflineService._();

  OfflineService._();

  // Cache notifications offline
  Future<void> cacheNotifications(
      List<ActivityNotification> notifications) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = notifications.map((n) => n.toJson()).toList();
      await prefs.setString(_notificationsKey, jsonEncode(notificationsJson));
      await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('✅ Cached ${notifications.length} notifications offline');
    } catch (e) {
      debugPrint('❌ Error caching notifications: $e');
    }
  }

  // Retrieve cached notifications
  Future<List<ActivityNotification>> getCachedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsString = prefs.getString(_notificationsKey);

      if (notificationsString == null) return [];

      final List<dynamic> notificationsJson = jsonDecode(notificationsString);
      return notificationsJson
          .map((json) => ActivityNotification.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ Error retrieving cached notifications: $e');
      return [];
    }
  }

  // Cache users offline
  Future<void> cacheUsers(List<user_model.User> users) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = users.map((u) => u.toMap()).toList();
      await prefs.setString(_usersKey, jsonEncode(usersJson));
      debugPrint('✅ Cached ${users.length} users offline');
    } catch (e) {
      debugPrint('❌ Error caching users: $e');
    }
  }

  // Retrieve cached users
  Future<List<user_model.User>> getCachedUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersString = prefs.getString(_usersKey);

      if (usersString == null) return [];

      final List<dynamic> usersJson = jsonDecode(usersString);
      return usersJson
          .map((json) => user_model.User.fromMap(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Error retrieving cached users: $e');
      return [];
    }
  }

  // Check if data is stale (older than 1 hour)
  Future<bool> isDataStale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getInt(_lastSyncKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      const oneHour = 60 * 60 * 1000; // 1 hour in milliseconds

      return (now - lastSync) > oneHour;
    } catch (e) {
      debugPrint('❌ Error checking data staleness: $e');
      return true; // Assume stale if error
    }
  }

  // Clear all cached data
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_notificationsKey);
      await prefs.remove(_usersKey);
      await prefs.remove(_lastSyncKey);
      debugPrint('✅ Cleared all cached data');
    } catch (e) {
      debugPrint('❌ Error clearing cache: $e');
    }
  }

  // Get cache size info
  Future<Map<String, dynamic>> getCacheInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsString = prefs.getString(_notificationsKey);
      final usersString = prefs.getString(_usersKey);
      final lastSync = prefs.getInt(_lastSyncKey) ?? 0;

      return {
        'notifications_count': notificationsString != null
            ? (jsonDecode(notificationsString) as List).length
            : 0,
        'users_count':
            usersString != null ? (jsonDecode(usersString) as List).length : 0,
        'last_sync': lastSync > 0
            ? DateTime.fromMillisecondsSinceEpoch(lastSync).toIso8601String()
            : 'Never',
        'is_stale': await isDataStale(),
      };
    } catch (e) {
      debugPrint('❌ Error getting cache info: $e');
      return {};
    }
  }
}
