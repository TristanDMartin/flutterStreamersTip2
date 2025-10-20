# Website Bookmark Fix - Exact Field Structure 🔧

## 🎯 Critical Issue

Your website bookmarks need to write the **exact fields** that the mobile app expects!

---

## 📋 Required Fields (MUST MATCH EXACTLY)

The mobile app's `BookmarkEvent` model requires these exact fields:

```javascript
{
  eventId: string,        // ✅ Event ID
  creatorId: string,      // ✅ Event owner's user ID  
  title: string,          // ✅ Event title
  startAt: Timestamp,     // ✅ When event starts
  notifyAt: Timestamp,    // ✅ When to notify user (30min before)
  notify: boolean,        // ✅ Whether to send notification
  createdAt: Timestamp,   // ✅ When bookmark was created
  scheduledTaskId: string | null,  // Optional
  source: string         // ✅ "website" or "mobile"
}
```

---

## ✅ Correct Website Implementation

### Update Your Website's Bookmark Service

**File:** `src/services/calendarBookmarkService.js` (or similar)

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
export async function bookmarkCalendarEvent(event, eventOwnerId) {
  const currentUser = auth.currentUser;
  if (!currentUser) {
    throw new Error('Not authenticated');
  }

  try {
    console.log('🔖 Bookmarking event:', event.id);

    // Parse event date
    const eventDate = new Date(event.date);
    
    // Calculate notify time (30 minutes before event)
    const notifyTime = new Date(eventDate.getTime() - (30 * 60 * 1000));

    // ✅ EXACT STRUCTURE THAT MOBILE APP EXPECTS
    const bookmarkData = {
      eventId: event.id,                    // ✅ Required
      creatorId: eventOwnerId,              // ✅ Required
      title: event.title,                   // ✅ Required
      startAt: Timestamp.fromDate(eventDate), // ✅ Required
      notifyAt: Timestamp.fromDate(notifyTime), // ✅ Required
      notify: true,                         // ✅ Required (default true)
      createdAt: serverTimestamp(),         // ✅ Required
      scheduledTaskId: null,                // Optional
      source: 'website'                     // ✅ Required
    };

    // ✅ CORRECT COLLECTION PATH
    const bookmarkRef = doc(
      db,
      'users',
      currentUser.uid,
      'bookmarks',  // ✅ Must be 'bookmarks' not 'calendarBookmarks'
      event.id
    );

    // Save to Firestore
    await setDoc(bookmarkRef, bookmarkData);

    console.log('✅ Bookmark saved to:', `users/${currentUser.uid}/bookmarks/${event.id}`);

    return true;
  } catch (error) {
    console.error('❌ Error bookmarking event:', error);
    throw error;
  }
}

/**
 * Remove bookmark (syncs with mobile app)
 */
export async function unbookmarkCalendarEvent(eventId) {
  const currentUser = auth.currentUser;
  if (!currentUser) {
    throw new Error('Not authenticated');
  }

  try {
    console.log('🗑️ Unbookmarking event:', eventId);

    // ✅ CORRECT COLLECTION PATH
    const bookmarkRef = doc(
      db,
      'users',
      currentUser.uid,
      'bookmarks',  // ✅ Must be 'bookmarks'
      eventId
    );

    await deleteDoc(bookmarkRef);

    console.log('✅ Bookmark removed from:', `users/${currentUser.uid}/bookmarks/${eventId}`);

    return true;
  } catch (error) {
    console.error('❌ Error unbookmarking event:', error);
    throw error;
  }
}

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

    const bookmarkSnap = await getDoc(bookmarkRef);
    return bookmarkSnap.exists();
  } catch (error) {
    console.error('❌ Error checking bookmark:', error);
    return false;
  }
}
```

---

## 🔍 Debug Your Current Website Code

### Step 1: Check Console Logs

When you bookmark on website, check browser console for:

```javascript
console.log('Saving bookmark to:', `users/${userId}/bookmarks/${eventId}`);
// OR
console.log('Saving bookmark to:', `users/${userId}/calendarBookmarks/${eventId}`);
```

**If you see `calendarBookmarks`** → That's the problem! Change it to `bookmarks`

### Step 2: Check Firebase Console

1. Go to Firebase Console → Firestore
2. Navigate to: `users` → `{your-user-id}`
3. Look for collections:
   - If you see `calendarBookmarks` → ❌ Wrong collection
   - Should be `bookmarks` → ✅ Correct

### Step 3: Check Field Names

Click on a bookmark document. It should have:
```
eventId: "event_123"          ✅
creatorId: "user_456"         ✅
title: "My Event"             ✅
startAt: Timestamp            ✅
notifyAt: Timestamp           ✅
notify: true                  ✅
createdAt: Timestamp          ✅
source: "website"             ✅
```

**If any field is missing or named differently** → Mobile app won't parse it!

---

## 🔧 Quick Fix Command

Find and replace in your website code:

```bash
# If using VS Code, search in all files:
Find: 'calendarBookmarks'
Replace: 'bookmarks'

# Then search for:
Find: bookmarkedAt
Replace: createdAt

# Ensure these fields exist:
- eventId ✅
- creatorId ✅  
- startAt ✅
- notifyAt ✅
- notify ✅
- createdAt ✅
```

---

## ✅ Testing Checklist

After fixing your website code:

- [ ] Website bookmarks write to `users/{uid}/bookmarks/`
- [ ] Bookmark has all required fields (eventId, creatorId, title, startAt, notifyAt, notify, createdAt, source)
- [ ] Field names match exactly (case-sensitive!)
- [ ] Check Firebase Console - bookmark appears in correct collection
- [ ] Open mobile app → Menu → Bookmarks
- [ ] Event appears in "Upcoming" tab
- [ ] Bookmark again from mobile
- [ ] Website should see it too (if you have website listener)

---

## 🚨 Common Mistakes

### ❌ Wrong Collection Name
```javascript
// WRONG
doc(db, 'users', userId, 'calendarBookmarks', eventId)

// CORRECT
doc(db, 'users', userId, 'bookmarks', eventId)
```

### ❌ Wrong Field Names
```javascript
// WRONG
{
  id: event.id,              // Should be 'eventId'
  userId: ownerId,           // Should be 'creatorId'
  date: timestamp,           // Should be 'startAt'
  bookmarkedAt: timestamp    // Should be 'createdAt'
}

// CORRECT
{
  eventId: event.id,
  creatorId: ownerId,
  startAt: timestamp,
  notifyAt: notifyTimestamp,
  notify: true,
  createdAt: serverTimestamp(),
  source: 'website'
}
```

### ❌ Missing Required Fields
```javascript
// WRONG - Missing fields
{
  eventId: event.id,
  title: event.title
  // ❌ Missing: creatorId, startAt, notifyAt, notify, createdAt
}

// CORRECT - All required fields
{
  eventId: event.id,
  creatorId: ownerId,
  title: event.title,
  startAt: Timestamp.fromDate(eventDate),
  notifyAt: Timestamp.fromDate(notifyDate),
  notify: true,
  createdAt: serverTimestamp(),
  source: 'website'
}
```

---

## 🎓 Understanding the Fields

| Field | Purpose | Example |
|-------|---------|---------|
| **eventId** | Unique event identifier | "event_1729468800000" |
| **creatorId** | User ID who owns the event | "user_abc123" |
| **title** | Event title | "Live Stream Session" |
| **startAt** | When event starts | Timestamp(2025-10-20 20:00) |
| **notifyAt** | When to notify user | Timestamp(2025-10-20 19:30) |
| **notify** | Enable notifications | true |
| **createdAt** | When bookmark was made | serverTimestamp() |
| **source** | Where bookmarked | "website" or "mobile" |

---

## 🔥 Expected Console Output

### When Bookmark Succeeds on Website

```
🔖 Bookmarking event: event_123
✅ Bookmark saved to: users/abc123/bookmarks/event_123
```

### When Mobile App Receives It

```
📡 EnhancedBookmarkService: Setting up real-time listener for user: abc123
📡 Received 1 bookmarks from Firestore
✅ Bookmarked events updated: 1
```

### In BookmarkView

```
📅 Upcoming event: "Live Stream Session"
⏰ Starts in: 2h 30m
🔔 Notifications: ON
```

---

## 🎯 Action Items

1. **Update website bookmark code** with exact field structure above
2. **Use collection path:** `users/{uid}/bookmarks/`
3. **Test bookmark creation** - Check Firebase Console
4. **Verify field names** match exactly
5. **Open mobile app** - Navigate to Bookmarks
6. **Should see your bookmarked event!** ✨

---

## 💡 Quick Test

Run this in your browser console (when logged into website):

```javascript
// Check what your website is writing
const testBookmark = {
  eventId: 'test123',
  creatorId: auth.currentUser.uid,
  title: 'Test Event',
  startAt: Timestamp.fromDate(new Date(Date.now() + 86400000)), // Tomorrow
  notifyAt: Timestamp.fromDate(new Date(Date.now() + 84600000)), // Tomorrow - 30min
  notify: true,
  createdAt: serverTimestamp(),
  source: 'website'
};

await setDoc(
  doc(db, 'users', auth.currentUser.uid, 'bookmarks', 'test123'),
  testBookmark
);

console.log('Test bookmark saved! Check mobile app.');
```

Then check your mobile app's BookmarkView → Upcoming tab!

---

## ✅ Summary

The key is:
1. **Use collection:** `bookmarks` (not `calendarBookmarks`)
2. **Use exact fields:** eventId, creatorId, title, startAt, notifyAt, notify, createdAt, source
3. **Field names are case-sensitive!**

Once your website writes the correct structure, the mobile app will pick it up instantly via real-time sync! 🚀

