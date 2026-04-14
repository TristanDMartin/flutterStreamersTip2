import 'package:flutter/foundation.dart';

import '../../models/user.dart' as app_user;
import '../../services/profile_update_service.dart';
import '../../services/unified_avatar_service.dart';
import '../../utils/avatar_url_resolver.dart';

/// Cached `Map` for profile header + back card, keyed off [app_user.User] and
/// [ProfileUpdateService] for the signed-in viewer.
class ProfileUserDataCache {
  Map<String, dynamic>? _cached;
  String? _lastSavedAvatarUrl;
  bool _dirty = true;

  bool get isDirty => _dirty;

  void markDirty() {
    _dirty = true;
  }

  void resetForNewProfile() {
    _cached = null;
    _dirty = true;
  }

  void onProfileServiceAvatarHint(String? newAvatarURL) {
    if (newAvatarURL != null && newAvatarURL != _lastSavedAvatarUrl) {
      _lastSavedAvatarUrl = null;
    }
  }

  Map<String, dynamic> resolve({
    required app_user.User profileUser,
    required ProfileUpdateService? updateService,
  }) {
    if (!_dirty && _cached != null) {
      return _cached!;
    }
    try {
      final String? currentUserId = updateService?.currentUser?.uid;
      final bool isViewerProfile =
          currentUserId != null && currentUserId == profileUser.id;
      if (isViewerProfile && updateService?.isDataLoaded == true) {
        _cached = updateService?.userData ?? profileUser.toMap();
        final String? avatarUrl =
            resolveAvatarUrl(_cached) ?? profileUser.avatarURL;
        if (avatarUrl != null &&
            avatarUrl.isNotEmpty &&
            avatarUrl != _lastSavedAvatarUrl) {
          UnifiedAvatarService().saveMainUserAvatar(avatarUrl);
          _lastSavedAvatarUrl = avatarUrl;
        }
        _dirty = false;
        return _cached!;
      }
      _cached = profileUser.toMap();
      if (isViewerProfile &&
          profileUser.avatarURL?.isNotEmpty == true &&
          profileUser.avatarURL != _lastSavedAvatarUrl) {
        UnifiedAvatarService().saveMainUserAvatar(profileUser.avatarURL!);
        _lastSavedAvatarUrl = profileUser.avatarURL;
      }
      _dirty = false;
      return _cached!;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ ProfileUserDataCache.resolve: $e');
        debugPrint('$stackTrace');
      }
      _dirty = false;
      return _fallback(profileUser);
    }
  }

  Map<String, dynamic> _fallback(app_user.User profileUser) {
    return <String, dynamic>{
      'id': profileUser.id,
      'displayName': profileUser.displayName,
      'username': profileUser.username,
      'bio': profileUser.bio ?? '',
      'avatarUrl': profileUser.avatarURL,
      'followers': 0,
      'following': 0,
      'videos': 0,
      'hashtags': <String>[],
      'platforms': <Map<String, dynamic>>[],
      'calendarEvents': <Map<String, dynamic>>[],
      'status': 'offline',
      'isOnline': false,
    };
  }
}
