import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Feed menu widget for HomeView (discover, network, etc.)
class FeedMenuWidget extends StatelessWidget {
  final bool isVisible;
  final VoidCallback onDiscoverTap;
  final VoidCallback onNetworkTap;
  final VoidCallback onClose;

  const FeedMenuWidget({
    super.key,
    required this.isVisible,
    required this.onDiscoverTap,
    required this.onNetworkTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMenuItem(
            icon: Icons.explore,
            title: 'Discover',
            subtitle: 'Find new content',
            onTap: () {
              HapticFeedback.lightImpact();
              onDiscoverTap();
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.people,
            title: 'Network',
            subtitle: 'Connect with others',
            onTap: () {
              HapticFeedback.lightImpact();
              onNetworkTap();
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.close,
            title: 'Close',
            subtitle: 'Hide menu',
            onTap: () {
              HapticFeedback.lightImpact();
              onClose();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(0.5),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.white.withOpacity(0.1),
    );
  }
}
