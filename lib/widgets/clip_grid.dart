import 'package:flutter/material.dart';
import '../models/video_clip.dart';

class ClipGrid extends StatelessWidget {
  final List<VideoClip> clips;
  final ValueChanged<VideoClip> onClipSelected;
  final String categoryId;
  final dynamic viewModel; // TODO: Replace with proper type

  const ClipGrid({
    super.key,
    required this.clips,
    required this.onClipSelected,
    required this.categoryId,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: clips.length,
      itemBuilder: (context, index) {
        final clip = clips[index];
        return ClipThumbnail(
          clip: clip,
          onTap: () => onClipSelected(clip),
        );
      },
    );
  }
}

class ClipThumbnail extends StatelessWidget {
  final VideoClip clip;
  final VoidCallback onTap;

  const ClipThumbnail({
    super.key,
    required this.clip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.transparent,
        ),
        child: Stack(
          children: [
            // Thumbnail image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  gradient: _getGradientForCategory(clip.categoryId),
                ),
                child: clip.thumbnailURL != null
                    ? Image.network(
                        clip.thumbnailURL!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              gradient: _getGradientForCategory(clip.categoryId),
                            ),
                            child: Icon(
                              Icons.photo,
                              color: Colors.white.withValues(alpha: 0.7),
                              size: 24,
                            ),
                          );
                        },
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: _getGradientForCategory(clip.categoryId),
                        ),
                        child: Icon(
                          Icons.photo,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 24,
                        ),
                      ),
              ),
            ),
            
            // View count overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.5),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatCount(clip.views),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LinearGradient _getGradientForCategory(String categoryId) {
    final colors = <Color>[];
    switch (categoryId) {
      case 'gaming':
        colors.addAll([Colors.purple, Colors.purple.withValues(alpha: 0.7)]);
        break;
      case 'art':
        colors.addAll([Colors.blue, Colors.blue.withValues(alpha: 0.7)]);
        break;
      case 'music':
        colors.addAll([Colors.pink, Colors.pink.withValues(alpha: 0.7)]);
        break;
      case 'tech':
        colors.addAll([Colors.green, Colors.green.withValues(alpha: 0.7)]);
        break;
      case 'sports':
        colors.addAll([Colors.orange, Colors.orange.withValues(alpha: 0.7)]);
        break;
      case 'food':
        colors.addAll([Colors.red, Colors.red.withValues(alpha: 0.7)]);
        break;
      case 'just-chatting':
        colors.addAll([Colors.cyan, Colors.cyan.withValues(alpha: 0.7)]);
        break;
      case 'tutorials':
        colors.addAll([Colors.indigo, Colors.indigo.withValues(alpha: 0.7)]);
        break;
      case 'fitness':
        colors.addAll([Colors.teal, Colors.teal.withValues(alpha: 0.7)]);
        break;
      case 'podcasts':
        colors.addAll([Colors.brown, Colors.brown.withValues(alpha: 0.7)]);
        break;
      case 'fashion':
        colors.addAll([Colors.purple, Colors.purple.withValues(alpha: 0.7)]);
        break;
      case 'roleplay':
        colors.addAll([Colors.amber, Colors.amber.withValues(alpha: 0.7)]);
        break;
      default:
        colors.addAll([
          const Color(0xFF2A2A2A),
          const Color(0xFF1A1A1A),
        ]);
    }
    
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    );
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    final kValue = count / 1000.0;
    return '${kValue.toStringAsFixed(1)}K';
  }
}
