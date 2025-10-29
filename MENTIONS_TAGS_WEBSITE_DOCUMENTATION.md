# Mentions & Tags Settings - Website Implementation Guide

This document provides complete implementation details for the **Mentions & Tags Settings** feature to replicate the Flutter app functionality on the website.

## Overview

The **Mentions & Tags View** allows users to control who can mention them and tag them in content, and to configure notification preferences for these interactions.

### Navigation Path
**Settings → Privacy → Mentions & Tags**

## Firestore Structure

### Privacy Settings Document
```
users/{userId}/privacySettings/main
```

**Fields:**
- `allowMentions` (String): 'everyone' | 'followers' | 'nobody'
- `allowTags` (Boolean): true | false

### Notification Settings Document
```
users/{userId}/notificationSettings/main
```

**Fields:**
- `mentions` (Boolean): true | false
- `tags` (Boolean): true | false

## Security Rules

Add these rules to your `firestore.rules`:

```javascript
// User Privacy Settings
match /users/{userId}/privacySettings/{settingsId} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow write: if request.auth != null && request.auth.uid == userId;
}

// User Notification Settings
match /users/{userId}/notificationSettings/{settingsId} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow write: if request.auth != null && request.auth.uid == userId;
}
```

## Flutter Implementation

### View Structure
- **File:** `lib/views/mentions_tags_view.dart`
- **Navigation:** From Settings → Privacy section

### Features

#### 1. Mentions Settings
- **Who can mention you:** Dropdown with 3 options
  - Everyone
  - Followers
  - Nobody
- **Mention Notifications:** Toggle switch

#### 2. Tags Settings
- **Allow Tags:** Toggle switch
- **Tag Notifications:** Toggle switch

#### 3. Info Card
- Explains what mentions and tags are

### State Management

```dart
// Privacy settings
String _allowMentions = 'everyone';
bool _allowTags = true;

// Notification settings
bool _allowMentionNotifications = true;
bool _allowTagNotifications = true;
```

### Loading Settings

```dart
Future<void> _loadSettings() async {
  final user = firebase_auth.FirebaseAuth.instance.currentUser;
  if (user == null) return;

  // Load privacy settings
  final privacyDoc = await _firestore
      .collection('users')
      .doc(user.uid)
      .collection('privacySettings')
      .doc('main')
      .get();

  // Load notification settings
  final notificationDoc = await _firestore
      .collection('users')
      .doc(user.uid)
      .collection('notificationSettings')
      .doc('main')
      .get();

  // Update state with loaded values
  if (privacyDoc.exists) {
    final data = privacyDoc.data()!;
    setState(() {
      _allowMentions = data['allowMentions'] ?? 'everyone';
      _allowTags = data['allowTags'] ?? true;
    });
  }

  if (notificationDoc.exists) {
    final data = notificationDoc.data()!;
    setState(() {
      _allowMentionNotifications = data['mentions'] ?? true;
      _allowTagNotifications = data['tags'] ?? true;
    });
  }
}
```

### Updating Settings

```dart
// Update privacy setting
Future<void> _updatePrivacySetting(String key, dynamic value) async {
  final user = firebase_auth.FirebaseAuth.instance.currentUser;
  if (user == null) return;

  await _firestore
      .collection('users')
      .doc(user.uid)
      .collection('privacySettings')
      .doc('main')
      .set({key: value}, SetOptions(merge: true));
}

// Update notification setting
Future<void> _updateNotificationSetting(String key, bool value) async {
  final user = firebase_auth.FirebaseAuth.instance.currentUser;
  if (user == null) return;

  await _firestore
      .collection('users')
      .doc(user.uid)
      .collection('notificationSettings')
      .doc('main')
      .set({key: value}, SetOptions(merge: true));
}
```

## Website Implementation

### React Component Structure

```jsx
import React, { useState, useEffect } from 'react';
import { doc, getDoc, setDoc } from 'firebase/firestore';
import { auth, db } from './firebase';
import './MentionsTags.css';

const MentionsTags = () => {
  const [loading, setLoading] = useState(true);
  const [allowMentions, setAllowMentions] = useState('everyone');
  const [allowTags, setAllowTags] = useState(true);
  const [mentionNotifications, setMentionNotifications] = useState(true);
  const [tagNotifications, setTagNotifications] = useState(true);

  useEffect(() => {
    loadSettings();
  }, []);

  const loadSettings = async () => {
    try {
      const user = auth.currentUser;
      if (!user) return;

      // Load privacy settings
      const privacyRef = doc(db, 'users', user.uid, 'privacySettings', 'main');
      const privacyDoc = await getDoc(privacyRef);
      if (privacyDoc.exists()) {
        const data = privacyDoc.data();
        setAllowMentions(data.allowMentions || 'everyone');
        setAllowTags(data.allowTags ?? true);
      }

      // Load notification settings
      const notifRef = doc(db, 'users', user.uid, 'notificationSettings', 'main');
      const notifDoc = await getDoc(notifRef);
      if (notifDoc.exists()) {
        const data = notifDoc.data();
        setMentionNotifications(data.mentions ?? true);
        setTagNotifications(data.tags ?? true);
      }

      setLoading(false);
    } catch (error) {
      console.error('Error loading settings:', error);
      setLoading(false);
    }
  };

  const updatePrivacySetting = async (key, value) => {
    try {
      const user = auth.currentUser;
      if (!user) return;

      const ref = doc(db, 'users', user.uid, 'privacySettings', 'main');
      await setDoc(ref, { [key]: value }, { merge: true });
    } catch (error) {
      console.error('Error updating setting:', error);
      alert('Failed to update setting');
    }
  };

  const updateNotificationSetting = async (key, value) => {
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

  const handleMentionsChange = (e) => {
    const value = e.target.value;
    setAllowMentions(value);
    updatePrivacySetting('allowMentions', value);
  };

  const handleAllowTagsChange = (e) => {
    setAllowTags(e.target.checked);
    updatePrivacySetting('allowTags', e.target.checked);
  };

  const handleMentionNotificationsChange = (e) => {
    setMentionNotifications(e.target.checked);
    updateNotificationSetting('mentions', e.target.checked);
  };

  const handleTagNotificationsChange = (e) => {
    setTagNotifications(e.target.checked);
    updateNotificationSetting('tags', e.target.checked);
  };

  if (loading) {
    return <div className="loading">Loading...</div>;
  }

  return (
    <div className="mentions-tags-container">
      <div className="mentions-section">
        <h2>Mentions</h2>
        <p className="subtitle">Control who can mention you</p>

        <div className="setting-card">
          <div className="setting-row">
            <div className="setting-info">
              <div className="setting-icon">@</div>
              <div>
                <div className="setting-title">Who can mention you</div>
                <div className="setting-subtitle">Control mention permissions</div>
              </div>
            </div>
            <select
              value={allowMentions}
              onChange={handleMentionsChange}
              className="dropdown"
            >
              <option value="everyone">Everyone</option>
              <option value="followers">Followers</option>
              <option value="nobody">Nobody</option>
            </select>
          </div>

          <div className="setting-row">
            <div className="setting-info">
              <div className="setting-icon">🔔</div>
              <div>
                <div className="setting-title">Mention Notifications</div>
                <div className="setting-subtitle">Get notified when someone mentions you</div>
              </div>
            </div>
            <label className="switch">
              <input
                type="checkbox"
                checked={mentionNotifications}
                onChange={handleMentionNotificationsChange}
              />
              <span className="slider"></span>
            </label>
          </div>
        </div>
      </div>

      <div className="tags-section">
        <h2>Tags</h2>
        <p className="subtitle">Control who can tag you</p>

        <div className="setting-card">
          <div className="setting-row">
            <div className="setting-info">
              <div className="setting-icon">🏷️</div>
              <div>
                <div className="setting-title">Allow Tags</div>
                <div className="setting-subtitle">Let people tag you in their content</div>
              </div>
            </div>
            <label className="switch">
              <input
                type="checkbox"
                checked={allowTags}
                onChange={handleAllowTagsChange}
              />
              <span className="slider"></span>
            </label>
          </div>

          <div className="setting-row">
            <div className="setting-info">
              <div className="setting-icon">🔔</div>
              <div>
                <div className="setting-title">Tag Notifications</div>
                <div className="setting-subtitle">Get notified when someone tags you</div>
              </div>
            </div>
            <label className="switch">
              <input
                type="checkbox"
                checked={tagNotifications}
                onChange={handleTagNotificationsChange}
              />
              <span className="slider"></span>
            </label>
          </div>
        </div>
      </div>

      <div className="info-card">
        <div className="info-icon">ℹ️</div>
        <div>
          <div className="info-title">About Mentions & Tags</div>
          <div className="info-text">
            Mentions allow users to tag you in comments. Tags let users tag you in their content. You control who can do this.
          </div>
        </div>
      </div>
    </div>
  );
};

export default MentionsTags;
```

### CSS Styling

```css
/* MentionsTags.css */

.mentions-tags-container {
  max-width: 800px;
  margin: 0 auto;
  padding: 40px 20px;
  background: linear-gradient(135deg, #6633CC 0%, #1A1A4D 100%);
  min-height: 100vh;
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

.dropdown {
  padding: 8px 12px;
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 8px;
  color: white;
  font-size: 14px;
  cursor: pointer;
}

.dropdown option {
  background: #1C135D;
  color: white;
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

.mentions-section,
.tags-section {
  margin-bottom: 32px;
}
```

### JavaScript (Vanilla JS) Version

```javascript
// mentionsTags.js

let allowMentions = 'everyone';
let allowTags = true;
let mentionNotifications = true;
let tagNotifications = true;

async function loadSettings() {
  try {
    const user = firebase.auth().currentUser;
    if (!user) return;

    // Load privacy settings
    const privacyRef = db.collection('users')
      .doc(user.uid)
      .collection('privacySettings')
      .doc('main');
    
    const privacyDoc = await privacyRef.get();
    if (privacyDoc.exists) {
      const data = privacyDoc.data();
      allowMentions = data.allowMentions || 'everyone';
      allowTags = data.allowTags ?? true;
    }

    // Load notification settings
    const notifRef = db.collection('users')
      .doc(user.uid)
      .collection('notificationSettings')
      .doc('main');
    
    const notifDoc = await notifRef.get();
    if (notifDoc.exists) {
      const data = notifDoc.data();
      mentionNotifications = data.mentions ?? true;
      tagNotifications = data.tags ?? true;
    }

    renderSettings();
  } catch (error) {
    console.error('Error loading settings:', error);
  }
}

async function updatePrivacySetting(key, value) {
  try {
    const user = firebase.auth().currentUser;
    if (!user) return;

    const ref = db.collection('users')
      .doc(user.uid)
      .collection('privacySettings')
      .doc('main');
    
    await ref.set({ [key]: value }, { merge: true });
  } catch (error) {
    console.error('Error updating setting:', error);
    alert('Failed to update setting');
  }
}

async function updateNotificationSetting(key, value) {
  try {
    const user = firebase.auth().currentUser;
    if (!user) return;

    const ref = db.collection('users')
      .doc(user.uid)
      .collection('notificationSettings')
      .doc('main');
    
    await ref.set({ [key]: value }, { merge: true });
  } catch (error) {
    console.error('Error updating setting:', error);
    alert('Failed to update setting');
  }
}

function renderSettings() {
  // Render mentions dropdown
  document.getElementById('mentions-dropdown').value = allowMentions;
  
  // Render toggles
  document.getElementById('allow-tags').checked = allowTags;
  document.getElementById('mention-notifications').checked = mentionNotifications;
  document.getElementById('tag-notifications').checked = tagNotifications;
}

// Event listeners
document.getElementById('mentions-dropdown').addEventListener('change', (e) => {
  allowMentions = e.target.value;
  updatePrivacySetting('allowMentions', allowMentions);
});

document.getElementById('allow-tags').addEventListener('change', (e) => {
  allowTags = e.target.checked;
  updatePrivacySetting('allowTags', allowTags);
});

document.getElementById('mention-notifications').addEventListener('change', (e) => {
  mentionNotifications = e.target.checked;
  updateNotificationSetting('mentions', mentionNotifications);
});

document.getElementById('tag-notifications').addEventListener('change', (e) => {
  tagNotifications = e.target.checked;
  updateNotificationSetting('tags', tagNotifications);
});

// Load settings on page load
loadSettings();
```

### HTML Template

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Mentions & Tags Settings</title>
  <link rel="stylesheet" href="mentionsTags.css">
</head>
<body>
  <div class="mentions-tags-container">
    <div class="mentions-section">
      <h2>Mentions</h2>
      <p class="subtitle">Control who can mention you</p>

      <div class="setting-card">
        <div class="setting-row">
          <div class="setting-info">
            <div class="setting-icon">@</div>
            <div>
              <div class="setting-title">Who can mention you</div>
              <div class="setting-subtitle">Control mention permissions</div>
            </div>
          </div>
          <select id="mentions-dropdown" class="dropdown">
            <option value="everyone">Everyone</option>
            <option value="followers">Followers</option>
            <option value="nobody">Nobody</option>
          </select>
        </div>

        <div class="setting-row">
          <div class="setting-info">
            <div class="setting-icon">🔔</div>
            <div>
              <div class="setting-title">Mention Notifications</div>
              <div class="setting-subtitle">Get notified when someone mentions you</div>
            </div>
          </div>
          <label class="switch">
            <input type="checkbox" id="mention-notifications">
            <span class="slider"></span>
          </label>
        </div>
      </div>
    </div>

    <div class="tags-section">
      <h2>Tags</h2>
      <p class="subtitle">Control who can tag you</p>

      <div class="setting-card">
        <div class="setting-row">
          <div class="setting-info">
            <div class="setting-icon">🏷️</div>
            <div>
              <div class="setting-title">Allow Tags</div>
              <div class="setting-subtitle">Let people tag you in their content</div>
            </div>
          </div>
          <label class="switch">
            <input type="checkbox" id="allow-tags">
            <span class="slider"></span>
          </label>
        </div>

        <div class="setting-row">
          <div class="setting-info">
            <div class="setting-icon">🔔</div>
            <div>
              <div class="setting-title">Tag Notifications</div>
              <div class="setting-subtitle">Get notified when someone tags you</div>
            </div>
          </div>
          <label class="switch">
            <input type="checkbox" id="tag-notifications">
            <span class="slider"></span>
          </label>
        </div>
      </div>
    </div>

    <div class="info-card">
      <div class="info-icon">ℹ️</div>
      <div>
        <div class="info-title">About Mentions & Tags</div>
        <div class="info-text">
          Mentions allow users to tag you in comments. Tags let users tag you in their content. You control who can do this.
        </div>
      </div>
    </div>
  </div>

  <script src="mentionsTags.js"></script>
</body>
</html>
```

## Testing Checklist

- [ ] Load settings on page/view open
- [ ] Display correct current values
- [ ] Update mentions dropdown
- [ ] Update allow tags toggle
- [ ] Update mention notifications toggle
- [ ] Update tag notifications toggle
- [ ] Show success message after saving
- [ ] Handle errors gracefully
- [ ] Match app UI styling
- [ ] Firestore rules working correctly

## Summary

This Mentions & Tags View allows users to:
1. Control who can mention them (everyone/followers/nobody)
2. Enable/disable tags
3. Configure notification preferences for mentions and tags

The implementation uses two Firestore collections:
- `privacySettings` for mention/tag permissions
- `notificationSettings` for notification preferences

Both the Flutter app and website can access the same data structure for cross-platform consistency.

