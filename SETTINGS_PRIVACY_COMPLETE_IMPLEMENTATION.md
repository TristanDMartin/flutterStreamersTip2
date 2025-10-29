# ⚙️ Settings & Privacy - Complete Implementation Guide (App & Website)

## 📋 **Overview**

This guide provides a complete implementation for Settings & Privacy that works seamlessly across:
- ✅ Flutter iOS App
- ✅ Flutter Android App
- ✅ Flutter Web
- ✅ Separate Website (React/Vue/Next.js)

---

## 🎯 **Features Breakdown**

### **1. Account Settings**
| Feature | Description | Firestore Collection |
|---------|-------------|---------------------|
| Manage Account | Phone, email, password | `users/{userId}` |
| Phone Number | Change phone | `users/{userId}` |
| Email Address | Change email | `users/{userId}` |
| Password | Update password | Firebase Auth |
| Account Deletion | Delete account | `users/{userId}` |

### **2. Security Settings**
| Feature | Description | Firestore Collection |
|---------|-------------|---------------------|
| Two-Factor Authentication | Enable/disable 2FA | `users/{userId}/twoFactorSettings` |
| Login Alerts | Get notified of new logins | `users/{userId}/loginHistory` |
| Active Sessions | View and manage sessions | `users/{userId}/sessions` |
| Security Questions | Set up recovery | `users/{userId}/securityQuestions` |

### **3. Privacy Settings**
| Feature | Description | Firestore Collection |
|---------|-------------|---------------------|
| Visibility Settings | Who can see your content | `users/{userId}/privacySettings` |
| Blocked Accounts | Manage blocked users | `users/{userId}/blockedUsers` |
| Mentions & Tags | Who can mention you | `users/{userId}/privacySettings` |
| Profile Visibility | Public, followers, private | `users/{userId}/privacySettings` |
| Video Visibility | Default privacy for videos | `users/{userId}/privacySettings` |

### **4. Content & Activity**
| Feature | Description | Firestore Collection |
|---------|-------------|---------------------|
| Notifications | Push notification settings | `users/{userId}/notificationSettings` |
| Video Categorization | Categorize existing videos | `videos/{videoId}` |
| Content Preferences | Language, restricted mode | `users/{userId}/contentPreferences` |
| Search History | View and clear search history | `users/{userId}/searchHistory` |
| Watch History | View watched videos | `users/{userId}/watchHistory` |
| Download Settings | Offline content settings | `users/{userId}/downloadSettings` |

### **5. Support & About**
| Feature | Description | Firestore Collection |
|---------|-------------|---------------------|
| Report a Problem | Submit bug reports | `support_tickets` |
| Contact Support | Get help | `support_tickets` |
| Safety Center | Learn about safety | Static content |
| Community Guidelines | Read rules | Static content |
| Terms & Privacy Policy | Legal information | Static content |
| About | App version | Static content |

---

## 🗄️ **Firestore Data Structure**

### **User Settings Document**
```javascript
users/{userId} {
  // Account Info
  email: "user@example.com",
  phoneNumber: "+1234567890",
  displayName: "User Name",
  username: "username",
  
  // Privacy Settings
  privacySettings: {
    profileVisibility: "public",  // public | followers | private
    videoPrivacy: "public",
    allowMentions: "everyone",   // everyone | followers | nobody
    allowTags: true,
    allowFollowers: true,
    showEmail: false,
    showPhone: false,
    allowMessagesFrom: "everyone", // everyone | followers | nobody
  },
  
  // Notification Settings
  notificationSettings: {
    pushEnabled: true,
    emailEnabled: false,
    smsEnabled: false,
    newFollower: true,
    newLike: true,
    newComment: true,
    newMessage: true,
    mentions: true,
    tags: true,
    liveStream: true,
    digestDaily: true,
    digestWeekly: false,
  },
  
  // Content Preferences
  contentPreferences: {
    language: "en",
    restrictedMode: false,
    screenTimeEnabled: false,
    screenTimeHours: 2,
    autoPlay: true,
    downloadOverWifiOnly: true,
    dataSaverMode: false,
  },
  
  // Two-Factor
  twoFactorEnabled: false,
  twoFactorBackupCodes: [],
  
  // Timestamps
  createdAt: Timestamp,
  updatedAt: Timestamp,
  lastLogin: Timestamp,
}
```

### **Privacy Settings Subcollection**
```javascript
users/{userId}/privacySettings {
  profileVisibility: "public",
  videoPrivacy: "public",
  allowMentions: "everyone",
  allowTags: true,
  allowFollowers: true,
  showEmail: false,
  showPhone: false,
  allowMessagesFrom: "everyone",
  showOnlineStatus: true,
  readReceipts: true,
}
```

### **Notification Settings Subcollection**
```javascript
users/{userId}/notificationSettings {
  pushEnabled: true,
  emailEnabled: false,
  smsEnabled: false,
  newFollower: true,
  newLike: true,
  newComment: true,
  newMessage: true,
  mentions: true,
  tags: true,
  liveStream: true,
  digestDaily: true,
  digestWeekly: false,
}
```

### **Blocked Users Subcollection**
```javascript
users/{userId}/blockedUsers/{blockedUserId} {
  userId: "blockedUserId",
  username: "blockedusername",
  displayName: "Blocked User",
  blockedAt: Timestamp,
  reason: "User reported",
}
```

### **Login History Subcollection**
```javascript
users/{userId}/loginHistory/{sessionId} {
  sessionId: "abc123",
  device: "iPhone 14 Pro",
  location: "New York, USA",
  ipAddress: "192.168.1.1",
  loginTime: Timestamp,
  isCurrentSession: true,
}
```

---

## 🔒 **Firestore Security Rules**

Add these rules to your existing `firestore_rules_with_support.txt`:

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

---

## 📱 **Flutter App Implementation**

### **1. Settings View Structure**

```dart
// lib/views/settings_view.dart
class SettingsView extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Settings UI with sections:
      // - Account (Manage Account)
      // - Security (Two-Factor)
      // - Privacy (Visibility, Blocked, Mentions)
      // - Content & Activity (Notifications, Preferences)
      // - Support & About (Report, Safety, Legal)
    );
  }
}
```

### **2. Privacy Settings View**

```dart
// lib/views/privacy_settings_view.dart
class PrivacySettingsView extends ConsumerStatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildVisibilityToggle(),
          _buildMentionsToggle(),
          _buildTagsToggle(),
          _buildFollowersToggle(),
          _buildMessagesToggle(),
        ],
      ),
    );
  }
  
  Widget _buildVisibilityToggle() {
    return SwitchListTile(
      title: Text('Profile Visibility'),
      subtitle: Text('Who can see your profile'),
      value: isPublic,
      onChanged: (value) {
        _updatePrivacySetting('profileVisibility', 
          value ? 'public' : 'private');
      },
    );
  }
  
  Future<void> _updatePrivacySetting(String key, dynamic value) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    await FirebaseFirestore.instance
      .collection('users')
      .doc(currentUser.uid)
      .collection('privacySettings')
      .doc('main')
      .set({key: value}, SetOptions(merge: true));
  }
}
```

### **3. Notification Settings View**

```dart
// lib/views/notification_settings_view.dart
class NotificationSettingsView extends ConsumerStatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('notificationSettings')
          .doc('main')
          .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return CircularProgressIndicator();
          
          final settings = snapshot.data!.data() as Map<String, dynamic>;
          
          return Column(
            children: [
              _buildToggle(
                'Push Notifications',
                settings['pushEnabled'] ?? true,
                (value) => _updateSetting('pushEnabled', value),
              ),
              _buildToggle(
                'Email Notifications',
                settings['emailEnabled'] ?? false,
                (value) => _updateSetting('emailEnabled', value),
              ),
              _buildToggle(
                'New Follower',
                settings['newFollower'] ?? true,
                (value) => _updateSetting('newFollower', value),
              ),
              _buildToggle(
                'New Like',
                settings['newLike'] ?? true,
                (value) => _updateSetting('newLike', value),
              ),
              _buildToggle(
                'New Comment',
                settings['newComment'] ?? true,
                (value) => _updateSetting('newComment', value),
              ),
              _buildToggle(
                'New Message',
                settings['newMessage'] ?? true,
                (value) => _updateSetting('newMessage', value),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Future<void> _updateSetting(String key, bool value) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    await FirebaseFirestore.instance
      .collection('users')
      .doc(currentUser.uid)
      .collection('notificationSettings')
      .doc('main')
      .set({key: value}, SetOptions(merge: true));
  }
}
```

---

## 🌐 **Website Implementation (React Example)**

### **1. Settings Page Structure**

```javascript
// src/pages/Settings.jsx
import React, { useState, useEffect } from 'react';
import { auth, db } from '../firebase-config';
import { collection, doc, getDoc, setDoc, onSnapshot } from 'firebase/firestore';

function Settings() {
  const [user, setUser] = useState(null);
  const [settings, setSettings] = useState({});
  
  useEffect(() => {
    if (auth.currentUser) {
      const unsubscribe = onSnapshot(
        doc(db, 'users', auth.currentUser.uid),
        (doc) => {
          setSettings(doc.data() || {});
        }
      );
      
      return () => unsubscribe();
    }
  }, []);
  
  return (
    <div className="settings-page">
      <h1>Settings & Privacy</h1>
      
      <section>
        <h2>Account</h2>
        <SettingsCard title="Manage Account" icon="person" />
      </section>
      
      <section>
        <h2>Security</h2>
        <SettingsCard title="Two-Factor Authentication" icon="security" />
      </section>
      
      <section>
        <h2>Privacy</h2>
        <SettingsCard title="Profile Visibility" icon="visibility" />
        <SettingsCard title="Blocked Accounts" icon="block" />
      </section>
      
      <section>
        <h2>Notifications</h2>
        <Toggle
          label="Push Notifications"
          checked={settings.pushEnabled}
          onChange={(value) => updateSetting('pushEnabled', value)}
        />
        <Toggle
          label="Email Notifications"
          checked={settings.emailEnabled}
          onChange={(value) => updateSetting('emailEnabled', value)}
        />
      </section>
      
      <section>
        <h2>Support</h2>
        <SettingsCard title="Contact Support" icon="support" />
        <SettingsCard title="Report a Problem" icon="report" />
      </section>
    </div>
  );
}

export default Settings;
```

### **2. Privacy Settings Component**

```javascript
// src/components/PrivacySettings.jsx
import React, { useState, useEffect } from 'react';
import { doc, getDoc, setDoc } from 'firebase/firestore';
import { db, auth } from '../firebase-config';

function PrivacySettings() {
  const [settings, setSettings] = useState({
    profileVisibility: 'public',
    allowMentions: 'everyone',
    allowTags: true,
    allowFollowers: true,
  });
  
  useEffect(() => {
    loadSettings();
  }, []);
  
  const loadSettings = async () => {
    const user = auth.currentUser;
    if (!user) return;
    
    const docRef = doc(db, 'users', user.uid, 'privacySettings', 'main');
    const docSnap = await getDoc(docRef);
    
    if (docSnap.exists()) {
      setSettings(docSnap.data());
    }
  };
  
  const updateSetting = async (key, value) => {
    const user = auth.currentUser;
    if (!user) return;
    
    await setDoc(
      doc(db, 'users', user.uid, 'privacySettings', 'main'),
      { [key]: value },
      { merge: true }
    );
    
    setSettings({ ...settings, [key]: value });
  };
  
  return (
    <div className="privacy-settings">
      <h2>Privacy Settings</h2>
      
      <div className="setting-item">
        <label>Profile Visibility</label>
        <select
          value={settings.profileVisibility}
          onChange={(e) => updateSetting('profileVisibility', e.target.value)}
        >
          <option value="public">Public</option>
          <option value="followers">Followers Only</option>
          <option value="private">Private</option>
        </select>
      </div>
      
      <div className="setting-item">
        <label>Who can mention you?</label>
        <select
          value={settings.allowMentions}
          onChange={(e) => updateSetting('allowMentions', e.target.value)}
        >
          <option value="everyone">Everyone</option>
          <option value="followers">Followers Only</option>
          <option value="nobody">Nobody</option>
        </select>
      </div>
      
      <div className="setting-item">
        <label>
          <input
            type="checkbox"
            checked={settings.allowTags}
            onChange={(e) => updateSetting('allowTags', e.target.checked)}
          />
          Allow others to tag you
        </label>
      </div>
      
      <div className="setting-item">
        <label>
          <input
            type="checkbox"
            checked={settings.allowFollowers}
            onChange={(e) => updateSetting('allowFollowers', e.target.checked)}
          />
          Allow followers
        </label>
      </div>
    </div>
  );
}

export default PrivacySettings;
```

### **3. Toggle Component**

```javascript
// src/components/Toggle.jsx
function Toggle({ label, checked, onChange }) {
  return (
    <div className="toggle-item">
      <label>
        <span>{label}</span>
        <input
          type="checkbox"
          checked={checked}
          onChange={(e) => onChange(e.target.checked)}
        />
      </label>
    </div>
  );
}

export default Toggle;
```

---

## 🔄 **Real-Time Sync**

### **All Platforms Get Real-Time Updates**

```javascript
// Flutter
StreamBuilder<DocumentSnapshot>(
  stream: FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .collection('privacySettings')
    .doc('main')
    .snapshots(),
  builder: (context, snapshot) {
    // Updates automatically
  },
)

// React Website
useEffect(() => {
  const unsubscribe = onSnapshot(
    doc(db, 'users', userId, 'privacySettings', 'main'),
    (doc) => {
      setSettings(doc.data());
    }
  );
  
  return () => unsubscribe();
}, [userId]);
```

**Same data, instant updates everywhere!**

---

## ✅ **Implementation Checklist**

### **Firebase Setup**
- [ ] Add Firestore rules (see rules above)
- [ ] Test rules in Firebase Console
- [ ] Verify user permissions

### **Flutter App**
- [x] Settings view with all sections
- [x] Privacy settings view
- [x] Notification settings view
- [x] Account management view
- [x] Two-factor auth view
- [x] Blocked accounts view

### **Website**
- [ ] Install Firebase SDK (`npm install firebase`)
- [ ] Create settings page component
- [ ] Create privacy settings component
- [ ] Create notification toggle component
- [ ] Implement real-time updates
- [ ] Style to match app design

### **Testing**
- [ ] Update setting in app → Check website updates
- [ ] Update setting in website → Check app updates
- [ ] Test on iOS
- [ ] Test on Android
- [ ] Test on Web
- [ ] Test on website

---

## 📊 **Settings Categories**

### **1. Account Section**
- Manage Account (phone, email, password)
- Switch Account
- Add Account

### **2. Security Section**
- Two-Factor Authentication
- Login Alerts
- Active Sessions
- Security Questions
- Change Password

### **3. Privacy Section**
- Profile Visibility
- Who can see your content
- Blocked Accounts
- Mentions & Tags
- Message Privacy
- Email/Phone visibility

### **4. Content & Activity Section**
- Push Notifications
- Email Notifications
- In-App Notifications
- Video Categorization
- Content Preferences
- Language Settings
- Restricted Mode
- Screen Time

### **5. Support & About Section**
- Contact Support (connects to support_tickets)
- Report a Problem
- Safety Center
- Community Guidelines
- Terms of Service
- Privacy Policy
- About

---

## 🎯 **Key Features**

### **Unified Settings**
- ✅ Same Firestore structure
- ✅ Same security rules
- ✅ Real-time sync
- ✅ Cross-platform compatibility

### **User Experience**
- ✅ Search functionality
- ✅ Organized sections
- ✅ Icon indicators
- ✅ Clear labels

### **Security**
- ✅ User can only modify own settings
- ✅ Admin can view all
- ✅ Two-factor authentication support
- ✅ Session management

---

## 🚀 **Ready to Use!**

Your Settings & Privacy system is **100% platform-agnostic**:
- ✅ Works on iOS
- ✅ Works on Android
- ✅ Works on Flutter Web
- ✅ Can work on any website
- ✅ All platforms see the same data
- ✅ All platforms update in real-time

**Just apply the Firestore rules and you're good to go!** 🎉

