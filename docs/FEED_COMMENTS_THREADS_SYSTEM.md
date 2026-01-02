# Feed, Comments, and Threads System Documentation

## Table of Contents
1. [Overview](#overview)
2. [For You Page](#for-you-page)
3. [Following Feed](#following-feed)
4. [Comments System](#comments-system)
5. [Thread Implementation](#thread-implementation)
6. [Component Architecture](#component-architecture)
7. [Data Flow](#data-flow)
8. [Service Layer](#service-layer)
9. [State Management](#state-management)
10. [Key Implementation Details](#key-implementation-details)
11. [Preventing Duplicates](#preventing-duplicates)
12. [Mobile Considerations](#mobile-considerations)

---

## Overview

This document provides comprehensive documentation for the **For You page**, **Following feed**, **Comments view**, and **Thread implementation** to ensure consistency between website and app implementations and prevent duplicate or conflicting code.

### System Components
- **For You Page**: Displays all published videos sorted by creation date (newest first)
- **Following Feed**: Shows videos from users the current user follows
- **Comments View**: Real-time comment system with replies and thread creation
- **Thread System**: Forum threads created from video comments with video embedding

---

## For You Page

### Route
- **Path**: `/for-you`
- **File**: `app/for-you/page.tsx`

### Implementation
```typescript
// app/for-you/page.tsx
'use client'
import dynamic from 'next/dynamic'

const HomeView = dynamic(() => import('@/components/feed/HomeView').then(mod => ({ default: mod.HomeView })), {
  ssr: false,
  loading: () => <LoadingSpinner />
})

export default function ForYouPage() {
  return <HomeView />
}
```

### Key Points
- Uses **dynamic import** with `ssr: false` for client-side only rendering
- Delegates all functionality to `HomeView` component
- Shows loading spinner during component load

### Data Source
- **Service**: `services/homeFeedService.ts` → `VideoService.loadAllVideos()`
- **Query**: Firestore `videos` collection
  - Filter: `status == 'published'`
  - Order: `createdAt` descending
  - Limit: 20 initially (paginated)

### Firestore Query
```typescript
query(
  collection(db, 'videos'),
  where('status', '==', 'published'),
  orderBy('createdAt', 'desc'),
  limit(20)
)
```

### Fallback Strategy
If composite index is missing:
1. Query without `status` filter
2. Fetch 2x limit (40 videos)
3. Filter `status === 'published'` in memory
4. Return filtered results

---

## Following Feed

### Route
- **Path**: `/for-you` (tab within HomeView)
- **Component**: `components/feed/HomeView.tsx` with `activeTab === 'following'`

### Implementation
- **Service**: `services/followingFeedService.ts` → `FollowingFeedService.loadFollowingFeed()`
- **Hook**: `hooks/useFeedState.ts` manages tab switching

### Data Flow
1. Get current user's following list from `follows` collection
2. Query videos from followed users (batched, max 10 per query)
3. Merge and sort by `createdAt` descending
4. Return `HomeVideo[]` array

### Firestore Queries

#### Step 1: Get Following IDs
```typescript
query(
  collection(db, 'follows'),
  where('followerUserId', '==', userId),
  where('isActive', '==', true)
)
// Maps to: data.targetUserId || data.followingId || data.followedId
```

#### Step 2: Query Videos (Batched)
```typescript
// For each batch of 10 user IDs:
query(
  collection(db, 'videos'),
  where('creatorId', 'in', batch), // or 'userId' as fallback
  where('status', '==', 'published'),
  orderBy('createdAt', 'desc'),
  limit(limitCount * 2)
)
```

### Key Points
- **Batching Required**: Firestore `in` query limit is 10, so batches are needed
- **Deduplication**: Videos are deduplicated across batches
- **Sorting**: All videos sorted by `createdAt` after fetching
- **Empty State**: Returns empty array if user follows no one

---

## Comments System

### Components

#### 1. CommentsView (Standalone)
- **File**: `components/CommentsView.tsx`
- **Usage**: Used in profile pages, video detail pages (non-overlay)
- **Props**:
  ```typescript
  interface CommentsViewProps {
    videoId: string;
    videoOwnerId: string;
    isOpen: boolean;
    onClose: () => void;
    videoTitle?: string;
  }
  ```

#### 2. CommentsSheet (Legacy/Alternative)
- **File**: `components/video_detail_overlay/CommentsSheet.tsx`
- **Usage**: Alternative comment component (may be used in specific contexts)
- **Note**: `VideoDetailOverlay` currently uses `CommentsView` instead of `CommentsSheet`
- **Props**:
  ```typescript
  interface CommentsSheetProps {
    videoId: string;
    isOpen: boolean;
    onClose: () => void;
    onComment?: (videoId: string, comment: string) => Promise<void>;
    comments?: Comment[];
    onLoadComments?: (videoId: string) => Promise<Comment[]>;
    onLikeComment?: (commentId: string, isLiked: boolean) => Promise<void>;
    onReplyComment?: (commentId: string, reply: string) => Promise<void>;
  }
  ```

### Data Structure

#### Comment Interface
```typescript
interface Comment {
  id: string;
  user: {
    id: string;
    username: string;
    displayName: string;
    avatarURL: string | null;
    bio?: string;
    onlineStatus?: 'online' | 'offline';
    postCount?: number;
    followerCount?: number;
    followingCount?: number;
  };
  text: string;
  timestamp: Date;
  likeCount: number;
  isLiked: boolean;
  replies?: Comment[];
  linkedThreadId?: string; // If thread created from this comment
}
```

### Firestore Structure
```
videos/{videoId}/comments/{commentId}
  - text: string
  - userId: string
  - user: { id, username, displayName, avatarURL }
  - timestamp: Timestamp
  - likeCount: number
  - likedBy: string[]
  - replies: subcollection
  - linkedThreadId?: string
```

### Services

#### Hook: `hooks/useComments.ts`
- **Purpose**: Manages comment state and operations
- **Methods**:
  - `addComment(text: string)`: Add new comment
  - `deleteComment(commentId: string)`: Delete comment
  - `toggleLike(commentId: string)`: Like/unlike comment
  - `addReply(parentCommentId: string, text: string)`: Reply to comment
  - `setSortOption(option: 'newest' | 'mostLiked')`: Change sort order

#### Service: `services/commentService.ts`
- **Functions**:
  - `subscribeToComments(videoId, callback)`: Real-time listener
  - `addComment(videoId, text, author)`: Create comment
  - `deleteComment(videoId, commentId, videoOwnerId)`: Delete comment
  - `toggleCommentLike(videoId, commentId)`: Toggle like
  - `addReply(videoId, parentCommentId, text, author)`: Add reply
  - `linkCommentToThread(videoId, commentId, threadId)`: Link comment to thread

### Real-time Updates
- Uses Firestore `onSnapshot` for real-time comment updates
- Automatically updates UI when comments are added/deleted/liked
- Requires authentication (comments are private to logged-in users)

### Thread Creation from Comments
- **Button**: Only visible to video owner (`currentUserId === videoOwnerId`)
- **Modal**: Opens thread creation form with:
  - Title (required)
  - Content (optional, pre-filled with comment text)
  - Category (required)
  - Tags (optional)
  - Visibility (public/followers/inviteOnly)
- **Process**:
  1. User clicks "Thread" button on comment
  2. Modal opens with pre-filled content
  3. User fills title, category, optional content/tags
  4. `forumService.createThreadFromComment()` creates thread
  5. `linkCommentToThread()` links comment to thread
  6. User redirected to `/threads/{threadId}`

### Mobile Considerations
- **Event Propagation**: Comments sheet stops propagation to prevent feed swipe
- **Touch Events**: `onTouchStart`, `onTouchMove`, `onTouchEnd` call `e.stopPropagation()`
- **Keyboard Handling**: Uses Visual Viewport API for dynamic padding
- **Input Focus**: `font-size: 16px` prevents iOS zoom
- **CSS**: `touch-action: pan-y` and `overscroll-behavior: contain` on comments list

---

## Thread Implementation

### Routes
- **List**: `/threads` → `app/threads/page.tsx`
- **Detail**: `/threads/[id]` → `app/threads/[id]/page.tsx`

### Thread Creation

#### 1. Standalone Thread Creation
- **Component**: `components/forum/ForumPostForm.tsx`
- **Service Method**: `forumService.createPost()`
- **Location**: Thread list page (`/threads`)
- **Fields**:
  - Title (required)
  - Content (required)
  - Category (required, hierarchical)
  - Tags (optional, comma-separated)
  - Visibility (public/followers/inviteOnly)

#### 2. Thread Creation from Comment
- **Service Method**: `forumService.createThreadFromComment()`
- **Location**: Comments view (video owner only)
- **Process**: Creates thread from video comment with video link

#### Service Methods
```typescript
// Standalone thread creation
async createPost(
  title: string,
  content: string,
  categoryId: string,
  tags: string[],
  author: ForumAuthor,
  visibility: 'public' | 'followers' | 'inviteOnly'
): Promise<string>

// Thread from comment
async createThreadFromComment(
  threadTitle: string,
  commentText: string,
  commentAuthor: { id: string; name: string; username: string },
  threadAuthor: ForumAuthor,
  videoId: string,
  commentId: string,
  categoryId: string,
  tags: string[],
  visibility: 'public' | 'followers' | 'inviteOnly'
): Promise<string>
```

#### Firestore Document Structure
```typescript
{
  title: string,
  content: string,
  category: categoryId,
  tags: string[],
  authorId: string,
  author: ForumAuthor,
  visibility: 'public' | 'followers' | 'inviteOnly',
  likes: number,
  commentCount: number,
  likedBy: string[],
  bookmarkedBy: string[],
  followedBy: string[],
  linkedVideoId?: string,        // If created from comment
  linkedCommentId?: string,     // If created from comment
  sourceComment?: {              // If created from comment
    text: string,
    authorId: string,
    authorName: string,
    authorUsername: string,
  },
  contentType: 'text',
  createdAt: Timestamp,
  updatedAt: Timestamp,
  deleted: boolean,
}
```

### Thread List Page (`/threads`)

#### Features
- **Thread Display**: Grid layout with `ForumPostCard` components
- **Search**: Real-time search by title/content
- **Sorting Options**:
  - `recent`: Most recently created
  - `popular`: Most liked
  - `trending`: Trending algorithm
  - `activeNow`: Recently commented
  - `new`: Newest posts
- **Filtering Options**:
  - `all`: All threads
  - `myPosts`: User's own threads
  - `commented`: Threads user has commented on
- **Category Filtering**:
  - Hierarchical categories (parent/child)
  - Quick category buttons
  - Expandable game categories (Looking for Group, Competitive)
- **Thread Creation**: Modal form for creating new threads
- **Notifications**: Unread notification count badge

#### Category System
- **Hierarchical**: Parent categories with child categories
- **Examples**: 
  - Parent: "Looking for Group" → Children: Game names
  - Parent: "Competitive" → Children: Game names
- **Service**: `forumService.getCategories()`
- **Structure**: `forumCategories/{categoryId}` with `parentCategoryId` field

### Thread Detail Page (`/threads/[id]`)

#### Thread Actions
- **Like/Unlike**: `forumService.togglePostLike()`
- **Bookmark**: `forumService.togglePostBookmark()`
- **Follow/Unfollow**: `forumService.toggleThreadFollow()` (notifications)
- **Delete**: `forumService.deletePost()` (author only)
- **Author Navigation**: Clickable avatar/name → `/streamer/{username}`

#### Video Embedding
- **Location**: `app/threads/[id]/page.tsx`
- **Logic**: If `post.linkedVideoId` exists, fetch video details and embed
- **Implementation**:
  ```typescript
  const [linkedVideo, setLinkedVideo] = useState(null)
  const [isLoadingVideo, setIsLoadingVideo] = useState(false)
  
  useEffect(() => {
    if (post?.linkedVideoId) {
      setIsLoadingVideo(true)
      forumService.getVideoDetails(post.linkedVideoId)
        .then(video => setLinkedVideo(video))
        .finally(() => setIsLoadingVideo(false))
    }
  }, [post?.linkedVideoId])
  ```

#### Video Display
- Renders `<video>` element with controls
- Shows thumbnail, title, views, likes
- "Watch Full Video" button navigates to `/video/{videoId}`
- Removes any markdown video links from content to avoid duplication

#### Content Rendering
- Original comment text is included in thread content (if from comment)
- Video link is **NOT** added as markdown (video is embedded instead)
- Any existing markdown links are removed if video is embedded

### Thread Comments

#### Structure
- **Collection**: `forumPosts/{postId}/comments/{commentId}`
- **Real-time**: Uses `forumService.watchComments()` for live updates

#### Features
- **Add Comment**: `forumService.addComment()`
- **Like/Dislike**: `forumService.toggleCommentLike()` / `toggleCommentDislike()` (mutually exclusive)
- **Reply**: Nested replies (1-level deep)
- **Delete**: Author can delete own comments
- **Expand/Collapse**: Replies are expandable/collapsible
- **Reply Count**: Tracks number of replies per comment
- **Author Enrichment**: Fetches author data from Firestore
- **Author Navigation**: Clickable author → `/streamer/{username}`

#### Comment Data Structure
```typescript
{
  id: string,
  content: string,
  author: {
    uid: string,
    username: string,
    displayName: string,
    avatarUrl: string,
  },
  createdAt: Timestamp,
  likes: number,
  dislikes: number,
  likedBy: string[],
  dislikedBy: string[],
  replyCount: number,
  replies?: ForumComment[],
}
```

### Thread Service Methods

#### Thread Operations
- `createPost()`: Create standalone thread
- `createThreadFromComment()`: Create thread from comment
- `getPost(postId)`: Get thread details
- `getPosts()`: Get threads with filters/sorting
- `deletePost(postId)`: Delete thread (author only)
- `togglePostLike()`: Like/unlike thread
- `togglePostBookmark()`: Bookmark/unbookmark thread
- `toggleThreadFollow()`: Follow/unfollow thread (for notifications)
- `getUserPosts(userId)`: Get user's threads
- `getUserCommentedPosts(userId)`: Get threads user commented on

#### Comment Operations
- `watchComments(postId, authorId, callback)`: Real-time comment listener
- `addComment(postId, text, author)`: Add comment to thread
- `toggleCommentLike(postId, commentId, userId)`: Like comment
- `toggleCommentDislike(postId, commentId, userId)`: Dislike comment
- `deleteComment(postId, commentId)`: Delete comment (author only)
- `addReply(postId, parentCommentId, text, author)`: Reply to comment

#### Category Operations
- `getCategories()`: Get all categories
- `initializeDefaultCategories()`: Initialize default category structure

#### Video Operations
- `getVideoDetails(videoId)`: Get video for embedding in thread

### Thread Notifications
- **Collection**: `forumNotifications/{userId}/items/{notificationId}`
- **Types**: Thread comments, thread replies
- **Service**: `forumService.getUnreadNotificationCount()`
- **Real-time**: Updates every 30 seconds on thread list page

---

## Component Architecture

### HomeView Component
- **File**: `components/feed/HomeView.tsx`
- **Purpose**: Main orchestrator for feed tabs and video playback
- **State Management**: Uses `useFeedState()` hook
- **Tabs**: 
  - `FeedSelector` component for tab switching
  - `activeTab: 'forYou' | 'following'`
- **Video Player**: `VideoDetailOverlay` component

### VideoDetailOverlay Component
- **File**: `components/video_detail_overlay/VideoDetailOverlay.tsx`
- **Purpose**: Full-screen video player with interactions
- **Features**:
  - Video playback (autoplay, mute/unmute)
  - Swipe gestures for navigation
  - Comments integration (uses `CommentsView` component)
  - Share, like, bookmark, follow actions
  - Report video functionality
  - Rate limiting for actions (likes, comments, shares)
  - Offline detection and handling
- **Comments Integration**: 
  - Uses `CommentsView` component (not `CommentsSheet`)
  - `showComments` state controls comments visibility
  - Disables feed swipe when `showComments === true`
  - Prevents wheel/touch events from triggering video navigation when comments are open
  - Props passed: `videoId`, `videoOwnerId`, `isOpen`, `onClose`, `videoTitle`

### FeedSelector Component
- **File**: `components/feed/FeedSelector.tsx`
- **Purpose**: Tab buttons for For You / Following
- **State**: Controlled by `HomeView` via `activeTab` prop

---

## Data Flow

### For You Feed Flow
```
User visits /for-you
  ↓
ForYouPage component renders
  ↓
Dynamic import loads HomeView (with loading spinner)
  ↓
HomeView component mounts
  ↓
useFeedState hook initializes
  ↓
activeTab = 'forYou' (default)
  ↓
videoService.loadAllVideos()
  ↓
Firestore query: videos collection
  - Filter: status == 'published'
  - Order: createdAt descending
  - Limit: 20 initially
  ↓
Batch fetch creator info (parallel requests)
  ↓
Transform to HomeVideo[] with creator data
  ↓
setForYouVideos(videos)
  ↓
HomeView renders VideoDetailOverlay with videos
  ↓
VideoDetailOverlay handles video playback, interactions, comments
```

### Following Feed Flow
```
User switches to Following tab
  ↓
switchTab('following')
  ↓
followingFeedService.loadFollowingFeed()
  ↓
Get following IDs from follows collection
  ↓
Batch query videos (10 user IDs per batch)
  ↓
Merge and deduplicate videos
  ↓
Sort by createdAt descending
  ↓
setFollowingVideos(videos)
  ↓
HomeView renders VideoDetailOverlay
```

### Comment Flow
```
User opens comments (from VideoDetailOverlay)
  ↓
showComments state set to true
  ↓
Feed swipe gestures disabled
  ↓
CommentsView component renders
  ↓
useComments hook initializes
  ↓
subscribeToComments() sets up real-time listener
  ↓
Firestore: videos/{videoId}/comments subcollection
  ↓
onSnapshot callback fires on changes
  ↓
Transform Firestore docs to Comment[]
  ↓
Apply sorting (newest/mostLiked)
  ↓
setComments(sortedComments)
  ↓
UI updates automatically (real-time)
  ↓
User can add/delete/like/reply to comments
  ↓
Changes propagate via Firestore listeners
```

### Thread Creation Flow (from Comment)
```
User clicks "Thread" button on comment (video owner only)
  ↓
handleOpenThreadModal(comment) called
  ↓
Thread creation modal opens
  ↓
Pre-filled data:
  - Content: Original comment text
  - Category: First parent category (default)
  - Tags: Optional
  ↓
User fills:
  - Title (required)
  - Category (required, hierarchical)
  - Content (optional, can edit)
  - Tags (optional, comma-separated)
  - Visibility (public/followers/inviteOnly)
  ↓
handleCreateThreadFromComment() called
  ↓
forumService.createThreadFromComment() creates thread
  - Adds 'from-video-comment' tag automatically
  - Links video via linkedVideoId
  - Links comment via linkedCommentId
  - Stores source comment metadata
  ↓
linkCommentToThread() updates comment with threadId
  ↓
Success message shown
  ↓
Redirect to /threads/{threadId}
```

### Standalone Thread Creation Flow
```
User clicks "Create Post" button on /threads page
  ↓
ForumPostForm modal opens
  ↓
User fills:
  - Title (required)
  - Content (required)
  - Category (required, hierarchical)
  - Tags (optional)
  - Visibility (public/followers/inviteOnly)
  ↓
forumService.createPost() creates thread
  ↓
Category post count updated
  ↓
Modal closes, thread list refreshes
  ↓
User can navigate to new thread
```

---

## Service Layer

### homeFeedService.ts
- **Class**: `VideoService`
- **Methods**:
  - `loadAllVideos(): Promise<HomeVideo[]>`
  - `getCreatorInfo(userId: string): Promise<User>`
  - `getDocumentById(videoId: string): Promise<DocumentSnapshot>`
- **Caching**: 5-minute cache for video list
- **Performance**: Batches creator info fetching

### followingFeedService.ts
- **Class**: `FollowingFeedService`
- **Methods**:
  - `getFollowingIds(userId: string): Promise<string[]>`
  - `loadFollowingFeed(limitCount: number, lastVideo?: HomeVideo): Promise<HomeVideo[]>`
- **Batching**: Handles Firestore `in` query limit (10)

### commentService.ts
- **Functions**:
  - `subscribeToComments(videoId, callback)`
  - `addComment(videoId, text, author)`
  - `deleteComment(videoId, commentId, videoOwnerId)`
  - `toggleCommentLike(videoId, commentId)`
  - `addReply(videoId, parentCommentId, text, author)`
  - `linkCommentToThread(videoId, commentId, threadId)`

### forumService.ts
- **Thread Creation**:
  - `createPost(...)`: Create standalone thread
  - `createThreadFromComment(...)`: Create thread from comment
- **Thread Operations**:
  - `getPost(postId)`: Get thread details
  - `getPosts(...)`: Get threads with filters/sorting/pagination
  - `deletePost(postId)`: Delete thread (author only)
  - `togglePostLike(postId, userId, author)`: Like/unlike thread
  - `togglePostBookmark(postId, userId)`: Bookmark/unbookmark thread
  - `toggleThreadFollow(postId, userId)`: Follow/unfollow thread
  - `getUserPosts(userId)`: Get user's threads
  - `getUserCommentedPosts(userId)`: Get threads user commented on
- **Thread Comments**:
  - `watchComments(postId, authorId, callback)`: Real-time comment listener
  - `addComment(postId, text, author)`: Add comment to thread
  - `toggleCommentLike(postId, commentId, userId)`: Like thread comment
  - `toggleCommentDislike(postId, commentId, userId)`: Dislike thread comment
  - `deleteComment(postId, commentId)`: Delete comment (author only)
  - `addReply(postId, parentCommentId, text, author)`: Reply to comment
- **Categories**:
  - `getCategories()`: Get all categories
  - `initializeDefaultCategories()`: Initialize default category structure
- **Video Integration**:
  - `getVideoDetails(videoId)`: Get video for embedding in thread
- **Notifications**:
  - `getUnreadNotificationCount(userId)`: Get unread thread notification count

---

## State Management

### useFeedState Hook
- **File**: `hooks/useFeedState.ts`
- **State**:
  - `forYouVideos: HomeVideo[]`
  - `followingVideos: HomeVideo[]`
  - `isLoading: boolean`
  - `isLoadingMore: boolean`
  - `hasMoreContent: boolean`
  - `currentIndex: number`
  - `activeTab: 'forYou' | 'following'`
  - `error: string | null`
- **Methods**:
  - `loadVideos()`
  - `loadMoreVideos()`
  - `refreshFeed()`
  - `switchTab(tab)`

### useComments Hook
- **File**: `hooks/useComments.ts`
- **State**:
  - `comments: Comment[]`
  - `sortedComments: Comment[]`
  - `isLoading: boolean`
  - `error: string | null`
  - `sortOption: 'newest' | 'mostLiked'`
- **Methods**:
  - `addComment(text)`
  - `deleteComment(commentId)`
  - `toggleLike(commentId)`
  - `addReply(parentCommentId, text)`
  - `setSortOption(option)`

---

## Key Implementation Details

### Video Field Mapping
The system supports multiple field names for video URLs:
```typescript
const playbackUrl = 
  data.playbackUrl || 
  data.originalVideoUrl || 
  data.videoUrl || 
  data.videoURL || 
  data.video_url || 
  data.canonicalPlaybackUrl || ''
```

### Creator ID Mapping
```typescript
const creatorId = 
  data.creatorId || 
  data.userId || 
  data.uid
```

### Follow Field Mapping
```typescript
const targetUserId = 
  data.targetUserId || 
  data.followingId || 
  data.followedId
```

### Pagination
- Uses Firestore `startAfter()` with last document snapshot
- `lastVideo` parameter for pagination
- `limitCount` defaults to 20

### Error Handling
- Index errors: Falls back to query without status filter
- Permission errors: Gracefully handles authentication issues
- Network errors: Retry logic with exponential backoff

---

## Preventing Duplicates

### Code Organization Rules

1. **Single Source of Truth**
   - `HomeView` is the only component that manages feed tabs
   - `CommentsView` and `CommentsSheet` are separate components (don't duplicate)
   - `forumService` is the only service for thread operations

2. **Component Usage**
   - **CommentsView**: 
     - Primary comment component used in feed (`VideoDetailOverlay`)
     - Also used in profile pages and video detail pages (non-overlay)
     - Handles all comment operations (add, delete, like, reply, thread creation)
   - **CommentsSheet**: 
     - Alternative/legacy component (may exist but not currently used in main feed)
     - Check before using - prefer `CommentsView` for consistency
   - **Do NOT** create new comment components - use existing ones

3. **Service Usage**
   - **For You Feed**: Always use `videoService.loadAllVideos()`
   - **Following Feed**: Always use `followingFeedService.loadFollowingFeed()`
   - **Comments**: Always use `useComments` hook or `commentService` functions
   - **Threads**: Always use `forumService` methods
     - Thread creation: `createPost()` or `createThreadFromComment()`
     - Thread operations: `getPost()`, `getPosts()`, `deletePost()`
     - Thread interactions: `togglePostLike()`, `togglePostBookmark()`, `toggleThreadFollow()`
     - Thread comments: `watchComments()`, `addComment()`, `toggleCommentLike()`, `deleteComment()`
     - Categories: `getCategories()`, `initializeDefaultCategories()`

4. **Data Queries**
   - **For You**: Query `videos` collection with `status == 'published'`
   - **Following**: Query `follows` collection first, then `videos` with `creatorId in [...]`
   - **Comments**: Query `videos/{videoId}/comments` subcollection
   - **Threads**: Query `forumPosts` collection

5. **State Management**
   - Use `useFeedState` hook for feed state
   - Use `useComments` hook for comment state
   - Do NOT create duplicate state management

### Before Adding New Code

**Check these files first:**
- `components/feed/HomeView.tsx` - Feed orchestration
- `components/CommentsView.tsx` - Primary comment component (used in feed and elsewhere)
- `components/video_detail_overlay/VideoDetailOverlay.tsx` - Video player with comments integration
- `components/video_detail_overlay/CommentsSheet.tsx` - Alternative comment component (check if used)
- `app/threads/page.tsx` - Thread list page
- `app/threads/[id]/page.tsx` - Thread detail page
- `components/forum/ForumPostForm.tsx` - Thread creation form
- `components/forum/ForumPostCard.tsx` - Thread card component
- `services/homeFeedService.ts` - For You feed service
- `services/followingFeedService.ts` - Following feed service
- `services/commentService.ts` - Comment operations
- `services/forumService.ts` - Thread operations (ALL thread features)
- `hooks/useFeedState.ts` - Feed state management
- `hooks/useComments.ts` - Comment state management

**If functionality exists:**
- Extend existing component/service
- Do NOT create duplicate
- Update this documentation if adding new features

---

## Mobile Considerations

### Gesture Handling
- **Feed Swipe**: Disabled when `showComments === true`
- **Comments Scroll**: Uses `touch-action: pan-y` to prevent parent scroll
- **Event Propagation**: Comments components stop propagation to prevent feed navigation

### Keyboard Handling
- **Visual Viewport API**: Detects keyboard height
- **Dynamic Padding**: Adjusts padding when keyboard opens
- **Input Focus**: `font-size: 16px` prevents iOS zoom
- **Scroll Into View**: Input scrolls into view on focus

### CSS Requirements
```css
/* Comments Sheet */
.commentsSheet {
  touch-action: pan-y;
  overscroll-behavior: contain;
}

/* Comments List */
.commentsList {
  overscroll-behavior: contain;
}

/* Input Area */
.inputArea {
  padding-bottom: env(keyboard-inset-bottom, 0);
}

.input {
  font-size: 16px; /* Prevents iOS zoom */
}
```

---

## Firestore Indexes Required

### For You Feed
```
Collection: videos
Fields: status (Ascending), createdAt (Descending)
```

### Following Feed
```
Collection: videos
Fields: creatorId (Ascending), status (Ascending), createdAt (Descending)
```

### Follows Collection
```
Collection: follows
Fields: followerUserId (Ascending), isActive (Ascending)
```

---

## Testing Checklist

### For You Feed
- [ ] Loads videos on page load
- [ ] Pagination works (load more)
- [ ] Pull-to-refresh works
- [ ] Videos sorted by newest first
- [ ] Only published videos shown

### Following Feed
- [ ] Shows videos from followed users only
- [ ] Empty state when not following anyone
- [ ] Pagination works
- [ ] Batches correctly (10 users per batch)

### Comments
- [ ] Real-time updates work
- [ ] Add comment works
- [ ] Delete comment works (owner only)
- [ ] Like comment works
- [ ] Reply to comment works
- [ ] Sort options work (newest/most liked)
- [ ] Thread creation button visible to owner only

### Threads
- [ ] Thread list page loads
- [ ] Standalone thread creation works
- [ ] Thread created from comment
- [ ] Category filtering works (hierarchical)
- [ ] Search functionality works
- [ ] Sorting options work (recent/popular/trending/activeNow/new)
- [ ] Filtering works (all/myPosts/commented)
- [ ] Thread detail page loads
- [ ] Like/unlike thread works
- [ ] Bookmark thread works
- [ ] Follow/unfollow thread works
- [ ] Delete thread works (author only)
- [ ] Video embedded in thread (if linkedVideoId exists)
- [ ] Comment linked to thread
- [ ] Thread comments work
- [ ] Like/dislike thread comments
- [ ] Reply to thread comments
- [ ] Delete thread comments (author only)
- [ ] Author navigation works (clickable avatars/names)
- [ ] Notifications work for thread comments/replies

---

## Summary

This documentation ensures:
1. **Consistency**: Website and app use same architecture
2. **No Duplicates**: Clear component/service boundaries
3. **Maintainability**: Single source of truth for each feature
4. **Mobile Support**: Proper gesture and keyboard handling
5. **Real-time Updates**: Firestore listeners for live data

**Before implementing new features, always check this document and existing code to avoid duplicates.**

