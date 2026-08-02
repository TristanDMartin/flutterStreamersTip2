import 'package:flutter/material.dart';

import 'threads_models.dart';

/// Detail hero chrome for Threads v2 (type, category, momentum, source).
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _Chip(label: thread.typeLabel, color: scheme.secondary),
              _Chip(
                label: thread.resolvedCategoryLabel,
                color: scheme.primary,
              ),
              _Chip(
                label: thread.momentumLabelText,
                color: scheme.tertiary,
              ),
              _Chip(
                label: thread.statusLabel,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            thread.title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          if (thread.sourceCommentText != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Text(
                'Started from a discussion on:\n“${thread.sourceCommentText}”',
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.72),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
          ],
          if (onFollow != null) ...<Widget>[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onFollow,
              icon: Icon(
                isFollowing ? Icons.notifications_active : Icons.notifications_none,
                size: 18,
              ),
              label: Text(isFollowing ? 'Following thread' : 'Follow thread'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
