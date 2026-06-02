import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trending_creator.dart';
import 'online_status_indicator.dart';

class TrendingCreatorCard extends ConsumerWidget {
  final TrendingCreator creator;
  final VoidCallback onTap;

  const TrendingCreatorCard({
    super.key,
    required this.creator,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 100,
        height: 120, // Fixed height to prevent overflow
        child: Column(
          mainAxisSize: MainAxisSize.min, // Prevent column from expanding
          children: [
            const SizedBox(height: 8),

            // Avatar with gradient ring - matching example exactly
            Stack(
              children: [
                // Outer gradient ring - very thick and prominent
                Container(
                  width: 100, // Large outer ring
                  height: 100,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Color(0xFF9248D2), // Purple
                        Color(0xFF7768DF), // Another purple
                        Color(0xFF1670DE), // Blue
                        Color(0xFF3C8BD6), // Lighter blue
                        Color(0xFF4897D2), // Lightest blue
                        Color(
                            0xFF9248D2), // Back to purple for smooth transition
                      ],
                    ),
                  ),
                ),

                // Inner white circle for separation
                Center(
                  child: Container(
                    width: 70, // White separation circle
                    height: 70,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),

                // Avatar circle - much smaller
                Center(
                  child: Container(
                    width: 60, // Small avatar circle
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.withValues(alpha: 0.1),
                    ),
                    child: creator.avatarURL != null
                        ? ClipOval(
                            child: Image.network(
                              creator.avatarURL!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.person,
                                  size: 28,
                                  color: Colors.grey,
                                );
                              },
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            size: 28,
                            color: Colors.grey,
                          ),
                  ),
                ),

                // Dynamic online status indicator
                OnlineStatusIndicator(
                  userId: creator.id,
                  size: 16,
                  showBorder: true,
                  borderColor: Colors.white,
                  borderWidth: 3,
                  showShadow: true,
                  position: const EdgeInsets.only(
                    right: 8,
                    top: 8,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8), // Reduced spacing

            // Username
            Expanded(
              // Use Expanded to take remaining space
              child: Center(
                child: Text(
                  creator.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12, // Reduced font size
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2, // Allow 2 lines for longer usernames
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const SizedBox(height: 8), // Bottom padding
          ],
        ),
      ),
    );
  }
}
