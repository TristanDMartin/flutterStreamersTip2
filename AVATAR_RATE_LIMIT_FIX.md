# Avatar Rate Limit Fix - Google CDN 429 Error

## 🐛 Problem

Your website is getting `429 (Too Many Requests)` errors when loading user avatars from Google's CDN:

```
GET https://lh3.googleusercontent.com/a/ACg8ocItf7uhhNDT91HzzB5s2Po7Dn6RBSP4vSKVjhygD32awXiOKEXT=s96-c
429 (Too Many Requests)
```

This happens because:
1. Google limits the number of requests per IP address
2. Your website loads many avatars at once (inbox, network, etc.)
3. Google's CDN blocks excessive requests
4. Avatars fail to load and show broken images

---

## ✅ Solution

We need to:
1. **Cache avatars** to reduce repeated requests
2. **Use fallback images** when avatars fail to load
3. **Store avatars in Firebase Storage** instead of using Google CDN
4. **Add proper error handling** for avatar loading

---

## Step 1: Create Avatar Component with Error Handling

Create file: `src/components/UserAvatar.jsx`

```jsx
import React, { useState } from 'react';
import './UserAvatar.css';

export function UserAvatar({ 
  avatarUrl, 
  displayName = 'User',
  size = 50,
  className = ''
}) {
  const [imageError, setImageError] = useState(false);
  const [imageLoading, setImageLoading] = useState(true);
  
  // Get first letter for fallback
  const getInitial = () => {
    return displayName?.charAt(0).toUpperCase() || '?';
  };
  
  // Check if URL is from Google CDN
  const isGoogleCDN = (url) => {
    return url && (
      url.includes('googleusercontent.com') ||
      url.includes('lh3.google') ||
      url.includes('lh4.google') ||
      url.includes('lh5.google') ||
      url.includes('lh6.google')
    );
  };
  
  // Handle image load error
  const handleError = () => {
    console.warn(`⚠️ Avatar failed to load: ${avatarUrl}`);
    setImageError(true);
    setImageLoading(false);
  };
  
  // Handle image load success
  const handleLoad = () => {
    setImageLoading(false);
    setImageError(false);
  };
  
  // Should we show the image?
  const shouldShowImage = avatarUrl && !imageError && !isGoogleCDN(avatarUrl);
  
  return (
    <div 
      className={`user-avatar ${className}`}
      style={{ width: size, height: size }}
    >
      {shouldShowImage ? (
        <>
          {imageLoading && (
            <div className="avatar-placeholder">
              {getInitial()}
            </div>
          )}
          <img
            src={avatarUrl}
            alt={displayName}
            onError={handleError}
            onLoad={handleLoad}
            style={{ display: imageLoading ? 'none' : 'block' }}
          />
        </>
      ) : (
        <div className="avatar-placeholder">
          {getInitial()}
        </div>
      )}
    </div>
  );
}
```

---

## Step 2: Create Avatar CSS

Create file: `src/components/UserAvatar.css`

```css
/* User Avatar */
.user-avatar {
  position: relative;
  border-radius: 50%;
  overflow: hidden;
  flex-shrink: 0;
}

.user-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.avatar-placeholder {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  font-weight: 600;
  font-size: 1rem;
}

/* Size variations */
.user-avatar[style*="width: 32px"] .avatar-placeholder {
  font-size: 0.9rem;
}

.user-avatar[style*="width: 40px"] .avatar-placeholder {
  font-size: 1rem;
}

.user-avatar[style*="width: 50px"] .avatar-placeholder {
  font-size: 1.2rem;
}

.user-avatar[style*="width: 120px"] .avatar-placeholder {
  font-size: 3rem;
}
```

---

## Step 3: Update InboxView to Use New Avatar Component

Update your `InboxView.tsx` or `InboxView.jsx`:

```jsx
import { UserAvatar } from '../components/UserAvatar';

// Replace all avatar img tags with:
<UserAvatar
  avatarUrl={profile.avatarURL}
  displayName={profile.displayName}
  size={50}
/>

// Example in chat item:
{filteredChats.map(chat => {
  const otherUser = getOtherUser(chat);
  const profile = otherUser.profile;
  
  return (
    <div key={chat.id} className="chat-item">
      <UserAvatar
        avatarUrl={profile.avatarURL}
        displayName={profile.displayName}
        size={50}
      />
      
      <div className="chat-info">
        <h3>{profile.displayName || 'User'}</h3>
        <p>{chat.lastMessage}</p>
      </div>
    </div>
  );
})}
```

---

## Step 4: Fix Auth Service to Store Avatars in Firebase Storage

When users sign in with Google, download their avatar and upload to Firebase Storage:

Create file: `src/services/avatarService.js`

```javascript
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { doc, updateDoc } from 'firebase/firestore';
import { storage, db } from '../firebase/config';

/**
 * Download Google avatar and upload to Firebase Storage
 */
export async function migrateGoogleAvatarToFirebase(userId, googleAvatarUrl) {
  try {
    // Skip if not a Google CDN URL
    if (!googleAvatarUrl || !googleAvatarUrl.includes('googleusercontent.com')) {
      return googleAvatarUrl;
    }
    
    console.log('📥 Migrating Google avatar to Firebase Storage...');
    
    // Download the image from Google
    const response = await fetch(googleAvatarUrl);
    if (!response.ok) {
      console.error('❌ Failed to download Google avatar:', response.status);
      return null;
    }
    
    const blob = await response.blob();
    
    // Upload to Firebase Storage
    const timestamp = Date.now();
    const fileName = `avatars/${userId}/${timestamp}_google_avatar.jpg`;
    const storageRef = ref(storage, fileName);
    
    await uploadBytes(storageRef, blob);
    console.log('✅ Avatar uploaded to Firebase Storage');
    
    // Get download URL
    const downloadURL = await getDownloadURL(storageRef);
    console.log('✅ Firebase avatar URL:', downloadURL);
    
    // Update user document with new URL
    await updateDoc(doc(db, 'users', userId), {
      avatarURL: downloadURL,
      googleAvatarURL: googleAvatarUrl // Keep original for reference
    });
    
    console.log('✅ User document updated with Firebase avatar');
    
    return downloadURL;
  } catch (error) {
    console.error('❌ Error migrating avatar:', error);
    return null;
  }
}

/**
 * Check if user needs avatar migration
 */
export async function checkAndMigrateAvatar(user) {
  try {
    const { uid, photoURL } = user;
    
    if (!photoURL) return;
    
    // Check if it's a Google CDN URL
    if (photoURL.includes('googleusercontent.com')) {
      console.log('🔄 User has Google avatar, migrating to Firebase...');
      await migrateGoogleAvatarToFirebase(uid, photoURL);
    }
  } catch (error) {
    console.error('❌ Error checking avatar:', error);
  }
}
```

---

## Step 5: Update Sign-In Flow to Migrate Avatars

Update your auth service to migrate avatars on sign-in:

```javascript
// src/services/authService.js
import { checkAndMigrateAvatar } from './avatarService';

export async function signInWithGoogle() {
  try {
    const result = await signInWithPopup(auth, googleProvider);
    const user = result.user;
    
    // Create/update user document
    await setDoc(doc(db, 'users', user.uid), {
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      username: user.email?.split('@')[0] || 'user',
      avatarURL: user.photoURL, // Will be migrated
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp()
    }, { merge: true });
    
    // Migrate Google avatar to Firebase Storage (async, don't wait)
    checkAndMigrateAvatar(user).catch(err => {
      console.error('Avatar migration failed:', err);
    });
    
    return user;
  } catch (error) {
    console.error('Sign-in error:', error);
    throw error;
  }
}
```

---

## Step 6: Add Lazy Loading for Images

For better performance, add lazy loading to avatars:

```jsx
export function UserAvatar({ 
  avatarUrl, 
  displayName = 'User',
  size = 50,
  className = '',
  lazy = true 
}) {
  const [imageError, setImageError] = useState(false);
  const [imageLoading, setImageLoading] = useState(true);
  
  // ... existing code ...
  
  return (
    <div className={`user-avatar ${className}`}>
      {shouldShowImage ? (
        <img
          src={avatarUrl}
          alt={displayName}
          onError={handleError}
          onLoad={handleLoad}
          loading={lazy ? 'lazy' : 'eager'}  // ← Add lazy loading
          style={{ display: imageLoading ? 'none' : 'block' }}
        />
      ) : (
        <div className="avatar-placeholder">
          {getInitial()}
        </div>
      )}
    </div>
  );
}
```

---

## Step 7: Add Caching with Service Worker (Optional)

For better performance, add a service worker to cache avatars:

Create file: `public/sw.js`

```javascript
// Service Worker for caching avatars
const CACHE_NAME = 'avatar-cache-v1';

self.addEventListener('fetch', (event) => {
  const { request } = event;
  
  // Only cache avatar images
  if (
    request.url.includes('firebasestorage') &&
    request.url.includes('avatars')
  ) {
    event.respondWith(
      caches.open(CACHE_NAME).then((cache) => {
        return cache.match(request).then((response) => {
          // Return cached response if found
          if (response) {
            return response;
          }
          
          // Fetch and cache new response
          return fetch(request).then((fetchResponse) => {
            if (fetchResponse.ok) {
              cache.put(request, fetchResponse.clone());
            }
            return fetchResponse;
          });
        });
      })
    );
  }
});
```

Register service worker in your app:

```javascript
// src/index.jsx
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js')
      .then(registration => {
        console.log('✅ Service Worker registered');
      })
      .catch(error => {
        console.error('❌ Service Worker registration failed:', error);
      });
  });
}
```

---

## 🔄 Migration Strategy

### For Existing Users

Run a one-time migration script to move all Google avatars to Firebase:

Create file: `scripts/migrateAvatars.js`

```javascript
import { initializeApp } from 'firebase/app';
import { getFirestore, collection, getDocs, doc, updateDoc } from 'firebase/firestore';
import { getStorage, ref, uploadBytes, getDownloadURL } from 'firebase/storage';

const firebaseConfig = {
  // Your config
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);
const storage = getStorage(app);

async function migrateAllAvatars() {
  try {
    console.log('🚀 Starting avatar migration...');
    
    const usersSnapshot = await getDocs(collection(db, 'users'));
    let migrated = 0;
    let skipped = 0;
    let failed = 0;
    
    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const userId = userDoc.id;
      const avatarURL = userData.avatarURL;
      
      // Skip if not a Google URL
      if (!avatarURL || !avatarURL.includes('googleusercontent.com')) {
        skipped++;
        continue;
      }
      
      try {
        console.log(`📥 Migrating avatar for user: ${userId}`);
        
        // Download from Google
        const response = await fetch(avatarURL);
        if (!response.ok) throw new Error('Download failed');
        
        const blob = await response.blob();
        
        // Upload to Firebase
        const fileName = `avatars/${userId}/${Date.now()}_migrated.jpg`;
        const storageRef = ref(storage, fileName);
        await uploadBytes(storageRef, blob);
        
        const downloadURL = await getDownloadURL(storageRef);
        
        // Update user document
        await updateDoc(doc(db, 'users', userId), {
          avatarURL: downloadURL,
          googleAvatarURL: avatarURL
        });
        
        migrated++;
        console.log(`✅ Migrated avatar for user: ${userId}`);
      } catch (error) {
        failed++;
        console.error(`❌ Failed to migrate avatar for ${userId}:`, error);
      }
    }
    
    console.log('\n📊 Migration Summary:');
    console.log(`✅ Migrated: ${migrated}`);
    console.log(`⏭️ Skipped: ${skipped}`);
    console.log(`❌ Failed: ${failed}`);
    console.log(`📦 Total: ${usersSnapshot.docs.length}`);
  } catch (error) {
    console.error('❌ Migration failed:', error);
  }
}

migrateAllAvatars();
```

Run the script:
```bash
node scripts/migrateAvatars.js
```

---

## 📝 Summary of Changes

### Before (Broken):
```jsx
<img src="https://lh3.googleusercontent.com/..." alt="User" />
// ❌ 429 Rate Limit Error
// ❌ Broken images
// ❌ No fallback
```

### After (Fixed):
```jsx
<UserAvatar
  avatarUrl={profile.avatarURL}
  displayName={profile.displayName}
  size={50}
/>
// ✅ Uses Firebase Storage URLs
// ✅ Fallback to initials if fails
// ✅ Lazy loading for performance
// ✅ Error handling
```

---

## ✅ Benefits

1. **No More Rate Limits** - Firebase Storage has higher limits
2. **Faster Loading** - Images cached by Firebase CDN
3. **Fallback Support** - Shows initials if image fails
4. **Better UX** - No broken images
5. **Offline Support** - Service Worker caches avatars
6. **Consistent** - Same behavior across mobile and website

---

## 🎯 Quick Fix (Immediate)

If you need an immediate fix without migration:

```jsx
// Just block Google CDN URLs and show fallback
export function UserAvatar({ avatarUrl, displayName, size }) {
  const isGoogleCDN = avatarUrl?.includes('googleusercontent.com');
  
  // Don't use Google CDN URLs at all
  if (isGoogleCDN) {
    return (
      <div className="avatar-placeholder" style={{ width: size, height: size }}>
        {displayName?.charAt(0).toUpperCase() || '?'}
      </div>
    );
  }
  
  return (
    <img 
      src={avatarUrl} 
      alt={displayName}
      onError={(e) => {
        e.target.style.display = 'none';
        e.target.nextSibling.style.display = 'flex';
      }}
    />
  );
}
```

This will immediately stop the 429 errors by not using Google CDN URLs.

---

**Implementation Time**: 1-2 hours (or 5 minutes for quick fix)  
**Difficulty**: Medium  
**Result**: No more rate limit errors, better performance! ✅

