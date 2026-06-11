import 'package:flutter/material.dart';
import '../models/insights_data.dart';
import 'insights_chart_widgets.dart';

/// Overview tab showing general performance metrics
class InsightsOverviewTab extends StatelessWidget {
  const InsightsOverviewTab({
    super.key,
    required this.insights,
    this.analyticsWindowDays = 7,
  });

  final InsightsData insights;
  final int analyticsWindowDays;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date range info
          _buildDateRangeInfo(),

          const SizedBox(height: 24),

          // Total metrics cards
          _buildMetricsCards(),

          const SizedBox(height: 24),

          // Retention rate section
          _buildRetentionSection(context),

          const SizedBox(height: 24),

          // Traffic sources section
          _buildTrafficSourcesSection(context),

          const SizedBox(height: 24),

          // Search queries section
          _buildSearchQueriesSection(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDateRangeInfo() {
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
      child: Row(
        children: [
          Icon(
            Icons.calendar_today,
            color: Colors.white.withValues(alpha: 0.8),
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            analyticsWindowDays >= 365
                ? 'Last 12 months'
                : 'Last $analyticsWindowDays days',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            '${insights.dateRange.day}/${insights.dateRange.month} - ${DateTime.now().day}/${DateTime.now().month}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Performance Metrics',
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
              child: _buildMetricCard(
                icon: Icons.visibility,
                title: 'Views',
                value: _formatNumber(insights.overview.totalViews),
                subtitle: _describeCount(
                  insights.overview.totalViews,
                  zero: 'Waiting for discovery',
                  low: 'Early audience traction',
                  active: 'Consistent reach so far',
                ),
                color: const Color(0xFF40DCD1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.watch_later,
                title: 'Watch Time',
                value: _formatDuration(insights.overview.totalWatchTime),
                subtitle: _describeDuration(
                  insights.overview.totalWatchTime,
                  zero: 'No meaningful watch time yet',
                  low: 'First minutes are coming in',
                  active: 'Audience is staying engaged',
                ),
                color: const Color(0xFF9248D2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.share,
                title: 'Shares',
                value: _formatNumber(insights.overview.shares),
                subtitle: _describeCount(
                  insights.overview.shares,
                  zero: 'No shares recorded yet',
                  low: 'A few viewers are passing it on',
                  active: 'This content is getting circulated',
                ),
                color: const Color(0xFF1670DE),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.comment,
                title: 'Comments',
                value: _formatNumber(insights.overview.comments),
                subtitle: _describeCount(
                  insights.overview.comments,
                  zero: 'No discussion yet',
                  low: 'Conversation is starting',
                  active: 'Viewers are actively responding',
                ),
                color: const Color(0xFFE91E63),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
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
          const SizedBox(height: 4),
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

  Widget _buildRetentionSection(BuildContext context) {
    final retentionStatus = _getRetentionStatus();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Retention Rate',
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
              title: 'About retention rate',
              message:
                  'Retention estimates how much of the video viewers keep watching on average. Newer videos can move quickly, so lower-volume posts are labeled more cautiously until more viewers have watched.',
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Measures how long viewers stay with this video',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 13,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(insights.overview.retentionRate * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: retentionStatus.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      retentionStatus.label,
                      style: TextStyle(
                        color: retentionStatus.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              RetentionChart(
                retentionRate: insights.overview.retentionRate,
              ),
              const SizedBox(height: 16),
              Text(
                retentionStatus.description,
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

  Widget _buildTrafficSourcesSection(BuildContext context) {
    final trafficSources = insights.overview.trafficSources;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Traffic Sources',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            _buildMetricInfoChip(
              context,
              label: 'What this means',
              title: 'About traffic sources',
              message:
                  'Traffic sources show where viewers discovered this video, such as profile visits, search, or recommendation surfaces. These breakdowns become more useful as the video reaches a wider audience.',
            ),
          ],
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
              if (trafficSources.isEmpty)
                _buildSectionEmptyState(
                  icon: Icons.traffic_outlined,
                  title: 'No traffic source breakdown yet',
                  message:
                      'Traffic source attribution will appear once this video has enough discovery data.',
                )
              else ...[
                TrafficSourcesChart(
                  sources: trafficSources,
                ),
                const SizedBox(height: 16),
                ...trafficSources
                    .map((source) => _buildTrafficSourceItem(source)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrafficSourceItem(TrafficSource source) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              source.source,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatNumber(source.views),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${source.percentage.toStringAsFixed(1)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchQueriesSection() {
    final searchQueries = insights.overview.searchQueries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top Search Queries',
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
              Row(
                children: [
                  Icon(
                    Icons.search,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Keywords that led users to your video',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (searchQueries.isEmpty)
                _buildSectionEmptyState(
                  icon: Icons.manage_search_outlined,
                  title: 'No search query data yet',
                  message:
                      'Search keywords will show up here once viewers start finding this video through search.',
                )
              else
                ...searchQueries.asMap().entries.map((entry) {
                  final index = entry.key;
                  final query = entry.value;
                  return _buildSearchQueryItem(index + 1, query);
                }),
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

  Widget _buildSearchQueryItem(int rank, String query) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: rank <= 3
                  ? const Color(0xFF9248D2).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  color: rank <= 3
                      ? const Color(0xFF9248D2)
                      : Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              query,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
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

  String _formatDuration(Duration duration) {
    if (duration.inHours >= 24) {
      return '${(duration.inHours / 24).toStringAsFixed(1)} days';
    } else if (duration.inHours >= 1) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
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

  String _describeDuration(
    Duration duration, {
    required String zero,
    required String low,
    required String active,
  }) {
    if (duration.inSeconds <= 0) {
      return zero;
    }
    if (duration.inMinutes < 10) {
      return low;
    }
    return active;
  }

  ({String label, String description, Color color}) _getRetentionStatus() {
    final views = insights.overview.totalViews;
    final retentionRate = insights.overview.retentionRate;

    if (views == 0) {
      return (
        label: 'No Signal Yet',
        description:
            'Retention will become meaningful once this video has viewers to measure.',
        color: Colors.white70,
      );
    }

    if (views < 25) {
      return (
        label: 'Early Signal',
        description:
            'This retention rate is based on a small audience so far and may move quickly.',
        color: Colors.orange,
      );
    }

    if (retentionRate >= 0.60) {
      return (
        label: 'Holding Strong',
        description: 'Viewers are staying with this video longer than average.',
        color: const Color(0xFF40DCD1),
      );
    }

    if (retentionRate >= 0.35) {
      return (
        label: 'Promising',
        description:
            'Retention looks healthy and there is a solid base to build on.',
        color: const Color(0xFF9248D2),
      );
    }

    return (
      label: 'Needs Testing',
      description:
          'Viewers are dropping earlier, so the opening may need a stronger hook.',
      color: const Color(0xFFE91E63),
    );
  }
}
