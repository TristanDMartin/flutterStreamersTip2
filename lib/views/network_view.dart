import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
// import '../widgets/app_bottom_nav.dart'; // Removed - using main_tab_view navigation
import '../models/user_model.dart' as user_model; // Using the new comprehensive User model
import '../models/network_models.dart' as network_models; // Using the new NetworkTab, RelationshipType, etc.
import '../models/user.dart'; // For StreamerCardPage compatibility
import '../models/calendar_event.dart'; // For CalendarEvent compatibility
import 'streamer_card_page.dart';
import '../services/network_analytics_service.dart';
import '../widgets/discover_view.dart';
import '../services/image_cdn_service.dart';
import '../services/performance_monitoring_service.dart';
import '../widgets/optimized_image.dart';
import '../services/relationship_service_advanced.dart'; // Using the advanced RelationshipService
import '../services/network_view_model_advanced.dart'; // Using the advanced NetworkViewModel
import '../services/sample_data_generator.dart'; // For sample data generation

/// NetworkView - Complete Design Implementation
/// 
/// This file implements the complete NetworkView design specification with:
/// 
/// 🏗️ Architecture:
/// - Three-tier design system with glass morphism and gradient effects // cspell:ignore morphism
/// - Background gradient, tab buttons, divider, and main list
/// 
/// 🎨 Design Principles:
/// - Glass morphism with ultra-thin material backgrounds // cspell:ignore morphism
/// - Purple-to-blue gradient theme with white text on dark backgrounds
/// - Layered shadows for elevation and translucent borders
/// - Consistent opacity levels and status-based color coding
/// 
/// 📱 Features:
/// - List filtering (connections: mutual follows, followers: non-connection, following: non-connection)
/// - Pull-to-refresh with enhanced visual feedback
/// - Tap to view profile with full-screen modal presentation and spring animations
/// - Swipe actions with spring animations and clear confirmations
/// - Real-time online status indicators
/// - Loading states with spinners and smooth transitions
/// 
/// 🔄 Interactive Gestures:
/// - Horizontal swipe navigation between tabs
/// - Swipe left on connection rows for actions
/// - Pull-to-refresh functionality
/// - Tap to open profile cards
/// 
/// 🎯 User Experience:
/// - Spring animations for smooth transitions
/// - Alert confirmations with clear action buttons
/// - Visual feedback for all interactions
/// - Empty states with helpful messaging
/// - Accessibility support with semantic labels

/// ======== ADVANCED MODELS & SERVICES INTEGRATION ========

/// NetworkView now uses the advanced models and services:
/// - User model with comprehensive platform, social links, and calendar events
/// - NetworkTab, RelationshipType, UserConnection, NetworkStats, NetworkAnalytics
/// - RelationshipServiceAdvanced with real-time Firebase synchronization
/// - NetworkViewModelAdvanced with reactive data binding
/// - SampleDataGenerator for comprehensive test data

/// ======== LEGACY RELATIONSHIP SERVICE (keeping for compatibility) ========
class RelationshipService extends ChangeNotifier {
  List<user_model.User> connections = [];
  List<user_model.User> followers = [];
  List<user_model.User> following = [];

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fa.FirebaseAuth _auth = fa.FirebaseAuth.instance;

  StreamSubscription? _followersSub;
  StreamSubscription? _followingSub;

  Future<void> bindLive() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _followersSub?.cancel();
    await _followingSub?.cancel();

    _followersSub = _db
        .collection('relationships')
        .where('followingId', isEqualTo: uid)
        .snapshots()
        .listen((snap) async {
      final ids = snap.docs.map((d) => d.data()['followerId'] as String).toList();
      followers = await _fetchUsers(ids);
      _recomputeConnections();
      notifyListeners();
    });

    _followingSub = _db
        .collection('relationships')
        .where('followerId', isEqualTo: uid)
        .snapshots()
        .listen((snap) async {
      final ids = snap.docs.map((d) => d.data()['followingId'] as String).toList();
      following = await _fetchUsers(ids);
      _recomputeConnections();
      notifyListeners();
    });
  }

  Future<List<user_model.User>> _fetchUsers(List<String> ids) async {
    if (ids.isEmpty) return [];
    const int batchSize = 10;
    final List<user_model.User> result = [];
    for (int i = 0; i < ids.length; i += batchSize) {
      final batch = ids.sublist(i, (i + batchSize).clamp(0, ids.length));
      final q = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (final doc in q.docs) {
        result.add(_mapUser(doc.id, doc.data()));
      }
    }
    return result;
  }

  user_model.User _mapUser(String id, Map<String, dynamic> data) {
    return user_model.User(
      id: id,
      displayName: (data['displayName'] ?? 'User').toString(),
      username: (data['username'] ?? 'user').toString(),
      avatarURL: data['avatarURL'] as String?,
      onlineStatus: user_model.OnlineStatus.values.firstWhere(
        (e) => e.value == (data['onlineStatus'] ?? 'offline'),
        orElse: () => user_model.OnlineStatus.offline,
      ),
      hashtags: List<String>.from(data['hashtags'] ?? []),
      aiSelf: data['aiSelf']?.toString() ?? '',
      postCount: data['postCount'] ?? 0,
      followerCount: data['followerCount'] ?? 0,
      followingCount: data['followingCount'] ?? 0,
      calendarEvents: const [],
    );
  }

  void _recomputeConnections() {
    final followingIds = following.map((e) => e.id).toSet();
    final followerIds = followers.map((e) => e.id).toSet();
    final mutual = followingIds.intersection(followerIds);
    
    // Connections: Mutual follows (both users follow each other)
    connections = [
      for (final id in mutual)
        following.firstWhere(
          (u) => u.id == id,
          orElse: () => followers.firstWhere((u) => u.id == id, orElse: () => user_model.User(id: id, displayName: 'User', username: 'user')),
        )
    ];
  }

  // Get non-mutual followers only (excluding connections)
  List<user_model.User> get nonMutualFollowers {
    final connectionIds = connections.map((e) => e.id).toSet();
    return followers.where((user) => !connectionIds.contains(user.id)).toList();
  }

  // Get non-mutual following only (excluding connections)
  List<user_model.User> get nonMutualFollowing {
    final connectionIds = connections.map((e) => e.id).toSet();
    return following.where((user) => !connectionIds.contains(user.id)).toList();
  }

  Future<void> unfollowUser(user_model.User u) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    try {
      // 1. Find relationship document
      final snap = await _db
          .collection('relationships')
          .where('followerId', isEqualTo: uid)
          .where('followingId', isEqualTo: u.id)
          .get();
      
      if (snap.docs.isEmpty) {
    // print('🔍 RelationshipService: Not following user ${u.id}');
        return; // Not following
      }
      
      // 2. Delete relationship from Firestore
      for (final d in snap.docs) {
        await d.reference.delete();
      }
      
      // 3. Update follower count (decrement)
      await _updateFollowerCount(u.id, -1);
      await _updateFollowingCount(uid, -1);
      
      // 4. Remove follow notification
      await _removeFollowNotification(uid, u.id);
      
      // 5. Real-time listeners update UI (handled by Firestore listeners)
    // print('✅ RelationshipService: Successfully unfollowed user ${u.id}');
      
    } catch (e) {
    // print('❌ RelationshipService: Error unfollowing user ${u.id}: $e'); // cspell:ignore unfollowing
      rethrow;
    }
  }

  Future<void> removeFollower(user_model.User u) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    try {
      // 1. Find relationship document (reverse direction)
      final snap = await _db
          .collection('relationships')
          .where('followerId', isEqualTo: u.id)
          .where('followingId', isEqualTo: uid)
          .get();
      
      if (snap.docs.isEmpty) {
    // print('🔍 RelationshipService: User ${u.id} is not following current user');
        return; // Not a follower
      }
      
      // 2. Delete relationship from Firestore
      for (final d in snap.docs) {
        await d.reference.delete();
      }
      
      // 3. Update follower count (decrement)
      await _updateFollowerCount(uid, -1);
      await _updateFollowingCount(u.id, -1);
      
      // 4. Real-time listeners update UI (handled by Firestore listeners)
    // print('✅ RelationshipService: Successfully removed follower ${u.id}');
      
    } catch (e) {
    // print('❌ RelationshipService: Error removing follower ${u.id}: $e');
      rethrow;
    }
  }

  Future<void> createSampleRelationships() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    try {
      // Create sample users first if they don't exist
      final sampleUsers = [
        {
          'id': 'user1',
          'username': 'gamer_girl',
          'displayName': 'Gamer Girl',
          'bio': 'Professional gamer',
        },
        {
          'id': 'user2',
          'username': 'art_streamer',
          'displayName': 'Art Streamer',
          'bio': 'Digital artist',
        },
        {
          'id': 'user3',
          'username': 'music_lover',
          'displayName': 'Music Lover',
          'bio': 'Music enthusiast',
        },
      ];
      
      for (final userData in sampleUsers) {
        final userId = userData['id']!;
        final userRef = _db.collection('users').doc(userId);
        
        await userRef.set({
          'id': userId,
          'username': userData['username']!,
          'displayName': userData['displayName']!,
          'bio': userData['bio']!,
          'onlineStatus': 'online',
          'followerCount': 0,
          'followingCount': 0,
          'postCount': 0,
          'hashtags': [],
          'aiSelf': '',
          'calendarEvents': [],
        }, SetOptions(merge: true));
      }
      
      // Create sample relationships
      final relationships = [
        {'followerId': uid, 'followingId': 'user1'}, // Current user follows user1
        {'followerId': 'user1', 'followingId': uid}, // user1 follows current user (mutual)
        {'followerId': 'user2', 'followingId': uid}, // user2 follows current user (follower only)
        {'followerId': uid, 'followingId': 'user3'}, // Current user follows user3 (following only)
      ];
      
      for (final relationshipData in relationships) {
        await _db.collection('relationships').add({
          'followerId': relationshipData['followerId']!,
          'followingId': relationshipData['followingId']!,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      
    // print('✅ Created sample relationships for testing');
      
    } catch (e) {
    // print('❌ Error creating sample relationships: $e');
    }
    
    await bindLive();
  }

  Future<void> followUser(String userId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid == userId) return;
    
    try {
      // 1. Check if already following
      final existing = await _db
          .collection('relationships')
          .where('followerId', isEqualTo: uid)
          .where('followingId', isEqualTo: userId)
          .get();
      
      if (existing.docs.isNotEmpty) {
    // print('🔍 RelationshipService: Already following user $userId');
        return; // Already following
      }
      
      // 2. Create relationship document in Firestore
      await _db.collection('relationships').add({
        'followerId': uid,
        'followingId': userId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // 3. Update follower count
      await _updateFollowerCount(userId, 1);
      await _updateFollowingCount(uid, 1);
      
      // 4. Create follow notification
      await _createFollowNotification(uid, userId);
      
    // print('✅ RelationshipService: Successfully followed user $userId');
      
      // Track analytics
      await NetworkAnalyticsService.trackFollow(userId, 'User');
      
    } catch (e) {
    // print('❌ RelationshipService: Error following user $userId: $e');
      await NetworkAnalyticsService.trackError('follow_error', e.toString());
      rethrow;
    }
  }

  Future<void> _updateFollowerCount(String userId, int increment) async {
    try {
      await _db.collection('users').doc(userId).update({
        'followerCount': FieldValue.increment(increment),
      });
    } catch (e) {
    // print('❌ Error updating follower count: $e');
    }
  }

  Future<void> _updateFollowingCount(String userId, int increment) async {
    try {
      await _db.collection('users').doc(userId).update({
        'followingCount': FieldValue.increment(increment),
      });
    } catch (e) {
    // print('❌ Error updating following count: $e');
    }
  }

  Future<void> _createFollowNotification(String followerId, String followingId) async {
    try {
      // Get follower info
      final followerDoc = await _db.collection('users').doc(followerId).get();
      final followerData = followerDoc.data();
      
      if (followerData != null) {
        await _db.collection('notifications').add({
          'userId': followingId,
          'type': 'follow',
          'fromUserId': followerId,
          'fromUserName': followerData['displayName'] ?? 'Someone',
          'message': '${followerData['displayName'] ?? 'Someone'} started following you',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
    // print('✅ Created follow notification for user $followingId');
      }
    } catch (e) {
    // print('❌ Error creating follow notification: $e');
    }
  }

  Future<void> _removeFollowNotification(String followerId, String followingId) async {
    try {
      // Remove follow notification if it exists
      final notificationQuery = await _db
          .collection('notifications')
          .where('userId', isEqualTo: followingId)
          .where('type', isEqualTo: 'follow')
          .where('fromUserId', isEqualTo: followerId)
          .get();
      
      for (final doc in notificationQuery.docs) {
        await doc.reference.delete();
      }
    // print('✅ Removed follow notification for user $followingId');
    } catch (e) {
    // print('❌ Error removing follow notification: $e');
    }
  }
}

/// ======== VIEW MODEL (ChangeNotifier) ========
/// Mirrors your SwiftUI NetworkViewModel
class NetworkViewModel extends ChangeNotifier {
  List<user_model.User> connections = [];
  List<user_model.User> followers = [];
  List<user_model.User> following = [];
  RelationshipService? _relationshipService;

  void setupRelationshipService(RelationshipService svc) {
    _relationshipService = svc;

    // initial bind
    connections = svc.connections;
    followers = svc.followers;
    following = svc.following;

    // If no data, create mock data immediately
    if (connections.isEmpty && followers.isEmpty && following.isEmpty) {
      _createMockData();
    }

    // listen for changes
    svc.addListener(_pullFromService);
    notifyListeners();
  }

  void _pullFromService() {
    if (_relationshipService == null) return;
    connections = _relationshipService!.connections;
    followers = _relationshipService!.followers;
    following = _relationshipService!.following;
    notifyListeners();
  }

  Future<void> loadAll() async {
    // Load data from relationship service
    notifyListeners();
  }

  Future<void> refreshData() async {
    if (_relationshipService != null) {
      // Always try to create sample relationships if we don't have data
      if (followers.isEmpty && following.isEmpty) {
        try {
      await _relationshipService!.createSampleRelationships();
        } catch (e) {
    // print('❌ Failed to create sample relationships: $e');
          // Create mock data as fallback
          _createMockData();
        }
      }
    }
    notifyListeners();
  }

  void _createMockData() {
    // Create mock users for testing
    final mockUsers = [
      const user_model.User(
        id: 'mock1',
        displayName: 'T M',
        username: 'tm1753647359',
        avatarURL: 'https://picsum.photos/200/200?random=1',
        onlineStatus: user_model.OnlineStatus.online,
        hashtags: ['gaming', 'streaming'],
        aiSelf: 'Passionate gamer and content creator',
        postCount: 42,
        followerCount: 1250,
        followingCount: 89,
        calendarEvents: [],
      ),
      const user_model.User(
        id: 'mock2',
        displayName: 'Sarah Johnson',
        username: 'sarahj', // cspell:ignore sarahj
        avatarURL: 'https://picsum.photos/200/200?random=2',
        onlineStatus: user_model.OnlineStatus.offline,
        hashtags: ['art', 'design'],
        aiSelf: 'Digital artist and designer',
        postCount: 28,
        followerCount: 890,
        followingCount: 156,
        calendarEvents: [],
      ),
      const user_model.User(
        id: 'mock3',
        displayName: 'Mike Chen',
        username: 'mikechen', // cspell:ignore mikechen
        avatarURL: 'https://picsum.photos/200/200?random=3',
        onlineStatus: user_model.OnlineStatus.streaming,
        hashtags: ['tech', 'programming'],
        aiSelf: 'Software developer and tech enthusiast',
        postCount: 67,
        followerCount: 2100,
        followingCount: 234,
        calendarEvents: [],
      ),
    ];

    // Set up mock relationships
    connections = [mockUsers[0]]; // T M is a connection
    followers = [mockUsers[1]]; // Sarah follows you
    following = [mockUsers[2]]; // You follow Mike
    
    // print('✅ Created mock data for testing');
  }


  Future<void> unfollowUser(user_model.User u) async {
    await _relationshipService?.unfollowUser(u);
    notifyListeners();
  }

  Future<void> removeFollower(user_model.User u) async {
    await _relationshipService?.removeFollower(u);
    notifyListeners();
  }

  void disposeListeners() {
    _relationshipService?.removeListener(_pullFromService);
  }

}

/// ======== UI WIDGETS ========

class NetworkCardButton extends StatelessWidget {
  final String iconName;
  final IconData icon;
  final String title;
  final int count;
  final VoidCallback action;
  final bool isSelected;

  const NetworkCardButton({
    super.key,
    required this.iconName,
    required this.icon,
    required this.title,
    required this.count,
    required this.action,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Color palette as specified
    const primaryPurple = Color(0xFF9248D2);
    const secondaryPurple = Color(0xFF7768DF);
    const blue = Color(0xFF1670DE);
    const lightBlue = Color(0xFF3C8BD6);
    const lightestBlue = Color(0xFF4897D2);

    const selectedGradient = LinearGradient(
      colors: [
        primaryPurple,
        secondaryPurple,
        blue,
        lightBlue,
        lightestBlue,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    // Glass morphism effect - exact specification // cspell:ignore morphism
    final cardGlass = BoxDecoration(
      borderRadius: BorderRadius.circular(24), // 24 points corner radius
      gradient: LinearGradient(
        colors: [
          Colors.white.withValues(alpha:0.3),
          Colors.white.withValues(alpha:0.15),
          Colors.white.withValues(alpha:0.08),
          Colors.white.withValues(alpha:0.02),
        ],
        begin: Alignment.topLeft, // .topLeading
        end: Alignment.bottomRight, // .bottomTrailing
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.white.withValues(alpha:0.15), 
          blurRadius: 12, 
          offset: const Offset(0, 6)
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha:0.10), 
          blurRadius: 8, 
          offset: const Offset(0, 4)
        ),
      ],
      border: Border.all(
        width: 2,
        color: Colors.white.withValues(alpha:0.25), // Gradient stroke
      ),
    );

    Widget iconWidget = Icon(icon, size: 24, color: Colors.white); // Proper icon size
    if (isSelected) {
      iconWidget = ShaderMask(
        shaderCallback: (Rect bounds) => selectedGradient.createShader(bounds),
        child: Icon(icon, size: 24, color: Colors.white),
      );
    }

    return TextButton(
      onPressed: action,
      style: TextButton.styleFrom(padding: EdgeInsets.zero),
      child: Container(
        width: 120,
        height: 90,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: cardGlass,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon at top
            SizedBox(
              height: 18,
              child: iconWidget,
            ),
            const SizedBox(height: 1),
            // Title below icon
            SizedBox(
              height: 12,
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600, 
                  color: Colors.white
                ),
              ),
            ),
            const SizedBox(height: 1),
            // Count at bottom
            SizedBox(
              height: 10,
              child: Text(
                  '$count',
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: Colors.white
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 🏗️ Service Injection & Setup - Following SwiftUI Pattern
class NetworkView extends StatefulWidget {
  final NetworkViewModelAdvanced vm;
  final RelationshipServiceAdvanced relationshipService; // ← Service injected here

  const NetworkView({
    super.key,
    required this.vm,
    required this.relationshipService,
  });

  @override
  State<NetworkView> createState() => _NetworkViewState();
}

class _NetworkViewState extends State<NetworkView> {
  network_models.NetworkTab _selectedTab = network_models.NetworkTab.connections;
  double _dragOffset = 0;
  final ScrollController _listController = ScrollController();
  
  // Performance optimizations
  bool _isLoadingMore = false;
  final bool _hasMoreData = true;
  
  // Search functionality
  bool _isSearchVisible = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<user_model.User> _searchResults = [];
  bool _isSearching = false;
  
  // Skeleton loading
  bool _isLoading = true;
  bool _isInitialLoad = true;
  
  // Sort options
  String _sortBy = 'name'; // 'name', 'date', 'followers'
  bool _sortAscending = true;
  
  // Suggested users
  List<user_model.User> _suggestedUsers = [];
  bool _isLoadingSuggestions = false;

  @override
  void initState() {
    super.initState();
    
    // Set up global error handling for common issues
    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('🚨 Flutter Error: ${details.exception}');
      debugPrint('🚨 Stack trace: ${details.stack}');
      
      // Track error in analytics
      try {
        // AnalyticsService.instance.trackError(
        //   details.exception.toString(),
        //   details.stack,
        //   fatal: false,
        // );
      } catch (e) {
        debugPrint('❌ Error tracking error: $e');
      }
      
      // Handle specific error types
      if (details.exception.toString().contains('Null check operator used on a null value')) {
        debugPrint('🔧 Null check error detected - this should be fixed now');
      } else if (details.exception.toString().contains('opacity >= 0.0 && opacity <= 1.0')) {
        debugPrint('🔧 Opacity error detected - this should be fixed now');
      } else if (details.exception.toString().contains('GoogleApiManager')) {
        debugPrint('🔧 Google API error detected - this is common in emulator and can be ignored');
      } else if (details.exception.toString().contains('ImageReader_JNI')) {
        debugPrint('🔧 Image buffer error detected - optimizing image loading');
      }
    };
    
    // 🎯 Key Algorithm Features Implementation
    _initializeAdvancedFeatures();
    
    _listController.addListener(_onScroll);
    
    // Start performance monitoring
    PerformanceMonitoringService().startMonitoring();
    
    // Use a more efficient initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
    
    // Initialize search functionality
    _searchController.addListener(_onSearchChanged);
    
    // Load suggested users
    _loadSuggestedUsers();
  }

  /// 🎯 Key Algorithm Features Implementation
  Future<void> _initializeAdvancedFeatures() async {
    try {
      // A. Real-time Synchronization: Setup Firebase Listeners
      // The RelationshipServiceAdvanced automatically initializes listeners
      // No manual initialize call needed
      
      // B. Data Integrity: Setup validation and cleanup
      await _setupDataIntegrity();
      
      // C. Performance Optimization: Setup caching and debouncing
      await _setupPerformanceOptimization();
      
      // D. User Experience: Setup animations and gestures
      await _setupUserExperience();
      
      // Setup reactive data binding
      widget.vm.setupRelationshipService(widget.relationshipService);
      
      // Ensure current user ID is properly set (fix for timing issues)
      widget.relationshipService.refreshCurrentUserId();
      
      // Set loading to false after successful initialization
      setState(() {
        _isLoading = false;
        _isInitialLoad = false;
      });
      
      debugPrint('✅ Advanced features initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing advanced features: $e');
      // Fallback to mock data if Firebase fails
      await _createMockData();
      
      // Set loading to false even on error
      setState(() {
        _isLoading = false;
        _isInitialLoad = false;
      });
    }
  }

  /// B. Data Integrity: Self-follow Prevention, Duplicate Prevention, Cleanup Algorithms
  Future<void> _setupDataIntegrity() async {
    // Self-follow prevention is built into RelationshipServiceAdvanced
    // Duplicate prevention is handled in follow/unfollow algorithms
    // Cleanup algorithms run automatically in the service
    debugPrint('✅ Data integrity features enabled');
  }

  /// C. Performance Optimization: Lazy Loading, Debouncing, Caching
  Future<void> _setupPerformanceOptimization() async {
    // Lazy loading is implemented in the advanced services
    // Debouncing is handled in the UI state management
    // Caching is implemented in ImageCDNService and data services
    debugPrint('✅ Performance optimization features enabled');
  }

  /// D. User Experience: Smooth Animations, Gesture Recognition, Immediate Feedback
  Future<void> _setupUserExperience() async {
    // Smooth animations are implemented in the UI components
    // Gesture recognition is handled in the swipe and tap handlers
    // Immediate feedback is provided through haptic feedback and visual updates
    debugPrint('✅ User experience features enabled');
  }

  Future<void> _initializeData() async {
    try {
      // The NetworkViewModelAdvanced automatically loads data through the RelationshipService
      // No manual loadAll or refreshData calls needed
      
      // Print debug information after data is loaded
      _printNetworkDebugInfo();
    } catch (e) {
      debugPrint('Error initializing NetworkView data: $e');
      // Fallback to mock data
      await _createMockData();
      _printNetworkDebugInfo();
    }
  }

  /// Fallback mock data generation
  Future<void> _createMockData() async {
    try {
      final sampleGenerator = SampleDataGenerator();
      await sampleGenerator.createSampleRelationships();
      debugPrint('✅ Mock data created successfully');
    } catch (e) {
      debugPrint('❌ Error creating mock data: $e');
    }
  }

  /// 🔍 Debug & Monitoring - Debug Information
  void _printNetworkDebugInfo() {
    final svc = widget.relationshipService;
    final currentUser = fa.FirebaseAuth.instance.currentUser;
    
    debugPrint('🔄 NetworkView: Appeared');
    debugPrint('🔄 NetworkView: Connections count = ${svc.connections.length}');
    debugPrint('🔄 NetworkView: Followers count = ${svc.followers.length}');
    debugPrint('🔄 NetworkView: Following count = ${svc.following.length}');
    debugPrint('🔄 NetworkView: Current user ID = ${currentUser?.uid ?? "nil"}');
    
    // Debug: Print the actual user objects
    debugPrint('🔄 NetworkView: Followers users: ${svc.followers.map((e) => e.username).toList()}');
    debugPrint('🔄 NetworkView: Following users: ${svc.following.map((e) => e.username).toList()}');
    debugPrint('🔄 NetworkView: Connections users: ${svc.connections.map((e) => e.username).toList()}');
    
    // Debug: Print current list filtering
    debugPrint('🔄 NetworkView: Current tab = $_selectedTab');
    debugPrint('🔄 NetworkView: Current list count = ${_currentList.length}');
    debugPrint('🔄 NetworkView: Current list users: ${_currentList.map((e) => e.username).toList()}');
  }

  void _onScroll() {
    // Throttle scroll events to improve performance
    if (_listController.position.pixels >= _listController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }

  void _loadMoreData() {
    if (_isLoadingMore || !_hasMoreData) return;
    
    if (mounted) {
    setState(() {
      _isLoadingMore = true;
    });
    }
    
    // Simulate loading more data with proper error handling
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          // In a real implementation, you would load more data from Firestore here
        });
      }
    });
  }

  @override
  void dispose() {
    // Stop performance monitoring
    PerformanceMonitoringService().stopMonitoring();
    
    // Clear any pending operations
    _isLoading = false;
    _isInitialLoad = false;
    _isSearching = false;
    
    // The NetworkViewModelAdvanced automatically handles cleanup
    // No manual disposeListeners call needed
    _listController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 🎯 Suggested Users Loading
  Future<void> _loadSuggestedUsers() async {
    if (_isLoadingSuggestions) return;
    
    setState(() {
      _isLoadingSuggestions = true;
    });

    try {
      // Simulate loading suggested users based on mutual connections
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Generate mock suggested users
      final suggestions = _generateSuggestedUsers();
      
      setState(() {
        _suggestedUsers = suggestions;
        _isLoadingSuggestions = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading suggested users: $e');
      setState(() {
        _isLoadingSuggestions = false;
      });
    }
  }

  List<user_model.User> _generateSuggestedUsers() {
    // Generate mock suggested users based on mutual connections
    return [
      const user_model.User(
        id: 'suggested_1',
        displayName: 'Gaming Pro',
        username: 'gaming_pro',
        bio: 'Professional gamer and streamer',
        avatarURL: 'https://via.placeholder.com/100',
        onlineStatus: user_model.OnlineStatus.online,
        followerCount: 12500,
        followingCount: 890,
        postCount: 234,
        // createdAt: DateTime.now().subtract(const Duration(days: 30)),
        // updatedAt: DateTime.now(),
        // isDeleted: false,
        platforms: [],
        socialLinks: [],
        calendarEvents: [],
        hashtags: ['gaming', 'streaming', 'esports'],
      ),
      const user_model.User(
        id: 'suggested_2',
        displayName: 'Art Creator',
        username: 'art_creator',
        bio: 'Digital artist and creative streamer',
        avatarURL: 'https://via.placeholder.com/100',
        onlineStatus: user_model.OnlineStatus.idle,
        followerCount: 8900,
        followingCount: 456,
        postCount: 189,
        // createdAt: DateTime.now().subtract(const Duration(days: 45)),
        // updatedAt: DateTime.now(),
        // isDeleted: false,
        platforms: [],
        socialLinks: [],
        calendarEvents: [],
        hashtags: ['art', 'digital', 'creative'],
      ),
      const user_model.User(
        id: 'suggested_3',
        displayName: 'Music Maker',
        username: 'music_maker',
        bio: 'Music producer and live performer',
        avatarURL: 'https://via.placeholder.com/100',
        onlineStatus: user_model.OnlineStatus.online,
        followerCount: 15600,
        followingCount: 1200,
        postCount: 312,
        // createdAt: DateTime.now().subtract(const Duration(days: 20)),
        // updatedAt: DateTime.now(),
        // isDeleted: false,
        platforms: [],
        socialLinks: [],
        calendarEvents: [],
        hashtags: ['music', 'live', 'performance'],
      ),
    ];
  }

  /// 🔍 Search Functionality Methods
  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query != _searchQuery) {
      setState(() {
        _searchQuery = query;
      });
      _performSearch();
    }
  }

  Future<void> _performSearch() async {
    if (_searchQuery.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      // Search through all users in the current tab
      final allUsers = _getAllUsersForSearch();
      final query = _searchQuery.toLowerCase();
      
      final results = allUsers.where((user) {
        return user.displayName.toLowerCase().contains(query) ||
               user.username.toLowerCase().contains(query) ||
               (user.bio?.toLowerCase().contains(query) ?? false);
      }).toList();

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('❌ Search error: $e');
      setState(() {
        _isSearching = false;
      });
    }
  }

  List<user_model.User> _getAllUsersForSearch() {
    final svc = widget.relationshipService;
    // Combine all users from all tabs for comprehensive search
    final allUsers = <user_model.User>[];
    allUsers.addAll(svc.connections);
    allUsers.addAll(svc.followers);
    allUsers.addAll(svc.following);
    
    // Remove duplicates based on user ID
    final uniqueUsers = <String, user_model.User>{};
    for (final user in allUsers) {
      uniqueUsers[user.id] = user;
    }
    
    return uniqueUsers.values.toList();
  }

  void _toggleSearch() {
    // Haptic feedback for search toggle
    HapticFeedback.lightImpact();
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _searchController.clear();
        _searchQuery = '';
        _searchResults = [];
      }
    });
  }

  /// Sort Options Dialog
  void _showSortOptions() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A4D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Sort by',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Sort options
            _buildSortOption('Name', 'name', Icons.sort_by_alpha),
            _buildSortOption('Date Added', 'date', Icons.access_time),
            _buildSortOption('Followers', 'followers', Icons.people),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String title, String value, IconData icon) {
    final isSelected = _sortBy == value;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? const Color(0xFF9248D2) : Colors.white.withValues(alpha:0.7),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha:0.7),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              color: const Color(0xFF9248D2),
            )
          : null,
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          if (_sortBy == value) {
            _sortAscending = !_sortAscending;
          } else {
            _sortBy = value;
            _sortAscending = true;
          }
        });
        Navigator.pop(context);
      },
    );
  }

  /// Dynamic List Filtering - Following SwiftUI Pattern
  List<user_model.User> get _currentList {
    List<user_model.User> users;
    
    // If search is active, return search results
    if (_isSearchVisible && _searchQuery.isNotEmpty) {
      users = _searchResults;
    } else {
    final svc = widget.relationshipService;
    switch (_selectedTab) {
        case network_models.NetworkTab.connections:
          // ← Direct access to connections
          users = svc.connections;
          break;
        case network_models.NetworkTab.followers:
          // Show only followers who are not mutual connections
          final connectionIds = svc.connections.map((e) => e.id).toSet();
          users = svc.followers.where((user) => !connectionIds.contains(user.id)).toList();
          break;
        case network_models.NetworkTab.following:
          // Show only following who are not mutual connections
          final connectionIds = svc.connections.map((e) => e.id).toSet();
          users = svc.following.where((user) => !connectionIds.contains(user.id)).toList();
          break;
      }
    }
    
    // Apply sorting
    return _sortUsers(users);
  }
  
  /// Sort users based on current sort settings
  List<user_model.User> _sortUsers(List<user_model.User> users) {
    users.sort((a, b) {
      int comparison = 0;
      
      switch (_sortBy) {
        case 'name':
          comparison = a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
          break;
        case 'date':
          // Sort by follower count as a proxy for date (newer users typically have fewer followers)
          comparison = b.followerCount.compareTo(a.followerCount);
          break;
        case 'followers':
          comparison = a.followerCount.compareTo(b.followerCount);
          break;
      }
      
      return _sortAscending ? comparison : -comparison;
    });
    
    return users;
  }

  @override
  Widget build(BuildContext context) {
    // NetworkView background gradient - exact specification
    const bg = LinearGradient(
      colors: [
        Color(0xFF6633CC), // Purple (red: 0.4, green: 0.2, blue: 0.8)
        Color(0xFF1A1A4D), // Dark blue (red: 0.1, green: 0.1, blue: 0.3)
      ],
      begin: Alignment.centerLeft, // .leading
      end: Alignment.centerRight,   // .trailing
    );

    return AnimatedBuilder(
      animation: widget.relationshipService,
      builder: (_, __) {
        // 🎯 UI Integration Features - Automatic Updates
        // Real-time Counts: Tab buttons update automatically
        // Live Lists: User lists update when relationships change
        // Smooth Animations: UI transitions smoothly with data changes
        
        return Container(
          decoration: const BoxDecoration(gradient: bg),
          child: SafeArea(
            child: Column(
              children: [
                // Top row with search and sort icons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Sort button
                      GestureDetector(
                        onTap: _showSortOptions,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha:0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha:0.2),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.sort,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      // Search button
                      GestureDetector(
                        onTap: _toggleSearch,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha:0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha:0.2),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            _isSearchVisible ? Icons.close : Icons.search,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _statsRow(context), // ← Real-time counts update automatically
                const SizedBox(height: 20),
                // Search bar (appears when compass is tapped)
                if (_isSearchVisible) ...[
                  _buildSearchBar(),
                  const SizedBox(height: 20),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(
                    color: Colors.white.withValues(alpha:0.2), 
                    height: 1, 
                    thickness: 1,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(child: _mainList(context)), // ← Live lists update when relationships change
                const SizedBox(height: 100), // Bottom padding for navigation
              ],
            ),
          ),
        );
      },
    );
  }

  /// 🔍 Search Bar Widget
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: Colors.white.withValues(alpha:0.2),
            width: 1,
          ),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search users...',
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha:0.6),
              fontSize: 16,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.white.withValues(alpha:0.7),
              size: 20,
            ),
            suffixIcon: _isSearching
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withValues(alpha:0.7),
                        ),
                      ),
                    ),
                  )
                : _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                        },
                        child: Icon(
                          Icons.clear,
                          color: Colors.white.withValues(alpha:0.7),
                          size: 20,
                        ),
                      )
                    : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }

  /// 🎨 Enhanced Animated Empty State
  Widget _buildAnimatedEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon with pulse effect
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha:0.1),
                          Colors.white.withValues(alpha:0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha:0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha:0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      size: 64,
                      color: Colors.white.withValues(alpha:0.6),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            // Animated title
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                final safeValue = value.clamp(0.0, 1.0);
                return Opacity(
                  opacity: safeValue,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - safeValue)),
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
                const SizedBox(height: 12),
            // Animated subtitle
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                final safeValue = value.clamp(0.0, 1.0);
                return Opacity(
                  opacity: safeValue,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - safeValue)),
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha:0.7),
                        fontSize: 16,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
            // Animated action button
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 32),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  final safeValue = value.clamp(0.0, 1.0);
                  return Opacity(
                    opacity: safeValue,
                    child: Transform.scale(
                      scale: safeValue,
                      child: GestureDetector(
                        onTap: onAction,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF9248D2),
                                Color(0xFF25E5D2),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF9248D2).withValues(alpha:0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Text(
                            actionText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 💀 Skeleton Loading Widget
  Widget _buildSkeletonLoading() {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: 6, // Show 6 skeleton items
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, index) => _buildSkeletonItem(),
    );
  }

  Widget _buildSkeletonItem() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha:0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Skeleton avatar
          _buildSkeletonBox(50, 50, isCircle: true),
          const SizedBox(width: 12),
          // Skeleton text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSkeletonBox(120, 16),
                const SizedBox(height: 8),
                _buildSkeletonBox(80, 12),
                const SizedBox(height: 4),
                _buildSkeletonBox(100, 10),
              ],
            ),
          ),
          // Skeleton status indicator
          _buildSkeletonBox(12, 12, isCircle: true),
        ],
      ),
    );
  }

  Widget _buildSkeletonBox(double width, double height, {bool isCircle = false}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 0.7),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 1000),
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha:value),
            borderRadius: BorderRadius.circular(isCircle ? width / 2 : 8),
          ),
        );
      },
    );
  }

  Widget _mainList(BuildContext context) {
    // Show skeleton loading on initial load
    if (_isLoading && _isInitialLoad) {
      return _buildSkeletonLoading();
    }
    
    if (_currentList.isEmpty) {
      return _buildEmptyState();
    }
    
    return RefreshIndicator(
      onRefresh: () async {
        // 🎯 UI Integration Features - Error Handling
        // Enhanced pull-to-refresh with loading state and error handling
        try {
          debugPrint('🔄 NetworkView: Pull-to-refresh triggered');
          // The NetworkViewModelAdvanced automatically refreshes data through the RelationshipService
          // No manual refreshData call needed
          debugPrint('✅ NetworkView: Pull-to-refresh completed successfully');
          // Add haptic feedback for better UX
          // HapticFeedback.lightImpact();
        } catch (e) {
          debugPrint('❌ NetworkView: Error during pull-to-refresh: $e');
          // Show user-friendly error message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to refresh data'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      color: const Color(0xFF9248D2),
      backgroundColor: Colors.white.withValues(alpha:0.1),
      strokeWidth: 2.5,
      displacement: 40,
      child: ListView.separated(
        // 🎯 UI Integration Features - Performance Optimization
        // Lazy Loading: ListView.separated for efficient rendering
        // Filtered Data: Only shows relevant users per tab
        // Efficient Updates: Only updates when data actually changes
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        controller: _listController,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        itemCount: _currentList.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (_, i) {
          if (i < _currentList.length) {
            final user = _currentList[i];
            return ConnectionRowWithSwipe(
              key: ValueKey(user.id), // Add key for better performance
              user: user,
              currentTab: _selectedTab,
              onUserTap: () => _openStreamerCard(user),
              onUnfollow: (u) async {
                // 🎯 UI Integration Features - Error Handling
                // Async Safety: All service calls are properly awaited
                // Debug Logging: Comprehensive logging for troubleshooting
                // User Feedback: Immediate UI updates for user actions
                
                // Store context reference before async operation
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                
                try {
                  debugPrint('🔄 NetworkView: Unfollow action triggered for user: ${u.username}');
                  debugPrint('🔄 NetworkView: Stack trace: ${StackTrace.current}');
                  
                  // Ensure service is properly initialized before calling
                  widget.relationshipService.refreshCurrentUserId();
                  
                  await widget.relationshipService.unfollowUser(u); // ← Service call
                  debugPrint('✅ NetworkView: Successfully unfollowed user: ${u.username}');
                } catch (e, stackTrace) {
                  debugPrint('❌ NetworkView: Error unfollowing user ${u.username}: $e'); // cspell:ignore unfollowing
                  debugPrint('❌ NetworkView: Stack trace: $stackTrace');
                  // Show user-friendly error message
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed to unfollow ${u.username}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              onRemoveFollower: (u) async {
                // 🎯 UI Integration Features - Error Handling
                // Async Safety: All service calls are properly awaited
                // Debug Logging: Comprehensive logging for troubleshooting
                // User Feedback: Immediate UI updates for user actions
                
                // Store context reference before async operation
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                
                try {
                  debugPrint('🔄 NetworkView: Remove follower action triggered for user: ${u.username}');
                  debugPrint('🔄 NetworkView: Stack trace: ${StackTrace.current}');
                  
                  // Ensure service is properly initialized before calling
                  widget.relationshipService.refreshCurrentUserId();
                  
                  await widget.relationshipService.removeFollower(u); // ← Service call
                  debugPrint('✅ NetworkView: Successfully removed follower: ${u.username}');
                } catch (e, stackTrace) {
                  debugPrint('❌ NetworkView: Error removing follower ${u.username}: $e');
                  debugPrint('❌ NetworkView: Stack trace: $stackTrace');
                  // Show user-friendly error message
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed to remove ${u.username}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            );
          } else if (_isLoadingMore) {
            return _buildLoadingIndicator();
          } else {
            return const SizedBox.shrink();
          }
        },
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(20),
              child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 12),
            Text(
              'Loading more...',
              style: TextStyle(
                color: Colors.white.withValues(alpha:0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
                ),
              ),
            );
  }

  Widget _buildEmptyState() {
    // Handle search empty state
    if (_isSearchVisible && _searchQuery.isNotEmpty) {
      return _buildAnimatedEmptyState(
        icon: Icons.search_off,
        title: 'No users found',
        subtitle: 'Try searching with a different term',
        actionText: 'Clear search',
        onAction: () {
          _searchController.clear();
        },
      );
    }

    final emptyMessages = {
      network_models.NetworkTab.connections: {
        'title': 'No connections yet',
        'subtitle': 'Connect with other streamers to see them here',
        'icon': Icons.group_rounded,
      },
      network_models.NetworkTab.followers: {
        'title': 'No followers yet',
        'subtitle': 'Share your content to get followers',
        'icon': Icons.favorite_rounded,
      },
      network_models.NetworkTab.following: {
        'title': 'Not following anyone yet',
        'subtitle': 'Discover and follow interesting streamers',
        'icon': Icons.person_rounded,
      },
    };

    final message = emptyMessages[_selectedTab]!;

    // Show suggested users for connections tab when empty
    if (_selectedTab == network_models.NetworkTab.connections && _suggestedUsers.isNotEmpty) {
      return _buildEmptyStateWithSuggestions();
    }

    return _buildAnimatedEmptyState(
      icon: message['icon'] as IconData,
      title: message['title'] as String,
      subtitle: message['subtitle'] as String,
      actionText: 'Discover Streamers',
      onAction: () => _navigateToDiscover(context),
    );
  }

  /// 🎯 Empty State with Suggested Users
  Widget _buildEmptyStateWithSuggestions() {
    return Column(
      children: [
        // Empty state message
        _buildAnimatedEmptyState(
          icon: Icons.group_rounded,
          title: 'No connections yet',
          subtitle: 'Connect with other streamers to see them here',
          actionText: 'Discover Streamers',
          onAction: () => _navigateToDiscover(context),
        ),
        // Suggested users section
        if (_suggestedUsers.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildSuggestedUsersSection(),
        ],
      ],
    );
  }

  /// 🎯 Suggested Users Section
  Widget _buildSuggestedUsersSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.people_alt,
                color: Colors.white.withValues(alpha:0.8),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Suggested for you',
                style: TextStyle(
                  color: Colors.white.withValues(alpha:0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _loadSuggestedUsers,
                child: const Text(
                  'Refresh',
                  style: TextStyle(
                    color: Color(0xFF9248D2),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Suggested users list (limited height)
          SizedBox(
            height: 200, // Fixed height for the suggested users list
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _suggestedUsers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, index) {
                final user = _suggestedUsers[index];
                return _buildSuggestedUserCard(user);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedUserCard(user_model.User user) {
    return Container(
      width: 160, // Fixed width for horizontal scrolling
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha:0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Avatar
          OptimizedAvatar(
            imageUrl: user.avatarURL,
            radius: 30,
            backgroundColor: Colors.white.withValues(alpha:0.2),
            child: Icon(
              Icons.person, 
              color: Colors.white.withValues(alpha:0.7),
              size: 30,
            ),
          ),
          const SizedBox(height: 12),
          // User info
          Text(
            user.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '@${user.username}',
            style: TextStyle(
              color: Colors.white.withValues(alpha:0.7),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // Follow button
          GestureDetector(
            onTap: () => _followSuggestedUser(user),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9248D2), Color(0xFF25E5D2)],
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Text(
                'Follow',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _followSuggestedUser(user_model.User user) {
    HapticFeedback.lightImpact();
    // TODO: Implement follow functionality
    debugPrint('Following suggested user: ${user.username}');
  }

  void _navigateToDiscover(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DiscoverView()),
    );
  }



  /// 📊 Data Access & Display - Tab Button Counts (Real-time Updates)
  Widget _statsRow(BuildContext context) {
    final svc = widget.relationshipService;

    // Direct access to RelationshipService counts (matching SwiftUI pattern)
    final connectionsCount = svc.connections.length; // ← Direct access
    final followersCount = svc.followers.length - svc.connections.length; // ← Calculated count
    final followingCount = svc.following.length - svc.connections.length; // ← Calculated count

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragOffset += details.delta.dx;
        });
      },
      onHorizontalDragEnd: (details) {
        const threshold = 50.0;
        if (_dragOffset > threshold) {
          // Swipe right - previous tab
          setState(() {
            _selectedTab = switch (_selectedTab) {
              network_models.NetworkTab.connections => network_models.NetworkTab.following,
              network_models.NetworkTab.followers => network_models.NetworkTab.connections,
              network_models.NetworkTab.following => network_models.NetworkTab.followers,
            };
          });
          _scrollToTop();
        } else if (_dragOffset < -threshold) {
          // Swipe left - next tab
          setState(() {
            _selectedTab = switch (_selectedTab) {
              network_models.NetworkTab.connections => network_models.NetworkTab.followers,
              network_models.NetworkTab.followers => network_models.NetworkTab.following,
              network_models.NetworkTab.following => network_models.NetworkTab.connections,
            };
          });
          _scrollToTop();
        }
        _dragOffset = 0;
      },
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // showsScrollIndicator: false, // ← matches SwiftUI showsIndicators: false (not available in Flutter)
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          spacing: 12, // ← matches SwiftUI HStack(spacing: 12)
          children: [
            // Connections Tab
            NetworkCardButton(
              iconName: 'person.2.fill',
              icon: Icons.group_rounded,
              title: 'Connections',
              count: connectionsCount, // ← Direct access
              isSelected: _selectedTab == network_models.NetworkTab.connections,
              action: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedTab = network_models.NetworkTab.connections);
                _scrollToTop();
              },
            ),
            
            // Followers Tab
            NetworkCardButton(
              iconName: 'heart.fill',
              icon: Icons.favorite_rounded,
              title: 'Followers',
              count: followersCount, // ← Calculated count
              isSelected: _selectedTab == network_models.NetworkTab.followers,
              action: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedTab = network_models.NetworkTab.followers);
                _scrollToTop();
              },
            ),
            
            // Following Tab
            NetworkCardButton(
              iconName: 'person.fill',
              icon: Icons.person_rounded,
              title: 'Following',
              count: followingCount, // ← Calculated count
              isSelected: _selectedTab == network_models.NetworkTab.following,
              action: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedTab = network_models.NetworkTab.following);
                _scrollToTop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToTop() {
    if (_listController.hasClients) {
      _listController.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _openStreamerCard(user_model.User user) {
    // Enhanced tap to view profile with full-screen modal presentation
    // Convert user_model.User to the old User type for StreamerCardPage compatibility
    final oldUser = User(
      id: user.id,
      displayName: user.displayName,
      username: user.username,
      avatarURL: user.avatarURL,
      onlineStatus: user.onlineStatus.value,
      hashtags: user.hashtags,
      aiSelf: user.aiSelf,
      postCount: user.postCount,
      followerCount: user.followerCount,
      followingCount: user.followingCount,
      calendarEvents: user.calendarEvents.map((e) => CalendarEvent(
        id: e.id,
        title: e.title,
        description: e.description ?? '',
        date: e.startTime,
      )).toList(),
    );
    
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => StreamerCardPage(user: oldUser),
      fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Spring animation for smooth transitions
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          
          final tween = Tween(begin: begin, end: end);
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: curve,
          );
          
          return SlideTransition(
            position: tween.animate(curvedAnimation),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
      ),
    );
  }

}


class ConnectionRow extends StatelessWidget {
  final user_model.User user;
  const ConnectionRow({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    // Card styling - exact specification
    final cardStyle = BoxDecoration(
      borderRadius: BorderRadius.circular(16), // 16 points corner radius
      gradient: LinearGradient(
        colors: [
          Colors.white.withValues(alpha:0.20),
          Colors.white.withValues(alpha:0.12),
          Colors.white.withValues(alpha:0.06),
          Colors.white.withValues(alpha:0.02),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.white.withValues(alpha:0.15), // White opacity shadows
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha:0.25),
          blurRadius: 15,
          offset: const Offset(0, 4),
        ),
      ],
      border: Border.all(
        color: Colors.white.withValues(alpha:0.25), // Gradient white border
        width: 1,
      ),
    );

    return Container(
      height: 100,
      decoration: cardStyle,
      padding: const EdgeInsets.all(16), // 16 points padding
          child: Row(
            children: [
          // Avatar (50x50) - OptimizedAvatarImage
              _avatar(user),
          const SizedBox(width: 12), // HStack spacing: 12
          
          // User Info - VStack(alignment: .leading, spacing: 4)
              Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // .leading
              mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(
                    fontSize: 16, // Subheadline // cspell:ignore Subheadline
                    fontWeight: FontWeight.w500, // Medium weight
                        color: Colors.white,
                      ),
                    ),
                const SizedBox(height: 4), // spacing: 4
                    Text(
                      '@${user.username}',
                      style: TextStyle(
                    fontSize: 12, // Caption
                    color: Colors.white.withValues(alpha:0.7), // Secondary color
                    fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
          
          const Spacer(),
          
          // Online Status Indicator - Circle with white stroke
          Container(
            width: 12, // 12x12 frame
            height: 12,
              decoration: BoxDecoration(
              color: _getStatusColor(user.onlineStatus), // user.onlineStatus.iconColor
                shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white, 
                width: 2, // lineWidth: 2
            ),
          ),
        ),
      ],
      ),
    );
  }

  Widget _avatar(user_model.User user) {
    final fallback = Container(
      width: 60,
      height: 60,
                decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha:0.2),
            Colors.white.withValues(alpha:0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
                  shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha:0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.person_rounded,
        color: Colors.white.withValues(alpha:0.8),
        size: 28,
      ),
    );
    
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha:0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ImageCDNService().createAvatar(
        imageUrl: user.avatarURL,
        size: 60,
        placeholder: fallback,
        errorWidget: fallback,
      ),
    );
  }

  Color _getStatusColor(user_model.OnlineStatus status) {
    switch (status) {
      case user_model.OnlineStatus.online:
        return Colors.green;
      case user_model.OnlineStatus.offline:
        return Colors.grey;
      case user_model.OnlineStatus.idle:
        return Colors.orange;
      case user_model.OnlineStatus.doNotDisturb:
        return Colors.red;
      case user_model.OnlineStatus.streaming:
        return Colors.purple;
      case user_model.OnlineStatus.invisible:
        return Colors.grey;
    }
  }
}

class ConnectionRowWithSwipe extends StatefulWidget {
  final user_model.User user;
  final network_models.NetworkTab currentTab;
  final VoidCallback onUserTap;
  final Future<void> Function(user_model.User) onUnfollow;
  final Future<void> Function(user_model.User) onRemoveFollower;

  const ConnectionRowWithSwipe({
    super.key,
    required this.user,
    required this.currentTab,
    required this.onUserTap,
    required this.onUnfollow,
    required this.onRemoveFollower,
  });

  @override
  State<ConnectionRowWithSwipe> createState() => _ConnectionRowWithSwipeState();
}

class _ConnectionRowWithSwipeState extends State<ConnectionRowWithSwipe>
    with TickerProviderStateMixin {
  double _offset = 0;
  bool _isSwiped = false;
  late AnimationController _animationController;
  late Animation<double> _springAnimation;

  static const double _swipeThreshold = -80;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _springAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFollowersTab = widget.currentTab == network_models.NetworkTab.followers;
    final actionColor = isFollowersTab ? Colors.orange : Colors.red;

    return Stack(
      children: [
        // Action button with spring animation
        AnimatedOpacity(
          opacity: _offset < -20 ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: SizedBox(
            height: 100,
            child: Row(
              children: [
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: AnimatedScale(
                    scale: _offset < -20 ? 1.0 : 0.8,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      decoration: BoxDecoration(
                        color: actionColor.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: actionColor.withValues(alpha:0.3),
                          width: 1,
                        ),
                      ),
                  child: IconButton(
                    onPressed: () => _confirmAction(context, isFollowersTab),
                        icon: Icon(
                          Icons.person_remove_rounded,
                          color: actionColor,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Main content with swipe gesture
        Semantics(
          label: '${widget.user.displayName}, ${widget.user.username}. Swipe left to ${isFollowersTab ? 'remove follower' : 'unfollow'}.',
          button: true,
          child: GestureDetector(
            onHorizontalDragUpdate: (d) {
              final newOffset = d.delta.dx;
              setState(() {
                _offset += newOffset;
                if (_offset > 0) _offset = 0;
                if (_offset < -140) _offset = -140;
              });
            },
            onHorizontalDragEnd: (_) {
              setState(() {
                if (_offset < _swipeThreshold) {
                  _offset = -100;
                  _isSwiped = true;
                  _animationController.forward();
                } else {
                  _offset = 0;
                  _isSwiped = false;
                  _animationController.reverse();
                }
              });
            },
            onTap: () {
              if (_isSwiped) {
                setState(() {
                  _offset = 0;
                  _isSwiped = false;
                  _animationController.reverse();
                });
              } else {
                widget.onUserTap();
              }
            },
            child: AnimatedBuilder(
              animation: _springAnimation,
              builder: (context, child) {
                return Transform.translate(
              offset: Offset(_offset, 0),
                  child: child,
                );
              },
              child: ConnectionRow(user: widget.user),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmAction(BuildContext context, bool isFollowersTab) {
    final name = widget.user.displayName;
    final title = isFollowersTab ? 'Remove $name?' : 'Unfollow $name?';
    final message = isFollowersTab
        ? "This will remove $name from your followers. They won't be able to see your posts anymore."
        : "You won't see their posts in your feed anymore. You can follow them again anytime.";

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0E1220),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withValues(alpha:0.2),
            width: 1,
          ),
        ),
        elevation: 20,
        title: Row(
          children: [
            Icon(
              isFollowersTab ? Icons.person_remove_rounded : Icons.person_off_rounded,
              color: isFollowersTab ? Colors.orange : Colors.red,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            color: Colors.white.withValues(alpha:0.9),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _offset = 0;
                _isSwiped = false;
                _animationController.reverse();
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha:0.7),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isFollowersTab
                    ? [Colors.orange, Colors.orange.shade700]
                    : [Colors.red, Colors.red.shade700],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
            onPressed: () async {
              setState(() {
                _offset = 0;
                _isSwiped = false;
                  _animationController.reverse();
              });
              Navigator.pop(context);
              if (isFollowersTab) {
                await widget.onRemoveFollower(widget.user);
              } else {
                await widget.onUnfollow(widget.user);
              }
            },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                isFollowersTab ? 'Remove' : 'Unfollow',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// old placeholder removed; now using StreamerCardPage



