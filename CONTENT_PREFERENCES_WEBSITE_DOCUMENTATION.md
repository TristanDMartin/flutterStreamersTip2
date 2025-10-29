# Content Preferences - Website Implementation Guide

This document provides complete implementation details for the **Content Preferences** feature to replicate the Flutter app functionality on the website.

## Overview

The **Content Preferences View** allows users to control video playback settings, quality preferences, download permissions, content visibility, and language preferences.

### Navigation Path
**Settings → Content & Activity → Content Preferences**

## Firestore Structure

### Content Settings Document
```
users/{userId}/contentSettings/main
```

**Fields:**
- `autoPlay` (Boolean): Enable auto-play for videos
- `soundEnabled` (Boolean): Enable sound by default
- `dataSaver` (Boolean): Enable data saver mode
- `videoQuality` (String): 'auto' | 'high' | 'medium' | 'low'
- `downloadEnabled` (Boolean): Allow video downloads
- `contentVisibility` (Boolean): Filter mature content
- `sensitiveContent` (Boolean): Show sensitive content
- `languagePreference` (String): Language code (en, es, fr, etc.)

## Security Rules

Add these rules to your `firestore.rules`:

```javascript
// User Content Settings
match /users/{userId}/contentSettings/{settingsId} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow write: if request.auth != null && request.auth.uid == userId;
}
```

## Flutter Implementation

### View Structure
- **File:** `lib/views/content_preferences_view.dart`
- **Navigation:** From Settings → Content & Activity section

### Features

#### 1. Playback Settings
- **Auto-play:** Toggle for automatic video playback
- **Sound:** Toggle for sound by default

#### 2. Quality & Data
- **Video Quality:** Dropdown (auto, high, medium, low)
- **Data Saver:** Toggle for reduced data usage

#### 3. Downloads
- **Allow Downloads:** Toggle

#### 4. Content Visibility
- **Show Sensitive Content:** Toggle for explicit content
- **Content Filter:** Toggle for mature content filtering

#### 5. Language
- **Preferred Language:** Dropdown (en, es, fr, de, it, pt, ja, zh)

### Loading & Saving Settings

```dart
Future<void> _loadSettings() async {
  final user = firebase_auth.FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final doc = await _firestore
      .collection('users')
      .doc(user.uid)
      .collection('contentSettings')
      .doc('main')
      .get();

  if (doc.exists) {
    final data = doc.data()!;
    setState(() {
      _autoPlay = data['autoPlay'] ?? true;
      _soundEnabled = data['soundEnabled'] ?? true;
      _dataSaver = data['dataSaver'] ?? false;
      _videoQuality = data['videoQuality'] ?? 'auto';
      _downloadEnabled = data['downloadEnabled'] ?? true;
      _contentVisibility = data['contentVisibility'] ?? true;
      _sensitiveContent = data['sensitiveContent'] ?? false;
      _languagePreference = data['languagePreference'] ?? 'en';
    });
  }
}

Future<void> _updateSetting(String key, dynamic value) async {
  final user = firebase_auth.FirebaseAuth.instance.currentUser;
  if (user == null) return;

  await _firestore
      .collection('users')
      .doc(user.uid)
      .collection('contentSettings')
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
import './ContentPreferences.css';

const ContentPreferences = () => {
  const [loading, setLoading] = useState(true);
  
  // Playback
  const [autoPlay, setAutoPlay] = useState(true);
  const [soundEnabled, setSoundEnabled] = useState(true);
  
  // Quality & data
  const [dataSaver, setDataSaver] = useState(false);
  const [videoQuality, setVideoQuality] = useState('auto');
  
  // Downloads
  const [downloadEnabled, setDownloadEnabled] = useState(true);
  
  // Content visibility
  const [contentVisibility, setContentVisibility] = useState(true);
  const [sensitiveContent, setSensitiveContent] = useState(false);
  
  // Language
  const [languagePreference, setLanguagePreference] = useState('en');

  useEffect(() => {
    loadSettings();
  }, []);

  const loadSettings = async () => {
    try {
      const user = auth.currentUser;
      if (!user) return;

      const ref = doc(db, 'users', user.uid, 'contentSettings', 'main');
      const docSnap = await getDoc(ref);
      
      if (docSnap.exists()) {
        const data = docSnap.data();
        setAutoPlay(data.autoPlay ?? true);
        setSoundEnabled(data.soundEnabled ?? true);
        setDataSaver(data.dataSaver ?? false);
        setVideoQuality(data.videoQuality ?? 'auto');
        setDownloadEnabled(data.downloadEnabled ?? true);
        setContentVisibility(data.contentVisibility ?? true);
        setSensitiveContent(data.sensitiveContent ?? false);
        setLanguagePreference(data.languagePreference ?? 'en');
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

      const ref = doc(db, 'users', user.uid, 'contentSettings', 'main');
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
    <div className="content-preferences-container">
      <div className="section">
        <h2>Playback</h2>
        <p className="subtitle">Control how content plays</p>

        <div className="setting-card">
          <div className="setting-row">
            <div className="setting-info">
              <div className="setting-icon">▶️</div>
              <div>
                <div className="setting-title">Auto-play</div>
                <div className="setting-subtitle">Automatically play videos when browsing</div>
              </div>
            </div>
            <label className="switch">
              <input
                type="checkbox"
                checked={autoPlay}
                onChange={(e) => handleChange('autoPlay', e.target.checked, setAutoPlay)}
              />
              <span className="slider"></span>
            </label>
          </div>

          <div className="setting-row">
            <div className="setting-info">
              <div className="setting-icon">🔊</div>
              <div>
                <div className="setting-title">Sound</div>
                <div className="setting-subtitle">Enable sound by default</div>
              </div>
            </div>
            <label className="switch">
              <input
                type="checkbox"
                checked={soundEnabled}
                onChange={(e) => handleChange('soundEnabled', e.target.checked, setSoundEnabled)}
              />
              <span className="slider"></span>
            </label>
          </div>
        </div>
      </div>

      <div className="section">
        <h2>Quality & Data</h2>
        <p className="subtitle">Control video quality and data usage</p>

        <div className="setting-card">
          <div className="setting-row">
            <div className="setting-info">
              <div className="setting-icon">📹</div>
              <div>
                <div className="setting-title">Video Quality</div>
                <div className="setting-subtitle">Choose preferred video quality</div>
              </div>
            </div>
            <select
              value={videoQuality}
              onChange={(e) => handleChange('videoQuality', e.target.value, setVideoQuality)}
              className="dropdown"
            >
              <option value="auto">Auto</option>
              <option value="high">High</option>
              <option value="medium">Medium</option>
              <option value="low">Low</option>
            </select>
          </div>

          <div className="setting-row">
            <div className="setting-info">
              <div className="setting-icon">📊</div>
              <div>
                <div className="setting-title">Data Saver</div>
                <div className="setting-subtitle">Reduce data usage by lowering quality</div>
              </div>
            </div>
            <label className="switch">
              <input
                type="checkbox"
                checked={dataSaver}
                onChange={(e) => handleChange('dataSaver', e.target.checked, setDataSaver)}
              />
              <span className="slider"></span>
            </label>
          </div>
        </div>
      </div>

      <div className="section">
        <h2>Downloads</h2>
        <p className="subtitle">Control downloaded content</p>

        <div className="setting-card">
          <div className="setting-row">
            <div className="setting-info">
              <div className="setting-icon">⬇️</div>
              <div>
                <div className="setting-title">Allow Downloads</div>
                <div className="setting-subtitle">Enable downloading videos</div>
              </div>
            </div>
            <label className="switch">
              <input
                type="checkbox"
                checked={downloadEnabled}
                onChange={(e) => handleChange('downloadEnabled', e.target.checked, setDownloadEnabled)}
              />
              <span className="slider"></span>
            </label>
          </div>
        </div>
      </div>

      <div className="section">
        <h2>Content Visibility</h2>
        <p className="subtitle">Control what content appears</p>

        <div className="setting-card">
          <div className="setting-row">
            <div className="setting-info">
              <div className="setting-icon">👁️</div>
              <div>
                <div className="setting-title">Show Sensitive Content</div>
                <div className="setting-subtitle">Show sensitive or explicit content</div>
              </div>
            </div>
            <label className="switch">
              <input
                type="checkbox"
                checked={sensitiveContent}
                onChange={(e) => handleChange('sensitiveContent', e.target.checked, setSensitiveContent)}
              />
              <span className="slider"></span>
            </label>
          </div>

          <div className="setting-row">
            <div className="setting-info">
              <div className="setting-icon">🔒</div>
              <div>
                <div className="setting-title">Content Filter</div>
                <div className="setting-subtitle">Filter mature or explicit content</div>
              </div>
            </div>
            <label className="switch">
              <input
                type="checkbox"
                checked={contentVisibility}
                onChange={(e) => handleChange('contentVisibility', e.target.checked, setContentVisibility)}
              />
              <span className="slider"></span>
            </label>
          </div>
        </div>
      </div>

      <div className="section">
        <h2>Language</h2>
        <p className="subtitle">Language preferences</p>

        <div className="setting-card">
          <div className="setting-row">
            <div className="setting-info">
              <div className="setting-icon">🌐</div>
              <div>
                <div className="setting-title">Preferred Language</div>
                <div className="setting-subtitle">Set your preferred language</div>
              </div>
            </div>
            <select
              value={languagePreference}
              onChange={(e) => handleChange('languagePreference', e.target.value, setLanguagePreference)}
              className="dropdown"
            >
              <option value="en">English</option>
              <option value="es">Spanish</option>
              <option value="fr">French</option>
              <option value="de">German</option>
              <option value="it">Italian</option>
              <option value="pt">Portuguese</option>
              <option value="ja">Japanese</option>
              <option value="zh">Chinese</option>
            </select>
          </div>
        </div>
      </div>

      <div className="info-card">
        <div className="info-icon">ℹ️</div>
        <div>
          <div className="info-title">About Content Preferences</div>
          <div className="info-text">
            Customize how you view and interact with content. Adjust quality, playback, and visibility settings to match your preferences.
          </div>
        </div>
      </div>
    </div>
  );
};

export default ContentPreferences;
```

### CSS Styling

```css
/* ContentPreferences.css */

.content-preferences-container {
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
```

## Testing Checklist

- [ ] Load settings on page/view open
- [ ] Display correct current values
- [ ] Update playback toggles (auto-play, sound)
- [ ] Update video quality dropdown
- [ ] Update data saver toggle
- [ ] Update download toggle
- [ ] Update content visibility toggles
- [ ] Update language preference
- [ ] Persist changes to Firestore
- [ ] Show success message after saving
- [ ] Handle errors gracefully
- [ ] Match app UI styling
- [ ] Firestore rules working correctly

## Summary

This Content Preferences View allows users to:
1. Control playback settings (auto-play, sound)
2. Adjust video quality and data saver mode
3. Enable/disable video downloads
4. Control content visibility and filtering
5. Set language preferences

The implementation uses the `contentSettings` Firestore collection to store all content preferences in one document. Both the Flutter app and website can access the same data structure for cross-platform consistency.

