import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/user_privacy_settings.dart';

class PrivacySettingsService {
  PrivacySettingsService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  static final PrivacySettingsService instance = PrivacySettingsService();

  final FirebaseFirestore _firestore;
  final Map<String, _PrivacySettingsCacheEntry> _cache =
      <String, _PrivacySettingsCacheEntry>{};
  static const Duration _cacheTtl = Duration(minutes: 5);

  @visibleForTesting
  static void debugClearCache() {
    instance._cache.clear();
  }

  void invalidate(String userId) {
    _cache.remove(userId);
  }

  Future<UserPrivacySettings> getSettings(String userId) async {
    final String normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return UserPrivacySettings.defaults;
    }
    final DateTime now = DateTime.now();
    final _PrivacySettingsCacheEntry? cached = _cache[normalizedUserId];
    if (cached != null && now.isBefore(cached.expiresAt)) {
      return cached.settings;
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
          .collection('users')
          .doc(normalizedUserId)
          .collection('privacySettings')
          .doc('main')
          .get();
      final UserPrivacySettings settings = doc.exists
          ? UserPrivacySettings.fromMap(doc.data())
          : UserPrivacySettings.defaults;
      _cache[normalizedUserId] = _PrivacySettingsCacheEntry(
        settings: settings,
        expiresAt: now.add(_cacheTtl),
      );
      return settings;
    } catch (e) {
      final String message = e.toString();
      final bool isPermissionDenied =
          message.contains('permission-denied');
      if (isPermissionDenied) {
        if (kDebugMode) {
          debugPrint(
            'PrivacySettingsService: permission denied — using defaults',
          );
        }
      } else if (kDebugMode) {
        debugPrint('PrivacySettingsService: load failed: $message');
      }
      _cache[normalizedUserId] = _PrivacySettingsCacheEntry(
        settings: UserPrivacySettings.defaults,
        expiresAt: now.add(_cacheTtl),
      );
      return UserPrivacySettings.defaults;
    }
  }

  Future<String?> defaultVideoPublishPrivacyLabel(String userId) async {
    final UserPrivacySettings settings = await getSettings(userId);
    return settings.videoPublishPrivacyLabel();
  }

  Future<bool> canViewProfile({
    required String? viewerId,
    required String profileOwnerId,
  }) async {
    if (viewerId != null && viewerId == profileOwnerId) {
      return true;
    }
    final UserPrivacySettings settings = await getSettings(profileOwnerId);
    switch (settings.profileVisibility) {
      case ProfileVisibilityLevel.public:
        return true;
      case ProfileVisibilityLevel.private:
        return false;
      case ProfileVisibilityLevel.followers:
        if (viewerId == null || viewerId.isEmpty) {
          return false;
        }
        return _isFollowing(
          followerId: viewerId,
          followingId: profileOwnerId,
        );
    }
  }

  Future<void> assertCanFollow({
    required String followerId,
    required String targetUserId,
  }) async {
    if (followerId == targetUserId) {
      return;
    }
    final UserPrivacySettings settings = await getSettings(targetUserId);
    if (!settings.allowFollowers) {
      throw const PrivacySettingsBlockedException(
        code: PrivacyBlockCode.followDisabled,
        message: 'This creator is not accepting new followers.',
      );
    }
  }

  Future<bool> acceptsNewFollowers(String targetUserId) async {
    final UserPrivacySettings settings = await getSettings(targetUserId);
    return settings.allowFollowers;
  }

  Future<bool> canSendDirectMessage({
    required String senderId,
    required String recipientId,
  }) async {
    if (senderId == recipientId) {
      return true;
    }
    final UserPrivacySettings settings = await getSettings(recipientId);
    switch (settings.allowMessagesFrom) {
      case AudienceRestriction.everyone:
        return true;
      case AudienceRestriction.nobody:
        return false;
      case AudienceRestriction.followers:
        return _isFollowing(
          followerId: senderId,
          followingId: recipientId,
        );
    }
  }

  Future<String?> directMessageBlockMessage({
    required String senderId,
    required String recipientId,
  }) async {
    final bool allowed = await canSendDirectMessage(
      senderId: senderId,
      recipientId: recipientId,
    );
    if (allowed) {
      return null;
    }
    final UserPrivacySettings settings = await getSettings(recipientId);
    switch (settings.allowMessagesFrom) {
      case AudienceRestriction.nobody:
        return 'This creator is not accepting messages.';
      case AudienceRestriction.followers:
        return 'Only followers can message this creator.';
      case AudienceRestriction.everyone:
        return null;
    }
  }

  Future<bool> canMentionUser({
    required String mentionerId,
    required String mentionedUserId,
  }) async {
    if (mentionerId == mentionedUserId) {
      return true;
    }
    final UserPrivacySettings settings = await getSettings(mentionedUserId);
    switch (settings.allowMentions) {
      case AudienceRestriction.everyone:
        return true;
      case AudienceRestriction.nobody:
        return false;
      case AudienceRestriction.followers:
        return _isFollowing(
          followerId: mentionerId,
          followingId: mentionedUserId,
        );
    }
  }

  Future<bool> canTagUser({
    required String taggerId,
    required String taggedUserId,
  }) async {
    if (taggerId == taggedUserId) {
      return true;
    }
    final UserPrivacySettings settings = await getSettings(taggedUserId);
    return settings.allowTags;
  }

  Future<bool> shouldPublishOnlineStatus(String userId) async {
    final UserPrivacySettings settings = await getSettings(userId);
    return settings.showOnlineStatus;
  }

  Future<bool> shouldSendReadReceipts(String userId) async {
    final UserPrivacySettings settings = await getSettings(userId);
    return settings.readReceipts;
  }

  String messageForProfileBlock({
    required ProfileVisibilityLevel visibility,
  }) {
    switch (visibility) {
      case ProfileVisibilityLevel.private:
        return 'This profile is private.';
      case ProfileVisibilityLevel.followers:
        return 'Follow this creator to view their profile.';
      case ProfileVisibilityLevel.public:
        return 'This profile is unavailable.';
    }
  }

  Future<bool> _isFollowing({
    required String followerId,
    required String followingId,
  }) async {
    if (followerId.isEmpty || followingId.isEmpty) {
      return false;
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> edge = await _firestore
          .collection('users')
          .doc(followingId)
          .collection('followers')
          .doc(followerId)
          .get();
      if (edge.exists) {
        return true;
      }
      final DocumentSnapshot<Map<String, dynamic>> canonical = await _firestore
          .collection('follows')
          .doc('${followerId}_$followingId')
          .get();
      return canonical.exists;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PrivacySettingsService: follow lookup failed: $e');
      }
      return false;
    }
  }
}

class _PrivacySettingsCacheEntry {
  const _PrivacySettingsCacheEntry({
    required this.settings,
    required this.expiresAt,
  });

  final UserPrivacySettings settings;
  final DateTime expiresAt;
}
