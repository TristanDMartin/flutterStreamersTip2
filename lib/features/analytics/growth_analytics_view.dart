import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/support_shell_style.dart';
import '../../features/billing/subscription_provider.dart';
import '../../routing/app_navigator.dart';
import 'growth_analytics_service.dart';
import 'models/growth_data.dart';
import 'widgets/growth_platform_sparkline.dart';

const List<int> _kDayOptions = <int>[7, 30, 90, 365];

class GrowthPlatformMeta {
  const GrowthPlatformMeta({
    required this.key,
    required this.name,
    required this.color,
    required this.emoji,
  });

  final String key;
  final String name;
  final Color color;
  final String emoji;
}

const List<GrowthPlatformMeta> kGrowthPlatforms = <GrowthPlatformMeta>[
  GrowthPlatformMeta(
    key: 'twitch',
    name: 'Twitch',
    color: Color(0xFF9147FF),
    emoji: '🟣',
  ),
  GrowthPlatformMeta(
    key: 'youtube',
    name: 'YouTube',
    color: Color(0xFFFF0033),
    emoji: '🔴',
  ),
  GrowthPlatformMeta(
    key: 'tiktok',
    name: 'TikTok',
    color: Color(0xFF00F2EA),
    emoji: '🩵',
  ),
  GrowthPlatformMeta(
    key: 'kick',
    name: 'Kick',
    color: Color(0xFF53FC18),
    emoji: '🟢',
  ),
];

class PlatformGrowthMetrics {
  const PlatformGrowthMetrics({
    required this.current,
    required this.start,
    required this.change,
    required this.pct,
    required this.c7,
    required this.p7,
  });

  final int current;
  final int start;
  final int change;
  final String pct;
  final int c7;
  final String p7;
}

PlatformGrowthMetrics computePlatformMetrics(
  List<PlatformGrowthPoint> series,
  int activeDays,
) {
  if (series.isEmpty) {
    return const PlatformGrowthMetrics(
      current: 0,
      start: 0,
      change: 0,
      pct: '0',
      c7: 0,
      p7: '0',
    );
  }
  final List<PlatformGrowthPoint> sorted = List<PlatformGrowthPoint>.from(series)
    ..sort((PlatformGrowthPoint a, PlatformGrowthPoint b) =>
        a.date.compareTo(b.date));
  final int current = sorted.last.value;
  final int windowStart = sorted.length > activeDays
      ? sorted.length - activeDays
      : 0;
  final int start = sorted[windowStart.clamp(0, sorted.length - 1)].value;
  final int change = current - start;
  final String pct = start == 0
      ? '0'
      : ((change / start) * 100).toStringAsFixed(1);
  final int c7Start = sorted.length > 7 ? sorted.length - 7 : 0;
  final int c7StartVal = sorted[c7Start.clamp(0, sorted.length - 1)].value;
  final int c7 = current - c7StartVal;
  final String p7 = c7StartVal == 0
      ? '0'
      : ((c7 / c7StartVal) * 100).toStringAsFixed(1);
  return PlatformGrowthMetrics(
    current: current,
    start: start,
    change: change,
    pct: pct,
    c7: c7,
    p7: p7,
  );
}

String formatGrowthCount(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return value.toString();
}

class GrowthAnalyticsView extends ConsumerStatefulWidget {
  const GrowthAnalyticsView({super.key});

  @override
  ConsumerState<GrowthAnalyticsView> createState() =>
      _GrowthAnalyticsViewState();
}

class _GrowthAnalyticsViewState extends ConsumerState<GrowthAnalyticsView> {
  GrowthData? _data;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  int _activeDays = 30;
  String? _lastUpdated;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData(showLoading: true);
    });
  }

  int _maxAnalyticsDays() {
    final int fromApi = ref.read(subscriptionSnapshotProvider).valueOrNull
            ?.entitlements.analyticsWindowDays ??
        7;
    return fromApi < 7 ? 7 : fromApi;
  }

  List<int> _allowedDayOptions() {
    final int maxDays = _maxAnalyticsDays();
    return _kDayOptions.where((int d) => d <= maxDays).toList();
  }

  Future<void> _loadData({required bool showLoading}) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'Sign in to view growth analytics.';
        _isLoading = false;
      });
      return;
    }
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final GrowthAnalyticsService service =
          ref.read(growthAnalyticsServiceProvider);
      final GrowthData data = await service.loadGrowthData(
        userId: user.uid,
        days: _maxAnalyticsDays(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _data = data;
        _lastUpdated = data.lastUpdated;
        _isLoading = false;
        _errorMessage = null;
      });
    } on GrowthAnalyticsException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Could not load growth analytics.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRefresh() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || _isRefreshing) {
      return;
    }
    setState(() {
      _isRefreshing = true;
    });
    try {
      await ref
          .read(growthAnalyticsServiceProvider)
          .refreshGrowthData(userId: user.uid);
      await _loadData(showLoading: false);
    } on GrowthAnalyticsException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = e.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  bool _hasAnyConnection(GrowthData? data) {
    if (data == null) {
      return false;
    }
    for (final GrowthPlatformMeta platform in kGrowthPlatforms) {
      final PlatformStatusSnapshot? status = data.platformStatus[platform.key];
      if (status?.connected == true) {
        return true;
      }
      if (data.seriesFor(platform.key).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final List<int> dayOptions = _allowedDayOptions();
    if (!dayOptions.contains(_activeDays)) {
      _activeDays = dayOptions.isNotEmpty ? dayOptions.last : 7;
    }
    return Scaffold(
      backgroundColor: shell.scaffold,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: shell.pageGradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildHeader(context, shell, dayOptions),
              Expanded(
                child: _buildBody(context, shell),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    StSupportShellStyle shell,
    List<int> dayOptions,
  ) {
    final String updatedLabel = _lastUpdated != null
        ? 'Updated ${_formatUpdated(_lastUpdated!)}'
        : 'Loading...';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.arrow_back, color: shell.onChrome),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Growth Analytics',
                      style: TextStyle(
                        color: shell.onChrome,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      updatedLabel,
                      style: TextStyle(
                        color: shell.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _isRefreshing ? null : _handleRefresh,
                icon: _isRefreshing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: shell.onChrome,
                        ),
                      )
                    : Icon(Icons.refresh_rounded, color: shell.onChrome),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: dayOptions.map((int days) {
                final bool selected = _activeDays == days;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(days == 365 ? '1Y' : '${days}D'),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        _activeDays = days;
                      });
                    },
                    selectedColor: shell.chipSelectedBg,
                    backgroundColor: shell.chipUnselectedBg,
                    labelStyle: TextStyle(
                      color: selected
                          ? shell.chipSelectedFg
                          : shell.chipUnselectedFg,
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide(
                      color: selected
                          ? shell.chipSelectedBorder
                          : shell.chipUnselectedBorder,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, StSupportShellStyle shell) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SelectableText.rich(
            TextSpan(
              text: _errorMessage!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final GrowthData data = _data ?? GrowthData.empty;
    final bool hasConnection = _hasAnyConnection(data);
    int totalNow = 0;
    int totalOld = 0;
    for (final GrowthPlatformMeta platform in kGrowthPlatforms) {
      final PlatformGrowthMetrics metrics = computePlatformMetrics(
        data.seriesFor(platform.key),
        _activeDays,
      );
      totalNow += metrics.current;
      totalOld += metrics.start;
    }
    final int totalChange = totalNow - totalOld;
    final String totalPct = totalOld == 0
        ? '0'
        : ((totalChange / totalOld) * 100).toStringAsFixed(1);
    return RefreshIndicator(
      onRefresh: () => _loadData(showLoading: false),
      color: shell.refreshColor,
      backgroundColor: shell.refreshBackground,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: <Widget>[
          if (!hasConnection) _buildConnectBanner(context, shell),
          _buildSummaryGrid(
            shell: shell,
            totalNow: totalNow,
            totalChange: totalChange,
            totalPct: totalPct,
            data: data,
          ),
          const SizedBox(height: 16),
          _buildGrowthChartCard(shell, data),
          const SizedBox(height: 16),
          _buildPlatformBreakdown(shell, data, totalNow),
          if (data.topContent.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            _buildTopContent(shell, data),
          ],
          if (data.crosspost.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            _buildCrossPostSection(shell, data),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectBanner(
    BuildContext context,
    StSupportShellStyle shell,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            'Connect your platforms to see your growth',
            style: TextStyle(
              color: shell.onChrome,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Connect Twitch, YouTube, TikTok, or Kick to track Total Reach, '
            'follower growth, and top performing content.',
            style: TextStyle(
              color: shell.muted,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => AppNavigator.openLinkedPlatforms(context),
            child: const Text('Connect Platforms'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid({
    required StSupportShellStyle shell,
    required int totalNow,
    required int totalChange,
    required String totalPct,
    required GrowthData data,
  }) {
    return Column(
      children: <Widget>[
        _MetricCard(
          shell: shell,
          title: 'Total Reach',
          value: formatGrowthCount(totalNow),
          change: totalChange,
          pct: totalPct,
          accent: const Color(0xFF3D99F7),
          activeDays: _activeDays,
        ),
        const SizedBox(height: 10),
        ...kGrowthPlatforms.map((GrowthPlatformMeta platform) {
          final PlatformGrowthMetrics metrics = computePlatformMetrics(
            data.seriesFor(platform.key),
            _activeDays,
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MetricCard(
              shell: shell,
              title: platform.name,
              value: formatGrowthCount(metrics.current),
              change: metrics.change,
              pct: metrics.pct,
              accent: platform.color,
              activeDays: _activeDays,
              leadingEmoji: platform.emoji,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildGrowthChartCard(StSupportShellStyle shell, GrowthData data) {
    return Container(
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
            'Follower Growth Over Time',
            style: TextStyle(
              color: shell.onChrome,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          Text(
            'All platforms combined',
            style: TextStyle(color: shell.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: GrowthPlatformSparkline(
              platforms: kGrowthPlatforms,
              data: data,
              activeDays: _activeDays,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformBreakdown(
    StSupportShellStyle shell,
    GrowthData data,
    int totalNow,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: shell.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: shell.surfaceCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Platform Breakdown',
                  style: TextStyle(
                    color: shell.onChrome,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Live metrics across all connected accounts',
                  style: TextStyle(color: shell.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          ...kGrowthPlatforms.map((GrowthPlatformMeta platform) {
            final PlatformGrowthMetrics metrics = computePlatformMetrics(
              data.seriesFor(platform.key),
              _activeDays,
            );
            final String share = totalNow == 0
                ? '0'
                : ((metrics.current / totalNow) * 100).toStringAsFixed(0);
            final PlatformStatusSnapshot? status =
                data.platformStatus[platform.key];
            final String handle = status?.username != null
                ? '@${status!.username}'
                : '—';
            return ListTile(
              title: Text(
                '${platform.emoji} ${platform.name}',
                style: TextStyle(
                  color: shell.onChrome,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                handle,
                style: TextStyle(color: shell.muted, fontSize: 12),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    formatGrowthCount(metrics.current),
                    style: TextStyle(
                      color: shell.onChrome,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '$share% share',
                    style: TextStyle(color: shell.muted, fontSize: 12),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTopContent(StSupportShellStyle shell, GrowthData data) {
    return Container(
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
            'Top Performing Content',
            style: TextStyle(
              color: shell.onChrome,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ...data.topContent.take(5).map((GrowthTopContentItem item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.title,
                          style: TextStyle(
                            color: shell.onChrome,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${item.platform} • ${item.views} views',
                          style: TextStyle(color: shell.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (item.uplift.isNotEmpty)
                    Text(
                      item.uplift,
                      style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCrossPostSection(StSupportShellStyle shell, GrowthData data) {
    return Container(
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
            'Cross-Post Performance',
            style: TextStyle(
              color: shell.onChrome,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ...data.crosspost.take(5).map((GrowthCrossPostItem item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.title,
                    style: TextStyle(
                      color: shell.onChrome,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${item.platforms.join(', ')} • ${item.followGain}',
                    style: TextStyle(color: shell.muted, fontSize: 12),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatUpdated(String iso) {
    try {
      final DateTime parsed = DateTime.parse(iso).toLocal();
      return DateFormat('MMM d, h:mm a').format(parsed);
    } catch (_) {
      return iso;
    }
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.shell,
    required this.title,
    required this.value,
    required this.change,
    required this.pct,
    required this.accent,
    required this.activeDays,
    this.leadingEmoji,
  });

  final StSupportShellStyle shell;
  final String title;
  final String value;
  final int change;
  final String pct;
  final Color accent;
  final int activeDays;
  final String? leadingEmoji;

  @override
  Widget build(BuildContext context) {
    final bool positive = change >= 0;
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
            leadingEmoji != null ? '$leadingEmoji $title' : title,
            style: TextStyle(
              color: shell.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: shell.onChrome,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (positive ? Colors.green : Colors.red)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${positive ? '↑' : '↓'} ${pct.replaceAll('-', '')}%',
                  style: TextStyle(
                    color: positive ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'vs ${activeDays}d ago',
                style: TextStyle(color: shell.muted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
