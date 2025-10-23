import 'package:flutter/material.dart';

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

    return Material(
      elevation: 20, // Very high elevation to appear above video
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDropdownItem(
              'For You',
              isSelected: activeTab == 'For You',
              onTap: onForYouTap,
            ),
            _buildDivider(),
            _buildDropdownItem(
              'Following',
              isSelected: activeTab == 'Following',
              onTap: onFollowingTap,
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected
              ? const Color(0xFF9248D2).withValues(alpha: 0.1)
              : Colors.transparent,
        ),
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

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: Colors.white.withValues(alpha: 0.1),
      margin: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}
