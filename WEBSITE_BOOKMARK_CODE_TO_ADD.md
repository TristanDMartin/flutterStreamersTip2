# Website Bookmark Code - Copy & Paste Ready 📋

## 🎯 What You Need to Do

Just update your existing website bookmark code with the correct structure. Here's the exact code:

---

## Step 1: Update Your Bookmark Function

Find your website's bookmark function and replace it with this:

```javascript
import {
  doc,
  setDoc,
  deleteDoc,
  serverTimestamp,
  Timestamp
} from 'firebase/firestore';
import { db, auth } from '../firebase/config';

/**
 * Bookmark a calendar event (syncs with mobile app)
 */
export async function bookmarkCalendarEvent(event, eventOwnerId, eventOwnerName) {
  const currentUser = auth.currentUser;
  if (!currentUser) {
    console.error('❌ Not authenticated');
    return false;
  }

  try {
    console.log('🔖 Bookmarking event:', event.id);

    // Parse event date
    const eventDate = new Date(event.date);
    
    // Calculate notify time (30 minutes before event)
    const notifyTime = new Date(eventDate.getTime() - (30 * 60 * 1000));

    // ✅ EXACT STRUCTURE MOBILE APP EXPECTS
    const bookmarkData = {
      eventId: event.id,
      creatorId: eventOwnerId,
      creatorName: eventOwnerName || 'Unknown User',  // ✅ Display name, not ID!
      title: event.title,
      startAt: Timestamp.fromDate(eventDate),
      notifyAt: Timestamp.fromDate(notifyTime),
      notify: true,
      createdAt: serverTimestamp(),
      scheduledTaskId: null,
      source: 'website'
    };

    // ✅ SAVE TO CORRECT LOCATION
    const bookmarkRef = doc(
      db,
      'users',
      currentUser.uid,
      'bookmarks',  // ← THIS IS KEY! Must be 'bookmarks'
      event.id
    );

    await setDoc(bookmarkRef, bookmarkData);

    console.log('✅ Bookmark saved!');
    return true;
  } catch (error) {
    console.error('❌ Bookmark error:', error);
    return false;
  }
}

/**
 * Unbookmark an event
 */
export async function unbookmarkCalendarEvent(eventId) {
  const currentUser = auth.currentUser;
  if (!currentUser) return false;

  try {
    const bookmarkRef = doc(
      db,
      'users',
      currentUser.uid,
      'bookmarks',  // ← Must match!
      eventId
    );

    await deleteDoc(bookmarkRef);
    console.log('✅ Bookmark removed');
    return true;
  } catch (error) {
    console.error('❌ Unbookmark error:', error);
    return false;
  }
}
```

---

## Step 2: Update Your Bookmark Button

In your calendar event component (wherever you show events on website):

```jsx
function EventCard({ event, eventOwnerId }) {
  const [isBookmarked, setIsBookmarked] = useState(false);

  // Check if bookmarked on load
  useEffect(() => {
    checkBookmarkStatus();
  }, [event.id]);

  const checkBookmarkStatus = async () => {
    const bookmarked = await isEventBookmarked(event.id);
    setIsBookmarked(bookmarked);
  };

  const handleToggleBookmark = async () => {
    if (isBookmarked) {
      await unbookmarkCalendarEvent(event.id);
      setIsBookmarked(false);
    } else {
      await bookmarkCalendarEvent(event, eventOwnerId);
      setIsBookmarked(true);
    }
  };

  return (
    <div className="event-card">
      <h3>{event.title}</h3>
      <p>{event.description}</p>
      
      {/* ✅ BOOKMARK BUTTON */}
      <button onClick={handleToggleBookmark}>
        {isBookmarked ? '🔖 Bookmarked' : '📑 Bookmark'}
      </button>
    </div>
  );
}
```

---

## Step 3: Helper Function to Check Bookmark Status

```javascript
import { doc, getDoc } from 'firebase/firestore';

/**
 * Check if event is bookmarked
 */
export async function isEventBookmarked(eventId) {
  const currentUser = auth.currentUser;
  if (!currentUser) return false;

  try {
    const bookmarkRef = doc(
      db,
      'users',
      currentUser.uid,
      'bookmarks',
      eventId
    );

    const snap = await getDoc(bookmarkRef);
    return snap.exists();
  } catch (error) {
    console.error('❌ Error checking bookmark:', error);
    return false;
  }
}
```

---

## 🔍 What to Change in YOUR Code

### Find These Lines:
```javascript
// Look for something like:
'calendarBookmarks'  // ← WRONG
// or
collection(db, 'users', uid, 'calendarBookmarks')
// or  
{ bookmarkedAt: ... }  // ← WRONG field name
```

### Replace With:
```javascript
'bookmarks'  // ← CORRECT
collection(db, 'users', uid, 'bookmarks')
{ createdAt: serverTimestamp() }  // ← CORRECT field name
```

---

## ✅ That's It!

You only need to:
1. **Update your bookmark JavaScript function** (copy code above)
2. **Ensure collection path is `bookmarks`**
3. **Ensure fields match exactly** (eventId, creatorId, startAt, notifyAt, etc.)

**Don't** need to:
- ❌ Add markdown files to website
- ❌ Create new pages
- ❌ Change mobile app (already done)

---

## 🧪 Test After Update

1. Bookmark event on website
2. Check browser console:
   ```
   ✅ Bookmark saved!
   ```
3. Open mobile app → Menu → Bookmarks
4. ✨ Should see event in Upcoming tab!

---

## 💡 Quick Debug

Add this console.log to your website code:

```javascript
console.log('Saving to:', `users/${currentUser.uid}/bookmarks/${event.id}`);
console.log('Data:', bookmarkData);
```

This will show you exactly where it's saving and what data it's writing!

