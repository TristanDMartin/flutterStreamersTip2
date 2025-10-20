# Bookmark Collection Mismatch - CRITICAL FIX 🚨

## ⚠️ Problem Identified

Your website and mobile app are writing to **DIFFERENT Firestore collections**!

---

## 📊 Collection Name Mismatch

### Mobile App Uses:
```
users/{userId}/bookmarks/
```

### Documentation Says Website Should Use:
```
users/{userId}/calendarBookmarks/
```

**Result:** They're in different places = No sync! ❌

---

## 🔍 How to Check

### Step 1: Open Firebase Console

1. Go to: https://console.firebase.google.com
2. Select your project
3. Click "Firestore Database"
4. Navigate to `users` → `{your-user-id}`

### Step 2: Look for Collections

You'll see one or both of these:
- `bookmarks/` - Used by mobile app
- `calendarBookmarks/` - May be used by website

### Step 3: Check the Data

Click on each bookmark document and look for:
```javascript
{
  eventId: "event123",
  title: "My Event",
  source: "mobile" or "website"  // This tells you where it came from
}
```

---

## ✅ Fix Option 1: Make Website Match Mobile (RECOMMENDED)

Update your website to use `bookmarks` instead of `calendarBookmarks`:

### Website Code Fix

**In your website's bookmark service:**

```javascript
// CHANGE THIS:
const bookmarkRef = doc(
  db,
  'users',
  userId,
  'calendarBookmarks',  // ❌ WRONG
  eventId
);

// TO THIS:
const bookmarkRef = doc(
  db,
  'users',
  userId,
  'bookmarks',  // ✅ CORRECT - matches mobile
  eventId
);
```

**Search and replace in your website code:**
- Find: `'calendarBookmarks'`
- Replace with: `'bookmarks'`

---

## ✅ Fix Option 2: Make Mobile Match Website

Update mobile app to use `calendarBookmarks`:

```dart
// In lib/services/enhanced_bookmark_service.dart
// Line 120 - Change:
.collection('bookmarks')  // ❌ WRONG

// To:
.collection('calendarBookmarks')  // ✅ CORRECT - matches website
```

**And update all occurrences (6 places in the file)**

---

## 🎯 Recommended Solution

**Use `bookmarks` everywhere** (Option 1)

Why?
- ✅ Mobile app already uses it
- ✅ Less code to change
- ✅ Existing mobile bookmarks won't break
- ✅ Just update website code

---

## 🧪 Test After Fix

1. **Clear Firebase data** (optional, for clean test)
   ```
   Delete both collections in Firebase Console
   ```

2. **Bookmark on website**
   - Should write to `users/{uid}/bookmarks/`

3. **Check mobile app**
   - Open Menu → Bookmarks
   - ✨ Should see the event!

4. **Bookmark on mobile**
   - Tap bookmark icon

5. **Check website**
   - ✨ Should see it appear!

---

## 📝 Quick Checklist

To verify the fix:

- [ ] Both mobile and website use SAME collection name
- [ ] Check Firebase Console - bookmarks appearing in correct location
- [ ] Test website → mobile sync
- [ ] Test mobile → website sync
- [ ] Console logs show "Received X bookmarks"

---

## 🔧 Website Code Locations to Update

Search for `calendarBookmarks` in these files and replace with `bookmarks`:

1. `src/services/calendarBookmarkService.js`
2. `src/components/ProfileCalendarTab.jsx`
3. `src/components/StreamerCalendarTab.jsx`
4. `src/components/CalendarBookmarksView.jsx`
5. Any other files using bookmarks

**Use Find & Replace:**
- Find: `calendarBookmarks`
- Replace: `bookmarks`

---

## ✅ Expected Result

After fixing collection names:

```
WEBSITE                    FIRESTORE                MOBILE APP
   ↓                          ↓                         ↓
Bookmark event    →    users/{uid}/         →    Listener fires
                         bookmarks/               
                       (SAME LOCATION!)              ↓
                                                 Appears in
                                                 BookmarkView!
```

---

## 🚀 Once Fixed

Bookmarks will sync **instantly**:
- Website → Mobile: < 1 second ✅
- Mobile → Website: < 1 second ✅
- No refresh needed ✅
- Perfect bidirectional sync ✅

---

## 💡 Pro Tip

After fixing, test with Firebase Console open:
1. Bookmark something on website
2. **Immediately check Firebase Console**
3. Verify it appears in `users/{your-uid}/bookmarks/`
4. Then check mobile app

This helps you see exactly where data is being written!

