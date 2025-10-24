# 🔥 MIXED VIDEO FEED ALGORITHM

## 📊 **OVERVIEW**

The Categories video layout now features a **sophisticated mixed feed algorithm** that combines **new videos** and **trending videos** to create an engaging, TikTok-style discovery experience. Users see a perfect blend of fresh content and proven popular videos.

---

## 🎯 **ALGORITHM PRINCIPLES**

### **Mixed Feed Composition**
- **60% Recent Videos**: Videos uploaded in the last 7 days
- **40% Trending Videos**: High-engagement videos from any time
- **Intelligent Sorting**: New videos with high engagement get priority
- **Duplicate Prevention**: Same video won't appear twice

### **Visual Indicators**
- **🆕 NEW Badge**: Green badge for videos uploaded in last 7 days
- **🔥 HOT Badge**: Pink badge for high-engagement videos
- **❤️ Score Badge**: Engagement score for videos with score > 50

---

## 🧮 **ALGORITHM BREAKDOWN**

### **1. Recent Videos Query (60% of feed)**
```dart
Query recentQuery = FirebaseFirestore.instance
  .collection('videos')
  .where('status', isEqualTo: 'published')
  .where('privacy', isEqualTo: 'Everyone')
  .where('category', isEqualTo: categoryId)
  .where('createdAt', isGreaterThan: sevenDaysAgo)  // Last 7 days
  .orderBy('createdAt', descending: true)           // Newest first
  .limit((_videosPerPage * 0.6).round());          // 60% of feed
```

### **2. Trending Videos Query (40% of feed)**
```dart
Query trendingQuery = FirebaseFirestore.instance
  .collection('videos')
  .where('status', isEqualTo: 'published')
  .where('privacy', isEqualTo: 'Everyone')
  .where('category', isEqualTo: categoryId)
  .orderBy('likes', descending: true)              // High engagement first
  .limit((_videosPerPage * 0.4).round());          // 40% of feed
```

### **3. Intelligent Mixing Algorithm**
```dart
// Step 1: Remove duplicates (recent videos take priority)
final allVideos = <String, Map<String, dynamic>>{};

// Add recent videos first
for (final video in recentVideos) {
  allVideos[video['docId']] = video;
}

// Add trending videos (only if not already added)
for (final video in trendingVideos) {
  if (!allVideos.containsKey(video['docId'])) {
    allVideos[video['docId']] = video;
  }
}

// Step 2: Sort by intelligent algorithm
mixedVideos.sort((a, b) {
  final aScore = a['trendingScore'] as double;
  final bScore = b['trendingScore'] as double;
  final aIsNew = a['isNew'] as bool;
  final bIsNew = b['isNew'] as bool;
  
  // New videos with high engagement get highest priority
  if (aIsNew && !bIsNew && aScore > 100) return -1;
  if (!aIsNew && bIsNew && bScore > 100) return 1;
  
  // Then sort by trending score
  return bScore.compareTo(aScore);
});
```

---

## 📊 **TRENDING SCORE CALCULATION**

### **Video Performance Metrics**
```dart
double _calculateVideoTrendingScore(Map<String, dynamic> videoData, DateTime now) {
  // Base metrics
  final views = (videoData['views'] ?? 0) as int;
  final likes = (videoData['likes'] ?? 0) as int;
  final comments = (videoData['comments'] ?? 0) as int;
  final shares = (videoData['shares'] ?? 0) as int;
  
  // Engagement rate (quality over quantity)
  final engagementRate = views > 0 ? (likes + comments + shares) / views : 0.0;
  
  // Recency boost (more recent = higher score)
  final createdAt = videoData['createdAt'] as Timestamp?;
  double recencyBoost = 1.0;
  if (createdAt != null) {
    final hoursAgo = now.difference(createdAt.toDate()).inHours;
    recencyBoost = 1.0 + (24.0 / (hoursAgo + 1)); // Boost decreases over time
  }
  
  // Calculate final score
  final baseScore = (views * 0.1) + (likes * 0.3) + (comments * 0.5) + (shares * 0.7);
  final engagementMultiplier = 1.0 + (engagementRate * 2.0);
  final finalScore = baseScore * engagementMultiplier * recencyBoost;
  
  return finalScore;
}
```

### **Score Weights**
- **Views**: 0.1x (reach indicator)
- **Likes**: 0.3x (basic engagement)
- **Comments**: 0.5x (high engagement)
- **Shares**: 0.7x (viral potential)
- **Engagement Rate**: 2.0x multiplier
- **Recency Boost**: 1.0x to 25.0x (decreases over time)

---

## 🎨 **VISUAL INDICATORS**

### **1. NEW Video Badge (Top-Left)**
```dart
// Green badge for videos uploaded in last 7 days
if (video['isNew'] == true)
  Positioned(
    top: 8,
    left: 8,
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50), // Green
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.fiber_new, color: Colors.white, size: 12),
          Text('NEW', style: TextStyle(color: Colors.white, fontSize: 10)),
        ],
      ),
    ),
  ),
```

### **2. HOT Video Badge (Top-Right)**
```dart
// Pink badge for high-engagement videos
if (video['isTrending'] == true)
  Positioned(
    top: 8,
    right: 8,
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFF6CAB), // Pink
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.trending_up, color: Colors.white, size: 12),
          Text('HOT', style: TextStyle(color: Colors.white, fontSize: 10)),
        ],
      ),
    ),
  ),
```

### **3. Engagement Score Badge (Bottom-Left)**
```dart
// Score badge for videos with trending score > 50
if (video['trendingScore'] > 50)
  Positioned(
    bottom: 8,
    left: 8,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(Icons.favorite, color: Color(0xFFFF6CAB), size: 12),
          Text('${trendingScore.round()}', style: TextStyle(color: Colors.white)),
        ],
      ),
    ),
  ),
```

---

## 🔄 **REAL-TIME UPDATE MECHANISM**

### **1. New Video Detection**
```dart
// Listen for new video uploads
FirebaseFirestore.instance
  .collection('videos')
  .where('createdAt', isGreaterThan: lastHour)
  .snapshots()
  .listen((snapshot) {
    if (snapshot.docs.isNotEmpty) {
      // Refresh trending creators and category videos
      loadTrendingCreators();
    }
  });
```

### **2. Category Selection Refresh**
```dart
void _onCategorySelected(String? categoryId) {
  setState(() {
    _selectedCategory = categoryId;
    _currentVideoPage = 0;  // Reset pagination
  });
  
  // Clear cache and load fresh mixed videos
  _resetPaginationForCategory(categoryId);
}
```

### **3. Mixed Feed Loading**
```dart
Future<List<Map<String, dynamic>>> _loadMixedCategoryVideos(
    String categoryId, DocumentSnapshot? startAfter) async {
  
  // Step 1: Load recent videos (60%)
  final recentVideos = await _loadRecentVideos(categoryId, startAfter);
  
  // Step 2: Load trending videos (40%)
  final trendingVideos = await _loadTrendingVideos(categoryId, startAfter);
  
  // Step 3: Mix and sort intelligently
  final mixedVideos = _mixAndSortVideos(recentVideos, trendingVideos);
  
  // Step 4: Apply pagination
  return _applyPagination(mixedVideos, startAfter);
}
```

---

## 📱 **USER EXPERIENCE**

### **What Users See**
1. **🆕 Fresh Content**: New videos from last 7 days with "NEW" badges
2. **🔥 Proven Content**: High-engagement videos with "HOT" badges
3. **📊 Engagement Scores**: Numerical scores for trending videos
4. **🎯 Perfect Mix**: 60% new + 40% trending for optimal discovery

### **Visual Hierarchy**
1. **New + High Engagement**: Top priority (NEW badge + high score)
2. **New + Low Engagement**: Second priority (NEW badge only)
3. **Old + High Engagement**: Third priority (HOT badge + high score)
4. **Old + Low Engagement**: Lowest priority (no badges)

---

## 🚀 **BENEFITS**

### **For Users**
1. **🎯 Best of Both Worlds**: Fresh content + proven quality
2. **⚡ Immediate Gratification**: See new uploads quickly
3. **📈 Quality Discovery**: Find videos that others love
4. **🔄 Dynamic Feed**: Always changing and engaging

### **For Creators**
1. **📊 Fair Exposure**: New creators get visibility
2. **🏆 Quality Rewards**: High-engagement videos get priority
3. **⚡ Real-time Recognition**: Immediate visibility for trending content
4. **🎯 Category Targeting**: Videos appear in relevant categories

### **For Platform**
1. **📈 Higher Engagement**: Mixed feed increases user retention
2. **🔄 Fresh Content**: Always new videos to discover
3. **📊 Data-Driven**: Algorithm based on actual performance
4. **⚡ Real-time Updates**: Immediate response to new uploads

---

## 🔧 **TECHNICAL IMPLEMENTATION**

### **Key Methods**
1. **`_loadMixedCategoryVideos()`**: Main mixed feed loader
2. **`_loadRecentVideos()`**: Loads recent videos (60%)
3. **`_loadTrendingVideos()`**: Loads trending videos (40%)
4. **`_mixAndSortVideos()`**: Intelligent mixing algorithm
5. **`_calculateVideoTrendingScore()`**: Performance scoring

### **Data Flow**
```
1. User selects category → Clear cache → Reset pagination
2. Load recent videos (last 7 days) → 60% of feed
3. Load trending videos (high engagement) → 40% of feed
4. Remove duplicates → Recent videos take priority
5. Sort by intelligent algorithm → New + high engagement first
6. Apply pagination → Return mixed results
7. Display with visual indicators → NEW, HOT, Score badges
```

---

## 📊 **PERFORMANCE METRICS**

### **Feed Composition Tracking**
- **Recent Videos**: Count and percentage in feed
- **Trending Videos**: Count and percentage in feed
- **Duplicate Removal**: Efficiency of deduplication
- **Sorting Performance**: Algorithm execution time

### **User Engagement Metrics**
- **Click-through Rate**: By video type (new vs trending)
- **Time Spent**: On new vs trending videos
- **Category Performance**: Which categories perform best
- **Badge Effectiveness**: Impact of visual indicators

---

## 🎯 **FUTURE ENHANCEMENTS**

### **Phase 1: Personalization**
- **User Interest Matching**: Based on watched categories
- **Behavioral Analysis**: User interaction patterns
- **A/B Testing**: Different mix ratios (50/50, 70/30, etc.)

### **Phase 2: Advanced Algorithms**
- **Machine Learning**: Predict trending potential
- **Sentiment Analysis**: Comment sentiment scoring
- **Completion Rate**: Video watch time percentage
- **Retention Rate**: User return after watching

### **Phase 3: Real-time Optimization**
- **Dynamic Mix Ratios**: Adjust based on user behavior
- **Category-specific Algorithms**: Different rules per category
- **Time-based Adjustments**: Different mixes by time of day
- **Seasonal Trends**: Adjust for trending topics

---

## ✅ **SUMMARY**

The Mixed Video Feed Algorithm creates a **perfect balance between discovery and quality** by:

- 🎯 **Mixing 60% new videos with 40% trending videos**
- ⚡ **Prioritizing new videos with high engagement**
- 🎨 **Using visual indicators (NEW, HOT, Score badges)**
- 🔄 **Updating in real-time with new uploads**
- 📊 **Calculating trending scores based on engagement**
- 🚀 **Creating an engaging, TikTok-style discovery experience**

This ensures users always see **fresh content** while also discovering **proven quality videos** that others love! 🚀✨
