import 'package:flutter/material.dart';
import '../models/trending_creator.dart';

class TrendingCreatorCard extends StatelessWidget {
  final TrendingCreator creator;
  final VoidCallback onTap;

  const TrendingCreatorCard({
    super.key,
    required this.creator,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 100,
        child: Column(
          children: [
            const SizedBox(height: 12),
            
            // Avatar with gradient ring
            Stack(
              children: [
                // Gradient ring
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Color(0xFF9248D2), // Purple
                        Color(0xFF7768DF), // Another purple
                        Color(0xFF1670DE), // Blue
                        Color(0xFF3C8BD6), // Lighter blue
                        Color(0xFF4897D2), // Lightest blue
                        Color(0xFF9248D2), // Back to purple for smooth transition
                      ],
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.transparent,
                    ),
                  ),
                ),
                
                // Avatar image or placeholder
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.all(3),
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
                                  size: 40,
                                  color: Colors.grey,
                                );
                              },
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.grey,
                          ),
                  ),
                ),
                
                // Online status badge
                if (creator.isOnline)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                        border: Border.all(
                          color: Colors.white,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Username
            Text(
              creator.username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
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
}
