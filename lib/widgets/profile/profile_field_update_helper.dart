import 'package:flutter/material.dart';

import '../../services/content_moderation_service.dart';
import '../../services/profile_update_service.dart';
import 'editable_profile_field.dart';
import 'profile_username_utils.dart';

class ProfileFieldUpdateResult {
  const ProfileFieldUpdateResult({
    required this.isSuccess,
    this.errorMessage,
    this.updatedUser,
    this.firestorePayload,
  });

  final bool isSuccess;
  final String? errorMessage;
  final Map<String, dynamic>? updatedUser;
  final Map<String, dynamic>? firestorePayload;
}

abstract final class ProfileFieldUpdateHelper {
  static ModerationResult? validateField(String key, String value) {
    if (key == EditableProfileField.name.key) {
      return ContentModerationService.validateDisplayName(value);
    }
    if (key == EditableProfileField.bio.key) {
      return ContentModerationService.validateBio(value);
    }
    if (key == EditableProfileField.hashtags.key) {
      final String hashtagsString = value.trim();
      if (hashtagsString.isEmpty) {
        return null;
      }
      final List<String> hashtags = hashtagsString
          .split(',')
          .map((String tag) => tag.trim().replaceFirst('#', ''))
          .where((String tag) => tag.isNotEmpty)
          .toList();
      return ContentModerationService.validateHashtags(hashtags);
    }
    return null;
  }

  static ProfileFieldUpdateResult applyLocalUpdate({
    required Map<String, dynamic> user,
    required String key,
    required String value,
    bool syncUsernameFromDisplayName = true,
    bool recordNameChangeDate = false,
  }) {
    final ModerationResult? moderation = validateField(key, value);
    if (moderation != null && !moderation.isAllowed) {
      return ProfileFieldUpdateResult(
        isSuccess: false,
        errorMessage: moderation.reason ??
            'Content contains inappropriate language',
      );
    }
    final Map<String, dynamic> nextUser = Map<String, dynamic>.from(user);
    if (key == EditableProfileField.hashtags.key) {
      final String hashtagsString = value.trim();
      if (hashtagsString.isEmpty) {
        nextUser[key] = <String>[];
      } else {
        nextUser[key] = hashtagsString
            .split(',')
            .map((String tag) => tag.trim().replaceFirst('#', ''))
            .where((String tag) => tag.isNotEmpty)
            .toList();
      }
    } else {
      nextUser[key] = value;
    }
    final Map<String, dynamic> payload = <String, dynamic>{};
    if (key == EditableProfileField.name.key) {
      payload['displayName'] = value;
      if (syncUsernameFromDisplayName) {
        final String username =
            ProfileUsernameUtils.generateUsernameFromDisplayName(value);
        nextUser['username'] = username;
        payload['username'] = username;
      }
      if (recordNameChangeDate) {
        final String changedAt = DateTime.now().toIso8601String();
        nextUser['lastNameChangeDate'] = changedAt;
        payload['lastNameChangeDate'] = changedAt;
      }
    } else if (key == EditableProfileField.hashtags.key) {
      payload[key] = nextUser[key];
    } else {
      payload[key] = value;
    }
    return ProfileFieldUpdateResult(
      isSuccess: true,
      updatedUser: nextUser,
      firestorePayload: payload,
    );
  }

  static Future<ProfileFieldUpdateResult> persistFieldUpdate({
    required Map<String, dynamic> user,
    required String key,
    required String value,
    ProfileUpdateService? profileUpdateService,
    bool syncUsernameFromDisplayName = true,
    bool recordNameChangeDate = false,
  }) async {
    final ProfileFieldUpdateResult local = applyLocalUpdate(
      user: user,
      key: key,
      value: value,
      syncUsernameFromDisplayName: syncUsernameFromDisplayName,
      recordNameChangeDate: recordNameChangeDate,
    );
    if (!local.isSuccess || local.firestorePayload == null) {
      return local;
    }
    final ProfileUpdateService service =
        profileUpdateService ?? ProfileUpdateService();
    await service.initialize();
    await service.updateUserData(local.firestorePayload!);
    return local;
  }

  static String readFieldValue(
    Map<String, dynamic> user,
    EditableProfileField field,
  ) {
    switch (field) {
      case EditableProfileField.name:
        return (user['displayName'] as String?) ?? '';
      case EditableProfileField.bio:
        return (user['bio'] as String?) ?? '';
      case EditableProfileField.hashtags:
        final List<dynamic> hashtags =
            user['hashtags'] as List<dynamic>? ?? <dynamic>[];
        return hashtags.join(', ');
    }
  }

  static void showModerationSnackBar(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
