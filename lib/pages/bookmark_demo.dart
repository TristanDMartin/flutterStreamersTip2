import 'package:flutter/material.dart';
import 'bookmark_view.dart';

class BookmarkDemo extends StatelessWidget {
  const BookmarkDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        title: const Text(
          'Bookmark Demo',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark,
              color: Color(0xFF955CFF),
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'Bookmark System Demo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Navigate to BookmarkView to see the complete implementation',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: null, // Will be handled by navigation
              child: Text('Open BookmarkView'),
            ),
          ],
        ),
      ),
    );
  }
}
