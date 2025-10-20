# Calendar Event System - Quick Reference

## 🎯 At A Glance

### Profile Page Calendar Tab
**Purpose**: Users manage their own calendar events  
**Actions**: CREATE, EDIT, DELETE  
**Component**: `ProfileCalendarTab.jsx`

### Streamer Page Calendar Tab
**Purpose**: Visitors view streamer's calendar events  
**Actions**: VIEW only (+ Remind Me)  
**Component**: `StreamerCalendarTab.jsx`

---

## 📸 Visual Flow

```
┌─────────────────────────────────────────────────────────────┐
│                        WEBSITE                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────┐         ┌──────────────────┐        │
│  │  PROFILE PAGE    │         │  STREAMER PAGE   │        │
│  │                  │         │                  │        │
│  │  [Videos]        │         │  [Videos]        │        │
│  │  [Favorites]     │         │  [Favorites]     │        │
│  │  [📅 Calendar]   │         │  [📅 Calendar]   │        │
│  │                  │         │                  │        │
│  │  ┌────────────┐  │         │  ┌────────────┐  │        │
│  │  │+ Create    │  │         │  │  Event 1   │  │        │
│  │  │  Event     │  │         │  │  Upcoming  │  │        │
│  │  └────────────┘  │         │  └────────────┘  │        │
│  │                  │         │  ┌────────────┐  │        │
│  │  📅 Event 1      │         │  │  Event 2   │  │        │
│  │  ✏️ Edit 🗑️     │         │  │  Past      │  │        │
│  │                  │         │  └────────────┘  │        │
│  │  📅 Event 2      │         │                  │        │
│  │  ✏️ Edit 🗑️     │         │  (Read-only)     │        │
│  │                  │         │                  │        │
│  └──────────────────┘         └──────────────────┘        │
│           │                             │                  │
│           └──────────┬──────────────────┘                  │
│                      │                                     │
└──────────────────────┼─────────────────────────────────────┘
                       │
                       ▼
            ┌──────────────────┐
            │    FIRESTORE     │
            │                  │
            │  users/{userId}  │
            │  ├─ displayName  │
            │  ├─ avatarURL    │
            │  └─ calendarEvents: [
            │      {
            │        id: "123",
            │        title: "Live Stream",
            │        description: "...",
            │        date: Timestamp
            │      }
            │    ]              │
            └──────────────────┘
                       │
                       │ Real-time Sync ✨
                       ▼
            ┌──────────────────┐
            │   MOBILE APP     │
            │                  │
            │  ProfileBackView │
            │  ┌────────────┐  │
            │  │ 📅 Event 1 │  │
            │  │ 📅 Event 2 │  │
            │  └────────────┘  │
            │                  │
            │ StreamerCardView │
            │  ┌────────────┐  │
            │  │ 📅 Event 1 │  │
            │  │ 📅 Event 2 │  │
            │  └────────────┘  │
            └──────────────────┘
```

---

## 🔥 Key Features Comparison

| Feature | Profile Calendar Tab | Streamer Calendar Tab |
|---------|---------------------|----------------------|
| Create Event | ✅ Yes | ❌ No |
| Edit Event | ✅ Yes | ❌ No |
| Delete Event | ✅ Yes | ❌ No |
| View Events | ✅ Yes | ✅ Yes |
| Upcoming Badge | ✅ Yes | ✅ Yes |
| Past Events | ✅ Yes (dimmed) | ✅ Yes (dimmed) |
| Remind Me | 🔜 Coming Soon | 🔜 Coming Soon |
| Empty State | ✅ "Create your first event" | ✅ "No events scheduled" |

---

## 💾 Data Structure

### Event Object (JavaScript)

```javascript
{
  id: "1697123456789",              // Unique timestamp-based ID
  title: "Live Stream Session",     // Required, max 100 chars
  description: "Weekly Q&A",        // Optional, max 500 chars
  date: new Date("2025-10-20T20:00:00Z")  // JavaScript Date
}
```

### Event Object (Firestore)

```javascript
{
  id: "1697123456789",
  title: "Live Stream Session",
  description: "Weekly Q&A",
  date: Timestamp(2025-10-20T20:00:00Z)  // Firebase Timestamp
}
```

### Event Object (Mobile App - Dart)

```dart
CalendarEvent(
  id: "1697123456789",
  title: "Live Stream Session",
  description: "Weekly Q&A",
  date: DateTime.parse("2025-10-20T20:00:00Z")  // Dart DateTime
)
```

---

## 🎨 UI Components Breakdown

### Profile Calendar Tab

```
┌─────────────────────────────────────┐
│ My Calendar      [+ Create Event]   │  ← Header
├─────────────────────────────────────┤
│ Upcoming Events                     │  ← Section Title
│                                     │
│ ┌─────────────────────────────┐    │
│ │ 📅 │ Live Stream Session    │    │  ← Event Card
│ │ 20 │ Weekly Q&A and gameplay│    │
│ │OCT │ Tomorrow at 8:00 PM    │    │
│ │    │              ✏️ 🗑️     │    │
│ │    │ [Upcoming]              │    │
│ └─────────────────────────────┘    │
│                                     │
│ Past Events                         │
│                                     │
│ ┌─────────────────────────────┐    │
│ │ 📅 │ Previous Stream        │    │  ← Past Event (dimmed)
│ │ 15 │ ...                    │    │
│ │OCT │ Oct 15 at 8:00 PM      │    │
│ │    │              ✏️ 🗑️     │    │
│ └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

### Streamer Calendar Tab

```
┌─────────────────────────────────────┐
│ Upcoming Events                     │  ← Section Title
│                                     │
│ ┌─────────┐  ┌─────────┐          │  ← Grid Layout
│ │ 📅     │  │ 📅     │          │
│ │ 20 OCT │  │ 25 OCT │          │
│ │        │  │        │          │
│ │ Live   │  │ Charity│          │
│ │ Stream │  │ Stream │          │
│ │        │  │        │          │
│ │Tomorrow│  │Next Wed│          │
│ │at 8 PM │  │at 12 PM│          │
│ │        │  │        │          │
│ │[🔔 Remind  │ [🔔 Remind │         │
│ │  Me]   │  │  Me]   │          │
│ │[Upcoming]│  │[Upcoming]│          │
│ └─────────┘  └─────────┘          │
└─────────────────────────────────────┘
```

---

## ⚡ API Methods

### calendarEventService.js

```javascript
// GET all events for a user
const events = await getCalendarEvents(userId);
// Returns: Array<Event>

// CREATE a new event
const newEvent = await createCalendarEvent(userId, {
  title: "Live Stream",
  description: "Weekly Q&A",
  date: new Date("2025-10-20T20:00:00Z")
});
// Returns: Event

// UPDATE an existing event
const updatedEvent = await updateCalendarEvent(userId, eventId, {
  title: "Updated Title",
  description: "Updated description",
  date: new Date("2025-10-21T20:00:00Z")
});
// Returns: Event

// DELETE an event
await deleteCalendarEvent(userId, eventId);
// Returns: true

// HELPERS
const formatted = formatEventDate(event.date);
// Returns: "Tomorrow at 8:00 PM"

const isPast = isEventPast(event.date);
// Returns: true/false

const isUpcoming = isEventUpcoming(event.date);
// Returns: true/false (within 7 days)
```

---

## 🧪 Testing Scenarios

### Scenario 1: First-Time User
```
1. User opens profile page
2. Clicks "Calendar" tab
3. Sees empty state: "No Events Yet"
4. Clicks "Create Event" button
5. Fills form and saves
6. Event appears in "Upcoming Events" section
7. ✅ SUCCESS: Event created and displayed
```

### Scenario 2: Event Sync
```
1. User creates event on website
2. Within 100ms, event syncs to Firestore
3. Mobile app's listener detects change
4. Mobile app parses event with CalendarEvent.fromMap()
5. Mobile app updates ProfileBackView
6. ✅ SUCCESS: Event visible on mobile app
```

### Scenario 3: Visitor View
```
1. Visitor opens streamer's page
2. Clicks "Calendar" tab
3. Sees all streamer's events
4. Upcoming events have green "Upcoming" badge
5. No edit/delete buttons (read-only)
6. ✅ SUCCESS: Events displayed correctly
```

---

## 🐛 Debugging Checklist

### Events Not Showing?
- [ ] Check Firebase auth - are you logged in?
- [ ] Check browser console for errors
- [ ] Verify userId is correct
- [ ] Check Firestore document exists
- [ ] Verify `calendarEvents` array exists

### Events Not Syncing to Mobile?
- [ ] Check mobile app is logged in with same account
- [ ] Verify Firestore listeners are active
- [ ] Check network connection
- [ ] Verify Firebase config is correct
- [ ] Check Firestore security rules allow read

### Create Event Not Working?
- [ ] Check form validation passes
- [ ] Verify Firebase config is initialized
- [ ] Check Firestore security rules allow write
- [ ] Check browser console for errors
- [ ] Verify date is in correct format

### Date/Time Issues?
- [ ] Use `new Date()` in JavaScript
- [ ] Use `Timestamp.fromDate()` for Firestore
- [ ] Use `.toDate()` when reading from Firestore
- [ ] Check timezone settings

---

## 📋 Implementation Checklist

### Phase 1: Setup
- [ ] Create `src/services/calendarEventService.js`
- [ ] Create `src/components/ProfileCalendarTab.jsx`
- [ ] Create `src/components/ProfileCalendarTab.css`
- [ ] Create `src/components/StreamerCalendarTab.jsx`
- [ ] Create `src/components/StreamerCalendarTab.css`

### Phase 2: Integration
- [ ] Add Calendar tab to Profile page
- [ ] Add Calendar tab to Streamer page
- [ ] Test create event
- [ ] Test edit event
- [ ] Test delete event
- [ ] Test visitor view

### Phase 3: Testing
- [ ] Test sync with mobile app
- [ ] Test with no events (empty state)
- [ ] Test with past events
- [ ] Test with upcoming events
- [ ] Test form validation
- [ ] Test on different devices

### Phase 4: Polish
- [ ] Add loading states
- [ ] Add error handling
- [ ] Add success messages
- [ ] Optimize performance
- [ ] Add accessibility features
- [ ] Test responsive design

---

## 🎯 Success Criteria

✅ Users can create events on profile page  
✅ Users can edit their events  
✅ Users can delete their events  
✅ Visitors can view streamer events  
✅ Events sync to mobile app < 100ms  
✅ Upcoming events show green badge  
✅ Past events are dimmed  
✅ Empty state shows helpful message  
✅ Form validation works correctly  
✅ Responsive design works on all devices  

---

## 📞 Need Help?

Refer to these documents:
- **Full Implementation**: `WEBSITE_CALENDAR_EVENT_IMPLEMENTATION.md`
- **Complete Guide**: `CALENDAR_SYSTEM_COMPLETE_GUIDE.md`
- **This Quick Reference**: `CALENDAR_QUICK_REFERENCE.md`

Mobile app calendar is already implemented in:
- `lib/models/calendar_event.dart`
- `lib/widgets/profile_back_view.dart`
- `lib/widgets/streamer_card_view.dart`

---

**Last Updated**: October 16, 2025  
**Version**: 1.0  
**Status**: Ready to implement ✨

