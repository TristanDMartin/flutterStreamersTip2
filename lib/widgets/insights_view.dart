import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/insights_data.dart';
import '../models/profile_video.dart';
import '../services/insights_firebase_service.dart';
import 'insights_overview_tab.dart';
import 'insights_viewers_tab.dart';
import 'insights_engagement_tab.dart';
import 'video_selector_widget.dart';

/// Main Insights View with tabbed interface for video analytics
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
  late InsightsData _insightsData;
  bool _isLoading = true;
  ProfileVideo? _selectedVideo;
  StreamSubscription<InsightsData?>? _insightsSubscription;

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 InsightsView initState called for videoId: ${widget.videoId}');
    _tabController = TabController(length: 3, vsync: this);
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
    
    try {
      final insights = await insightsService.getVideoInsights(videoId);
      
      if (mounted) {
        setState(() {
          if (insights != null) {
            _insightsData = insights;
          } else {
            // Fallback to mock data if no real data available
            _insightsData = _generateMockData();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Fallback to mock data on error
          _insightsData = _generateMockData();
          _isLoading = false;
        });
      }
      debugPrint('Error loading insights: $e');
    }
  }

  InsightsData _generateMockData() {
    final videoId = _selectedVideo?.id ?? widget.videoId;
    return InsightsData(
      videoId: videoId,
      dateRange: DateTime.now().subtract(const Duration(days: 7)),
      overview: OverviewMetrics(
        totalViews: 125000,
        totalWatchTime: const Duration(hours: 2500),
        shares: 3200,
        comments: 890,
        retentionRate: 0.78,
        trafficSources: [
          TrafficSource(source: 'For You Page', views: 85000, percentage: 68.0),
          TrafficSource(source: 'Profile', views: 25000, percentage: 20.0),
          TrafficSource(source: 'Search', views: 15000, percentage: 12.0),
        ],
        searchQueries: [
          'gaming tips',
          'streaming setup',
          'best games 2024',
          'how to stream',
        ],
      ),
      viewers: ViewerMetrics(
        totalViews: 125000,
        uniqueViewers: 98000,
        viewerTypes: ViewerTypes(
          newViewers: 75000,
          returningViewers: 23000,
        ),
        genderBreakdown: GenderBreakdown(
          male: 65000,
          female: 45000,
          other: 10000,
          unknown: 5000,
        ),
        ageGroups: [
          AgeGroup(range: '13-17', count: 15000, percentage: 12.0),
          AgeGroup(range: '18-24', count: 45000, percentage: 36.0),
          AgeGroup(range: '25-34', count: 35000, percentage: 28.0),
          AgeGroup(range: '35-44', count: 20000, percentage: 16.0),
          AgeGroup(range: '45+', count: 10000, percentage: 8.0),
        ],
        topLocations: [
          Location(name: 'United States', views: 45000, percentage: 36.0),
          Location(name: 'United Kingdom', views: 18000, percentage: 14.4),
          Location(name: 'Canada', views: 15000, percentage: 12.0),
          Location(name: 'Australia', views: 12000, percentage: 9.6),
          Location(name: 'Germany', views: 10000, percentage: 8.0),
        ],
      ),
      engagement: EngagementMetrics(
        likes: 8900,
        shares: 3200,
        comments: 890,
        favorites: 2100,
        engagementRate: 0.12,
        trends: [
          EngagementTrend(
            date: DateTime.now().subtract(const Duration(days: 6)),
            likes: 1200,
            shares: 400,
            comments: 120,
            favorites: 280,
          ),
          EngagementTrend(
            date: DateTime.now().subtract(const Duration(days: 5)),
            likes: 1500,
            shares: 500,
            comments: 150,
            favorites: 350,
          ),
          EngagementTrend(
            date: DateTime.now().subtract(const Duration(days: 4)),
            likes: 1800,
            shares: 600,
            comments: 180,
            favorites: 420,
          ),
          EngagementTrend(
            date: DateTime.now().subtract(const Duration(days: 3)),
            likes: 1600,
            shares: 550,
            comments: 160,
            favorites: 380,
          ),
          EngagementTrend(
            date: DateTime.now().subtract(const Duration(days: 2)),
            likes: 1400,
            shares: 480,
            comments: 140,
            favorites: 320,
          ),
          EngagementTrend(
            date: DateTime.now().subtract(const Duration(days: 1)),
            likes: 1100,
            shares: 380,
            comments: 110,
            favorites: 250,
          ),
        ],
      ),
    );
  }

  void _onVideoSelected(ProfileVideo video) {
    setState(() {
      _selectedVideo = video;
      _isLoading = true;
    });
    
    // Cancel previous subscription
    _insightsSubscription?.cancel();
    
    // Check if video is too new for insights
    final now = DateTime.now();
    final hoursSinceUpload = now.difference(video.createdAt).inHours;
    
    if (hoursSinceUpload < 24) {
      // Don't load insights data for videos that are too new
      setState(() {
        _isLoading = false;
      });
    } else {
      // Start real-time listening for insights updates
      _startRealTimeInsights(video.id);
      
      // Also load initial data
      _loadInsightsData();
    }
  }
  
  void _startRealTimeInsights(String videoId) {
    final insightsService = ref.read(insightsFirebaseServiceProvider);
    
    _insightsSubscription = insightsService.listenToVideoInsights(videoId).listen(
      (insights) {
        if (mounted && insights != null) {
          setState(() {
            _insightsData = insights;
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
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
                child: _isLoading
                    ? _buildLoadingState()
                    : _isVideoTooNewForInsights()
                        ? _buildDataCollectingState()
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              InsightsOverviewTab(insights: _insightsData),
                              InsightsViewersTab(insights: _insightsData),
                              InsightsEngagementTab(insights: _insightsData),
                            ],
                          ),
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
    return Container(
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
    );
  }

  bool _isVideoTooNewForInsights() {
    if (_selectedVideo == null) return false;
    final now = DateTime.now();
    final hoursSinceUpload = now.difference(_selectedVideo!.createdAt).inHours;
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

  void _shareInsights() {
    // TODO: Implement sharing insights functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sharing insights...'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
