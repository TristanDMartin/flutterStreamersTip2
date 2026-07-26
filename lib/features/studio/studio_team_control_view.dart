import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/support_shell_style.dart';
import '../../routing/app_routes.dart';
import '../tippy/models/tippy_launch_context.dart';
import 'models/studio_team_control_models.dart';
import 'studio_team_control_service.dart';

class StudioTeamControlView extends ConsumerStatefulWidget {
  const StudioTeamControlView({super.key});

  @override
  ConsumerState<StudioTeamControlView> createState() =>
      _StudioTeamControlViewState();
}

class _StudioTeamControlViewState extends ConsumerState<StudioTeamControlView> {
  final StudioTeamControlService _service = StudioTeamControlService();
  StudioTeamControl? _control;
  String? _error;
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final StudioTeamControlResponse data =
          await _service.fetchTeamControl();
      if (!mounted) {
        return;
      }
      setState(() {
        _control = data.control;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await _service.exportWeeklyReportJson();
    } catch (error) {
      if (!mounted) {
        return;
      }
      final String message = error.toString();
      if (message.contains('Creator Studio')) {
        Navigator.of(context).pushNamed(AppRoutes.upgrade);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Scaffold(
      backgroundColor: shell.scaffold,
      appBar: AppBar(
        backgroundColor: shell.scaffold,
        foregroundColor: shell.onChrome,
        title: const Text('Team & automation'),
        actions: <Widget>[
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: shell.pageGradient,
          ),
        ),
        child: _buildBody(shell),
      ),
    );
  }

  Widget _buildBody(StSupportShellStyle shell) {
    if (_loading && _control == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _control == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(_error!, style: TextStyle(color: shell.mutedStrong)),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final StudioTeamControl control = _control!;
    return RefreshIndicator(
      onRefresh: _load,
      color: shell.refreshColor,
      backgroundColor: shell.refreshBackground,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          Text(
            'Studio Team Control',
            style: TextStyle(
              color: shell.onChrome,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Assignments, approvals, automation, exports, and campaign '
            'reporting from your shared workspace.',
            style: TextStyle(color: shell.mutedStrong),
          ),
          const SizedBox(height: 16),
          _card(
            shell,
            title: 'Campaign reporting',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  control.campaignNextFocus,
                  style: TextStyle(color: shell.onChrome),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _chip(
                      shell,
                      'Published',
                      control.targetPostsPerWeek == null
                          ? '${control.postsPublishedThisWeek}'
                          : '${control.postsPublishedThisWeek}/'
                              '${control.targetPostsPerWeek}',
                    ),
                    _chip(
                      shell,
                      'Open tasks',
                      '${control.openAssignments}',
                    ),
                    _chip(
                      shell,
                      'Approvals',
                      '${control.pendingApprovals}',
                    ),
                    _chip(
                      shell,
                      'Team',
                      control.limit > 0
                          ? '${control.activeCount}/${control.limit}'
                          : '${control.activeCount}',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...control.campaignNotes.map(
                  (String note) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '· $note',
                      style: TextStyle(color: shell.mutedStrong),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!control.entitled) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              'Unlock Studio team & automation',
              style: TextStyle(
                color: shell.onChrome,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...control.previews.map(
              (StudioTeamPreview preview) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _card(
                  shell,
                  title: preview.title,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        preview.teaser,
                        style: TextStyle(color: shell.mutedStrong),
                      ),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(context).pushNamed(AppRoutes.upgrade);
                        },
                        child: Text(preview.upgradeLabel),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...<Widget>[
            const SizedBox(height: 16),
            _card(
              shell,
              title: 'Team',
              child: control.members.isEmpty
                  ? Text(
                      'No teammates yet.',
                      style: TextStyle(color: shell.mutedStrong),
                    )
                  : Column(
                      children: control.members
                          .map(
                            (StudioTeamMemberSummary m) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                m.displayName,
                                style: TextStyle(color: shell.onChrome),
                              ),
                              trailing: Text(
                                m.role,
                                style: TextStyle(color: shell.muted),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
            ),
            const SizedBox(height: 12),
            _card(
              shell,
              title: 'Assignments',
              child: control.assignments.isEmpty
                  ? Text(
                      'No open assignments.',
                      style: TextStyle(color: shell.mutedStrong),
                    )
                  : Column(
                      children: control.assignments
                          .map(
                            (StudioAssignmentItem a) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                a.title,
                                style: TextStyle(color: shell.onChrome),
                              ),
                              subtitle: Text(
                                '${a.assigneeDisplayName ?? 'Unassigned'}'
                                ' · ${a.status}',
                                style: TextStyle(color: shell.muted),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
            ),
            const SizedBox(height: 12),
            _card(
              shell,
              title: 'Approvals',
              child: control.approvals.isEmpty
                  ? Text(
                      'Approval queue is clear.',
                      style: TextStyle(color: shell.mutedStrong),
                    )
                  : Column(
                      children: control.approvals
                          .map(
                            (StudioApprovalItem a) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                a.title,
                                style: TextStyle(color: shell.onChrome),
                              ),
                              subtitle: Text(
                                a.kind.replaceAll('_', ' '),
                                style: TextStyle(color: shell.muted),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.of(context).pushNamed(
                                  AppRoutes.tippyChat,
                                  arguments: const TippyLaunchContext(),
                                );
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
            ),
            const SizedBox(height: 12),
            _card(
              shell,
              title: 'Automation',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    control.automationSummary,
                    style: TextStyle(color: shell.mutedStrong),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    control.automationActive
                        ? 'Status: Active'
                        : 'Status: Entitled / pending flag',
                    style: TextStyle(color: shell.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _card(
              shell,
              title: 'Exports',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    control.exportSummary,
                    style: TextStyle(color: shell.mutedStrong),
                  ),
                  const SizedBox(height: 10),
                  if (control.exportEntitled)
                    FilledButton(
                      onPressed: _exporting ? null : _export,
                      child: Text(
                        _exporting
                            ? 'Exporting…'
                            : 'Share weekly report JSON',
                      ),
                    )
                  else
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRoutes.upgrade);
                      },
                      child: const Text('Unlock exports'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card(
    StSupportShellStyle shell, {
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: shell.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: shell.surfaceCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              color: shell.onChrome,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _chip(StSupportShellStyle shell, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: shell.panelSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: shell.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: TextStyle(color: shell.muted, fontSize: 11)),
          Text(
            value,
            style: TextStyle(
              color: shell.onChrome,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
