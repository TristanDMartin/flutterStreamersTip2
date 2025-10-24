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

    debugPrint(
        '🔘 FeedDropdown: Building dropdown widget - activeTab: $activeTab, isVisible: $isVisible');

    return Stack(
      children: [
        // Debug overlay to show dropdown bounds
        Positioned.fill(
          child: Container(
            color: Colors.red.withValues(alpha: 0.1),
            child: Center(
              child: Text(
                'DEBUG: Dropdown Area',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        // Actual dropdown
        Material(
          elevation: 20, // Very high elevation to appear above video
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 200,
            decoration: BoxDecoration(
              color: Colors.black
                  .withValues(alpha: 0.9), // More opaque for better visibility
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    Colors.white.withValues(alpha: 0.3), // More visible border
                width: 2, // Thicker border
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
        ),
      ],
    );
  }

  Widget _buildDropdownItem(String title,
      {required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        debugPrint('🔘 FeedDropdown: $title item tapped');
        onTap();
      },
      behavior: HitTestBehavior.opaque, // Ensure it captures taps
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
