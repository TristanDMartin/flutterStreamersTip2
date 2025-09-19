import 'package:flutter/material.dart';
import '../models/insights_data.dart';
import 'insights_chart_widgets.dart';

/// Engagement tab showing interaction metrics and trends
class InsightsEngagementTab extends StatelessWidget {
  final InsightsData insights;

  const InsightsEngagementTab({
    super.key,
    required this.insights,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Engagement rate card
          _buildEngagementRateCard(),
          
          const SizedBox(height: 24),
          
          // Engagement metrics cards
          _buildEngagementMetricsCards(),
          
          const SizedBox(height: 24),
          
          // Engagement trends section
          _buildEngagementTrendsSection(),
          
          const SizedBox(height: 24),
          
          // Engagement breakdown section
          _buildEngagementBreakdownSection(),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildEngagementRateCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF9248D2).withValues(alpha: 0.3),
            const Color(0xFF40DCD1).withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Engagement Rate',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'How much your audience interacts with your content',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(insights.engagement.engagementRate * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _getEngagementRateColor().withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getEngagementRateLabel(),
                  style: TextStyle(
                    color: _getEngagementRateColor(),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementMetricsCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Engagement Metrics',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildEngagementCard(
                icon: Icons.favorite,
                title: 'Likes',
                value: _formatNumber(insights.engagement.likes),
                color: const Color(0xFFE91E63),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildEngagementCard(
                icon: Icons.share,
                title: 'Shares',
                value: _formatNumber(insights.engagement.shares),
                color: const Color(0xFF1670DE),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildEngagementCard(
                icon: Icons.comment,
                title: 'Comments',
                value: _formatNumber(insights.engagement.comments),
                color: const Color(0xFF40DCD1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildEngagementCard(
                icon: Icons.bookmark,
                title: 'Favorites',
                value: _formatNumber(insights.engagement.favorites),
                color: const Color(0xFF9248D2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEngagementCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementTrendsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Engagement Trends',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              EngagementTrendsChart(
                trends: insights.engagement.trends,
              ),
              const SizedBox(height: 16),
              Text(
                'Daily engagement over the past week',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEngagementBreakdownSection() {
    final totalEngagements = insights.engagement.likes +
                           insights.engagement.shares +
                           insights.engagement.comments +
                           insights.engagement.favorites;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Engagement Breakdown',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              EngagementBreakdownChart(
                likes: insights.engagement.likes,
                shares: insights.engagement.shares,
                comments: insights.engagement.comments,
                favorites: insights.engagement.favorites,
              ),
              const SizedBox(height: 20),
              Column(
                children: [
                  _buildEngagementBreakdownItem(
                    'Likes',
                    insights.engagement.likes,
                    totalEngagements,
                    const Color(0xFFE91E63),
                    Icons.favorite,
                  ),
                  _buildEngagementBreakdownItem(
                    'Shares',
                    insights.engagement.shares,
                    totalEngagements,
                    const Color(0xFF1670DE),
                    Icons.share,
                  ),
                  _buildEngagementBreakdownItem(
                    'Comments',
                    insights.engagement.comments,
                    totalEngagements,
                    const Color(0xFF40DCD1),
                    Icons.comment,
                  ),
                  _buildEngagementBreakdownItem(
                    'Favorites',
                    insights.engagement.favorites,
                    totalEngagements,
                    const Color(0xFF9248D2),
                    Icons.bookmark,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEngagementBreakdownItem(
    String label,
    int count,
    int total,
    Color color,
    IconData icon,
  ) {
    final percentage = total > 0 ? (count / total * 100) : 0.0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: percentage / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatNumber(count),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getEngagementRateColor() {
    if (insights.engagement.engagementRate >= 0.15) {
      return const Color(0xFF40DCD1); // Excellent
    } else if (insights.engagement.engagementRate >= 0.10) {
      return const Color(0xFF9248D2); // Good
    } else if (insights.engagement.engagementRate >= 0.05) {
      return Colors.orange; // Average
    } else {
      return const Color(0xFFE91E63); // Needs improvement
    }
  }

  String _getEngagementRateLabel() {
    if (insights.engagement.engagementRate >= 0.15) {
      return 'Excellent';
    } else if (insights.engagement.engagementRate >= 0.10) {
      return 'Good';
    } else if (insights.engagement.engagementRate >= 0.05) {
      return 'Average';
    } else {
      return 'Needs Improvement';
    }
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toString();
    }
  }
}
