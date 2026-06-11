import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../routing/app_routes.dart';
import '../../routing/navigation_context.dart';
import '../../services/content_moderation_service.dart';
import '../../services/profile_update_service.dart';
import '../../utils/platform_rules.dart';
import '../../utils/user_profile_firestore.dart';
import '../links_edit_view.dart';

class ProfilePlatformsUpdateResult {
  const ProfilePlatformsUpdateResult({
    required this.isSuccess,
    this.errorMessage,
    this.platforms,
  });

  final bool isSuccess;
  final String? errorMessage;
  final List<Map<String, dynamic>>? platforms;
}

abstract final class ProfilePlatformsUpdateHelper {
  static List<Map<String, dynamic>> readPlatforms(Map<String, dynamic> user) {
    return UserProfileFirestore.parsePlatformsFromUserData(user);
  }

  static int countLinkedPlatforms(List<Map<String, dynamic>> platforms) {
    return platforms.where((Map<String, dynamic> platform) {
      final String username = (platform['username'] as String?)?.trim() ?? '';
      final String url = (platform['url'] as String?)?.trim() ?? '';
      return username.isNotEmpty || url.isNotEmpty;
    }).length;
  }

  static ProfilePlatformsUpdateResult validateAndNormalize(
    List<Map<String, dynamic>> updatedPlatforms,
  ) {
    final String? platformRulesError =
        PlatformRules.validatePlatformsList(updatedPlatforms);
    if (platformRulesError != null) {
      return ProfilePlatformsUpdateResult(
        isSuccess: false,
        errorMessage: platformRulesError,
      );
    }
    final List<Map<String, dynamic>> normalizedPlatforms =
        UserProfileFirestore.normalizePlatformsForFirestore(updatedPlatforms);
    final ModerationResult moderationResult =
        ContentModerationService.validatePlatforms(normalizedPlatforms);
    if (!moderationResult.isAllowed) {
      return ProfilePlatformsUpdateResult(
        isSuccess: false,
        errorMessage: moderationResult.reason ??
            'Platform contains inappropriate content',
      );
    }
    return ProfilePlatformsUpdateResult(
      isSuccess: true,
      platforms: normalizedPlatforms,
    );
  }

  static Future<ProfilePlatformsUpdateResult> persistPlatforms({
    required List<Map<String, dynamic>> platforms,
    ProfileUpdateService? profileUpdateService,
  }) async {
    final ProfilePlatformsUpdateResult validated =
        validateAndNormalize(platforms);
    if (!validated.isSuccess) {
      return validated;
    }
    final ProfileUpdateService service =
        profileUpdateService ?? ProfileUpdateService();
    await service.initialize();
    await service.updateUserData(
      <String, dynamic>{
        UserProfileFirestore.platformsField: validated.platforms,
      },
    );
    return validated;
  }

  static void openPlatformsEditor({
    required BuildContext context,
    required Map<String, dynamic> user,
    required void Function(List<Map<String, dynamic>> platforms) onSaved,
    String auditView = 'ProfileView',
    ProfileUpdateService? profileUpdateService,
  }) {
    final List<Map<String, dynamic>> currentPlatforms = readPlatforms(user);
    if (!NavigationContext.canNavigate(context)) {
      return;
    }
    final BuildContext navigatorContext =
        NavigationContext.requireForNavigation(context);
    Navigator.push<void>(
      navigatorContext,
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: AppRoutes.editLinks),
        builder: (BuildContext routeContext) {
          return LinksEditView(
            platforms: currentPlatforms,
            onPlatformsUpdated: (List<Map<String, dynamic>> updatedPlatforms) {
              unawaited(_handlePlatformsUpdated(
                context: routeContext,
                user: user,
                updatedPlatforms: updatedPlatforms,
                onSaved: onSaved,
                auditView: auditView,
                profileUpdateService: profileUpdateService,
              ));
            },
          );
        },
      ),
    );
  }

  static Future<void> _handlePlatformsUpdated({
    required BuildContext context,
    required Map<String, dynamic> user,
    required List<Map<String, dynamic>> updatedPlatforms,
    required void Function(List<Map<String, dynamic>> platforms) onSaved,
    required String auditView,
    ProfileUpdateService? profileUpdateService,
  }) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ProfilePlatformsUpdateResult validated =
        validateAndNormalize(updatedPlatforms);
    if (!validated.isSuccess) {
      if (context.mounted && validated.errorMessage != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(validated.errorMessage!),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }
    final String? uid = (user['id'] ?? user['uid'])?.toString();
    if (uid != null && uid.isNotEmpty) {
      UserProfileFirestore.logPlatformSave(
        uid: uid,
        view: auditView,
        count: validated.platforms?.length ?? 0,
      );
    }
    try {
      await persistPlatforms(
        platforms: validated.platforms ?? <Map<String, dynamic>>[],
        profileUpdateService: profileUpdateService,
      );
      onSaved(validated.platforms ?? <Map<String, dynamic>>[]);
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Platforms updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProfilePlatformsUpdateHelper: save failed: $e');
      }
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to update platforms: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
