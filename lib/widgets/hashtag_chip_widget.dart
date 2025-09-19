import 'package:flutter/material.dart';
import '../services/hashtag_lock_service.dart';

class HashtagChipWidget extends StatelessWidget {
  final String hashtag;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool showReservedIndicator;

  const HashtagChipWidget({
    super.key,
    required this.hashtag,
    this.isSelected = false,
    this.onTap,
    this.showReservedIndicator = true,
  });

  @override
  Widget build(BuildContext context) {
    final hashtagService = HashtagLockService();
    final isReserved = hashtagService.isHashtagReserved(hashtag);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFF9248D2)
              : isReserved 
                  ? Colors.orange.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFF9248D2)
                : isReserved
                    ? Colors.orange.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.3),
            width: isReserved ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hashtag,
              style: TextStyle(
                color: isSelected 
                    ? Colors.white 
                    : isReserved 
                        ? Colors.orange
                        : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isReserved && showReservedIndicator) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.lock,
                size: 12,
                color: Colors.orange,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ReservedHashtagIndicator extends StatelessWidget {
  final String hashtag;
  
  const ReservedHashtagIndicator({
    super.key,
    required this.hashtag,
  });

  @override
  Widget build(BuildContext context) {
    final hashtagService = HashtagLockService();
    final isReserved = hashtagService.isHashtagReserved(hashtag);
    
    if (!isReserved) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock,
            size: 12,
            color: Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            'Reserved',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
