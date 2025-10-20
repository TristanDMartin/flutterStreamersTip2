# Calendar Auto-Cleanup Implementation 🧹

## 🎯 Feature

Calendar events automatically delete **12 hours after** their scheduled time. This keeps calendars clean and relevant, showing only current and upcoming events.

---

## ⏰ How It Works

### Deletion Rule

```
Event Time: 8:00 PM Today
Expiry Time: 8:00 AM Tomorrow (12 hours later)
Status: ✅ Visible until 8:00 AM, then auto-deleted
```

### Timeline Example

```
EVENT: "Live Stream" at 8:00 PM Monday
├─ 8:00 PM Mon → Event happens ✅
├─ 9:00 PM Mon → Still visible (1h after)
├─ 11:00 PM Mon → Still visible (3h after)
├─ 2:00 AM Tue → Still visible (6h after)
├─ 6:00 AM Tue → Still visible (10h after)
├─ 7:59 AM Tue → Still visible (11h 59m after)
└─ 8:00 AM Tue → AUTO-DELETED 🗑️ (12h after)
```

---

## 🛠️ Implementation

### 1. CalendarCleanupService

**File:** `lib/services/calendar_cleanup_service.dart`

```dart
class CalendarCleanupService {
  /// Delete events that are 12+ hours past their scheduled time
  Future<void> cleanupExpiredEvents(String userId) async {
    // Get user's calendar events
    final events = await _loadEvents(userId);
    
    // Find expired events (12+ hours past)
    final now = DateTime.now();
    final cutoffTime = now.subtract(const Duration(hours: 12));
    final expiredEvents = events.where((e) => e.date.isBefore(cutoffTime));
    
    // Keep only non-expired events
    final remainingEvents = events.where((e) => !e.date.isBefore(cutoffTime));
    
    // Update Firestore
    await _saveEvents(userId, remainingEvents);
  }
  
  /// Check if an event is expired
  bool isEventExpired(DateTime eventDate) {
    final cutoffTime = DateTime.now().subtract(const Duration(hours: 12));
    return eventDate.isBefore(cutoffTime);
  }
}
```

---

### 2. Automatic Triggers

Cleanup runs automatically in **three places**:

#### A. App Startup
**File:** `lib/widgets/app_startup_wrapper.dart`

```dart
void _startSplashCountdown() {
  // When splash screen finishes...
  if (_splashCountdown <= 0) {
    _runCalendarCleanup(); // 🧹 Auto-cleanup on app launch
  }
}

void _runCalendarCleanup() {
  final userId = authService.currentUser?.id;
  if (userId != null) {
    CalendarCleanupService().cleanupExpiredEvents(userId);
  }
}
```

**When:** Every time the app is opened

#### B. ProfileBackView
**File:** `lib/widgets/profile_back_view.dart`

```dart
@override
void initState() {
  super.initState();
  _setupRealtimeListener();
  _runCalendarCleanup(); // 🧹 Auto-cleanup when viewing calendar
}
```

**When:** User opens their profile and flips to calendar view

#### C. Real-Time Sync
**Automatic:** When events expire, any device viewing the calendar will see them disappear via Firestore real-time sync

---

## 📊 What Gets Deleted

### ✅ Events That Get Deleted

| Event Time | Current Time | Status |
|------------|-------------|--------|
| Yesterday 6:00 PM | Today 7:00 AM | ✅ Deleted (13h past) |
| Today 6:00 AM | Today 8:00 PM | ✅ Deleted (14h past) |
| 2 days ago | Today | ✅ Deleted (48h past) |

### ❌ Events That Stay

| Event Time | Current Time | Status |
|------------|-------------|--------|
| Today 8:00 PM | Today 9:00 PM | ❌ Keep (1h past) |
| Today 6:00 PM | Today 10:00 PM | ❌ Keep (4h past) |
| Tomorrow 8:00 PM | Today 8:00 PM | ❌ Keep (future) |
| In 1 week | Today | ❌ Keep (future) |

---

## 🔄 Cleanup Frequency

| Trigger | Frequency | Impact |
|---------|-----------|--------|
| **App Startup** | Every launch | Users see clean calendar on app open |
| **Profile View** | When viewing | Calendar cleaned before display |
| **Real-Time Sync** | Instant | Other devices see deletions immediately |

---

## 🧪 Testing Guide

### Test 1: Create Event in the Past

```dart
// Create test event 13 hours ago
final pastEvent = CalendarEvent(
  title: "Test Event",
  description: "Should be auto-deleted",
  date: DateTime.now().subtract(Duration(hours: 13)),
);

// Open app or profile
// ✅ Event should be deleted automatically
```

### Test 2: Event Just Expired

1. Create event for "Today at 8:00 PM"
2. Wait until tomorrow 8:01 AM (12h 1min later)
3. Open app
4. ✅ Event should be gone

### Test 3: Event Not Yet Expired

1. Create event for "Today at 8:00 PM"
2. Current time: Today at 11:00 PM (3h after)
3. Open app
4. ❌ Event should still be visible

### Test 4: Multiple Events

```
Events:
- Event A: Yesterday 6 PM (26h ago) ✅ Deleted
- Event B: Today 8 AM (14h ago) ✅ Deleted  
- Event C: Today 6 PM (2h ago) ❌ Keep
- Event D: Tomorrow 8 PM ❌ Keep

Result: Only C and D remain
```

### Test 5: Cross-Platform Cleanup

1. **On Mobile:** Create event "Test" for yesterday
2. **Close mobile app**
3. **Open website:** Event still visible
4. **Open mobile app:** Cleanup runs
5. **Check website:** ✨ Event disappears (real-time sync)

---

## 🎯 Benefits

### User Experience
✅ **Always relevant** - Only shows current/upcoming events
✅ **Automatic** - No manual cleanup needed
✅ **Consistent** - Works across all devices
✅ **12-hour buffer** - Events stay visible long enough

### Technical Benefits
✅ **Reduces storage** - Less data in Firestore
✅ **Faster loading** - Fewer events to parse
✅ **Better performance** - Smaller arrays to process
✅ **Clean data** - No stale events accumulating

---

## 🔧 Configuration

### Change Expiry Time

Want different timing? Modify the duration:

```dart
// Current: 12 hours
final cutoffTime = now.subtract(const Duration(hours: 12));

// Examples:
final cutoffTime = now.subtract(const Duration(hours: 24));  // 24h
final cutoffTime = now.subtract(const Duration(hours: 6));   // 6h
final cutoffTime = now.subtract(const Duration(days: 1));    // 1 day
final cutoffTime = now.subtract(const Duration(days: 7));    // 1 week
```

---

## 📝 Console Logs

When cleanup runs, you'll see:

```
🧹 CalendarCleanup: Checking for expired events...
🗑️ CalendarCleanup: Found 3 expired events to delete
   • Deleted: "Live Stream" (15h past scheduled time)
   • Deleted: "Q&A Session" (28h past scheduled time)
   • Deleted: "Gaming Night" (36h past scheduled time)
✅ CalendarCleanup: Deleted 3 expired events
📅 CalendarCleanup: 5 events remaining
✅ App startup: Calendar cleanup completed
```

---

## 🚨 Edge Cases Handled

### 1. No Events
```
🧹 CalendarCleanup: Checking for expired events...
📅 CalendarCleanup: No calendar events to clean
```

### 2. All Events Future
```
🧹 CalendarCleanup: Checking for expired events...
✅ CalendarCleanup: No expired events found
```

### 3. Parse Errors
```
❌ CalendarCleanup: Error parsing event: ...
// Skips bad event, continues cleanup
```

### 4. Firestore Error
```
❌ CalendarCleanup: Error cleaning up events: ...
// Fails gracefully, no data corruption
```

---

## 🔍 Data Safety

### Protection Against Data Loss

✅ **Fails safely** - If cleanup errors, old events stay
✅ **No cascade deletes** - Only affects calendar events
✅ **Audit trail** - All deletions logged
✅ **Recoverable** - Events stored until deleted

### What's NOT Deleted

❌ User profile data
❌ Videos
❌ Platforms
❌ Bio/hashtags
❌ Followers/following
❌ Any other user data

**Only** `calendarEvents` array is modified!

---

## 🎓 Best Practices

### For Users

1. **Don't rely on events as archives** - They auto-delete after 12h
2. **Create new events for recurring streams** - Old ones will be cleaned
3. **Check calendar regularly** - Cleanup happens automatically

### For Developers

1. **Test with past dates** - Ensure cleanup works
2. **Monitor console logs** - Watch for cleanup activity
3. **Adjust timing if needed** - 12h may not fit all use cases
4. **Consider notifications** - Remind users before deletion

---

## 📊 Expected Behavior

### Typical User Scenario

```
Monday:
- User creates "Stream at 8 PM Mon"
- Event visible on calendar ✅

Tuesday 7:00 AM:
- Event still visible (11h after) ✅
- User opens app → Cleanup runs
- Event still visible (< 12h) ✅

Tuesday 8:30 AM:
- User opens app → Cleanup runs
- Event deleted (12.5h after) 🗑️
- Calendar only shows upcoming events ✅
```

---

## ✅ Summary

Calendar events now **automatically delete 12 hours** after occurring:

| Trigger Point | When | Action |
|---------------|------|--------|
| App Startup | Every launch | Check & delete expired |
| Profile View | When viewing calendar | Check & delete expired |
| Real-Time Sync | When deleted on any device | Sync to all devices |

**Result:** Always clean, relevant calendars across all platforms! 🎉

