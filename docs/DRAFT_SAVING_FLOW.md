# Draft Saving Flow Documentation

This document describes the complete flow for saving video drafts from the publish video view to displaying them in the profile view. This documentation is intended for web developers to implement similar functionality.

## Table of Contents

1. [Overview](#overview)
2. [Data Structures](#data-structures)
3. [Storage Mechanism](#storage-mechanism)
4. [Service API](#service-api)
5. [UI Flow](#ui-flow)
6. [Implementation Guide](#implementation-guide)

## Overview

The draft system allows users to save videos locally before publishing them. Drafts are:
- Stored **locally** (not in Firebase/backend)
- Only visible to the user who created them
- Persisted across app restarts
- Displayed in the user's profile view as a combined thumbnail

### Key Features

- **Local Storage**: Videos and thumbnails stored in device storage
- **Metadata Storage**: Draft information stored in key-value storage (SharedPreferences/IndexedDB)
- **Thumbnail Generation**: Automatic high-quality thumbnail generation
- **Privacy**: Drafts are only visible to the creator

## Data Structures

### Draft Object

```typescript
interface Draft {
  id: string;                    // Unique draft ID (format: "draft_{timestamp}_{random}")
  videoPath: string;              // Local file path to video
  thumbnailPath: string;          // Local file path to thumbnail
  caption: string;                // Video caption
  hashtags: string[];             // Array of hashtags
  privacy: string;                // Privacy setting (e.g., "Everyone", "Friends", "Private")
  allowComments: boolean;         // Whether comments are allowed
  category: string;               // Video category (default: "general")
  createdAt: string;              // ISO 8601 timestamp
  updatedAt: string;              // ISO 8601 timestamp
  status: "draft";                // Always "draft" for local drafts
  isSharedWithConnections: boolean; // Future: sharing with connections
  sharedConnections: string[];     // Future: list of connection IDs
  metadata: {
    fileSize: number;             // Video file size in bytes
    duration: number;             // Video duration in seconds
    resolution: string;           // Video resolution (e.g., "1080x1920")
    format: string;               // Video format (e.g., "mp4")
    cross_platform_sharing?: string[]; // Platforms for sharing
    watermark_applied?: boolean;  // Whether watermark was applied
  };
}
```

### Example Draft Object

```json
{
  "id": "draft_1704067200000_1234",
  "videoPath": "/documents/DraftVideos/draft_1704067200000_1234.mp4",
  "thumbnailPath": "/documents/DraftThumbnails/draft_thumb_draft_1704067200000_1234.jpg",
  "caption": "My awesome video",
  "hashtags": ["fun", "viral"],
  "privacy": "Everyone",
  "allowComments": true,
  "category": "entertainment",
  "createdAt": "2024-01-01T12:00:00.000Z",
  "updatedAt": "2024-01-01T12:00:00.000Z",
  "status": "draft",
  "isSharedWithConnections": false,
  "sharedConnections": [],
  "metadata": {
    "fileSize": 15728640,
    "duration": 30.0,
    "resolution": "1080x1920",
    "format": "mp4",
    "cross_platform_sharing": ["tiktok", "instagram"],
    "watermark_applied": true
  }
}
```

## Storage Mechanism

### File Storage

**Mobile App (Flutter)**:
- Videos: `{documentsDir}/DraftVideos/{draftId}.mp4`
- Thumbnails: `{documentsDir}/DraftThumbnails/draft_thumb_{draftId}.jpg`

**Web Implementation**:
- Use **IndexedDB** for storing video blobs
- Use **Blob URLs** for video and thumbnail references
- Store file paths as IndexedDB keys

### Metadata Storage

**Mobile App (Flutter)**:
- Uses `SharedPreferences` (key-value storage)
- Key: `"draftVideos"`
- Value: JSON array of draft objects

**Web Implementation**:
- Use **IndexedDB** with a `drafts` object store
- Store drafts as JSON objects
- Index by `id` and `createdAt` for efficient queries

### Storage Structure (Web)

```typescript
// IndexedDB Schema
interface DraftStore {
  name: "drafts";
  keyPath: "id";
  indexes: [
    { name: "createdAt", unique: false },
    { name: "status", unique: false }
  ];
}

// Video Blob Storage
interface VideoBlobStore {
  name: "draftVideos";
  keyPath: "draftId";
}

// Thumbnail Blob Storage
interface ThumbnailBlobStore {
  name: "draftThumbnails";
  keyPath: "draftId";
}
```

## Service API

### LocalDraftService

The service manages all draft operations. Here's the API interface:

#### `saveDraft(params)`

Saves a video as a draft.

**Parameters:**
```typescript
interface SaveDraftParams {
  videoFile: File | Blob;        // Video file to save
  caption: string;                // Video caption
  hashtags: string[];             // Array of hashtags
  privacy: string;                 // Privacy setting
  allowComments: boolean;          // Allow comments flag
  category?: string;               // Optional category
  additionalMetadata?: Record<string, any>; // Additional metadata
}
```

**Returns:** `Promise<boolean>` - Success status

**Process:**
1. Generate unique draft ID: `draft_{timestamp}_{random4digits}`
2. Save video file to local storage (IndexedDB for web)
3. Generate thumbnail from video (at 30% of video duration or 1 second)
4. Save thumbnail to local storage
5. Create draft object with all metadata
6. Save draft metadata to IndexedDB/SharedPreferences
7. Return success status

**Example:**
```typescript
const success = await localDraftService.saveDraft({
  videoFile: videoBlob,
  caption: "My video",
  hashtags: ["fun", "viral"],
  privacy: "Everyone",
  allowComments: true,
  category: "entertainment",
  additionalMetadata: {
    cross_platform_sharing: ["tiktok", "instagram"],
    watermark_applied: true
  }
});
```

#### `getAllDrafts()`

Retrieves all drafts for the current user.

**Returns:** `Promise<Draft[]>` - Array of draft objects, sorted by creation date (newest first)

**Process:**
1. Load all drafts from IndexedDB/SharedPreferences
2. Validate thumbnail existence (regenerate if missing)
3. Sort by `createdAt` descending
4. Return sorted array

**Example:**
```typescript
const drafts = await localDraftService.getAllDrafts();
// Returns: Draft[] sorted by newest first
```

#### `deleteDraft(draftId)`

Deletes a draft and its associated files.

**Parameters:**
- `draftId: string` - ID of draft to delete

**Returns:** `Promise<boolean>` - Success status

**Process:**
1. Find draft by ID
2. Delete video file from storage
3. Delete thumbnail file from storage
4. Remove draft from IndexedDB/SharedPreferences
5. Return success status

**Example:**
```typescript
const success = await localDraftService.deleteDraft("draft_1704067200000_1234");
```

#### `publishDraft(draftId)`

Publishes a draft (converts to published video).

**Parameters:**
- `draftId: string` - ID of draft to publish

**Returns:** `Promise<boolean>` - Success status

**Note:** This method should integrate with your video upload service to:
1. Upload video to cloud storage
2. Create video document in database
3. Add to appropriate feeds
4. Remove from local drafts

## UI Flow

### 1. Publish Video View

**Location:** `VideoPublishingScreen`

**User Action:** User taps "Save as Draft" button

**Flow:**
```typescript
async function saveAsDraft() {
  // 1. Show loading state
  setIsUploading(true);
  
  // 2. Call LocalDraftService
  const success = await localDraftService.saveDraft({
    videoFile: videoFile,
    caption: caption,
    hashtags: hashtags,
    privacy: selectedPrivacy,
    allowComments: allowComments,
    category: selectedCategory,
    additionalMetadata: {
      cross_platform_sharing: selectedPlatforms,
      watermark_applied: shouldApplyWatermark(selectedPlatforms)
    }
  });
  
  // 3. Handle result
  if (success) {
    showSnackbar("Video saved as draft 📝");
    navigateToHome();
  } else {
    showErrorDialog("Failed to save draft");
  }
  
  setIsUploading(false);
}
```

### 2. Profile View

**Location:** `ProfileVideoFeedView`

**Display Logic:**
- Only show drafts if viewing **own profile**
- Load drafts using `LocalDraftService.getAllDrafts()`
- Display drafts as a **combined thumbnail** at position 0
- Show published videos after drafts

**Implementation:**
```typescript
function ProfileVideoFeed({ userId, videos }) {
  const [drafts, setDrafts] = useState<Draft[]>([]);
  const isViewingOwnProfile = currentUser?.uid === userId;
  
  useEffect(() => {
    if (isViewingOwnProfile) {
      loadDrafts();
    }
  }, [isViewingOwnProfile]);
  
  async function loadDrafts() {
    const allDrafts = await localDraftService.getAllDrafts();
    setDrafts(allDrafts);
  }
  
  if (isViewingOwnProfile && drafts.length > 0) {
    return buildVideoGridWithDrafts(videos, drafts);
  } else {
    return buildVideoGridWithoutDrafts(videos);
  }
}
```

### 3. Drafts Grid Display

**Combined Drafts Thumbnail:**
- Shows at **index 0** in the grid
- Uses first draft's thumbnail as preview
- Displays orange badge with draft count (e.g., "3 Drafts")
- Tapping opens `DraftsSheetView`

**Grid Layout:**
```
[Combined Drafts Thumbnail] [Published Video 1] [Published Video 2]
[Published Video 3]         [Published Video 4] [Published Video 5]
```

**Implementation:**
```typescript
function buildVideoGridWithDrafts(videos: Video[], drafts: Draft[]) {
  const itemCount = videos.length + (drafts.length > 0 ? 1 : 0);
  
  return (
    <GridView
      itemCount={itemCount}
      itemBuilder={(index) => {
        // Show drafts at index 0
        if (drafts.length > 0 && index === 0) {
          return buildCombinedDraftsThumbnail(drafts);
        }
        
        // Show published videos after drafts
        const videoIndex = drafts.length > 0 ? index - 1 : index;
        return buildVideoCard(videos[videoIndex]);
      }}
    />
  );
}

function buildCombinedDraftsThumbnail(drafts: Draft[]) {
  const firstDraft = drafts[0];
  
  return (
    <Stack>
      <Thumbnail
        src={firstDraft.thumbnailPath}
        onClick={() => openDraftsSheet(drafts)}
      />
      <Badge position="top-right" color="orange">
        {drafts.length} Draft{drafts.length > 1 ? 's' : ''}
      </Badge>
    </Stack>
  );
}
```

### 4. Drafts Sheet View

**Location:** `DraftsSheetView`

**Features:**
- Displays all drafts in a grid/list
- Allows editing drafts
- Allows deleting drafts
- Navigates back to profile after actions

**Implementation:**
```typescript
function DraftsSheetView({ drafts, onDraftTap, onDelete }) {
  async function handleDelete(draft: Draft) {
    const confirmed = await showConfirmDialog(
      "Delete Draft",
      "Are you sure you want to delete this draft?"
    );
    
    if (confirmed) {
      const success = await localDraftService.deleteDraft(draft.id);
      if (success) {
        onDelete(draft);
        showSnackbar(`Deleted draft: ${draft.caption || 'Untitled Draft'}`);
        
        // Close if no drafts left
        if (drafts.length === 1) {
          navigateBack();
        }
      }
    }
  }
  
  return (
    <Grid>
      {drafts.map(draft => (
        <DraftCard
          key={draft.id}
          draft={draft}
          onTap={() => onDraftTap(draft)}
          onDelete={() => handleDelete(draft)}
        />
      ))}
    </Grid>
  );
}
```

## Implementation Guide

### Web Implementation Steps

#### 1. Set Up IndexedDB

```typescript
// Initialize IndexedDB
async function initDraftDB(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open('DraftDB', 1);
    
    request.onupgradeneeded = (event) => {
      const db = (event.target as IDBOpenDBRequest).result;
      
      // Drafts metadata store
      if (!db.objectStoreNames.contains('drafts')) {
        const draftStore = db.createObjectStore('drafts', { keyPath: 'id' });
        draftStore.createIndex('createdAt', 'createdAt', { unique: false });
        draftStore.createIndex('status', 'status', { unique: false });
      }
      
      // Video blobs store
      if (!db.objectStoreNames.contains('draftVideos')) {
        db.createObjectStore('draftVideos', { keyPath: 'draftId' });
      }
      
      // Thumbnail blobs store
      if (!db.objectStoreNames.contains('draftThumbnails')) {
        db.createObjectStore('draftThumbnails', { keyPath: 'draftId' });
      }
    };
    
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}
```

#### 2. Implement LocalDraftService (Web)

```typescript
class LocalDraftService {
  private db: IDBDatabase | null = null;
  
  async init() {
    this.db = await initDraftDB();
  }
  
  async saveDraft(params: SaveDraftParams): Promise<boolean> {
    try {
      // 1. Generate draft ID
      const draftId = this.generateDraftId();
      
      // 2. Save video blob
      await this.saveVideoBlob(draftId, params.videoFile);
      
      // 3. Generate and save thumbnail
      const thumbnailBlob = await this.generateThumbnail(params.videoFile);
      await this.saveThumbnailBlob(draftId, thumbnailBlob);
      
      // 4. Create draft object
      const draft: Draft = {
        id: draftId,
        videoPath: `blob:draftVideos/${draftId}`, // Blob URL reference
        thumbnailPath: `blob:draftThumbnails/${draftId}`, // Blob URL reference
        caption: params.caption,
        hashtags: params.hashtags,
        privacy: params.privacy,
        allowComments: params.allowComments,
        category: params.category || 'general',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        status: 'draft',
        isSharedWithConnections: false,
        sharedConnections: [],
        metadata: {
          fileSize: params.videoFile.size,
          duration: await this.getVideoDuration(params.videoFile),
          resolution: '1080x1920',
          format: 'mp4',
          ...params.additionalMetadata
        }
      };
      
      // 5. Save draft metadata
      await this.saveDraftMetadata(draft);
      
      return true;
    } catch (error) {
      console.error('Error saving draft:', error);
      return false;
    }
  }
  
  async getAllDrafts(): Promise<Draft[]> {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        resolve([]);
        return;
      }
      
      const transaction = this.db.transaction(['drafts'], 'readonly');
      const store = transaction.objectStore('drafts');
      const index = store.index('createdAt');
      const request = index.getAll();
      
      request.onsuccess = () => {
        const drafts = request.result as Draft[];
        // Sort by createdAt descending (newest first)
        drafts.sort((a, b) => 
          new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
        );
        resolve(drafts);
      };
      
      request.onerror = () => reject(request.error);
    });
  }
  
  async deleteDraft(draftId: string): Promise<boolean> {
    try {
      // Delete video blob
      await this.deleteVideoBlob(draftId);
      
      // Delete thumbnail blob
      await this.deleteThumbnailBlob(draftId);
      
      // Delete draft metadata
      await this.deleteDraftMetadata(draftId);
      
      return true;
    } catch (error) {
      console.error('Error deleting draft:', error);
      return false;
    }
  }
  
  private generateDraftId(): string {
    const timestamp = Date.now();
    const random = Math.floor(Math.random() * 10000).toString().padStart(4, '0');
    return `draft_${timestamp}_${random}`;
  }
  
  private async generateThumbnail(videoFile: File | Blob): Promise<Blob> {
    // Use HTML5 video element to extract frame
    return new Promise((resolve, reject) => {
      const video = document.createElement('video');
      const canvas = document.createElement('canvas');
      const ctx = canvas.getContext('2d');
      
      video.preload = 'metadata';
      video.onloadedmetadata = () => {
        // Seek to 30% of video or 1 second
        const timestamp = Math.max(1000, video.duration * 1000 * 0.3);
        video.currentTime = timestamp / 1000;
      };
      
      video.onseeked = () => {
        canvas.width = 720;
        canvas.height = 1280;
        ctx?.drawImage(video, 0, 0, canvas.width, canvas.height);
        
        canvas.toBlob((blob) => {
          if (blob) {
            resolve(blob);
          } else {
            reject(new Error('Failed to generate thumbnail'));
          }
        }, 'image/jpeg', 0.95);
      };
      
      video.onerror = () => reject(new Error('Video load error'));
      video.src = URL.createObjectURL(videoFile);
    });
  }
  
  // ... additional helper methods
}
```

#### 3. Thumbnail Generation (Web)

For web, use HTML5 video element to extract frames:

```typescript
async function generateThumbnail(
  videoFile: File | Blob,
  timestamp?: number
): Promise<Blob> {
  return new Promise((resolve, reject) => {
    const video = document.createElement('video');
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');
    
    video.preload = 'metadata';
    video.muted = true;
    video.playsInline = true;
    
    video.onloadedmetadata = () => {
      // Use 30% of duration or 1 second, whichever is greater
      const seekTime = timestamp ?? Math.max(1, video.duration * 0.3);
      video.currentTime = seekTime;
    };
    
    video.onseeked = () => {
      // Set canvas to high quality (720x1280 for 9:16 aspect ratio)
      canvas.width = 720;
      canvas.height = 1280;
      
      // Draw video frame to canvas
      ctx?.drawImage(video, 0, 0, canvas.width, canvas.height);
      
      // Convert to JPEG blob with high quality
      canvas.toBlob(
        (blob) => {
          if (blob) {
            resolve(blob);
          } else {
            reject(new Error('Failed to generate thumbnail'));
          }
        },
        'image/jpeg',
        0.95 // 95% quality
      );
    };
    
    video.onerror = () => reject(new Error('Video load error'));
    video.src = URL.createObjectURL(videoFile);
  });
}
```

#### 4. Profile View Integration

```typescript
function ProfileVideoFeed({ userId }: { userId: string }) {
  const [drafts, setDrafts] = useState<Draft[]>([]);
  const [videos, setVideos] = useState<Video[]>([]);
  const currentUser = useCurrentUser();
  const isViewingOwnProfile = currentUser?.id === userId;
  
  useEffect(() => {
    loadVideos();
    if (isViewingOwnProfile) {
      loadDrafts();
    }
  }, [userId, isViewingOwnProfile]);
  
  async function loadDrafts() {
    const allDrafts = await localDraftService.getAllDrafts();
    setDrafts(allDrafts);
  }
  
  function buildVideoGrid() {
    if (isViewingOwnProfile && drafts.length > 0) {
      return buildVideoGridWithDrafts(videos, drafts);
    } else {
      return buildVideoGridWithoutDrafts(videos);
    }
  }
  
  return (
    <div className="video-grid">
      {buildVideoGrid()}
    </div>
  );
}
```

### Key Considerations for Web

1. **Blob URLs**: Use `URL.createObjectURL()` for video/thumbnail references
2. **Memory Management**: Revoke blob URLs when no longer needed
3. **Storage Limits**: IndexedDB has storage limits (check quota)
4. **Thumbnail Quality**: Use 720x1280 resolution for high quality
5. **Video Duration**: Extract from video metadata before generating thumbnail
6. **Error Handling**: Handle cases where video/thumbnail generation fails
7. **Privacy**: Ensure drafts are never synced to server unless explicitly published

### Testing Checklist

- [ ] Save draft with all metadata fields
- [ ] Load all drafts (sorted by newest first)
- [ ] Display drafts in profile view (own profile only)
- [ ] Combined drafts thumbnail shows correct count
- [ ] Delete draft removes files and metadata
- [ ] Thumbnail regeneration for missing thumbnails
- [ ] Draft persistence across page refreshes
- [ ] Error handling for corrupted drafts
- [ ] Storage quota exceeded handling

## Summary

The draft saving flow consists of:

1. **Save**: User saves video → `LocalDraftService.saveDraft()` → Stores video, thumbnail, and metadata locally
2. **Display**: Profile view loads drafts → Shows combined thumbnail at position 0 → Only visible to creator
3. **Manage**: User can view, edit, or delete drafts → Changes persist locally

All drafts are stored **locally** and never synced to the server unless explicitly published by the user.

