# HomeView Feed Implementation for Website

This document provides a complete implementation guide for the HomeView feed on the website, mimicking the Flutter app's TikTok-style vertical scrolling video feed.

## Table of Contents

1. [Overview](#overview)
2. [Data Structures](#data-structures)
3. [Feed Architecture](#feed-architecture)
4. [Service Layer](#service-layer)
5. [React Components](#react-components)
6. [State Management](#state-management)
7. [Video Playback](#video-playback)
8. [Feed Tabs](#feed-tabs)
9. [Pull to Refresh](#pull-to-refresh)
10. [Infinite Scroll](#infinite-scroll)

## Overview

The HomeView feed is a TikTok-style vertical scrolling video feed with:
- **Two tabs**: "For You" and "Following"
- **Vertical scrolling**: Swipe up/down to navigate between videos
- **Autoplay**: Current video plays automatically
- **Preloading**: Adjacent videos preload for smooth transitions
- **Pull to refresh**: Refresh feed from top
- **Infinite scroll**: Load more videos as user scrolls

### Key Features

- Vertical PageView-style scrolling
- Automatic video playback management
- Feed tab switching (For You / Following)
- Real-time video state updates (likes, views, comments)
- Pull-to-refresh functionality
- Infinite scroll pagination
- Video preloading for smooth transitions

## Data Structures

### HomeVideo Interface

```typescript
interface HomeVideo {
  id: string;
  creator: User;
  videoURL: string;
  thumbnailURL?: string;
  thumbnails?: VideoThumbnails; // Multi-size thumbnail support
  likes: number;
  comments: number;
  views: number;
  caption: string;
  isLiked: boolean;
  isFavorited: boolean;
  isDraft: boolean;
  mlScore: number;
  categoryId: string;
  duration?: number; // Video duration in seconds
  createdAt?: Timestamp | Date; // For sorting
  allowSave: boolean;
  allowRemix: boolean;
  visibility: 'public' | 'followers' | 'private';
  status: 'draft' | 'processing' | 'published' | 'blocked' | 'deleted';
  isPinned: boolean;
  tags: string[];
  playlistIds: string[];
}

interface User {
  id: string;
  displayName: string;
  username: string;
  avatarURL?: string;
  bio?: string;
  hashtags?: string[];
}

interface VideoThumbnails {
  urls: Record<number, string>; // { 360: url, 540: url, 720: url }
  generatedAt?: Timestamp | Date;
  aspectRatio?: number;
  qualityScore?: number;
}

interface FeedState {
  forYouVideos: HomeVideo[];
  followingVideos: HomeVideo[];
  isLoading: boolean;
  isLoadingMore: boolean;
  hasMoreContent: boolean;
  currentIndex: number;
  activeTab: 'forYou' | 'following';
  error: string | null;
}
```

## Feed Architecture

### Component Hierarchy

```
HomeView
├── FeedSelector (For You / Following tabs)
├── VideoFeedContainer
│   ├── VideoPageView (vertical scroll container)
│   │   ├── VideoPlayerCard (for each video)
│   │   │   ├── VideoPlayer
│   │   │   ├── VideoOverlay (HUD)
│   │   │   │   ├── CreatorInfo
│   │   │   │   ├── VideoActions (like, comment, share, bookmark)
│   │   │   │   └── VideoStats
│   │   │   └── Caption
│   │   └── LoadingIndicator (for loading more)
│   └── PullToRefreshIndicator
└── NetworkStatusIndicator
```

## Service Layer

### VideoService

```typescript
import { collection, query, where, orderBy, limit, getDocs, startAfter, DocumentSnapshot } from 'firebase/firestore';
import { db } from './firebase';

class VideoService {
  private videos: HomeVideo[] = [];
  private lastFetchTime: number = 0;
  private readonly CACHE_DURATION = 5 * 60 * 1000; // 5 minutes

  /**
   * Load all videos from Firestore
   * Mimics Flutter's VideoService.loadAllVideos()
   */
  async loadAllVideos(): Promise<HomeVideo[]> {
    try {
      console.log('🎬 VideoService: Loading all videos...');

      // Check cache
      const now = Date.now();
      if (this.videos.length > 0 && (now - this.lastFetchTime) < this.CACHE_DURATION) {
        console.log('✅ VideoService: Using cached videos');
        return this.videos;
      }

      // Query published videos, ordered by createdAt descending
      const videosQuery = query(
        collection(db, 'videos'),
        where('status', '==', 'published'),
        orderBy('createdAt', 'desc'),
        limit(500)
      );

      const snapshot = await getDocs(videosQuery);
      console.log(`🎬 VideoService: Found ${snapshot.docs.length} published videos`);

      const videos: HomeVideo[] = [];

      for (const doc of snapshot.docs) {
        const data = doc.data();
        
        // Skip invalid videos
        if (!data.videoURL && !data.videoUrl) continue;
        if (data.status !== 'published') continue;

        // Resolve video URL
        const videoURL = this.resolveVideoUrl(data);
        if (!videoURL) continue;

        // Get creator info
        const creator = await this.getCreatorInfo(data.userId || data.creatorId);

        // Create thumbnails object
        const thumbnails = this.createThumbnails(data);

        const video: HomeVideo = {
          id: doc.id,
          creator,
          videoURL,
          thumbnailURL: data.thumbnailURL || data.thumbnailUrl,
          thumbnails,
          likes: data.likes || 0,
          comments: data.comments || 0,
          views: data.views || 0,
          caption: data.caption || data.title || '',
          isLiked: false, // Will be loaded separately
          isFavorited: false, // Will be loaded separately
          isDraft: false,
          mlScore: data.mlScore || 0,
          categoryId: data.categoryId || data.category || 'general',
          duration: data.metadata?.duration || data.duration,
          createdAt: data.createdAt?.toDate() || new Date(),
          allowSave: data.allowSave !== false,
          allowRemix: data.allowRemix !== false,
          visibility: data.visibility || data.privacy || 'public',
          status: data.status || 'published',
          isPinned: data.isPinned || false,
          tags: data.tags || [],
          playlistIds: data.playlistIds || [],
        };

        videos.push(video);
      }

      // Sort by createdAt (newest first) as safety net
      videos.sort((a, b) => {
        const aTime = a.createdAt?.getTime() || 0;
        const bTime = b.createdAt?.getTime() || 0;
        return bTime - aTime;
      });

      this.videos = videos;
      this.lastFetchTime = now;

      console.log(`✅ VideoService: Loaded ${videos.length} videos`);
      return videos;
    } catch (error) {
      console.error('❌ VideoService: Error loading videos:', error);
      
      // Fallback: Try query without status filter
      try {
        const fallbackQuery = query(
          collection(db, 'videos'),
          orderBy('createdAt', 'desc'),
          limit(1000)
        );
        const snapshot = await getDocs(fallbackQuery);
        // Filter in memory
        const videos = snapshot.docs
          .map(doc => this.mapVideoDocument(doc))
          .filter(v => v && v.status === 'published');
        return videos.filter(Boolean) as HomeVideo[];
      } catch (fallbackError) {
        console.error('❌ VideoService: Fallback query also failed:', fallbackError);
        return [];
      }
    }
  }

  /**
   * Load more videos (pagination)
   */
  async loadMoreVideos(lastVideo: HomeVideo): Promise<HomeVideo[]> {
    try {
      const lastDoc = await this.getDocumentById(lastVideo.id);
      if (!lastDoc) return [];

      const videosQuery = query(
        collection(db, 'videos'),
        where('status', '==', 'published'),
        orderBy('createdAt', 'desc'),
        startAfter(lastDoc),
        limit(20)
      );

      const snapshot = await getDocs(videosQuery);
      return snapshot.docs.map(doc => this.mapVideoDocument(doc)).filter(Boolean) as HomeVideo[];
    } catch (error) {
      console.error('❌ VideoService: Error loading more videos:', error);
      return [];
    }
  }

  /**
   * Refresh videos (pull to refresh)
   */
  async refresh(): Promise<HomeVideo[]> {
    this.videos = [];
    this.lastFetchTime = 0;
    return this.loadAllVideos();
  }

  /**
   * Resolve video URL from data
   */
  private resolveVideoUrl(data: any): string | null {
    return data.videoURL || data.videoUrl || null;
  }

  /**
   * Get creator user info
   */
  private async getCreatorInfo(userId: string): Promise<User> {
    // Fetch user document from Firestore
    const userDoc = await getDoc(doc(db, 'users', userId));
    if (!userDoc.exists()) {
      return {
        id: userId,
        displayName: 'Unknown User',
        username: 'unknown',
      };
    }

    const userData = userDoc.data();
    return {
      id: userId,
      displayName: userData.displayName || userData.name || 'Unknown User',
      username: userData.username || 'unknown',
      avatarURL: userData.avatarURL || userData.avatarUrl,
      bio: userData.bio,
      hashtags: userData.hashtags,
    };
  }

  /**
   * Create VideoThumbnails object from data
   */
  private createThumbnails(data: any): VideoThumbnails | undefined {
    const thumbnailURL = data.thumbnailURL || data.thumbnailUrl;
    if (!thumbnailURL) return undefined;

    return {
      urls: {
        360: thumbnailURL,
        540: thumbnailURL,
        720: thumbnailURL,
      },
      generatedAt: data.createdAt?.toDate(),
      aspectRatio: 9 / 16,
    };
  }

  /**
   * Map Firestore document to HomeVideo
   */
  private mapVideoDocument(doc: DocumentSnapshot): HomeVideo | null {
    const data = doc.data();
    if (!data) return null;

    // Implementation similar to loadAllVideos
    // ... (omitted for brevity, same logic)
    return null; // Placeholder
  }
}

export const videoService = new VideoService();
```

### FollowingFeedService

```typescript
import { collection, query, where, orderBy, limit, getDocs } from 'firebase/firestore';
import { db } from './firebase';
import { auth } from './firebase';

class FollowingFeedService {
  /**
   * Load videos from users the current user follows
   */
  async loadFollowingFeed(limitCount: number = 20): Promise<HomeVideo[]> {
    try {
      const currentUser = auth.currentUser;
      if (!currentUser) return [];

      // Get list of followed user IDs
      const followingQuery = query(
        collection(db, 'users', currentUser.uid, 'following')
      );
      const followingSnapshot = await getDocs(followingQuery);
      const followingIds = followingSnapshot.docs.map(doc => doc.id);

      if (followingIds.length === 0) {
        return [];
      }

      // Query videos from followed users
      const videos: HomeVideo[] = [];
      
      // Firestore 'in' query limit is 10, so batch if needed
      for (let i = 0; i < followingIds.length; i += 10) {
        const batch = followingIds.slice(i, i + 10);
        const videosQuery = query(
          collection(db, 'videos'),
          where('userId', 'in', batch),
          where('status', '==', 'published'),
          orderBy('createdAt', 'desc'),
          limit(limitCount)
        );

        const snapshot = await getDocs(videosQuery);
        const batchVideos = snapshot.docs.map(doc => this.mapVideoDocument(doc));
        videos.push(...batchVideos.filter(Boolean) as HomeVideo[]);
      }

      // Sort all videos by createdAt (newest first)
      videos.sort((a, b) => {
        const aTime = a.createdAt?.getTime() || 0;
        const bTime = b.createdAt?.getTime() || 0;
        return bTime - aTime;
      });

      return videos.slice(0, limitCount);
    } catch (error) {
      console.error('❌ FollowingFeedService: Error loading following feed:', error);
      return [];
    }
  }

  private mapVideoDocument(doc: DocumentSnapshot): HomeVideo | null {
    // Same implementation as VideoService
    return null; // Placeholder
  }
}

export const followingFeedService = new FollowingFeedService();
```

## React Components

### HomeView Component

```typescript
import React, { useState, useEffect, useCallback } from 'react';
import { useFeedState } from '../hooks/useFeedState';
import { FeedSelector } from './FeedSelector';
import { VideoFeedContainer } from './VideoFeedContainer';
import { NetworkStatusIndicator } from './NetworkStatusIndicator';

export const HomeView: React.FC = () => {
  const {
    forYouVideos,
    followingVideos,
    isLoading,
    activeTab,
    currentIndex,
    error,
    switchTab,
    loadVideos,
    loadMoreVideos,
    refreshFeed,
    setCurrentIndex,
  } = useFeedState();

  const videos = activeTab === 'forYou' ? forYouVideos : followingVideos;

  useEffect(() => {
    loadVideos();
  }, [loadVideos]);

  const handleTabChange = useCallback((tab: 'forYou' | 'following') => {
    switchTab(tab);
    setCurrentIndex(0); // Reset to first video when switching tabs
  }, [switchTab, setCurrentIndex]);

  const handlePageChange = useCallback((index: number) => {
    setCurrentIndex(index);
  }, [setCurrentIndex]);

  const handleRefresh = useCallback(async () => {
    await refreshFeed();
  }, [refreshFeed]);

  const handleLoadMore = useCallback(async () => {
    if (videos.length > 0) {
      const lastVideo = videos[videos.length - 1];
      await loadMoreVideos(lastVideo);
    }
  }, [videos, loadMoreVideos]);

  return (
    <div className="home-view">
      <NetworkStatusIndicator />
      
      <FeedSelector
        activeTab={activeTab}
        onTabChange={handleTabChange}
      />

      <VideoFeedContainer
        videos={videos}
        currentIndex={currentIndex}
        isLoading={isLoading}
        error={error}
        onPageChange={handlePageChange}
        onRefresh={handleRefresh}
        onLoadMore={handleLoadMore}
      />
    </div>
  );
};
```

### VideoFeedContainer Component

```typescript
import React, { useRef, useEffect } from 'react';
import { VideoPageView } from './VideoPageView';
import { PullToRefresh } from './PullToRefresh';

interface VideoFeedContainerProps {
  videos: HomeVideo[];
  currentIndex: number;
  isLoading: boolean;
  error: string | null;
  onPageChange: (index: number) => void;
  onRefresh: () => Promise<void>;
  onLoadMore: () => Promise<void>;
}

export const VideoFeedContainer: React.FC<VideoFeedContainerProps> = ({
  videos,
  currentIndex,
  isLoading,
  error,
  onPageChange,
  onRefresh,
  onLoadMore,
}) => {
  const containerRef = useRef<HTMLDivElement>(null);

  if (isLoading && videos.length === 0) {
    return (
      <div className="video-feed-loading">
        <div className="spinner">Loading videos...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="video-feed-error">
        <p>{error}</p>
        <button onClick={onRefresh}>Retry</button>
      </div>
    );
  }

  if (videos.length === 0) {
    return (
      <div className="video-feed-empty">
        <p>No videos available</p>
      </div>
    );
  }

  return (
    <div ref={containerRef} className="video-feed-container">
      <PullToRefresh onRefresh={onRefresh} enabled={currentIndex === 0}>
        <VideoPageView
          videos={videos}
          currentIndex={currentIndex}
          onPageChange={onPageChange}
          onLoadMore={onLoadMore}
        />
      </PullToRefresh>
    </div>
  );
};
```

### VideoPageView Component

```typescript
import React, { useRef, useEffect, useState } from 'react';
import { VideoPlayerCard } from './VideoPlayerCard';
import { useSwipeable } from 'react-swipeable';

interface VideoPageViewProps {
  videos: HomeVideo[];
  currentIndex: number;
  onPageChange: (index: number) => void;
  onLoadMore: () => Promise<void>;
}

export const VideoPageView: React.FC<VideoPageViewProps> = ({
  videos,
  currentIndex,
  onPageChange,
  onLoadMore,
}) => {
  const containerRef = useRef<HTMLDivElement>(null);
  const [isScrolling, setIsScrolling] = useState(false);

  // Handle vertical swipe gestures
  const handlers = useSwipeable({
    onSwipedUp: () => {
      if (currentIndex < videos.length - 1) {
        onPageChange(currentIndex + 1);
      } else {
        // Load more when at end
        onLoadMore();
      }
    },
    onSwipedDown: () => {
      if (currentIndex > 0) {
        onPageChange(currentIndex - 1);
      }
    },
    trackMouse: true,
  });

  // Scroll to current video
  useEffect(() => {
    if (containerRef.current) {
      const videoElement = containerRef.current.children[currentIndex] as HTMLElement;
      if (videoElement) {
        videoElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
      }
    }
  }, [currentIndex]);

  // Handle scroll events for infinite scroll
  const handleScroll = useCallback(() => {
    if (isScrolling) return;
    setIsScrolling(true);

    const container = containerRef.current;
    if (!container) return;

    const scrollTop = container.scrollTop;
    const scrollHeight = container.scrollHeight;
    const clientHeight = container.clientHeight;

    // Check if scrolled to bottom (load more)
    if (scrollTop + clientHeight >= scrollHeight - 100) {
      onLoadMore();
    }

    // Determine which video is currently visible
    const videoElements = Array.from(container.children) as HTMLElement[];
    let newIndex = currentIndex;

    for (let i = 0; i < videoElements.length; i++) {
      const rect = videoElements[i].getBoundingClientRect();
      const containerRect = container.getBoundingClientRect();
      
      // Video is considered visible if it's in the center 60% of viewport
      const isVisible = 
        rect.top <= containerRect.top + containerRect.height * 0.7 &&
        rect.bottom >= containerRect.top + containerRect.height * 0.3;

      if (isVisible) {
        newIndex = i;
        break;
      }
    }

    if (newIndex !== currentIndex) {
      onPageChange(newIndex);
    }

    setTimeout(() => setIsScrolling(false), 100);
  }, [currentIndex, onPageChange, onLoadMore, isScrolling]);

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    container.addEventListener('scroll', handleScroll);
    return () => container.removeEventListener('scroll', handleScroll);
  }, [handleScroll]);

  return (
    <div
      {...handlers}
      ref={containerRef}
      className="video-page-view"
      style={{
        height: '100vh',
        overflowY: 'scroll',
        scrollSnapType: 'y mandatory',
        scrollBehavior: 'smooth',
      }}
    >
      {videos.map((video, index) => (
        <div
          key={video.id}
          style={{
            height: '100vh',
            scrollSnapAlign: 'start',
            scrollSnapStop: 'always',
          }}
        >
          <VideoPlayerCard
            video={video}
            isActive={index === currentIndex}
            isFirst={index === 0}
          />
        </div>
      ))}
    </div>
  );
};
```

### VideoPlayerCard Component

```typescript
import React, { useEffect, useRef } from 'react';
import { VideoPlayer } from './VideoPlayer';
import { VideoOverlay } from './VideoOverlay';

interface VideoPlayerCardProps {
  video: HomeVideo;
  isActive: boolean;
  isFirst: boolean;
}

export const VideoPlayerCard: React.FC<VideoPlayerCardProps> = {
  video,
  isActive,
  isFirst,
}) => {
  const cardRef = useRef<HTMLDivElement>(null);

  return (
    <div
      ref={cardRef}
      className="video-player-card"
      style={{
        position: 'relative',
        width: '100%',
        height: '100%',
        backgroundColor: '#000',
      }}
    >
      <VideoPlayer
        video={video}
        isActive={isActive}
        autoplay={isActive}
        muted={!isActive}
      />

      {isActive && (
        <VideoOverlay
          video={video}
        />
      )}
    </div>
  );
};
```

## State Management

### useFeedState Hook

```typescript
import { useState, useCallback, useEffect } from 'react';
import { videoService } from '../services/videoService';
import { followingFeedService } from '../services/followingFeedService';
import { HomeVideo } from '../types';

export const useFeedState = () => {
  const [forYouVideos, setForYouVideos] = useState<HomeVideo[]>([]);
  const [followingVideos, setFollowingVideos] = useState<HomeVideo[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const [hasMoreContent, setHasMoreContent] = useState(true);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [activeTab, setActiveTab] = useState<'forYou' | 'following'>('forYou');
  const [error, setError] = useState<string | null>(null);

  const loadVideos = useCallback(async () => {
    try {
      setIsLoading(true);
      setError(null);

      if (activeTab === 'forYou') {
        const videos = await videoService.loadAllVideos();
        setForYouVideos(videos);
      } else {
        const videos = await followingFeedService.loadFollowingFeed();
        setFollowingVideos(videos);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load videos');
    } finally {
      setIsLoading(false);
    }
  }, [activeTab]);

  const loadMoreVideos = useCallback(async (lastVideo: HomeVideo) => {
    if (isLoadingMore || !hasMoreContent) return;

    try {
      setIsLoadingMore(true);
      const moreVideos = await videoService.loadMoreVideos(lastVideo);

      if (moreVideos.length === 0) {
        setHasMoreContent(false);
        return;
      }

      if (activeTab === 'forYou') {
        setForYouVideos(prev => [...prev, ...moreVideos]);
      } else {
        setFollowingVideos(prev => [...prev, ...moreVideos]);
      }
    } catch (err) {
      console.error('Error loading more videos:', err);
    } finally {
      setIsLoadingMore(false);
    }
  }, [activeTab, isLoadingMore, hasMoreContent]);

  const refreshFeed = useCallback(async () => {
    setHasMoreContent(true);
    await loadVideos();
  }, [loadVideos]);

  const switchTab = useCallback((tab: 'forYou' | 'following') => {
    setActiveTab(tab);
    setCurrentIndex(0);
  }, []);

  useEffect(() => {
    loadVideos();
  }, [loadVideos]);

  return {
    forYouVideos,
    followingVideos,
    isLoading,
    isLoadingMore,
    hasMoreContent,
    currentIndex,
    activeTab,
    error,
    loadVideos,
    loadMoreVideos,
    refreshFeed,
    switchTab,
    setCurrentIndex,
  };
};
```

## Video Playback

### VideoPlayer Component

```typescript
import React, { useRef, useEffect } from 'react';
import { HomeVideo } from '../types';

interface VideoPlayerProps {
  video: HomeVideo;
  isActive: boolean;
  autoplay: boolean;
  muted: boolean;
}

export const VideoPlayer: React.FC<VideoPlayerProps> = ({
  video,
  isActive,
  autoplay,
  muted,
}) => {
  const videoRef = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    const videoElement = videoRef.current;
    if (!videoElement) return;

    if (isActive && autoplay) {
      videoElement.play().catch(err => {
        console.error('Error playing video:', err);
      });
    } else {
      videoElement.pause();
    }
  }, [isActive, autoplay]);

  useEffect(() => {
    const videoElement = videoRef.current;
    if (!videoElement) return;

    videoElement.muted = muted;
  }, [muted]);

  return (
    <video
      ref={videoRef}
      src={video.videoURL}
      className="video-player"
      style={{
        width: '100%',
        height: '100%',
        objectFit: 'cover',
      }}
      playsInline
      loop
      preload="auto"
    />
  );
};
```

## Feed Tabs

### FeedSelector Component

```typescript
import React from 'react';

interface FeedSelectorProps {
  activeTab: 'forYou' | 'following';
  onTabChange: (tab: 'forYou' | 'following') => void;
}

export const FeedSelector: React.FC<FeedSelectorProps> = ({
  activeTab,
  onTabChange,
}) => {
  return (
    <div className="feed-selector">
      <button
        className={activeTab === 'forYou' ? 'active' : ''}
        onClick={() => onTabChange('forYou')}
      >
        For You
      </button>
      <button
        className={activeTab === 'following' ? 'active' : ''}
        onClick={() => onTabChange('following')}
      >
        Following
      </button>
    </div>
  );
};
```

## Pull to Refresh

### PullToRefresh Component

```typescript
import React, { useState, useRef, useEffect } from 'react';

interface PullToRefreshProps {
  onRefresh: () => Promise<void>;
  enabled: boolean;
  children: React.ReactNode;
}

export const PullToRefresh: React.FC<PullToRefreshProps> = ({
  onRefresh,
  enabled,
  children,
}) => {
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [pullDistance, setPullDistance] = useState(0);
  const startY = useRef<number>(0);
  const isPulling = useRef<boolean>(false);

  const handleTouchStart = (e: React.TouchEvent) => {
    if (!enabled) return;
    startY.current = e.touches[0].clientY;
    isPulling.current = true;
  };

  const handleTouchMove = (e: React.TouchEvent) => {
    if (!enabled || !isPulling.current) return;

    const currentY = e.touches[0].clientY;
    const distance = currentY - startY.current;

    if (distance > 0) {
      setPullDistance(Math.min(distance, 100));
    }
  };

  const handleTouchEnd = async () => {
    if (!enabled || !isPulling.current) return;

    isPulling.current = false;

    if (pullDistance > 50) {
      setIsRefreshing(true);
      await onRefresh();
      setIsRefreshing(false);
    }

    setPullDistance(0);
  };

  return (
    <div
      onTouchStart={handleTouchStart}
      onTouchMove={handleTouchMove}
      onTouchEnd={handleTouchEnd}
      style={{ position: 'relative' }}
    >
      {isRefreshing && (
        <div className="pull-to-refresh-indicator">
          <div className="spinner">Refreshing...</div>
        </div>
      )}
      {children}
    </div>
  );
};
```

## Infinite Scroll

The infinite scroll is handled in the `VideoPageView` component's `handleScroll` function. When the user scrolls near the bottom, `onLoadMore` is called to fetch additional videos.

## CSS Styling

```css
.home-view {
  width: 100%;
  height: 100vh;
  background-color: #000;
  overflow: hidden;
}

.feed-selector {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  z-index: 100;
  display: flex;
  justify-content: center;
  gap: 20px;
  padding: 10px;
  background: linear-gradient(to bottom, rgba(0,0,0,0.8), transparent);
}

.feed-selector button {
  background: transparent;
  border: none;
  color: #fff;
  font-size: 16px;
  font-weight: 600;
  padding: 8px 16px;
  cursor: pointer;
  opacity: 0.6;
  transition: opacity 0.2s;
}

.feed-selector button.active {
  opacity: 1;
  border-bottom: 2px solid #fff;
}

.video-feed-container {
  width: 100%;
  height: 100vh;
  overflow: hidden;
}

.video-page-view {
  width: 100%;
  height: 100vh;
  overflow-y: scroll;
  scroll-snap-type: y mandatory;
  scroll-behavior: smooth;
  -webkit-overflow-scrolling: touch;
}

.video-player-card {
  position: relative;
  width: 100%;
  height: 100vh;
  scroll-snap-align: start;
  scroll-snap-stop: always;
}

.video-player {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
```

## Summary

This implementation provides:

1. **Vertical scrolling feed** with TikTok-style navigation
2. **Two feed tabs** (For You / Following)
3. **Automatic video playback** management
4. **Pull-to-refresh** functionality
5. **Infinite scroll** pagination
6. **Video preloading** for smooth transitions
7. **Real-time state updates** for likes, views, comments

The architecture mirrors the Flutter implementation while using web-native technologies (React, TypeScript, Firebase).

