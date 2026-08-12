import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/recommended_content.dart';
import 'streamer_card_sections.dart';

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
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color foreground =
        isDark ? StreamerCardBackStyle.softText : const Color(0xFF0F172A);
    final Color muted =
        isDark ? StreamerCardBackStyle.muted : const Color(0xFF64748B);
    return GestureDetector(
      onTap: _onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (BuildContext context, Widget? child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              height: 84,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFF0F172A).withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? StreamerCardBackStyle.accent.withValues(alpha: 0.2)
                          : const Color(0xFF9248D2).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getIconForContent(widget.content.id),
                      color: isDark
                          ? StreamerCardBackStyle.lavender
                          : const Color(0xFF4897D2),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.content.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
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
                            fontWeight: FontWeight.w400,
                            color: muted,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
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
