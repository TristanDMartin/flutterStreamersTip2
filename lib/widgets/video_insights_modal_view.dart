import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class VideoInsightsModalView extends StatefulWidget {
  final Map<String, dynamic> video;
  
  const VideoInsightsModalView({
    super.key,
    required this.video,
  });

  @override
  State<VideoInsightsModalView> createState() => _VideoInsightsModalViewState();
}

class _VideoInsightsModalViewState extends State<VideoInsightsModalView> {
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;
  StreamSubscription? _analyticsSubscription;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  @override
  void dispose() {
    _analyticsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    try {
      final videoId = widget.video['id'] as String?;
      if (videoId == null) {
        _setDefaultAnalytics();
        return;
      }

      // Start listening to real-time analytics updates
      _analyticsSubscription = _firestore
          .collection('video_analytics')
          .doc(videoId)
          .snapshots()
          .listen(
        (snapshot) {
          if (mounted) {
            if (snapshot.exists && snapshot.data() != null) {
              final data = snapshot.data()!;
              setState(() {
                _analytics = {
                  'views': data['views'] ?? widget.video['views'] ?? 0,
                  'likes': data['likes'] ?? widget.video['likes'] ?? 0,
                  'comments': data['comments'] ?? widget.video['comments'] ?? 0,
                  'shares': data['shares'] ?? 0,
                  'engagementRate': _calculateEngagementRate(data),
                  'averageWatchTime': data['averageWatchTime'] ?? 0.0,
                  'audienceReach': data['audienceReach'] ?? 0,
                  'retentionRate': data['retentionRate'] ?? 0.0,
                };
                _isLoading = false;
              });
            } else {
              _setDefaultAnalytics();
            }
          }
        },
        onError: (error) {
          debugPrint('Error loading analytics: $error');
          if (mounted) {
            _setDefaultAnalytics();
          }
        },
      );
    } catch (error) {
      debugPrint('Error initializing analytics: $error');
      _setDefaultAnalytics();
    }
  }

  void _setDefaultAnalytics() {
    if (mounted) {
      setState(() {
        _analytics = {
          'views': widget.video['views'] ?? 0,
          'likes': widget.video['likes'] ?? 0,
          'comments': widget.video['comments'] ?? 0,
          'engagementRate': 0.0,
          'averageWatchTime': 0.0,
          'audienceReach': 0,
          'retentionRate': 0.0,
          'shares': 0,
        };
        _isLoading = false;
      });
    }
  }

  double _calculateEngagementRate(Map<String, dynamic> data) {
    final views = data['views'] ?? 0;
    if (views == 0) return 0.0;
    
    final likes = data['likes'] ?? 0;
    final comments = data['comments'] ?? 0;
    final shares = data['shares'] ?? 0;
    
    final totalEngagement = likes + comments + shares;
    return totalEngagement / views;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Done',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(
                      children: [
                        const Text(
                          'Video Insights',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        Text(
                          'Performance metrics for your video',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Overview Stats
                  _buildOverviewStats(),
                  
                  const SizedBox(height: 24),
                  
                  // Detailed Metrics
                  _buildDetailedMetrics(),
                  
                  const SizedBox(height: 24),
                  
                  // Growth Chart Placeholder
                  _buildGrowthChart(),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          
          const SizedBox(height: 16),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              InsightCard(
                title: 'Views',
                value: _formatNumber(_analytics?['views'] ?? widget.video['views'] ?? 0),
                icon: Icons.play_circle,
                color: Colors.blue,
              ),
              
              InsightCard(
                title: 'Likes',
                value: _formatNumber(_analytics?['likes'] ?? widget.video['likes'] ?? 0),
                icon: Icons.favorite,
                color: Colors.red,
              ),
              
              InsightCard(
                title: 'Comments',
                value: _formatNumber(_analytics?['comments'] ?? widget.video['comments'] ?? 0),
                icon: Icons.chat_bubble,
                color: Colors.green,
              ),
              
              InsightCard(
                title: 'Engagement',
                value: '${((_analytics?['engagementRate'] ?? 0.0) * 100).toStringAsFixed(1)}%',
                icon: Icons.trending_up,
                color: Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedMetrics() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detailed Metrics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Column(
            children: [
              MetricRow(
                title: 'Watch Time',
                value: '${((_analytics?['averageWatchTime'] ?? 0.0) / 60.0).toStringAsFixed(1)} min avg',
                icon: Icons.access_time,
                color: Colors.purple,
              ),
              
              const SizedBox(height: 12),
              
              MetricRow(
                title: 'Audience Reach',
                value: '${_formatNumber(_analytics?['audienceReach'] ?? 0)} accounts',
                icon: Icons.people,
                color: Colors.blue,
              ),
              
              const SizedBox(height: 12),
              
              MetricRow(
                title: 'Retention Rate',
                value: '${((_analytics?['retentionRate'] ?? 0.0) * 100).toStringAsFixed(1)}%',
                icon: Icons.bar_chart,
                color: Colors.green,
              ),
              
              const SizedBox(height: 12),
              
              MetricRow(
                title: 'Shares',
                value: _formatNumber(_analytics?['shares'] ?? 0),
                icon: Icons.share,
                color: Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthChart() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Growth Over Time',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.trending_up,
                    size: 40,
                    color: Colors.grey,
                  ),
                  
                  SizedBox(height: 8),
                  
                  Text(
                    'Growth chart coming soon',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number < 1000) {
      return number.toString();
    } else if (number < 1000000) {
      return '${(number / 1000.0).toStringAsFixed(1)}K';
    } else {
      return '${(number / 1000000.0).toStringAsFixed(1)}M';
    }
  }
}

class InsightCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const InsightCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 24,
            color: color,
          ),
          
          const SizedBox(height: 8),
          
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class MetricRow extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const MetricRow({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
        ),
        
        const SizedBox(width: 12),
        
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black,
            ),
          ),
        ),
        
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}
