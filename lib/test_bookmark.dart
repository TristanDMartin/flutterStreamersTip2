import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'models/calendar_event.dart';
import 'services/enhanced_bookmark_service.dart';

class BookmarkTestPage extends StatefulWidget {
  const BookmarkTestPage({super.key});

  @override
  State<BookmarkTestPage> createState() => _BookmarkTestPageState();
}

class _BookmarkTestPageState extends State<BookmarkTestPage> {
  late final EnhancedBookmarkService _bookmarkService;
  bool _isLoading = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _bookmarkService = EnhancedBookmarkService();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      await _bookmarkService.initialize();
      if (kDebugMode) {
        print('✅ BookmarkTestPage: Service initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ BookmarkTestPage: Error initializing service: $e');
      }
      setState(() {
        _error = 'Failed to initialize service: $e';
      });
    }
  }

  Future<void> _testBookmarkEvent() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _success = null;
    });

    try {
      // Create a test calendar event
      final testEvent = CalendarEvent(
        id: 'test-event-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Test Event',
        description: 'This is a test event for bookmarking',
        date: DateTime.now().add(const Duration(hours: 1)),
      );

      // Test bookmarking the event
      await _bookmarkService.bookmarkEvent(
        eventId: testEvent.id,
        creatorId: 'test-creator',
        title: testEvent.title,
        startAt: testEvent.date,
        notifyAt: testEvent.date.subtract(const Duration(minutes: 15)),
        source: 'test',
      );

      setState(() {
        _success = 'Event bookmarked successfully!';
      });

      if (kDebugMode) {
        print('✅ BookmarkTestPage: Event bookmarked successfully');
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to bookmark event: $e';
      });

      if (kDebugMode) {
        print('❌ BookmarkTestPage: Error bookmarking event: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testDeleteBookmark() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _success = null;
    });

    try {
      // Delete the test bookmark
      await _bookmarkService.deleteBookmark(eventId: 'test-event-${DateTime.now().millisecondsSinceEpoch}');

      setState(() {
        _success = 'Bookmark deleted successfully!';
      });

      if (kDebugMode) {
        print('✅ BookmarkTestPage: Bookmark deleted successfully');
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to delete bookmark: $e';
      });

      if (kDebugMode) {
        print('❌ BookmarkTestPage: Error deleting bookmark: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmark Test'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Current User: ${FirebaseAuth.instance.currentUser?.uid ?? "Not logged in"}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _testBookmarkEvent,
              child: _isLoading 
                ? const CircularProgressIndicator()
                : const Text('Test Bookmark Event'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isLoading ? null : _testDeleteBookmark,
              child: _isLoading 
                ? const CircularProgressIndicator()
                : const Text('Test Delete Bookmark'),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            if (_success != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _success!,
                  style: const TextStyle(color: Colors.green),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
