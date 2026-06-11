import '../../services/admin_service.dart';

/// Parsed from Firestore `users/{uid}.admin.permissions` (list or map).
class AdminPermissions {
  const AdminPermissions({
    required this.viewReports,
    required this.manageReports,
    required this.viewUploads,
    required this.removeVideos,
    required this.banUsers,
    required this.manageUsers,
    required this.viewAdminStats,
    required this.manageTiers,
  });

  final bool viewReports;
  final bool manageReports;
  final bool viewUploads;
  final bool removeVideos;
  final bool banUsers;
  final bool manageUsers;
  final bool viewAdminStats;
  final bool manageTiers;

  static AdminPermissions full() => const AdminPermissions(
        viewReports: true,
        manageReports: true,
        viewUploads: true,
        removeVideos: true,
        banUsers: true,
        manageUsers: true,
        viewAdminStats: true,
        manageTiers: true,
      );

  static AdminPermissions moderator() => const AdminPermissions(
        viewReports: true,
        manageReports: true,
        viewUploads: true,
        removeVideos: false,
        banUsers: false,
        manageUsers: false,
        viewAdminStats: false,
        manageTiers: false,
      );

  static AdminPermissions none() => const AdminPermissions(
        viewReports: false,
        manageReports: false,
        viewUploads: false,
        removeVideos: false,
        banUsers: false,
        manageUsers: false,
        viewAdminStats: false,
        manageTiers: false,
      );

  factory AdminPermissions.fromUserDoc(Map<String, dynamic>? data) {
    if (!AdminService.userDocGrantsAdminAccess(
      data,
      logSource: 'permissions',
    )) {
      return AdminPermissions.none();
    }
    if (data == null) {
      return AdminPermissions.full();
    }
    final Object? adminMap = data['admin'];
    if (adminMap is! Map<String, dynamic>) {
      return AdminPermissions.full();
    }
    final Object? raw = adminMap['permissions'];
    if (raw is List && raw.map((dynamic e) => e.toString()).contains('*')) {
      return AdminPermissions.full();
    }
    if (raw is Map<String, dynamic>) {
      bool g(String k, bool d) => raw[k] is bool ? raw[k] as bool : d;
      return AdminPermissions(
        viewReports: g('viewReports', true),
        manageReports: g('manageReports', true),
        viewUploads: g('viewUploads', true),
        removeVideos: g('removeVideos', false),
        banUsers: g('banUsers', false),
        manageUsers: g('manageUsers', false),
        viewAdminStats: g('viewAdminStats', false),
        manageTiers: g('manageTiers', false),
      );
    }
    if (raw is List) {
      final List<String> list =
          raw.map((dynamic e) => e.toString()).toList();
      return AdminPermissions(
        viewReports: list.contains('view_reports'),
        manageReports:
            list.contains('manage_flags') || list.contains('view_reports'),
        viewUploads: list.contains('view_uploads'),
        removeVideos: list.contains('remove_videos'),
        banUsers: list.contains('ban_users'),
        manageUsers:
            list.contains('view_user_profiles') || list.contains('ban_users'),
        viewAdminStats: list.contains('view_reports'),
        manageTiers: list.contains('manage_tiers'),
      );
    }
    return AdminPermissions.full();
  }
}
