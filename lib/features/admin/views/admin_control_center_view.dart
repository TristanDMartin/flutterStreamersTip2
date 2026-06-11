import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/admin_service.dart';
import '../admin_backend_service.dart';
import '../admin_permissions.dart';
import '../models/admin_overview_metric.dart';
import 'admin_creator_intelligence_view.dart';
import 'admin_overview_detail_view.dart';
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
  int _overviewEpoch = 0;

  (List<Tab>, List<Widget>) _makeTabs(AdminPermissions perms) {
    final List<Tab> tabs = [];
    final List<Widget> bodies = [];
    if (perms.viewAdminStats) {
      tabs.add(const Tab(text: 'Overview'));
      bodies.add(_OverviewPane(key: ValueKey<int>(_overviewEpoch)));
      tabs.add(const Tab(text: 'Analytics'));
      bodies.add(const AdminCreatorIntelligenceView());
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
      bodies.add(_OverviewPane(key: ValueKey<int>(_overviewEpoch)));
    }
    return (tabs, bodies);
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final User? authUser = FirebaseAuth.instance.currentUser;
    debugPrint('ADMIN_BUTTON_TAPPED source=control_center_bootstrap');
    Map<String, dynamic>? userData;
    if (authUser != null) {
      final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
          .instance
          .collection('users')
          .doc(authUser.uid)
          .get();
      userData = doc.data();
      if (userData != null) {
        userData['id'] = authUser.uid;
        userData['uid'] = authUser.uid;
        if (authUser.email != null) {
          userData['email'] = authUser.email;
        }
      }
    }
    final bool ok = await AdminService.instance.resolveAdminAccess(
      cachedUserMap: userData,
    );
    if (!mounted) {
      return;
    }
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin access required'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
      return;
    }
    await AdminService.instance.ensureOwnerAdminActivation(
      cachedUserMap: userData,
    );
    await AdminService.instance.refreshIdTokenForAdminSession();
    if (authUser != null) {
      final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
          .instance
          .collection('users')
          .doc(authUser.uid)
          .get();
      userData = doc.data();
    }
    final AdminPermissions perms = AdminPermissions.fromUserDoc(userData);
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
    _overviewEpoch++;
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
  const _OverviewPane({super.key});

  @override
  State<_OverviewPane> createState() => _OverviewPaneState();
}

class _OverviewPaneState extends State<_OverviewPane> {
  Future<Map<String, dynamic>>? _statsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final Future<Map<String, dynamic>> next =
        AdminBackendService.dashboardStats();
    setState(() {
      _statsFuture = next;
    });
    await next;
  }

  String _statsErrorMessage(Object err) {
    if (err is FirebaseFunctionsException && err.code == 'permission-denied') {
      return 'Admin dashboard stats are unavailable for this session. '
          'Tap the key icon to refresh, or deploy the latest admin '
          'Cloud Functions.\n\n$err';
    }
    if (err is PlatformException &&
        (err.message ?? '').toLowerCase().contains('permission-denied')) {
      return 'Admin dashboard stats were denied by the server. '
          'Pull to refresh after tapping the key icon.\n\n$err';
    }
    return 'Stats error: $err';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _statsFuture,
        builder: (context, snap) {
          if (_statsFuture == null || snap.connectionState == ConnectionState.waiting) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(child: CircularProgressIndicator()),
              ],
            );
          }
          if (snap.hasError) {
            final String message = _statsErrorMessage(snap.error!);
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
          final Map<String, dynamic> d = snap.data ?? <String, dynamic>{};
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

          final List<(AdminOverviewMetric, int)> tiles =
              <(AdminOverviewMetric, int)>[
            (AdminOverviewMetric.openReports, g('openReports')),
            (AdminOverviewMetric.flaggedVideos, g('flaggedVideos')),
            (AdminOverviewMetric.failedUploads, g('failedUploads')),
            (AdminOverviewMetric.bannedUsers, g('bannedUsers')),
            (AdminOverviewMetric.newUsersToday, g('newUsersToday')),
            (AdminOverviewMetric.totalUploads, g('totalUploads')),
            (AdminOverviewMetric.processingVideos, g('processingVideos')),
          ];
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: tiles
                .map(
                  ((AdminOverviewMetric, int) e) => Card(
                    child: ListTile(
                      title: Text(e.$1.title),
                      subtitle: Text(e.$1.description),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${e.$2}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => AdminOverviewDetailView(
                              metric: e.$1,
                              summaryCount: e.$2,
                            ),
                          ),
                        );
                      },
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
