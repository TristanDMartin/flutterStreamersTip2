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
    final useCompactSize = hasCategorySelected && !isSelected;
    final containerSize = useCompactSize ? _iconSizeUnselected : _iconSizeSelected;
    final innerIconSize = useCompactSize ? _iconInnerUnselected : _iconInnerSelected;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: containerSize,
                height: containerSize,
                decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected 
                    ? const Color(0xFF6633CC).withValues(alpha: 0.2) // Selected background
                    : const Color(0xFF1A1A1A), // Dark circular background
                border: isSelected 
                    ? Border.all(
                        color: const Color(0xFF6633CC),
                        width: 2,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: isSelected 
                        ? const Color(0xFF6633CC).withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.3),
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
          ),
            SizedBox(height: useCompactSize ? 6 : 12),
            Text(
              category.name,
              style: TextStyle(
                fontSize: useCompactSize ? 11 : 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected 
                    ? const Color(0xFF6633CC) 
                    : Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
