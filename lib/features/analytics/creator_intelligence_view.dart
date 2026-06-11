import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/support_shell_style.dart';
import '../../features/billing/subscription_provider.dart';
import '../../routing/app_navigator.dart';
import '../../services/creator_intelligence_analytics_service.dart';
import '../../shared/analytics/analytics_event_constants.dart';
import 'models/analytics_profile.dart';
import 'personalization_hooks.dart';

class CreatorIntelligenceView extends ConsumerStatefulWidget {
  const CreatorIntelligenceView({super.key});

  @override
  ConsumerState<CreatorIntelligenceView> createState() =>
      _CreatorIntelligenceViewState();
}

class _CreatorIntelligenceViewState extends ConsumerState<CreatorIntelligenceView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<int> _allowedWindows() {
    const List<int> options = <int>[7, 30, 90, 365];
    final int maxDays = ref.read(subscriptionSnapshotProvider).valueOrNull
            ?.entitlements.analyticsWindowDays ??
        7;
    final int capped = maxDays < 7 ? 7 : maxDays;
    return options.where((int d) => d <= capped).toList();
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final AsyncValue<AnalyticsProfile> profileAsync =
        ref.watch(analyticsProfileProvider);
    final List<int> windows = _allowedWindows();
    return Scaffold(
      backgroundColor: shell.scaffold,
      appBar: AppBar(
        backgroundColor: shell.scaffold,
        foregroundColor: shell.onChrome,
        title: const Text('Creator Intelligence'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const <Tab>[
            Tab(text: 'Overview'),
            Tab(text: 'Content'),
            Tab(text: 'Tippy'),
            Tab(text: 'Growth'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: <Widget>[
          _OverviewTab(
            shell: shell,
            profileAsync: profileAsync,
            allowedWindows: windows,
          ),
          _ContentInsightsTab(shell: shell, allowedWindows: windows),
          _TippyTab(shell: shell, profileAsync: profileAsync),
          _GrowthTab(shell: shell, allowedWindows: windows),
        ],
      ),
    );
  }
}

class _GrowthTab extends StatelessWidget {
  const _GrowthTab({
    required this.shell,
    required this.allowedWindows,
  });

  final StSupportShellStyle shell;
  final List<int> allowedWindows;

  @override
  Widget build(BuildContext context) {
    final String tierWindow = allowedWindows.isEmpty
        ? '7'
        : '${allowedWindows.last}';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          'Platform growth trends respect your subscription window '
          '(up to $tierWindow days).',
          style: TextStyle(color: shell.muted, height: 1.4),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {
            AppNavigator.openGrowthAnalytics(context);
          },
          icon: const Icon(Icons.trending_up),
          label: const Text('Open Growth Analytics'),
        ),
      ],
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({
    required this.shell,
    required this.profileAsync,
    required this.allowedWindows,
  });

  final StSupportShellStyle shell;
  final AsyncValue<AnalyticsProfile> profileAsync;
  final List<int> allowedWindows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AnalyticsProfile profile =
        profileAsync.valueOrNull?.toUserFacing() ?? AnalyticsProfile.empty;
    final String stageLabel = _stageLabel(profile.creatorStage);
    final String windowLabel = allowedWindows.isEmpty
        ? '7 days'
        : '${allowedWindows.last}-day history';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          kAnalyticsPrivacyNotice,
          style: TextStyle(color: shell.muted, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 16),
        _MetricCard(
          shell: shell,
          title: 'Creator stage',
          value: stageLabel,
          subtitle: 'Based on your recent activity',
        ),
        _MetricCard(
          shell: shell,
          title: 'Engagement score',
          value: '${profile.engagementScore}',
          subtitle: windowLabel,
        ),
        _MetricCard(
          shell: shell,
          title: 'Preferred content',
          value: _formatType(profile.preferredContentType),
          subtitle: 'What you interact with most',
        ),
        if (profile.favoriteCategories.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            'Top interests',
            style: TextStyle(
              color: shell.onChrome,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: () {
              final List<MapEntry<String, int>> sorted =
                  profile.favoriteCategories.entries.toList()
                    ..sort(
                      (MapEntry<String, int> a, MapEntry<String, int> b) =>
                          b.value.compareTo(a.value),
                    );
              return sorted
                  .take(5)
                  .map(
                    (MapEntry<String, int> e) => Chip(
                      label: Text('${e.key} (${e.value})'),
                      backgroundColor: shell.surfaceCard,
                    ),
                  )
                  .toList();
            }(),
          ),
        ],
        if (profile.lastActiveAt != null) ...<Widget>[
          const SizedBox(height: 16),
          Text(
            'Last active ${DateFormat.MMMd().format(profile.lastActiveAt!)}',
            style: TextStyle(color: shell.muted, fontSize: 12),
          ),
        ],
      ],
    );
  }

  String _stageLabel(String stage) {
    switch (stage) {
      case 'established':
        return 'Established creator';
      case 'growing':
        return 'Growing creator';
      default:
        return 'Getting started';
    }
  }

  String _formatType(String type) {
    if (type.isEmpty) {
      return 'Videos';
    }
    return type[0].toUpperCase() + type.substring(1);
  }
}

class _ContentInsightsTab extends ConsumerStatefulWidget {
  const _ContentInsightsTab({
    required this.shell,
    required this.allowedWindows,
  });

  final StSupportShellStyle shell;
  final List<int> allowedWindows;

  @override
  ConsumerState<_ContentInsightsTab> createState() =>
      _ContentInsightsTabState();
}

class _ContentInsightsTabState extends ConsumerState<_ContentInsightsTab> {
  int _windowDays = 7;
  bool _loading = true;
  Map<String, int> _eventTotals = <String, int>{};

  @override
  void initState() {
    super.initState();
    _windowDays = widget.allowedWindows.isNotEmpty
        ? widget.allowedWindows.last
        : 7;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    final List<Map<String, dynamic>> events = await ref
        .read(creatorIntelligenceAnalyticsProvider)
        .loadRecentEvents(windowDays: _windowDays, uid: user.uid);
    final Map<String, int> totals = <String, int>{};
    for (final Map<String, dynamic> event in events) {
      final String type = (event['eventType'] as String?) ?? 'unknown';
      totals[type] = (totals[type] ?? 0) + 1;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _eventTotals = totals;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final int views = _eventTotals[AnalyticsEventTypes.videoViewed] ?? 0;
    final int completed =
        _eventTotals[AnalyticsEventTypes.videoCompleted] ?? 0;
    final int likes = _eventTotals[AnalyticsEventTypes.postLiked] ?? 0;
    final int saves = _eventTotals[AnalyticsEventTypes.postSaved] ?? 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (widget.allowedWindows.length > 1)
          SegmentedButton<int>(
            segments: widget.allowedWindows
                .map(
                  (int d) => ButtonSegment<int>(
                    value: d,
                    label: Text('${d}d'),
                  ),
                )
                .toList(),
            selected: <int>{_windowDays},
            onSelectionChanged: (Set<int> selected) {
              setState(() {
                _windowDays = selected.first;
                _loading = true;
              });
              _load();
            },
          ),
        const SizedBox(height: 16),
        _MetricCard(
          shell: widget.shell,
          title: 'Videos watched',
          value: '$views',
          subtitle: 'Last $_windowDays days',
        ),
        _MetricCard(
          shell: widget.shell,
          title: 'Videos completed',
          value: '$completed',
          subtitle: views > 0
              ? '${((completed / views) * 100).toStringAsFixed(0)}% completion'
              : 'Completion rate',
        ),
        _MetricCard(
          shell: widget.shell,
          title: 'Likes & saves',
          value: '${likes + saves}',
          subtitle: '$likes likes · $saves saves',
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            AppNavigator.openVideoInsights(context);
          },
          icon: const Icon(Icons.insights_outlined),
          label: const Text('Open per-video insights'),
        ),
      ],
    );
  }
}

class _TippyTab extends StatelessWidget {
  const _TippyTab({
    required this.shell,
    required this.profileAsync,
  });

  final StSupportShellStyle shell;
  final AsyncValue<AnalyticsProfile> profileAsync;

  @override
  Widget build(BuildContext context) {
    final AnalyticsProfile profile =
        profileAsync.valueOrNull?.toUserFacing() ?? AnalyticsProfile.empty;
    const DefaultAnalyticsPersonalizationHooks hooks =
        kDefaultPersonalizationHooks;
    final List<String> prompts = hooks.recommendTippyPrompts(profile);
    final List<String> actions = profile.recommendedNextActions;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          'Suggested next steps',
          style: TextStyle(
            color: shell.onChrome,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (actions.isEmpty && prompts.isEmpty)
          Text(
            'Ask Tippy a question to unlock personalized recommendations.',
            style: TextStyle(color: shell.muted),
          ),
        ...actions.map(
          (String action) => Card(
            color: shell.surfaceCard,
            child: ListTile(
              leading: Icon(
                Icons.lightbulb_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(action, style: TextStyle(color: shell.onChrome)),
            ),
          ),
        ),
        if (prompts.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Text(
            'Try asking Tippy',
            style: TextStyle(
              color: shell.onChrome,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...prompts.map(
            (String prompt) => Card(
              color: shell.surfaceCard,
              child: ListTile(
                title: Text(prompt, style: TextStyle(color: shell.onChrome)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  AppNavigator.openTippyChat(context);
                },
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {
            AppNavigator.openTippyChat(context);
          },
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Open Tippy'),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.shell,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final StSupportShellStyle shell;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: shell.surfaceCard,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: TextStyle(color: shell.muted, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: shell.onChrome,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: shell.muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
