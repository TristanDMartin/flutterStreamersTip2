import 'package:flutter/material.dart';
import '../models/shared_draft.dart';

class SharedDraftItem extends StatelessWidget {
  final SharedDraft sharedDraft;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const SharedDraftItem({
    super.key,
    required this.sharedDraft,
    required this.onTap,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = sharedDraft.status != SharedDraftStatus.viewed;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  isUnread 
                      ? Colors.white.withValues(alpha:0.2)
                      : Colors.white.withValues(alpha:0.1),
                  isUnread 
                      ? Colors.white.withValues(alpha:0.15)
                      : Colors.white.withValues(alpha:0.05),
                ],
              ),
              border: Border.all(
                color: isUnread 
                    ? const Color(0xFF9248d2).withValues(alpha:0.5)
                    : Colors.white.withValues(alpha:0.1),
                width: isUnread ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Draft thumbnail
                _buildDraftThumbnail(),
                const SizedBox(width: 16),
                // Draft info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              sharedDraft.draftTitle,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildStatusBadge(),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'From ${sharedDraft.senderName}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      if (sharedDraft.message != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          sharedDraft.message!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.play_circle_outline,
                            color: Colors.white.withValues(alpha:0.6),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(sharedDraft.draftDuration),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha:0.6),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.access_time,
                            color: Colors.white.withValues(alpha:0.6),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimeAgo(sharedDraft.sharedAt),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha:0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action buttons
                if (sharedDraft.status == SharedDraftStatus.pending) ...[
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: onAccept,
                        iconSize: 20,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: onDecline,
                        iconSize: 20,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDraftThumbnail() {
    return Container(
      width: 60,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[800],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: sharedDraft.draftThumbnailUrl.isNotEmpty
            ? Image.network(
                sharedDraft.draftThumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.video_library,
                    color: Colors.grey,
                    size: 24,
                  );
                },
              )
            : const Icon(
                Icons.video_library,
                color: Colors.grey,
                size: 24,
              ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    switch (sharedDraft.status) {
      case SharedDraftStatus.pending:
        badgeColor = Colors.orange;
        badgeText = 'Pending';
        badgeIcon = Icons.schedule;
        break;
      case SharedDraftStatus.delivered:
        badgeColor = Colors.blue;
        badgeText = 'Delivered';
        badgeIcon = Icons.done;
        break;
      case SharedDraftStatus.viewed:
        badgeColor = Colors.green;
        badgeText = 'Viewed';
        badgeIcon = Icons.visibility;
        break;
      case SharedDraftStatus.declined:
        badgeColor = Colors.red;
        badgeText = 'Declined';
        badgeIcon = Icons.close;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha:0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha:0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            badgeIcon,
            color: badgeColor,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            badgeText,
            style: TextStyle(
              color: badgeColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }
}
