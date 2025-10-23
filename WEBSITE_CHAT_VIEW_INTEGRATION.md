# Website Chat View Video Sharing Integration Guide 💬

## Overview
This document provides the complete integration guide for implementing TikTok-style video share messages in the website chat view, matching the mobile app's beautiful video display functionality.

## Core Components

### 1. Message Model Enhancement

#### **Extended Message Interface**
```typescript
interface Message {
  id?: string;
  chatId?: string;
  text: string;
  from: string;
  to: string;
  timestamp?: Date;
  isRead: boolean;
  recipients: string[];
  readBy: string[];
  gifUrl?: string;
  messageType: string;
  isDeviceGif: boolean;
  // Video share fields
  videoId?: string;
  shareToken?: string;
  videoThumbnailUrl?: string;
  videoTitle?: string;
}
```

### 2. Video Share Message Component

#### **TikTok-Style Video Share UI**
```tsx
import React from 'react';

interface VideoShareMessageProps {
  message: Message;
  isFromCurrentUser: boolean;
  onVideoTap: (videoId: string) => void;
}

export const VideoShareMessage: React.FC<VideoShareMessageProps> = ({
  message,
  isFromCurrentUser,
  onVideoTap,
}) => {
  const handleVideoTap = () => {
    if (message.videoId) {
      onVideoTap(message.videoId);
    }
  };

  return (
    <div className={`message-bubble ${isFromCurrentUser ? 'outgoing' : 'incoming'}`}>
      <div className="video-share-container" onClick={handleVideoTap}>
        <div className="video-thumbnail">
          {message.videoThumbnailUrl ? (
            <img
              src={message.videoThumbnailUrl}
              alt="Video thumbnail"
              className="video-thumbnail-image"
              onError={(e) => {
                e.currentTarget.style.display = 'none';
                e.currentTarget.nextElementSibling.style.display = 'flex';
              }}
            />
          ) : null}
          
          {/* Gradient fallback */}
          <div 
            className="video-gradient-background"
            style={{ display: message.videoThumbnailUrl ? 'none' : 'flex' }}
          >
            <i className="fas fa-videocam"></i>
          </div>

          {/* Dark overlay for text visibility */}
          <div className="video-overlay"></div>

          {/* Play button */}
          <div className="video-play-button">
            <i className="fas fa-play"></i>
          </div>

          {/* Video info at bottom */}
          <div className="video-info">
            <div className="video-title">
              {message.videoTitle || 'Shared a video'}
            </div>
            <div className="video-subtitle">
              <i className="fas fa-play-circle"></i>
              <span>Tap to watch</span>
            </div>
          </div>

          {/* TikTok-style corner indicator */}
          <div className="video-corner-badge">
            <i className="fas fa-videocam"></i>
            <span>VIDEO</span>
          </div>
        </div>
      </div>
    </div>
  );
};
```

### 3. CSS Styling (TikTok-Style)

#### **Video Share Message Styles**
```css
.video-share-container {
  width: 240px;
  height: 180px;
  border-radius: 16px;
  overflow: hidden;
  cursor: pointer;
  position: relative;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
  transition: transform 0.2s ease;
}

.video-share-container:hover {
  transform: scale(1.02);
}

.video-thumbnail {
  width: 100%;
  height: 100%;
  position: relative;
  overflow: hidden;
}

.video-thumbnail-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.video-gradient-background {
  width: 100%;
  height: 100%;
  background: linear-gradient(135deg, 
    rgba(138, 43, 226, 0.8) 0%, 
    rgba(0, 191, 255, 0.8) 50%, 
    rgba(255, 20, 147, 0.8) 100%
  );
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-size: 40px;
}

.video-overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: linear-gradient(
    to bottom,
    transparent 0%,
    rgba(0, 0, 0, 0.3) 50%,
    rgba(0, 0, 0, 0.6) 100%
  );
  pointer-events: none;
}

.video-play-button {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  width: 70px;
  height: 70px;
  background: rgba(255, 255, 255, 0.9);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
  pointer-events: none;
}

.video-play-button i {
  color: #000;
  font-size: 35px;
  margin-left: 3px; /* Slight offset for play icon */
}

.video-info {
  position: absolute;
  bottom: 12px;
  left: 12px;
  right: 12px;
  color: white;
  pointer-events: none;
}

.video-title {
  font-size: 16px;
  font-weight: 600;
  line-height: 1.2;
  margin-bottom: 4px;
  text-shadow: 0 1px 4px rgba(0, 0, 0, 0.8);
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.video-subtitle {
  display: flex;
  align-items: center;
  font-size: 13px;
  font-weight: 500;
  opacity: 0.8;
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.8);
}

.video-subtitle i {
  margin-right: 4px;
  font-size: 16px;
}

.video-corner-badge {
  position: absolute;
  top: 8px;
  right: 8px;
  background: rgba(0, 0, 0, 0.6);
  padding: 4px 8px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  color: white;
  font-size: 10px;
  font-weight: 600;
  letter-spacing: 0.5px;
  pointer-events: none;
}

.video-corner-badge i {
  margin-right: 4px;
  font-size: 12px;
}

/* Message bubble positioning */
.message-bubble.outgoing .video-share-container {
  margin-left: auto;
}

.message-bubble.incoming .video-share-container {
  margin-right: auto;
}
```

### 4. Chat View Integration

#### **Message Rendering Logic**
```tsx
import React from 'react';
import { VideoShareMessage } from './VideoShareMessage';

interface ChatViewProps {
  messages: Message[];
  currentUserId: string;
  onVideoTap: (videoId: string) => void;
}

export const ChatView: React.FC<ChatViewProps> = ({
  messages,
  currentUserId,
  onVideoTap,
}) => {
  const renderMessage = (message: Message, index: number) => {
    const isFromCurrentUser = message.from === currentUserId;

    // Handle video share messages
    if (message.messageType === 'video_share' && message.videoId) {
      return (
        <VideoShareMessage
          key={message.id || index}
          message={message}
          isFromCurrentUser={isFromCurrentUser}
          onVideoTap={onVideoTap}
        />
      );
    }

    // Handle GIF messages
    if (message.messageType === 'gif' && message.gifUrl) {
      return (
        <div className={`message-bubble ${isFromCurrentUser ? 'outgoing' : 'incoming'}`}>
          <img
            src={message.gifUrl}
            alt="GIF"
            className="gif-message"
            style={{ maxWidth: '200px', borderRadius: '12px' }}
          />
        </div>
      );
    }

    // Handle text messages
    return (
      <div className={`message-bubble ${isFromCurrentUser ? 'outgoing' : 'incoming'}`}>
        <div className="message-text">
          {message.text}
        </div>
      </div>
    );
  };

  return (
    <div className="chat-messages">
      {messages.map((message, index) => renderMessage(message, index))}
    </div>
  );
};
```

### 5. Video Navigation Service

#### **Video Player Navigation**
```typescript
class VideoNavigationService {
  async navigateToVideo(videoId: string): Promise<void> {
    try {
      // Fetch video data from Firestore
      const videoDoc = await db.collection('videos').doc(videoId).get();
      
      if (!videoDoc.exists) {
        this.showVideoUnavailable();
        return;
      }

      const videoData = videoDoc.data()!;

      // Check if video is deleted or private
      if (videoData.isDeleted === true) {
        this.showVideoUnavailable();
        return;
      }

      // Convert to video object for player
      const video = this.convertToVideoObject(videoData, videoId);

      // Navigate to video player
      this.openVideoPlayer(video);
    } catch (error) {
      console.error('Error navigating to video:', error);
      this.showErrorMessage('Unable to open video');
    }
  }

  private convertToVideoObject(data: any, videoId: string) {
    return {
      id: videoId,
      creator: {
        id: data.userId || '',
        displayName: data.displayName || 'Unknown',
        username: data.username || 'unknown',
        avatarURL: data.userAvatarUrl || '',
        bio: data.bio || '',
        followerCount: data.followerCount || 0,
        followingCount: data.followingCount || 0,
      },
      videoURL: data.videoUrl || '',
      thumbnailURL: data.thumbnailUrl || '',
      likes: data.likeCount || 0,
      comments: data.commentCount || 0,
      views: data.viewCount || 0,
      caption: data.caption || '',
      categoryId: data.category || 'general',
      createdAt: data.timestamp,
    };
  }

  private openVideoPlayer(video: any) {
    // Navigate to video player page
    window.location.href = `/video/${video.id}`;
    // Or use your routing system:
    // router.push(`/video/${video.id}`);
  }

  private showVideoUnavailable() {
    // Show modal or alert
    alert('This video is no longer available or has been deleted.');
  }

  private showErrorMessage(message: string) {
    // Show error message
    console.error(message);
    alert(message);
  }
}
```

### 6. Real-time Message Updates

#### **Firestore Listener for Chat Messages**
```typescript
class ChatService {
  private unsubscribe: (() => void) | null = null;

  subscribeToMessages(
    chatId: string,
    onMessagesUpdate: (messages: Message[]) => void
  ) {
    this.unsubscribe = db
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('timestamp', 'asc')
      .onSnapshot(
        (snapshot) => {
          const messages: Message[] = snapshot.docs.map((doc) => {
            const data = doc.data();
            return {
              id: doc.id,
              chatId: chatId,
              text: data.text || '',
              from: data.from || '',
              to: data.to || '',
              timestamp: data.timestamp?.toDate(),
              isRead: data.read || false,
              recipients: data.recipients || [],
              readBy: data.readBy || [],
              gifUrl: data.gifUrl,
              messageType: data.messageType || 'text',
              isDeviceGif: data.isDeviceGif || false,
              // Video share fields
              videoId: data.videoId,
              shareToken: data.shareToken,
              videoThumbnailUrl: data.videoThumbnailUrl,
              videoTitle: data.videoTitle,
            };
          });
          onMessagesUpdate(messages);
        },
        (error) => {
          console.error('Error listening to messages:', error);
        }
      );
  }

  unsubscribeFromMessages() {
    if (this.unsubscribe) {
      this.unsubscribe();
      this.unsubscribe = null;
    }
  }
}
```

### 7. Complete Chat View Component

#### **Full Implementation**
```tsx
import React, { useState, useEffect } from 'react';
import { ChatService } from './services/ChatService';
import { VideoNavigationService } from './services/VideoNavigationService';
import { VideoShareMessage } from './VideoShareMessage';

interface ChatViewProps {
  chatId: string;
  currentUserId: string;
}

export const ChatView: React.FC<ChatViewProps> = ({
  chatId,
  currentUserId,
}) => {
  const [messages, setMessages] = useState<Message[]>([]);
  const [loading, setLoading] = useState(true);
  
  const chatService = new ChatService();
  const videoNavigationService = new VideoNavigationService();

  useEffect(() => {
    // Subscribe to real-time message updates
    chatService.subscribeToMessages(chatId, (newMessages) => {
      setMessages(newMessages);
      setLoading(false);
    });

    // Cleanup subscription on unmount
    return () => {
      chatService.unsubscribeFromMessages();
    };
  }, [chatId]);

  const handleVideoTap = (videoId: string) => {
    videoNavigationService.navigateToVideo(videoId);
  };

  const renderMessage = (message: Message, index: number) => {
    const isFromCurrentUser = message.from === currentUserId;

    // Video share messages
    if (message.messageType === 'video_share' && message.videoId) {
      return (
        <VideoShareMessage
          key={message.id || index}
          message={message}
          isFromCurrentUser={isFromCurrentUser}
          onVideoTap={handleVideoTap}
        />
      );
    }

    // GIF messages
    if (message.messageType === 'gif' && message.gifUrl) {
      return (
        <div className={`message-bubble ${isFromCurrentUser ? 'outgoing' : 'incoming'}`}>
          <img
            src={message.gifUrl}
            alt="GIF"
            className="gif-message"
          />
        </div>
      );
    }

    // Text messages
    return (
      <div className={`message-bubble ${isFromCurrentUser ? 'outgoing' : 'incoming'}`}>
        <div className="message-text">
          {message.text}
        </div>
      </div>
    );
  };

  if (loading) {
    return <div className="chat-loading">Loading messages...</div>;
  }

  return (
    <div className="chat-view">
      <div className="chat-messages">
        {messages.length === 0 ? (
          <div className="empty-chat">
            <i className="fas fa-comment-slash"></i>
            <p>No messages yet</p>
            <p>Start the conversation!</p>
          </div>
        ) : (
          messages.map((message, index) => renderMessage(message, index))
        )}
      </div>
    </div>
  );
};
```

## Key Implementation Notes

### **Message Type Handling**
- Always check `messageType === 'video_share'` before rendering video components
- Ensure `videoId` exists before attempting to display video share
- Provide fallback rendering for unknown message types

### **Video Data Fetching**
- Fetch real video titles and thumbnails from Firestore
- Use `caption` field for video titles (not `title`)
- Use `avatarURL` field for user avatars (capital L)
- Handle missing data gracefully with fallbacks

### **Performance Optimization**
- Use proper image loading with error handling
- Implement lazy loading for video thumbnails
- Cache video data to avoid repeated API calls
- Use efficient Firestore queries with proper indexing

### **User Experience**
- Provide visual feedback during video loading
- Show proper error states for failed video loads
- Implement smooth animations and transitions
- Ensure responsive design for all screen sizes

### **Security**
- Validate video IDs before navigation
- Check user permissions for video access
- Sanitize video titles and metadata
- Implement proper error handling

This implementation provides the complete TikTok-style video share message functionality for the website chat view, matching the mobile app's beautiful and intuitive video sharing experience.
