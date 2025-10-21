# 📊 **STATS VIEW IMPLEMENTATION GUIDE**

## 🎯 **Overview**

This guide provides complete implementation for real-time stats synchronization between the mobile app and website. Both platforms will show identical stats instantly using Firestore real-time listeners.

---

## 📱 **Mobile App Implementation**

### **1. Stats Data Structure**

**Firestore Collections:**
```javascript
// users/{userId} - User document with denormalized counters
{
  "postCount": 15,           // Total published posts
  "followersCount": 42,      // Total followers (denormalized)
  "followingCount": 38,      // Total following (denormalized)
  "connectionsCount": 12,    // Mutual follows (denormalized)
  "lastStatsUpdate": "timestamp"
}

// follows/{followerId}_{followedId} - Follow relationships
{
  "followerId": "user123",
  "followedId": "user456", 
  "createdAt": "timestamp"
}

// videos/{videoId} - Posts for counting
{
  "userId": "user123",
  "status": "published",     // Only published posts count
  "privacy": "everyone",     // Privacy level
  "createdAt": "timestamp"
}
```

### **2. Real-Time Stats Service**

**File: `lib/services/stats_service.dart`**
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class StatsService {
  static final StatsService _instance = StatsService._internal();
  factory StatsService() => _instance;
  StatsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream user stats for real-time updates
  Stream<Map<String, int>> watchUserStats(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return {'posts': 0, 'followers': 0, 'following': 0, 'connections': 0};
      }
      
      final data = snapshot.data()!;
      return {
        'posts': data['postCount'] ?? 0,
        'followers': data['followersCount'] ?? 0,
        'following': data['followingCount'] ?? 0,
        'connections': data['connectionsCount'] ?? 0,
      };
    });
  }

  /// Update denormalized counters when follow/unfollow happens
  Future<void> updateFollowCounters(String userId) async {
    try {
      // Count followers
      final followersQuery = await _firestore
          .collection('follows')
          .where('followedId', isEqualTo: userId)
          .get();
      
      // Count following
      final followingQuery = await _firestore
          .collection('follows')
          .where('followerId', isEqualTo: userId)
          .get();
      
      // Count connections (mutual follows)
      final followingIds = followingQuery.docs
          .map((doc) => doc.data()['followedId'] as String)
          .toSet();
      final followerIds = followersQuery.docs
          .map((doc) => doc.data()['followerId'] as String)
          .toSet();
      final connectionsCount = followingIds.intersection(followerIds).length;

      // Update user document
      await _firestore.collection('users').doc(userId).update({
        'followersCount': followersQuery.docs.length,
        'followingCount': followingQuery.docs.length,
        'connectionsCount': connectionsCount,
        'lastStatsUpdate': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        debugPrint('📊 StatsService: Updated counters for $userId - '
            'Followers: ${followersQuery.docs.length}, '
            'Following: ${followingQuery.docs.length}, '
            'Connections: $connectionsCount');
      }
    } catch (e) {
      debugPrint('❌ StatsService: Error updating counters: $e');
    }
  }
}
```

### **3. Stats Widget Implementation**

**File: `lib/widgets/stats_view.dart`**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/stats_service.dart';

class StatsView extends ConsumerStatefulWidget {
  final String userId;
  final bool showLabels;
  final double fontSize;
  final Color textColor;

  const StatsView({
    Key? key,
    required this.userId,
    this.showLabels = true,
    this.fontSize = 24.0,
    this.textColor = Colors.white,
  }) : super(key: key);

  @override
  ConsumerState<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends ConsumerState<StatsView> {
  final StatsService _statsService = StatsService();
  Map<String, int> _stats = {'posts': 0, 'followers': 0, 'following': 0, 'connections': 0};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    _statsService.watchUserStats(widget.userId).listen(
      (stats) {
        if (mounted) {
          setState(() {
            _stats = stats;
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        debugPrint('❌ StatsView: Error loading stats: $error');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingStats();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatItem('Posts', _stats['posts']!.toString()),
        const SizedBox(width: 54),
        _buildStatItem('Followers', _stats['followers']!.toString()),
        const SizedBox(width: 54),
        _buildStatItem('Following', _stats['following']!.toString()),
        if (widget.showLabels) ...[
          const SizedBox(width: 54),
          _buildStatItem('Connections', _stats['connections']!.toString()),
        ],
      ],
    );
  }

  Widget _buildLoadingStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatItem('Posts', '...'),
        const SizedBox(width: 54),
        _buildStatItem('Followers', '...'),
        const SizedBox(width: 54),
        _buildStatItem('Following', '...'),
        if (widget.showLabels) ...[
          const SizedBox(width: 54),
          _buildStatItem('Connections', '...'),
        ],
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: widget.textColor,
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
        if (widget.showLabels) ...[
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: widget.textColor.withValues(alpha: 0.7),
              fontSize: widget.fontSize * 0.67,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
          ),
        ],
      ],
    );
  }
}
```

### **4. Integration in Profile Views**

**Update `StreamerCardView`:**
```dart
// Replace the existing _buildStatisticsRow() method
Widget _buildStatisticsRow() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
    child: StatsView(
      userId: widget.userId,
      showLabels: true,
      fontSize: 24.0,
      textColor: Colors.white,
    ),
  );
}
```

**Update `ProfileViewOptimized`:**
```dart
// Replace the existing _buildStatsRow() method
Widget _buildStatsRow() {
  return Consumer(
    builder: (context, ref, child) {
      return StatsView(
        userId: widget.user.id,
        showLabels: true,
        fontSize: 24.0,
        textColor: Colors.white,
      );
    },
  );
}
```

---

## 🌐 **Website Implementation**

### **1. HTML Structure**

**File: `stats-view.html`**
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Stats View</title>
    <link rel="stylesheet" href="stats-view.css">
</head>
<body>
    <div class="stats-container">
        <div class="stats-row">
            <div class="stat-item">
                <div class="stat-value" id="posts-count">...</div>
                <div class="stat-label">Posts</div>
            </div>
            <div class="stat-item">
                <div class="stat-value" id="followers-count">...</div>
                <div class="stat-label">Followers</div>
            </div>
            <div class="stat-item">
                <div class="stat-value" id="following-count">...</div>
                <div class="stat-label">Following</div>
            </div>
            <div class="stat-item">
                <div class="stat-value" id="connections-count">...</div>
                <div class="stat-label">Connections</div>
            </div>
        </div>
    </div>

    <!-- Firebase SDK -->
    <script src="https://www.gstatic.com/firebasejs/9.0.0/firebase-app.js"></script>
    <script src="https://www.gstatic.com/firebasejs/9.0.0/firebase-firestore.js"></script>
    <script src="stats-view.js"></script>
</body>
</html>
```

### **2. CSS Styling**

**File: `stats-view.css`**
```css
.stats-container {
    display: flex;
    justify-content: center;
    align-items: center;
    padding: 20px;
    background: linear-gradient(135deg, #1a1a1a 0%, #2d2d2d 100%);
    border-radius: 12px;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
}

.stats-row {
    display: flex;
    align-items: center;
    gap: 54px;
}

.stat-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
}

.stat-value {
    font-size: 24px;
    font-weight: 900;
    color: #ffffff;
    line-height: 1.0;
    margin-bottom: 4px;
}

.stat-label {
    font-size: 16px;
    font-weight: 600;
    color: rgba(255, 255, 255, 0.7);
    line-height: 1.0;
}

/* Loading animation */
.stat-value.loading {
    animation: pulse 1.5s ease-in-out infinite;
}

@keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.5; }
}

/* Responsive design */
@media (max-width: 768px) {
    .stats-row {
        gap: 32px;
    }
    
    .stat-value {
        font-size: 20px;
    }
    
    .stat-label {
        font-size: 14px;
    }
}

@media (max-width: 480px) {
    .stats-row {
        gap: 24px;
    }
    
    .stat-value {
        font-size: 18px;
    }
    
    .stat-label {
        font-size: 12px;
    }
}
```

### **3. JavaScript Implementation**

**File: `stats-view.js`**
```javascript
// Firebase configuration
const firebaseConfig = {
    apiKey: "your-api-key",
    authDomain: "your-project.firebaseapp.com",
    projectId: "your-project-id",
    storageBucket: "your-project.appspot.com",
    messagingSenderId: "123456789",
    appId: "your-app-id"
};

// Initialize Firebase
firebase.initializeApp(firebaseConfig);
const db = firebase.firestore();

class StatsView {
    constructor(userId) {
        this.userId = userId;
        this.stats = {
            posts: 0,
            followers: 0,
            following: 0,
            connections: 0
        };
        this.isLoading = true;
        this.unsubscribe = null;
        
        this.init();
    }

    init() {
        this.setupRealTimeListener();
        this.updateUI();
    }

    setupRealTimeListener() {
        // Listen to user document changes for real-time stats
        this.unsubscribe = db.collection('users').doc(this.userId)
            .onSnapshot((doc) => {
                if (doc.exists) {
                    const data = doc.data();
                    this.stats = {
                        posts: data.postCount || 0,
                        followers: data.followersCount || 0,
                        following: data.followingCount || 0,
                        connections: data.connectionsCount || 0
                    };
                    this.isLoading = false;
                    this.updateUI();
                    
                    console.log('📊 Stats updated:', this.stats);
                } else {
                    console.warn('❌ User document not found:', this.userId);
                    this.isLoading = false;
                    this.updateUI();
                }
            }, (error) => {
                console.error('❌ Stats listener error:', error);
                this.isLoading = false;
                this.updateUI();
            });
    }

    updateUI() {
        const elements = {
            posts: document.getElementById('posts-count'),
            followers: document.getElementById('followers-count'),
            following: document.getElementById('following-count'),
            connections: document.getElementById('connections-count')
        };

        Object.keys(elements).forEach(key => {
            const element = elements[key];
            if (element) {
                if (this.isLoading) {
                    element.textContent = '...';
                    element.classList.add('loading');
                } else {
                    element.textContent = this.stats[key].toString();
                    element.classList.remove('loading');
                }
            }
        });
    }

    // Update counters when follow/unfollow happens
    async updateFollowCounters() {
        try {
            console.log('🔄 Updating follow counters for:', this.userId);
            
            // Count followers
            const followersQuery = await db.collection('follows')
                .where('followedId', '==', this.userId)
                .get();
            
            // Count following
            const followingQuery = await db.collection('follows')
                .where('followerId', '==', this.userId)
                .get();
            
            // Count connections (mutual follows)
            const followingIds = new Set(followingQuery.docs.map(doc => doc.data().followedId));
            const followerIds = new Set(followersQuery.docs.map(doc => doc.data().followerId));
            const connectionsCount = new Set([...followingIds].filter(id => followerIds.has(id))).size;

            // Update user document
            await db.collection('users').doc(this.userId).update({
                followersCount: followersQuery.docs.length,
                followingCount: followingQuery.docs.length,
                connectionsCount: connectionsCount,
                lastStatsUpdate: firebase.firestore.FieldValue.serverTimestamp()
            });

            console.log('✅ Counters updated:', {
                followers: followersQuery.docs.length,
                following: followingQuery.docs.length,
                connections: connectionsCount
            });
        } catch (error) {
            console.error('❌ Error updating counters:', error);
        }
    }

    destroy() {
        if (this.unsubscribe) {
            this.unsubscribe();
        }
    }
}

// Initialize stats view when page loads
document.addEventListener('DOMContentLoaded', () => {
    // Get userId from URL parameter or global variable
    const urlParams = new URLSearchParams(window.location.search);
    const userId = urlParams.get('userId') || window.currentUserId;
    
    if (userId) {
        window.statsView = new StatsView(userId);
    } else {
        console.error('❌ No userId provided for stats view');
    }
});

// Cleanup when page unloads
window.addEventListener('beforeunload', () => {
    if (window.statsView) {
        window.statsView.destroy();
    }
});
```

### **4. Integration Examples**

**Profile Page Integration:**
```html
<!-- Include stats view in profile page -->
<div class="profile-stats">
    <div id="user-stats"></div>
</div>

<script>
// Initialize stats for current user
const userId = 'current-user-id';
const statsView = new StatsView(userId);
</script>
```

**Streamer Card Integration:**
```html
<!-- Compact stats for streamer cards -->
<div class="streamer-stats">
    <div class="stat-compact">
        <span id="posts">...</span>
        <span>Posts</span>
    </div>
    <div class="stat-compact">
        <span id="followers">...</span>
        <span>Followers</span>
    </div>
    <div class="stat-compact">
        <span id="following">...</span>
        <span>Following</span>
    </div>
</div>
```

---

## 🔄 **Real-Time Synchronization**

### **1. Follow/Unfollow Updates**

**Mobile App (FollowsService):**
```dart
// After successful follow/unfollow
await _statsService.updateFollowCounters(currentUserId);
await _statsService.updateFollowCounters(targetUserId);
```

**Website (Follow Handler):**
```javascript
// After successful follow/unfollow
await statsView.updateFollowCounters();
```

### **2. Post Count Updates**

**Mobile App (PostCounterService):**
```dart
// When post is published/deleted
await postCounterService.incrementPostCount(userId);
// or
await postCounterService.decrementPostCount(userId);
```

**Website (Post Handler):**
```javascript
// When post is published/deleted
await updatePostCount(userId, increment);
```

---

## 🧪 **Testing**

### **1. Mobile App Testing**
```dart
// Test stats loading
final statsView = StatsView(userId: 'test-user');
// Verify stats display correctly

// Test real-time updates
// Follow/unfollow user and verify stats update instantly
```

### **2. Website Testing**
```javascript
// Test stats loading
const statsView = new StatsView('test-user');
// Verify stats display correctly

// Test real-time updates
// Follow/unfollow user and verify stats update instantly
```

---

## 📊 **Performance Considerations**

### **1. Caching**
- Stats are cached in user documents for fast access
- Real-time listeners only update when changes occur
- Debounced updates prevent excessive writes

### **2. Optimization**
- Use denormalized counters instead of counting documents
- Batch counter updates when possible
- Implement proper cleanup for listeners

---

## 🚀 **Deployment**

### **1. Mobile App**
1. Add `StatsService` to your services
2. Replace existing stats widgets with `StatsView`
3. Update follow handlers to call `updateFollowCounters()`
4. Test real-time updates

### **2. Website**
1. Deploy HTML, CSS, and JavaScript files
2. Configure Firebase project settings
3. Test real-time listeners
4. Verify cross-platform synchronization

---

## ✅ **Verification Checklist**

- [ ] Mobile app shows real-time stats
- [ ] Website shows real-time stats  
- [ ] Both platforms show identical numbers
- [ ] Stats update instantly on follow/unfollow
- [ ] Stats update instantly on post publish/delete
- [ ] Loading states work correctly
- [ ] Error handling works properly
- [ ] Performance is acceptable
- [ ] Cross-platform sync verified

---

**This implementation ensures both the mobile app and website show identical stats instantly using Firestore real-time listeners!** 🎯
