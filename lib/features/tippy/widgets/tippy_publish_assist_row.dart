import 'package:flutter/material.dart';

import '../../publish/publish_flow_tokens.dart';

enum TippyPublishAssistBusyKind {
  idle,
  improving,
  suggesting,
}

/// Compact Tippy actions on the New Post screen (caption + hashtags).
class TippyPublishAssistRow extends StatelessWidget {
  const TippyPublishAssistRow({
    super.key,
    required this.enabled,
    required this.busyKind,
    required this.onImproveCaption,
    required this.onSuggestHashtags,
    this.onOpenTippy,
    this.creditsRemaining,
  });

  final bool enabled;
  final TippyPublishAssistBusyKind busyKind;
  final VoidCallback? onImproveCaption;
  final VoidCallback? onSuggestHashtags;
  final VoidCallback? onOpenTippy;
  final int? creditsRemaining;

  bool get _isBusy => busyKind != TippyPublishAssistBusyKind.idle;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return _LockedHint(onUnlock: onOpenTippy);
    }
    final String improveLabel =
        busyKind == TippyPublishAssistBusyKind.improving
            ? 'Improving…'
            : 'Improve caption';
    final String hashtagLabel =
        busyKind == TippyPublishAssistBusyKind.suggesting
            ? 'Suggesting…'
            : 'Suggest hashtags';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _AssistChip(
                icon: Icons.auto_awesome_rounded,
                label: improveLabel,
                showProgress:
                    busyKind == TippyPublishAssistBusyKind.improving,
                onTap: _isBusy ? null : onImproveCaption,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AssistChip(
                icon: Icons.tag_rounded,
                label: hashtagLabel,
                showProgress:
                    busyKind == TippyPublishAssistBusyKind.suggesting,
                onTap: _isBusy ? null : onSuggestHashtags,
              ),
            ),
          ],
        ),
        if (creditsRemaining != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            '$creditsRemaining Tippy credits left',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _LockedHint extends StatelessWidget {
  const _LockedHint({this.onUnlock});

  final VoidCallback? onUnlock;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onUnlock,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: PublishFlowTokens.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PublishFlowTokens.border),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Unlock Tippy on Pro for caption and hashtag help',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onUnlock != null)
              Text(
                'Learn more',
                style: TextStyle(
                  color: PublishFlowTokens.primaryStart,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AssistChip extends StatelessWidget {
  const _AssistChip({
    required this.icon,
    required this.label,
    this.onTap,
    this.showProgress = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PublishFlowTokens.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PublishFlowTokens.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (showProgress)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF93C5FD),
                  ),
                )
              else
                Icon(icon, size: 16, color: const Color(0xFF93C5FD)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
