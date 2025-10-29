# 🔧 Manage Account - Website Documentation

## 📋 **Complete Feature List**

This document provides all the content from the Manage Account view in the app so you can replicate it exactly on your website.

---

## 🎯 **Three Main Sections**

### **1. Account Information**
Displays current user account details with verification status

### **2. Security**
Two-Factor Authentication settings

### **3. Account Actions**
Switch account, add account, sign out, delete account

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
  title: Text('Manage Account'),
)
```

### **Body Layout**
```dart
SingleChildScrollView(
  padding: EdgeInsets.all(24),
  child: Column(
    children: [
      _buildAccountInfo(user),      // Section 1
      SizedBox(height: 32),
      _buildSecuritySection(),       // Section 2
      SizedBox(height: 32),
      _buildAccountActions(),        // Section 3
    ],
  ),
)
```

---

## 📊 **Section 1: Account Information**

### **Container Style**
```javascript
Container({
  padding: EdgeInsets.all(20),
  decoration: BoxDecoration({
    color: Colors.white.withAlpha(10%),  // white with 0.1 opacity
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: Colors.white.withAlpha(20%),
    ),
  }),
})
```

### **Content**
**Title**: "Account Information"  
**Style**: White, size 20, bold

**Information Rows**:
1. **Email**
   - Icon: `Icons.email`
   - Label: "Email"
   - Value: `user.email` or "Not provided"

2. **Username**
   - Icon: `Icons.person`
   - Label: "Username"
   - Value: `userData.username` or "Not set"

3. **Display Name**
   - Icon: `Icons.badge`
   - Label: "Display Name"
   - Value: `userData.displayName` or "Not set"

4. **Verification Status** (Conditional)
   - If verified: Show green badge "Email Verified"
   - If not verified: Show orange badge "Email Not Verified"

### **Info Row Structure**
```javascript
Row({
  children: [
    Icon(icon, color: white.withAlpha(70%), size: 20),
    SizedBox(width: 12),
    Text(label, color: white.withAlpha(70%), fontSize: 14),
    Spacer(),
    Flexible(
      child: Text(value, color: white, fontWeight: bold, textAlign: right),
    ),
  ],
})
```

### **Verified Badge**
```javascript
Container({
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration({
    color: Colors.green.withAlpha(20%),
    borderRadius: BorderRadius.circular(16),
  }),
  child: Row({
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.check_circle, color: green, size: 16),
      SizedBox(width: 4),
      Text('Email Verified', color: green, fontWeight: bold),
    ],
  }),
})
```

### **Unverified Badge**
```javascript
Container({
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration({
    color: Colors.orange.withAlpha(20%),
    borderRadius: BorderRadius.circular(16),
  }),
  child: Row({
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.warning, color: orange, size: 16),
      SizedBox(width: 4),
      Text('Email Not Verified', color: orange, fontWeight: bold),
    ],
  }),
})
```

---

## 🔐 **Section 2: Security**

### **Title**
Text: "Security"  
Style: White, size 20, bold  
Spacing: 16px after title

### **Security Item**
```javascript
Container({
  decoration: BoxDecoration({
    color: Colors.white.withAlpha(10%),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: white.withAlpha(20%)),
  }),
  child: ListTile({
    leading: Icon(security, size: 20, color: white),
    title: Text('Two-Factor Authentication', color: white, fontWeight: bold),
    subtitle: Text('Add an extra layer of security', fontSize: 12, color: white70),
    trailing: Icon(arrow_forward_ios, size: 16, color: white54),
    onTap: () => navigateToTwoFactorSettings(),
  }),
})
```

**Action**: Opens Two-Factor Authentication settings page

---

## ⚙️ **Section 3: Account Actions**

### **Title**
Text: "Account Actions"  
Style: White, size 20, bold  
Spacing: 16px after title

### **Container Style** (Same as Section 1)
```javascript
Container({
  decoration: BoxDecoration({
    color: Colors.white.withAlpha(10%),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: white.withAlpha(20%)),
  }),
})
```

### **Action 1: Switch Account**
```javascript
ListTile({
  leading: Icon(swap_horiz, color: white, size: 20),
  title: Text('Switch Account', color: white, fontWeight: bold),
  subtitle: Text('Switch to another account', fontSize: 12, color: white70),
  onTap: () => showAccountSwitcher(),
})
```

**Action**: Opens account switcher modal with saved accounts

---

### **Action 2: Add Account**
```javascript
ListTile({
  leading: Icon(add_circle_outline, color: white, size: 20),
  title: Text('Add Account', color: white, fontWeight: bold),
  subtitle: Text('Add a new Google account', fontSize: 12, color: white70),
  onTap: () => addGoogleAccount(),
})
```

**Action**: Triggers Google Sign-In to add a new account

---

### **Action 3: Sign Out**
```javascript
ListTile({
  leading: Icon(logout, color: red, size: 20),
  title: Text('Sign Out', color: red, fontWeight: bold),
  subtitle: Text('Sign out of your account', fontSize: 12, color: white70),
  onTap: () => showSignOutConfirmation(),
})
```

**Action**: Shows confirmation dialog before signing out

**Confirmation Dialog**:
```
Title: "Sign Out"
Content: "Are you sure you want to sign out? Your saved accounts will remain so you can switch back later."
Actions: 
  - Cancel (default)
  - Sign Out (red text)
```

---

### **Action 4: Delete Account**
```javascript
ListTile({
  leading: Icon(delete_forever, color: red, size: 20),
  title: Text('Delete Account', color: red, fontWeight: bold),
  subtitle: Text('Permanently delete your account', fontSize: 12, color: white70),
  onTap: () => showDeleteAccountConfirmations(),
})
```

**Action**: Shows two confirmation dialogs

**First Confirmation Dialog**:
```
Title: "Delete Account"
Content: 
  "This will permanently delete your account and all data."
  
  "This action cannot be undone." (red, bold)
  
  "All of the following will be deleted:" (bold)
    • Your profile and account
    • All your videos
    • All your followers and following
    • All your likes and comments
    • All your messages
    • All your bookmarks and saved content

Actions:
  - Cancel (default)
  - Continue (red)
```

**Final Confirmation Dialog**:
```
Title: "Final Confirmation"
Content: 
  "Type 'DELETE' to confirm account deletion:"
  
  [Text Input Field - autofocus]
  
Actions:
  - Cancel (default)
  - Delete Account (red, bold)
  
Validation: Must type exactly "DELETE" to proceed
```

---

## 🌐 **Website Implementation (React)**

### **Data Loading**
```javascript
import { useEffect, useState } from 'react';
import { doc, getDoc } from 'firebase/firestore';
import { auth, db } from '../firebase-config';

function ManageAccountView() {
  const [userData, setUserData] = useState(null);
  const [loading, setLoading] = useState(true);
  
  useEffect(() => {
    const loadUserData = async () => {
      const user = auth.currentUser;
      if (!user) return;
      
      const docRef = doc(db, 'users', user.uid);
      const docSnap = await getDoc(docRef);
      
      if (docSnap.exists()) {
        setUserData(docSnap.data());
      }
      setLoading(false);
    };
    
    loadUserData();
  }, []);
  
  // ... rest of component
}
```

### **Account Info Section**
```javascript
function AccountInfoSection({ user, userData }) {
  return (
    <div className="account-info-card">
      <h2>Account Information</h2>
      
      <InfoRow 
        icon="email" 
        label="Email" 
        value={user?.email || 'Not provided'} 
      />
      
      <InfoRow 
        icon="person" 
        label="Username" 
        value={userData?.username || 'Not set'} 
      />
      
      <InfoRow 
        icon="badge" 
        label="Display Name" 
        value={userData?.displayName || 'Not set'} 
      />
      
      {user?.emailVerified ? (
        <VerifiedBadge />
      ) : (
        <UnverifiedBadge />
      )}
    </div>
  );
}
```

### **Security Section**
```javascript
function SecuritySection({ onTwoFactorPress }) {
  return (
    <div className="security-section">
      <h2>Security</h2>
      
      <div className="security-item" onClick={onTwoFactorPress}>
        <Icon name="security" />
        <div>
          <h3>Two-Factor Authentication</h3>
          <p>Add an extra layer of security</p>
        </div>
        <Icon name="arrow_forward_ios" />
      </div>
    </div>
  );
}
```

### **Account Actions Section**
```javascript
function AccountActionsSection({ 
  onSwitchAccount, 
  onAddAccount, 
  onSignOut, 
  onDeleteAccount 
}) {
  return (
    <div className="account-actions-section">
      <h2>Account Actions</h2>
      
      <div className="account-actions-card">
        <ActionItem
          icon="swap_horiz"
          title="Switch Account"
          subtitle="Switch to another account"
          onClick={onSwitchAccount}
        />
        
        <Divider />
        
        <ActionItem
          icon="add_circle_outline"
          title="Add Account"
          subtitle="Add a new Google account"
          onClick={onAddAccount}
        />
        
        <Divider />
        
        <ActionItem
          icon="logout"
          title="Sign Out"
          subtitle="Sign out of your account"
          onClick={onSignOut}
          danger
        />
        
        <Divider />
        
        <ActionItem
          icon="delete_forever"
          title="Delete Account"
          subtitle="Permanently delete your account"
          onClick={onDeleteAccount}
          danger
        />
      </div>
    </div>
  );
}
```

---

## 🗄️ **Data Requirements**

### **Firebase Auth User**
```javascript
user.email          // Email address
user.emailVerified  // Boolean - verification status
user.uid           // User ID
user.displayName    // Display name (if set)
```

### **Firestore User Document**
```javascript
users/{userId} {
  username: "string",
  displayName: "string",
  email: "string",
  // ... other fields
}
```

---

## 🎨 **Color Scheme**

### **Background**
- Primary: `#1C135D` (Dark Purple)
- Cards: `rgba(255, 255, 255, 0.1)` (White with 10% opacity)
- Borders: `rgba(255, 255, 255, 0.2)` (White with 20% opacity)

### **Text Colors**
- Primary: `#FFFFFF` (White)
- Secondary: `rgba(255, 255, 255, 0.7)` (White with 70% opacity)
- Danger: `#FF0000` (Red)

### **Badge Colors**
- Verified: `#00FF00` (Green)
- Unverified: `#FFA500` (Orange)
- Danger Actions: `#FF0000` (Red)

### **Spacing**
- Section padding: `24px`
- Between sections: `32px`
- Card padding: `20px`
- Border radius: `16px`

---

## ✅ **Complete Feature List**

### **Account Information**
- ✅ Email address display
- ✅ Username display
- ✅ Display name
- ✅ Email verification status badge
- ✅ Unverified email warning badge

### **Security**
- ✅ Two-Factor Authentication link
- ✅ Opens Two-Factor Settings page

### **Account Actions**
- ✅ Switch Account (open account switcher)
- ✅ Add Account (Google Sign-In)
- ✅ Sign Out (with confirmation)
- ✅ Delete Account (with double confirmation)

### **Confirmation Dialogs**
- ✅ Sign Out confirmation
- ✅ Delete Account - First confirmation
- ✅ Delete Account - Final confirmation with "DELETE" text input
- ✅ Delete Account - Data deletion list

### **Data Deletion**
When deleting account, removes:
- ✅ User profile
- ✅ All videos
- ✅ All messages
- ✅ All comments
- ✅ All bookmarks
- ✅ All calendar events
- ✅ Firebase Auth account

---

## 🎯 **Website CSS Example**

```css
.manage-account-container {
  max-width: 800px;
  margin: 0 auto;
  padding: 24px;
}

.account-card {
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 16px;
  padding: 20px;
  margin-bottom: 32px;
}

.account-card h2 {
  color: white;
  font-size: 20px;
  font-weight: bold;
  margin-bottom: 20px;
}

.info-row {
  display: flex;
  align-items: center;
  padding: 12px 0;
}

.info-row .icon {
  color: rgba(255, 255, 255, 0.7);
  font-size: 20px;
  margin-right: 12px;
}

.info-row .label {
  color: rgba(255, 255, 255, 0.7);
  font-size: 14px;
}

.info-row .value {
  color: white;
  font-weight: 600;
  margin-left: auto;
}

.badge {
  padding: 6px 12px;
  border-radius: 16px;
  display: inline-flex;
  align-items: center;
  gap: 4px;
}

.badge.verified {
  background: rgba(0, 255, 0, 0.2);
  color: #00FF00;
}

.badge.unverified {
  background: rgba(255, 165, 0, 0.2);
  color: #FFA500;
}

.action-item {
  padding: 16px;
  display: flex;
  align-items: center;
  cursor: pointer;
  transition: background 0.2s;
}

.action-item:hover {
  background: rgba(255, 255, 255, 0.05);
}

.action-item.danger {
  color: #FF0000;
}
```

---

## 📱 **Complete Structure**

```
ManageAccountView
├── AppBar
│   ├── Back Button
│   └── "Manage Account" Title
└── Body (SingleChildScrollView)
    ├── Account Information Card
    │   ├── "Account Information" Title
    │   ├── Email Info Row
    │   ├── Username Info Row
    │   ├── Display Name Info Row
    │   └── Verification Badge
    ├── Security Section
    │   ├── "Security" Title
    │   └── Two-Factor Authentication Item
    └── Account Actions Section
        ├── "Account Actions" Title
        ├── Switch Account Item
        ├── Add Account Item
        ├── Sign Out Item (red)
        └── Delete Account Item (red)
```

---

## ✅ **Ready to Implement!**

All the content, structure, and styling from the Flutter app's Manage Account view is documented above. Use this to create an exact match on your website! 🎉

