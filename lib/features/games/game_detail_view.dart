import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/game.dart';
import '../../models/home_video.dart';
import '../../services/game_service.dart';
import '../../widgets/video_player_view_optimized.dart';

final gameDetailProvider = FutureProvider.family<Game?, String>((ref, gameId) async {
  return GameService().getGame(gameId);
});

final gameVideosProvider = FutureProvider.family<List<HomeVideo>, String>((ref, gameId) async {
  return GameService().getGameVideos(gameId, limit: 50);
});

final gameFollowStatusProvider = FutureProvider.family<bool, String>((ref, gameId) async {
  return GameService().isGameFollowed(gameId);
});

class GameDetailView extends ConsumerStatefulWidget {
  const GameDetailView({
    super.key,
    required this.gameId,
  });

  final String gameId;

  @override
  ConsumerState<GameDetailView> createState() => _GameDetailViewState();
}

class _GameDetailViewState extends ConsumerState<GameDetailView> {
  String _selectedFeed = 'recent';

  @override
  Widget build(BuildContext context) {
    final gameAsync = ref.watch(gameDetailProvider(widget.gameId));
    final videosAsync = ref.watch(gameVideosProvider(widget.gameId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark 
          ? const Color(0xFF0A0A0F) 
          : theme.scaffoldBackgroundColor,
      body: gameAsync.when(
        data: (game) {
          if (game == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.videogame_asset_off, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Game not found',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go back'),
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                backgroundColor: isDark 
                    ? const Color(0xFF0A0A0F) 
                    : theme.scaffoldBackgroundColor,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: game.artworkUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: isDark 
                              ? Colors.white.withValues(alpha: 0.03)
                              : Colors.grey.shade200,
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: isDark 
                              ? Colors.white.withValues(alpha: 0.03)
                              : Colors.grey.shade200,
                          child: const Icon(Icons.videogame_asset, size: 64),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              (isDark 
                                  ? const Color(0xFF0A0A0F) 
                                  : theme.scaffoldBackgroundColor
                              ).withValues(alpha: 0.9),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  game.title,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${game.clipCount} clips · ${game.followerCount} followers',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.textTheme.bodyMedium?.color
                                        ?.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          _FollowButton(gameId: widget.gameId),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SegmentedButton<String>(
                        selected: {_selectedFeed},
                        onSelectionChanged: (Set<String> selected) {
                          setState(() {
                            _selectedFeed = selected.first;
                          });
                        },
                        segments: const [
                          ButtonSegment(
                            value: 'recent',
                            label: Text('Recent'),
                          ),
                          ButtonSegment(
                            value: 'trending',
                            label: Text('Trending'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              videosAsync.when(
                data: (videos) {
                  if (videos.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.video_library_outlined,
                              size: 64,
                              color: theme.disabledColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No clips yet',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.disabledColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to share ${game.title} content!',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.disabledColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final sortedVideos = _selectedFeed == 'recent'
                      ? videos
                      : [...videos]..sort((a, b) {
                          final aLikes = a.likeCount ?? 0;
                          final bLikes = b.likeCount ?? 0;
                          return bLikes.compareTo(aLikes);
                        });

                  return SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.56,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final video = sortedVideos[index];
                        return _VideoCard(
                          video: video,
                          allVideos: sortedVideos,
                          startIndex: index,
                        );
                      },
                      childCount: sortedVideos.length,
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stack) => SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load videos',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            ref.invalidate(gameVideosProvider(widget.gameId));
                          },
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load game',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  ref.invalidate(gameDetailProvider(widget.gameId));
                },
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowButton extends ConsumerWidget {
  const _FollowButton({required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followStatus = ref.watch(gameFollowStatusProvider(gameId));

    return followStatus.when(
      data: (isFollowing) {
        return FilledButton.icon(
          onPressed: () async {
            if (isFollowing) {
              await GameService().unfollowGame(gameId);
            } else {
              await GameService().followGame(gameId);
            }
            ref.invalidate(gameFollowStatusProvider(gameId));
            ref.invalidate(gameDetailProvider(gameId));
          },
          icon: Icon(isFollowing ? Icons.check : Icons.add),
          label: Text(isFollowing ? 'Following' : 'Follow'),
          style: FilledButton.styleFrom(
            backgroundColor: isFollowing
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : Theme.of(context).colorScheme.primary,
            foregroundColor: isFollowing
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onPrimary,
          ),
        );
      },
      loading: () => const SizedBox(
        width: 120,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({
    required this.video,
    required this.allVideos,
    required this.startIndex,
  });

  final HomeVideo video;
  final List<HomeVideo> allVideos;
  final int startIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VideoPlayerViewOptimized(
              videos: allVideos,
              initialIndex: startIndex,
              useHero: false,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade100,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: video.thumbnailURL ?? '',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade900,
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade900,
                        child: const Icon(Icons.video_library),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDuration(video.duration ?? 0),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.caption ?? 'Untitled',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.favorite,
                        size: 14,
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatCount(video.likeCount ?? 0),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color
                              ?.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
