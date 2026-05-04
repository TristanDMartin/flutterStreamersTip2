import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../services/admin_service.dart';
import '../admin_backend_service.dart';
import '../admin_permissions.dart';
import 'admin_audit_log_view.dart';
import 'admin_reports_view.dart';
import 'admin_uploads_view.dart';
import 'admin_users_view.dart';

/// Moderation shell. Must match Cloud Functions: JWT `admin` claim and/or
/// Firestore `role`/`isAdmin`/`admin.isAdmin` — not username-only UI bootstrap.
class AdminControlCenterView extends StatefulWidget {
  const AdminControlCenterView({super.key});

  @override
  State<AdminControlCenterView> createState() => _AdminControlCenterViewState();
}

class _AdminControlCenterViewState extends State<AdminControlCenterView>
    with TickerProviderStateMixin {
  TabController? _tabs;
  List<Tab> _tabWidgets = [];
  List<Widget> _tabBodies = [];
  bool _loading = true;
  AdminPermissions? _perms;

  (List<Tab>, List<Widget>) _makeTabs(AdminPermissions perms) {
    final List<Tab> tabs = [];
    final List<Widget> bodies = [];
    if (perms.viewAdminStats) {
      tabs.add(const Tab(text: 'Overview'));
      bodies.add(const _OverviewPane());
    }
    if (perms.viewReports) {
      tabs.add(const Tab(text: 'Reports'));
      bodies.add(const AdminReportsView());
    }
    if (perms.viewUploads) {
      tabs.add(const Tab(text: 'Uploads'));
      bodies.add(const AdminUploadsView());
    }
    if (perms.manageUsers || perms.banUsers) {
      tabs.add(const Tab(text: 'Users'));
      bodies.add(const AdminUsersView());
    }
    if (perms.manageReports) {
      tabs.add(const Tab(text: 'Audit'));
      bodies.add(const AdminAuditLogView());
    }
    if (tabs.isEmpty) {
      tabs.add(const Tab(text: 'Overview'));
      bodies.add(const _OverviewPane());
    }
    return (tabs, bodies);
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await AdminService.instance.refreshIdTokenForAdminSession();
    final bool ok = await AdminService.instance.hasFirestoreRulesAdminAccess();
    if (!mounted) {
      return;
    }
    if (!ok) {
      Navigator.pop(context);
      return;
    }
    final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
        .instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .get();
    final AdminPermissions perms = AdminPermissions.fromUserDoc(doc.data());
    final (List<Tab> tabs, List<Widget> bodies) = _makeTabs(perms);
    if (!mounted) {
      return;
    }
    setState(() {
      _perms = perms;
      _tabs?.dispose();
      _tabs = TabController(length: tabs.length, vsync: this);
      _tabWidgets = tabs;
      _tabBodies = bodies;
      _loading = false;
    });
  }

  Future<void> _refreshJwtAndRebuildTabs() async {
    await AdminService.instance.refreshIdTokenForAdminSession();
    if (!mounted || _perms == null) {
      return;
    }
    final (List<Tab> tabs, List<Widget> bodies) = _makeTabs(_perms!);
    setState(() {
      _tabs?.dispose();
      _tabs = TabController(length: tabs.length, vsync: this);
      _tabWidgets = tabs;
      _tabBodies = bodies;
    });
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _tabs == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Control Center'),
        actions: [
          IconButton(
            tooltip: 'Refresh ID token (after setting JWT admin claim)',
            onPressed: _refreshJwtAndRebuildTabs,
            icon: const Icon(Icons.key_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: _tabWidgets,
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: _tabBodies,
      ),
    );
  }
}

class _OverviewPane extends StatefulWidget {
  const _OverviewPane();

  @override
  State<_OverviewPane> createState() => _OverviewPaneState();
}

class _OverviewPaneState extends State<_OverviewPane> {
  late Future<Map<String, dynamic>> _statsFuture =
      AdminBackendService.dashboardStats();

  Future<void> _reload() async {
    final Future<Map<String, dynamic>> next =
        AdminBackendService.dashboardStats();
    setState(() => _statsFuture = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _statsFuture,
        builder: (context, snap) {
          if (snap.hasError) {
            final Object err = snap.error!;
            String message = 'Stats error: $err';
            if (err is FirebaseException &&
                err.plugin == 'firebase_functions' &&
                err.code == 'permission-denied') {
              message =
                  'Admin access is not active for this session yet. Tap the '
                  'key icon to refresh your session, then try again.\n\n'
                  'If this keeps happening, contact support.';
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText.rich(
                    TextSpan(
                      text: message,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            );
          }
          if (!snap.hasData) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(child: CircularProgressIndicator()),
              ],
            );
          }
          final Map<String, dynamic> d = snap.data!;
          int g(String k) {
            final Object? v = d[k];
            if (v is int) {
              return v;
            }
            if (v is num) {
              return v.toInt();
            }
            return 0;
          }

          final List<(String, int)> tiles = [
            ('Open reports', g('openReports')),
            ('Flagged videos', g('flaggedVideos')),
            ('Failed uploads', g('failedUploads')),
            ('Banned users', g('bannedUsers')),
            ('New users today', g('newUsersToday')),
            ('Total uploads', g('totalUploads')),
            ('Processing videos', g('processingVideos')),
          ];
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: tiles
                .map(
                  ((String, int) e) => Card(
                    child: ListTile(
                      title: Text(e.$1),
                      trailing: Text(
                        '${e.$2}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}
