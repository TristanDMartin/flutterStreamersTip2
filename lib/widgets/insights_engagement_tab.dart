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
          _buildEngagementRateCard(context),

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

  Widget _buildEngagementRateCard(BuildContext context) {
    final engagementStatus = _getEngagementStatus();

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
                    Row(
                      children: [
                        const Text(
                          'Engagement Rate',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildMetricInfoChip(
                          context,
                          label: 'How we read this',
                          title: 'About engagement rate',
                          message:
                              'Engagement rate compares likes, comments, shares, and favorites to overall viewing activity. Smaller sample sizes are marked as early signals because a few actions can move the rate a lot.',
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'How much your audience interacts with your content',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      engagementStatus.description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: engagementStatus.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  engagementStatus.label,
                  style: TextStyle(
                    color: engagementStatus.color,
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
                subtitle: _describeCount(
                  insights.engagement.likes,
                  zero: 'No likes yet',
                  low: 'Appreciation is beginning',
                  active: 'Strong positive response',
                ),
                color: const Color(0xFFE91E63),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildEngagementCard(
                icon: Icons.share,
                title: 'Shares',
                value: _formatNumber(insights.engagement.shares),
                subtitle: _describeCount(
                  insights.engagement.shares,
                  zero: 'No shares yet',
                  low: 'A few viewers are sharing',
                  active: 'This is being passed around',
                ),
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
                subtitle: _describeCount(
                  insights.engagement.comments,
                  zero: 'No comments yet',
                  low: 'Conversation is starting',
                  active: 'Viewers are actively responding',
                ),
                color: const Color(0xFF40DCD1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildEngagementCard(
                icon: Icons.bookmark,
                title: 'Favorites',
                value: _formatNumber(insights.engagement.favorites),
                subtitle: _describeCount(
                  insights.engagement.favorites,
                  zero: 'Not saved yet',
                  low: 'A few saves are appearing',
                  active: 'Viewers want to revisit this',
                ),
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
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.14),
            color.withValues(alpha: 0.12),
          ],
        ),
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
            title.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementTrendsSection() {
    final trends = insights.engagement.trends;

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
              if (trends.isEmpty)
                _buildSectionEmptyState(
                  icon: Icons.show_chart_outlined,
                  title: 'No engagement trend line yet',
                  message:
                      'Daily trend data will appear once we have multiple days of engagement activity to compare.',
                )
              else ...[
                EngagementTrendsChart(
                  trends: trends,
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
              if (totalEngagements == 0)
                _buildSectionEmptyState(
                  icon: Icons.favorite_border,
                  title: 'No engagement breakdown yet',
                  message:
                      'Likes, comments, shares, and favorites will be broken down here as viewers start interacting.',
                )
              else ...[
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.72), size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricInfoChip(
    BuildContext context, {
    required String label,
    required String title,
    required String message,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => _showMetricInfo(context, title: title, message: message),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline,
              size: 14,
              color: Colors.white.withValues(alpha: 0.78),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMetricInfo(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C135D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Metric guide',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toString();
    }
  }

  String _describeCount(
    int count, {
    required String zero,
    required String low,
    required String active,
  }) {
    if (count <= 0) {
      return zero;
    }
    if (count < 10) {
      return low;
    }
    return active;
  }

  ({String label, String description, Color color}) _getEngagementStatus() {
    final totalEngagements = insights.engagement.likes +
        insights.engagement.shares +
        insights.engagement.comments +
        insights.engagement.favorites;
    final engagementRate = insights.engagement.engagementRate;

    if (totalEngagements == 0) {
      return (
        label: 'No Signal Yet',
        description:
            'Audience interaction will start showing up here as people engage with this video.',
        color: Colors.white70,
      );
    }

    if (totalEngagements < 10) {
      return (
        label: 'Early Signal',
        description:
            'This engagement rate is based on a small number of actions and may shift quickly.',
        color: Colors.orange,
      );
    }

    if (engagementRate >= 0.15) {
      return (
        label: 'Highly Active',
        description:
            'Viewers are interacting at a strong rate across likes, shares, comments, and saves.',
        color: const Color(0xFF40DCD1),
      );
    }

    if (engagementRate >= 0.10) {
      return (
        label: 'Healthy Response',
        description:
            'Audience interaction looks solid and the content is resonating.',
        color: const Color(0xFF9248D2),
      );
    }

    if (engagementRate >= 0.05) {
      return (
        label: 'Building Momentum',
        description:
            'Engagement is present, with room to strengthen the call-to-action or hook.',
        color: Colors.orange,
      );
    }

    return (
      label: 'Needs a Stronger Hook',
      description:
          'Viewers are watching but not interacting much yet, so the post may need a sharper payoff.',
      color: const Color(0xFFE91E63),
    );
  }
}
