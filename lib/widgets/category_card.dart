import 'package:flutter/material.dart';
import '../models/category.dart';
import 'streamer_card_sections.dart';

class CategoryCard extends StatelessWidget {
  final Category category;
  final bool isSelected;
  final bool hasCategorySelected;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.category,
    required this.isSelected,
    this.hasCategorySelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final ColorScheme cs = Theme.of(context).colorScheme;
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedScale(
            scale: isSelected ? 0.98 : 1,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark
                        ? StreamerCardBackStyle.accent.withValues(alpha: 0.2)
                        : cs.primary.withValues(alpha: 0.12))
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.white.withValues(alpha: 0.92)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? (isDark
                          ? StreamerCardBackStyle.accent.withValues(alpha: 0.4)
                          : cs.primary)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFF0F172A).withValues(alpha: 0.08)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        _getIconData(category.icon),
                        color: isSelected && isDark
                            ? StreamerCardBackStyle.lavender
                            : _getIconColor(category.id),
                        size: 18,
                      ),
                      const Spacer(),
                      if (isSelected)
                        Icon(
                          Icons.check_circle_rounded,
                          color: isDark
                              ? StreamerCardBackStyle.lavender
                              : cs.primary,
                          size: 16,
                        ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? (isDark
                                  ? StreamerCardBackStyle.lavender
                                  : cs.primary)
                              : (isDark
                                  ? StreamerCardBackStyle.softText
                                  : cs.onSurface),
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Explore clips',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: isDark
                              ? StreamerCardBackStyle.muted
                              : cs.onSurface.withValues(alpha: 0.55),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getIconColor(String categoryId) {
    switch (categoryId) {
      case 'All':
        return const Color(0xFF40DCD1);
      case 'general':
        return const Color(0xFF607D8B);
      case 'gaming':
        return const Color(0xFF9C27B0);
      case 'art':
        return const Color(0xFF2196F3);
      case 'music':
        return const Color(0xFFF44336);
      case 'tech':
        return const Color(0xFF4CAF50);
      case 'sports':
        return const Color(0xFFFF9800);
      case 'food':
        return const Color(0xFFE91E63);
      case 'just-chatting':
        return const Color(0xFF00BCD4);
      case 'tutorials':
        return const Color(0xFF3F51B5);
      case 'fitness':
        return const Color(0xFF009688);
      case 'podcasts':
        return const Color(0xFF795548);
      case 'fashion':
        return const Color(0xFF9C27B0);
      case 'roleplay':
        return const Color(0xFFFFC107);
      default:
        return const Color(0xFF757575);
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'square.grid.2x2':
        return Icons.grid_view;
      case 'sparkles':
        return Icons.auto_awesome;
      case 'gamecontroller.fill':
        return Icons.sports_esports;
      case 'paintbrush.fill':
        return Icons.brush;
      case 'music.note':
        return Icons.music_note;
      case 'laptopcomputer':
        return Icons.laptop;
      case 'sportscourt.fill':
        return Icons.sports_soccer;
      case 'fork.knife':
        return Icons.restaurant;
      case 'message.fill':
        return Icons.chat;
      case 'book.fill':
        return Icons.book;
      case 'figure.run':
        return Icons.directions_run;
      case 'mic.fill':
        return Icons.mic;
      case 'tshirt.fill':
        return Icons.checkroom;
      case 'theatermasks.fill':
        return Icons.theater_comedy;
      default:
        return Icons.category;
    }
  }
}
