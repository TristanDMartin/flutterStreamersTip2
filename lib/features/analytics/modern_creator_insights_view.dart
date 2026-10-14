import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/insights_data.dart';
import '../../models/profile_video.dart';

class ModernCreatorInsightsView extends ConsumerStatefulWidget {
  const ModernCreatorInsightsView({
    super.key,
    required this.video,
    required this.insights,
  });

  final ProfileVideo video;
  final InsightsData insights;

  @override
  ConsumerState<ModernCreatorInsightsView> createState() =>
      _ModernCreatorInsightsViewState();
}

class _ModernCreatorInsightsViewState
    extends ConsumerState<ModernCreatorInsightsView> {
  String _selectedPeriod = '7D';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            _buildVideoHeader(),
            _buildAnalyticsBanner(),
            _buildPeriodSelector(),
            _buildStatsGrid(),
            _buildAudienceRetention(),
            _buildTrafficSources(),
            _buildTopLocations(),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: const Color(0xFF0A0A0F),
      elevation: 0,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Creator Insights',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            widget.video.caption.isNotEmpty
                ? widget.video.caption
                : 'Your video',
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.file_download_outlined, color: Colors.white),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.ios_share, color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildVideoHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 120,
                height: 160,
                color: const Color(0xFF1C1C1E),
                child: widget.video.thumbnailURL != null
                    ? Image.network(
                        widget.video.thumbnailURL!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(Icons.video_library,
                                color: Color(0xFF8E8E93), size: 40),
                          );
                        },
                      )
                    : const Center(
                        child: Icon(Icons.video_library,
                            color: Color(0xFF8E8E93), size: 40),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.video.caption.isNotEmpty
                        ? widget.video.caption
                        : 'Untitled video',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Jul 18, 2026 • Public',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34C759).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF34C759),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Published',
                          style: TextStyle(
                            color: Color(0xFF34C759),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsBanner() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF7B3FF2).withValues(alpha: 0.2),
                const Color(0xFF3D99F7).withValues(alpha: 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF7B3FF2).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B3FF2).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  color: Color(0xFF7B3FF2),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analytics are now available',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Your views, engagement and audience data have started to populate.',
                      style: TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF8E8E93)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Row(
          children: [
            _buildPeriodChip('7D'),
            const SizedBox(width: 8),
            _buildPeriodChip('28D'),
            const SizedBox(width: 8),
            _buildPeriodChip('90D'),
            const SizedBox(width: 8),
            _buildPeriodChip('All time'),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String period) {
    final isSelected = _selectedPeriod == period;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPeriod = period),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF00D9FF), Color(0xFF007AFF)],
                  )
                : null,
            color: isSelected ? null : const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            period,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF8E8E93),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final insights = widget.insights;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildListDelegate([
          _buildStatCard(
            'Views',
            insights.overview.totalViews.toString(),
            '+42%',
            const Color(0xFF00D9FF),
            Icons.visibility_outlined,
          ),
          _buildStatCard(
            'Likes',
            insights.engagement.likes.toString(),
            '+36%',
            const Color(0xFFFF2D55),
            Icons.favorite_outline,
          ),
          _buildStatCard(
            'Comments',
            insights.overview.comments.toString(),
            '+75%',
            const Color(0xFF7B3FF2),
            Icons.chat_bubble_outline,
          ),
          _buildStatCard(
            'Shares',
            insights.overview.shares.toString(),
            '+91%',
            const Color(0xFF007AFF),
            Icons.share_outlined,
          ),
          _buildStatCard(
            'Profile visits',
            '0',
            '+63%',
            const Color(0xFF00D9FF),
            Icons.person_outline,
          ),
          _buildStatCard(
            'Engagement rate',
            '${((insights.engagement.engagementRate) * 100).toStringAsFixed(1)}%',
            '+2.4%',
            const Color(0xFF7B3FF2),
            Icons.trending_up,
          ),
        ]),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    String change,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.arrow_upward, color: color, size: 12),
              const SizedBox(width: 4),
              Text(
                change,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAudienceRetention() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.show_chart,
                          color: Color(0xFF7B3FF2), size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Audience Retention',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.info_outline,
                          color: Colors.white.withValues(alpha: 0.3), size: 16),
                    ],
                  ),
                  const Text(
                    '0:03',
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 120,
                child: CustomPaint(
                  size: const Size(double.infinity, 120),
                  painter: RetentionChartPainter(),
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('0:00',
                      style: TextStyle(color: Color(0xFF8E8E93), fontSize: 11)),
                  Text('0:01',
                      style: TextStyle(color: Color(0xFF8E8E93), fontSize: 11)),
                  Text('0:02',
                      style: TextStyle(color: Color(0xFF8E8E93), fontSize: 11)),
                  Text('0:03',
                      style: TextStyle(color: Color(0xFF8E8E93), fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrafficSources() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.traffic, color: Color(0xFF007AFF), size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Traffic sources',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.info_outline,
                      color: Colors.white.withValues(alpha: 0.3), size: 16),
                ],
              ),
              const SizedBox(height: 20),
              _buildTrafficBar('For You', 0.64, const Color(0xFF007AFF)),
              const SizedBox(height: 12),
              _buildTrafficBar('Followers', 0.18, const Color(0xFF7B3FF2)),
              const SizedBox(height: 12),
              _buildTrafficBar('Profile', 0.09, const Color(0xFF00D9FF)),
              const SizedBox(height: 12),
              _buildTrafficBar('External', 0.09, const Color(0xFF8E8E93)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrafficBar(String label, double percentage, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percentage,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.6), color],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 40,
          child: Text(
            '${(percentage * 100).toInt()}%',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopLocations() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: Color(0xFF00D9FF), size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Top audience locations',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.info_outline,
                          color: Colors.white.withValues(alpha: 0.3), size: 16),
                    ],
                  ),
                  const Text(
                    'See all',
                    style: TextStyle(
                      color: Color(0xFF007AFF),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildLocationBar('United States', 0.62, const Color(0xFF007AFF)),
              const SizedBox(height: 12),
              _buildLocationBar('Canada', 0.12, const Color(0xFF7B3FF2)),
              const SizedBox(height: 12),
              _buildLocationBar(
                  'United Kingdom', 0.08, const Color(0xFF00D9FF)),
              const SizedBox(height: 12),
              _buildLocationBar('Other', 0.18, const Color(0xFF8E8E93)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationBar(String label, double percentage, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percentage,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.6), color],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 40,
          child: Text(
            '${(percentage * 100).toInt()}%',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class RetentionChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF7B3FF2).withValues(alpha: 0.4),
          const Color(0xFF7B3FF2).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width * 0.3, size.height * 0.2);
    path.lineTo(size.width * 0.6, size.height * 0.5);
    path.lineTo(size.width, size.height * 0.72);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    final linePaint = Paint()
      ..color = const Color(0xFF7B3FF2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final linePath = Path();
    linePath.moveTo(0, 0);
    linePath.lineTo(size.width * 0.3, size.height * 0.2);
    linePath.lineTo(size.width * 0.6, size.height * 0.5);
    linePath.lineTo(size.width, size.height * 0.72);

    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()
      ..color = const Color(0xFF7B3FF2)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width, size.height * 0.72), 5, dotPaint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: '28%',
        style: TextStyle(
          color: Color(0xFF7B3FF2),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(size.width - 30, size.height * 0.72 - 20),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
