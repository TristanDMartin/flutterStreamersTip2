import 'package:flutter/material.dart';

import '../../models/forum_author.dart';
import '../../services/discussion_author_service.dart';
import '../../utils/avatar_url_resolver.dart';
import '../../widgets/status_aware_avatar.dart';
import 'threads_contract.dart';
import 'threads_models.dart';


/// Detail hero chrome for Threads v2.
class ThreadWorkspaceHeader extends StatelessWidget {
  const ThreadWorkspaceHeader({
    super.key,
    required this.thread,
    this.onFollow,
    this.isFollowing = false,
  });

  final ThreadDto thread;
  final VoidCallback? onFollow;
  final bool isFollowing;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String category = humanCategoryLabel(thread);
    final String type = thread.typeLabel;
    final String momentum = thread.momentumLabelText;
    final bool showResolved = thread.status == 'resolved';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _AuthorBlock(thread: thread),
              ),
              if (onFollow != null)
                IconButton(
                  tooltip: isFollowing ? 'Following' : 'Follow thread',
                  onPressed: onFollow,
                  icon: Icon(
                    isFollowing
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_none_rounded,
                    color: isFollowing
                        ? scheme.primary
                        : scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            thread.title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _MetaPill(label: type, emphasized: true),
              Text(
                '·',
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.35),
                ),
              ),
              _MetaPill(label: category),
              Text(
                '·',
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.35),
                ),
              ),
              _MetaPill(label: momentum),
              if (showResolved) ...<Widget>[
                Text(
                  '·',
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.35),
                  ),
                ),
                _MetaPill(label: 'Resolved', emphasized: true),
              ],
            ],
          ),
          if (thread.sourceCommentText != null) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                'Started from a discussion:\n'
                '“${thread.sourceCommentText}”',
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.72),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AuthorBlock extends StatelessWidget {
  const _AuthorBlock({required this.thread});

  final ThreadDto thread;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String authorId = thread.authorId.trim();
    if (authorId.isEmpty) {
      return Text(
        'Creator',
        style: TextStyle(
          color: scheme.onSurface.withValues(alpha: 0.75),
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return StreamBuilder<ForumAuthor?>(
      stream: DiscussionAuthorService().watchForumAuthor(authorId),
      builder: (
        BuildContext context,
        AsyncSnapshot<ForumAuthor?> snapshot,
      ) {
        final ForumAuthor? live = snapshot.data;
        final String username = safeThreadHandle(
          liveUsername: live?.username,
          fallbackUsername: thread.authorUsername,
          fallbackDisplayName:
              live?.displayName ?? thread.authorDisplayName,
          authorId: authorId,
        );
        final String? avatarUrl = pickBestAvatarUrl(
          live?.avatarUrl,
          thread.authorAvatarUrl,
        );
        return Row(
          children: <Widget>[
            StatusAwareAvatar(
              userId: authorId,
              avatarURL: avatarUrl,
              radius: 21,
              showOnlineIndicator: false,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Original post',
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.45),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.label,
    this.emphasized = false,
  });

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Text(
      label,
      style: TextStyle(
        color: emphasized
            ? scheme.primary
            : scheme.onSurface.withValues(alpha: 0.62),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

String humanCategoryLabel(ThreadDto thread) {
  final String canonical = normalizeCategoryId(thread.categoryId);
  final String? mapped = kCategoryLabels[canonical];
  if (mapped != null && mapped.isNotEmpty) {
    return mapped;
  }
  final String label = (thread.categoryLabel ?? '').trim();
  if (label.isNotEmpty && !looksLikeOpaqueDocumentId(label)) {
    return label;
  }
  final String raw = thread.categoryId.trim();
  if (raw.isNotEmpty && !looksLikeOpaqueDocumentId(raw)) {
    return raw;
  }
  return 'Discussion';
}

String safeThreadHandle({
  required String? liveUsername,
  required String? fallbackUsername,
  required String? fallbackDisplayName,
  required String authorId,
}) {
  final String live = (liveUsername ?? '').trim();
  if (_isDisplayable(live, authorId)) {
    return live;
  }
  final String fallback = (fallbackUsername ?? '').trim();
  if (_isDisplayable(fallback, authorId)) {
    return fallback;
  }
  final String display = (fallbackDisplayName ?? '').trim();
  if (_isDisplayable(display, authorId)) {
    return display;
  }
  return 'Creator';
}

bool _isDisplayable(String value, String authorId) {
  if (value.isEmpty || value == authorId) {
    return false;
  }
  return !looksLikeOpaqueDocumentId(value);
}

bool looksLikeOpaqueDocumentId(String value) {
  if (value.contains(' ') || value.contains('_') || value.contains('-')) {
    return false;
  }
  return RegExp(r'^[A-Za-z0-9]{18,28}$').hasMatch(value);
}
