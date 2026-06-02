import 'package:flutter/material.dart';
import '../models/insights_data.dart';
import 'insights_chart_widgets.dart';

/// Viewers tab showing demographics and behavior metrics
class InsightsViewersTab extends StatelessWidget {
  final InsightsData insights;

  const InsightsViewersTab({
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
          // Viewer summary cards
          _buildViewerSummaryCards(),

          const SizedBox(height: 24),

          // Viewer types section
          _buildViewerTypesSection(context),

          const SizedBox(height: 24),

          // Gender breakdown section
          _buildGenderBreakdownSection(context),

          const SizedBox(height: 24),

          // Age groups section
          _buildAgeGroupsSection(context),

          const SizedBox(height: 24),

          // Top locations section
          _buildTopLocationsSection(context),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildViewerSummaryCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Viewer Summary',
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
              child: _buildSummaryCard(
                icon: Icons.visibility,
                title: 'Total Views',
                value: _formatNumber(insights.viewers.totalViews),
                subtitle: _describeCount(
                  insights.viewers.totalViews,
                  zero: 'No audience volume yet',
                  low: 'First viewers are arriving',
                  active: 'Reach is building steadily',
                ),
                color: const Color(0xFF40DCD1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.people,
                title: 'Unique Viewers',
                value: _formatNumber(insights.viewers.uniqueViewers),
                subtitle: _describeCount(
                  insights.viewers.uniqueViewers,
                  zero: 'No distinct viewers yet',
                  low: 'Audience is still small',
                  active: 'You are reaching individual viewers',
                ),
                color: const Color(0xFF9248D2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
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
              fontSize: 26,
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

  Widget _buildViewerTypesSection(BuildContext context) {
    final viewerTypes = insights.viewers.viewerTypes;
    final totalTypes = viewerTypes.newViewers + viewerTypes.returningViewers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Viewer Types',
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
              title: 'About viewer types',
              message:
                  'New viewers are people who recently discovered this content, while returning viewers have watched your content before. This split becomes more reliable as repeat audience behavior builds up.',
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
              if (totalTypes == 0)
                _buildSectionEmptyState(
                  icon: Icons.groups_2_outlined,
                  title: 'Viewer type data is still populating',
                  message:
                      'We will separate new and returning viewers once enough audience history is available.',
                )
              else ...[
                ViewerTypesChart(
                  newViewers: viewerTypes.newViewers,
                  returningViewers: viewerTypes.returningViewers,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildViewerTypeItem(
                        label: 'New Viewers',
                        count: viewerTypes.newViewers,
                        total: insights.viewers.totalViews,
                        color: const Color(0xFF9248D2),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildViewerTypeItem(
                        label: 'Returning Viewers',
                        count: viewerTypes.returningViewers,
                        total: insights.viewers.totalViews,
                        color: const Color(0xFF40DCD1),
                      ),
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

  Widget _buildViewerTypeItem({
    required String label,
    required int count,
    required int total,
    required Color color,
  }) {
    final percentage = total > 0 ? (count / total * 100) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _formatNumber(count),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
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
    );
  }

  Widget _buildGenderBreakdownSection(BuildContext context) {
    final breakdown = insights.viewers.genderBreakdown;
    final totalGender =
        breakdown.male + breakdown.female + breakdown.other + breakdown.unknown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Gender Breakdown',
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
              title: 'About gender breakdown',
              message:
                  'Gender data is an aggregate estimate, not individual identity information. It appears only when enough audience data exists to show a broad anonymous trend.',
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
              if (totalGender == 0)
                _buildSectionEmptyState(
                  icon: Icons.person_search_outlined,
                  title: 'No audience demographic split yet',
                  message:
                      'Demographic estimates appear only after enough viewer data has been collected.',
                )
              else ...[
                GenderBreakdownChart(
                  breakdown: breakdown,
                ),
                const SizedBox(height: 20),
                Column(
                  children: [
                    _buildGenderItem(
                        'Male', breakdown.male, const Color(0xFF1670DE)),
                    _buildGenderItem(
                        'Female', breakdown.female, const Color(0xFFE91E63)),
                    _buildGenderItem(
                        'Other', breakdown.other, const Color(0xFF40DCD1)),
                    _buildGenderItem('Unknown', breakdown.unknown, Colors.grey),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenderItem(String label, int count, Color color) {
    final total = insights.viewers.genderBreakdown.male +
        insights.viewers.genderBreakdown.female +
        insights.viewers.genderBreakdown.other +
        insights.viewers.genderBreakdown.unknown;
    final percentage = total > 0 ? (count / total * 100) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            _formatNumber(count),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 50,
            child: Text(
              '${percentage.toStringAsFixed(1)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgeGroupsSection(BuildContext context) {
    final ageGroups = insights.viewers.ageGroups;
    final hasAgeData = ageGroups.any((group) => group.count > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Age Groups',
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
              title: 'About age groups',
              message:
                  'Age groups are shown as anonymous ranges so you can understand broad audience fit. Small audiences may not generate enough data to display these ranges confidently.',
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
              if (!hasAgeData)
                _buildSectionEmptyState(
                  icon: Icons.cake_outlined,
                  title: 'No age group breakdown yet',
                  message:
                      'Age ranges will appear here once enough viewers can be grouped anonymously.',
                )
              else ...[
                AgeGroupsChart(
                  ageGroups: ageGroups,
                ),
                const SizedBox(height: 20),
                ...ageGroups.map((ageGroup) => _buildAgeGroupItem(ageGroup)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAgeGroupItem(AgeGroup ageGroup) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              ageGroup.range,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: ageGroup.percentage / 100,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF9248D2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: Text(
              _formatNumber(ageGroup.count),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              '${ageGroup.percentage.toStringAsFixed(1)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopLocationsSection(BuildContext context) {
    final locations = insights.viewers.topLocations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Top Locations',
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
              title: 'About top locations',
              message:
                  'Top locations show the countries or regions where your viewers are concentrated. This helps identify where your content is resonating geographically as view volume grows.',
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
              Row(
                children: [
                  Icon(
                    Icons.public,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Where your viewers are located',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (locations.isEmpty)
                _buildSectionEmptyState(
                  icon: Icons.public_off_outlined,
                  title: 'No location breakdown yet',
                  message:
                      'Top countries and regions will show once we have enough location signals from viewers.',
                )
              else
                ...locations.asMap().entries.map((entry) {
                  final index = entry.key;
                  final location = entry.value;
                  return _buildLocationItem(index + 1, location);
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

  Widget _buildLocationItem(int rank, Location location) {
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
              location.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            _formatNumber(location.views),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 50,
            child: Text(
              '${location.percentage.toStringAsFixed(1)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
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
}
