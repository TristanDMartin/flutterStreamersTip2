import '../../services/admin_service.dart';

/// Profile tab only — does not affect routes, listeners, or StreamerCard views.
abstract final class ProfileStreamerCardVisibility {
  static bool canShowStreamerCardButton(Map<String, dynamic> viewerUserData) {
    final String username =
        (viewerUserData['username'] ?? '').toString().toLowerCase().trim();
    if (username == 'technqs' || username == 'buzzz') {
      return true;
    }
    if (viewerUserData['isAdmin'] == true) {
      return true;
    }
    return AdminService.userDocHasRulesAlignedAdmin(viewerUserData);
  }
}
