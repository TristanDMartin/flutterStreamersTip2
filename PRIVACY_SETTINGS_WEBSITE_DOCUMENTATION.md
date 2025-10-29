# 🔒 Privacy Settings - Website Documentation

## 📋 **Complete Feature List**

This document provides all the content from the Privacy Settings view so you can replicate it exactly on your website.

---

## 🎯 **Four Main Sections**

### **1. Profile** - Control who can see your profile
### **2. Content** - Control video visibility  
### **3. Social** - Control mentions, tags, and messages
### **4. Activity** - Control activity visibility

---

## 📱 **UI Structure**

### **App Bar**
```dart
AppBar(
  backgroundColor: Colors.transparent,
  elevation: 0,
  leading: IconButton(
    icon: Icons.arrow_back,
    onPressed: () => Navigator.pop(),
  ),
  title: Text('Privacy Settings'),
)
```

### **Body Layout**
```dart
SingleChildScrollView(
  padding: EdgeInsets.all(24),
  child: Column({
    _buildSection('Profile', [...]),
    SizedBox(height: 32),
    _buildSection('Content', [...]),
    SizedBox(height: 32),
    _buildSection('Social', [...]),
    SizedBox(height: 32),
    _buildSection('Activity', [...]),
  }),
)
```

---

## 📊 **Section 1: Profile**

### **Setting 1: Profile Visibility**
```javascript
DropdownSetting({
  icon: "visibility",
  title: "Profile Visibility",
  subtitle: "Who can see your profile",
  value: "public", // Options: public | followers | private
  options: ["public", "followers", "private"],
  onChanged: (value) => updateSetting('profileVisibility', value)
})
```

**Options**:
- `public` - Everyone can see your profile
- `followers` - Only followers can see your profile
- `private` - Only you can see your profile

---

### **Setting 2: Allow Followers**
```javascript
SwitchSetting({
  icon: "people_outline",
  title: "Allow Followers",
  subtitle: "Let people follow your account",
  value: true,
  onChanged: (value) => updateSetting('allowFollowers', value)
})
```

---

## 📊 **Section 2: Content**

### **Setting: Video Privacy**
```javascript
DropdownSetting({
  icon: "video_library",
  title: "Video Privacy",
  subtitle: "Default privacy for new videos",
  value: "public", // Options: public | followers | private
  options: ["public", "followers", "private"],
  onChanged: (value) => updateSetting('videoPrivacy', value)
})
```

---

## 📊 **Section 3: Social**

### **Setting 1: Mentions**
```javascript
DropdownSetting({
  icon: "alternate_email",
  title: "Mentions",
  subtitle: "Who can mention you",
  value: "everyone", // Options: everyone | followers | nobody
  options: ["everyone", "followers", "nobody"],
  onChanged: (value) => updateSetting('allowMentions', value)
})
```

**Options**:
- `everyone` - Anyone can mention you
- `followers` - Only followers can mention you
- `nobody` - No one can mention you

---

### **Setting 2: Allow Tags**
```javascript
SwitchSetting({
  icon: "label_outline",
  title: "Allow Tags",
  subtitle: "Let people tag you",
  value: true,
  onChanged: (value) => updateSetting('allowTags', value)
})
```

---

### **Setting 3: Messages**
```javascript
DropdownSetting({
  icon: "message_outlined",
  title: "Messages",
  subtitle: "Who can send you messages",
  value: "everyone", // Options: everyone | followers | nobody
  options: ["everyone", "followers", "nobody"],
  onChanged: (value) => updateSetting('allowMessagesFrom', value)
})
```

---

## 📊 **Section 4: Activity**

### **Setting 1: Show Online Status**
```javascript
SwitchSetting({
  icon: "circle",
  title: "Show Online Status",
  subtitle: "Let others see when you're online",
  value: true,
  onChanged: (value) => updateSetting('showOnlineStatus', value)
})
```

---

### **Setting 2: Read Receipts**
```javascript
SwitchSetting({
  icon: "done_all",
  title: "Read Receipts",
  subtitle: "Let others know when you've read their messages",
  value: true,
  onChanged: (value) => updateSetting('readReceipts', value)
})
```

---

## 🗄️ **Firestore Data Structure**

### **Privacy Settings Document**
```javascript
users/{userId}/privacySettings/main {
  profileVisibility: "public",         // public | followers | private
  videoPrivacy: "public",              // public | followers | private
  allowMentions: "everyone",          // everyone | followers | nobody
  allowTags: true,                     // boolean
  allowFollowers: true,                // boolean
  showEmail: false,                    // boolean
  showPhone: false,                    // boolean
  allowMessagesFrom: "everyone",      // everyone | followers | nobody
  showOnlineStatus: true,             // boolean
  readReceipts: true,                 // boolean
}
```

---

## 🌐 **Website Implementation (React)**

### **Component Structure**
```javascript
import { useEffect, useState } from 'react';
import { doc, getDoc, setDoc } from 'firebase/firestore';
import { db, auth } from '../firebase-config';

function PrivacySettingsView() {
  const [settings, setSettings] = useState({
    profileVisibility: 'public',
    videoPrivacy: 'public',
    allowMentions: 'everyone',
    allowTags: true,
    allowFollowers: true,
    allowMessagesFrom: 'everyone',
    showOnlineStatus: true,
    readReceipts: true,
  });
  
  const [loading, setLoading] = useState(true);
  
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
    setLoading(false);
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
  
  if (loading) {
    return <LoadingSpinner />;
  }
  
  return (
    <div className="privacy-settings-container">
      <h1>Privacy Settings</h1>
      
      <Section title="Profile">
        <DropdownSetting
          icon="visibility"
          title="Profile Visibility"
          subtitle="Who can see your profile"
          value={settings.profileVisibility}
          options={['public', 'followers', 'private']}
          onChange={(value) => updateSetting('profileVisibility', value)}
        />
        
        <SwitchSetting
          icon="people_outline"
          title="Allow Followers"
          subtitle="Let people follow your account"
          value={settings.allowFollowers}
          onChange={(value) => updateSetting('allowFollowers', value)}
        />
      </Section>
      
      <Section title="Content">
        <DropdownSetting
          icon="video_library"
          title="Video Privacy"
          subtitle="Default privacy for new videos"
          value={settings.videoPrivacy}
          options={['public', 'followers', 'private']}
          onChange={(value) => updateSetting('videoPrivacy', value)}
        />
      </Section>
      
      <Section title="Social">
        <DropdownSetting
          icon="alternate_email"
          title="Mentions"
          subtitle="Who can mention you"
          value={settings.allowMentions}
          options={['everyone', 'followers', 'nobody']}
          onChange={(value) => updateSetting('allowMentions', value)}
        />
        
        <SwitchSetting
          icon="label_outline"
          title="Allow Tags"
          subtitle="Let people tag you"
          value={settings.allowTags}
          onChange={(value) => updateSetting('allowTags', value)}
        />
        
        <DropdownSetting
          icon="message_outlined"
          title="Messages"
          subtitle="Who can send you messages"
          value={settings.allowMessagesFrom}
          options={['everyone', 'followers', 'nobody']}
          onChange={(value) => updateSetting('allowMessagesFrom', value)}
        />
      </Section>
      
      <Section title="Activity">
        <SwitchSetting
          icon="circle"
          title="Show Online Status"
          subtitle="Let others see when you're online"
          value={settings.showOnlineStatus}
          onChange={(value) => updateSetting('showOnlineStatus', value)}
        />
        
        <SwitchSetting
          icon="done_all"
          title="Read Receipts"
          subtitle="Let others know when you've read their messages"
          value={settings.readReceipts}
          onChange={(value) => updateSetting('readReceipts', value)}
        />
      </Section>
    </div>
  );
}
```

### **Section Component**
```javascript
function Section({ title, children }) {
  return (
    <div className="privacy-section">
      <h2>{title}</h2>
      <div className="settings-card">
        {children}
      </div>
    </div>
  );
}
```

### **Dropdown Setting Component**
```javascript
function DropdownSetting({ icon, title, subtitle, value, options, onChange }) {
  return (
    <div className="setting-item">
      <div className="setting-header">
        <Icon name={icon} />
        <div className="setting-info">
          <h3>{title}</h3>
          <p>{subtitle}</p>
        </div>
      </div>
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
      >
        {options.map(option => (
          <option key={option} value={option}>
            {option.charAt(0).toUpperCase() + option.slice(1)}
          </option>
        ))}
      </select>
    </div>
  );
}
```

### **Switch Setting Component**
```javascript
function SwitchSetting({ icon, title, subtitle, value, onChange }) {
  return (
    <div className="setting-item">
      <div className="setting-header">
        <Icon name={icon} />
        <div className="setting-info">
          <h3>{title}</h3>
          <p>{subtitle}</p>
        </div>
      </div>
      <input
        type="checkbox"
        checked={value}
        onChange={(e) => onChange(e.target.checked)}
      />
    </div>
  );
}
```

---

## 🎨 **Styling**

### **Container Styles**
```css
.privacy-settings-container {
  max-width: 800px;
  margin: 0 auto;
  padding: 24px;
  background: linear-gradient(to bottom right, #6137EB, #1C135D);
  min-height: 100vh;
}

.privacy-section {
  margin-bottom: 32px;
}

.privacy-section h2 {
  color: white;
  font-size: 20px;
  font-weight: bold;
  margin-bottom: 16px;
}

.settings-card {
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 16px;
  padding: 0;
}
```

### **Setting Item Styles**
```css
.setting-item {
  padding: 20px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.setting-item:last-child {
  border-bottom: none;
}

.setting-header {
  display: flex;
  align-items: center;
  flex: 1;
}

.setting-header .icon {
  width: 36px;
  height: 36px;
  background: rgba(255, 255, 255, 0.1);
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-right: 16px;
}

.setting-info h3 {
  color: white;
  font-size: 16px;
  font-weight: 600;
  margin: 0;
}

.setting-info p {
  color: rgba(255, 255, 255, 0.7);
  font-size: 12px;
  margin: 2px 0 0 0;
}

.setting-item select {
  padding: 8px 12px;
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 8px;
  color: white;
  font-size: 14px;
}

.setting-item input[type="checkbox"] {
  width: 48px;
  height: 28px;
  cursor: pointer;
}
```

---

## 📋 **Complete Settings Reference**

### **Profile Section**
1. **Profile Visibility** - `profileVisibility`
   - Options: `public` | `followers` | `private`
2. **Allow Followers** - `allowFollowers`
   - Type: boolean

### **Content Section**
1. **Video Privacy** - `videoPrivacy`
   - Options: `public` | `followers` | `private`

### **Social Section**
1. **Mentions** - `allowMentions`
   - Options: `everyone` | `followers` | `nobody`
2. **Allow Tags** - `allowTags`
   - Type: boolean
3. **Messages** - `allowMessagesFrom`
   - Options: `everyone` | `followers` | `nobody`

### **Activity Section**
1. **Show Online Status** - `showOnlineStatus`
   - Type: boolean
2. **Read Receipts** - `readReceipts`
   - Type: boolean

---

## 🎨 **Color Scheme**

### **Background**
- Primary: `#1C135D` (Dark Purple)
- Gradient: Linear gradient from `#6137EB` to `#1C135D`
- Cards: `rgba(255, 255, 255, 0.1)` (White with 10% opacity)
- Borders: `rgba(255, 255, 255, 0.2)` (White with 20% opacity)

### **Text Colors**
- Primary: `#FFFFFF` (White)
- Secondary: `rgba(255, 255, 255, 0.7)` (White with 70% opacity)

### **Accent**
- Purple: `#9248D2` (Switch active color)

---

## ✅ **Ready to Implement!**

All content from the Flutter app's Privacy Settings view is documented above. Use this to create an exact match on your website! 🎉

