# Notifications Settings - Website Implementation Guide

This document provides complete implementation details for the **Notifications Settings** feature to replicate the Flutter app functionality on the website.

## Overview

The **Notifications View** allows users to control how and when they receive various types of notifications across different channels.

### Navigation Path
**Settings → Privacy → Notifications**

## Firestore Structure

### Notification Settings Document
```
users/{userId}/notificationSettings/main
```

**Fields:**
- `pushNotifications` (Boolean): Enable/disable push notifications
- `emailNotifications` (Boolean): Enable/disable email notifications
- `smsNotifications` (Boolean): Enable/disable SMS notifications
- `follows` (Boolean): Notifications for new followers
- `likes` (Boolean): Notifications for likes
- `comments` (Boolean): Notifications for comments
- `mentions` (Boolean): Notifications for mentions
- `tags` (Boolean): Notifications for tags
- `messages` (Boolean): Notifications for direct messages
- `live` (Boolean): Notifications for live streams

## Security Rules

Add these rules to your `firestore.rules`:

```javascript
// User Notification Settings
match /users/{userId}/notificationSettings/{settingsId} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow write: if request.auth != null && request.auth.uid == userId;
}
```

## Flutter Implementation

### View Structure
- **File:** `lib/views/notifications_view.dart`
- **Navigation:** From Settings → Privacy section

### Features

#### 1. General Notifications
- **Push Notifications:** Toggle for device push notifications
- **Email Notifications:** Toggle for email notifications
- **SMS Notifications:** Toggle for SMS notifications

#### 2. Social Activity Notifications
- **New Followers:** Notify when someone follows you
- **Likes:** Notify when someone likes your content
- **Comments:** Notify when someone comments

#### 3. Mentions & Tags Notifications
- **Mentions:** Notify when someone mentions you
- **Tags:** Notify when someone tags you

#### 4. Messages Notifications
- **Direct Messages:** Notify when you receive a message

#### 5. Live & Events Notifications
- **Live Streams:** Notify when someone goes live

### State Management

```dart
// General notifications
bool _pushNotifications = true;
bool _emailNotifications = false;
bool _smsNotifications = false;

// Social activity
bool _followNotifications = true;
bool _likeNotifications = true;
bool _commentNotifications = true;

// Mentions & tags
bool _mentionNotifications = true;
bool _tagNotifications = true;

// Messages
bool _messageNotifications = true;

// Live & events
bool _liveNotifications = true;
```

### Loading Settings

```dart
Future<void> _loadSettings() async {
  final user = firebase_auth.FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final doc = await _firestore
      .collection('users')
      .doc(user.uid)
      .collection('notificationSettings')
      .doc('main')
      .get();

  if (doc.exists) {
    final data = doc.data()!;
    setState(() {
      _pushNotifications = data['pushNotifications'] ?? true;
      _emailNotifications = data['emailNotifications'] ?? false;
      _smsNotifications = data['smsNotifications'] ?? false;
      _followNotifications = data['follows'] ?? true;
      _likeNotifications = data['likes'] ?? true;
      _commentNotifications = data['comments'] ?? true;
      _mentionNotifications = data['mentions'] ?? true;
      _tagNotifications = data['tags'] ?? true;
      _messageNotifications = data['messages'] ?? true;
      _liveNotifications = data['live'] ?? true;
    });
  }
}
```

### Updating Settings

```dart
Future<void> _updateSetting(String key, dynamic value) async {
  final user = firebase_auth.FirebaseAuth.instance.currentUser;
  if (user == null) return;

  setState(() => _isSaving = true);

  try {
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notificationSettings')
        .doc('main')
        .set({key: value}, SetOptions(merge: true));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings updated'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isSaving = false);
    }
  }
}
```

## Website Implementation

### React Component Structure

```jsx
import React, { useState, useEffect } from 'react';
import { doc, getDoc, setDoc } from 'firebase/firestore';
import { auth, db } from './firebase';
import './Notifications.css';

const Notifications = () => {
  const [loading, setLoading] = useState(true);
  
  // General notifications
  const [pushNotifications, setPushNotifications] = useState(true);
  const [emailNotifications, setEmailNotifications] = useState(false);
  const [smsNotifications, setSmsNotifications] = useState(false);
  
  // Social activity
  const [followNotifications, setFollowNotifications] = useState(true);
  const [likeNotifications, setLikeNotifications] = useState(true);
  const [commentNotifications, setCommentNotifications] = useState(true);
  
  // Mentions & tags
  const [mentionNotifications, setMentionNotifications] = useState(true);
  const [tagNotifications, setTagNotifications] = useState(true);
  
  // Messages
  const [messageNotifications, setMessageNotifications] = useState(true);
  
  // Live
  const [liveNotifications, setLiveNotifications] = useState(true);

  useEffect(() => {
    loadSettings();
  }, []);

  const loadSettings = async () => {
    try {
      const user = auth.currentUser;
      if (!user) return;

      const ref = doc(db, 'users', user.uid, 'notificationSettings', 'main');
      const docSnap = await getDoc(ref);
      
      if (docSnap.exists()) {
        const data = docSnap.data();
        setPushNotifications(data.pushNotifications ?? true);
        setEmailNotifications(data.emailNotifications ?? false);
        setSmsNotifications(data.smsNotifications ?? false);
        setFollowNotifications(data.follows ?? true);
        setLikeNotifications(data.likes ?? true);
        setCommentNotifications(data.comments ?? true);
        setMentionNotifications(data.mentions ?? true);
        setTagNotifications(data.tags ?? true);
        setMessageNotifications(data.messages ?? true);
        setLiveNotifications(data.live ?? true);
      }

      setLoading(false);
    } catch (error) {
      console.error('Error loading settings:', error);
      setLoading(false);
    }
  };

  const updateSetting = async (key, value) => {
    try {
      const user = auth.currentUser;
      if (!user) return;

      const ref = doc(db, 'users', user.uid, 'notificationSettings', 'main');
      await setDoc(ref, { [key]: value }, { merge: true });
    } catch (error) {
      console.error('Error updating setting:', error);
      alert('Failed to update setting');
    }
  };

  const handleChange = (key, value, setValue) => {
    setValue(value);
    updateSetting(key, value);
  };

  if (loading) {
    return <div className="loading">Loading...</div>;
  }

  return (
    <div className="notifications-container">
      <div className="section">
        <h2>General</h2>
        <p className="subtitle">Basic notification settings</p>

        <div className="setting-card">
          <div className="setting-row">
            <div className="setting-info">
              <div className="setting-icon">🔔</div>
              <div>
                <div className="setting-title">Push Notifications</div>
                <div className="setting-subtitle">Receive push notifications on your device</div>
              </div>
            </div>
            <label className="switch">
              <input
                type="checkbox"
                checked={pushNotifications}
                onChange={(e) => handleChange('pushNotifications', e.target.checked, setPushNotifications)}
              />
              <span className="slider"></span>
            </label>
          </div>

          <div className="setting-row">
            <div className="setting-info">
              <div className="setting-icon">📧</div>
              <div>
                <div className="setting-title">Email Notifications</div>
                <div className="setting-subtitle">Receive notifications via email</div>
              </div>
            </div>
            <label className="switch">
              <input
                type="checkbox"
                checked={emailNotifications}
                onChange={(e) => handleChange('emailNotifications', e.target.checked, setEmailNotifications)}
              />
              <span className="slider"></span>
            </label>
          </div>

          <div className="setting-row">
            <div className="setting-info">
              <div className="setting-icon">💬</div>
              <div>
                <div className="setting-title">SMS Notifications</div>
                <div className="setting-subtitle">Receive notifications via SMS</div>
              </div>
            </div>
            <label className="switch">
              <input
                type="checkbox"
                checked={smsNotifications}
                onChange={(e) => handleChange('smsNotifications', e.target.checked, setSmsNotifications)}
              />
              <span className="slider"></span>
            </label>
          </div>
        </div>
      </div>

      <div className="section">
        <h2>Social Activity</h2>
        <p className="subtitle">Notifications for social interactions</p>

        <div className="setting-card">
          <div className="setting-row">
            <div className="setting-info">
              <div className="setting-icon">👥</div>
              <div>
                <div className="setting-title">New Followers</div>
                <div className="setting-subtitle">Get notified when someone follows you</div>
              </div>
            </div>
            <label className="switch">
              <input
                type="checkbox"
                checked={followNotifications}
                onChange={(e) => handleChange('follows', e.target.checked, setFollowNotifications)}
              />
              <span className="slider"></span>
            </label>
          </div>

          <div className="setting-row">
            <div className="setting-info">
              <div className="setting-icon">❤️</div>
              <div>
                <div className="setting-title">Likes</div>
                <div className="setting-subtitle">Get notified when someone likes your content</div>
              </div>
            </div>
            <label className="switch">
              <input
                type="checkbox"
                checked={likeNotifications}
                onChange={(e) => handleChange('likes', e.target.checked, setLikeNotifications)}
              />
              <span className="slider"></span>
            </label>
          </div>

          <div className="setting-row">
            <div className="setting-info">
              <div className="setting-icon">💬</div>
              <div>
                <div className="setting-title">Comments</div>
                <div className="setting-subtitle">Get notified when someone comments</div>
              </div>
            </div>
            <label className="switch">
              <input
                type="checkbox"
                checked={commentNotifications}
                onChange={(e) => handleChange('comments', e.target.checked, setCommentNotifications)}
              />
              <span className="slider"></span>
            </label>
          </div>
        </div>
      </div>

      <div className="section">
        <h2>Mentions & Tags</h2>
        <p className="subtitle">Notifications for mentions and tags</p>

        <div className="setting-card">
          <div className="setting-row">
            <div className="setting-info">
              <div className="setting-icon">@</div>
              <div>
                <div className="setting-title">Mentions</div>
                <div className="setting-subtitle">Get notified when someone mentions you</div>
              </div>
            </div>
            <label className="switch">
              <input
                type="checkbox"
                checked={mentionNotifications}
                onChange={(e) => handleChange('mentions', e.target.checked, setMentionNotifications)}
              />
              <span className="slider"></span>
            </label>
          </div>

          <div className="setting-row">
            <div className="setting-info">
              <div className="setting-icon">🏷️</div>
              <div>
                <div className="setting-title">Tags</div>
                <div className="setting-subtitle">Get notified when someone tags you</div>
              </div>
            </div>
            <label className="switch">
              <input
                type="checkbox"
                checked={tagNotifications}
                onChange={(e) => handleChange('tags', e.target.checked, setTagNotifications)}
              />
              <span className="slider"></span>
            </label>
          </div>
        </div>
      </div>

      <div className="section">
        <h2>Messages</h2>
        <p className="subtitle">Notification settings for messages</p>

        <div className="setting-card">
          <div className="setting-row">
            <div className="setting-info">
              <div className="setting-icon">💌</div>
              <div>
                <div className="setting-title">Direct Messages</div>
                <div className="setting-subtitle">Get notified when you receive a message</div>
              </div>
            </div>
            <label className="switch">
              <input
                type="checkbox"
                checked={messageNotifications}
                onChange={(e) => handleChange('messages', e.target.checked, setMessageNotifications)}
              />
              <span className="slider"></span>
            </label>
          </div>
        </div>
      </div>

      <div className="section">
        <h2>Live & Events</h2>
        <p className="subtitle">Notifications for live content and events</p>

        <div className="setting-card">
          <div className="setting-row">
            <div className="setting-info">
              <div className="setting-icon">📹</div>
              <div>
                <div className="setting-title">Live Streams</div>
                <div className="setting-subtitle">Get notified when someone goes live</div>
              </div>
            </div>
            <label className="switch">
              <input
                type="checkbox"
                checked={liveNotifications}
                onChange={(e) => handleChange('live', e.target.checked, setLiveNotifications)}
              />
              <span className="slider"></span>
            </label>
          </div>
        </div>
      </div>

      <div className="info-card">
        <div className="info-icon">ℹ️</div>
        <div>
          <div className="info-title">About Notifications</div>
          <div className="info-text">
            Customize how and when you receive notifications. You can control each type of notification individually.
          </div>
        </div>
      </div>
    </div>
  );
};

export default Notifications;
```

### CSS Styling

```css
/* Notifications.css */

.notifications-container {
  max-width: 800px;
  margin: 0 auto;
  padding: 40px 20px;
  background: linear-gradient(135deg, #6633CC 0%, #1A1A4D 100%);
  min-height: 100vh;
}

.section {
  margin-bottom: 32px;
}

h2 {
  color: white;
  font-size: 24px;
  font-weight: bold;
  margin-bottom: 8px;
}

.subtitle {
  color: rgba(255, 255, 255, 0.7);
  font-size: 14px;
  margin-bottom: 20px;
}

.setting-card {
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 16px;
  overflow: hidden;
}

.setting-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 20px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.setting-row:last-child {
  border-bottom: none;
}

.setting-info {
  display: flex;
  align-items: center;
  gap: 16px;
  flex: 1;
}

.setting-icon {
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.1);
  border-radius: 8px;
  font-size: 20px;
}

.setting-title {
  color: white;
  font-size: 16px;
  font-weight: 600;
  margin-bottom: 2px;
}

.setting-subtitle {
  color: rgba(255, 255, 255, 0.7);
  font-size: 12px;
}

/* Toggle Switch */
.switch {
  position: relative;
  display: inline-block;
  width: 48px;
  height: 24px;
}

.switch input {
  opacity: 0;
  width: 0;
  height: 0;
}

.slider {
  position: absolute;
  cursor: pointer;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: #ccc;
  transition: 0.4s;
  border-radius: 24px;
}

.slider:before {
  position: absolute;
  content: "";
  height: 18px;
  width: 18px;
  left: 3px;
  bottom: 3px;
  background-color: white;
  transition: 0.4s;
  border-radius: 50%;
}

input:checked + .slider {
  background-color: #9248D2;
}

input:checked + .slider:before {
  transform: translateX(24px);
}

/* Info Card */
.info-card {
  background: rgba(59, 130, 246, 0.1);
  border: 1px solid rgba(59, 130, 246, 0.3);
  border-radius: 16px;
  padding: 20px;
  display: flex;
  align-items: start;
  gap: 16px;
  margin-top: 32px;
}

.info-icon {
  font-size: 24px;
}

.info-title {
  color: white;
  font-size: 16px;
  font-weight: bold;
  margin-bottom: 8px;
}

.info-text {
  color: rgba(255, 255, 255, 0.8);
  font-size: 14px;
  line-height: 1.5;
}

.loading {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 100vh;
  color: white;
  font-size: 18px;
}
```

### JavaScript (Vanilla JS) Version

```javascript
// notifications.js

let notificationSettings = {
  pushNotifications: true,
  emailNotifications: false,
  smsNotifications: false,
  follows: true,
  likes: true,
  comments: true,
  mentions: true,
  tags: true,
  messages: true,
  live: true
};

async function loadSettings() {
  try {
    const user = firebase.auth().currentUser;
    if (!user) return;

    const ref = db.collection('users')
      .doc(user.uid)
      .collection('notificationSettings')
      .doc('main');
    
    const doc = await ref.get();
    if (doc.exists) {
      const data = doc.data();
      Object.assign(notificationSettings, {
        pushNotifications: data.pushNotifications ?? true,
        emailNotifications: data.emailNotifications ?? false,
        smsNotifications: data.smsNotifications ?? false,
        follows: data.follows ?? true,
        likes: data.likes ?? true,
        comments: data.comments ?? true,
        mentions: data.mentions ?? true,
        tags: data.tags ?? true,
        messages: data.messages ?? true,
        live: data.live ?? true
      });
    }

    renderSettings();
  } catch (error) {
    console.error('Error loading settings:', error);
  }
}

async function updateSetting(key, value) {
  try {
    const user = firebase.auth().currentUser;
    if (!user) return;

    const ref = db.collection('users')
      .doc(user.uid)
      .collection('notificationSettings')
      .doc('main');
    
    await ref.set({ [key]: value }, { merge: true });
    notificationSettings[key] = value;
  } catch (error) {
    console.error('Error updating setting:', error);
    alert('Failed to update setting');
  }
}

function renderSettings() {
  // Render all toggles
  const toggleIds = [
    'push-notifications',
    'email-notifications',
    'sms-notifications',
    'follow-notifications',
    'like-notifications',
    'comment-notifications',
    'mention-notifications',
    'tag-notifications',
    'message-notifications',
    'live-notifications'
  ];

  const settingKeys = [
    'pushNotifications',
    'emailNotifications',
    'smsNotifications',
    'follows',
    'likes',
    'comments',
    'mentions',
    'tags',
    'messages',
    'live'
  ];

  toggleIds.forEach((id, index) => {
    const checkbox = document.getElementById(id);
    if (checkbox) {
      checkbox.checked = notificationSettings[settingKeys[index]];
    }
  });
}

// Event listeners
document.getElementById('push-notifications').addEventListener('change', (e) => {
  updateSetting('pushNotifications', e.target.checked);
});

document.getElementById('email-notifications').addEventListener('change', (e) => {
  updateSetting('emailNotifications', e.target.checked);
});

document.getElementById('sms-notifications').addEventListener('change', (e) => {
  updateSetting('smsNotifications', e.target.checked);
});

document.getElementById('follow-notifications').addEventListener('change', (e) => {
  updateSetting('follows', e.target.checked);
});

document.getElementById('like-notifications').addEventListener('change', (e) => {
  updateSetting('likes', e.target.checked);
});

document.getElementById('comment-notifications').addEventListener('change', (e) => {
  updateSetting('comments', e.target.checked);
});

document.getElementById('mention-notifications').addEventListener('change', (e) => {
  updateSetting('mentions', e.target.checked);
});

document.getElementById('tag-notifications').addEventListener('change', (e) => {
  updateSetting('tags', e.target.checked);
});

document.getElementById('message-notifications').addEventListener('change', (e) => {
  updateSetting('messages', e.target.checked);
});

document.getElementById('live-notifications').addEventListener('change', (e) => {
  updateSetting('live', e.target.checked);
});

// Load settings on page load
loadSettings();
```

## Testing Checklist

- [ ] Load settings on page/view open
- [ ] Display correct current values
- [ ] Update each toggle switch
- [ ] Persist changes to Firestore
- [ ] Show success message after saving
- [ ] Handle errors gracefully
- [ ] Match app UI styling
- [ ] Firestore rules working correctly

## Summary

This Notifications View allows users to:
1. Control general notification channels (Push, Email, SMS)
2. Configure social activity notifications (Follows, Likes, Comments)
3. Manage mentions & tags notifications
4. Set message notification preferences
5. Configure live stream notifications

The implementation uses the `notificationSettings` Firestore collection to store all notification preferences in one document. Both the Flutter app and website can access the same data structure for cross-platform consistency.

