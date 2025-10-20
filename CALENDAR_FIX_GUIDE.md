# Calendar Events Fix Guide

## 🐛 Problem

Your calendar events aren't showing on the streamer page because:
1. **Firestore Index Missing**: The query requires a composite index
2. **Data Structure Mismatch**: Website uses `events` collection, mobile app uses `calendarEvents` array

## ✅ Solution: Update Website to Match Mobile App

Your mobile app stores events in `users/{userId}/calendarEvents` array. Update your website to use the same structure.

---

## Step 1: Update Your Calendar Service

Find your website's calendar service file (likely `useCalendar.ts` or similar) and update it to query from user documents instead of events collection:

### Before (Current - Causing Error):
```typescript
// ❌ This queries from events collection and requires index
const eventsQuery = collectionGroup(db, 'events')
  .where('creator_id', '==', userId)
  .orderBy('end_at')
  .orderBy('start_at')
  .orderBy('__name__');
```

### After (Fixed):
```typescript
// ✅ This queries from user document - no index needed
import { doc, getDoc, onSnapshot } from 'firebase/firestore';

export function useCalendar(userId: string) {
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!userId) {
      setLoading(false);
      return;
    }

    // Listen to user document for calendar events
    const userDocRef = doc(db, 'users', userId);
    
    const unsubscribe = onSnapshot(
      userDocRef,
      (snapshot) => {
        if (snapshot.exists()) {
          const userData = snapshot.data();
          const calendarEvents = userData.calendarEvents || [];
          
          // Parse events
          const parsedEvents = calendarEvents.map(event => ({
            id: event.id,
            title: event.title || '',
            description: event.description || '',
            date: event.date?.toDate ? event.date.toDate() : new Date(event.date),
          })).sort((a, b) => a.date - b.date);
          
          setEvents(parsedEvents);
          setError(null);
        } else {
          setEvents([]);
        }
        setLoading(false);
      },
      (err) => {
        console.error('Error loading calendar events:', err);
        setError(err.message);
        setLoading(false);
      }
    );

    return () => unsubscribe();
  }, [userId]);

  return { events, loading, error };
}
```

---

## Step 2: Verify Data Structure in Firestore

Check your Firestore console:

### Expected Structure:
```
users (collection)
  └── bU0RxyZ2L4ULAv1Co5L4f825yV73 (document)
      ├── displayName: "technqs"
      ├── avatarURL: "..."
      └── calendarEvents: [         ← Events stored here
          {
            id: "1760622973323",
            title: "Live Stream",
            description: "Weekly Q&A",
            date: Timestamp(...)
          }
        ]
```

---

## Step 3: Test the Fix

1. Open your profile page
2. Create a calendar event
3. Go to your streamer page
4. Click "Calendar" tab
5. ✅ Events should now appear!

---

## Alternative: Keep Events Collection (Requires Index)

If you prefer to keep the events collection structure:

### Create the Firestore Index

1. Click this link: https://console.firebase.google.com/project/streamerstip-6cfdb/firestore/indexes
2. Click "Create Index"
3. Configure:
   - **Collection Group**: `events`
   - **Fields**:
     - `end_at` (Ascending)
     - `start_at` (Ascending)
     - `__name__` (Ascending)
4. Click "Create"
5. Wait 2-5 minutes for index to build

---

## Why This Happens

Your **mobile app** stores events in the user document:
```dart
// lib/widgets/streamer_card_view.dart
final eventsData = _userData!['calendarEvents'];
```

Your **website** was trying to query from a separate collection:
```typescript
// useCalendar.ts - OLD APPROACH
collectionGroup(db, 'events')
```

These two approaches don't match, causing the events to not sync properly.

---

## Recommended Approach

**Use the `calendarEvents` array in user documents** because:
- ✅ No Firestore index needed
- ✅ Simpler queries
- ✅ Faster reads (single document vs collection query)
- ✅ Already matches mobile app structure
- ✅ Easier to maintain

---

## Next Steps

1. Update your `useCalendar.ts` (or similar file) to use the fixed code above
2. Test creating an event on your profile page
3. Verify it shows on the streamer page
4. Check that it syncs to mobile app

---

**Last Updated**: October 16, 2025  
**Status**: Ready to Fix 🔧

