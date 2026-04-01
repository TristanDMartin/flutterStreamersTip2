# Mobile App Video Upload Guide

## Overview

Video upload in the Flutter app follows the website flow with a multi-method thumbnail generation system that ensures thumbnails are always generated.

## Implemented Flow

1. User selects video → moderation check
2. Generate video ID: `{timestamp}_{random}`
3. Upload video: `videos/{userId}/{videoId}.mp4`
4. Generate thumbnail (4-method fallback cascade)
5. Upload thumbnail: `thumbnails/{videoId}.jpg`
6. Create Firestore document in `videos/{videoId}`
7. Add to feeds, user profile, post count

## Thumbnail Generation (4 methods)

`VideoProcessingService.generateThumbnailWithFallbacks` tries in order:

1. **Primary**: 10% of duration (clamped 0–1s) – best for most videos
2. **Alternative**: 500ms, 1s, 2s – different time points
3. **Fallback**: 0ms – start of video
4. **Aggressive**: 0, 100, 500, 1000, 2000 ms – last attempt before placeholder
5. **Placeholder**: Dark grey with play icon if all extraction fails

## Category Detection

`VideoUploadService._detectCategoryFromContent` infers category from caption + hashtags when not explicitly set. Keywords map to: Gaming, Art, Music, Tech, Sports, Food, Travel, Fashion, Comedy, Education, Fitness, Lifestyle; else `Other`.

## Key Files

- `lib/services/video_upload_service.dart` – Upload flow, category detection
- `lib/services/video_processing_service.dart` – Thumbnail cascade

## Dependencies

- `video_thumbnail` – Frame extraction
- `image` – Resize/crop
- `path_provider` – Temp dir
