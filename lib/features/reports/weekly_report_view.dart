import 'dart:async' show unawaited;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/support_shell_style.dart';
import '../../routing/app_navigator.dart';
import '../../routing/app_routes.dart';
import '../../services/retention_tracking_service.dart';
import 'models/weekly_report_models.dart';
import 'weekly_report_service.dart';

class WeeklyReportView extends ConsumerStatefulWidget {
  const WeeklyReportView({super.key});

  @override
  ConsumerState<WeeklyReportView> createState() => _WeeklyReportViewState();
}

class _WeeklyReportViewState extends ConsumerState<WeeklyReportView> {
  final WeeklyReportService _service = WeeklyReportService();
  WeeklyReportResponse? _data;
  String? _error;
  bool _loading = true;
  bool _didTrackView = false;

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
      final WeeklyReportResponse data = await _service.fetchWeeklyReport();
      if (!mounted) {
        return;
      }
      setState(() {
        _data = data;
        _loading = false;
      });
      _trackWeeklyReportViewed(data.report.level);
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

  void _trackWeeklyReportViewed(String level) {
    if (_didTrackView) {
      return;
    }
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return;
    }
    _didTrackView = true;
    unawaited(
      RetentionTrackingService.instance.trackViewedWeeklyReport(
        uid: uid,
        level: level,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final WeeklyReport? report = _data?.report;
    return Scaffold(
      backgroundColor: shell.scaffold,
      appBar: AppBar(
        backgroundColor: shell.scaffold,
        foregroundColor: shell.onChrome,
        title: const Text('Weekly report'),
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
        child: _buildBody(shell, report),
      ),
    );
  }

  Widget _buildBody(StSupportShellStyle shell, WeeklyReport? report) {
    if (_loading && report == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && report == null) {
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
    if (report == null) {
      return const SizedBox.shrink();
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: shell.refreshColor,
      backgroundColor: shell.refreshBackground,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          Text(
            report.period.label,
            style: TextStyle(color: shell.muted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            report.headline,
            style: TextStyle(
              color: shell.onChrome,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(report.summary, style: TextStyle(color: shell.mutedStrong)),
          const SizedBox(height: 8),
          Text(
            'Basic weekly recap is free — no AI credits charged.',
            style: TextStyle(color: shell.muted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          _sectionCard(
            shell,
            title: 'Weekly recap',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _statChip(
                      shell,
                      'Published',
                      report.basic.targetPosts == null
                          ? '${report.basic.postsPublished}'
                          : '${report.basic.postsPublished}/'
                              '${report.basic.targetPosts}',
                    ),
                    _statChip(
                      shell,
                      'Streak',
                      '${report.basic.uploadStreak}d',
                    ),
                    _statChip(
                      shell,
                      'Missions',
                      '${report.basic.missionsCompletedApprox}',
                    ),
                    _statChip(shell, 'Level', report.level),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Next focus: ${report.basic.nextFocus}',
                  style: TextStyle(color: shell.onChrome),
                ),
                const SizedBox(height: 6),
                Text(report.basic.tip, style: TextStyle(color: shell.mutedStrong)),
              ],
            ),
          ),
          if (report.growth != null) ...<Widget>[
            const SizedBox(height: 16),
            _sectionCard(
              shell,
              title: 'Growth report',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _statChip(
                        shell,
                        'Score',
                        '${report.growth!.creatorScore ?? '—'}',
                      ),
                      _statChip(
                        shell,
                        'Momentum',
                        '${report.growth!.growthMomentum ?? '—'}',
                      ),
                      _statChip(
                        shell,
                        'Strongest',
                        report.growth!.strongestCategory ?? '—',
                      ),
                      _statChip(
                        shell,
                        'Weakest',
                        report.growth!.weakestCategory ?? '—',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _bulletBlock(shell, 'What worked', report.growth!.wins),
                  _bulletBlock(shell, 'Experiments', report.growth!.experiments),
                  _bulletBlock(shell, 'Next actions', report.growth!.actions),
                  _topContentBlock(shell, report.growth!.topContent),
                ],
              ),
            ),
          ],
          if (report.business != null) ...<Widget>[
            const SizedBox(height: 16),
            _sectionCard(
              shell,
              title: 'Business report',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    report.business!.partnershipReadiness,
                    style: TextStyle(color: shell.onChrome),
                  ),
                  if (report.business!.teamHint != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      report.business!.teamHint!,
                      style: TextStyle(color: shell.mutedStrong),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _bulletBlock(shell, 'Benchmarks', report.business!.benchmarks),
                  _bulletBlock(
                    shell,
                    'Campaign notes',
                    report.business!.campaignNotes,
                  ),
                  if (report.business!.exportAvailable) ...<Widget>[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => AppNavigator.openStudioTeamControl(
                        context,
                      ),
                      child: const Text('Open Team Control for export'),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (report.previews.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              'Unlock more depth',
              style: TextStyle(
                color: shell.onChrome,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...report.previews.map(
              (WeeklyReportPreview preview) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _sectionCard(
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
          ],
        ],
      ),
    );
  }

  Widget _sectionCard(
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

  Widget _statChip(StSupportShellStyle shell, String label, String value) {
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
          const SizedBox(height: 2),
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

  Widget _bulletBlock(
    StSupportShellStyle shell,
    String title,
    List<String> items,
  ) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              color: shell.onChrome,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          ...items.map(
            (String item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '· $item',
                style: TextStyle(color: shell.mutedStrong),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topContentBlock(
    StSupportShellStyle shell,
    List<WeeklyReportTopContent> items,
  ) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Top content',
            style: TextStyle(
              color: shell.onChrome,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          ...items.map(
            (WeeklyReportTopContent item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(color: shell.mutedStrong),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.metricLabel != null &&
                      item.metricLabel!.isNotEmpty) ...<Widget>[
                    const SizedBox(width: 8),
                    Text(
                      item.metricLabel!,
                      style: TextStyle(
                        color: shell.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
