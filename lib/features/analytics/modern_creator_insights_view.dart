import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/support_shell_style.dart';
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
    final shell = StSupportShellStyle.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: shell.scaffold,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            _buildAppBar(shell),
            _buildVideoHeader(shell, isDark),
            _buildAnalyticsBanner(shell, theme),
            _buildPeriodSelector(shell, theme),
            _buildStatsGrid(shell, theme, isDark),
            _buildAudienceRetention(shell, theme),
            _buildTrafficSources(shell, theme),
            _buildTopLocations(shell, theme),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(StSupportShellStyle shell) {
    return SliverAppBar(
      backgroundColor: shell.scaffold,
      elevation: 0,
      pinned: true,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: shell.onChrome),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Creator Insights',
            style: TextStyle(
              color: shell.onChrome,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            widget.video.caption.isNotEmpty
                ? widget.video.caption
                : 'Your video',
            style: TextStyle(
              color: shell.muted,
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
          icon: Icon(Icons.file_download_outlined, color: shell.onChrome),
          onPressed: () {},
        ),
        IconButton(
          icon: Icon(Icons.ios_share, color: shell.onChrome),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildVideoHeader(StSupportShellStyle shell, bool isDark) {
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
                color: shell.surfaceCard,
                child: widget.video.thumbnailURL != null
                    ? Image.network(
                        widget.video.thumbnailURL!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(Icons.video_library,
                                color: shell.muted, size: 40),
                          );
                        },
                      )
                    : Center(
                        child: Icon(Icons.video_library,
                            color: shell.muted, size: 40),
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
                    style: TextStyle(
                      color: shell.onChrome,
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
                      color: shell.muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34C759).withValues(alpha: isDark ? 0.2 : 0.15),
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

  Widget _buildAnalyticsBanner(StSupportShellStyle shell, ThemeData theme) {
    final primaryColor = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor.withValues(alpha: isDark ? 0.2 : 0.15),
                primaryColor.withValues(alpha: isDark ? 0.15 : 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: primaryColor.withValues(alpha: isDark ? 0.3 : 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: isDark ? 0.3 : 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.analytics_outlined,
                  color: primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analytics are now available',
                      style: TextStyle(
                        color: shell.onChrome,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your views, engagement and audience data have started to populate.',
                      style: TextStyle(
                        color: shell.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: shell.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(StSupportShellStyle shell, ThemeData theme) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Row(
          children: [
            _buildPeriodChip('7D', shell, theme),
            const SizedBox(width: 8),
            _buildPeriodChip('28D', shell, theme),
            const SizedBox(width: 8),
            _buildPeriodChip('90D', shell, theme),
            const SizedBox(width: 8),
            _buildPeriodChip('All time', shell, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String period, StSupportShellStyle shell, ThemeData theme) {
    final isSelected = _selectedPeriod == period;
    final primaryColor = theme.colorScheme.primary;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPeriod = period),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
                  )
                : null,
            color: isSelected ? null : shell.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? primaryColor : shell.surfaceCardBorder,
              width: isSelected ? 0 : 1,
            ),
          ),
          child: Text(
            period,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : shell.muted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(StSupportShellStyle shell, ThemeData theme, bool isDark) {
    final insights = widget.insights;
    
    // Define accent colors that work in both light and dark mode
    final cyan = isDark ? const Color(0xFF00D9FF) : const Color(0xFF0099CC);
    final pink = isDark ? const Color(0xFFFF2D55) : const Color(0xFFCC0033);
    final purple = isDark ? const Color(0xFF7B3FF2) : const Color(0xFF5E3AB8);
    final blue = isDark ? const Color(0xFF007AFF) : const Color(0xFF0055CC);
    
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
            cyan,
            Icons.visibility_outlined,
            shell,
          ),
          _buildStatCard(
            'Likes',
            insights.engagement.likes.toString(),
            '+36%',
            pink,
            Icons.favorite_outline,
            shell,
          ),
          _buildStatCard(
            'Comments',
            insights.overview.comments.toString(),
            '+75%',
            purple,
            Icons.chat_bubble_outline,
            shell,
          ),
          _buildStatCard(
            'Shares',
            insights.overview.shares.toString(),
            '+91%',
            blue,
            Icons.share_outlined,
            shell,
          ),
          _buildStatCard(
            'Profile visits',
            '0',
            '+63%',
            cyan,
            Icons.person_outline,
            shell,
          ),
          _buildStatCard(
            'Engagement rate',
            '${((insights.engagement.engagementRate) * 100).toStringAsFixed(1)}%',
            '+2.4%',
            purple,
            Icons.trending_up,
            shell,
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
    StSupportShellStyle shell,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: shell.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: shell.surfaceCardBorder),
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
                style: TextStyle(
                  color: shell.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: shell.onChrome,
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

  Widget _buildAudienceRetention(StSupportShellStyle shell, ThemeData theme) {
    final primaryColor = theme.colorScheme.primary;
    
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: shell.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: shell.surfaceCardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.show_chart,
                          color: primaryColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Audience Retention',
                        style: TextStyle(
                          color: shell.onChrome,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.info_outline,
                          color: shell.iconDim, size: 16),
                    ],
                  ),
                  Text(
                    '0:03',
                    style: TextStyle(
                      color: shell.muted,
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
                  painter: RetentionChartPainter(primaryColor),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('0:00',
                      style: TextStyle(color: shell.muted, fontSize: 11)),
                  Text('0:01',
                      style: TextStyle(color: shell.muted, fontSize: 11)),
                  Text('0:02',
                      style: TextStyle(color: shell.muted, fontSize: 11)),
                  Text('0:03',
                      style: TextStyle(color: shell.muted, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrafficSources(StSupportShellStyle shell, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final blue = isDark ? const Color(0xFF007AFF) : const Color(0xFF0055CC);
    final purple = isDark ? const Color(0xFF7B3FF2) : const Color(0xFF5E3AB8);
    final cyan = isDark ? const Color(0xFF00D9FF) : const Color(0xFF0099CC);
    
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: shell.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: shell.surfaceCardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.traffic, color: blue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Traffic sources',
                    style: TextStyle(
                      color: shell.onChrome,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.info_outline,
                      color: shell.iconDim, size: 16),
                ],
              ),
              const SizedBox(height: 20),
              _buildTrafficBar('For You', 0.64, blue, shell),
              const SizedBox(height: 12),
              _buildTrafficBar('Followers', 0.18, purple, shell),
              const SizedBox(height: 12),
              _buildTrafficBar('Profile', 0.09, cyan, shell),
              const SizedBox(height: 12),
              _buildTrafficBar('External', 0.09, shell.muted, shell),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrafficBar(String label, double percentage, Color color, StSupportShellStyle shell) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: shell.muted,
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
                  color: shell.skeletonLineDim,
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
            style: TextStyle(
              color: shell.onChrome,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopLocations(StSupportShellStyle shell, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final cyan = isDark ? const Color(0xFF00D9FF) : const Color(0xFF0099CC);
    final blue = isDark ? const Color(0xFF007AFF) : const Color(0xFF0055CC);
    final purple = isDark ? const Color(0xFF7B3FF2) : const Color(0xFF5E3AB8);
    
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: shell.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: shell.surfaceCardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          color: cyan, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Top audience locations',
                        style: TextStyle(
                          color: shell.onChrome,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.info_outline,
                          color: shell.iconDim, size: 16),
                    ],
                  ),
                  Text(
                    'See all',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildLocationBar('United States', 0.62, blue, shell),
              const SizedBox(height: 12),
              _buildLocationBar('Canada', 0.12, purple, shell),
              const SizedBox(height: 12),
              _buildLocationBar('United Kingdom', 0.08, cyan, shell),
              const SizedBox(height: 12),
              _buildLocationBar('Other', 0.18, shell.muted, shell),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationBar(String label, double percentage, Color color, StSupportShellStyle shell) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              color: shell.muted,
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
                  color: shell.skeletonLineDim,
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
            style: TextStyle(
              color: shell.onChrome,
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
  final Color primaryColor;
  
  RetentionChartPainter(this.primaryColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withValues(alpha: 0.4),
          primaryColor.withValues(alpha: 0.0),
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
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final linePath = Path();
    linePath.moveTo(0, 0);
    linePath.lineTo(size.width * 0.3, size.height * 0.2);
    linePath.lineTo(size.width * 0.6, size.height * 0.5);
    linePath.lineTo(size.width, size.height * 0.72);

    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width, size.height * 0.72), 5, dotPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: '28%',
        style: TextStyle(
          color: primaryColor,
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
