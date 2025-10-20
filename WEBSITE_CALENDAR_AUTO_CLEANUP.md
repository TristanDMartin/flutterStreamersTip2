# Website Calendar Auto-Cleanup Implementation

## 🎯 Goal
Add the same 12-hour auto-deletion feature to the website calendar.

---

## Step 1: Update calendarEventService.js

Add cleanup function to `src/services/calendarEventService.js`:

```javascript
/**
 * Clean up expired calendar events (12+ hours past)
 * @param {string} userId - User ID
 * @returns {Promise<number>} Number of events deleted
 */
export async function cleanupExpiredEvents(userId) {
  try {
    console.log('🧹 Cleaning up expired calendar events...');
    
    // Get current events
    const events = await getCalendarEvents(userId);
    
    if (events.length === 0) {
      console.log('📅 No events to clean up');
      return 0;
    }
    
    // Calculate cutoff time (12 hours ago)
    const now = new Date();
    const cutoffTime = new Date(now.getTime() - (12 * 60 * 60 * 1000));
    
    // Find expired events
    const expiredEvents = events.filter(event => new Date(event.date) < cutoffTime);
    
    if (expiredEvents.length === 0) {
      console.log('✅ No expired events found');
      return 0;
    }
    
    console.log(`🗑️ Found ${expiredEvents.length} expired events to delete`);
    
    // Keep only non-expired events
    const remainingEvents = events.filter(event => new Date(event.date) >= cutoffTime);
    
    // Convert to Firestore format
    const eventsData = remainingEvents.map(e => ({
      id: e.id,
      title: e.title,
      description: e.description,
      date: Timestamp.fromDate(new Date(e.date))
    }));
    
    // Update Firestore
    const userRef = doc(db, 'users', userId);
    await updateDoc(userRef, {
      calendarEvents: eventsData,
      updatedAt: serverTimestamp()
    });
    
    // Log deleted events
    expiredEvents.forEach(event => {
      const hoursPast = Math.floor((now - new Date(event.date)) / (1000 * 60 * 60));
      console.log(`   • Deleted: "${event.title}" (${hoursPast}h past)`);
    });
    
    console.log(`✅ Deleted ${expiredEvents.length} expired events`);
    console.log(`📅 ${remainingEvents.length} events remaining`);
    
    return expiredEvents.length;
  } catch (error) {
    console.error('❌ Error cleaning up expired events:', error);
    throw error;
  }
}

/**
 * Check if an event is expired (12+ hours past)
 * @param {Date} eventDate - Event date
 * @returns {boolean} True if expired
 */
export function isEventExpired(eventDate) {
  const now = new Date();
  const cutoffTime = new Date(now.getTime() - (12 * 60 * 60 * 1000));
  return new Date(eventDate) < cutoffTime;
}
```

---

## Step 2: Update ProfileCalendarTab.jsx

Add cleanup on component mount:

```jsx
import {
  subscribeToCalendarEvents,
  createCalendarEvent,
  updateCalendarEvent,
  deleteCalendarEvent,
  cleanupExpiredEvents,  // ✨ ADD THIS
  formatEventDate,
  isEventPast,
  isEventUpcoming,
  isEventExpired  // ✨ ADD THIS
} from '../services/calendarEventService';

export function ProfileCalendarTab() {
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(true);
  const currentUser = auth.currentUser;
  
  useEffect(() => {
    if (!currentUser) {
      setLoading(false);
      return;
    }
    
    // ✨ RUN CLEANUP ON MOUNT
    runCleanup();
    
    // Set up real-time listener
    const unsubscribe = subscribeToCalendarEvents(
      currentUser.uid,
      (updatedEvents) => {
        setEvents(updatedEvents);
        setLoading(false);
      }
    );
    
    return () => unsubscribe();
  }, [currentUser]);
  
  // ✨ CLEANUP FUNCTION
  const runCleanup = async () => {
    try {
      const deletedCount = await cleanupExpiredEvents(currentUser.uid);
      if (deletedCount > 0) {
        console.log(`🧹 Cleaned up ${deletedCount} expired events`);
      }
    } catch (error) {
      console.error('❌ Cleanup error:', error);
      // Fail silently - don't block UI
    }
  };
  
  // Rest of component...
}
```

---

## Step 3: Update StreamerCalendarTab.jsx

Same cleanup for public streamer pages:

```jsx
export function StreamerCalendarTab({ userId }) {
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(true);
  
  useEffect(() => {
    if (!userId) {
      setLoading(false);
      return;
    }
    
    // ✨ RUN CLEANUP ON MOUNT (if viewing own profile)
    if (auth.currentUser && auth.currentUser.uid === userId) {
      runCleanup();
    }
    
    // Set up real-time listener
    const unsubscribe = subscribeToCalendarEvents(
      userId,
      (updatedEvents) => {
        setEvents(updatedEvents);
        setLoading(false);
      }
    );
    
    return () => unsubscribe();
  }, [userId]);
  
  // ✨ CLEANUP FUNCTION
  const runCleanup = async () => {
    try {
      await cleanupExpiredEvents(userId);
    } catch (error) {
      console.error('❌ Cleanup error:', error);
    }
  };
  
  // Rest of component...
}
```

---

## Step 4: Optional - Add Visual Indicator

Show "expires in X hours" for recent events:

```jsx
function EventCard({ event }) {
  const eventDate = new Date(event.date);
  const now = new Date();
  const hoursSinceEvent = Math.floor((now - eventDate) / (1000 * 60 * 60));
  const hoursUntilExpiry = 12 - hoursSinceEvent;
  
  const isPast = eventDate < now;
  const willExpireSoon = isPast && hoursUntilExpiry <= 2 && hoursUntilExpiry > 0;
  
  return (
    <div className={`event-card ${isPast ? 'past' : ''}`}>
      <div className="event-content">
        <h3>{event.title}</h3>
        <p>{event.description}</p>
        <p className="event-time">{formatEventDate(event.date)}</p>
        
        {/* ✨ EXPIRY WARNING */}
        {willExpireSoon && (
          <div className="expiry-warning">
            ⏰ Expires in {hoursUntilExpiry}h
          </div>
        )}
      </div>
    </div>
  );
}
```

**CSS:**
```css
.expiry-warning {
  display: inline-block;
  padding: 4px 8px;
  background: rgba(255, 152, 0, 0.2);
  border: 1px solid rgba(255, 152, 0, 0.4);
  border-radius: 12px;
  color: #ff9800;
  font-size: 12px;
  font-weight: 600;
  margin-top: 8px;
}
```

---

## Step 5: Optional - Add Automatic Periodic Cleanup

Run cleanup every hour while page is open:

```jsx
export function ProfileCalendarTab() {
  const [events, setEvents] = useState([]);
  const currentUser = auth.currentUser;
  
  useEffect(() => {
    if (!currentUser) return;
    
    // Initial cleanup
    runCleanup();
    
    // ✨ PERIODIC CLEANUP (every hour)
    const cleanupInterval = setInterval(() => {
      console.log('🔄 Running periodic cleanup...');
      runCleanup();
    }, 60 * 60 * 1000); // 1 hour
    
    // Real-time listener
    const unsubscribe = subscribeToCalendarEvents(
      currentUser.uid,
      setEvents
    );
    
    return () => {
      unsubscribe();
      clearInterval(cleanupInterval); // Clean up interval
    };
  }, [currentUser]);
  
  const runCleanup = async () => {
    try {
      await cleanupExpiredEvents(currentUser.uid);
    } catch (error) {
      console.error('❌ Cleanup error:', error);
    }
  };
  
  // Rest of component...
}
```

---

## 🧪 Testing on Website

### Test 1: Create Past Event
```javascript
// In browser console:
const pastEvent = {
  title: "Test Past Event",
  description: "Should be deleted",
  date: new Date(Date.now() - 13 * 60 * 60 * 1000) // 13 hours ago
};

await createCalendarEvent(userId, pastEvent);
// Refresh page → Event should be auto-deleted
```

### Test 2: Monitor Cleanup
```javascript
// Open Calendar tab
// Check console logs:
// 🧹 Cleaning up expired calendar events...
// 🗑️ Found 2 expired events to delete
// ✅ Deleted 2 expired events
```

### Test 3: Cross-Platform
1. Create event yesterday on mobile
2. Open website
3. ✅ Event should auto-delete when calendar loads

---

## 📊 Cleanup Triggers

| Trigger | When | Platform |
|---------|------|----------|
| **Component Mount** | User opens calendar tab | Website |
| **App Startup** | User opens app | Mobile |
| **Profile View** | User views calendar | Mobile |
| **Periodic** (optional) | Every 1 hour | Website |
| **Real-Time Sync** | After any cleanup | Both |

---

## ✅ Result

After implementing:

✅ Website calendar auto-cleans on load
✅ Mobile calendar auto-cleans on open
✅ 12-hour expiry window
✅ Real-time sync between platforms
✅ Optional visual indicators
✅ Optional periodic cleanup

**Users see clean, relevant calendars everywhere!** 🎉

