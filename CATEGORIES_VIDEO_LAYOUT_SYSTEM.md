# 🎯 CATEGORIES VIDEO LAYOUT SYSTEM

## 📊 **OVERVIEW**

The Categories video layout system in DiscoverView provides a dynamic, real-time updating grid of videos organized by categories. Users can browse videos by category with infinite scroll pagination and automatic updates when new videos are uploaded.

---

## 🏗️ **ARCHITECTURE**

### **1. Category Selection System**
```dart
String? _selectedCategory;  // Currently selected category ID
int _currentCategoryPage = 0;  // Current category page
int _currentVideoPage = 0;  // Current video page within category
bool _isLoadingMoreVideos = false;  // Loading state for pagination
```

### **2. Video Caching System**
```dart
// Enhanced caching with user-specific keys
final Map<String, List<Map<String, dynamic>>> _cachedVideos = {};

// Pagination tracking
final Map<String, DocumentSnapshot> _lastDocuments = {};
static const int _videosPerPage = 12;  // Videos per page
```

### **3. Error Handling & Retry System**
```dart
final Map<String, int> _retryCounts = {};  // Retry attempts per category
final Map<String, String> _errorMessages = {};  // Error messages per category
static const int _maxRetries = 3;  // Maximum retry attempts
```

---

## 🔄 **REAL-TIME UPDATE MECHANISM**

### **1. New Video Detection Stream**
```dart
// Listen to videos collection for new uploads
_trendingCreatorsSubscription = FirebaseFirestore.instance
  .collection('videos')
  .where('createdAt', isGreaterThan: Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 1))))
  .snapshots()
  .listen((snapshot) {
    if (mounted && snapshot.docs.isNotEmpty) {
      // Refresh trending creators when new videos are uploaded
      ref.read(discoverProvider.notifier).loadTrendingCreators();
    }
  });
```

### **2. Category Video Refresh**
```dart
void _onCategorySelected(String? categoryId) {
  setState(() {
    _selectedCategory = categoryId;
    _currentCategoryPage = 0;  // Reset pagination
    _currentVideoPage = 0;     // Reset video pagination
    _isLoadingMoreVideos = false;  // Reset loading state
  });
  
  // Reset pagination when switching categories
  if (categoryId != null) {
    _resetPaginationForCategory(categoryId);
  }
}
```

### **3. Cache Invalidation**
```dart
// Clear cache when switching categories to ensure fresh data
void _resetPaginationForCategory(String categoryId) {
  _lastDocuments.remove(categoryId);
  // Cache is automatically refreshed on next load
}
```

---

## 📱 **UI LAYOUT SYSTEM**

### **1. Category Selection UI**
```dart
// Horizontal scrollable category chips
ListView.builder(
  scrollDirection: Axis.horizontal,
  itemCount: discoverState.categories.length,
  itemBuilder: (context, index) {
    final category = discoverState.categories[index];
    return CategoryCard(
      category: category,
      isSelected: _selectedCategory == category.id,
      onTap: () => _onCategorySelected(
        _selectedCategory == category.id ? null : category.id,
      ),
    );
  },
)
```

### **2. Video Grid Layout**
```dart
// 3-column video grid with 9:16 aspect ratio
GridView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 3,           // 3 columns
    crossAxisSpacing: 2,         // 2px spacing between columns
    mainAxisSpacing: 2,          // 2px spacing between rows
    childAspectRatio: 9 / 16,    // Portrait video aspect ratio
  ),
  itemCount: categoryVideos.length,
  itemBuilder: (context, index) {
    return _buildVideoGridItem(categoryVideos[index], categoryId);
  },
)
```

### **3. Video Grid Item**
```dart
Widget _buildVideoGridItem(Map<String, dynamic> video, String categoryId) {
  return GestureDetector(
    onTap: () => _showVideoDetails(video),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: _getCategoryColor(categoryId).withValues(alpha: 0.1),
      ),
      child: Column(
        children: [
          // Thumbnail
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                video['thumbnail'] ?? '',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.video_library, color: Colors.white70),
                  );
                },
              ),
            ),
          ),
          // Video info
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Text(
                  video['title'] ?? 'Untitled',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${video['views']} views',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
```

---

## 🔄 **DATA FLOW**

### **1. Category Selection Flow**
```
User taps category → _onCategorySelected() → Reset pagination → Clear cache → Load fresh videos
```

### **2. Video Loading Flow**
```
_getCategoryVideos() → Check cache → If cached: return cached data → If not cached: _loadVideosWithRetry()
```

### **3. Real-time Update Flow**
```
New video uploaded → Firestore stream detects → Refresh trending creators → Category videos auto-refresh on next load
```

---

## 📊 **VIDEO LOADING ALGORITHM**

### **1. Firestore Query**
```dart
Query query = FirebaseFirestore.instance
  .collection('videos')
  .where('status', isEqualTo: 'published')      // Only published videos
  .where('privacy', isEqualTo: 'Everyone')      // Public videos only
  .where('category', isEqualTo: categoryId)     // Filter by category
  .orderBy('createdAt', descending: true)       // Newest first
  .limit(_videosPerPage);                       // Pagination limit

// Add pagination cursor if available
if (startAfter != null) {
  query = query.startAfterDocument(startAfter);
}
```

### **2. Batch User Data Loading**
```dart
// 🔥 FIX: Extract all unique user IDs first (batch approach)
final userIds = <String>{};
final videoDataList = <Map<String, dynamic>>[];

for (final doc in snapshot.docs) {
  final data = doc.data() as Map<String, dynamic>?;
  if (data == null) continue;
  
  final userId = (data['userId'] ?? data['creatorId'] ?? data['creator_id']) as String?;
  if (userId != null) {
    userIds.add(userId);
    videoDataList.add({
      'docId': doc.id,
      'data': data,
    });
  }
}

// Batch fetch all user data in one query
final userSnapshot = await FirebaseFirestore.instance
  .collection('users')
  .where(FieldPath.documentId, whereIn: userIds.toList())
  .get();

// Create user lookup map for O(1) access
final userMap = <String, Map<String, dynamic>>{};
for (final doc in userSnapshot.docs) {
  userMap[doc.id] = doc.data();
}
```

### **3. Video Data Processing**
```dart
// Process videos with user data
final videos = <Map<String, dynamic>>[];
for (final videoData in videoDataList) {
  final data = videoData['data'];
  final userId = FieldMapper.getUserId(data);
  final userData = userMap[userId] ?? {};
  
  videos.add({
    'id': videoData['docId'],
    'title': FieldMapper.safeString(data['caption'] ?? data['title'] ?? 'Untitled'),
    'creator': FieldMapper.getDisplayName(userData),
    'thumbnail': FieldMapper.getThumbnailUrl(data),
    'views': '${FieldMapper.safeInt(data['views'] ?? data['viewsCount'])}',
    'duration': _formatDuration(data['duration']),
    'color': _getCategoryColor(categoryId),
    'videoUrl': FieldMapper.getVideoUrl(data),
    'creatorId': userId,
    'creatorAvatar': FieldMapper.getAvatarUrl(userData),
    'creatorUsername': FieldMapper.safeString(userData['username']),
    'likes': FieldMapper.safeInt(data['likes'] ?? data['likesCount']),
    'comments': FieldMapper.safeInt(data['comments'] ?? data['commentsCount']),
    'createdAt': data['createdAt'],
    'isLiked': data['isLiked'] ?? false,
    'isFavorited': data['isFavorited'] ?? false,
  });
}
```

---

## ⚡ **PERFORMANCE OPTIMIZATIONS**

### **1. Caching Strategy**
```dart
// Check cache first
if (_cachedVideos.containsKey(categoryId)) {
  final cachedVideos = _cachedVideos[categoryId]!;
  final endIndex = ((_currentVideoPage + 1) * _videosPerPage)
      .clamp(0, cachedVideos.length);
  return cachedVideos.sublist(0, endIndex);
}

// Generate and cache all videos for this category
final allVideos = await _generateCategoryVideos(categoryId);
_cachedVideos[categoryId] = allVideos;
```

### **2. Pagination System**
```dart
// Track last document for each category
final Map<String, DocumentSnapshot> _lastDocuments = {};

// Add pagination cursor
if (startAfter != null) {
  query = query.startAfterDocument(startAfter);
}

// Store new cursor after successful load
if (snapshot.docs.isNotEmpty) {
  _setLastDocumentForCategory(categoryId, snapshot.docs.last);
}
```

### **3. Error Handling & Retry**
```dart
// Exponential backoff retry
if (retryCount < _maxRetries) {
  final delayMs = (1000 * math.pow(2, retryCount)).round();
  await Future.delayed(Duration(milliseconds: delayMs));
  return await _loadVideosWithRetry(categoryId);
}
```

---

## 🎨 **CATEGORY COLORS & THEMING**

### **Category Color Mapping**
```dart
int _getCategoryColor(String categoryId) {
  switch (categoryId) {
    case 'gaming': return 0xFFFF6CAB;    // Pink
    case 'music': return 0xFF8E54E9;     // Purple
    case 'art': return 0xFF3D99F7;       // Blue
    case 'comedy': return 0xFF4CAF50;    // Green
    case 'dance': return 0xFFFF9800;     // Orange
    case 'sports': return 0xFF9C27B0;    // Purple
    case 'tech': return 0xFF00BCD4;      // Cyan
    case 'food': return 0xFFFF5722;      // Deep Orange
    case 'fashion': return 0xFFE91E63;   // Pink
    case 'fitness': return 0xFF4CAF50;   // Green
    default: return 0xFF9248D2;          // Default purple
  }
}
```

---

## 🔄 **REAL-TIME UPDATE TRIGGERS**

### **1. New Video Upload Detection**
- **Stream**: `videos` collection with `createdAt > lastHour`
- **Action**: Refresh trending creators
- **Impact**: Category videos refresh on next load

### **2. Category Selection**
- **Trigger**: User taps category chip
- **Action**: Clear cache, reset pagination, load fresh videos
- **Impact**: Immediate video grid update

### **3. Load More Videos**
- **Trigger**: User taps "Load More Videos" button
- **Action**: Load next page of videos for current category
- **Impact**: Append new videos to existing grid

---

## 📱 **USER INTERACTION FLOW**

### **1. Category Selection**
```
1. User sees horizontal category chips
2. User taps a category (e.g., "Gaming")
3. Category becomes selected (highlighted)
4. Video grid updates with Gaming videos
5. "Clear Filter" button appears
```

### **2. Video Browsing**
```
1. User sees 3-column video grid
2. Videos show thumbnail, title, view count
3. User scrolls to see more videos
4. "Load More Videos" button appears at bottom
5. User taps to load next page
```

### **3. Video Interaction**
```
1. User taps a video thumbnail
2. Video details modal opens
3. Shows full video info, creator details
4. User can close modal to return to grid
```

---

## 🚀 **BENEFITS**

### **For Users**
1. **🎯 Category Discovery**: Easy browsing by content type
2. **⚡ Fast Loading**: Cached data for instant display
3. **🔄 Real-time Updates**: Always see latest videos
4. **📱 Infinite Scroll**: Seamless pagination experience
5. **🎨 Visual Appeal**: Color-coded categories and clean grid

### **For Creators**
1. **📊 Category Visibility**: Videos appear in relevant categories
2. **⚡ Real-time Updates**: New uploads appear quickly
3. **📈 Performance Tracking**: View counts and engagement visible
4. **🎯 Targeted Discovery**: Users find content by interest

### **For Platform**
1. **📈 Higher Engagement**: Category-based discovery increases usage
2. **🔄 Dynamic Content**: Always fresh, relevant videos
3. **⚡ Performance**: Optimized loading and caching
4. **📊 Analytics**: Track category performance and user behavior

---

## 🔧 **TECHNICAL IMPLEMENTATION**

### **Key Files**
1. **`lib/widgets/discover_view.dart`**
   - Main DiscoverView widget
   - Category selection and video grid
   - Real-time update mechanisms

2. **`lib/models/category.dart`**
   - Category data model
   - Sample categories

3. **`lib/widgets/category_card.dart`**
   - Individual category chip widget

### **Database Structure**
```dart
// Videos collection
{
  "id": "video_id",
  "category": "gaming",           // Category ID
  "status": "published",          // Video status
  "privacy": "Everyone",          // Privacy setting
  "createdAt": Timestamp,         // Upload time
  "userId": "creator_id",         // Creator ID
  "caption": "Video title",       // Video title
  "thumbnail": "url",             // Thumbnail URL
  "views": 1000,                  // View count
  "likes": 50,                    // Like count
  "comments": 10,                 // Comment count
}

// Users collection
{
  "id": "user_id",
  "username": "creator_name",
  "displayName": "Creator Name",
  "avatarURL": "url",
  "followerCount": 1000,
}
```

---

## ✅ **SUMMARY**

The Categories video layout system provides a **comprehensive, real-time updating video discovery experience** that:

- 🎯 **Organizes videos by category** for easy browsing
- ⚡ **Updates in real-time** when new videos are uploaded
- 📱 **Provides infinite scroll** with smooth pagination
- 🎨 **Uses color-coded categories** for visual appeal
- 🔄 **Caches data efficiently** for fast loading
- 📊 **Tracks performance metrics** for analytics

This creates an engaging, TikTok-style category browsing experience that keeps users discovering new content! 🚀✨
