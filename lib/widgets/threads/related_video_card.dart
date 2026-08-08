import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../routing/app_navigator.dart';
import '../../services/forum_service.dart';
import '../player_screen.dart';

/// Canonical related-video card for thread detail (matches web RelatedVideoCard).
class RelatedVideoCard extends StatefulWidget {
  const RelatedVideoCard({
    super.key,
    required this.videoId,
    this.fallbackThumbnailUrl,
    this.fallbackTitle,
  });

  final String videoId;
  final String? fallbackThumbnailUrl;
  final String? fallbackTitle;

  @override
  State<RelatedVideoCard> createState() => _RelatedVideoCardState();
}

class _RelatedVideoCardState extends State<RelatedVideoCard> {
  final ForumService _forumService = ForumService();
  bool _loading = true;
  bool _unavailable = false;
  String _title = 'Related video';
  String? _thumbnailUrl;
  String _meta = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final Map<String, dynamic>? data =
          await _forumService.getVideoDetails(widget.videoId);
      if (!mounted) return;
      if (data == null &&
          (widget.fallbackThumbnailUrl == null ||
              widget.fallbackThumbnailUrl!.isEmpty) &&
          (widget.fallbackTitle == null || widget.fallbackTitle!.isEmpty)) {
        setState(() {
          _loading = false;
          _unavailable = true;
        });
        return;
      }
      final String title = (data?['title'] ??
              data?['caption'] ??
              widget.fallbackTitle ??
              'Related video')
          .toString();
      final String thumb = (data?['thumb'] ??
              data?['thumbnailUrl'] ??
              data?['thumbnailURL'] ??
              widget.fallbackThumbnailUrl ??
              '')
          .toString();
      final int duration = (data?['duration'] as num?)?.toInt() ?? 0;
      String meta = '';
      if (duration > 0) {
        final int m = duration ~/ 60;
        final int s = duration % 60;
        meta = '$m:${s.toString().padLeft(2, '0')}';
      }
      setState(() {
        _loading = false;
        _title = title;
        _thumbnailUrl = thumb.isEmpty ? null : thumb;
        _meta = meta;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _unavailable = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Related Video',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          if (_loading)
            Container(
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
              ),
            )
          else if (_unavailable)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: const Text(
                'This video is no longer available.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            )
          else
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  AppNavigator.openPlayer(
                    context,
                    mode: PlayerMode.homeFeed,
                    initialIndex: 0,
                    videoIds: <String>[widget.videoId],
                  );
                },
                child: Ink(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(16),
                        ),
                        child: SizedBox(
                          width: 132,
                          height: 84,
                          child: Stack(
                            fit: StackFit.expand,
                            children: <Widget>[
                              if (_thumbnailUrl != null)
                                CachedNetworkImage(
                                  imageUrl: _thumbnailUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(
                                    color: Colors.black26,
                                  ),
                                )
                              else
                                Container(color: Colors.black26),
                              const Center(
                                child: Icon(
                                  Icons.play_circle_fill,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              if (_meta.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 4),
                                Text(
                                  _meta,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
