import 'package:flutter/material.dart';
import '../../models/feed_tab.dart';
import '../../constants/app_colors.dart';

/// Feed dropdown widget for HomeView (For You / Progression / Threads)
class FeedDropdownWidget extends StatelessWidget {
  final FeedTab activeTab;
  final bool isVisible;
  final ValueChanged<FeedTab> onTabSelected;
  final VoidCallback onClose;

  const FeedDropdownWidget({
    super.key,
    required this.activeTab,
    required this.isVisible,
    required this.onTabSelected,
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
                _buildDropdownItem(FeedTab.forYou),
                _buildDivider(),
                _buildDropdownItem(FeedTab.following),
                _buildDivider(),
                _buildDropdownItem(FeedTab.threads),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownItem(FeedTab tab) {
    final bool isSelected = activeTab == tab;
    return GestureDetector(
      onTap: () {
        onTabSelected(tab);
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
              tab.displayName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check, color: Colors.white, size: 20),
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
