import 'package:flutter/material.dart';
import '../widgets/streamer_card_view.dart';
import '../models/streamer_card_samples.dart';
import '../models/streamer_card.dart';

class StreamerCardDemo extends StatelessWidget {
  const StreamerCardDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'StreamerCard Demo',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Tap a card to view it',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            _buildCardPreview(
              context,
              StreamerCardSamples.gamingPro,
              'Gaming Pro',
              'Online • 200K YouTube',
            ),
            const SizedBox(height: 16),
            _buildCardPreview(
              context,
              StreamerCardSamples.techReviewer,
              'Tech Reviewer',
              'Idle • 500K YouTube',
            ),
            const SizedBox(height: 16),
            _buildCardPreview(
              context,
              StreamerCardSamples.fitnessInfluencer,
              'Fitness Guru',
              'DND • 300K Instagram',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardPreview(
    BuildContext context,
    StreamerCard card,
    String title,
    String subtitle,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => StreamerCardView(
              userId: card.id,
              currentUserId: 'current_user',
              onDismiss: () => Navigator.of(context).pop(),
              onFollow: (userId) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Followed ${card.displayName}'),
                    backgroundColor: const Color(0xFF25E5D2),
                  ),
                );
              },
              onMessage: (userId) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Messaged ${card.displayName}'),
                    backgroundColor: const Color(0xFF25E5D2),
                  ),
                );
              },
              onShare: (userId) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Shared ${card.displayName}\'s profile'),
                    backgroundColor: const Color(0xFF25E5D2),
                  ),
                );
              },
            ),
          ),
        );
      },
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF9248d2),
              Color(0xFF7768df),
              Color(0xFF1670de),
              Color(0xFF3c8bd6),
              Color(0xFF4897d2),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9248d2).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Avatar placeholder
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.2),
                border: Border.all(
                  color: const Color(0xFF25E5D2),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Tap to view',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
