import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/calendar_event.dart';

/// Service to automatically clean up expired calendar events
/// Deletes events that are 12+ hours past their scheduled time
class CalendarCleanupService {
  static final CalendarCleanupService _instance =
      CalendarCleanupService._internal();
  factory CalendarCleanupService() => _instance;
  CalendarCleanupService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Delete events that are 12+ hours past their scheduled time
  Future<void> cleanupExpiredEvents(String userId) async {
    try {
      debugPrint('🧹 CalendarCleanup: Checking for expired events...');

      // Get user document
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        debugPrint('⚠️ CalendarCleanup: User document not found');
        return;
      }

      final userData = userDoc.data();
      if (userData == null || userData['calendarEvents'] == null) {
        debugPrint('📅 CalendarCleanup: No calendar events to clean');
        return;
      }

      final eventsData = userData['calendarEvents'] as List<dynamic>;
      if (eventsData.isEmpty) {
        debugPrint('📅 CalendarCleanup: No events to process');
        return;
      }

      // Parse events
      final events = eventsData
          .map((e) {
            try {
              if (e is Map<String, dynamic>) {
                return CalendarEvent.fromMap(e);
              }
              return null;
            } catch (error) {
              debugPrint('❌ CalendarCleanup: Error parsing event: $error');
              return null;
            }
          })
          .where((e) => e != null)
          .cast<CalendarEvent>()
          .toList();

      // Find expired events (12+ hours past their time)
      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(hours: 12));

      final expiredEvents =
          events.where((event) => event.date.isBefore(cutoffTime)).toList();

      if (expiredEvents.isEmpty) {
        debugPrint('✅ CalendarCleanup: No expired events found');
        return;
      }

      debugPrint(
          '🗑️ CalendarCleanup: Found ${expiredEvents.length} expired events to delete');

      // Keep only non-expired events
      final remainingEvents = events
          .where((event) => !event.date.isBefore(cutoffTime))
          .map((event) => event.toMap())
          .toList();

      // Update Firestore
      await _firestore.collection('users').doc(userId).update({
        'calendarEvents': remainingEvents,
      });

      debugPrint(
          '✅ CalendarCleanup: Deleted ${expiredEvents.length} expired events');
      debugPrint(
          '📅 CalendarCleanup: ${remainingEvents.length} events remaining');

      // Log deleted events for debugging
      for (final event in expiredEvents) {
        final hoursPast = now.difference(event.date).inHours;
        debugPrint(
            '   • Deleted: "${event.title}" (${hoursPast}h past scheduled time)');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ CalendarCleanup: Error cleaning up events: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Check if an event is expired (12+ hours past)
  bool isEventExpired(DateTime eventDate) {
    final now = DateTime.now();
    final cutoffTime = now.subtract(const Duration(hours: 12));
    return eventDate.isBefore(cutoffTime);
  }

  /// Get time until event expires (in hours)
  int hoursUntilExpiry(DateTime eventDate) {
    final now = DateTime.now();
    final expiryTime = eventDate.add(const Duration(hours: 12));
    final difference = expiryTime.difference(now);
    return difference.inHours;
  }
}
