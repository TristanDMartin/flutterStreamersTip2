# Feed System Documentation - For You & Following Tabs

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Data Structures](#data-structures)
4. [Service Layer](#service-layer)
5. [State Management](#state-management)
6. [Component Structure](#component-structure)
7. [Event Logging](#event-logging)
8. [Firestore Queries & Indexes](#firestore-queries--indexes)
9. [Performance Optimizations](#performance-optimizations)
10. [Integration Guide](#integration-guide)
11. [API Reference](#api-reference)

---

## Overview

The feed system provides two main tabs:
- **For You**: Shows all published videos sorted by creation date (newest first)
- **Following**: Shows videos from users the current user follows

### Key Features
- TikTok-style vertical scrolling video feed
- Autoplay with mute/unmute controls
- Pull-to-refresh
- Infinite scroll pagination
- Real-time video stats (likes, comments, views, shares, bookmarks)
- Event tracking for analytics
- Optimized batch loading for performance

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      HomeView Component                      │
│  (Main orchestrator - handles tab switching, navigation)    │
└───────────────────┬───────────────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
┌───────▼────────┐    ┌─────────▼──────────┐
│  FeedSelector  │    │ VideoDetailOverlay │
│  (Tab buttons) │    │  (Video player)    │
└────────────────┘    └─────────┬──────────┘
                                │
                    ┌───────────┴───────────┐
                    │                       │
            ┌───────▼──────┐      ┌─────────▼────────┐
            │ useFeedState │      │  VideoHUD        │
            │   (Hook)     │      │  (UI controls)  │
            └───────┬──────┘      └──────────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
┌───────▼────────┐    ┌─────────▼──────────┐
│ homeFeedService│    │followingFeedService│
│  (For You)     │    │   (Following)      │
└────────────────┘    └────────────────────┘
```

---

## Data Structures

### HomeVideo Interface

```typescript
interface HomeVideo {
  id: string                    // Video document ID
  creator: User                 // Creator information
  videoUrl: string              // Primary playback URL
  originalVideoUrl?: string     // Original video URL (for instant playback)
  thumbnailUrl: string          // Thumbnail image URL
  thumbnails?: VideoThumbnails  // Multiple thumbnail sizes
  likes: number                 // Like count
  comments: number              // Comment count
  views: number                 // View count
  shares: number                // Share count
  bookmarks?: number            // Bookmark count
  caption: string               // Video caption/description
  isLiked: boolean              // Current user liked this video
  isFavorited: boolean          // Current user favorited this video
  isDraft: boolean              // Is draft video
  mlScore: number               // Machine learning score (for ranking)
  categoryId: string            // Category ID
  category?: string              // Category name
  duration?: number             // Video duration in seconds
  createdAt?: Timestamp | Date  // Creation timestamp
  allowSave: boolean            // Can user save this video
  allowRemix: boolean           // Can user remix this video
  visibility: 'public' | 'followers' | 'private'
  status: 'draft' | 'processing' | 'published' | 'blocked' | 'deleted'
  isPinned: boolean             // Is pinned video
  tags: string[]                // Video tags
  playlistIds: string[]          // Playlist IDs
  trendingScore?: number        // Trending score
  isTrending?: boolean          // Is trending video
  isNew?: boolean               // Is new video
}
```

### User Interface

```typescript
interface User {
  id: string                    // User ID
  displayName: string           // Display name
  username: string              // Username (for @mentions)
  avatarURL?: string            // Avatar image URL
  bio?: string                  // User bio
  hashtags?: string[]           // User hashtags
}
```

### FeedState Interface

```typescript
interface FeedState {
  forYouVideos: HomeVideo[]     // For You feed videos
  followingVideos: HomeVideo[]  // Following feed videos
  isLoading: boolean            // Initial load state
  isLoadingMore: boolean        // Pagination load state
  hasMoreContent: boolean       // More content available
  currentIndex: number          // Current video index
  activeTab: 'forYou' | 'following'
  error: string | null          // Error message
}
```

---

## Service Layer

### HomeFeedService (For You Tab)

**Location**: `services/homeFeedService.ts`

**Purpose**: Fetches all published videos sorted by creation date

**Key Methods**:

#### `loadAllVideos(): Promise<HomeVideo[]>`
- Fetches initial batch of videos (20 videos)
- Filters by `status === 'published'`
- Orders by `createdAt` descending
- Batches creator info fetching for performance
- Returns array of `HomeVideo` objects

**Query Structure**:
```typescript
query(
  collection(db, 'videos'),
  where('status', '==', 'published'),
  orderBy('createdAt', 'desc'),
  limit(20)
)
```

**Fallback Query** (if index missing):
```typescript
query(
  collection(db, 'videos'),
  orderBy('createdAt', 'desc'),
  limit(40) // Fetch more to filter in memory
)
// Then filter: data.status === 'published'
```

#### `loadMoreVideos(lastVideo: HomeVideo): Promise<HomeVideo[]>`
- Pagination: fetches next batch after `lastVideo`
- Uses `startAfter()` for cursor-based pagination
- Returns next 20 videos

**Query Structure**:
```typescript
const lastDoc = await getDoc(doc(db, 'videos', lastVideo.id))
query(
  collection(db, 'videos'),
  where('status', '==', 'published'),
  orderBy('createdAt', 'desc'),
  startAfter(lastDoc),
  limit(20)
)
```

#### `getCreatorInfo(userId: string): Promise<User>`
- Fetches user profile from `users` collection
- 2-second timeout to prevent blocking
- Returns `User` object with fallback values

**Performance Optimization**:
- Batches all creator lookups using `Promise.all()`
- Collects unique creator IDs first, then fetches all in parallel

**Implementation**:
```typescript
import { collection, query, where, orderBy, limit, getDocs, startAfter, getDoc, doc } from 'firebase/firestore';
import { db } from './firebase';

class HomeFeedService {
  private videos: HomeVideo[] = [];
  private lastFetchTime: number = 0;
  private readonly CACHE_DURATION = 5 * 60 * 1000; // 5 minutes

  async loadAllVideos(): Promise<HomeVideo[]> {
    try {
      // Check cache
      const now = Date.now();
      if (this.videos.length > 0 && (now - this.lastFetchTime) < this.CACHE_DURATION) {
        return this.videos;
      }

      // Query published videos
      let snapshot;
      try {
        const videosQuery = query(
          collection(db, 'videos'),
          where('status', '==', 'published'),
          orderBy('createdAt', 'desc'),
          limit(20)
        );
        snapshot = await getDocs(videosQuery);
      } catch (error: any) {
        // Fallback if index missing
        if (error.code === 'failed-precondition' || error.message?.includes('index')) {
          const fallbackQuery = query(
            collection(db, 'videos'),
            orderBy('createdAt', 'desc'),
            limit(40)
          );
          snapshot = await getDocs(fallbackQuery);
        } else {
          throw error;
        }
      }

      const videos: HomeVideo[] = [];
      const creatorIds = new Set<string>();

      // First pass: collect video data and creator IDs
      for (const docSnapshot of snapshot.docs) {
        const data = docSnapshot.data();
        
        // Filter by status if using fallback query
        if (data.status !== 'published') continue;

        const creatorId = data.creatorId || data.userId;
        if (creatorId) creatorIds.add(creatorId);

        const video: HomeVideo = {
          id: docSnapshot.id,
          videoUrl: data.playbackUrl || data.originalVideoUrl || data.videoUrl,
          originalVideoUrl: data.originalVideoUrl || data.videoUrl,
          thumbnailUrl: data.thumb || data.thumbnailUrl,
          likes: data.likes || 0,
          comments: data.comments || 0,
          views: data.views || 0,
          shares: data.shares || 0,
          bookmarks: data.bookmarks || 0,
          caption: data.caption || '',
          isLiked: false,
          isFavorited: false,
          isDraft: false,
          mlScore: data.mlScore || 0,
          categoryId: data.categoryId || 'general',
          category: data.category,
          duration: data.metadata?.duration || data.duration,
          createdAt: data.createdAt?.toDate() || new Date(),
          allowSave: data.allowSave !== false,
          allowRemix: data.allowRemix !== false,
          visibility: data.visibility || data.privacy || 'public',
          status: data.status || 'published',
          isPinned: data.isPinned || false,
          tags: data.tags || [],
          playlistIds: data.playlistIds || [],
          trendingScore: data.trendingScore,
          isTrending: data.isTrending || false,
          isNew: data.isNew || false,
          creator: {
            id: creatorId,
            displayName: 'Loading...',
            username: 'loading',
          },
        };

        videos.push(video);
      }

      // Second pass: batch fetch creator info
      const creatorPromises = Array.from(creatorIds).map(id => this.getCreatorInfo(id));
      const creators = await Promise.all(creatorPromises);
      const creatorMap = new Map(creators.map(c => [c.id, c]));

      // Third pass: attach creator info
      videos.forEach(video => {
        const creator = creatorMap.get(video.creator.id);
        if (creator) {
          video.creator = creator;
        }
      });

      // Sort by createdAt (newest first)
      videos.sort((a, b) => {
        const aTime = a.createdAt?.getTime() || 0;
        const bTime = b.createdAt?.getTime() || 0;
        return bTime - aTime;
      });

      this.videos = videos;
      this.lastFetchTime = now;

      return videos;
    } catch (error) {
      console.error('Error loading videos:', error);
      return [];
    }
  }

  async loadMoreVideos(lastVideo: HomeVideo): Promise<HomeVideo[]> {
    try {
      const lastDoc = await getDoc(doc(db, 'videos', lastVideo.id));
      if (!lastDoc.exists()) return [];

      const videosQuery = query(
        collection(db, 'videos'),
        where('status', '==', 'published'),
        orderBy('createdAt', 'desc'),
        startAfter(lastDoc),
        limit(20)
      );

      const snapshot = await getDocs(videosQuery);
      
      // Same processing as loadAllVideos
      const videos: HomeVideo[] = [];
      const creatorIds = new Set<string>();

      for (const docSnapshot of snapshot.docs) {
        const data = docSnapshot.data();
        const creatorId = data.creatorId || data.userId;
        if (creatorId) creatorIds.add(creatorId);

        const video: HomeVideo = {
          id: docSnapshot.id,
          videoUrl: data.playbackUrl || data.originalVideoUrl || data.videoUrl,
          originalVideoUrl: data.originalVideoUrl || data.videoUrl,
          thumbnailUrl: data.thumb || data.thumbnailUrl,
          likes: data.likes || 0,
          comments: data.comments || 0,
          views: data.views || 0,
          shares: data.shares || 0,
          bookmarks: data.bookmarks || 0,
          caption: data.caption || '',
          isLiked: false,
          isFavorited: false,
          isDraft: false,
          mlScore: data.mlScore || 0,
          categoryId: data.categoryId || 'general',
          category: data.category,
          duration: data.metadata?.duration || data.duration,
          createdAt: data.createdAt?.toDate() || new Date(),
          allowSave: data.allowSave !== false,
          allowRemix: data.allowRemix !== false,
          visibility: data.visibility || data.privacy || 'public',
          status: data.status || 'published',
          isPinned: data.isPinned || false,
          tags: data.tags || [],
          playlistIds: data.playlistIds || [],
          trendingScore: data.trendingScore,
          isTrending: data.isTrending || false,
          isNew: data.isNew || false,
          creator: {
            id: creatorId,
            displayName: 'Loading...',
            username: 'loading',
          },
        };

        videos.push(video);
      }

      // Batch fetch creator info
      const creatorPromises = Array.from(creatorIds).map(id => this.getCreatorInfo(id));
      const creators = await Promise.all(creatorPromises);
      const creatorMap = new Map(creators.map(c => [c.id, c]));

      videos.forEach(video => {
        const creator = creatorMap.get(video.creator.id);
        if (creator) {
          video.creator = creator;
        }
      });

      return videos;
    } catch (error) {
      console.error('Error loading more videos:', error);
      return [];
    }
  }

  async getCreatorInfo(userId: string): Promise<User> {
    try {
      const timeoutPromise = new Promise<User>(resolve => 
        setTimeout(() => resolve({
          id: userId,
          displayName: 'Unknown User',
          username: 'unknown',
        }), 2000)
      );

      const userDoc = await Promise.race([
        getDoc(doc(db, 'users', userId)),
        timeoutPromise,
      ]) as any;

      if (!userDoc || !userDoc.exists()) {
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
    } catch (error) {
      console.error(`Error fetching creator info for ${userId}:`, error);
      return {
        id: userId,
        displayName: 'Unknown User',
        username: 'unknown',
      };
    }
  }

  async refresh(): Promise<HomeVideo[]> {
    this.videos = [];
    this.lastFetchTime = 0;
    return this.loadAllVideos();
  }
}

export const homeFeedService = new HomeFeedService();
```

---

### FollowingFeedService (Following Tab)

**Location**: `services/followingFeedService.ts`

**Purpose**: Fetches videos from users the current user follows

**Key Methods**:

#### `getFollowingIds(userId: string): Promise<string[]>`
- Queries `follows` collection for users the current user follows
- Returns array of user IDs

**Query Structure**:
```typescript
query(
  collection(db, 'follows'),
  where('followerUserId', '==', userId),
  where('isActive', '==', true)
)
// Maps to: data.targetUserId || data.followingId || data.followedId
```

#### `loadFollowingFeed(limitCount: number, lastVideo?: HomeVideo): Promise<HomeVideo[]>`
- Fetches videos from followed users
- Batches queries (Firestore `in` query limit is 10)
- Supports pagination with `lastVideo`
- Returns array of `HomeVideo` objects

**Query Structure** (batched):
```typescript
// For each batch of 10 user IDs:
query(
  collection(db, 'videos'),
  where('creatorId', 'in', batch), // or 'userId' as fallback
  where('status', '==', 'published'),
  orderBy('createdAt', 'desc'),
  startAfter(lastDoc), // if paginating
  limit(limitCount * 2)
)
```

**Performance Optimization**:
- Batches creator info fetching (same as For You feed)
- Deduplicates videos across batches
- Sorts all videos by `createdAt` after fetching

**Implementation**:
```typescript
import { collection, query, where, orderBy, limit, getDocs, startAfter, getDoc, doc } from 'firebase/firestore';
import { db } from './firebase';
import { auth } from './firebase';
import { homeFeedService } from './homeFeedService';

class FollowingFeedService {
  async getFollowingIds(userId: string): Promise<string[]> {
    try {
      const followsQuery = query(
        collection(db, 'follows'),
        where('followerUserId', '==', userId),
        where('isActive', '==', true)
      );

      const snapshot = await getDocs(followsQuery);
      const followingIds: string[] = [];

      for (const docSnapshot of snapshot.docs) {
        const data = docSnapshot.data();
        const targetUserId = data.targetUserId || data.followingId || data.followedId;
        if (targetUserId) {
          followingIds.push(targetUserId);
        }
      }

      return followingIds;
    } catch (error) {
      console.error('Error getting following IDs:', error);
      return [];
    }
  }

  async loadFollowingFeed(limitCount: number = 20, lastVideo?: HomeVideo): Promise<HomeVideo[]> {
    try {
      const currentUser = auth.currentUser;
      if (!currentUser) return [];

      // Get following IDs
      const followingIds = await this.getFollowingIds(currentUser.uid);
      if (followingIds.length === 0) return [];

      // Batch queries (Firestore 'in' limit is 10)
      const allVideos: HomeVideo[] = [];
      const lastDoc = lastVideo ? await getDoc(doc(db, 'videos', lastVideo.id)) : null;

      for (let i = 0; i < followingIds.length; i += 10) {
        const batch = followingIds.slice(i, i + 10);
        
        let videosQuery = query(
          collection(db, 'videos'),
          where('creatorId', 'in', batch),
          where('status', '==', 'published'),
          orderBy('createdAt', 'desc'),
          limit(limitCount * 2)
        );

        // Add pagination if provided
        if (lastDoc) {
          videosQuery = query(videosQuery, startAfter(lastDoc));
        }

        try {
          const snapshot = await getDocs(videosQuery);
          
          for (const docSnapshot of snapshot.docs) {
            const data = docSnapshot.data();
            const creatorId = data.creatorId || data.userId;
            
            const video: HomeVideo = {
              id: docSnapshot.id,
              videoUrl: data.playbackUrl || data.originalVideoUrl || data.videoUrl,
              originalVideoUrl: data.originalVideoUrl || data.videoUrl,
              thumbnailUrl: data.thumb || data.thumbnailUrl,
              likes: data.likes || 0,
              comments: data.comments || 0,
              views: data.views || 0,
              shares: data.shares || 0,
              bookmarks: data.bookmarks || 0,
              caption: data.caption || '',
              isLiked: false,
              isFavorited: false,
              isDraft: false,
              mlScore: data.mlScore || 0,
              categoryId: data.categoryId || 'general',
              category: data.category,
              duration: data.metadata?.duration || data.duration,
              createdAt: data.createdAt?.toDate() || new Date(),
              allowSave: data.allowSave !== false,
              allowRemix: data.allowRemix !== false,
              visibility: data.visibility || data.privacy || 'public',
              status: data.status || 'published',
              isPinned: data.isPinned || false,
              tags: data.tags || [],
              playlistIds: data.playlistIds || [],
              trendingScore: data.trendingScore,
              isTrending: data.isTrending || false,
              isNew: data.isNew || false,
              creator: {
                id: creatorId,
                displayName: 'Loading...',
                username: 'loading',
              },
            };

            allVideos.push(video);
          }
        } catch (error: any) {
          // Try fallback with userId field
          if (error.code === 'failed-precondition' || error.message?.includes('index')) {
            const fallbackQuery = query(
              collection(db, 'videos'),
              where('userId', 'in', batch),
              where('status', '==', 'published'),
              orderBy('createdAt', 'desc'),
              limit(limitCount * 2)
            );
            const snapshot = await getDocs(fallbackQuery);
            // Process same as above
          }
        }
      }

      // Deduplicate videos
      const uniqueVideos = Array.from(
        new Map(allVideos.map(v => [v.id, v])).values()
      );

      // Batch fetch creator info
      const creatorIds = new Set(uniqueVideos.map(v => v.creator.id));
      const creatorPromises = Array.from(creatorIds).map(id => 
        homeFeedService.getCreatorInfo(id)
      );
      const creators = await Promise.all(creatorPromises);
      const creatorMap = new Map(creators.map(c => [c.id, c]));

      uniqueVideos.forEach(video => {
        const creator = creatorMap.get(video.creator.id);
        if (creator) {
          video.creator = creator;
        }
      });

      // Sort by createdAt (newest first)
      uniqueVideos.sort((a, b) => {
        const aTime = a.createdAt?.getTime() || 0;
        const bTime = b.createdAt?.getTime() || 0;
        return bTime - aTime;
      });

      return uniqueVideos.slice(0, limitCount);
    } catch (error) {
      console.error('Error loading following feed:', error);
      return [];
    }
  }
}

export const followingFeedService = new FollowingFeedService();
```

---

## State Management

### useFeedState Hook

**Location**: `hooks/useFeedState.ts`

**Purpose**: Manages feed state and loading logic

**State Variables**:
- `forYouVideos`: Array of For You videos
- `followingVideos`: Array of Following videos
- `isLoading`: Initial load state
- `isLoadingMore`: Pagination load state
- `hasMoreContent`: More content available flag
- `currentIndex`: Current video index
- `activeTab`: Active tab ('forYou' | 'following')
- `error`: Error message

**Methods**:
- `loadVideos()`: Loads initial videos for active tab
- `loadMoreVideos(lastVideo)`: Loads next batch for pagination
- `refreshFeed()`: Refreshes current feed
- `switchTab(tab)`: Switches between For You and Following tabs

**Implementation**:
```typescript
import { useState, useCallback, useEffect } from 'react';
import { homeFeedService } from '../services/homeFeedService';
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
        const videos = await homeFeedService.loadAllVideos();
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
      let moreVideos: HomeVideo[];

      if (activeTab === 'forYou') {
        moreVideos = await homeFeedService.loadMoreVideos(lastVideo);
      } else {
        moreVideos = await followingFeedService.loadFollowingFeed(20, lastVideo);
      }

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
    // Defer initial load
    const timer = setTimeout(() => {
      loadVideos();
    }, 0);
    return () => clearTimeout(timer);
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

**Usage**:
```typescript
const {
  forYouVideos,
  followingVideos,
  isLoading,
  activeTab,
  loadVideos,
  loadMoreVideos,
  switchTab,
  setCurrentIndex
} = useFeedState()
```

---

## Component Structure

### HomeView Component

**Location**: `components/feed/HomeView.tsx`

**Purpose**: Main feed component orchestrating all feed functionality

**Key Features**:
- Tab switching (For You / Following)
- Video navigation (up/down arrows)
- Event logging integration
- Action handlers (like, bookmark, follow, share, comment)

**Props**: None (self-contained)

**State**:
- `currentVideoIndex`: Current video being viewed
- `hasLikedMap`: Map of video IDs to like state
- `isBookmarkedMap`: Map of video IDs to bookmark state

**Key Handlers**:
- `handleTabChange(tab)`: Switches tabs
- `handleLike(videoId, isLiked)`: Toggles like
- `handleBookmark(videoId, isBookmarked)`: Toggles bookmark
- `handleFollow(userId, isFollowing)`: Toggles follow
- `handleShare(video)`: Opens share sheet
- `handleComment(videoId)`: Opens comments
- `handleNavigateUp()`: Navigate to previous video
- `handleNavigateDown()`: Navigate to next video

**Video Transformation**:
Transforms `HomeVideo[]` to `VideoDetailVideo[]` format for `VideoDetailOverlay`:
```typescript
{
  id: video.id,
  src: video.originalVideoUrl || video.videoUrl,
  cover: video.thumbnailUrl,
  user: {
    id: video.creator.id,
    username: video.creator.username,
    displayName: video.creator.displayName,
    avatarUrl: video.creator.avatarURL
  },
  stats: {
    views: video.views,
    likes: video.likes,
    comments: video.comments,
    shares: video.shares,
    bookmarks: video.bookmarks
  },
  caption: video.caption,
  // ... other fields
}
```

**Implementation**:
```typescript
import React, { useState, useEffect, useCallback } from 'react';
import { useFeedState } from '../hooks/useFeedState';
import { FeedSelector } from './FeedSelector';
import { VideoDetailOverlay } from '../video_detail_overlay/VideoDetailOverlay';
import { feedEventLogger } from '../services/feedEventLogger';
import { HomeVideo } from '../types';

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

  const [hasLikedMap, setHasLikedMap] = useState<Map<string, boolean>>(new Map());
  const [isBookmarkedMap, setIsBookmarkedMap] = useState<Map<string, boolean>>(new Map());
  const [isOverlayOpen, setIsOverlayOpen] = useState(false);

  const videos = activeTab === 'forYou' ? forYouVideos : followingVideos;

  useEffect(() => {
    loadVideos();
  }, [loadVideos]);

  const handleTabChange = useCallback((tab: 'forYou' | 'following') => {
    switchTab(tab);
    setCurrentIndex(0);
  }, [switchTab, setCurrentIndex]);

  const handleVideoChange = useCallback((index: number, video: HomeVideo) => {
    setCurrentIndex(index);
    
    // Track impression
    feedEventLogger.trackImpression(
      video.id,
      video.creator.id,
      activeTab,
      index
    );

    // Track view start
    feedEventLogger.trackViewStart(video.id, video.creator.id, activeTab);
  }, [activeTab, setCurrentIndex]);

  const handleLike = useCallback(async (videoId: string, isLiked: boolean) => {
    const video = videos.find(v => v.id === videoId);
    if (!video) return;

    setHasLikedMap(prev => new Map(prev).set(videoId, isLiked));
    
    // Track event
    feedEventLogger.trackLike(videoId, video.creator.id, isLiked, activeTab);
    
    // Update video like count
    // ... API call to update like
  }, [videos, activeTab]);

  const handleBookmark = useCallback(async (videoId: string, isBookmarked: boolean) => {
    const video = videos.find(v => v.id === videoId);
    if (!video) return;

    setIsBookmarkedMap(prev => new Map(prev).set(videoId, isBookmarked));
    
    // Track event
    feedEventLogger.trackSave(videoId, video.creator.id, isBookmarked, activeTab);
    
    // Update video bookmark count
    // ... API call to update bookmark
  }, [videos, activeTab]);

  const handleFollow = useCallback(async (userId: string, isFollowing: boolean) => {
    const video = videos[currentIndex];
    if (!video) return;

    // Track event
    feedEventLogger.trackFollowFromVideo(
      video.id,
      video.creator.id,
      isFollowing,
      activeTab
    );
    
    // Update follow state
    // ... API call to update follow
  }, [videos, currentIndex, activeTab]);

  const handleShare = useCallback((video: HomeVideo) => {
    feedEventLogger.trackShare(video.id, video.creator.id, activeTab);
    // ... Open share sheet
  }, [activeTab]);

  const handleComment = useCallback((videoId: string) => {
    const video = videos.find(v => v.id === videoId);
    if (!video) return;

    feedEventLogger.trackComment(videoId, video.creator.id, activeTab);
    // ... Open comments
  }, [videos, activeTab]);

  // Transform videos for VideoDetailOverlay
  const transformedVideos = videos.map(video => ({
    id: video.id,
    src: video.originalVideoUrl || video.videoUrl,
    cover: video.thumbnailUrl,
    user: {
      id: video.creator.id,
      username: video.creator.username,
      displayName: video.creator.displayName,
      avatarUrl: video.creator.avatarURL,
    },
    stats: {
      views: video.views,
      likes: video.likes,
      comments: video.comments,
      shares: video.shares,
      bookmarks: video.bookmarks || 0,
    },
    caption: video.caption,
    isLiked: hasLikedMap.get(video.id) ?? video.isLiked,
    isBookmarked: isBookmarkedMap.get(video.id) ?? video.isFavorited,
  }));

  return (
    <div className="home-view">
      <FeedSelector
        activeTab={activeTab}
        onTabChange={handleTabChange}
      />

      {isLoading && videos.length === 0 ? (
        <div className="loading">Loading videos...</div>
      ) : error ? (
        <div className="error">{error}</div>
      ) : (
        <VideoDetailOverlay
          isOpen={!isLoading}
          videos={transformedVideos}
          initialIndex={currentIndex}
          fitToContainer={true}
          onVideoChange={handleVideoChange}
          onLike={handleLike}
          onBookmark={handleBookmark}
          onFollow={handleFollow}
          onShare={handleShare}
          onComment={handleComment}
        />
      )}
    </div>
  );
};
```

---

### FeedSelector Component

**Location**: `components/feed/FeedSelector.tsx`

**Purpose**: Tab selector UI (For You / Following buttons)

**Props**:
```typescript
interface FeedSelectorProps {
  activeTab: 'forYou' | 'following'
  onTabChange: (tab: 'forYou' | 'following') => void
}
```

**Styling**:
- Active tab: Gradient background with shadow
- Inactive tab: Glass morphism effect
- Hover states for both tabs
- Mobile responsive

**Implementation**:
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
        className={`feed-tab ${activeTab === 'forYou' ? 'active' : ''}`}
        onClick={() => onTabChange('forYou')}
      >
        For You
      </button>
      <button
        className={`feed-tab ${activeTab === 'following' ? 'active' : ''}`}
        onClick={() => onTabChange('following')}
      >
        Following
      </button>
    </div>
  );
};
```

---

### VideoDetailOverlay Component

**Location**: `components/video_detail_overlay/VideoDetailOverlay.tsx`

**Purpose**: Full-screen video player overlay

**Key Props**:
- `isOpen: boolean`: Overlay visibility
- `videos: Video[]`: Array of videos to display
- `initialIndex: number`: Starting video index
- `fitToContainer: boolean`: Use absolute positioning (for feed mode)
- `onVideoChange(index, video)`: Callback when video changes
- `onLike(videoId, isLiked)`: Like handler
- `onBookmark(videoId, isBookmarked)`: Bookmark handler
- `onFollow(userId, isFollowing)`: Follow handler
- `onShare(video)`: Share handler
- `onComment(videoId)`: Comment handler

**Features**:
- Vertical swipe navigation
- Autoplay with mute/unmute
- Volume slider on hover
- Video stats overlay
- Creator info display
- Action buttons (like, comment, share, bookmark)

---

## Event Logging

### FeedEventLogger Service

**Location**: `services/feedEventLogger.ts`

**Purpose**: Tracks user interactions and video playback events

**Events Tracked**:

1. **impression**: Video shown in feed
   ```typescript
   trackImpression(videoId, creatorId, feedType, videoIndex)
   ```

2. **view_start**: Video playback started
   ```typescript
   trackViewStart(videoId, creatorId, feedType)
   ```

3. **view_2s**: User watched at least 2 seconds
   ```typescript
   trackView2s(videoId, creatorId, feedType)
   ```

4. **view_complete**: User watched entire video or significant portion
   ```typescript
   trackViewComplete(videoId, creatorId, feedType, progressPercent)
   ```

5. **like**: Like/unlike action
   ```typescript
   trackLike(videoId, creatorId, isLiked, feedType)
   ```

6. **comment**: Comment action
   ```typescript
   trackComment(videoId, creatorId, feedType)
   ```

7. **share**: Share action
   ```typescript
   trackShare(videoId, creatorId, feedType)
   ```

8. **save**: Bookmark/save action
   ```typescript
   trackSave(videoId, creatorId, isSaved, feedType)
   ```

9. **follow_from_video**: Follow/unfollow from video
   ```typescript
   trackFollowFromVideo(videoId, creatorId, isFollowing, feedType)
   ```

10. **not_interested**: Not interested action
    ```typescript
    trackNotInterested(videoId, creatorId, feedType)
    ```

11. **report**: Report action
    ```typescript
    trackReport(videoId, creatorId, reason, feedType)
    ```

**Event Metadata**:
```typescript
{
  videoId: string
  creatorId: string
  feedType: 'forYou' | 'following'
  videoIndex?: number
  timestamp: number
  watchMs?: number        // For view events
  progressPercent?: number // For view_complete
  isLiked?: boolean       // For like events
  isSaved?: boolean       // For save events
  isFollowing?: boolean   // For follow events
  reason?: string         // For report events
}
```

**Implementation**:
```typescript
import { trackEvent } from './analytics';
import { event } from 'nextjs-google-analytics';

class FeedEventLogger {
  private viewTimers: Map<string, NodeJS.Timeout> = new Map();
  private viewStartTimes: Map<string, number> = new Map();

  async trackImpression(
    videoId: string,
    creatorId: string,
    feedType: 'forYou' | 'following',
    videoIndex?: number
  ) {
    const eventData = {
      eventType: 'impression',
      videoId,
      creatorId,
      feedType,
      videoIndex,
      timestamp: Date.now(),
    };

    await trackEvent(eventData);
    event('feed_impression', {
      video_id: videoId,
      creator_id: creatorId,
      feed_type: feedType,
      video_index: videoIndex?.toString(),
    });
  }

  async trackViewStart(
    videoId: string,
    creatorId: string,
    feedType: 'forYou' | 'following'
  ) {
    // Clean up previous video timer
    this.cleanup(videoId);

    const eventData = {
      eventType: 'view_start',
      videoId,
      creatorId,
      feedType,
      timestamp: Date.now(),
    };

    await trackEvent(eventData);
    event('feed_view_start', {
      video_id: videoId,
      creator_id: creatorId,
      feed_type: feedType,
    });

    // Set up 2-second timer
    this.viewStartTimes.set(videoId, Date.now());
    const timer2s = setTimeout(() => {
      this.trackView2s(videoId, creatorId, feedType);
    }, 2000);
    this.viewTimers.set(videoId, timer2s);
  }

  async trackView2s(
    videoId: string,
    creatorId: string,
    feedType: 'forYou' | 'following'
  ) {
    const eventData = {
      eventType: 'view_2s',
      videoId,
      creatorId,
      feedType,
      timestamp: Date.now(),
    };

    await trackEvent(eventData);
    event('feed_view_2s', {
      video_id: videoId,
      creator_id: creatorId,
      feed_type: feedType,
    });
  }

  async trackViewComplete(
    videoId: string,
    creatorId: string,
    feedType: 'forYou' | 'following',
    progressPercent?: number
  ) {
    const startTime = this.viewStartTimes.get(videoId) || Date.now();
    const watchMs = Date.now() - startTime;

    const eventData = {
      eventType: 'view_complete',
      videoId,
      creatorId,
      feedType,
      watchMs,
      progressPercent,
      timestamp: Date.now(),
    };

    await trackEvent(eventData);
    event('feed_view_complete', {
      video_id: videoId,
      creator_id: creatorId,
      feed_type: feedType,
      watch_ms: watchMs.toString(),
      progress_percent: progressPercent?.toString(),
    });

    this.cleanup(videoId);
  }

  async trackLike(
    videoId: string,
    creatorId: string,
    isLiked: boolean,
    feedType: 'forYou' | 'following'
  ) {
    const eventData = {
      eventType: 'like',
      videoId,
      creatorId,
      feedType,
      isLiked,
      timestamp: Date.now(),
    };

    await trackEvent(eventData);
    event('feed_like', {
      video_id: videoId,
      creator_id: creatorId,
      feed_type: feedType,
      is_liked: isLiked.toString(),
    });
  }

  async trackComment(
    videoId: string,
    creatorId: string,
    feedType: 'forYou' | 'following'
  ) {
    const eventData = {
      eventType: 'comment',
      videoId,
      creatorId,
      feedType,
      timestamp: Date.now(),
    };

    await trackEvent(eventData);
    event('feed_comment', {
      video_id: videoId,
      creator_id: creatorId,
      feed_type: feedType,
    });
  }

  async trackShare(
    videoId: string,
    creatorId: string,
    feedType: 'forYou' | 'following'
  ) {
    const eventData = {
      eventType: 'share',
      videoId,
      creatorId,
      feedType,
      timestamp: Date.now(),
    };

    await trackEvent(eventData);
    event('feed_share', {
      video_id: videoId,
      creator_id: creatorId,
      feed_type: feedType,
    });
  }

  async trackSave(
    videoId: string,
    creatorId: string,
    isSaved: boolean,
    feedType: 'forYou' | 'following'
  ) {
    const eventData = {
      eventType: 'save',
      videoId,
      creatorId,
      feedType,
      isSaved,
      timestamp: Date.now(),
    };

    await trackEvent(eventData);
    event('feed_save', {
      video_id: videoId,
      creator_id: creatorId,
      feed_type: feedType,
      is_saved: isSaved.toString(),
    });
  }

  async trackFollowFromVideo(
    videoId: string,
    creatorId: string,
    isFollowing: boolean,
    feedType: 'forYou' | 'following'
  ) {
    const eventData = {
      eventType: 'follow_from_video',
      videoId,
      creatorId,
      feedType,
      isFollowing,
      timestamp: Date.now(),
    };

    await trackEvent(eventData);
    event('feed_follow_from_video', {
      video_id: videoId,
      creator_id: creatorId,
      feed_type: feedType,
      is_following: isFollowing.toString(),
    });
  }

  async trackNotInterested(
    videoId: string,
    creatorId: string,
    feedType: 'forYou' | 'following'
  ) {
    const eventData = {
      eventType: 'not_interested',
      videoId,
      creatorId,
      feedType,
      timestamp: Date.now(),
    };

    await trackEvent(eventData);
    event('feed_not_interested', {
      video_id: videoId,
      creator_id: creatorId,
      feed_type: feedType,
    });
  }

  async trackReport(
    videoId: string,
    creatorId: string,
    reason?: string,
    feedType?: 'forYou' | 'following'
  ) {
    const eventData = {
      eventType: 'report',
      videoId,
      creatorId,
      feedType,
      reason,
      timestamp: Date.now(),
    };

    await trackEvent(eventData);
    event('feed_report', {
      video_id: videoId,
      creator_id: creatorId,
      feed_type: feedType,
      reason,
    });
  }

  cleanup(videoId: string) {
    const timer = this.viewTimers.get(videoId);
    if (timer) {
      clearTimeout(timer);
      this.viewTimers.delete(videoId);
    }
    this.viewStartTimes.delete(videoId);
  }

  reset() {
    this.viewTimers.forEach(timer => clearTimeout(timer));
    this.viewTimers.clear();
    this.viewStartTimes.clear();
  }
}

export const feedEventLogger = new FeedEventLogger();
```

**Integration Points**:
- Sends to custom API via `trackEvent()`
- Sends to Google Analytics via `event()`
- Tracks view timers automatically
- Cleans up timers on video change

---

## Firestore Queries & Indexes

### Required Indexes

#### For You Feed
```
Collection: videos
Fields: status (Ascending), createdAt (Descending)
```

#### Following Feed
```
Collection: videos
Fields: creatorId (Ascending), status (Ascending), createdAt (Descending)
```

**OR** (fallback):
```
Collection: videos
Fields: userId (Ascending), status (Ascending), createdAt (Descending)
```

#### Follows Collection
```
Collection: follows
Fields: followerUserId (Ascending), isActive (Ascending)
```

### Query Patterns

#### For You Feed Query
```typescript
query(
  collection(db, 'videos'),
  where('status', '==', 'published'),
  orderBy('createdAt', 'desc'),
  limit(20)
)
```

#### Following Feed Query (Batched)
```typescript
// For each batch of 10 user IDs:
query(
  collection(db, 'videos'),
  where('creatorId', 'in', [userId1, userId2, ..., userId10]),
  where('status', '==', 'published'),
  orderBy('createdAt', 'desc'),
  limit(40)
)
```

#### Pagination Query
```typescript
const lastDoc = await getDoc(doc(db, 'videos', lastVideoId))
query(
  collection(db, 'videos'),
  where('status', '==', 'published'),
  orderBy('createdAt', 'desc'),
  startAfter(lastDoc),
  limit(20)
)
```

### Fallback Strategy

If composite index is missing:
1. Query without `status` filter
2. Fetch more documents (2x limit)
3. Filter `status === 'published'` in memory
4. Return filtered results

---

## Performance Optimizations

### 1. Batch Creator Info Fetching

**Problem**: Sequential creator lookups are slow

**Solution**: Collect all unique creator IDs, then fetch in parallel

```typescript
// First pass: collect creator IDs
const creatorIds = new Set<string>()
videos.forEach(video => creatorIds.add(video.creatorId))

// Second pass: batch fetch
const creatorPromises = Array.from(creatorIds).map(id => 
  getCreatorInfo(id)
)
const creators = await Promise.all(creatorPromises)
```

### 2. Reduced Initial Load

**Problem**: Loading 500 videos initially is slow

**Solution**: Load 20 videos initially, paginate as needed

```typescript
const INITIAL_LIMIT = 20 // Instead of 500
```

### 3. Timeout for Creator Lookups

**Problem**: Slow creator lookups block entire feed

**Solution**: 2-second timeout per creator lookup

```typescript
const timeoutPromise = new Promise(resolve => 
  setTimeout(() => resolve(null), 2000)
)
const creator = await Promise.race([
  getCreatorInfo(userId),
  timeoutPromise
])
```

### 4. Caching

**Problem**: Repeated fetches for same data

**Solution**: 5-minute cache for feed data

```typescript
private videos: HomeVideo[] = []
private lastFetchTime: number = 0
private readonly CACHE_DURATION = 5 * 60 * 1000 // 5 minutes
```

### 5. Deferred Initial Load

**Problem**: Feed loading blocks initial render

**Solution**: Defer load with `setTimeout`

```typescript
useEffect(() => {
  const timer = setTimeout(() => {
    loadVideos()
  }, 0)
  return () => clearTimeout(timer)
}, [])
```

### 6. Lazy Loading Components

**Problem**: Feed components load on every page

**Solution**: Dynamic import with `next/dynamic`

```typescript
const HomeView = dynamic(
  () => import('@/components/feed/HomeView').then(mod => mod.HomeView),
  { ssr: false }
)
```

---

## Integration Guide

### Step 1: Set Up Data Structures

Create the `HomeVideo` and `User` interfaces in your app:

```typescript
// types/feed.ts
interface HomeVideo {
  id: string
  creator: User
  videoUrl: string
  thumbnailUrl: string
  // ... other fields
}

interface User {
  id: string
  displayName: string
  username: string
  avatarURL?: string
}
```

### Step 2: Implement Service Layer

#### For You Feed Service

```typescript
class HomeFeedService {
  async loadAllVideos(): Promise<HomeVideo[]> {
    // 1. Query Firestore for published videos
    // 2. Collect unique creator IDs
    // 3. Batch fetch creator info
    // 4. Map videos with creator data
    // 5. Return HomeVideo[]
  }

  async loadMoreVideos(lastVideo: HomeVideo): Promise<HomeVideo[]> {
    // 1. Get last document snapshot
    // 2. Query with startAfter
    // 3. Batch fetch creator info
    // 4. Return next batch
  }
}
```

#### Following Feed Service

```typescript
class FollowingFeedService {
  async getFollowingIds(userId: string): Promise<string[]> {
    // 1. Query follows collection
    // 2. Return array of user IDs
  }

  async loadFollowingFeed(limit: number, lastVideo?: HomeVideo): Promise<HomeVideo[]> {
    // 1. Get following IDs
    // 2. Batch queries (10 IDs per batch)
    // 3. Fetch videos from each batch
    // 4. Deduplicate and sort
    // 5. Return HomeVideo[]
  }
}
```

### Step 3: Implement State Management

```typescript
function useFeedState() {
  const [forYouVideos, setForYouVideos] = useState<HomeVideo[]>([])
  const [followingVideos, setFollowingVideos] = useState<HomeVideo[]>([])
  const [activeTab, setActiveTab] = useState<'forYou' | 'following'>('forYou')
  
  const loadVideos = async () => {
    if (activeTab === 'forYou') {
      const videos = await homeFeedService.loadAllVideos()
      setForYouVideos(videos)
    } else {
      const videos = await followingFeedService.loadFollowingFeed()
      setFollowingVideos(videos)
    }
  }
  
  return { forYouVideos, followingVideos, loadVideos, activeTab, setActiveTab }
}
```

### Step 4: Implement UI Components

#### Feed Selector
```typescript
function FeedSelector({ activeTab, onTabChange }) {
  return (
    <div>
      <button onClick={() => onTabChange('forYou')}>
        For You
      </button>
      <button onClick={() => onTabChange('following')}>
        Following
      </button>
    </div>
  )
}
```

#### Video Player
```typescript
function VideoPlayer({ video, isActive }) {
  return (
    <video
      src={video.videoUrl}
      autoPlay={isActive}
      muted
      loop
      playsInline
    />
  )
}
```

### Step 5: Implement Event Logging

```typescript
class FeedEventLogger {
  async trackImpression(videoId, creatorId, feedType) {
    await trackEvent({
      eventType: 'impression',
      videoId,
      creatorId,
      feedType
    })
  }
  
  async trackViewStart(videoId, creatorId, feedType) {
    // Track view start
    // Set up 2-second timer
  }
  
  // ... other event methods
}
```

### Step 6: Set Up Firestore Indexes

Create composite indexes in Firebase Console:

1. **For You Feed**:
   - Collection: `videos`
   - Fields: `status` (Ascending), `createdAt` (Descending)

2. **Following Feed**:
   - Collection: `videos`
   - Fields: `creatorId` (Ascending), `status` (Ascending), `createdAt` (Descending)

3. **Follows Collection**:
   - Collection: `follows`
   - Fields: `followerUserId` (Ascending), `isActive` (Ascending)

---

## API Reference

### HomeFeedService

#### `loadAllVideos(): Promise<HomeVideo[]>`
Loads initial batch of For You feed videos.

**Returns**: Array of `HomeVideo` objects

**Throws**: Error if Firestore not initialized

---

#### `loadMoreVideos(lastVideo: HomeVideo): Promise<HomeVideo[]>`
Loads next batch of videos for pagination.

**Parameters**:
- `lastVideo`: Last video in current batch

**Returns**: Array of next `HomeVideo` objects

**Throws**: Error if pagination fails

---

### FollowingFeedService

#### `getFollowingIds(userId: string): Promise<string[]>`
Gets list of user IDs that the current user follows.

**Parameters**:
- `userId`: Current user ID

**Returns**: Array of user IDs

---

#### `loadFollowingFeed(limitCount: number, lastVideo?: HomeVideo): Promise<HomeVideo[]>`
Loads videos from users the current user follows.

**Parameters**:
- `limitCount`: Number of videos to fetch (default: 20)
- `lastVideo`: Optional last video for pagination

**Returns**: Array of `HomeVideo` objects

---

### useFeedState Hook

#### State
- `forYouVideos: HomeVideo[]`
- `followingVideos: HomeVideo[]`
- `isLoading: boolean`
- `isLoadingMore: boolean`
- `hasMoreContent: boolean`
- `currentIndex: number`
- `activeTab: 'forYou' | 'following'`
- `error: string | null`

#### Methods
- `loadVideos(): Promise<void>`
- `loadMoreVideos(lastVideo: HomeVideo): Promise<void>`
- `refreshFeed(): Promise<void>`
- `switchTab(tab: 'forYou' | 'following'): void`
- `setCurrentIndex(index: number): void`

---

### FeedEventLogger

#### `trackImpression(videoId, creatorId, feedType, videoIndex?)`
Tracks video impression.

#### `trackViewStart(videoId, creatorId, feedType)`
Tracks view start and sets up 2-second timer.

#### `trackView2s(videoId, creatorId, feedType)`
Tracks 2-second view milestone.

#### `trackViewComplete(videoId, creatorId, feedType, progressPercent?)`
Tracks view completion.

#### `trackLike(videoId, creatorId, isLiked, feedType)`
Tracks like/unlike action.

#### `trackComment(videoId, creatorId, feedType)`
Tracks comment action.

#### `trackShare(videoId, creatorId, feedType)`
Tracks share action.

#### `trackSave(videoId, creatorId, isSaved, feedType)`
Tracks save/bookmark action.

#### `trackFollowFromVideo(videoId, creatorId, isFollowing, feedType)`
Tracks follow/unfollow from video.

#### `trackNotInterested(videoId, creatorId, feedType)`
Tracks not interested action.

#### `trackReport(videoId, creatorId, reason?, feedType)`
Tracks report action.

#### `cleanup(videoId)`
Cleans up view tracking for a video.

#### `reset()`
Resets all tracking state.

---

## Firestore Schema

### Videos Collection

```typescript
{
  id: string                    // Document ID
  creatorId: string             // Primary: creator user ID
  userId?: string               // Fallback: creator user ID
  status: 'published' | 'draft' | 'processing' | 'blocked' | 'deleted'
  playbackUrl?: string          // Primary: transcoded playback URL
  originalVideoUrl?: string     // Original video URL
  videoUrl?: string             // Fallback: video URL
  thumb?: string                // Primary: thumbnail URL
  thumbnailUrl?: string         // Fallback: thumbnail URL
  createdAt: Timestamp          // Creation timestamp
  likes: number                 // Like count
  comments: number              // Comment count
  views: number                 // View count
  shares: number                // Share count
  bookmarks: number             // Bookmark count
  caption: string               // Video caption
  categoryId: string            // Category ID
  category?: string             // Category name
  tags: string[]                // Video tags
  // ... other fields
}
```

### Follows Collection

```typescript
{
  id: string                    // Document ID (format: followerUserId_targetUserId)
  followerUserId: string         // User who is following
  targetUserId: string           // User being followed
  isActive: boolean              // Is follow active
  createdAt: Timestamp           // Follow timestamp
}
```

### Users Collection

```typescript
{
  id: string                     // Document ID (user ID)
  uid: string                    // User ID (same as document ID)
  username: string               // Username
  displayName: string            // Display name
  avatarURL?: string            // Avatar URL
  bio?: string                  // User bio
  hashtags?: string[]          // User hashtags
  // ... other fields
}
```

---

## Error Handling

### Common Errors

1. **Index Missing Error**
   - **Error**: `failed-precondition` or message contains "index"
   - **Solution**: Use fallback query without status filter, filter in memory

2. **Permission Denied**
   - **Error**: `permission-denied`
   - **Solution**: Check Firestore security rules, ensure user is authenticated

3. **Network Error**
   - **Error**: Network timeout or connection error
   - **Solution**: Retry with exponential backoff, show error message to user

4. **Empty Feed**
   - **Error**: No videos returned
   - **Solution**: Show empty state message, suggest following users (for Following tab)

---

## Best Practices

1. **Always batch creator info fetching** - Don't fetch sequentially
2. **Use pagination** - Don't load all videos at once
3. **Implement fallback queries** - Handle missing indexes gracefully
4. **Cache feed data** - Reduce unnecessary Firestore reads
5. **Track events consistently** - Use FeedEventLogger for all interactions
6. **Handle errors gracefully** - Show user-friendly error messages
7. **Optimize initial load** - Defer loading, use lazy loading
8. **Clean up timers** - Prevent memory leaks from event tracking

---

## Mobile App Integration

### Flutter/Dart Implementation

```dart
// Service layer
class HomeFeedService {
  Future<List<HomeVideo>> loadAllVideos() async {
    // Query Firestore
    // Batch fetch creator info
    // Return HomeVideo list
  }
}

// State management (Riverpod)
@riverpod
class FeedState extends _$FeedState {
  @override
  FeedState build() => FeedState(
    forYouVideos: [],
    followingVideos: [],
    isLoading: true,
  );
  
  Future<void> loadVideos() async {
    state = state.copyWith(isLoading: true);
    final videos = await homeFeedService.loadAllVideos();
    state = state.copyWith(
      forYouVideos: videos,
      isLoading: false,
    );
  }
}

// UI Component
class FeedView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedState = ref.watch(feedStateProvider);
    
    return TabBarView(
      children: [
        VideoFeed(videos: feedState.forYouVideos),
        VideoFeed(videos: feedState.followingVideos),
      ],
    );
  }
}
```

---

## Conclusion

This feed system provides a scalable, performant solution for displaying videos in a TikTok-style vertical feed. Key features include:

- **Separation of concerns**: Service layer, state management, and UI are clearly separated
- **Performance optimized**: Batch fetching, caching, and pagination
- **Error resilient**: Fallback queries and graceful error handling
- **Analytics ready**: Comprehensive event tracking
- **Mobile friendly**: Can be easily adapted to Flutter/Dart

For questions or issues, refer to the code comments in the respective service files or component files.
