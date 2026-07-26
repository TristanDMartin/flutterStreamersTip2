import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../core/theme/support_shell_style.dart';
import '../features/analytics/widgets/creator_insights_hero.dart';
import '../features/billing/subscription_provider.dart';
import '../models/insights_data.dart';
import '../models/profile_video.dart';
import '../services/insights_firebase_service.dart';
import '../services/video_analytics_aggregation_service.dart';
import '../utils/insights_metrics.dart';
import '../utils/user_facing_error.dart';
import 'insights_engagement_tab.dart';
import 'insights_overview_tab.dart';
import 'insights_viewers_tab.dart';
import 'video_selector_widget.dart';

enum _InsightsLoadState { loading, ready, empty, error, accessDenied }

class InsightsView extends ConsumerStatefulWidget {
  const InsightsView({
    super.key,
    required this.videoId,
    this.videoTitle,
  });

  final String videoId;
  final String? videoTitle;

  @override
  ConsumerState<InsightsView> createState() => _InsightsViewState();
}

class _InsightsViewState extends ConsumerState<InsightsView>
    with TickerProviderStateMixin {
  late TabController _tabController;
  CreatorInsightsSnapshot? _snapshot;
  _InsightsLoadState _loadState = _InsightsLoadState.loading;
  String? _errorMessage;
  ProfileVideo? _selectedVideo;
  StreamSubscription<CreatorInsightsSnapshot?>? _insightsSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _bootstrap(widget.videoId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _insightsSubscription?.cancel();
    super.dispose();
  }

  int _analyticsWindowDays() {
    return ref.read(subscriptionSnapshotProvider).valueOrNull
            ?.entitlements.analyticsWindowDays ??
        7;
  }

  Future<void> _bootstrap(String videoId) async {
    if (mounted) {
      setState(() {
        _loadState = _InsightsLoadState.loading;
        _errorMessage = null;
      });
    }
    try {
      final InsightsFirebaseService service =
          ref.read(insightsFirebaseServiceProvider);
      await VideoAnalyticsAggregationService().aggregateVideoAnalytics(videoId);
      final CreatorInsightsSnapshot? initial = await service.getCreatorInsights(
        videoId: videoId,
        analyticsWindowDays: _analyticsWindowDays(),
      );
      if (!mounted) {
        return;
      }
      if (initial == null) {
        setState(() {
          _loadState = _InsightsLoadState.empty;
        });
        return;
      }
      setState(() {
        _snapshot = initial;
        _selectedVideo = initial.video;
        _loadState = _InsightsLoadState.ready;
      });
      _startRealtime(initial.video.id);
    } on StateError catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadState = _InsightsLoadState.accessDenied;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadState = _InsightsLoadState.error;
        _errorMessage = UserFacingError.message(e);
      });
    }
  }

  void _startRealtime(String videoId) {
    final InsightsFirebaseService service =
        ref.read(insightsFirebaseServiceProvider);
    _insightsSubscription?.cancel();
    _insightsSubscription = service
        .watchCreatorInsights(
          videoId: videoId,
          analyticsWindowDays: _analyticsWindowDays(),
        )
        .listen(
      (CreatorInsightsSnapshot? value) {
        if (!mounted || value == null) {
          return;
        }
        setState(() {
          _snapshot = value;
          _selectedVideo = value.video;
          _loadState = _InsightsLoadState.ready;
          _errorMessage = null;
        });
      },
      onError: (Object error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _loadState = _InsightsLoadState.error;
          _errorMessage = UserFacingError.message(error);
        });
      },
    );
  }

  void _onVideoSelected(ProfileVideo video) {
    setState(() {
      _selectedVideo = video;
      _snapshot = null;
      _loadState = _InsightsLoadState.loading;
      _errorMessage = null;
    });
    _insightsSubscription?.cancel();
    unawaited(_bootstrap(video.id));
  }

  Future<void> _refreshCurrent() async {
    final String videoId = _selectedVideo?.id ?? widget.videoId;
    await _bootstrap(videoId);
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
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
              _buildHeader(shell),
              if (_loadState == _InsightsLoadState.ready &&
                  _snapshot != null) ...<Widget>[
                if (!_snapshot!.insights.isNotEnoughDataYet)
                  CreatorInsightsHero(
                    video: _snapshot!.video,
                    isLive: _snapshot!.isLive,
                    lastUpdated: _snapshot!.lastUpdated,
                    views: _snapshot!.insights.overview.totalViews,
                    likes: _snapshot!.insights.engagement.likes,
                    comments: _snapshot!.insights.overview.comments,
                    shares: _snapshot!.insights.overview.shares,
                    bookmarks: _snapshot!.insights.bookmarks,
                  ),
                _buildVideoSelector(),
              ],
              if (_loadState == _InsightsLoadState.ready &&
                  _snapshot != null &&
                  !_snapshot!.insights.isNotEnoughDataYet)
                _buildTabBar(shell),
              Expanded(child: _buildBody(shell)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(StSupportShellStyle shell) {
    final String title = widget.videoTitle ??
        _selectedVideo?.caption ??
        _snapshot?.video.caption ??
        'Creator Insights';
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
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
                  'Creator Insights',
                  style: TextStyle(
                    color: shell.onChrome,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: shell.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _exportInsightsJson,
            icon: Icon(Icons.download_rounded, color: shell.onChrome),
            tooltip: 'Export JSON',
          ),
          IconButton(
            onPressed: _shareInsights,
            icon: Icon(Icons.ios_share_rounded, color: shell.onChrome),
            tooltip: 'Share',
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSelector() {
    return VideoSelectorWidget(
      selectedVideoId: _selectedVideo?.id ?? widget.videoId,
      onVideoSelected: _onVideoSelected,
    );
  }

  Widget _buildTabBar(StSupportShellStyle shell) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: shell.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: shell.surfaceCardBorder),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: shell.chipSelectedBg,
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.all(4),
          labelColor: shell.chipSelectedFg,
          unselectedLabelColor: shell.chipUnselectedFg,
          dividerHeight: 0,
          tabs: const <Widget>[
            Tab(text: 'Overview'),
            Tab(text: 'Audience'),
            Tab(text: 'Engagement'),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(StSupportShellStyle shell) {
    switch (_loadState) {
      case _InsightsLoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case _InsightsLoadState.accessDenied:
        return _buildStatusCard(
          shell: shell,
          icon: Icons.lock_outline,
          title: 'Access denied',
          message: _errorMessage ??
              'You can only view insights for your own videos.',
          accentColor: Colors.redAccent,
        );
      case _InsightsLoadState.error:
        return _buildStatusCard(
          shell: shell,
          icon: Icons.cloud_off_outlined,
          title: 'Insights unavailable',
          message:
              'We could not load analytics right now. Only verified data is shown.',
          detail: _errorMessage,
          accentColor: Colors.orange,
          actionLabel: 'Try again',
          onAction: _refreshCurrent,
        );
      case _InsightsLoadState.empty:
        return _buildStatusCard(
          shell: shell,
          icon: Icons.insights_outlined,
          title: 'No insights yet',
          message:
              'Upload a video to start tracking views, engagement, and audience signals.',
          accentColor: const Color(0xFF3D99F7),
        );
      case _InsightsLoadState.ready:
        final InsightsData? insights = _snapshot?.insights;
        if (insights == null || insights.isNotEnoughDataYet) {
          return _buildStatusCard(
            shell: shell,
            icon: Icons.insights_outlined,
            title: 'Not enough data yet',
            message:
                'Keep sharing this video. Verified views and engagement will '
                'appear here — we never fill in sample numbers.',
            accentColor: const Color(0xFF3D99F7),
            actionLabel: 'Refresh',
            onAction: _refreshCurrent,
          );
        }
        final int windowDays = _analyticsWindowDays();
        return Column(
          children: <Widget>[
            if (insights.isEarlySignal)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _buildEarlySignalBanner(shell: shell),
              ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: <Widget>[
                  InsightsOverviewTab(
                    insights: insights,
                    analyticsWindowDays: windowDays,
                  ),
                  InsightsViewersTab(insights: insights),
                  InsightsEngagementTab(insights: insights),
                ],
              ),
            ),
          ],
        );
    }
  }

  Widget _buildEarlySignalBanner({required StSupportShellStyle shell}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF3D99F7).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF3D99F7).withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        'Early signal — under '
        '${InsightsDataAvailability.minViewsForReliableRates} views. '
        'Rates can swing a lot until more people watch.',
        style: TextStyle(
          color: shell.onChrome,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required StSupportShellStyle shell,
    required IconData icon,
    required String title,
    required String message,
    required Color accentColor,
    String? detail,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: shell.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: shell.surfaceCardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: accentColor, size: 40),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: shell.onChrome,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: shell.muted,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              if (detail != null && detail.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                SelectableText.rich(
                  TextSpan(
                    text: detail,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                    ),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: 16),
                FilledButton(onPressed: onAction, child: Text(actionLabel)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareInsights() async {
    final InsightsData? insights = _snapshot?.insights;
    if (insights == null || _loadState != _InsightsLoadState.ready) {
      return;
    }
    final String caption = _snapshot?.video.caption ?? widget.videoTitle ?? '';
    final double engagement = InsightsMetrics.engagementRatePercent(
      views: insights.overview.totalViews,
      likes: insights.engagement.likes,
      comments: insights.overview.comments,
      shares: insights.overview.shares,
      bookmarks: insights.bookmarks,
    );
    final StringBuffer shareText = StringBuffer()
      ..writeln('Creator insights for "$caption"')
      ..writeln()
      ..writeln('Views: ${insights.overview.totalViews}')
      ..writeln('Likes: ${insights.engagement.likes}')
      ..writeln('Comments: ${insights.overview.comments}')
      ..writeln('Shares: ${insights.overview.shares}')
      ..writeln('Saves: ${insights.bookmarks}')
      ..writeln(
        'Engagement: ${InsightsMetrics.formatPercent(engagement)}',
      );
    await SharePlus.instance.share(
      ShareParams(
        text: shareText.toString(),
        subject: 'Creator insights',
      ),
    );
  }

  Future<void> _exportInsightsJson() async {
    final CreatorInsightsSnapshot? snapshot = _snapshot;
    if (snapshot == null || _loadState != _InsightsLoadState.ready) {
      return;
    }
    final Map<String, dynamic> payload = <String, dynamic>{
      'videoId': snapshot.insights.videoId,
      'caption': snapshot.video.caption,
      'exportedAt': DateTime.now().toIso8601String(),
      'stats': snapshot.insights.toJson(),
    };
    final String jsonText = const JsonEncoder.withIndent('  ').convert(payload);
    await SharePlus.instance.share(
      ShareParams(
        text: jsonText,
        subject: 'video-insights-${snapshot.insights.videoId}.json',
      ),
    );
  }
}
