# Website Share Sheet Integration Guide 📱

## Overview
This document provides the complete integration guide for implementing TikTok-style video sharing with connections in the website, matching the mobile app functionality.

## Core Components

### 1. Share Sheet UI Components

#### **Enhanced Share Sheet Structure**
```typescript
interface ShareSheetProps {
  videoId: string;
  videoTitle: string;
  videoThumbnailUrl: string;
  onClose: () => void;
}

interface ConnectionLite {
  userId: string;
  handle: string;
  displayName: string;
  avatarUrl: string;
  isOnline: boolean;
  lastInteractedAt?: number;
  canDM: boolean;
  rankingScore: number;
}
```

#### **Share Sheet Layout (TikTok Style)**
```css
.share-sheet {
  height: 60vh;
  max-height: 500px;
  background: linear-gradient(135deg, #1a1a1a 0%, #2d2d2d 100%);
  border-radius: 20px 20px 0 0;
  padding: 20px;
  display: flex;
  flex-direction: column;
}

.connections-row {
  height: 100px;
  margin-bottom: 30px;
  overflow-x: auto;
  overflow-y: hidden;
}

.connection-avatar {
  width: 60px;
  height: 60px;
  border-radius: 50%;
  margin-right: 12px;
  cursor: pointer;
  transition: transform 0.2s;
}

.connection-avatar:hover {
  transform: scale(1.1);
}

.share-targets {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 16px;
  margin-bottom: 20px;
}

.share-target-button {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 12px;
  background: rgba(255, 255, 255, 0.1);
  border-radius: 12px;
  cursor: pointer;
  transition: background 0.2s;
}

.share-target-button:hover {
  background: rgba(255, 255, 255, 0.2);
}
```

### 2. Connections Service

#### **Fetch Connections from Multiple Sources**
```typescript
class ConnectionsService {
  async getConnections(userId: string): Promise<ConnectionLite[]> {
    const connections: ConnectionLite[] = [];
    const processedUserIds = new Set<string>();

    try {
      // 1. Fetch from users/{userId}/connections subcollection
      const connectionsSnapshot = await db
        .collection('users')
        .doc(userId)
        .collection('connections')
        .get();

      for (const doc of connectionsSnapshot.docs) {
        const connectionData = doc.data();
        if (!processedUserIds.has(connectionData.userId)) {
          const userData = await this.getUserData(connectionData.userId);
          if (userData) {
            connections.push({
              userId: connectionData.userId,
              handle: userData.username,
              displayName: userData.displayName,
              avatarUrl: userData.avatarURL, // Note: capital L
              isOnline: userData.onlineStatus === 'online',
              lastInteractedAt: connectionData.lastInteractedAt,
              canDM: true,
              rankingScore: 1.0,
            });
            processedUserIds.add(connectionData.userId);
          }
        }
      }

      // 2. Fetch from relationships collection (followers)
      const followersSnapshot = await db
        .collection('relationships')
        .where('followerId', '==', userId)
        .get();

      for (const doc of followersSnapshot.docs) {
        const relationshipData = doc.data();
        if (!processedUserIds.has(relationshipData.followingId)) {
          const userData = await this.getUserData(relationshipData.followingId);
          if (userData) {
            connections.push({
              userId: relationshipData.followingId,
              handle: userData.username,
              displayName: userData.displayName,
              avatarUrl: userData.avatarURL,
              isOnline: userData.onlineStatus === 'online',
              lastInteractedAt: relationshipData.createdAt?.toMillis(),
              canDM: true,
              rankingScore: 2.0,
            });
            processedUserIds.add(relationshipData.followingId);
          }
        }
      }

      // 3. Fetch from relationships collection (following)
      const followingSnapshot = await db
        .collection('relationships')
        .where('followingId', '==', userId)
        .get();

      for (const doc of followingSnapshot.docs) {
        const relationshipData = doc.data();
        if (!processedUserIds.has(relationshipData.followerId)) {
          const userData = await this.getUserData(relationshipData.followerId);
          if (userData) {
            connections.push({
              userId: relationshipData.followerId,
              handle: userData.username,
              displayName: userData.displayName,
              avatarUrl: userData.avatarURL,
              isOnline: userData.onlineStatus === 'online',
              lastInteractedAt: relationshipData.createdAt?.toMillis(),
              canDM: true,
              rankingScore: 2.0,
            });
            processedUserIds.add(relationshipData.followerId);
          }
        }
      }

      // Sort by ranking score and last interaction
      return connections.sort((a, b) => {
        if (a.rankingScore !== b.rankingScore) {
          return b.rankingScore - a.rankingScore;
        }
        return (b.lastInteractedAt || 0) - (a.lastInteractedAt || 0);
      });
    } catch (error) {
      console.error('Error fetching connections:', error);
      return [];
    }
  }

  private async getUserData(userId: string) {
    const userDoc = await db.collection('users').doc(userId).get();
    return userDoc.exists ? userDoc.data() : null;
  }
}
```

### 3. Video Sharing Implementation

#### **Share to Connection**
```typescript
class VideoSharingService {
  async shareToConnection(
    recipientId: string,
    videoId: string,
    shareToken: string
  ): Promise<void> {
    try {
      // Fetch video data for better display
      let videoTitle = 'Shared a video';
      let videoThumbnailUrl = '';

      try {
        const videoDoc = await db.collection('videos').doc(videoId).get();
        if (videoDoc.exists) {
          const videoData = videoDoc.data()!;
          videoTitle = videoData.caption || videoData.title || 'Shared a video';
          videoThumbnailUrl = videoData.thumbnailUrl || '';
        }
      } catch (error) {
        console.warn('Could not fetch video data:', error);
      }

      // Find or create chat
      const chatId = await this.findOrCreateChat(recipientId);

      // Create message data
      const messageData = {
        type: 'video_share',
        messageType: 'video_share',
        from: getCurrentUserId(),
        senderId: getCurrentUserId(),
        recipientId: recipientId,
        videoId: videoId,
        shareToken: shareToken,
        videoTitle: videoTitle,
        videoThumbnailUrl: videoThumbnailUrl,
        text: 'Shared a video',
        timestamp: firebase.firestore.FieldValue.serverTimestamp(),
        read: false,
        readBy: [getCurrentUserId()],
      };

      // Add message to chat
      await db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(messageData);

      // Update chat metadata
      await db.collection('chats').doc(chatId).update({
        lastMessage: 'Shared a video',
        lastTimestamp: firebase.firestore.FieldValue.serverTimestamp(),
        unreadCount: firebase.firestore.FieldValue.increment(1),
      });

      console.log('Video shared successfully to', recipientId);
    } catch (error) {
      console.error('Error sharing video:', error);
      throw error;
    }
  }

  private async findOrCreateChat(otherUserId: string): Promise<string> {
    const currentUserId = getCurrentUserId();

    // Try to find existing chat
    const existingQuery = await db
      .collection('chats')
      .where('participants', 'array-contains', currentUserId)
      .get();

    for (const doc of existingQuery.docs) {
      const participants = doc.data().participants || [];
      if (participants.includes(otherUserId)) {
        return doc.id;
      }
    }

    // Create new chat
    const chatData = {
      participants: [currentUserId, otherUserId],
      lastMessage: '',
      lastTimestamp: firebase.firestore.FieldValue.serverTimestamp(),
      chatType: 'direct',
      unreadCount: 0,
    };

    const docRef = await db.collection('chats').add(chatData);
    return docRef.id;
  }
}
```

### 4. Firestore Security Rules

#### **Chats Collection Rules**
```javascript
// Chats collection
match /chats/{chatId} {
  // Allow creating new chats if the user is a participant
  allow create: if request.auth != null &&
    request.auth.uid in request.resource.data.participants;

  // Allow reading and updating existing chats if the user is a participant
  allow read, update: if request.auth != null &&
    request.auth.uid in resource.data.participants;

  // Allow listing chats for authenticated users
  allow list: if request.auth != null;

  // Allow deleting chats if the user is a participant
  allow delete: if request.auth != null &&
    request.auth.uid in resource.data.participants;

  // Messages subcollection
  match /messages/{messageId} {
    // Allow reading messages if user is a participant in parent chat
    allow read: if request.auth != null &&
      request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants;

    // Allow listing messages if user is a participant in parent chat
    allow list: if request.auth != null &&
      request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants;

    // Allow creating messages if user is the sender OR a participant in the chat
    allow create: if request.auth != null &&
      (request.auth.uid == request.resource.data.from ||
       request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants);

    // Allow updating messages if user is a participant (for read receipts)
    allow update: if request.auth != null &&
      request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants;

    // Allow deleting messages if user is the sender (use 'from' field)
    allow delete: if request.auth.uid == resource.data.from;
  }
}
```

### 5. UI Implementation

#### **React Component Example**
```tsx
import React, { useState, useEffect } from 'react';
import { ConnectionsService } from './services/ConnectionsService';
import { VideoSharingService } from './services/VideoSharingService';

interface ShareSheetProps {
  videoId: string;
  videoTitle: string;
  videoThumbnailUrl: string;
  onClose: () => void;
}

export const ShareSheet: React.FC<ShareSheetProps> = ({
  videoId,
  videoTitle,
  videoThumbnailUrl,
  onClose,
}) => {
  const [connections, setConnections] = useState<ConnectionLite[]>([]);
  const [loading, setLoading] = useState(true);
  const [sharing, setSharing] = useState<string | null>(null);

  const connectionsService = new ConnectionsService();
  const videoSharingService = new VideoSharingService();

  useEffect(() => {
    loadConnections();
  }, []);

  const loadConnections = async () => {
    try {
      setLoading(true);
      const userConnections = await connectionsService.getConnections(getCurrentUserId());
      setConnections(userConnections);
    } catch (error) {
      console.error('Error loading connections:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleConnectionTap = async (connection: ConnectionLite) => {
    try {
      setSharing(connection.userId);
      const shareToken = generateShareToken(videoId);
      
      await videoSharingService.shareToConnection(
        connection.userId,
        videoId,
        shareToken
      );
      
      // Show success feedback
      showSuccessMessage(`Video sent to ${connection.displayName}!`);
      onClose();
    } catch (error) {
      console.error('Error sharing video:', error);
      showErrorMessage('Could not send video');
    } finally {
      setSharing(null);
    }
  };

  const generateShareToken = (videoId: string): string => {
    const timestamp = Date.now();
    const random = (timestamp % 10000).toString().padStart(4, '0');
    return `${videoId}_${timestamp}_${random}`;
  };

  return (
    <div className="share-sheet">
      {/* Connections Row */}
      <div className="connections-row">
        <h3>Share to Connections</h3>
        <div className="connections-list">
          {loading ? (
            <div>Loading connections...</div>
          ) : (
            connections.map((connection) => (
              <div
                key={connection.userId}
                className="connection-item"
                onClick={() => handleConnectionTap(connection)}
              >
                <img
                  src={connection.avatarUrl || '/default-avatar.png'}
                  alt={connection.displayName}
                  className="connection-avatar"
                />
                <span className="connection-name">
                  {connection.displayName}
                </span>
                {sharing === connection.userId && (
                  <div className="sharing-indicator">Sending...</div>
                )}
              </div>
            ))
          )}
        </div>
      </div>

      {/* Share Targets */}
      <div className="share-targets">
        <div className="share-target-button">
          <i className="fab fa-whatsapp"></i>
          <span>WhatsApp</span>
        </div>
        <div className="share-target-button">
          <i className="fab fa-instagram"></i>
          <span>Instagram</span>
        </div>
        <div className="share-target-button">
          <i className="fab fa-twitter"></i>
          <span>Twitter</span>
        </div>
        <div className="share-target-button">
          <i className="fab fa-facebook"></i>
          <span>Facebook</span>
        </div>
      </div>

      {/* Action Buttons */}
      <div className="action-buttons">
        <button className="action-button">
          <i className="fas fa-copy"></i>
          <span>Copy Link</span>
        </button>
        <button className="action-button">
          <i className="fas fa-download"></i>
          <span>Download</span>
        </button>
      </div>
    </div>
  );
};
```

## Key Implementation Notes

### **Field Name Consistency**
- Use `avatarURL` (capital L) when accessing user data from Firestore
- Use `caption` for video titles (not `title`)
- Use `thumbnailUrl` for video thumbnails

### **Error Handling**
- Always handle cases where video data might not exist
- Provide fallback values for missing data
- Show user-friendly error messages

### **Performance Optimization**
- Cache connections data to avoid repeated API calls
- Use pagination for large connection lists
- Implement proper loading states

### **Security**
- Ensure proper Firestore rules are in place
- Validate user permissions before sharing
- Sanitize user input

This implementation provides the complete TikTok-style share sheet functionality for the website, matching the mobile app's behavior exactly.
