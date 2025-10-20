# Website Streamer Page - Add Platforms Tab 🔗

## 🎯 Goal
Add a "Platforms" tab to the streamer page, positioned before the Calendar tab.

---

## 📋 Tab Order

```
[Videos] [Favorites] [Platforms] [📅 Calendar]
                        ↑ NEW!
```

---

## Step 1: Update Streamer Page Tabs

**File:** `src/pages/StreamerPage.jsx` (or wherever your streamer page is)

```jsx
export function StreamerPage({ streamerId }) {
  const [selectedTab, setSelectedTab] = useState('videos');
  
  return (
    <div className="streamer-page">
      {/* Header... */}
      
      {/* ✅ UPDATED TABS - Added Platforms */}
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
        
        {/* ✨ NEW PLATFORMS TAB */}
        <button 
          className={selectedTab === 'platforms' ? 'active' : ''}
          onClick={() => setSelectedTab('platforms')}
        >
          🔗 Platforms
        </button>
        
        <button 
          className={selectedTab === 'calendar' ? 'active' : ''}
          onClick={() => setSelectedTab('calendar')}
        >
          📅 Calendar
        </button>
      </div>
      
      {/* ✅ UPDATED CONTENT - Added Platforms Tab */}
      <div className="streamer-content">
        {selectedTab === 'videos' && <VideosTab userId={streamerId} />}
        {selectedTab === 'favorites' && <FavoritesTab userId={streamerId} />}
        {selectedTab === 'platforms' && <PlatformsTab userId={streamerId} />}
        {selectedTab === 'calendar' && <StreamerCalendarTab userId={streamerId} />}
      </div>
    </div>
  );
}
```

---

## Step 2: Create Platforms Tab Component

**Create file:** `src/components/PlatformsTab.jsx`

```jsx
import React, { useState, useEffect } from 'react';
import { doc, getDoc, onSnapshot } from 'firebase/firestore';
import { db } from '../firebase/config';
import './PlatformsTab.css';

export function PlatformsTab({ userId }) {
  const [platforms, setPlatforms] = useState([]);
  const [loading, setLoading] = useState(true);

  // Real-time listener for platforms
  useEffect(() => {
    if (!userId) {
      setLoading(false);
      return;
    }

    console.log('👂 Setting up real-time listener for platforms:', userId);

    // Subscribe to user document changes
    const unsubscribe = onSnapshot(
      doc(db, 'users', userId),
      (docSnap) => {
        if (docSnap.exists()) {
          const data = docSnap.data();
          const userPlatforms = data.platforms || [];
          console.log('📡 Platforms updated:', userPlatforms.length);
          setPlatforms(userPlatforms);
        } else {
          setPlatforms([]);
        }
        setLoading(false);
      },
      (error) => {
        console.error('❌ Error listening to platforms:', error);
        setLoading(false);
      }
    );

    return () => unsubscribe();
  }, [userId]);

  if (loading) {
    return (
      <div className="platforms-tab">
        <div className="loading">
          <div className="spinner"></div>
          <p>Loading platforms...</p>
        </div>
      </div>
    );
  }

  if (platforms.length === 0) {
    return (
      <div className="platforms-tab">
        <div className="empty-state">
          <span className="empty-icon">🔗</span>
          <h2>No platforms added</h2>
          <p>This user hasn't connected any platforms yet</p>
        </div>
      </div>
    );
  }

  return (
    <div className="platforms-tab">
      {/* Real-time sync indicator */}
      <div className="sync-indicator">
        <span className="sync-dot"></span>
        <span className="sync-text">Live</span>
      </div>

      <div className="platforms-grid">
        {platforms.map((platform) => (
          <PlatformCard key={platform.id} platform={platform} />
        ))}
      </div>
    </div>
  );
}

function PlatformCard({ platform }) {
  const handleClick = () => {
    if (platform.url) {
      window.open(platform.url, '_blank', 'noopener,noreferrer');
    }
  };

  return (
    <div 
      className="platform-card"
      onClick={handleClick}
      style={{ cursor: platform.url ? 'pointer' : 'default' }}
    >
      <div className="platform-header">
        <div className="platform-icon">
          {getPlatformIcon(platform.type)}
        </div>
        <div className="platform-info">
          <h3 className="platform-name">{getPlatformName(platform.type)}</h3>
          <p className="platform-username">
            {platform.username || platform.url}
          </p>
        </div>
      </div>

      {platform.followers && (
        <div className="platform-followers">
          {formatFollowers(platform.followers)} followers
        </div>
      )}

      {platform.url && (
        <div className="platform-link">
          <span>Open →</span>
        </div>
      )}
    </div>
  );
}

// Helper functions
function getPlatformIcon(type) {
  const icons = {
    twitch: '🎮',
    youtube: '▶️',
    kick: '⚡',
    tiktok: '🎵',
    instagram: '📷',
    twitter: '🐦',
    discord: '💬',
    bluesky: '🦋',
    reddit: '🔴',
    facebook: '👤',
    other: '🌐'
  };
  return icons[type] || '🌐';
}

function getPlatformName(type) {
  const names = {
    twitch: 'Twitch',
    youtube: 'YouTube',
    kick: 'Kick',
    tiktok: 'TikTok',
    instagram: 'Instagram',
    twitter: 'Twitter/X',
    discord: 'Discord',
    bluesky: 'Bluesky',
    reddit: 'Reddit',
    facebook: 'Facebook',
    other: 'Website'
  };
  return names[type] || 'Platform';
}

function formatFollowers(count) {
  if (count >= 1000000) {
    return `${(count / 1000000).toFixed(1)}M`;
  } else if (count >= 1000) {
    return `${(count / 1000).toFixed(1)}K`;
  }
  return count.toString();
}
```

---

## Step 3: Create Platforms Tab CSS

**Create file:** `src/components/PlatformsTab.css`

```css
.platforms-tab {
  padding: 24px;
  max-width: 1200px;
  margin: 0 auto;
}

/* Loading state */
.loading {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 60px 20px;
  color: rgba(255, 255, 255, 0.6);
}

.spinner {
  width: 40px;
  height: 40px;
  border: 3px solid rgba(255, 255, 255, 0.2);
  border-top-color: #ffffff;
  border-radius: 50%;
  animation: spin 1s linear infinite;
  margin-bottom: 16px;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

/* Empty state */
.empty-state {
  text-align: center;
  padding: 60px 20px;
  color: rgba(255, 255, 255, 0.6);
}

.empty-icon {
  font-size: 80px;
  display: block;
  margin-bottom: 16px;
}

.empty-state h2 {
  color: #ffffff;
  font-size: 24px;
  margin-bottom: 8px;
}

.empty-state p {
  font-size: 16px;
}

/* Sync indicator */
.sync-indicator {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  background: rgba(46, 213, 115, 0.1);
  border-radius: 20px;
  margin-bottom: 24px;
  width: fit-content;
}

.sync-dot {
  width: 8px;
  height: 8px;
  background: #2ed573;
  border-radius: 50%;
  animation: pulse 2s infinite;
}

@keyframes pulse {
  0%, 100% {
    opacity: 1;
    transform: scale(1);
  }
  50% {
    opacity: 0.5;
    transform: scale(1.2);
  }
}

.sync-text {
  font-size: 12px;
  color: #2ed573;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

/* Platforms grid */
.platforms-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 16px;
}

/* Platform card */
.platform-card {
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 16px;
  padding: 20px;
  transition: all 0.2s ease;
}

.platform-card:hover {
  background: rgba(255, 255, 255, 0.15);
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
}

.platform-header {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  margin-bottom: 12px;
}

.platform-icon {
  font-size: 32px;
  width: 48px;
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.1);
  border-radius: 12px;
}

.platform-info {
  flex: 1;
}

.platform-name {
  color: #ffffff;
  font-size: 18px;
  font-weight: 700;
  margin: 0 0 4px 0;
}

.platform-username {
  color: rgba(255, 255, 255, 0.7);
  font-size: 14px;
  margin: 0;
  word-break: break-all;
}

.platform-followers {
  color: rgba(255, 255, 255, 0.6);
  font-size: 14px;
  margin-bottom: 12px;
  font-weight: 600;
}

.platform-link {
  display: flex;
  justify-content: flex-end;
  color: #955CFF;
  font-size: 14px;
  font-weight: 600;
}

.platform-link span {
  transition: transform 0.2s ease;
}

.platform-card:hover .platform-link span {
  transform: translateX(4px);
}
```

---

## Step 4: Complete Tab Integration Example

Here's the full implementation with all tabs in order:

```jsx
import React, { useState } from 'react';
import { StreamerCalendarTab } from '../components/StreamerCalendarTab';
import { PlatformsTab } from '../components/PlatformsTab';
import './StreamerPage.css';

export function StreamerPage({ streamerId }) {
  // Tab state - default to 'videos'
  const [selectedTab, setSelectedTab] = useState('videos');
  
  return (
    <div className="streamer-page">
      {/* Streamer Header */}
      <div className="streamer-header">
        <div className="streamer-avatar">
          {/* Avatar... */}
        </div>
        <div className="streamer-info">
          <h1>{displayName}</h1>
          <p>@{username}</p>
          {/* Stats... */}
        </div>
      </div>
      
      {/* ✅ TABS WITH PLATFORMS */}
      <div className="streamer-tabs">
        <button 
          className={`tab-button ${selectedTab === 'videos' ? 'active' : ''}`}
          onClick={() => setSelectedTab('videos')}
        >
          Videos
        </button>
        
        <button 
          className={`tab-button ${selectedTab === 'favorites' ? 'active' : ''}`}
          onClick={() => setSelectedTab('favorites')}
        >
          Favorites
        </button>
        
        {/* ✨ NEW - PLATFORMS TAB */}
        <button 
          className={`tab-button ${selectedTab === 'platforms' ? 'active' : ''}`}
          onClick={() => setSelectedTab('platforms')}
        >
          🔗 Platforms
        </button>
        
        <button 
          className={`tab-button ${selectedTab === 'calendar' ? 'active' : ''}`}
          onClick={() => setSelectedTab('calendar')}
        >
          📅 Calendar
        </button>
      </div>
      
      {/* ✅ TAB CONTENT WITH PLATFORMS */}
      <div className="streamer-content">
        {selectedTab === 'videos' && <VideosTab userId={streamerId} />}
        {selectedTab === 'favorites' && <FavoritesTab userId={streamerId} />}
        {selectedTab === 'platforms' && <PlatformsTab userId={streamerId} />}
        {selectedTab === 'calendar' && <StreamerCalendarTab userId={streamerId} />}
      </div>
    </div>
  );
}
```

---

## 🎨 CSS for Tabs (Optional Improvements)

```css
/* Tabs container */
.streamer-tabs {
  display: flex;
  gap: 8px;
  padding: 16px 20px;
  background: rgba(0, 0, 0, 0.2);
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
  overflow-x: auto;
}

/* Individual tab button */
.tab-button {
  flex: 0 0 auto;
  padding: 12px 24px;
  background: transparent;
  border: none;
  border-radius: 24px;
  color: rgba(255, 255, 255, 0.6);
  font-size: 16px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s ease;
  white-space: nowrap;
}

.tab-button:hover {
  background: rgba(255, 255, 255, 0.1);
  color: rgba(255, 255, 255, 0.9);
}

.tab-button.active {
  background: linear-gradient(135deg, #955CFF, #3D99F7);
  color: #ffffff;
}

/* Content area */
.streamer-content {
  padding: 20px;
}
```

---

## 🧪 Testing

### Test 1: Tab Navigation

1. Open streamer page
2. Click tabs in order:
   - Videos → Shows videos ✅
   - Favorites → Shows favorites ✅
   - **Platforms → Shows platforms** ✅ NEW!
   - Calendar → Shows calendar ✅

### Test 2: Real-Time Sync

1. Open streamer page on **Platforms tab**
2. Have streamer add a platform on mobile app
3. ✨ Platform should appear on website instantly

### Test 3: Click Platform Card

1. Go to Platforms tab
2. Click a platform card (e.g., Twitch)
3. ✨ Opens streamer's Twitch page in new tab

---

## 📊 What Platforms Tab Shows

### For Streamers with Platforms

```
🔗 Platforms                    [Live sync indicator]

┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ 🎮              │  │ ▶️              │  │ 🎵              │
│ Twitch          │  │ YouTube         │  │ TikTok          │
│ coolstreamer    │  │ @CoolStreamer   │  │ @coolstreamer   │
│ 1.2K followers  │  │ 5K followers    │  │ 850 followers   │
│         Open →  │  │         Open →  │  │         Open →  │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

### For Streamers Without Platforms

```
🔗

No platforms added
This user hasn't connected any platforms yet
```

---

## 🔥 Key Features

✅ **Real-time sync** - Updates when streamer adds platforms
✅ **Clickable cards** - Opens platform in new tab
✅ **11 platforms supported** - Twitch, YouTube, Kick, TikTok, etc.
✅ **Follower counts** - Shows formatted numbers (1.2K, 5M)
✅ **Responsive grid** - Adapts to screen size
✅ **Loading states** - Smooth loading experience
✅ **Empty states** - Helpful message when no platforms

---

## 🚀 Quick Integration (5 minutes)

1. **Create file:** `src/components/PlatformsTab.jsx` (copy code above)
2. **Create file:** `src/components/PlatformsTab.css` (copy styles above)
3. **Update:** Your streamer page tabs section
4. **Test:** Navigate to streamer page and check tabs

---

## 📁 Files to Create/Update

**New Files:**
- `src/components/PlatformsTab.jsx` - Tab component
- `src/components/PlatformsTab.css` - Tab styles

**Update:**
- Your `StreamerPage.jsx` (or equivalent) - Add platforms tab

---

## ✅ After Integration

Your streamer page will have:

```
[Videos] [Favorites] [🔗 Platforms] [📅 Calendar]
```

Users can:
- View all streamer's social platforms
- Click to visit each platform
- See follower counts
- Real-time sync with mobile app

**Total time: ~5 minutes!** 🚀

See `WEBSITE_PLATFORMS_IMPLEMENTATION.md` for more detailed platform management features.

