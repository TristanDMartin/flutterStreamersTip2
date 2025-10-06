import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Feed dropdown widget for HomeView (shows For You / Following options)
class FeedDropdownWidget extends StatelessWidget {
  final String activeTab;
  final bool isVisible;
  final VoidCallback onForYouTap;
  final VoidCallback onFollowingTap;
  final VoidCallback onClose;

  const FeedDropdownWidget({
    super.key,
    required this.activeTab,
    required this.isVisible,
    required this.onForYouTap,
    required this.onFollowingTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Positioned(
      top: 60, // Position below the header
      left: 16,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF9248D2).withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDropdownItem(
              'For You',
              isSelected: activeTab == 'For You',
              onTap: () {
                HapticFeedback.lightImpact();
                onForYouTap();
                onClose();
              },
            ),
            Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.1),
              margin: const EdgeInsets.symmetric(horizontal: 16),
            ),
            _buildDropdownItem(
              'Following',
              isSelected: activeTab == 'Following',
              onTap: () {
                HapticFeedback.lightImpact();
                onFollowingTap();
                onClose();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownItem(String title,
      {required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? const Color(0xFF9248D2) : Colors.white,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(
                Icons.check,
                color: Color(0xFF9248D2),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
