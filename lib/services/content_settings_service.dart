import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_content_settings.dart';

class ContentSettingsService {
  ContentSettingsService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static final ContentSettingsService instance = ContentSettingsService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Map<String, _ContentSettingsCacheEntry> _cache =
      <String, _ContentSettingsCacheEntry>{};
  static const Duration _cacheTtl = Duration(minutes: 5);

  @visibleForTesting
  static void debugClearCache() {
    instance._cache.clear();
  }

  void invalidate(String userId) {
    _cache.remove(userId.trim());
  }

  Future<UserContentSettings> getSettings(String userId) async {
    final String normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return UserContentSettings.defaults;
    }
    final DateTime now = DateTime.now();
    final _ContentSettingsCacheEntry? cached = _cache[normalizedUserId];
    if (cached != null && now.isBefore(cached.expiresAt)) {
      return cached.settings;
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
          .collection('users')
          .doc(normalizedUserId)
          .collection('contentSettings')
          .doc('main')
          .get();
      final UserContentSettings settings = doc.exists
          ? UserContentSettings.fromMap(doc.data())
          : UserContentSettings.defaults;
      _cache[normalizedUserId] = _ContentSettingsCacheEntry(
        settings: settings,
        expiresAt: now.add(_cacheTtl),
      );
      return settings;
    } catch (e) {
      debugPrint('ContentSettingsService: load failed for $normalizedUserId: $e');
      return UserContentSettings.defaults;
    }
  }

  Future<UserContentSettings> getCurrentUserSettings() async {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) {
      return UserContentSettings.defaults;
    }
    return getSettings(userId);
  }

  UserContentSettings? cachedCurrentUserSettings() {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) {
      return null;
    }
    final _ContentSettingsCacheEntry? cached = _cache[userId];
    if (cached == null || DateTime.now().isAfter(cached.expiresAt)) {
      return null;
    }
    return cached.settings;
  }

  bool isAutoPlayEnabledSync() {
    return cachedCurrentUserSettings()?.autoPlay ??
        UserContentSettings.defaults.autoPlay;
  }

  bool isSoundEnabledSync() {
    return cachedCurrentUserSettings()?.soundEnabled ??
        UserContentSettings.defaults.soundEnabled;
  }

  bool areDownloadsEnabledSync() {
    return cachedCurrentUserSettings()?.downloadEnabled ??
        UserContentSettings.defaults.downloadEnabled;
  }

  Future<bool> isAutoPlayEnabled() async {
    final UserContentSettings settings = await getCurrentUserSettings();
    return settings.autoPlay;
  }

  Future<bool> isSoundEnabled() async {
    final UserContentSettings settings = await getCurrentUserSettings();
    return settings.soundEnabled;
  }

  Future<bool> areDownloadsEnabled() async {
    final UserContentSettings settings = await getCurrentUserSettings();
    return settings.downloadEnabled;
  }

  Future<String?> preferredPlaybackResolution() async {
    final UserContentSettings settings = await getCurrentUserSettings();
    return settings.preferredPlaybackResolutionLabel();
  }
}

class _ContentSettingsCacheEntry {
  const _ContentSettingsCacheEntry({
    required this.settings,
    required this.expiresAt,
  });

  final UserContentSettings settings;
  final DateTime expiresAt;
}
