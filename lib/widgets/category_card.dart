import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/category.dart';

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

  static const double _iconSizeSelected = 80;
  static const double _iconSizeUnselected = 56;
  static const double _iconInnerSelected = 32;
  static const double _iconInnerUnselected = 22;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ColorScheme cs = Theme.of(context).colorScheme;
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final useCompactSize = hasCategorySelected && !isSelected;
        final targetIconSize =
            useCompactSize ? _iconSizeUnselected : _iconSizeSelected;
        final targetInnerSize =
            useCompactSize ? _iconInnerUnselected : _iconInnerSelected;
        final textScale = MediaQuery.textScalerOf(context);
        final labelReserve = textScale.scale(useCompactSize ? 18 : 22);
        final gap = useCompactSize ? 6.0 : 8.0;
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : targetIconSize;
        final maxHeight =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 120.0;
        final availableForIcon = math.max(40.0, maxHeight - labelReserve - gap);
        final containerSize = math.min(
          targetIconSize,
          math.min(maxWidth, availableForIcon),
        );
        final innerIconSize =
            math.min(targetInnerSize, math.max(20.0, containerSize * 0.4));

        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox.expand(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                Container(
                  width: containerSize,
                  height: containerSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? cs.primary.withValues(alpha: 0.2)
                        : cs.surfaceContainerHighest,
                    border: isSelected
                        ? Border.all(color: cs.primary, width: 2)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? cs.primary.withValues(alpha: 0.28)
                            : cs.shadow.withValues(alpha: isDark ? 0.35 : 0.1),
                        blurRadius: isSelected ? 12 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getIconData(category.icon),
                    color: _getIconColor(category.id),
                    size: innerIconSize,
                  ),
                ),
                SizedBox(height: gap),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    category.name,
                    style: TextStyle(
                      fontSize: useCompactSize ? 11 : 14,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? cs.primary : cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
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
