import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../models/insights_data.dart';
import '../models/profile_video.dart';
import '../services/insights_firebase_service.dart';
import '../services/video_analytics_aggregation_service.dart';
import 'insights_overview_tab.dart';
import 'insights_viewers_tab.dart';
import 'insights_engagement_tab.dart';
import 'video_selector_widget.dart';

/// Main Insights View with tabbed interface for video analytics
enum _InsightsLoadState { loading, ready, empty, error }

class InsightsView extends ConsumerStatefulWidget {
  final String videoId;
  final String videoTitle;

  const InsightsView({
    super.key,
    required this.videoId,
    required this.videoTitle,
  });

  @override
  ConsumerState<InsightsView> createState() => _InsightsViewState();
}

class _InsightsViewState extends ConsumerState<InsightsView>
    with TickerProviderStateMixin {
  late TabController _tabController;
  InsightsData? _insightsData;
  _InsightsLoadState _loadState = _InsightsLoadState.loading;
  String? _errorMessage;
  ProfileVideo? _selectedVideo;
  StreamSubscription<InsightsData?>? _insightsSubscription;

  @override
  void initState() {
    super.initState();
    debugPrint(
        '🔍 InsightsView initState called for videoId: ${widget.videoId}');
    _tabController = TabController(length: 3, vsync: this);
    _startRealTimeInsights(widget.videoId);
    _loadInsightsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _insightsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadInsightsData() async {
    final videoId = _selectedVideo?.id ?? widget.videoId;
    final insightsService = ref.read(insightsFirebaseServiceProvider);

    debugPrint('🔍 InsightsView: Loading insights for videoId: $videoId');

    if (mounted) {
      setState(() {
        _loadState = _InsightsLoadState.loading;
        _errorMessage = null;
      });
    }

    try {
      // First, trigger aggregation to ensure we have the latest data
      final aggregationService = VideoAnalyticsAggregationService();
      await aggregationService.aggregateVideoAnalytics(videoId);

      // Then fetch the aggregated insights
      final insights = await insightsService.getVideoInsights(videoId);

      if (mounted) {
        setState(() {
          if (insights != null) {
            debugPrint(
                '✅ InsightsView: Real data loaded - Views: ${insights.overview.totalViews}, Likes: ${insights.engagement.likes}');
            _insightsData = insights;
            _loadState = _InsightsLoadState.ready;
          } else {
            debugPrint(
                '⚠️ InsightsView: No analytics data found for video: $videoId');
            _insightsData = null;
            _loadState = _InsightsLoadState.empty;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          debugPrint('❌ InsightsView: Error loading insights: $e');
          _insightsData = null;
          _errorMessage = e.toString();
          _loadState = _InsightsLoadState.error;
        });
      }
      debugPrint('Error loading insights: $e');
    }
  }

  void _onVideoSelected(ProfileVideo video) {
    setState(() {
      _selectedVideo = video;
      _insightsData = null;
      _loadState = _InsightsLoadState.loading;
      _errorMessage = null;
    });

    // Cancel previous subscription
    _insightsSubscription?.cancel();

    _startRealTimeInsights(video.id);
    _loadInsightsData();
  }

  void _startRealTimeInsights(String videoId) {
    final insightsService = ref.read(insightsFirebaseServiceProvider);

    _insightsSubscription =
        insightsService.listenToVideoInsights(videoId).listen(
      (insights) {
        if (mounted && insights != null) {
          setState(() {
            _insightsData = insights;
            _loadState = _InsightsLoadState.ready;
            _errorMessage = null;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _loadState = _InsightsLoadState.error;
            _errorMessage = error.toString();
          });
        }
        debugPrint('Real-time insights error: $error');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildVideoSelector(),
              _buildTabBar(),
              Expanded(
                child: _buildBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Video Insights',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.videoTitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Share button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _shareInsights();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.share_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSelector() {
    return VideoSelectorWidget(
      selectedVideoId: widget.videoId,
      onVideoSelected: _onVideoSelected,
    );
  }

  Widget _buildTabBar() {
    return Opacity(
      opacity: _loadState == _InsightsLoadState.ready ? 1 : 0.65,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.all(4),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Viewers'),
            Tab(text: 'Engagement'),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_loadState) {
      case _InsightsLoadState.loading:
        return _buildLoadingState();
      case _InsightsLoadState.error:
        return _buildErrorState();
      case _InsightsLoadState.empty:
        return _isLikelyCollectingFreshData()
            ? _buildDataCollectingState()
            : _buildNoDataState();
      case _InsightsLoadState.ready:
        final insights = _insightsData;
        if (insights == null) {
          return _buildNoDataState();
        }
        return TabBarView(
          controller: _tabController,
          children: [
            InsightsOverviewTab(insights: insights),
            InsightsViewersTab(insights: insights),
            InsightsEngagementTab(insights: insights),
          ],
        );
    }
  }

  bool _isLikelyCollectingFreshData() {
    final video = _selectedVideo;
    if (video == null) {
      return false;
    }

    final hoursSinceUpload = DateTime.now().difference(video.createdAt).inHours;
    return hoursSinceUpload < 24;
  }

  Widget _buildDataCollectingState() {
    final remainingHours = _selectedVideo != null
        ? 24 - DateTime.now().difference(_selectedVideo!.createdAt).inHours
        : 24;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.analytics_outlined,
                color: Colors.white70,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Collecting Data',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'We\'re gathering insights for your video. This process takes up to 24 hours after upload.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 16,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.schedule,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    remainingHours > 1
                        ? 'Estimated time remaining: ${remainingHours.toInt()} hours'
                        : 'Estimated time remaining: ${(remainingHours * 60).toInt()} minutes',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'What we\'re tracking:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTrackingItem('Views and watch time'),
                  _buildTrackingItem('Engagement rates'),
                  _buildTrackingItem('Audience demographics'),
                  _buildTrackingItem('Traffic sources'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: Colors.green.withValues(alpha: 0.8),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          SizedBox(height: 16),
          Text(
            'Loading insights...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState() {
    return _buildStatusCard(
      icon: Icons.insights_outlined,
      title: 'No Insights Yet',
      message:
          'This video does not have enough processed analytics to show a breakdown yet. Check back after views and engagement start coming in.',
      accentColor: const Color(0xFF40DCD1),
      actionLabel: 'Refresh',
      onAction: _loadInsightsData,
    );
  }

  Widget _buildErrorState() {
    return _buildStatusCard(
      icon: Icons.cloud_off_outlined,
      title: 'Insights Unavailable',
      message:
          'We couldn\'t load analytics for this video right now. No placeholder data is being shown.',
      detail: _errorMessage,
      accentColor: Colors.orange,
      actionLabel: 'Try Again',
      onAction: _loadInsightsData,
    );
  }

  Widget _buildStatusCard({
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
        padding: const EdgeInsets.all(32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              if (detail != null && detail.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    detail,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1C135D),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: Text(actionLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareInsights() async {
    final insights = _insightsData;
    if (insights == null || _loadState != _InsightsLoadState.ready) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insights can be shared once analytics are available.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final shareText = StringBuffer()
      ..writeln('Video insights for "${widget.videoTitle}"')
      ..writeln()
      ..writeln('Views: ${insights.overview.totalViews}')
      ..writeln('Watch time: ${insights.overview.totalWatchTime.inMinutes} min')
      ..writeln('Retention: ${(insights.overview.retentionRate * 100).toStringAsFixed(1)}%')
      ..writeln('Likes: ${insights.engagement.likes}')
      ..writeln('Comments: ${insights.engagement.comments}')
      ..writeln('Shares: ${insights.engagement.shares}')
      ..writeln('Unique viewers: ${insights.viewers.uniqueViewers}');

    await SharePlus.instance.share(
      ShareParams(
        text: shareText.toString(),
        subject: 'Video insights for ${widget.videoTitle}',
      ),
    );
  }
}
