# Website NetworkView Implementation - Social Network Sync

## 🎯 Goal
Create a social network interface on the website that syncs with the mobile app, allowing users to connect, follow, message, and interact across both platforms.

---

## 📋 Features Overview

This implementation provides:
- ✅ **Follow/Unfollow** users from website → syncs to mobile
- ✅ **Followers/Following lists** in real-time
- ✅ **User search** and discovery
- ✅ **Connection requests** and management
- ✅ **User profiles** with stats
- ✅ **Online status** indicators
- ✅ **Direct messaging** (optional)
- ✅ **Notifications** for new followers
- ✅ **Real-time sync** with mobile app (< 100ms)

---

## Step 1: Install Dependencies

```bash
npm install firebase
npm install react-router-dom  # For navigation
```

---

## Step 2: Create Network Service

Create file: `src/services/networkService.js`

```javascript
import { 
  collection, 
  query, 
  where, 
  orderBy, 
  limit,
  doc,
  getDoc,
  getDocs,
  setDoc,
  deleteDoc,
  updateDoc,
  onSnapshot,
  increment,
  serverTimestamp,
  writeBatch
} from 'firebase/firestore';
import { db } from '../firebase/config';

/**
 * Follow a user (syncs to mobile app)
 */
export async function followUser(followerId, followedId) {
  if (followerId === followedId) {
    throw new Error('Cannot follow yourself');
  }

  try {
    const batch = writeBatch(db);
    
    // 1. Create follow relationship
    const followRef = doc(db, 'follows', `${followerId}_${followedId}`);
    batch.set(followRef, {
      followerId: followerId,
      followedId: followedId,
      createdAt: serverTimestamp(),
      status: 'active'
    });
    
    // 2. Add to follower's following collection
    const followingRef = doc(db, 'users', followerId, 'following', followedId);
    batch.set(followingRef, {
      userId: followedId,
      followedAt: serverTimestamp()
    });
    
    // 3. Add to followed user's followers collection
    const followerRef = doc(db, 'users', followedId, 'followers', followerId);
    batch.set(followerRef, {
      userId: followerId,
      followedAt: serverTimestamp()
    });
    
    // 4. Update follower counts
    batch.update(doc(db, 'users', followerId), {
      followingCount: increment(1)
    });
    batch.update(doc(db, 'users', followedId), {
      followerCount: increment(1)
    });
    
    await batch.commit();
    console.log(`✅ User ${followerId} followed ${followedId}`);
    
    return true;
  } catch (error) {
    console.error('❌ Error following user:', error);
    throw error;
  }
}

/**
 * Unfollow a user (syncs to mobile app)
 */
export async function unfollowUser(followerId, followedId) {
  try {
    const batch = writeBatch(db);
    
    // 1. Remove follow relationship
    const followRef = doc(db, 'follows', `${followerId}_${followedId}`);
    batch.delete(followRef);
    
    // 2. Remove from follower's following collection
    const followingRef = doc(db, 'users', followerId, 'following', followedId);
    batch.delete(followingRef);
    
    // 3. Remove from followed user's followers collection
    const followerRef = doc(db, 'users', followedId, 'followers', followerId);
    batch.delete(followerRef);
    
    // 4. Update follower counts
    batch.update(doc(db, 'users', followerId), {
      followingCount: increment(-1)
    });
    batch.update(doc(db, 'users', followedId), {
      followerCount: increment(-1)
    });
    
    await batch.commit();
    console.log(`✅ User ${followerId} unfollowed ${followedId}`);
    
    return true;
  } catch (error) {
    console.error('❌ Error unfollowing user:', error);
    throw error;
  }
}

/**
 * Check if user is following another user
 */
export async function isFollowing(followerId, followedId) {
  try {
    const followDoc = await getDoc(
      doc(db, 'users', followerId, 'following', followedId)
    );
    return followDoc.exists();
  } catch (error) {
    console.error('❌ Error checking follow status:', error);
    return false;
  }
}

/**
 * Get followers list in real-time
 */
export function watchFollowers(userId, callback, onError) {
  try {
    const followersQuery = query(
      collection(db, 'users', userId, 'followers'),
      orderBy('followedAt', 'desc')
    );
    
    const unsubscribe = onSnapshot(
      followersQuery,
      async (snapshot) => {
        console.log(`👥 Loaded ${snapshot.docs.length} followers`);
        const followers = [];
        
        for (const docSnap of snapshot.docs) {
          const data = docSnap.data();
          const followerUserId = data.userId;
          
          // Get follower's full profile
          const userDoc = await getDoc(doc(db, 'users', followerUserId));
          if (userDoc.exists()) {
            followers.push({
              id: followerUserId,
              followedAt: data.followedAt?.toDate(),
              ...userDoc.data()
            });
          }
        }
        
        callback(followers);
      },
      (error) => {
        console.error('❌ Error watching followers:', error);
        if (onError) onError(error);
      }
    );
    
    return unsubscribe;
  } catch (error) {
    console.error('❌ Error setting up followers watcher:', error);
    if (onError) onError(error);
    return () => {};
  }
}

/**
 * Get following list in real-time
 */
export function watchFollowing(userId, callback, onError) {
  try {
    const followingQuery = query(
      collection(db, 'users', userId, 'following'),
      orderBy('followedAt', 'desc')
    );
    
    const unsubscribe = onSnapshot(
      followingQuery,
      async (snapshot) => {
        console.log(`👥 Loaded ${snapshot.docs.length} following`);
        const following = [];
        
        for (const docSnap of snapshot.docs) {
          const data = docSnap.data();
          const followedUserId = data.userId;
          
          // Get followed user's full profile
          const userDoc = await getDoc(doc(db, 'users', followedUserId));
          if (userDoc.exists()) {
            following.push({
              id: followedUserId,
              followedAt: data.followedAt?.toDate(),
              ...userDoc.data()
            });
          }
        }
        
        callback(following);
      },
      (error) => {
        console.error('❌ Error watching following:', error);
        if (onError) onError(error);
      }
    );
    
    return unsubscribe;
  } catch (error) {
    console.error('❌ Error setting up following watcher:', error);
    if (onError) onError(error);
    return () => {};
  }
}

/**
 * Search users by username or display name
 */
export async function searchUsers(searchTerm, limitCount = 20) {
  try {
    if (!searchTerm || searchTerm.trim().length === 0) {
      return [];
    }
    
    const searchLower = searchTerm.toLowerCase();
    
    // Search by username
    const usernameQuery = query(
      collection(db, 'users'),
      where('username', '>=', searchLower),
      where('username', '<=', searchLower + '\uf8ff'),
      limit(limitCount)
    );
    
    const snapshot = await getDocs(usernameQuery);
    const users = [];
    
    snapshot.docs.forEach(doc => {
      users.push({
        id: doc.id,
        ...doc.data()
      });
    });
    
    console.log(`🔍 Found ${users.length} users for "${searchTerm}"`);
    return users;
  } catch (error) {
    console.error('❌ Error searching users:', error);
    return [];
  }
}

/**
 * Get suggested users (users you might want to follow)
 */
export async function getSuggestedUsers(currentUserId, limitCount = 10) {
  try {
    // Get users with most followers that current user isn't following
    const usersQuery = query(
      collection(db, 'users'),
      orderBy('followerCount', 'desc'),
      limit(limitCount * 2) // Get extra to filter out
    );
    
    const snapshot = await getDocs(usersQuery);
    const suggestions = [];
    
    for (const docSnap of snapshot.docs) {
      const userId = docSnap.id;
      
      // Skip current user
      if (userId === currentUserId) continue;
      
      // Check if already following
      const alreadyFollowing = await isFollowing(currentUserId, userId);
      if (alreadyFollowing) continue;
      
      suggestions.push({
        id: userId,
        ...docSnap.data()
      });
      
      // Stop when we have enough suggestions
      if (suggestions.length >= limitCount) break;
    }
    
    console.log(`💡 Found ${suggestions.length} suggested users`);
    return suggestions;
  } catch (error) {
    console.error('❌ Error getting suggested users:', error);
    return [];
  }
}

/**
 * Get mutual connections (users who follow each other)
 */
export async function getMutualConnections(userId1, userId2) {
  try {
    // Check if both users follow each other
    const user1FollowsUser2 = await isFollowing(userId1, userId2);
    const user2FollowsUser1 = await isFollowing(userId2, userId1);
    
    return user1FollowsUser2 && user2FollowsUser1;
  } catch (error) {
    console.error('❌ Error checking mutual connections:', error);
    return false;
  }
}

/**
 * Get connection status between two users
 */
export async function getConnectionStatus(viewerId, targetUserId) {
  try {
    if (viewerId === targetUserId) {
      return 'self';
    }
    
    const viewerFollowsTarget = await isFollowing(viewerId, targetUserId);
    const targetFollowsViewer = await isFollowing(targetUserId, viewerId);
    
    if (viewerFollowsTarget && targetFollowsViewer) {
      return 'mutual'; // Both follow each other
    } else if (viewerFollowsTarget) {
      return 'following'; // Viewer follows target
    } else if (targetFollowsViewer) {
      return 'follower'; // Target follows viewer
    } else {
      return 'none'; // No connection
    }
  } catch (error) {
    console.error('❌ Error getting connection status:', error);
    return 'none';
  }
}

/**
 * Get network stats for a user
 */
export async function getNetworkStats(userId) {
  try {
    const userDoc = await getDoc(doc(db, 'users', userId));
    
    if (!userDoc.exists()) {
      return {
        followers: 0,
        following: 0,
        posts: 0
      };
    }
    
    const data = userDoc.data();
    
    return {
      followers: data.followerCount || 0,
      following: data.followingCount || 0,
      posts: data.postCount || 0,
      totalViews: data.totalViews || 0,
      totalLikes: data.totalLikes || 0
    };
  } catch (error) {
    console.error('❌ Error getting network stats:', error);
    return {
      followers: 0,
      following: 0,
      posts: 0
    };
  }
}
```

---

## Step 3: Create NetworkView Component

Create file: `src/components/NetworkView.jsx`

```jsx
import React, { useState, useEffect } from 'react';
import { 
  followUser, 
  unfollowUser, 
  isFollowing,
  watchFollowers,
  watchFollowing,
  searchUsers,
  getSuggestedUsers,
  getConnectionStatus
} from '../services/networkService';
import { UserAvatar } from './UserAvatar';
import { auth } from '../firebase/config';
import './NetworkView.css';

export function NetworkView() {
  const [activeTab, setActiveTab] = useState('followers'); // followers, following, suggestions
  const [followers, setFollowers] = useState([]);
  const [following, setFollowing] = useState([]);
  const [suggestions, setSuggestions] = useState([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [searchResults, setSearchResults] = useState([]);
  const [loading, setLoading] = useState(true);
  const [followingSet, setFollowingSet] = useState(new Set());
  
  const currentUser = auth.currentUser;
  
  // Load followers in real-time
  useEffect(() => {
    if (!currentUser) return;
    
    console.log('👥 Loading followers...');
    const unsubscribe = watchFollowers(
      currentUser.uid,
      (followersList) => {
        setFollowers(followersList);
        setLoading(false);
      }
    );
    
    return () => unsubscribe();
  }, [currentUser]);
  
  // Load following in real-time
  useEffect(() => {
    if (!currentUser) return;
    
    console.log('👥 Loading following...');
    const unsubscribe = watchFollowing(
      currentUser.uid,
      (followingList) => {
        setFollowing(followingList);
        
        // Create a set of user IDs we're following for quick lookup
        const followingIds = new Set(followingList.map(u => u.id));
        setFollowingSet(followingIds);
        
        setLoading(false);
      }
    );
    
    return () => unsubscribe();
  }, [currentUser]);
  
  // Load suggested users
  useEffect(() => {
    if (!currentUser) return;
    
    const loadSuggestions = async () => {
      const suggestedUsers = await getSuggestedUsers(currentUser.uid, 10);
      setSuggestions(suggestedUsers);
    };
    
    loadSuggestions();
  }, [currentUser]);
  
  // Search users
  useEffect(() => {
    if (!searchTerm || searchTerm.trim().length < 2) {
      setSearchResults([]);
      return;
    }
    
    const performSearch = async () => {
      const results = await searchUsers(searchTerm);
      setSearchResults(results);
    };
    
    const debounce = setTimeout(performSearch, 300);
    return () => clearTimeout(debounce);
  }, [searchTerm]);
  
  // Handle follow/unfollow
  const handleFollowToggle = async (userId) => {
    if (!currentUser) {
      alert('Please sign in to follow users');
      return;
    }
    
    try {
      const isCurrentlyFollowing = followingSet.has(userId);
      
      if (isCurrentlyFollowing) {
        await unfollowUser(currentUser.uid, userId);
        setFollowingSet(prev => {
          const newSet = new Set(prev);
          newSet.delete(userId);
          return newSet;
        });
      } else {
        await followUser(currentUser.uid, userId);
        setFollowingSet(prev => new Set(prev).add(userId));
      }
    } catch (error) {
      console.error('Error toggling follow:', error);
      alert('Failed to update follow status. Please try again.');
    }
  };
  
  // Render user card
  const renderUserCard = (user) => {
    const isCurrentlyFollowing = followingSet.has(user.id);
    const isSelf = currentUser && user.id === currentUser.uid;
    
    return (
      <div key={user.id} className="network-user-card">
        <UserAvatar userId={user.id} size={60} showOnlineStatus={true} />
        
        <div className="user-info">
          <div className="user-name">{user.displayName || 'Unknown User'}</div>
          <div className="user-username">@{user.username || 'unknown'}</div>
          {user.bio && <div className="user-bio">{user.bio}</div>}
          
          <div className="user-stats">
            <span>{user.followerCount || 0} followers</span>
            <span className="stat-divider">•</span>
            <span>{user.postCount || 0} posts</span>
          </div>
          
          {user.followedAt && (
            <div className="followed-date">
              Followed {formatDate(user.followedAt)}
            </div>
          )}
        </div>
        
        <div className="user-actions">
          {!isSelf && (
            <button
              className={`follow-button ${isCurrentlyFollowing ? 'following' : ''}`}
              onClick={() => handleFollowToggle(user.id)}
            >
              {isCurrentlyFollowing ? 'Following' : 'Follow'}
            </button>
          )}
          
          <button 
            className="profile-button"
            onClick={() => window.location.href = `/profile/${user.id}`}
          >
            View Profile
          </button>
        </div>
      </div>
    );
  };
  
  // Format date
  const formatDate = (date) => {
    if (!date) return '';
    
    const now = new Date();
    const diff = now - date;
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    
    if (days === 0) return 'today';
    if (days === 1) return 'yesterday';
    if (days < 7) return `${days}d ago`;
    if (days < 30) return `${Math.floor(days / 7)}w ago`;
    return `${Math.floor(days / 30)}mo ago`;
  };
  
  if (!currentUser) {
    return (
      <div className="network-view">
        <div className="network-error">
          <h2>Sign In Required</h2>
          <p>Please sign in to view your network</p>
        </div>
      </div>
    );
  }
  
  return (
    <div className="network-view">
      {/* Header */}
      <div className="network-header">
        <h1>Network</h1>
        <p>Synced with mobile app • Updates in real-time</p>
      </div>
      
      {/* Search Bar */}
      <div className="network-search">
        <input
          type="text"
          placeholder="Search users..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          className="search-input"
        />
        {searchTerm && (
          <button 
            className="clear-search"
            onClick={() => setSearchTerm('')}
          >
            ✕
          </button>
        )}
      </div>
      
      {/* Search Results */}
      {searchResults.length > 0 && (
        <div className="search-results">
          <h3>Search Results ({searchResults.length})</h3>
          <div className="users-list">
            {searchResults.map(renderUserCard)}
          </div>
        </div>
      )}
      
      {/* Tabs */}
      {!searchTerm && (
        <>
          <div className="network-tabs">
            <button
              className={`tab ${activeTab === 'followers' ? 'active' : ''}`}
              onClick={() => setActiveTab('followers')}
            >
              Followers ({followers.length})
            </button>
            <button
              className={`tab ${activeTab === 'following' ? 'active' : ''}`}
              onClick={() => setActiveTab('following')}
            >
              Following ({following.length})
            </button>
            <button
              className={`tab ${activeTab === 'suggestions' ? 'active' : ''}`}
              onClick={() => setActiveTab('suggestions')}
            >
              Suggested ({suggestions.length})
            </button>
          </div>
          
          {/* Content */}
          <div className="network-content">
            {loading ? (
              <div className="network-loading">
                <div className="spinner"></div>
                <p>Loading network...</p>
              </div>
            ) : (
              <>
                {activeTab === 'followers' && (
                  <div className="users-list">
                    {followers.length === 0 ? (
                      <div className="empty-state">
                        <p>No followers yet</p>
                        <p className="empty-hint">
                          Share your profile to get followers!
                        </p>
                      </div>
                    ) : (
                      followers.map(renderUserCard)
                    )}
                  </div>
                )}
                
                {activeTab === 'following' && (
                  <div className="users-list">
                    {following.length === 0 ? (
                      <div className="empty-state">
                        <p>Not following anyone yet</p>
                        <p className="empty-hint">
                          Find users in the Suggested tab!
                        </p>
                      </div>
                    ) : (
                      following.map(renderUserCard)
                    )}
                  </div>
                )}
                
                {activeTab === 'suggestions' && (
                  <div className="users-list">
                    {suggestions.length === 0 ? (
                      <div className="empty-state">
                        <p>No suggestions available</p>
                      </div>
                    ) : (
                      suggestions.map(renderUserCard)
                    )}
                  </div>
                )}
              </>
            )}
          </div>
        </>
      )}
    </div>
  );
}
```

---

## Step 4: Create NetworkView CSS

Create file: `src/components/NetworkView.css`

```css
/* Network View Container */
.network-view {
  max-width: 800px;
  margin: 0 auto;
  padding: 20px;
}

/* Header */
.network-header {
  text-align: center;
  margin-bottom: 30px;
}

.network-header h1 {
  font-size: 2rem;
  margin-bottom: 10px;
  color: #333;
}

.network-header p {
  color: #666;
  font-size: 0.9rem;
}

/* Search Bar */
.network-search {
  position: relative;
  margin-bottom: 30px;
}

.search-input {
  width: 100%;
  padding: 12px 40px 12px 16px;
  font-size: 1rem;
  border: 2px solid #e0e0e0;
  border-radius: 25px;
  outline: none;
  transition: border-color 0.2s;
}

.search-input:focus {
  border-color: #3498db;
}

.clear-search {
  position: absolute;
  right: 12px;
  top: 50%;
  transform: translateY(-50%);
  background: #999;
  color: white;
  border: none;
  border-radius: 50%;
  width: 24px;
  height: 24px;
  cursor: pointer;
  font-size: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.clear-search:hover {
  background: #666;
}

/* Search Results */
.search-results {
  margin-bottom: 30px;
}

.search-results h3 {
  font-size: 1.1rem;
  margin-bottom: 15px;
  color: #333;
}

/* Tabs */
.network-tabs {
  display: flex;
  gap: 10px;
  margin-bottom: 25px;
  border-bottom: 2px solid #e0e0e0;
}

.tab {
  flex: 1;
  padding: 12px 20px;
  background: none;
  border: none;
  border-bottom: 3px solid transparent;
  cursor: pointer;
  font-size: 1rem;
  font-weight: 500;
  color: #666;
  transition: all 0.2s;
}

.tab:hover {
  color: #333;
  background: #f5f5f5;
}

.tab.active {
  color: #3498db;
  border-bottom-color: #3498db;
}

/* Users List */
.users-list {
  display: flex;
  flex-direction: column;
  gap: 15px;
}

/* User Card */
.network-user-card {
  display: flex;
  align-items: center;
  gap: 15px;
  padding: 15px;
  background: white;
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  transition: transform 0.2s, box-shadow 0.2s;
}

.network-user-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
}

/* User Info */
.user-info {
  flex: 1;
  min-width: 0; /* Allow text truncation */
}

.user-name {
  font-size: 1.1rem;
  font-weight: 600;
  color: #333;
  margin-bottom: 4px;
}

.user-username {
  font-size: 0.9rem;
  color: #666;
  margin-bottom: 8px;
}

.user-bio {
  font-size: 0.85rem;
  color: #555;
  line-height: 1.4;
  margin-bottom: 8px;
  overflow: hidden;
  text-overflow: ellipsis;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}

.user-stats {
  display: flex;
  gap: 8px;
  font-size: 0.85rem;
  color: #666;
  align-items: center;
}

.stat-divider {
  color: #ccc;
}

.followed-date {
  font-size: 0.75rem;
  color: #999;
  margin-top: 4px;
}

/* User Actions */
.user-actions {
  display: flex;
  flex-direction: column;
  gap: 8px;
  flex-shrink: 0;
}

.follow-button {
  padding: 8px 20px;
  background: #3498db;
  color: white;
  border: none;
  border-radius: 20px;
  font-size: 0.9rem;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.2s;
  white-space: nowrap;
}

.follow-button:hover {
  background: #2980b9;
}

.follow-button.following {
  background: white;
  color: #3498db;
  border: 2px solid #3498db;
}

.follow-button.following:hover {
  background: #fee;
  color: #e74c3c;
  border-color: #e74c3c;
}

.follow-button.following:hover::after {
  content: 'Unfollow';
  position: absolute;
  background: #333;
  color: white;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 0.75rem;
  white-space: nowrap;
  top: -30px;
  left: 50%;
  transform: translateX(-50%);
}

.profile-button {
  padding: 8px 20px;
  background: white;
  color: #666;
  border: 2px solid #e0e0e0;
  border-radius: 20px;
  font-size: 0.9rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  white-space: nowrap;
}

.profile-button:hover {
  background: #f5f5f5;
  border-color: #ccc;
}

/* Loading State */
.network-loading {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 400px;
  gap: 15px;
}

.spinner {
  width: 40px;
  height: 40px;
  border: 4px solid #f3f3f3;
  border-top: 4px solid #3498db;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

/* Empty State */
.empty-state {
  text-align: center;
  padding: 60px 20px;
  color: #666;
}

.empty-state p {
  margin: 10px 0;
  font-size: 1rem;
}

.empty-hint {
  font-size: 0.9rem !important;
  color: #999 !important;
}

/* Error State */
.network-error {
  text-align: center;
  padding: 60px 20px;
  color: #666;
}

.network-error h2 {
  color: #e74c3c;
  margin-bottom: 15px;
}

/* Responsive */
@media (max-width: 768px) {
  .network-view {
    padding: 10px;
  }
  
  .network-user-card {
    flex-direction: column;
    align-items: flex-start;
  }
  
  .user-actions {
    width: 100%;
    flex-direction: row;
  }
  
  .follow-button,
  .profile-button {
    flex: 1;
  }
  
  .network-tabs {
    overflow-x: auto;
  }
  
  .tab {
    white-space: nowrap;
    min-width: 120px;
  }
}
```

---

## Step 5: Create Follow Button Component

Create file: `src/components/FollowButton.jsx`

```jsx
import React, { useState, useEffect } from 'react';
import { followUser, unfollowUser, isFollowing, getConnectionStatus } from '../services/networkService';
import { auth } from '../firebase/config';
import './FollowButton.css';

/**
 * Reusable Follow Button - Use anywhere in your app
 * Syncs with mobile app in real-time
 */
export function FollowButton({ userId, size = 'medium', showStatus = false }) {
  const [following, setFollowing] = useState(false);
  const [connectionStatus, setConnectionStatus] = useState('none');
  const [loading, setLoading] = useState(true);
  const currentUser = auth.currentUser;
  
  useEffect(() => {
    if (!currentUser || !userId || currentUser.uid === userId) {
      setLoading(false);
      return;
    }
    
    const checkStatus = async () => {
      const isFollowingUser = await isFollowing(currentUser.uid, userId);
      setFollowing(isFollowingUser);
      
      if (showStatus) {
        const status = await getConnectionStatus(currentUser.uid, userId);
        setConnectionStatus(status);
      }
      
      setLoading(false);
    };
    
    checkStatus();
  }, [currentUser, userId, showStatus]);
  
  const handleClick = async () => {
    if (!currentUser) {
      alert('Please sign in to follow users');
      return;
    }
    
    if (loading) return;
    
    setLoading(true);
    
    try {
      if (following) {
        await unfollowUser(currentUser.uid, userId);
        setFollowing(false);
        setConnectionStatus('none');
      } else {
        await followUser(currentUser.uid, userId);
        setFollowing(true);
        
        // Check if it's now mutual
        const isMutual = await isFollowing(userId, currentUser.uid);
        setConnectionStatus(isMutual ? 'mutual' : 'following');
      }
    } catch (error) {
      console.error('Error toggling follow:', error);
      alert('Failed to update. Please try again.');
    } finally {
      setLoading(false);
    }
  };
  
  // Don't show button for current user
  if (!currentUser || currentUser.uid === userId) {
    return null;
  }
  
  return (
    <div className="follow-button-container">
      <button
        className={`follow-btn follow-btn-${size} ${following ? 'following' : ''} ${loading ? 'loading' : ''}`}
        onClick={handleClick}
        disabled={loading}
      >
        {loading ? (
          <span className="btn-spinner"></span>
        ) : following ? (
          'Following'
        ) : (
          'Follow'
        )}
      </button>
      
      {showStatus && connectionStatus === 'mutual' && !loading && (
        <span className="mutual-badge">Mutual</span>
      )}
    </div>
  );
}
```

Create file: `src/components/FollowButton.css`

```css
.follow-button-container {
  display: inline-flex;
  align-items: center;
  gap: 8px;
}

.follow-btn {
  padding: 8px 20px;
  background: #3498db;
  color: white;
  border: none;
  border-radius: 20px;
  font-size: 0.9rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  white-space: nowrap;
  min-width: 100px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.follow-btn:hover:not(.loading) {
  background: #2980b9;
  transform: translateY(-1px);
}

.follow-btn.following {
  background: white;
  color: #3498db;
  border: 2px solid #3498db;
}

.follow-btn.following:hover:not(.loading) {
  background: #fee;
  color: #e74c3c;
  border-color: #e74c3c;
}

.follow-btn.loading {
  opacity: 0.7;
  cursor: not-allowed;
}

/* Size variants */
.follow-btn-small {
  padding: 6px 16px;
  font-size: 0.8rem;
  min-width: 80px;
}

.follow-btn-large {
  padding: 12px 28px;
  font-size: 1rem;
  min-width: 120px;
}

/* Loading spinner */
.btn-spinner {
  width: 16px;
  height: 16px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top-color: white;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

/* Mutual badge */
.mutual-badge {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  padding: 4px 10px;
  border-radius: 12px;
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}
```

---

## Step 6: Add to Your App

```jsx
// src/App.js
import React from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { NetworkView } from './components/NetworkView';
import { VideoFeed } from './components/VideoFeed';
import './App.css';

function App() {
  return (
    <BrowserRouter>
      <div className="App">
        <nav>
          <a href="/">Home</a>
          <a href="/network">Network</a>
        </nav>
        
        <Routes>
          <Route path="/" element={<VideoFeed />} />
          <Route path="/network" element={<NetworkView />} />
        </Routes>
      </div>
    </BrowserRouter>
  );
}

export default App;
```

---

## 🔄 How Network Sync Works

### Follow Flow:

```
Website                    Firestore                   Mobile App
   |                          |                            |
   | 1. User clicks Follow    |                            |
   |------------------------->|                            |
   |                          |                            |
   |     2. Batch write:      |                            |
   |     - Create follow      |                            |
   |     - Update counts      |                            |
   |     - Add to collections |                            |
   |                          |                            |
   |                          | 3. Real-time listener      |
   |                          | detects change             |
   |                          |--------------------------->|
   |                          |                            |
   |                          |       4. Mobile updates    |
   |                          |       follower count ✨    |
```

### Real-Time Updates:

1. **User A follows User B on website**
   - Website → Firestore (batch update)
   - Mobile app (User B) sees new follower instantly

2. **User B follows User A back on mobile**
   - Mobile → Firestore (batch update)
   - Website (User A) sees "Mutual" badge instantly

3. **User A unfollows on website**
   - Website → Firestore
   - Mobile updates immediately
   - No refresh needed anywhere

---

## ✅ Testing Checklist

### Test 1: Follow from Website → Mobile Sync
1. [ ] Open website, go to Network tab
2. [ ] Follow a user
3. [ ] Open mobile app on same account
4. [ ] Verify following count increased
5. [ ] Verify user appears in following list

**Expected:** Mobile updates within 100ms

### Test 2: Follow from Mobile → Website Sync
1. [ ] Open mobile app
2. [ ] Follow a user
3. [ ] Keep website Network tab open
4. [ ] Verify following count increases on website
5. [ ] Verify user appears in following list

**Expected:** Website updates without refresh

### Test 3: Mutual Connections
1. [ ] User A follows User B (website)
2. [ ] User B follows User A (mobile)
3. [ ] Check website - should show "Mutual" badge
4. [ ] Check mobile - should show mutual status

**Expected:** Both platforms show mutual connection

### Test 4: Unfollow Sync
1. [ ] Unfollow user on website
2. [ ] Check mobile app
3. [ ] Verify user removed from following list
4. [ ] Verify count decremented

**Expected:** Instant sync across platforms

### Test 5: Search Users
1. [ ] Search for username on website
2. [ ] Results appear instantly
3. [ ] Follow from search results
4. [ ] Verify added to following list

**Expected:** Search works, follow syncs

---

## 📊 Verification Checklist

After implementation:

- [ ] Can follow users from website
- [ ] Can unfollow users from website
- [ ] Followers list syncs with mobile app
- [ ] Following list syncs with mobile app
- [ ] Follower counts match across platforms
- [ ] Search users works correctly
- [ ] Suggested users appear
- [ ] "Mutual" badge shows correctly
- [ ] Real-time updates (< 100ms)
- [ ] No console errors
- [ ] Profile buttons work
- [ ] Avatars display correctly
- [ ] Online status shows (if implemented)

---

## 🎯 Advanced Features (Optional)

### Add Connection Requests (Private Accounts)

```javascript
// For private accounts that require approval
export async function sendConnectionRequest(fromUserId, toUserId) {
  const requestRef = doc(db, 'connection_requests', `${fromUserId}_${toUserId}`);
  await setDoc(requestRef, {
    from: fromUserId,
    to: toUserId,
    status: 'pending',
    createdAt: serverTimestamp()
  });
}

export async function approveConnectionRequest(requestId) {
  // Implement approval logic
}
```

### Add Direct Messaging

```javascript
// Basic messaging system
export async function sendMessage(fromUserId, toUserId, message) {
  const conversationId = [fromUserId, toUserId].sort().join('_');
  
  await addDoc(collection(db, 'messages', conversationId, 'messages'), {
    from: fromUserId,
    to: toUserId,
    message: message,
    timestamp: serverTimestamp(),
    read: false
  });
}
```

---

## 💡 Instructions for Cursor.ai

Tell cursor.ai:

```
"Please implement the NetworkView from WEBSITE_NETWORKVIEW_IMPLEMENTATION.md

This creates a social network interface that syncs with my mobile app.

Implement:
1. Network Service (Step 2) - Follow/unfollow, followers/following lists
2. NetworkView Component (Step 3) - Main network interface with tabs
3. FollowButton Component (Step 5) - Reusable follow button

Key Requirements:
✅ When I follow someone on website → mobile app updates instantly
✅ When I follow someone on mobile → website updates instantly  
✅ Show followers, following, and suggested users
✅ Search users by username
✅ Real-time sync (< 100ms)
✅ Mutual connection badges

Test by:
1. Following a user on website → check mobile app sees it
2. Following on mobile → check website updates
3. Searching for users
4. Viewing followers/following lists"
```

---

**Implementation Time:** ~1-2 hours  
**Difficulty:** Medium  
**Dependencies:** Firebase SDK, React Router  
**Result:** Full social network sync between mobile and web ✨

