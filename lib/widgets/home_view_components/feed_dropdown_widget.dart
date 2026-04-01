import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// Feed dropdown widget for HomeView (shows For You / Following / Threads options)
class FeedDropdownWidget extends StatelessWidget {
  final String activeTab;
  final bool isVisible;
  final VoidCallback onForYouTap;
  final VoidCallback onFollowingTap;
  final VoidCallback onThreadsTap;
  final VoidCallback onClose;

  const FeedDropdownWidget({
    super.key,
    required this.activeTab,
    required this.isVisible,
    required this.onForYouTap,
    required this.onFollowingTap,
    required this.onThreadsTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Stack(
      children: [
        Material(
          elevation: 20,
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 200,
            decoration: BoxDecoration(
              color: AppColors.supportBackground.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.supportSurfaceGradient,
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
                _buildDivider(),
                _buildDropdownItem(
                  'Threads',
                  isSelected: activeTab == 'Threads',
                  onTap: onThreadsTap,
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
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isSelected
              ? AppColors.supportAccent.withValues(alpha: 0.16)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(
                Icons.check,
                color: Colors.white,
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
