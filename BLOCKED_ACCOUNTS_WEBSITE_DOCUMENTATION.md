# 🚫 Blocked Accounts - Website Documentation

## 📋 **Complete Feature List**

This document provides all the content from the Blocked Accounts view so you can replicate it exactly on your website.

---

## 🎯 **Features Overview**

### **Blocked Accounts View**
- View all blocked users
- Unblock users with confirmation
- Pull-to-refresh
- Empty state when no blocked users
- User avatar, name, and username display
- "Blocked" status indicator

---

## 📱 **UI Structure**

### **App Bar**
```dart
AppBar(
  backgroundColor: Color(0xFF0E1220),
  title: Text('Blocked Accounts', color: white),
  actions: [
    IconButton(
      icon: Icons.refresh,
      onPressed: () => loadBlockedUsers(),
    ),
  ],
)
```

### **Body States**
1. **Loading**: Shows CircularProgressIndicator
2. **Empty**: Shows empty state message
3. **List**: Shows list of blocked users

---

## 🎨 **Empty State**

### **UI Elements**
```
Center - Column
  ↓
  Icon(Icons.block_outlined, size: 80, color: white50%)
  Text('No Blocked Accounts', fontSize: 24, bold)
  Text('Users you block will appear here.\nYou can unblock them at any time.', fontSize: 16)
```

### **Empty State Code**
```javascript
function EmptyState() {
  return (
    <div className="empty-state">
      <Icon name="block_outlined" size={80} color="rgba(255,255,255,0.5)" />
      <h1>No Blocked Accounts</h1>
      <p>
        Users you block will appear here.<br />
        You can unblock them at any time.
      </p>
    </div>
  );
}
```

---

## 📊 **Blocked User Card**

### **Card Structure**
```
Container - Card
  ↓
  Row
    ├─ CircleAvatar (user avatar)
    ├─ Column (user info)
    │   ├─ Display Name (fontSize: 18, bold)
    │   ├─ @username (fontSize: 14, gray)
    │   └─ "Blocked" badge (red)
    └─ IconButton (unblock button - green check icon)
```

### **Card Styling**
- Background: `#1A1A1A`
- Border: 1px solid `rgba(255,255,255,0.1)`
- Border Radius: 12px
- Padding: 16px
- Margin: 0 0 12px 0

---

## 🔄 **Data Flow**

### **Loading Blocked Users**
```javascript
async function loadBlockedUsers() {
  const user = auth.currentUser;
  if (!user) return [];
  
  // Get blocked user IDs from user_blocks collection
  const query = await getDocs(
    query(
      collection(db, 'user_blocks'),
      where('blockerId', '==', user.uid)
    )
  );
  
  const blockedUserIds = query.docs.map(
    doc => doc.data().blockedUserId
  );
  
  // Fetch user details for each blocked user
  const users = [];
  for (const userId of blockedUserIds) {
    const userDoc = await getDoc(doc(db, 'users', userId));
    if (userDoc.exists()) {
      const data = userDoc.data();
      users.push({
        id: userId,
        displayName: data.displayName || 'Unknown User',
        username: data.username || 'unknown',
        avatarURL: data.avatarURL || null,
      });
    }
  }
  
  return users;
}
```

### **Unblocking User**
```javascript
async function unblockUser(targetUserId, displayName) {
  const user = auth.currentUser;
  if (!user) return;
  
  try {
    // Delete from user_blocks collection
    const q = query(
      collection(db, 'user_blocks'),
      where('blockerId', '==', user.uid),
      where('blockedUserId', '==', targetUserId)
    );
    
    const snapshot = await getDocs(q);
    for (const doc of snapshot.docs) {
      await deleteDoc(doc.ref);
    }
    
    // Remove from user's blockedUsers array
    await updateDoc(doc(db, 'users', user.uid), {
      blockedUsers: arrayRemove(targetUserId)
    });
    
    // Show success message
    showSnackbar(`${displayName} has been unblocked`, 'success');
    
    // Reload the list
    loadBlockedUsers();
  } catch (error) {
    showSnackbar(`Failed to unblock user: ${error}`, 'error');
  }
}
```

---

## 🗄️ **Firestore Data Structure**

### **User Blocks Collection**
```javascript
user_blocks/{blockId} {
  blockerId: "current-user-id",
  blockedUserId: "blocked-user-id",
  reason: "User blocked",
  createdAt: Timestamp
}
```

### **Users Collection**
```javascript
users/{userId} {
  // ... other user fields
  blockedUsers: [          // Array of blocked user IDs
    "blocked-user-1",
    "blocked-user-2"
  ]
}
```

---

## 🌐 **Website Implementation (React)**

### **Component Structure**
```javascript
import { useState, useEffect } from 'react';
import { collection, query, where, getDocs, doc, getDoc, deleteDoc, updateDoc, arrayRemove } from 'firebase/firestore';
import { db, auth } from '../firebase-config';

function BlockedAccountsView() {
  const [blockedUsers, setBlockedUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  
  useEffect(() => {
    loadBlockedUsers();
  }, []);
  
  const loadBlockedUsers = async () => {
    setLoading(true);
    
    const user = auth.currentUser;
    if (!user) return;
    
    try {
      // Get blocked user IDs
      const q = query(
        collection(db, 'user_blocks'),
        where('blockerId', '==', user.uid)
      );
      
      const snapshot = await getDocs(q);
      const blockedUserIds = snapshot.docs.map(
        doc => doc.data().blockedUserId
      );
      
      // Fetch user details
      const users = [];
      for (const userId of blockedUserIds) {
        const userDoc = await getDoc(doc(db, 'users', userId));
        if (userDoc.exists()) {
          const data = userDoc.data();
          users.push({
            id: userId,
            displayName: data.displayName || 'Unknown User',
            username: data.username || 'unknown',
            avatarURL: data.avatarURL || null,
          });
        }
      }
      
      setBlockedUsers(users);
    } catch (error) {
      console.error('Error loading blocked users:', error);
    } finally {
      setLoading(false);
    }
  };
  
  const handleUnblock = async (userId, displayName) => {
    const confirmed = await showConfirmationDialog({
      title: 'Unblock User',
      message: `Are you sure you want to unblock ${displayName}? You will be able to see their content and interact with them again.`,
    });
    
    if (!confirmed) return;
    
    const user = auth.currentUser;
    if (!user) return;
    
    try {
      // Delete from user_blocks
      const q = query(
        collection(db, 'user_blocks'),
        where('blockerId', '==', user.uid),
        where('blockedUserId', '==', userId)
      );
      
      const snapshot = await getDocs(q);
      for (const docSnap of snapshot.docs) {
        await deleteDoc(docSnap.ref);
      }
      
      // Remove from user's blockedUsers array
      await updateDoc(doc(db, 'users', user.uid), {
        blockedUsers: arrayRemove(userId)
      });
      
      showSnackbar(`${displayName} has been unblocked`, 'success');
      loadBlockedUsers();
    } catch (error) {
      showSnackbar(`Failed to unblock user: ${error}`, 'error');
    }
  };
  
  if (loading) {
    return <LoadingSpinner />;
  }
  
  return (
    <div className="blocked-accounts-view">
      <AppBar title="Blocked Accounts" />
      
      {blockedUsers.length === 0 ? (
        <EmptyState />
      ) : (
        <div className="blocked-users-list">
          {blockedUsers.map(user => (
            <BlockedUserCard
              key={user.id}
              user={user}
              onUnblock={() => handleUnblock(user.id, user.displayName)}
            />
          ))}
        </div>
      )}
    </div>
  );
}
```

### **Blocked User Card Component**
```javascript
function BlockedUserCard({ user, onUnblock }) {
  return (
    <div className="blocked-user-card">
      <div className="user-avatar">
        {user.avatarURL ? (
          <img src={user.avatarURL} alt={user.displayName} />
        ) : (
          <div className="avatar-placeholder">
            {user.displayName[0]?.toUpperCase() || '?'}
          </div>
        )}
      </div>
      
      <div className="user-info">
        <h3>{user.displayName}</h3>
        <p>@{user.username}</p>
        <div className="blocked-badge">
          <Icon name="block" size={16} />
          <span>Blocked</span>
        </div>
      </div>
      
      <button className="unblock-button" onClick={onUnblock}>
        <Icon name="check_circle_outline" color="green" size={24} />
      </button>
    </div>
  );
}
```

### **Empty State Component**
```javascript
function EmptyState() {
  return (
    <div className="empty-state">
      <Icon name="block_outlined" size={80} color="rgba(255,255,255,0.5)" />
      <h1>No Blocked Accounts</h1>
      <p>
        Users you block will appear here.<br />
        You can unblock them at any time.
      </p>
    </div>
  );
}
```

---

## 🎨 **Styling**

### **Container Styles**
```css
.blocked-accounts-view {
  background: #0E1220;
  min-height: 100vh;
}

.blocked-users-list {
  padding: 16px;
}
```

### **Empty State Styles**
```css
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 60vh;
  text-align: center;
}

.empty-state .icon {
  color: rgba(255, 255, 255, 0.5);
  font-size: 80px;
  margin-bottom: 24px;
}

.empty-state h1 {
  color: rgba(255, 255, 255, 0.8);
  font-size: 24px;
  font-weight: bold;
  margin: 0 0 12px 0;
}

.empty-state p {
  color: rgba(255, 255, 255, 0.6);
  font-size: 16px;
  line-height: 1.5;
}
```

### **Blocked User Card Styles**
```css
.blocked-user-card {
  background: #1A1A1A;
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 12px;
  padding: 16px;
  margin-bottom: 12px;
  display: flex;
  align-items: center;
}

.user-avatar {
  width: 60px;
  height: 60px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.3);
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  flex-shrink: 0;
}

.user-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.avatar-placeholder {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-size: 20px;
  font-weight: bold;
}

.user-info {
  flex: 1;
  margin-left: 16px;
}

.user-info h3 {
  color: white;
  font-size: 18px;
  font-weight: bold;
  margin: 0 0 4px 0;
}

.user-info p {
  color: rgba(255, 255, 255, 0.7);
  font-size: 14px;
  margin: 0 0 8px 0;
}

.blocked-badge {
  display: flex;
  align-items: center;
  gap: 4px;
  color: rgba(255, 0, 0, 0.7);
  font-size: 12px;
  font-weight: 500;
}

.unblock-button {
  background: transparent;
  border: none;
  cursor: pointer;
  padding: 8px;
  color: green;
}

.unblock-button:hover {
  opacity: 0.8;
}
```

---

## 🔄 **User Blocking Service**

### **Methods**

#### **1. Block User**
```javascript
async function blockUser(targetUserId, reason = 'User blocked') {
  const user = auth.currentUser;
  if (!user) throw new Error('User not authenticated');
  
  if (user.uid === targetUserId) {
    throw new Error('Cannot block yourself');
  }
  
  // Add to user_blocks collection
  await addDoc(collection(db, 'user_blocks'), {
    blockerId: user.uid,
    blockedUserId: targetUserId,
    reason: reason,
    createdAt: serverTimestamp(),
  });
  
  // Update user's blockedUsers array
  await updateDoc(doc(db, 'users', user.uid), {
    blockedUsers: arrayUnion(targetUserId)
  });
}
```

#### **2. Unblock User**
```javascript
async function unblockUser(targetUserId) {
  const user = auth.currentUser;
  if (!user) throw new Error('User not authenticated');
  
  // Delete from user_blocks collection
  const q = query(
    collection(db, 'user_blocks'),
    where('blockerId', '==', user.uid),
    where('blockedUserId', '==', targetUserId)
  );
  
  const snapshot = await getDocs(q);
  for (const docSnap of snapshot.docs) {
    await deleteDoc(docSnap.ref);
  }
  
  // Remove from user's blockedUsers array
  await updateDoc(doc(db, 'users', user.uid), {
    blockedUsers: arrayRemove(targetUserId)
  });
}
```

#### **3. Check if User is Blocked**
```javascript
async function isUserBlocked(targetUserId) {
  const user = auth.currentUser;
  if (!user) return false;
  
  const q = query(
    collection(db, 'user_blocks'),
    where('blockerId', '==', user.uid),
    where('blockedUserId', '==', targetUserId),
    limit(1)
  );
  
  const snapshot = await getDocs(q);
  return !snapshot.empty;
}
```

#### **4. Get Blocked Users**
```javascript
async function getBlockedUsers() {
  const user = auth.currentUser;
  if (!user) return [];
  
  const q = query(
    collection(db, 'user_blocks'),
    where('blockerId', '==', user.uid)
  );
  
  const snapshot = await getDocs(q);
  return snapshot.docs.map(doc => doc.data().blockedUserId);
}
```

---

## 🎯 **Confirmation Dialog**

### **Unblock Confirmation**
```javascript
function showUnblockConfirmation(userId, displayName) {
  return new Promise((resolve) => {
    // Show modal dialog
    const dialog = document.createElement('div');
    dialog.className = 'modal-overlay';
    dialog.innerHTML = `
      <div class="modal-dialog">
        <h2>Unblock User</h2>
        <p>Are you sure you want to unblock ${displayName}? You will be able to see their content and interact with them again.</p>
        <div class="modal-actions">
          <button class="btn-cancel" onclick="closeModal(false)">Cancel</button>
          <button class="btn-unblock" onclick="closeModal(true)">Unblock</button>
        </div>
      </div>
    `;
    
    document.body.appendChild(dialog);
    
    window.closeModal = (confirmed) => {
      document.body.removeChild(dialog);
      resolve(confirmed);
    };
  });
}
```

---

## 🗄️ **Firestore Security Rules**

```javascript
// User Blocks
match /user_blocks/{blockId} {
  allow read: if request.auth != null && request.auth.uid == resource.data.blockerId;
  allow create: if request.auth != null && request.auth.uid == request.resource.data.blockerId;
  allow delete: if request.auth != null && request.auth.uid == resource.data.blockerId;
}
```

---

## ✅ **Complete Features**

### **View Features** ✅
- [x] List all blocked users
- [x] User avatar display
- [x] User display name
- [x] User username
- [x] "Blocked" status badge
- [x] Unblock button
- [x] Pull-to-refresh
- [x] Empty state message
- [x] Loading indicator

### **Actions** ✅
- [x] Unblock user with confirmation
- [x] Success snackbar
- [x] Error handling
- [x] Auto-refresh after unblock

### **Data Management** ✅
- [x] Loads from `user_blocks` collection
- [x] Fetches user details for each blocked user
- [x] Updates `users` collection on unblock
- [x] Handles empty state gracefully

---

## 🚀 **Ready to Implement!**

All content from the Flutter app's Blocked Accounts view is documented above. Use this to create an exact match on your website! 🎉

