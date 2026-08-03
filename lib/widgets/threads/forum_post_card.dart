import 'package:flutter/material.dart';
import '../../core/theme/support_shell_style.dart';
import '../../models/forum_post.dart';
import '../../services/discussion_author_service.dart';
import '../status_aware_avatar.dart';

/// Testimonial-style card for a forum thread in the grid.
class ForumPostCard extends StatefulWidget {
  final ForumPost post;
  final VoidCallback onTap;
  final bool featured;

  const ForumPostCard({
    super.key,
    required this.post,
    required this.onTap,
    this.featured = false,
  });

  @override
  State<ForumPostCard> createState() => _ForumPostCardState();
}

class _ForumPostCardState extends State<ForumPostCard> {
  bool _isHovered = false;

  double get _restAngle {
    final int hash = widget.post.id.codeUnits.fold<int>(
      0,
      (int sum, int c) => sum + c,
    );
    switch (hash.abs() % 3) {
      case 0:
        return -0.055;
      case 1:
        return 0.044;
      default:
        return -0.035;
    }
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final ForumPost post = widget.post;
    final String category = (post.categoryDisplayName ?? '').isNotEmpty
        ? post.categoryDisplayName!
        : _threadTypeLabel(post.category);
    final String quote = post.content.trim().isNotEmpty
        ? post.content.trim()
        : (post.title.trim().isNotEmpty ? post.title.trim() : 'Open thread');
    final bool showTitle =
        post.title.trim().isNotEmpty && post.title.trim() != quote;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          transformAlignment: Alignment.center,
          transform: Matrix4.identity()
            ..rotateZ(_isHovered ? 0 : _restAngle)
            ..translateByDouble(0, _isHovered ? -6.0 : 0.0, 0, 1),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: shell.surfaceCard.withValues(alpha: 0.72),
                  border: Border.all(
                    color: shell.surfaceCardBorder.withValues(alpha: 0.58),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: shell.shadowSoft.withValues(alpha: 0.65),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        _ThreadTypePill(label: category),
                        const Spacer(),
                        Text(
                          _relativeTime(post.createdAt),
                          style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.45),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (showTitle) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        post.title,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: widget.featured ? 18 : 15,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Expanded(
                      child: Text(
                        '“$quote”',
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.78),
                          fontSize: 15,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: widget.featured ? 6 : 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        StatusAwareAvatar(
                          userId: post.author.uid,
                          avatarURL: post.author.avatarUrl,
                          radius: 21,
                          showOnlineIndicator: false,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StreamBuilder(
                            stream: DiscussionAuthorService()
                                .watchForumAuthor(post.author.uid),
                            builder: (BuildContext ctx, snapshot) {
                              final ColorScheme c =
                                  Theme.of(ctx).colorScheme;
                              final liveAuthor = snapshot.data;
                              final String name = (liveAuthor?.username ??
                                      liveAuthor?.displayName ??
                                      post.author.username)
                                  .trim();
                              final String display = name.isNotEmpty
                                  ? name
                                  : post.author.displayName.trim();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    display.isEmpty ? 'Creator' : display,
                                    style: TextStyle(
                                      color: c.onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    category,
                                    style: TextStyle(
                                      color: c.onSurface
                                          .withValues(alpha: 0.5),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${post.commentCount} replies · ${post.likes} helpful',
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.4),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _threadTypeLabel(String category) {
    final String normalized = category.toLowerCase();
    if (normalized.contains('growth')) return 'Growth Advice';
    if (normalized.contains('game')) return 'Gaming Debate';
    if (normalized.contains('video') || normalized.contains('clip')) {
      return 'Video Discussion';
    }
    if (normalized.contains('setup')) return 'Stream Setup';
    return 'Creator Talk';
  }

  String _relativeTime(DateTime date) {
    final Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${date.month}/${date.day}';
  }
}

class _ThreadTypePill extends StatelessWidget {
  const _ThreadTypePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: scheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
