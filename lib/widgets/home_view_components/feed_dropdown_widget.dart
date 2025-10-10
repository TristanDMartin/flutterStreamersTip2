import 'dart:developer';
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
      top: 60, // Position right below the header (50px + 10px margin)
      left: 16,
      child: Material(
        elevation: 20, // Very high elevation to appear above video
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 200,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A)
                .withValues(alpha: 0.98), // More opaque dark background
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF9248D2)
                  .withValues(alpha: 0.8), // More visible purple border
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7), // Stronger shadow
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: const Color(0xFF9248D2)
                    .withValues(alpha: 0.2), // Purple glow
                blurRadius: 15,
                offset: const Offset(0, 5),
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
                  log('🔘 FeedDropdown: For You tapped, current tab: $activeTab, isSelected: ${activeTab == 'For You'}');
                  HapticFeedback.lightImpact();
                  log('🔘 FeedDropdown: Calling onForYouTap()');
                  onForYouTap();
                  log('🔘 FeedDropdown: Calling onClose()');
                  onClose();
                  log('🔘 FeedDropdown: For You callback complete');
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
                  log('🔘 FeedDropdown: Following tapped, current tab: $activeTab');
                  HapticFeedback.lightImpact();
                  onFollowingTap();
                  onClose();
                  log('🔘 FeedDropdown: Following callback complete');
                },
              ),
            ],
          ),
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
