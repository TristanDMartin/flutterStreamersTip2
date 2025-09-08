import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/favorites_provider.dart';
import '../services/favorites_service.dart';
import 'favorite_button.dart';

class VideoCardWithFavorites extends ConsumerWidget {
  final String videoId;
  final String title;
  final String creator;
  final String description;
  final String likes;
  final String comments;
  final String shares;
  final String videoUrl;
  final VoidCallback? onTap;

  const VideoCardWithFavorites({
    super.key,
    required this.videoId,
    required this.title,
    required this.creator,
    required this.description,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.videoUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesState = ref.watch(favoritesProvider);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        color: Colors.black,
        child: Stack(
          children: [
            // Video content would go here
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'by $creator',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            // Right side action buttons
            Positioned(
              right: 16,
              bottom: 100,
              child: Column(
                children: [
                  // Like button
                  _buildActionButton(
                    icon: Icons.favorite_border,
                    count: likes,
                    onTap: () {
                      // Handle like action
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Favorite button with instant response
                  FavoriteButton(
                    videoId: videoId,
                    size: 28,
                    activeColor: const Color(0xFF9248d2), // User's preferred purple
                  ),
                  const SizedBox(height: 16),
                  
                  // Comment button
                  _buildActionButton(
                    icon: Icons.comment_outlined,
                    count: comments,
                    onTap: () {
                      // Handle comment action
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Share button
                  _buildActionButton(
                    icon: Icons.share,
                    count: shares,
                    onTap: () {
                      // Handle share action
                    },
                  ),
                ],
              ),
            ),
            
            // Sync status indicator (top right)
            Positioned(
              top: 50,
              right: 16,
              child: _buildSyncStatusIndicator(favoritesState.syncStatus),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              count,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatusIndicator(FavoritesSyncStatus status) {
    switch (status) {
      case FavoritesSyncStatus.synced:
        return const SizedBox.shrink();
      case FavoritesSyncStatus.pending:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Syncing...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      case FavoritesSyncStatus.error:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Sync Error',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      case FavoritesSyncStatus.offline:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Offline',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
    }
  }
}
