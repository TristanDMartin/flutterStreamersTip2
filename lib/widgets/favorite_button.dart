import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/favorites_provider.dart';
import '../services/favorites_service.dart';

class FavoriteButton extends ConsumerWidget {
  final String videoId;
  final double size;
  final Color? color;
  final Color? activeColor;

  const FavoriteButton({
    super.key,
    required this.videoId,
    this.size = 24.0,
    this.color,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesState = ref.watch(favoritesProvider);
    final favoritesNotifier = ref.read(favoritesProvider.notifier);

    final isFavorited = favoritesState.favorites.contains(videoId);
    final isLoading = favoritesState.isLoading;
    final syncStatus = favoritesState.syncStatus;

    return GestureDetector(
      onTap: isLoading ? null : () => _handleFavoriteToggle(favoritesNotifier),
      child: Container(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Icon(
                  isFavorited ? Icons.favorite : Icons.favorite_border,
                  size: size,
                  color: isFavorited
                      ? (activeColor ?? Colors.red)
                      : (color ?? Colors.white),
                ),
                if (isLoading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // Sync status indicator
            _buildSyncStatusIndicator(syncStatus),
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
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Colors.orange,
            shape: BoxShape.circle,
          ),
        );
      case FavoritesSyncStatus.error:
        return Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
        );
      case FavoritesSyncStatus.offline:
        return Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Colors.grey,
            shape: BoxShape.circle,
          ),
        );
    }
  }

  void _handleFavoriteToggle(FavoritesNotifier notifier) {
    // Instant button response - UI updates immediately
    notifier.toggleFavorite(videoId);
  }
}
