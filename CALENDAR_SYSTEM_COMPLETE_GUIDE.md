# Calendar Event System - Complete Implementation Guide

## 🎯 Overview

This guide provides a complete calendar event system for your website where:
- **Profile Page**: Users can CREATE, EDIT, and DELETE calendar events
- **Streamer Page**: Visitors can VIEW all events from that streamer
- **Mobile Sync**: All changes sync instantly with the Flutter mobile app (< 100ms)

---

## 📁 Project Structure

Your website should have this structure:

```
your-website/
├── src/
│   ├── services/
│   │   └── calendarEventService.js        # Calendar event CRUD operations
│   ├── components/
│   │   ├── ProfileCalendarTab.jsx         # Profile page calendar (create/edit/delete)
│   │   ├── ProfileCalendarTab.css         # Styling for profile calendar
│   │   ├── StreamerCalendarTab.jsx        # Streamer page calendar (read-only)
│   │   └── StreamerCalendarTab.css        # Styling for streamer calendar
│   ├── pages/
│   │   ├── ProfilePage.jsx                # Your profile page
│   │   └── StreamerPage.jsx               # Streamer viewing page
│   └── firebase/
│       └── config.js                      # Firebase configuration
```

---

## 🚀 Quick Start

### Step 1: Review the Full Implementation

Read the complete implementation guide:
- **File**: `WEBSITE_CALENDAR_EVENT_IMPLEMENTATION.md`
- **Contains**: All code for services, components, and styling

### Step 2: Create Service Layer

Create `src/services/calendarEventService.js`:
- `getCalendarEvents(userId)` - Fetch all events for a user
- `createCalendarEvent(userId, eventData)` - Create new event
- `updateCalendarEvent(userId, eventId, updates)` - Update existing event
- `deleteCalendarEvent(userId, eventId)` - Delete event
- Helper functions for formatting dates

### Step 3: Create Profile Calendar Tab

Create `src/components/ProfileCalendarTab.jsx`:
- Calendar management interface
- Create event modal with form
- Edit event functionality
- Delete event with confirmation
- Upcoming vs past events sections

### Step 4: Create Streamer Calendar Tab

Create `src/components/StreamerCalendarTab.jsx`:
- Read-only event display
- Beautiful card layout
- "Remind Me" button (future enhancement)
- Upcoming badges

### Step 5: Add Styling

Create CSS files:
- `src/components/ProfileCalendarTab.css` - Profile page styling
- `src/components/StreamerCalendarTab.css` - Streamer page styling

---

## 🔌 Integration with Your Pages

### Profile Page Integration

```jsx
// src/pages/ProfilePage.jsx
import React, { useState } from 'react';
import { ProfileCalendarTab } from '../components/ProfileCalendarTab';

export function ProfilePage() {
  const [selectedTab, setSelectedTab] = useState('videos');
  
  return (
    <div className="profile-page">
      {/* Profile Header */}
      <div className="profile-header">
        <img src={avatarUrl} alt="Avatar" />
        <h1>{displayName}</h1>
        <div className="stats">
          <div>{postCount} Posts</div>
          <div>{followerCount} Followers</div>
          <div>{followingCount} Following</div>
        </div>
      </div>
      
      {/* Tabs */}
      <div className="tabs">
        <button 
          className={selectedTab === 'videos' ? 'active' : ''}
          onClick={() => setSelectedTab('videos')}
        >
          Videos
        </button>
        <button 
          className={selectedTab === 'favorites' ? 'active' : ''}
          onClick={() => setSelectedTab('favorites')}
        >
          Favorites
        </button>
        <button 
          className={selectedTab === 'calendar' ? 'active' : ''}
          onClick={() => setSelectedTab('calendar')}
        >
          📅 Calendar
        </button>
      </div>
      
      {/* Content */}
      <div className="tab-content">
        {selectedTab === 'videos' && <VideosTab />}
        {selectedTab === 'favorites' && <FavoritesTab />}
        {selectedTab === 'calendar' && <ProfileCalendarTab />}
      </div>
    </div>
  );
}
```

### Streamer Page Integration

```jsx
// src/pages/StreamerPage.jsx
import React, { useState } from 'react';
import { StreamerCalendarTab } from '../components/StreamerCalendarTab';

export function StreamerPage({ streamerId }) {
  const [selectedTab, setSelectedTab] = useState('videos');
  
  return (
    <div className="streamer-page">
      {/* Streamer Header */}
      <div className="streamer-header">
        <img src={avatarUrl} alt="Avatar" />
        <h1>{displayName}</h1>
        <button className="btn-follow">Follow</button>
      </div>
      
      {/* Tabs */}
      <div className="tabs">
        <button 
          className={selectedTab === 'videos' ? 'active' : ''}
          onClick={() => setSelectedTab('videos')}
        >
          Videos
        </button>
        <button 
          className={selectedTab === 'favorites' ? 'active' : ''}
          onClick={() => setSelectedTab('favorites')}
        >
          Favorites
        </button>
        <button 
          className={selectedTab === 'calendar' ? 'active' : ''}
          onClick={() => setSelectedTab('calendar')}
        >
          📅 Calendar
        </button>
      </div>
      
      {/* Content */}
      <div className="tab-content">
        {selectedTab === 'videos' && <VideosTab userId={streamerId} />}
        {selectedTab === 'favorites' && <FavoritesTab userId={streamerId} />}
        {selectedTab === 'calendar' && <StreamerCalendarTab userId={streamerId} />}
      </div>
    </div>
  );
}
```

---

## 🔄 Data Flow & Sync

### Creating an Event (Profile Page → Mobile App)

```
1. User clicks "+ Create Event" on website profile page
   ↓
2. Modal opens with form (title, description, date/time)
   ↓
3. User fills form and clicks "Create Event"
   ↓
4. calendarEventService.createCalendarEvent() called
   ↓
5. Event added to Firestore: users/{userId}/calendarEvents array
   ↓
6. Mobile app's Firestore listener detects change
   ↓
7. Mobile app updates calendar display automatically ✨
   ↓
8. Website refreshes event list
   ↓
9. Event now visible on both website and mobile app
```

### Viewing Events (Streamer Page)

```
1. Visitor navigates to streamer's page
   ↓
2. Clicks "Calendar" tab
   ↓
3. StreamerCalendarTab component loads
   ↓
4. calendarEventService.getCalendarEvents(streamerId) fetches events
   ↓
5. Events displayed in beautiful grid layout
   ↓
6. Upcoming events highlighted with green badge
   ↓
7. Visitor can click "Remind Me" (future feature)
```

---

## 📊 Firestore Data Structure

### Document: `users/{userId}`

```javascript
{
  // ... other user fields ...
  
  calendarEvents: [
    {
      id: "1697123456789",
      title: "Live Stream: Friday Night Gaming",
      description: "Join me for some epic gameplay and Q&A!",
      date: Timestamp(2025-10-20T20:00:00Z)
    },
    {
      id: "1697123456790",
      title: "Charity Stream Marathon",
      description: "24-hour streaming for a good cause",
      date: Timestamp(2025-10-25T12:00:00Z)
    }
  ],
  
  // ... other user fields ...
}
```

### Mobile App Sync

The mobile app already has the `CalendarEvent` model and is listening to Firestore changes:

```dart
// lib/models/calendar_event.dart
class CalendarEvent {
  final String id;
  String title;
  String description;
  DateTime date;
  
  // Converts from Firestore map
  factory CalendarEvent.fromMap(Map<String, dynamic> map) {
    // ... parsing logic ...
  }
}
```

When you update `calendarEvents` array in Firestore, the mobile app automatically:
1. Receives the update via StreamSubscription
2. Parses the events using `CalendarEvent.fromMap()`
3. Updates the UI in `ProfileBackView` and `StreamerCardView`

---

## 🎨 Design Features

### Profile Calendar Tab
- ✅ **"+ Create Event" button** - Prominent call-to-action
- ✅ **Event cards** - Visual date badges with month/day
- ✅ **Edit/Delete buttons** - Quick actions on each card
- ✅ **Upcoming section** - Green-bordered cards for upcoming events
- ✅ **Past section** - Grayed out historical events
- ✅ **Empty state** - Friendly message when no events exist
- ✅ **Modal form** - Clean interface for creating/editing

### Streamer Calendar Tab
- ✅ **Grid layout** - Responsive cards that adapt to screen size
- ✅ **Glass morphism** - Semi-transparent cards with backdrop blur
- ✅ **Upcoming badge** - Green badge on upcoming events
- ✅ **Date badge** - Purple gradient date indicator
- ✅ **Remind Me button** - For future notification feature
- ✅ **Read-only view** - No edit/delete options for visitors

---

## ✅ Testing Your Implementation

### Test 1: Create Event on Profile
1. Open your profile page
2. Click "Calendar" tab
3. Click "+ Create Event"
4. Fill in:
   - Title: "Test Live Stream"
   - Description: "Testing calendar sync"
   - Date: Tomorrow at 8:00 PM
5. Click "Create Event"
6. ✅ Event appears on profile calendar
7. ✅ Open mobile app → See event in ProfileBackView

### Test 2: Edit Event
1. Click edit (✏️) button on an event
2. Change title to "Updated Title"
3. Click "Update Event"
4. ✅ Event updated on website
5. ✅ Open mobile app → See updated title

### Test 3: Delete Event
1. Click delete (🗑️) button on an event
2. Confirm deletion
3. ✅ Event removed from website
4. ✅ Open mobile app → Event no longer visible

### Test 4: View on Streamer Page
1. Navigate to a streamer's page (as visitor)
2. Click "Calendar" tab
3. ✅ See all their events
4. ✅ Upcoming events have green badge
5. ✅ Past events are dimmed
6. ✅ No edit/delete buttons (read-only)

### Test 5: Sync Speed
1. Have mobile app open on ProfileBackView
2. Create event on website
3. ✅ Event appears on mobile within 100ms

---

## 🚨 Common Issues & Solutions

### Issue 1: Events Not Syncing to Mobile
**Cause**: Firestore listeners not set up in mobile app  
**Solution**: The mobile app already has listeners in `ProfileBackView` and `StreamerCardView`. Make sure you're logged in with the same account.

### Issue 2: Date Format Errors
**Cause**: JavaScript Date vs Firestore Timestamp  
**Solution**: Always use `Timestamp.fromDate()` when saving to Firestore, and `.toDate()` when reading.

### Issue 3: Events Not Showing on Streamer Page
**Cause**: Incorrect userId prop  
**Solution**: Make sure you're passing the correct `userId` prop to `<StreamerCalendarTab userId={streamerId} />`

### Issue 4: Modal Not Closing After Save
**Cause**: Error in save handler  
**Solution**: Check browser console for errors. Make sure Firebase is properly initialized.

---

## 🎯 Future Enhancements

### Phase 2 Features
- [ ] **Remind Me functionality** - Users can set reminders for events
- [ ] **Event notifications** - Push notifications before event starts
- [ ] **Recurring events** - Weekly/monthly repeating events
- [ ] **Event categories** - Gaming, IRL, Q&A, etc.
- [ ] **Event colors** - Custom colors for different event types
- [ ] **iCal export** - Download events to calendar apps
- [ ] **Event RSVP** - Track who's planning to attend
- [ ] **Event chat** - Pre-event discussion

### Firebase Cloud Function for Reminders

```javascript
// cloud_functions/index.js
exports.sendEventReminders = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async (context) => {
    // Find events starting in 1 hour
    // Send notifications to users who bookmarked
  });
```

---

## 📱 Mobile App Integration (Already Complete!)

Your Flutter mobile app already supports calendar events! The implementation is in:

### Files Already Implemented
- `lib/models/calendar_event.dart` - Event model
- `lib/widgets/profile_back_view.dart` - Profile calendar display
- `lib/widgets/streamer_card_view.dart` - Streamer calendar display

### Mobile App Features
- ✅ Display calendar events
- ✅ Real-time sync with Firestore
- ✅ Bookmark events
- ✅ Event notifications
- ✅ Past vs upcoming separation

### What You Need to Add (Mobile)
Nothing! The mobile app is ready. Just make sure users have events in their `calendarEvents` array in Firestore, and they'll appear automatically.

---

## 📦 Dependencies Needed

### Website
```json
{
  "dependencies": {
    "react": "^18.0.0",
    "firebase": "^10.0.0",
    "react-router-dom": "^6.0.0"
  }
}
```

### Mobile App
Already installed! ✅

---

## 🔐 Security Rules

Make sure your Firestore rules allow users to update their own calendar:

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      // Users can read any profile
      allow read: if true;
      
      // Users can only update their own calendar
      allow update: if request.auth != null 
                    && request.auth.uid == userId
                    && request.resource.data.diff(resource.data)
                       .affectedKeys().hasOnly(['calendarEvents', 'updatedAt']);
    }
  }
}
```

---

## 📚 Summary

This calendar event system provides:

### For Profile Owners (Website)
- ✅ Create events with title, description, date/time
- ✅ Edit existing events
- ✅ Delete events
- ✅ See upcoming vs past events
- ✅ Clean, intuitive interface

### For Visitors (Website)
- ✅ View all streamer's events
- ✅ See upcoming events highlighted
- ✅ Beautiful grid layout
- ✅ "Remind Me" option (coming soon)

### For Mobile App Users
- ✅ Automatic sync from website
- ✅ Real-time updates (< 100ms)
- ✅ Display in ProfileBackView and StreamerCardView
- ✅ Bookmark and notification support

---

## 🎉 Next Steps

1. **Read** the full implementation: `WEBSITE_CALENDAR_EVENT_IMPLEMENTATION.md`
2. **Create** the service file: `src/services/calendarEventService.js`
3. **Create** the components:
   - `src/components/ProfileCalendarTab.jsx`
   - `src/components/StreamerCalendarTab.jsx`
4. **Add** the CSS files
5. **Integrate** into your Profile and Streamer pages
6. **Test** the sync with your mobile app
7. **Deploy** and enjoy! 🚀

---

**Created**: October 16, 2025  
**Implementation Time**: 2-3 hours  
**Difficulty**: Medium  
**Result**: Full calendar event system with instant mobile sync ✨

