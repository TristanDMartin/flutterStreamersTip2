import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/recommended_content.dart';

class RecommendedContentCard extends StatefulWidget {
  final RecommendedContent content;

  const RecommendedContentCard({
    super.key,
    required this.content,
  });

  @override
  State<RecommendedContentCard> createState() => _RecommendedContentCardState();
}

class _RecommendedContentCardState extends State<RecommendedContentCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  // bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTap() async {
    if (widget.content.url != null) {
      final uri = Uri.parse(widget.content.url!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // appLog('Cannot open URL: ${widget.content.url}');
      }
    }
  }

  void _onTapDown(TapDownDetails details) {
    // setState(() {
    //   _isPressed = true;
    // });
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    // setState(() {
    //   _isPressed = false;
    // });
    _animationController.reverse();
  }

  void _onTapCancel() {
    // setState(() {
    //   _isPressed = false;
    // });
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final foreground = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);
    return GestureDetector(
      onTap: _onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              height: 92,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A).withValues(alpha: 0.72)
                    : Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : const Color(0xFF0F172A).withValues(alpha: 0.08),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.07),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Icon/Thumbnail
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF9248D2).withValues(alpha: 0.22),
                          const Color(0xFF4897D2).withValues(alpha: 0.22),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _getIconForContent(widget.content.id),
                      color: const Color(0xFF4897D2),
                      size: 24,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Content info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.content.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: foreground,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.content.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: muted,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Arrow indicator
                  const Icon(
                    Icons.north_east_rounded,
                    color: Color(0xFF4897D2),
                    size: 16,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getIconForContent(String contentId) {
    switch (contentId) {
      case 'creator-tools':
        return Icons.build;
      case 'academy':
        return Icons.school;
      case 'peripherals':
        return Icons.devices_other_rounded;
      default:
        return Icons.link;
    }
  }
}
