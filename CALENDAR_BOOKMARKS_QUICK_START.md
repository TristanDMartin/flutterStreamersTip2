# Calendar Bookmarks - Quick Start Guide 🚀

## 🎯 What You Get

Bookmark calendar events on mobile or website → See them instantly everywhere!

---

## 📱 Mobile App - Quick Integration

### Step 1: Initialize Service (AppStartup or Main View)

```dart
import '../services/calendar_bookmark_service.dart';

@override
void initState() {
  super.initState();
  
  // Initialize when user logs in
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId != null) {
    CalendarBookmarkService().initialize(userId);
  }
}
```

### Step 2: Add Bookmark Button to Calendar Events

```dart
// In StreamerCardView or wherever calendar events are shown
Widget _buildBookmarkButton(CalendarEvent event, String eventOwnerId) {
  final bookmarkService = CalendarBookmarkService();

  return StreamBuilder<Set<String>>(
    stream: bookmarkService.bookmarksStream,
    builder: (context, snapshot) {
      final isBookmarked = snapshot.data?.contains(event.id) ?? false;

      return IconButton(
        icon: Icon(
          isBookmarked ? Icons.bookmark : Icons.bookmark_border,
          color: isBookmarked ? Colors.amber : Colors.white,
        ),
        onPressed: () async {
          await bookmarkService.toggleBookmark(
            event,
            eventOwnerId,
            eventOwnerName: 'Streamer Name', // Optional
          );
        },
      );
    },
  );
}
```

### Step 3: Show Bookmarked Events

```dart
// Create a bookmarks page
Widget build(BuildContext context) {
  final bookmarkService = CalendarBookmarkService();

  return StreamBuilder<List<BookmarkedCalendarEvent>>(
    stream: bookmarkService.eventsStream,
    builder: (context, snapshot) {
      final bookmarkedEvents = snapshot.data ?? [];

      if (bookmarkedEvents.isEmpty) {
        return Text('No bookmarked events');
      }

      return ListView.builder(
        itemCount: bookmarkedEvents.length,
        itemBuilder: (context, index) {
          final event = bookmarkedEvents[index];
          return ListTile(
            title: Text(event.title),
            subtitle: Text(event.description),
            trailing: Icon(Icons.bookmark, color: Colors.amber),
          );
        },
      );
    },
  );
}
```

---

## 🌐 Website - Quick Integration

### Step 1: Initialize Service

```javascript
import { calendarBookmarkService } from '../services/calendarBookmarkService';
import { auth } from '../firebase/config';

useEffect(() => {
  const currentUser = auth.currentUser;
  if (currentUser) {
    calendarBookmarkService.initialize(currentUser.uid);
  }
}, []);
```

### Step 2: Add Bookmark Button

```jsx
function EventCard({ event, eventOwnerId }) {
  const [isBookmarked, setIsBookmarked] = useState(false);

  useEffect(() => {
    // Subscribe to bookmark changes
    const unsubscribe = calendarBookmarkService.subscribe((bookmarkedIds) => {
      setIsBookmarked(bookmarkedIds.has(event.id));
    });

    return () => unsubscribe();
  }, [event.id]);

  const handleToggle = async () => {
    await calendarBookmarkService.toggleBookmark(event, eventOwnerId);
  };

  return (
    <div className="event-card">
      <h3>{event.title}</h3>
      <p>{event.description}</p>
      <button onClick={handleToggle}>
        {isBookmarked ? '🔖 Bookmarked' : '📑 Bookmark'}
      </button>
    </div>
  );
}
```

### Step 3: Show Bookmarked Events

```jsx
function BookmarksPage() {
  const [bookmarkedEvents, setBookmarkedEvents] = useState([]);

  useEffect(() => {
    const unsubscribe = calendarBookmarkService.subscribe(
      (bookmarkedIds, bookmarkedEventsMap) => {
        const events = Array.from(bookmarkedEventsMap.values());
        setBookmarkedEvents(events);
      }
    );

    return () => unsubscribe();
  }, []);

  return (
    <div>
      <h1>Bookmarked Events ({bookmarkedEvents.length})</h1>
      {bookmarkedEvents.map((event) => (
        <EventCard key={event.eventId} event={event} />
      ))}
    </div>
  );
}
```

---

## 🔥 Key Features

✅ **Instant sync** - Changes appear in < 100ms
✅ **Optimistic UI** - Instant feedback before save
✅ **Real-time** - Uses Firestore snapshots()
✅ **Bidirectional** - Mobile ↔️ Website
✅ **Source tracking** - See where bookmark was made
✅ **Auto-cleanup** - Respects 12h event expiry

---

## 📊 Firestore Structure

```
users/{userId}/
  └─ calendarBookmarks/
      └─ {eventId}/
          ├─ eventId: "event123"
          ├─ userId: "owner456"
          ├─ userName: "John Doe"
          ├─ title: "Live Stream"
          ├─ description: "Q&A session"
          ├─ date: Timestamp
          ├─ bookmarkedAt: Timestamp
          └─ source: "mobile" | "website"
```

---

## 🧪 Test It!

1. **Mobile**: Bookmark an event
2. **Website**: Open bookmarks → ✨ Appears instantly
3. **Website**: Unbookmark it
4. **Mobile**: ✨ Disappears instantly

---

## 🚀 That's It!

You now have **instant cross-platform bookmark sync** with just a few lines of code! 🎉

See `CALENDAR_BOOKMARKS_SYNC_IMPLEMENTATION.md` for full details.

