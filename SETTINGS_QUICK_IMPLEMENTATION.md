# ⚙️ Settings & Privacy - Quick Implementation

## ⚡ **10-Minute Setup**

### **1. Add Firestore Rules**

Add these rules to your existing `firestore_rules_with_support.txt`:

```javascript
// Add before the closing braces of match /databases/{database}/documents {
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

// Blocked Users
match /users/{userId}/blockedUsers/{blockedUserId} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow create: if request.auth != null && request.auth.uid == userId;
  allow delete: if request.auth != null && request.auth.uid == userId;
}

// Login History
match /users/{userId}/loginHistory/{sessionId} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow write: if request.auth != null && request.auth.uid == userId;
}

// Two-Factor Settings
match /users/{userId}/twoFactorSettings/{settingsId} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow write: if request.auth != null && request.auth.uid == userId;
}

// Security Questions
match /users/{userId}/securityQuestions/{questionId} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow write: if request.auth != null && request.auth.uid == userId;
}

// Content Preferences
match /users/{userId}/contentPreferences/{preferenceId} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow write: if request.auth != null && request.auth.uid == userId;
}
```

### **2. Apply to Firebase**
1. Open `firestore_rules_with_support.txt`
2. Add the rules above before the closing `}`
3. Copy entire file
4. Go to Firebase Console → Firestore → Rules
5. Paste and Publish

### **3. Flutter App (Already Done!)**
- ✅ Settings view exists
- ✅ Privacy settings views exist
- ✅ Notification settings exist
- ✅ All navigation working

### **4. Website Implementation**

#### **Install Firebase**
```bash
npm install firebase
```

#### **Initialize Firebase**
```javascript
// firebase-config.js
import { initializeApp } from 'firebase/app';
import { getFirestore } from 'firebase/firestore';
import { getAuth } from 'firebase/auth';

const config = {
  apiKey: "your-api-key",
  projectId: "streamerstip-6cfdb",
  // ... other config
};

export const app = initializeApp(config);
export const db = getFirestore(app);
export const auth = getAuth(app);
```

#### **Update Privacy Settings**
```javascript
import { doc, setDoc } from 'firebase/firestore';
import { db, auth } from './firebase-config';

async function updatePrivacySetting(key, value) {
  const user = auth.currentUser;
  if (!user) return;
  
  await setDoc(
    doc(db, 'users', user.uid, 'privacySettings', 'main'),
    { [key]: value },
    { merge: true }
  );
}

// Usage
updatePrivacySetting('profileVisibility', 'private');
updatePrivacySetting('allowMentions', 'followers');
```

#### **Update Notification Settings**
```javascript
async function updateNotificationSetting(key, value) {
  const user = auth.currentUser;
  if (!user) return;
  
  await setDoc(
    doc(db, 'users', user.uid, 'notificationSettings', 'main'),
    { [key]: value },
    { merge: true }
  );
}

// Usage
updateNotificationSetting('pushEnabled', true);
updateNotificationSetting('newFollower', false);
```

---

## 📊 **Data Structure**

### **Privacy Settings**
```javascript
users/{userId}/privacySettings/main {
  profileVisibility: "public",  // public | followers | private
  videoPrivacy: "public",
  allowMentions: "everyone",   // everyone | followers | nobody
  allowTags: true,
  allowFollowers: true,
  showEmail: false,
  showPhone: false,
  allowMessagesFrom: "everyone",
}
```

### **Notification Settings**
```javascript
users/{userId}/notificationSettings/main {
  pushEnabled: true,
  emailEnabled: false,
  newFollower: true,
  newLike: true,
  newComment: true,
  newMessage: true,
  mentions: true,
  tags: true,
}
```

### **Content Preferences**
```javascript
users/{userId}/contentPreferences/main {
  language: "en",
  restrictedMode: false,
  autoPlay: true,
  downloadOverWifiOnly: true,
}
```

---

## 🎯 **Quick Usage Examples**

### **Flutter - Update Privacy**
```dart
Future<void> updatePrivacySetting(String key, dynamic value) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  
  await FirebaseFirestore.instance
    .collection('users')
    .doc(user.uid)
    .collection('privacySettings')
    .doc('main')
    .set({key: value}, SetOptions(merge: true));
}
```

### **Website - Read Settings**
```javascript
import { doc, onSnapshot } from 'firebase/firestore';
import { useEffect, useState } from 'react';

function useSettings() {
  const [settings, setSettings] = useState({});
  
  useEffect(() => {
    const user = auth.currentUser;
    if (!user) return;
    
    const unsubscribe = onSnapshot(
      doc(db, 'users', user.uid, 'notificationSettings', 'main'),
      (doc) => setSettings(doc.data() || {})
    );
    
    return () => unsubscribe();
  }, []);
  
  return settings;
}
```

### **Website - Toggle Notification**
```javascript
function NotificationToggle({ setting }) {
  const settings = useSettings();
  const [loading, setLoading] = useState(false);
  
  const toggle = async () => {
    setLoading(true);
    await updateNotificationSetting(setting, !settings[setting]);
    setLoading(false);
  };
  
  return (
    <div>
      <label>
        {setting}
        <input
          type="checkbox"
          checked={settings[setting] || false}
          onChange={toggle}
          disabled={loading}
        />
      </label>
    </div>
  );
}
```

---

## ✅ **Test It**

### **1. Update in Flutter App**
1. Open Settings → Privacy
2. Toggle "Profile Visibility"
3. **Expected**: Changes instantly

### **2. Check Website**
1. Open website settings
2. **Expected**: Same setting value
3. Toggle notification setting
4. **Expected**: Updates instantly

### **3. Check in Flutter Again**
1. Go back to app
2. **Expected**: Website changes reflected

---

## 🚀 **Ready!**

Your Settings & Privacy now works on:
- ✅ iOS
- ✅ Android
- ✅ Flutter Web
- ✅ Separate Website

All platforms sync in real-time! 🎉

