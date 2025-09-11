import 'package:flutter/material.dart';

class EndOfFeedView extends StatelessWidget {
  const EndOfFeedView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.keyboard_arrow_down,
              size: 60,
              color: Colors.white.withValues(alpha:0.7),
            ),
            const SizedBox(height: 20),
            const Text(
              "You've reached the end!",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "You've seen all the amazing content we have for you right now. Check back later for more! ✨",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha:0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            Column(
              children: [
                Text(
                  "Pull down to refresh and discover new content",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha:0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "🔄 Latest videos • 🔥 Popular content",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha:0.4),
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
