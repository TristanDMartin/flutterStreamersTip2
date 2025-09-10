# Bookmark System Implementation

This document outlines the complete bookmark → notify → manage flow implementation for StreamersTip.

## Overview

The bookmark system allows users to:
1. **Bookmark events** from StreamerCardBackView
2. **Receive push notifications** when events go live
3. **Manage bookmarks** in a dedicated BookmarkView
4. **Toggle notifications** on/off per bookmark

## Architecture

### Data Model (Firestore)

```
/users/{uid}/bookmarks/{eventId}
{
  eventId: string,                   // Same ID used in events collection
  creatorId: string,                 // Profile hosting the event
  title: string,                     // Event title for rendering and notifications
  startAt: Timestamp,                // UTC start time of event
  notifyAt: Timestamp,               // Usually same as startAt (or startAt - 5m)
  notify: boolean,                   // Default true; toggle-able
  createdAt: Timestamp,              // serverTimestamp()
  scheduledTaskId: string | null,    // ID for Cloud Task to cancel if un-bookmarked
  source: "streamerCardBackView"     // Traceability/analytics
}

/users/{uid}/deviceTokens/{token}
{
  createdAt: serverTimestamp(),
  platform: 'ios' | 'android' | 'web',
  lastSeenAt: serverTimestamp()
}
```

### Client Flow (Flutter)

#### 1. Bookmark Creation (StreamerCardBackView)
- User taps bookmark button
- **Optimistic UI update** (immediate visual feedback)
- Write to Firestore with `notify: true`
- Cloud Function trigger schedules notification
- Revert UI on failure

#### 2. Bookmark Management (BookmarkView)
- **Tabbed interface**: Upcoming, Live, Past
- **Status chips**: Color-coded by event status
- **Delete functionality**: Swipe or long-press
- **Notification toggle**: Per-bookmark on/off
- **Real-time updates**: Stream-based data loading

#### 3. Push Notifications
- **FCM token registration** on app start
- **Cloud Functions** handle scheduling
- **Notification content**: "Event is live now" + "@creator — title"
- **Deep linking**: `streamerstip://event/{eventId}`

## Implementation Files

### Models
- `lib/models/bookmark_event.dart` - BookmarkEvent model with status helpers

### Services
- `lib/services/enhanced_bookmark_service.dart` - Complete bookmark management
- `lib/services/bookmark_service.dart` - Legacy service (backward compatibility)

### UI Components
- `lib/pages/bookmark_view.dart` - Main bookmark management interface
- `lib/widgets/streamer_card_view.dart` - Updated with optimistic bookmark UI

### Backend (Cloud Functions)
- `cloud_functions/index.js` - Notification scheduling and sending
- `cloud_functions/package.json` - Dependencies

### Security
- `firestore.rules` - Updated with bookmark and device token permissions

## Key Features

### ✅ Optimistic UI
- Immediate visual feedback on bookmark actions
- Automatic reversion on failure
- Smooth user experience

### ✅ Real-time Updates
- Stream-based data loading
- Live status updates (upcoming → live → past)
- Automatic UI refresh

### ✅ Status Management
- **Upcoming**: Events in the future
- **Live**: Events within 30 minutes of start time
- **Past**: Events that have already started

### ✅ Notification Control
- Per-bookmark notification toggle
- FCM token management
- Cloud Function integration

### ✅ Error Handling
- Graceful failure recovery
- User-friendly error messages
- Debug logging

## Usage Examples

### Bookmark an Event
```dart
await _bookmarkService.bookmarkEvent(
  eventId: 'event_123',
  creatorId: 'user_456',
  title: 'Live Stream',
  startAt: DateTime.now().add(Duration(hours: 2)),
);
```

### Toggle Notifications
```dart
await _bookmarkService.toggleNotification(
  eventId: 'event_123',
  notify: false,
);
```

### Get Bookmarks by Status
```dart
final grouped = _bookmarkService.getBookmarksByStatus();
final upcoming = grouped[EventStatus.upcoming];
```

## Security Rules

```javascript
// Users can read and write their own bookmarks
match /users/{userId}/bookmarks/{bookmarkId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}

// Users can read and write their own device tokens
match /users/{userId}/deviceTokens/{tokenId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

## Deployment

### 1. Update Dependencies
```bash
flutter pub get
```

### 2. Deploy Firestore Rules
```bash
firebase deploy --only firestore:rules
```

### 3. Deploy Cloud Functions
```bash
cd cloud_functions
npm install
firebase deploy --only functions
```

## Testing

### Manual Testing
1. Open StreamerCardBackView
2. Tap bookmark button on calendar events
3. Navigate to BookmarkView
4. Verify events appear in correct tabs
5. Test delete and notification toggle

### Unit Testing
```dart
test('bookmark event creates correct data structure', () async {
  final service = EnhancedBookmarkService();
  await service.bookmarkEvent(
    eventId: 'test_event',
    creatorId: 'test_creator',
    title: 'Test Event',
    startAt: DateTime.now(),
  );
  
  final bookmarks = await service.getBookmarks();
  expect(bookmarks.length, 1);
  expect(bookmarks.first.eventId, 'test_event');
});
```

## Future Enhancements

- [ ] **Bulk operations**: Select multiple bookmarks
- [ ] **Export functionality**: Share bookmarks
- [ ] **Advanced filtering**: By creator, date range, etc.
- [ ] **Analytics**: Track bookmark engagement
- [ ] **Offline support**: Sync when connection restored
- [ ] **Custom notification times**: User-defined reminders

## Troubleshooting

### Common Issues

1. **Bookmarks not appearing**: Check Firestore rules and user authentication
2. **Notifications not working**: Verify FCM token registration and Cloud Functions
3. **UI not updating**: Ensure proper state management and stream subscriptions

### Debug Commands

```bash
# Check Firestore rules
firebase firestore:rules:get

# View Cloud Function logs
firebase functions:log

# Test FCM token
firebase messaging:send --token YOUR_TOKEN
```

## Performance Considerations

- **Pagination**: Load bookmarks in batches for large collections
- **Caching**: Cache frequently accessed bookmark data
- **Optimization**: Use `const` constructors and efficient rebuilds
- **Memory**: Dispose streams and controllers properly

This implementation provides a complete, production-ready bookmark system with real-time updates, push notifications, and excellent user experience.
