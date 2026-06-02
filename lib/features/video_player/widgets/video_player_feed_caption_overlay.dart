import 'package:flutter/material.dart';

import '../../../utils/video_caption_resolver.dart';

class VideoPlayerOverlayCaption extends StatelessWidget {
  const VideoPlayerOverlayCaption({
    super.key,
    required this.overlayCaption,
    this.bottom = 120,
  });

  final String overlayCaption;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final String overlayText = overlayCaption.trim();
    if (overlayText.isEmpty) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: 16,
      right: 16,
      bottom: bottom,
      child: IgnorePointer(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            overlayText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}

class VideoPlayerExpandableCaption extends StatefulWidget {
  const VideoPlayerExpandableCaption({
    super.key,
    required this.caption,
    required this.overlayCaption,
  });

  final String caption;
  final String overlayCaption;

  @override
  State<VideoPlayerExpandableCaption> createState() =>
      _VideoPlayerExpandableCaptionState();
}

class _VideoPlayerExpandableCaptionState
    extends State<VideoPlayerExpandableCaption> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final String caption = resolveFeedDisplayCaption(
      caption: widget.caption,
      overlayCaption: widget.overlayCaption,
    );
    if (caption.isEmpty) {
      return const SizedBox.shrink();
    }

    const TextStyle captionStyle = TextStyle(
      color: Colors.white,
      fontSize: 16,
      height: 1.2,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final TextPainter textPainter = TextPainter(
          text: const TextSpan(),
          maxLines: 2,
          textDirection: TextDirection.ltr,
        );
        textPainter.text = TextSpan(text: caption, style: captionStyle);
        textPainter.layout(maxWidth: constraints.maxWidth);
        final bool hasOverflow = textPainter.didExceedMaxLines;

        return AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                caption,
                maxLines: _isExpanded ? null : 2,
                overflow: _isExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: captionStyle,
              ),
              if (hasOverflow) ...<Widget>[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  child: Text(
                    _isExpanded ? 'less' : 'more',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      shadows: <Shadow>[
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.24),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
