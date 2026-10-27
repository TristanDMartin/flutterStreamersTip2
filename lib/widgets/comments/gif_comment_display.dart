import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GifCommentDisplay extends StatefulWidget {
  const GifCommentDisplay({
    super.key,
    required this.gifUrl,
    this.gifMetadata,
    this.gifProvider,
    this.maxHeight = 200.0,
    this.showAttribution = true,
  });

  final String gifUrl;
  final Map<String, dynamic>? gifMetadata;
  final String? gifProvider;
  final double maxHeight;
  final bool showAttribution;

  @override
  State<GifCommentDisplay> createState() => _GifCommentDisplayState();
}

class _GifCommentDisplayState extends State<GifCommentDisplay> {
  bool _isPlaying = true;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isPlaying = !_isPlaying;
            });
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: widget.maxHeight,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CachedNetworkImage(
                    imageUrl: widget.gifUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 150,
                      color: scheme.surfaceContainerHighest,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 150,
                      color: scheme.surfaceContainerHighest,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            color: scheme.error,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load GIF',
                            style: TextStyle(
                              color: scheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    memCacheWidth: 400,
                    maxWidthDiskCache: 400,
                  ),
                  if (!_isPlaying)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(12),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (widget.showAttribution && _shouldShowAttribution())
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _getAttribution(),
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }

  bool _shouldShowAttribution() {
    if (widget.gifProvider != null && widget.gifProvider!.isNotEmpty) {
      return true;
    }
    if (widget.gifMetadata != null &&
        widget.gifMetadata!['username'] != null) {
      return true;
    }
    return false;
  }

  String _getAttribution() {
    final provider = widget.gifProvider ?? 'GIPHY';
    final username = widget.gifMetadata?['username'] as String?;

    if (username != null && username.isNotEmpty) {
      return 'via $provider · @$username';
    }
    return 'via $provider';
  }
}
