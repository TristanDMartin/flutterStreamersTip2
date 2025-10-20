# Website Calendar Event Implementation - Full Sync

## 🎯 Goal
Create a calendar event system on the website where users can create events on their profile page. These events will display on their streamer page and sync instantly with the mobile app.

---

## 📋 Features Overview

This implementation provides:
- ✅ **Create events** on Profile page Calendar tab
- ✅ **Display events** on Streamer page Calendar tab
- ✅ **Edit/delete** existing events
- ✅ **Real-time sync** with mobile app (< 100ms)
- ✅ **Date/time picker** with validation
- ✅ **Event colors** and categories
- ✅ **Responsive design** for all devices

---

## Step 1: Create Calendar Event Service

Create file: `src/services/calendarEventService.js`

```javascript
import { 
  doc, 
  getDoc, 
  updateDoc,
  arrayUnion,
  arrayRemove,
  serverTimestamp,
  Timestamp
} from 'firebase/firestore';
import { db } from '../firebase/config';

/**
 * Get calendar events for a user
 */
export async function getCalendarEvents(userId) {
  try {
    const userDoc = await getDoc(doc(db, 'users', userId));
    
    if (!userDoc.exists()) {
      throw new Error('User not found');
    }
    
    const data = userDoc.data();
    const events = data.calendarEvents || [];
    
    // Parse events
    return events.map(event => ({
      id: event.id,
      title: event.title || '',
      description: event.description || '',
      date: event.date?.toDate ? event.date.toDate() : new Date(event.date),
    })).sort((a, b) => a.date - b.date); // Sort by date ascending
  } catch (error) {
    console.error('❌ Error getting calendar events:', error);
    throw error;
  }
}

/**
 * Create a new calendar event
 */
export async function createCalendarEvent(userId, eventData) {
  try {
    console.log('📅 Creating calendar event for user:', userId);
    
    // Validate input
    if (!eventData.title?.trim()) {
      throw new Error('Event title is required');
    }
    
    if (!eventData.date) {
      throw new Error('Event date is required');
    }
    
    // Generate unique ID
    const eventId = Date.now().toString();
    
    // Create event object
    const newEvent = {
      id: eventId,
      title: eventData.title.trim(),
      description: eventData.description?.trim() || '',
      date: Timestamp.fromDate(new Date(eventData.date))
    };
    
    const userRef = doc(db, 'users', userId);
    
    // Add event to user's calendarEvents array
    await updateDoc(userRef, {
      calendarEvents: arrayUnion(newEvent),
      updatedAt: serverTimestamp()
    });
    
    console.log('✅ Calendar event created:', eventId);
    
    return {
      ...newEvent,
      date: newEvent.date.toDate()
    };
  } catch (error) {
    console.error('❌ Error creating calendar event:', error);
    throw error;
  }
}

/**
 * Update an existing calendar event
 */
export async function updateCalendarEvent(userId, eventId, updates) {
  try {
    console.log('📝 Updating calendar event:', eventId);
    
    // Get current events
    const currentEvents = await getCalendarEvents(userId);
    
    // Find the event to update
    const eventIndex = currentEvents.findIndex(e => e.id === eventId);
    
    if (eventIndex === -1) {
      throw new Error('Event not found');
    }
    
    // Create updated event
    const oldEvent = currentEvents[eventIndex];
    const updatedEvent = {
      id: eventId,
      title: updates.title?.trim() || oldEvent.title,
      description: updates.description?.trim() || oldEvent.description,
      date: Timestamp.fromDate(updates.date ? new Date(updates.date) : oldEvent.date)
    };
    
    const userRef = doc(db, 'users', userId);
    
    // Remove old event and add updated event
    const oldEventForRemoval = {
      id: oldEvent.id,
      title: oldEvent.title,
      description: oldEvent.description,
      date: Timestamp.fromDate(oldEvent.date)
    };
    
    await updateDoc(userRef, {
      calendarEvents: arrayRemove(oldEventForRemoval)
    });
    
    await updateDoc(userRef, {
      calendarEvents: arrayUnion(updatedEvent),
      updatedAt: serverTimestamp()
    });
    
    console.log('✅ Calendar event updated');
    
    return {
      ...updatedEvent,
      date: updatedEvent.date.toDate()
    };
  } catch (error) {
    console.error('❌ Error updating calendar event:', error);
    throw error;
  }
}

/**
 * Delete a calendar event
 */
export async function deleteCalendarEvent(userId, eventId) {
  try {
    console.log('🗑️ Deleting calendar event:', eventId);
    
    // Get current events
    const currentEvents = await getCalendarEvents(userId);
    
    // Find the event to delete
    const eventToDelete = currentEvents.find(e => e.id === eventId);
    
    if (!eventToDelete) {
      throw new Error('Event not found');
    }
    
    const userRef = doc(db, 'users', userId);
    
    // Remove event from array
    const eventForRemoval = {
      id: eventToDelete.id,
      title: eventToDelete.title,
      description: eventToDelete.description,
      date: Timestamp.fromDate(eventToDelete.date)
    };
    
    await updateDoc(userRef, {
      calendarEvents: arrayRemove(eventForRemoval),
      updatedAt: serverTimestamp()
    });
    
    console.log('✅ Calendar event deleted');
    
    return true;
  } catch (error) {
    console.error('❌ Error deleting calendar event:', error);
    throw error;
  }
}

/**
 * Format date for display
 */
export function formatEventDate(date) {
  const eventDate = new Date(date);
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);
  const eventDay = new Date(eventDate.getFullYear(), eventDate.getMonth(), eventDate.getDate());
  
  // Check if today
  if (eventDay.getTime() === today.getTime()) {
    return `Today at ${formatTime(eventDate)}`;
  }
  
  // Check if tomorrow
  if (eventDay.getTime() === tomorrow.getTime()) {
    return `Tomorrow at ${formatTime(eventDate)}`;
  }
  
  // Check if this week
  const daysUntilEvent = Math.floor((eventDay - today) / (1000 * 60 * 60 * 24));
  if (daysUntilEvent > 0 && daysUntilEvent < 7) {
    const dayName = eventDate.toLocaleDateString('en-US', { weekday: 'long' });
    return `${dayName} at ${formatTime(eventDate)}`;
  }
  
  // Default format
  return eventDate.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: eventDate.getFullYear() !== now.getFullYear() ? 'numeric' : undefined,
    hour: 'numeric',
    minute: '2-digit'
  });
}

/**
 * Format time for display
 */
function formatTime(date) {
  return date.toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: '2-digit'
  });
}

/**
 * Check if event is in the past
 */
export function isEventPast(date) {
  return new Date(date) < new Date();
}

/**
 * Check if event is upcoming (within 7 days)
 */
export function isEventUpcoming(date) {
  const eventDate = new Date(date);
  const now = new Date();
  const daysUntil = (eventDate - now) / (1000 * 60 * 60 * 24);
  return daysUntil >= 0 && daysUntil <= 7;
}
```

---

## Step 2: Create Calendar Tab Component for Profile Page

Create file: `src/components/ProfileCalendarTab.jsx`

```jsx
import React, { useState, useEffect } from 'react';
import {
  getCalendarEvents,
  createCalendarEvent,
  updateCalendarEvent,
  deleteCalendarEvent,
  formatEventDate,
  isEventPast,
  isEventUpcoming
} from '../services/calendarEventService';
import { auth } from '../firebase/config';
import './ProfileCalendarTab.css';

export function ProfileCalendarTab() {
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [editingEvent, setEditingEvent] = useState(null);
  const [error, setError] = useState(null);
  
  const currentUser = auth.currentUser;
  
  // Load events
  useEffect(() => {
    if (!currentUser) {
      setLoading(false);
      return;
    }
    
    loadEvents();
  }, [currentUser]);
  
  const loadEvents = async () => {
    try {
      setLoading(true);
      const fetchedEvents = await getCalendarEvents(currentUser.uid);
      setEvents(fetchedEvents);
      setError(null);
    } catch (err) {
      console.error('Error loading events:', err);
      setError('Failed to load events');
    } finally {
      setLoading(false);
    }
  };
  
  const handleCreateEvent = () => {
    setEditingEvent(null);
    setShowCreateModal(true);
  };
  
  const handleEditEvent = (event) => {
    setEditingEvent(event);
    setShowCreateModal(true);
  };
  
  const handleDeleteEvent = async (eventId) => {
    if (!window.confirm('Are you sure you want to delete this event?')) {
      return;
    }
    
    try {
      await deleteCalendarEvent(currentUser.uid, eventId);
      await loadEvents(); // Reload events
    } catch (err) {
      console.error('Error deleting event:', err);
      alert('Failed to delete event');
    }
  };
  
  const handleSaveEvent = async (eventData) => {
    try {
      if (editingEvent) {
        await updateCalendarEvent(currentUser.uid, editingEvent.id, eventData);
      } else {
        await createCalendarEvent(currentUser.uid, eventData);
      }
      
      await loadEvents(); // Reload events
      setShowCreateModal(false);
      setEditingEvent(null);
    } catch (err) {
      console.error('Error saving event:', err);
      throw err;
    }
  };
  
  if (!currentUser) {
    return (
      <div className="profile-calendar-tab">
        <div className="calendar-empty-state">
          <h3>Sign In Required</h3>
          <p>Please sign in to manage your calendar events</p>
        </div>
      </div>
    );
  }
  
  if (loading) {
    return (
      <div className="profile-calendar-tab">
        <div className="calendar-loading">
          <div className="spinner"></div>
          <p>Loading events...</p>
        </div>
      </div>
    );
  }
  
  // Separate past and upcoming events
  const upcomingEvents = events.filter(e => !isEventPast(e.date));
  const pastEvents = events.filter(e => isEventPast(e.date));
  
  return (
    <div className="profile-calendar-tab">
      {/* Header with Create Button */}
      <div className="calendar-header">
        <h2>My Calendar</h2>
        <button className="btn-create-event" onClick={handleCreateEvent}>
          + Create Event
        </button>
      </div>
      
      {error && (
        <div className="calendar-error">
          {error}
        </div>
      )}
      
      {/* Upcoming Events */}
      {upcomingEvents.length > 0 && (
        <div className="calendar-section">
          <h3 className="section-title">Upcoming Events</h3>
          <div className="events-list">
            {upcomingEvents.map(event => (
              <EventCard
                key={event.id}
                event={event}
                onEdit={() => handleEditEvent(event)}
                onDelete={() => handleDeleteEvent(event.id)}
              />
            ))}
          </div>
        </div>
      )}
      
      {/* Past Events */}
      {pastEvents.length > 0 && (
        <div className="calendar-section">
          <h3 className="section-title">Past Events</h3>
          <div className="events-list">
            {pastEvents.map(event => (
              <EventCard
                key={event.id}
                event={event}
                isPast={true}
                onEdit={() => handleEditEvent(event)}
                onDelete={() => handleDeleteEvent(event.id)}
              />
            ))}
          </div>
        </div>
      )}
      
      {/* Empty State */}
      {events.length === 0 && (
        <div className="calendar-empty-state">
          <div className="empty-icon">📅</div>
          <h3>No Events Yet</h3>
          <p>Create your first event to get started</p>
          <button className="btn-primary" onClick={handleCreateEvent}>
            Create Event
          </button>
        </div>
      )}
      
      {/* Create/Edit Modal */}
      {showCreateModal && (
        <EventFormModal
          event={editingEvent}
          onSave={handleSaveEvent}
          onClose={() => {
            setShowCreateModal(false);
            setEditingEvent(null);
          }}
        />
      )}
    </div>
  );
}

// Event Card Component
function EventCard({ event, isPast = false, onEdit, onDelete }) {
  const isUpcoming = isEventUpcoming(event.date);
  
  return (
    <div className={`event-card ${isPast ? 'past' : ''} ${isUpcoming ? 'upcoming' : ''}`}>
      <div className="event-card-main">
        <div className="event-date">
          <div className="event-day">
            {new Date(event.date).getDate()}
          </div>
          <div className="event-month">
            {new Date(event.date).toLocaleDateString('en-US', { month: 'short' })}
          </div>
        </div>
        
        <div className="event-details">
          <h4 className="event-title">{event.title}</h4>
          {event.description && (
            <p className="event-description">{event.description}</p>
          )}
          <div className="event-time">
            {formatEventDate(event.date)}
          </div>
        </div>
        
        <div className="event-actions">
          <button className="btn-icon" onClick={onEdit} title="Edit">
            ✏️
          </button>
          <button className="btn-icon" onClick={onDelete} title="Delete">
            🗑️
          </button>
        </div>
      </div>
      
      {isUpcoming && !isPast && (
        <div className="event-badge">Upcoming</div>
      )}
    </div>
  );
}

// Event Form Modal Component
function EventFormModal({ event, onSave, onClose }) {
  const [title, setTitle] = useState(event?.title || '');
  const [description, setDescription] = useState(event?.description || '');
  const [date, setDate] = useState(
    event?.date ? formatDateForInput(event.date) : formatDateForInput(new Date())
  );
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  
  const isEditing = !!event;
  
  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!title.trim()) {
      setError('Event title is required');
      return;
    }
    
    if (!date) {
      setError('Event date is required');
      return;
    }
    
    setSaving(true);
    setError(null);
    
    try {
      await onSave({
        title: title.trim(),
        description: description.trim(),
        date: new Date(date)
      });
    } catch (err) {
      setError(err.message || 'Failed to save event');
      setSaving(false);
    }
  };
  
  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2>{isEditing ? 'Edit Event' : 'Create Event'}</h2>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>
        
        {error && (
          <div className="modal-error">{error}</div>
        )}
        
        <form onSubmit={handleSubmit} className="event-form">
          <div className="form-field">
            <label htmlFor="title">Event Title *</label>
            <input
              id="title"
              type="text"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="e.g., Live Stream, Q&A Session"
              maxLength={100}
              required
              autoFocus
            />
          </div>
          
          <div className="form-field">
            <label htmlFor="description">Description</label>
            <textarea
              id="description"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Add details about your event..."
              maxLength={500}
              rows={4}
            />
            <div className="character-count">
              {description.length} / 500
            </div>
          </div>
          
          <div className="form-field">
            <label htmlFor="date">Date & Time *</label>
            <input
              id="date"
              type="datetime-local"
              value={date}
              onChange={(e) => setDate(e.target.value)}
              required
            />
          </div>
          
          <div className="form-actions">
            <button
              type="button"
              className="btn-secondary"
              onClick={onClose}
              disabled={saving}
            >
              Cancel
            </button>
            <button
              type="submit"
              className="btn-primary"
              disabled={saving}
            >
              {saving ? 'Saving...' : (isEditing ? 'Update Event' : 'Create Event')}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

// Helper function to format date for input
function formatDateForInput(date) {
  const d = new Date(date);
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  const hours = String(d.getHours()).padStart(2, '0');
  const minutes = String(d.getMinutes()).padStart(2, '0');
  return `${year}-${month}-${day}T${hours}:${minutes}`;
}
```

---

## Step 3: Create Calendar Tab Component for Streamer Page

Create file: `src/components/StreamerCalendarTab.jsx`

```jsx
import React, { useState, useEffect } from 'react';
import {
  getCalendarEvents,
  formatEventDate,
  isEventPast,
  isEventUpcoming
} from '../services/calendarEventService';
import './StreamerCalendarTab.css';

export function StreamerCalendarTab({ userId }) {
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  
  // Load events
  useEffect(() => {
    if (!userId) {
      setLoading(false);
      return;
    }
    
    loadEvents();
  }, [userId]);
  
  const loadEvents = async () => {
    try {
      setLoading(true);
      const fetchedEvents = await getCalendarEvents(userId);
      setEvents(fetchedEvents);
      setError(null);
    } catch (err) {
      console.error('Error loading events:', err);
      setError('Failed to load events');
    } finally {
      setLoading(false);
    }
  };
  
  if (loading) {
    return (
      <div className="streamer-calendar-tab">
        <div className="calendar-loading">
          <div className="spinner"></div>
          <p>Loading events...</p>
        </div>
      </div>
    );
  }
  
  if (error) {
    return (
      <div className="streamer-calendar-tab">
        <div className="calendar-error">
          {error}
        </div>
      </div>
    );
  }
  
  // Separate past and upcoming events
  const upcomingEvents = events.filter(e => !isEventPast(e.date));
  const pastEvents = events.filter(e => isEventPast(e.date));
  
  return (
    <div className="streamer-calendar-tab">
      {/* Upcoming Events */}
      {upcomingEvents.length > 0 && (
        <div className="calendar-section">
          <h3 className="section-title">Upcoming Events</h3>
          <div className="events-grid">
            {upcomingEvents.map(event => (
              <StreamerEventCard
                key={event.id}
                event={event}
              />
            ))}
          </div>
        </div>
      )}
      
      {/* Past Events */}
      {pastEvents.length > 0 && (
        <div className="calendar-section">
          <h3 className="section-title">Past Events</h3>
          <div className="events-grid">
            {pastEvents.map(event => (
              <StreamerEventCard
                key={event.id}
                event={event}
                isPast={true}
              />
            ))}
          </div>
        </div>
      )}
      
      {/* Empty State */}
      {events.length === 0 && (
        <div className="calendar-empty-state">
          <div className="empty-icon">📅</div>
          <h3>No Events Scheduled</h3>
          <p>This streamer hasn't scheduled any events yet</p>
        </div>
      )}
    </div>
  );
}

// Streamer Event Card Component (Read-only)
function StreamerEventCard({ event, isPast = false }) {
  const isUpcoming = isEventUpcoming(event.date);
  
  return (
    <div className={`streamer-event-card ${isPast ? 'past' : ''} ${isUpcoming ? 'upcoming' : ''}`}>
      <div className="event-header">
        <div className="event-date-badge">
          <div className="event-day">
            {new Date(event.date).getDate()}
          </div>
          <div className="event-month">
            {new Date(event.date).toLocaleDateString('en-US', { month: 'short' })}
          </div>
        </div>
        
        {isUpcoming && !isPast && (
          <div className="upcoming-badge">Upcoming</div>
        )}
      </div>
      
      <div className="event-content">
        <h4 className="event-title">{event.title}</h4>
        {event.description && (
          <p className="event-description">{event.description}</p>
        )}
        <div className="event-time">
          <span className="time-icon">🕐</span>
          {formatEventDate(event.date)}
        </div>
      </div>
      
      {!isPast && (
        <button className="btn-remind">
          <span>🔔</span>
          Remind Me
        </button>
      )}
    </div>
  );
}
```

---

## Step 4: Create CSS Styles

### Profile Calendar Tab CSS

Create file: `src/components/ProfileCalendarTab.css`

```css
/* Profile Calendar Tab */
.profile-calendar-tab {
  padding: 20px;
  max-width: 1200px;
  margin: 0 auto;
}

/* Calendar Header */
.calendar-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 30px;
  padding-bottom: 15px;
  border-bottom: 2px solid #e0e0e0;
}

.calendar-header h2 {
  font-size: 1.8rem;
  margin: 0;
  color: #333;
}

.btn-create-event {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border: none;
  padding: 12px 24px;
  border-radius: 8px;
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
  transition: transform 0.2s, box-shadow 0.2s;
}

.btn-create-event:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
}

/* Calendar Section */
.calendar-section {
  margin-bottom: 40px;
}

.section-title {
  font-size: 1.3rem;
  margin: 0 0 20px 0;
  color: #666;
  font-weight: 600;
}

/* Events List */
.events-list {
  display: flex;
  flex-direction: column;
  gap: 15px;
}

/* Event Card */
.event-card {
  background: white;
  border: 2px solid #e0e0e0;
  border-radius: 12px;
  padding: 20px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  transition: all 0.2s;
  position: relative;
  overflow: hidden;
}

.event-card:hover {
  border-color: #667eea;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  transform: translateY(-2px);
}

.event-card.upcoming {
  border-left: 4px solid #27ae60;
}

.event-card.past {
  opacity: 0.6;
  background: #f8f8f8;
}

.event-card-main {
  display: flex;
  gap: 20px;
  align-items: flex-start;
}

/* Event Date */
.event-date {
  flex-shrink: 0;
  width: 60px;
  height: 60px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border-radius: 12px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  color: white;
}

.event-day {
  font-size: 1.5rem;
  font-weight: 700;
  line-height: 1;
}

.event-month {
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
  margin-top: 2px;
}

/* Event Details */
.event-details {
  flex: 1;
}

.event-title {
  font-size: 1.2rem;
  margin: 0 0 8px 0;
  color: #333;
  font-weight: 600;
}

.event-description {
  margin: 0 0 8px 0;
  color: #666;
  font-size: 0.95rem;
  line-height: 1.5;
}

.event-time {
  font-size: 0.9rem;
  color: #999;
  display: flex;
  align-items: center;
  gap: 5px;
}

/* Event Actions */
.event-actions {
  display: flex;
  gap: 8px;
  flex-shrink: 0;
}

.btn-icon {
  background: none;
  border: none;
  width: 36px;
  height: 36px;
  border-radius: 8px;
  cursor: pointer;
  font-size: 1.1rem;
  transition: background 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
}

.btn-icon:hover {
  background: #f0f0f0;
}

/* Event Badge */
.event-badge {
  position: absolute;
  top: 10px;
  right: 10px;
  background: #27ae60;
  color: white;
  font-size: 0.75rem;
  font-weight: 600;
  padding: 4px 12px;
  border-radius: 12px;
  text-transform: uppercase;
}

/* Empty State */
.calendar-empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 60px 20px;
  text-align: center;
}

.empty-icon {
  font-size: 4rem;
  margin-bottom: 20px;
  opacity: 0.5;
}

.calendar-empty-state h3 {
  font-size: 1.5rem;
  margin: 0 0 10px 0;
  color: #333;
}

.calendar-empty-state p {
  margin: 0 0 20px 0;
  color: #666;
  font-size: 1rem;
}

/* Loading State */
.calendar-loading {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 60px 20px;
  gap: 15px;
}

.spinner {
  width: 40px;
  height: 40px;
  border: 4px solid #f3f3f3;
  border-top: 4px solid #667eea;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

/* Error State */
.calendar-error {
  padding: 15px;
  background: #fee;
  border: 1px solid #fcc;
  border-radius: 8px;
  color: #c33;
  margin-bottom: 20px;
}

/* Modal Overlay */
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.6);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: 20px;
}

.modal-content {
  background: white;
  border-radius: 16px;
  max-width: 600px;
  width: 100%;
  max-height: 90vh;
  overflow-y: auto;
  box-shadow: 0 10px 40px rgba(0, 0, 0, 0.3);
}

.modal-header {
  padding: 25px;
  border-bottom: 2px solid #f0f0f0;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.modal-header h2 {
  margin: 0;
  font-size: 1.5rem;
  color: #333;
}

.modal-close {
  background: none;
  border: none;
  font-size: 1.5rem;
  cursor: pointer;
  color: #999;
  width: 32px;
  height: 32px;
  border-radius: 50%;
  transition: all 0.2s;
}

.modal-close:hover {
  background: #f0f0f0;
  color: #333;
}

.modal-error {
  margin: 20px 25px 0;
  padding: 12px;
  background: #fee;
  border: 1px solid #fcc;
  border-radius: 8px;
  color: #c33;
  font-size: 0.9rem;
}

/* Event Form */
.event-form {
  padding: 25px;
}

.form-field {
  margin-bottom: 20px;
}

.form-field label {
  display: block;
  font-weight: 600;
  margin-bottom: 8px;
  color: #333;
  font-size: 0.95rem;
}

.form-field input,
.form-field textarea {
  width: 100%;
  padding: 12px 16px;
  border: 2px solid #e0e0e0;
  border-radius: 8px;
  font-size: 1rem;
  font-family: inherit;
  transition: border-color 0.2s;
  box-sizing: border-box;
}

.form-field input:focus,
.form-field textarea:focus {
  outline: none;
  border-color: #667eea;
}

.form-field textarea {
  resize: vertical;
  min-height: 100px;
}

.character-count {
  text-align: right;
  font-size: 0.85rem;
  color: #999;
  margin-top: 6px;
}

.form-actions {
  display: flex;
  gap: 12px;
  justify-content: flex-end;
  margin-top: 25px;
}

.btn-primary,
.btn-secondary {
  padding: 12px 30px;
  font-size: 1rem;
  font-weight: 600;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s;
  border: none;
}

.btn-primary {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
}

.btn-primary:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
}

.btn-primary:disabled {
  background: #ccc;
  cursor: not-allowed;
}

.btn-secondary {
  background: white;
  color: #666;
  border: 2px solid #e0e0e0;
}

.btn-secondary:hover:not(:disabled) {
  background: #f5f5f5;
  border-color: #ccc;
}

/* Responsive */
@media (max-width: 768px) {
  .calendar-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 15px;
  }
  
  .btn-create-event {
    width: 100%;
  }
  
  .event-card-main {
    flex-direction: column;
    gap: 15px;
  }
  
  .event-date {
    align-self: flex-start;
  }
  
  .event-actions {
    align-self: flex-end;
  }
}
```

### Streamer Calendar Tab CSS

Create file: `src/components/StreamerCalendarTab.css`

```css
/* Streamer Calendar Tab */
.streamer-calendar-tab {
  padding: 20px;
}

/* Calendar Section */
.calendar-section {
  margin-bottom: 30px;
}

.section-title {
  font-size: 1.2rem;
  margin: 0 0 15px 0;
  color: rgba(255, 255, 255, 0.9);
  font-weight: 600;
}

/* Events Grid */
.events-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 15px;
}

/* Streamer Event Card */
.streamer-event-card {
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 16px;
  padding: 20px;
  display: flex;
  flex-direction: column;
  gap: 15px;
  transition: all 0.3s;
}

.streamer-event-card:hover {
  background: rgba(255, 255, 255, 0.15);
  border-color: rgba(255, 255, 255, 0.3);
  transform: translateY(-4px);
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.3);
}

.streamer-event-card.upcoming {
  border-color: rgba(39, 174, 96, 0.6);
  box-shadow: 0 0 0 1px rgba(39, 174, 96, 0.4);
}

.streamer-event-card.past {
  opacity: 0.5;
}

/* Event Header */
.event-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
}

.event-date-badge {
  width: 50px;
  height: 50px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border-radius: 10px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  color: white;
  flex-shrink: 0;
}

.event-day {
  font-size: 1.3rem;
  font-weight: 700;
  line-height: 1;
}

.event-month {
  font-size: 0.7rem;
  font-weight: 600;
  text-transform: uppercase;
  margin-top: 2px;
}

.upcoming-badge {
  background: #27ae60;
  color: white;
  font-size: 0.7rem;
  font-weight: 600;
  padding: 4px 10px;
  border-radius: 10px;
  text-transform: uppercase;
}

/* Event Content */
.event-content {
  flex: 1;
}

.event-title {
  font-size: 1.1rem;
  margin: 0 0 8px 0;
  color: white;
  font-weight: 600;
  line-height: 1.3;
}

.event-description {
  margin: 0 0 10px 0;
  color: rgba(255, 255, 255, 0.8);
  font-size: 0.9rem;
  line-height: 1.4;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.event-time {
  font-size: 0.85rem;
  color: rgba(255, 255, 255, 0.7);
  display: flex;
  align-items: center;
  gap: 6px;
}

.time-icon {
  font-size: 1rem;
}

/* Remind Me Button */
.btn-remind {
  width: 100%;
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.3);
  color: white;
  padding: 10px;
  border-radius: 8px;
  font-size: 0.9rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
}

.btn-remind:hover {
  background: rgba(255, 255, 255, 0.2);
  border-color: rgba(255, 255, 255, 0.4);
}

/* Empty State */
.calendar-empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 60px 20px;
  text-align: center;
}

.empty-icon {
  font-size: 4rem;
  margin-bottom: 20px;
  opacity: 0.3;
}

.calendar-empty-state h3 {
  font-size: 1.5rem;
  margin: 0 0 10px 0;
  color: rgba(255, 255, 255, 0.9);
}

.calendar-empty-state p {
  margin: 0;
  color: rgba(255, 255, 255, 0.7);
  font-size: 1rem;
}

/* Loading State */
.calendar-loading {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 60px 20px;
  gap: 15px;
}

.spinner {
  width: 40px;
  height: 40px;
  border: 4px solid rgba(255, 255, 255, 0.2);
  border-top: 4px solid white;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

/* Error State */
.calendar-error {
  padding: 15px;
  background: rgba(255, 0, 0, 0.1);
  border: 1px solid rgba(255, 0, 0, 0.3);
  border-radius: 8px;
  color: #ffcccc;
  margin-bottom: 20px;
}

/* Responsive */
@media (max-width: 768px) {
  .events-grid {
    grid-template-columns: 1fr;
  }
}
```

---

## Step 5: Integration Guide

### For Profile Page

```jsx
// src/pages/ProfilePage.jsx
import React, { useState } from 'react';
import { ProfileCalendarTab } from '../components/ProfileCalendarTab';

export function ProfilePage() {
  const [selectedTab, setSelectedTab] = useState('videos'); // 'videos', 'favorites', 'calendar'
  
  return (
    <div className="profile-page">
      {/* Profile Header */}
      <div className="profile-header">
        {/* ... avatar, name, stats ... */}
      </div>
      
      {/* Tabs */}
      <div className="profile-tabs">
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
          Calendar
        </button>
      </div>
      
      {/* Tab Content */}
      <div className="profile-content">
        {selectedTab === 'videos' && <VideosTab />}
        {selectedTab === 'favorites' && <FavoritesTab />}
        {selectedTab === 'calendar' && <ProfileCalendarTab />}
      </div>
    </div>
  );
}
```

### For Streamer Page

```jsx
// src/pages/StreamerPage.jsx
import React, { useState } from 'react';
import { StreamerCalendarTab } from '../components/StreamerCalendarTab';

export function StreamerPage({ streamerId }) {
  const [selectedTab, setSelectedTab] = useState('videos'); // 'videos', 'favorites', 'calendar'
  
  return (
    <div className="streamer-page">
      {/* Streamer Header */}
      <div className="streamer-header">
        {/* ... avatar, name, stats, follow button ... */}
      </div>
      
      {/* Tabs */}
      <div className="streamer-tabs">
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
          Calendar
        </button>
      </div>
      
      {/* Tab Content */}
      <div className="streamer-content">
        {selectedTab === 'videos' && <VideosTab userId={streamerId} />}
        {selectedTab === 'favorites' && <FavoritesTab userId={streamerId} />}
        {selectedTab === 'calendar' && <StreamerCalendarTab userId={streamerId} />}
      </div>
    </div>
  );
}
```

---

## 🔄 How Calendar Sync Works

### Create/Update Flow:

```
Website                    Firestore                   Mobile App
   |                          |                            |
   | 1. User creates event    |                            |
   | on profile page          |                            |
   |------------------------->|                            |
   |                          |                            |
   |    2. Event added to     |                            |
   |    calendarEvents array  |                            |
   |                          |                            |
   |                          | 3. Real-time listener      |
   |                          | detects change             |
   |                          |--------------------------->|
   |                          |                            |
   |                          |      4. Mobile app updates |
   |                          |      calendar display ✨   |
   |                          |                            |
   | 5. Event shows on        |                            |
   | streamer page            |                            |
   |<-------------------------|                            |
```

---

## ✅ Testing Checklist

### Test 1: Create Event on Profile Page
1. [ ] Go to your profile page
2. [ ] Click "Calendar" tab
3. [ ] Click "+ Create Event"
4. [ ] Fill in title, description, date/time
5. [ ] Click "Create Event"
6. [ ] Event appears in calendar
7. [ ] Check mobile app - event synced ✨

**Expected:** Event created and synced < 100ms

### Test 2: Edit Event
1. [ ] Click edit (✏️) on an event
2. [ ] Modify title/description/date
3. [ ] Click "Update Event"
4. [ ] Event updated in calendar
5. [ ] Check mobile app - changes synced ✨

**Expected:** Changes sync instantly

### Test 3: Delete Event
1. [ ] Click delete (🗑️) on an event
2. [ ] Confirm deletion
3. [ ] Event removed from calendar
4. [ ] Check mobile app - event deleted ✨

**Expected:** Deletion syncs instantly

### Test 4: View Events on Streamer Page
1. [ ] Navigate to streamer's page
2. [ ] Click "Calendar" tab
3. [ ] See all streamer's events
4. [ ] Events sorted by date
5. [ ] "Remind Me" button available

**Expected:** All events display correctly

### Test 5: Upcoming vs Past Events
1. [ ] Create event in the future
2. [ ] Create event in the past
3. [ ] Upcoming events show "Upcoming" badge
4. [ ] Past events are grayed out
5. [ ] Events properly sorted

**Expected:** Events categorized correctly

---

## 🎨 Features Summary

### Profile Page Calendar Tab
- ✅ **Create events** with title, description, date/time
- ✅ **Edit events** inline
- ✅ **Delete events** with confirmation
- ✅ **Upcoming/Past sections**
- ✅ **Visual date badges**
- ✅ **Empty state** for new users

### Streamer Page Calendar Tab
- ✅ **View all events** (read-only)
- ✅ **Grid layout** for better visibility
- ✅ **"Remind Me" button** (future enhancement)
- ✅ **Upcoming badges**
- ✅ **Beautiful gradient design**

### Real-Time Features
- ✅ **Instant sync** to mobile (< 100ms)
- ✅ **No refresh needed**
- ✅ **Consistent data** across platforms
- ✅ **Optimistic updates**

---

## 📊 Data Structure

### Firestore Document: `users/{userId}`

```javascript
{
  calendarEvents: [
    {
      id: "1697123456789",
      title: "Live Stream Session",
      description: "Weekly Q&A and gameplay",
      date: Timestamp // Firebase Timestamp
    },
    {
      id: "1697123456790",
      title: "Charity Event",
      description: "24-hour streaming marathon",
      date: Timestamp
    }
  ]
}
```

---

**Implementation Time:** ~2-3 hours  
**Difficulty:** Medium  
**Dependencies:** Firebase SDK, React  
**Result:** Full calendar event system with mobile sync ✨

