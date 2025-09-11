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
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circular Icon Container
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A1A1A), // Dark circular background
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha:0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _getIconData(category.icon),
                color: _getIconColor(category.id),
                size: 32,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Category Name
            Text(
              category.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
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
    // Match the specific colors from the images
    switch (categoryId) {
      case 'gaming':
        return const Color(0xFF9C27B0); // Purple
      case 'art':
        return const Color(0xFF2196F3); // Blue
      case 'music':
        return const Color(0xFFF44336); // Red
      case 'tech':
        return const Color(0xFF4CAF50); // Green
      case 'sports':
        return const Color(0xFFFF9800); // Orange
      case 'food':
        return const Color(0xFFE91E63); // Pink/Red
      case 'just-chatting':
        return const Color(0xFF00BCD4); // Light Blue
      case 'tutorials':
        return const Color(0xFF3F51B5); // Indigo
      case 'fitness':
        return const Color(0xFF009688); // Teal
      case 'podcasts':
        return const Color(0xFF795548); // Brown
      case 'fashion':
        return const Color(0xFF9C27B0); // Purple
      case 'roleplay':
        return const Color(0xFFFFC107); // Yellow
      default:
        return const Color(0xFF757575); // Grey
    }
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
