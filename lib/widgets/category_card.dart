import 'package:flutter/material.dart';
import '../models/category.dart';

class CategoryCard extends StatelessWidget {
  final Category category;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected 
              ? category.color.withValues(alpha: 0.1)
              : Colors.transparent,
          border: isSelected
              ? Border.all(
                  color: category.color,
                  width: 2,
                )
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            
            // Icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected 
                    ? category.color
                    : Colors.grey.withValues(alpha: 0.2),
              ),
              child: Icon(
                _getIconData(category.icon),
                color: isSelected 
                    ? Colors.white
                    : category.color,
                size: 24,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Name
            Text(
              category.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected 
                    ? category.color
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

  IconData _getIconData(String iconName) {
    // Map SwiftUI system icon names to Flutter Material icons
    switch (iconName) {
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
