import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/scheduled_post.dart';
import '../services/scheduled_post_service.dart';

class PostAnalyticsView extends StatefulWidget {
  final ScheduledPost post;

  const PostAnalyticsView({
    super.key,
    required this.post,
  });

  @override
  State<PostAnalyticsView> createState() => _PostAnalyticsViewState();
}

class _PostAnalyticsViewState extends State<PostAnalyticsView> with TickerProviderStateMixin {
  final ScheduledPostService _postService = ScheduledPostService();
  late TabController _tabController;
  
  bool _isLoading = true;
  Map<String, dynamic> _analytics = {};
  List<AnalyticsDataPoint> _engagementData = [];
  List<AnalyticsDataPoint> _reachData = [];
  List<AnalyticsDataPoint> _impressionsData = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Simulate loading analytics data
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _analytics = {
          'totalViews': 15420,
          'totalLikes': 892,
          'totalComments': 156,
          'totalShares': 234,
          'totalReach': 18920,
          'totalImpressions': 25680,
          'engagementRate': 8.2,
          'clickThroughRate': 3.4,
          'saves': 45,
          'bookmarks': 23,
        };

        _engagementData = _generateMockData('Engagement', 7);
        _reachData = _generateMockData('Reach', 7);
        _impressionsData = _generateMockData('Impressions', 7);
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load analytics: $e');
    }
  }

  List<AnalyticsDataPoint> _generateMockData(String type, int days) {
    final data = <AnalyticsDataPoint>[];
    final now = DateTime.now();
    
    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      int value;
      
      switch (type) {
        case 'Engagement':
          value = (100 + (i * 15) + (i % 3 * 20)).toInt();
          break;
        case 'Reach':
          value = (500 + (i * 80) + (i % 2 * 120)).toInt();
          break;
        case 'Impressions':
          value = (800 + (i * 120) + (i % 4 * 200)).toInt();
          break;
        default:
          value = 0;
      }
      
      data.add(AnalyticsDataPoint(
        date: date,
        value: value,
        label: _formatDate(date),
      ));
    }
    
    return data;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Post Analytics',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAnalytics,
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _shareAnalytics,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF9248D2),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Engagement'),
            Tab(text: 'Reach'),
          ],
        ),
      ),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildEngagementTab(),
                    _buildReachTab(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricsGrid(),
          const SizedBox(height: 24),
          _buildPlatformBreakdown(),
          const SizedBox(height: 24),
          _buildTopPerformingContent(),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _buildMetricCard(
          'Total Views',
          _analytics['totalViews'].toString(),
          Icons.visibility,
          Colors.blue,
          '+12.5%',
        ),
        _buildMetricCard(
          'Engagement Rate',
          '${_analytics['engagementRate']}%',
          Icons.favorite,
          Colors.red,
          '+2.1%',
        ),
        _buildMetricCard(
          'Total Reach',
          _analytics['totalReach'].toString(),
          Icons.people,
          Colors.green,
          '+8.3%',
        ),
        _buildMetricCard(
          'Click Through Rate',
          '${_analytics['clickThroughRate']}%',
          Icons.touch_app,
          Colors.orange,
          '+1.7%',
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, String change) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Text(
                change,
                style: TextStyle(
                  color: change.startsWith('+') ? Colors.green : Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Platform Performance',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...widget.post.platforms.map((platform) => _buildPlatformCard(platform)),
      ],
    );
  }

  Widget _buildPlatformCard(PlatformConfig platform) {
    final platformName = _getPlatformName(platform.key);
    final metrics = _getPlatformMetrics(platform.key);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(
            _getPlatformIcon(platform.key),
            color: _getPlatformColor(platform.key),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  platformName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${metrics['views']} views • ${metrics['engagement']}% engagement',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (platform.status == PlatformStatus.published)
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 20,
            )
          else
            Icon(
              Icons.schedule,
              color: Colors.orange,
              size: 20,
            ),
        ],
      ),
    );
  }

  Widget _buildTopPerformingContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top Performing Content',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              _buildContentItem('Video Content', '12.5K views', '85%'),
              const Divider(color: Colors.white30, height: 24),
              _buildContentItem('Image Posts', '8.2K views', '72%'),
              const Divider(color: Colors.white30, height: 24),
              _buildContentItem('Text Posts', '3.1K views', '45%'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContentItem(String type, String views, String engagement) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF9248D2).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.analytics,
            color: Color(0xFF9248D2),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                type,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                views,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Text(
          engagement,
          style: const TextStyle(
            color: Color(0xFF9248D2),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEngagementTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChartSection('Engagement Over Time', _engagementData, Colors.red),
          const SizedBox(height: 24),
          _buildEngagementBreakdown(),
        ],
      ),
    );
  }

  Widget _buildReachTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChartSection('Reach Over Time', _reachData, Colors.blue),
          const SizedBox(height: 24),
          _buildChartSection('Impressions Over Time', _impressionsData, Colors.green),
        ],
      ),
    );
  }

  Widget _buildChartSection(String title, List<AnalyticsDataPoint> data, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: _buildSimpleChart(data, color),
        ),
      ],
    );
  }

  Widget _buildSimpleChart(List<AnalyticsDataPoint> data, Color color) {
    if (data.isEmpty) {
      return const Center(
        child: Text(
          'No data available',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final maxValue = data.map((d) => d.value).reduce((a, b) => a > b ? a : b).toDouble();
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.map((point) {
        final height = (point.value / maxValue) * 150;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEngagementBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Engagement Breakdown',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              _buildEngagementItem('Likes', _analytics['totalLikes'], Icons.favorite, Colors.red),
              const Divider(color: Colors.white30, height: 24),
              _buildEngagementItem('Comments', _analytics['totalComments'], Icons.comment, Colors.blue),
              const Divider(color: Colors.white30, height: 24),
              _buildEngagementItem('Shares', _analytics['totalShares'], Icons.share, Colors.green),
              const Divider(color: Colors.white30, height: 24),
              _buildEngagementItem('Saves', _analytics['saves'], Icons.bookmark, Colors.orange),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEngagementItem(String label, dynamic value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
        Text(
          value.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _getPlatformName(String platform) {
    switch (platform) {
      case 'youtube':
        return 'YouTube';
      case 'tiktok':
        return 'TikTok';
      case 'instagram':
        return 'Instagram';
      case 'x':
        return 'X (Twitter)';
      case 'facebook':
        return 'Facebook';
      case 'linkedin':
        return 'LinkedIn';
      default:
        return platform;
    }
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform) {
      case 'youtube':
        return Icons.play_circle_filled;
      case 'tiktok':
        return Icons.music_note;
      case 'instagram':
        return Icons.camera_alt;
      case 'x':
        return Icons.alternate_email;
      case 'facebook':
        return Icons.facebook;
      case 'linkedin':
        return Icons.business;
      default:
        return Icons.public;
    }
  }

  Color _getPlatformColor(String platform) {
    switch (platform) {
      case 'youtube':
        return Colors.red;
      case 'tiktok':
        return Colors.black;
      case 'instagram':
        return Colors.purple;
      case 'x':
        return Colors.blue;
      case 'facebook':
        return Colors.blue;
      case 'linkedin':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Map<String, dynamic> _getPlatformMetrics(String platform) {
    // Mock platform-specific metrics
    switch (platform) {
      case 'youtube':
        return {'views': '8.2K', 'engagement': '12.5'};
      case 'tiktok':
        return {'views': '4.1K', 'engagement': '18.3'};
      case 'instagram':
        return {'views': '2.9K', 'engagement': '9.7'};
      default:
        return {'views': '0', 'engagement': '0'};
    }
  }

  void _shareAnalytics() {
    HapticFeedback.lightImpact();
    _showInfoSnackBar('Analytics sharing functionality coming soon');
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF9248D2),
      ),
    );
  }
}

class AnalyticsDataPoint {
  final DateTime date;
  final int value;
  final String label;

  AnalyticsDataPoint({
    required this.date,
    required this.value,
    required this.label,
  });
}
