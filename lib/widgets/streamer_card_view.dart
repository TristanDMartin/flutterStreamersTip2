import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/calendar_event.dart';
import '../providers/status_provider.dart';
import '../models/user_status.dart';
import '../widgets/profile_video_feed_view.dart';
import '../services/enhanced_bookmark_service.dart';
import 'streamer_share_sheet.dart';
import 'instant_response_button.dart';
import 'brand_icons.dart';
import '../services/unified_avatar_service.dart';
import '../services/chat_service.dart';
import '../services/follows_service.dart';
import 'chat_view.dart';

class StreamerCardView extends ConsumerStatefulWidget {
  final String userId; // Changed from StreamerCard to userId for live data
  final String? currentUserId;
  final VoidCallback? onDismiss;
  final Function(String userId)? onFollow;
  final Function(String userId)? onMessage;
  final Function(String userId)? onShare;
  final Function(String tabName)? onNavigateToTab; // New callback for tab navigation

  const StreamerCardView({
    super.key,
    required this.userId,
    this.currentUserId,
    this.onDismiss,
    this.onFollow,
    this.onMessage,
    this.onShare,
    this.onNavigateToTab,
  });

  @override
  ConsumerState<StreamerCardView> createState() => _StreamerCardViewState();
}

class _StreamerCardViewState extends ConsumerState<StreamerCardView> 
    with TickerProviderStateMixin {
  late AnimationController _flipController;
  final FollowsService _followsService = FollowsService();
  late Animation<double> _flipAnimation;
  bool _isFront = true;
  
  // MARK: - State Management
  String _selectedHashtag = "";
  bool _showBio = true;
  bool _showPlatforms = true;
  bool _showCalendar = true;
  final Set<String> _bookmarkedEventIds = {};
  List<Map<String, dynamic>> _platforms = [];
  List<CalendarEvent> _calendarEvents = [];
  
  // Gradient for selected hashtag
  final LinearGradient _selectedHashtagGradient = const LinearGradient(
    colors: [Color(0xFF955CFF), Color(0xFF3D99F7)], // Match ProfileBackView
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  
  // Bookmark service
  late final EnhancedBookmarkService _bookmarkService;
  
  // Real-time data
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _error;
  
  // Relationship states (matching the exact algorithm)
  bool _isFollowing = false;
  bool _isFollowedByStreamer = false;
  bool _isConnected = false;
  
  // Stats
  int _postsCount = 0;
  int _followersCount = 0;
  int _followingCount = 0;
  
  // Tab management
  int _selectedTabIndex = 0; // 0: Video, 1: Favorites, 2: Tagged
  
  // Chat UI State
  bool _showChatView = false;
  Map<String, dynamic>? _selectedChat;
  
  // Firestore listeners for proper cleanup
  StreamSubscription<DocumentSnapshot>? _userDataSubscription;
  StreamSubscription<DocumentSnapshot>? _userStatsSubscription;
  StreamSubscription<QuerySnapshot>? _followersSubscription;
  StreamSubscription<QuerySnapshot>? _followingSubscription;
  StreamSubscription<QuerySnapshot>? _followingRelationshipSubscription;
  StreamSubscription<QuerySnapshot>? _followedByRelationshipSubscription;
  
  // Loading states for async operations
  bool _isFollowingOperation = false;
  bool _isUnfollowingOperation = false;

  @override
  void initState() {
    super.initState();
    _bookmarkService = EnhancedBookmarkService();
    _initializeBookmarks();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _flipAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOut,
    ));
    
    // Load user data first, then relationship status will be checked when user data loads
    _loadUserData();
  }

  // MARK: - Data Loading
  Future<void> _initializeBookmarks() async {
    try {
      await _bookmarkService.initialize();
      await _fetchBookmarkedEventIds();
    } catch (e) {
      if (kDebugMode) {
    // print('❌ StreamerCardView: Error initializing bookmarks: $e');
      }
    }
  }

  Future<void> _fetchBookmarkedEventIds() async {
    try {
      if (kDebugMode) {
    // print('📚 StreamerCardView: Fetching bookmarked event IDs...');
      }
      final bookmarkedIds = await _bookmarkService.fetchBookmarkedEventIds();
      if (kDebugMode) {
    // print('📚 StreamerCardView: Found ${bookmarkedIds.length} bookmarked events: $bookmarkedIds');
      }
      if (mounted) {
        setState(() {
          _bookmarkedEventIds.clear();
          _bookmarkedEventIds.addAll(bookmarkedIds);
        });
      }
    } catch (e) {
      if (kDebugMode) {
    // print('❌ StreamerCardView: Error fetching bookmarked event IDs: $e');
      }
    }
  }

  void _loadUserData() {
    // Cancel existing subscription if any
    _userDataSubscription?.cancel();
    
    _userDataSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        if (snapshot.exists) {
          setState(() {
            _userData = snapshot.data();
            _isLoading = false;
            _error = null;
          });
          _loadStats();
          _checkRelationshipStatus();
          _loadPlatforms();
          _loadCalendarEvents();
        } else {
          // Fall back to sample data for sample users
          _loadSampleUserData();
        }
      }
    }, onError: (error) {
      if (mounted) {
        // Try sample data as fallback
        _loadSampleUserData();
      }
    });
  }

  void _loadSampleUserData() {
    // Sample data for demo users
    final sampleUsers = {
      'user1': {
        'id': 'user1',
        'username': 'streamer1',
        'displayName': 'Streamer One',
        'avatarURL': 'https://i.pravatar.cc/200?img=1',
        'bio': 'Professional gamer and content creator. Love sharing amazing gaming moments! 🎮',
        'hashtags': ['gaming', 'streaming', 'esports'],
        'onlineStatus': 'online',
        'postCount': 42,
        'followerCount': 1250,
        'followingCount': 89,
        'aiSelf': 'Passionate gamer who loves creating content and connecting with the community.',
        'platforms': [
          {'type': 'twitch', 'username': 'streamer1', 'followers': 1250},
          {'type': 'youtube', 'username': 'streamer1', 'followers': 890},
        ],
        'calendarEvents': [
          {
            'id': 'event1',
            'title': 'Gaming Stream',
            'description': 'Playing the latest games with viewers',
            'date': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
          },
        ],
      },
      'user2': {
        'id': 'user2',
        'username': 'streamer2',
        'displayName': 'Streamer Two',
        'avatarURL': 'https://i.pravatar.cc/200?img=2',
        'bio': 'Creative content creator sharing cool tricks and entertaining moments! 🔥',
        'hashtags': ['entertainment', 'tricks', 'fun'],
        'onlineStatus': 'online',
        'postCount': 28,
        'followerCount': 890,
        'followingCount': 156,
        'aiSelf': 'Creative entertainer who loves sharing fun and engaging content.',
        'platforms': [
          {'type': 'tiktok', 'username': 'streamer2', 'followers': 890},
          {'type': 'instagram', 'username': 'streamer2', 'followers': 456},
        ],
        'calendarEvents': [
          {
            'id': 'event2',
            'title': 'Trick Tutorial',
            'description': 'Teaching cool tricks to followers',
            'date': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
          },
        ],
      },
    };

    final sampleData = sampleUsers[widget.userId];
    if (sampleData != null) {
      setState(() {
        _userData = sampleData;
        _isLoading = false;
        _error = null;
      });
      _loadStats();
      _checkRelationshipStatus();
      _loadPlatforms();
      _loadCalendarEvents();
    } else {
      setState(() {
        _error = 'User not found';
        _isLoading = false;
      });
    }
  }

  void _loadStats() {
    if (_userData == null) return;
    
    // Cancel existing subscriptions
    _userStatsSubscription?.cancel();
    _followersSubscription?.cancel();
    _followingSubscription?.cancel();
    
    // Load stats from user document (denormalized counters)
    _userStatsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .snapshots()
        .listen((snapshot) {
      if (mounted && snapshot.exists) {
        final data = snapshot.data()!;
        setState(() {
          _postsCount = data['postCount'] ?? 0;
          _followersCount = data['followerCount'] ?? 0;
          _followingCount = data['followingCount'] ?? 0;
        });
        
        if (kDebugMode) {
          print("📊 StreamerCardView: Stats loaded - Posts: $_postsCount, Followers: $_followersCount, Following: $_followingCount");
        }
      }
    });

    // Also listen to followers collection for real-time updates
    _followersSubscription = FirebaseFirestore.instance
        .collection('follows')
        .where('followedId', isEqualTo: widget.userId)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _followersCount = snapshot.docs.length;
        });
        
        if (kDebugMode) {
          print("📊 StreamerCardView: Followers count updated from follows collection: $_followersCount");
        }
      }
    });

    // Also listen to following collection for real-time updates
    _followingSubscription = FirebaseFirestore.instance
        .collection('follows')
        .where('followerId', isEqualTo: widget.userId)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _followingCount = snapshot.docs.length;
        });
        
        if (kDebugMode) {
          print("📊 StreamerCardView: Following count updated from follows collection: $_followingCount");
        }
      }
    });
  }

  void _checkRelationshipStatus() {
    if (widget.currentUserId == null || widget.currentUserId == widget.userId) {
      if (kDebugMode) {
        print("🔘 StreamerCardView: Skipping relationship check - currentUserId: ${widget.currentUserId}, userId: ${widget.userId}");
      }
      return;
    }
    
    if (kDebugMode) {
      print("🔘 StreamerCardView: Checking relationship status for currentUserId: ${widget.currentUserId}, userId: ${widget.userId}");
    }
    
    // First do an initial check to set the current state
    _checkConnectionStatus().then((_) {
      if (kDebugMode) {
        print("🔘 StreamerCardView: Initial relationship check complete - isFollowing: $_isFollowing, isFollowedByStreamer: $_isFollowedByStreamer, isConnected: $_isConnected");
      }
      
      // Then set up real-time listeners for relationship changes
      _setupRelationshipListeners();
    });
  }

  void _setupRelationshipListeners() {
    // Cancel existing subscriptions
    _followingRelationshipSubscription?.cancel();
    _followedByRelationshipSubscription?.cancel();
    
    if (kDebugMode) {
      print("🔘 StreamerCardView: Setting up relationship listeners");
    }
    
    // Listen for changes in current user's following list
    _followingRelationshipSubscription = FirebaseFirestore.instance
        .collection('follows')
        .where('followerId', isEqualTo: widget.currentUserId)
        .where('followedId', isEqualTo: widget.userId)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        final wasFollowing = _isFollowing;
        setState(() {
          _isFollowing = snapshot.docs.isNotEmpty;
          _updateConnectionStatus();
        });
        
        if (kDebugMode) {
          print("🔄 StreamerCardView: Following listener updated - wasFollowing: $wasFollowing, isFollowing: $_isFollowing, docs count: ${snapshot.docs.length}");
          print("🔄 StreamerCardView: Connection state after following update - isConnected: $_isConnected");
        }
      }
    }, onError: (error) {
      if (kDebugMode) {
        print("❌ StreamerCardView: Error in following relationship listener: $error");
      }
    });

    // Listen for changes in this user's following list (to check if they follow current user)
    _followedByRelationshipSubscription = FirebaseFirestore.instance
        .collection('follows')
        .where('followerId', isEqualTo: widget.userId)
        .where('followedId', isEqualTo: widget.currentUserId)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        final wasFollowedByStreamer = _isFollowedByStreamer;
        setState(() {
          _isFollowedByStreamer = snapshot.docs.isNotEmpty;
          _updateConnectionStatus();
        });
        
        if (kDebugMode) {
          print("🔄 StreamerCardView: Followed by streamer listener updated - wasFollowedByStreamer: $wasFollowedByStreamer, isFollowedByStreamer: $_isFollowedByStreamer, docs count: ${snapshot.docs.length}");
          print("🔄 StreamerCardView: Connection state after followed by update - isConnected: $_isConnected");
        }
      }
    }, onError: (error) {
      if (kDebugMode) {
        print("❌ StreamerCardView: Error in followed by relationship listener: $error");
      }
    });
  }

  void _updateConnectionStatus() {
    final previousConnected = _isConnected;
    _isConnected = _isFollowing && _isFollowedByStreamer;
    
    if (kDebugMode && previousConnected != _isConnected) {
      print("🔄 StreamerCardView: Connection status changed from $previousConnected to $_isConnected");
      print("🔄 StreamerCardView: _isFollowing: $_isFollowing, _isFollowedByStreamer: $_isFollowedByStreamer");
    }
  }

  // MARK: - Computed Properties
  Map<String, dynamic> get userData => _userData ?? {};
  
  String get displayName => userData['displayName'] as String? ?? 'Unknown User';
  String get username => userData['username'] as String? ?? 'unknown';
  String get bio => userData['bio'] as String? ?? '';
  String? get avatarURL => userData['avatarURL'] as String?;
  
  List<String> get hashtags {
    final hashtagsData = userData['hashtags'];
    if (hashtagsData == null) return [];
    
    if (hashtagsData is List<dynamic>) {
      return hashtagsData.cast<String>();
    } else if (hashtagsData is String) {
      return hashtagsData.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList();
    }
    
    return [];
  }
  
  int get selectedHashtagIndex {
    final index = hashtags.indexOf(_selectedHashtag);
    return index >= 0 ? index : 0;
  }
  
  bool get isOwner {
    // For StreamerCardView, visitors should see bookmark buttons, not delete buttons
    // Only allow deletion if explicitly viewing own profile (which should use ProfileView instead)
    // For now, always show bookmark buttons to visitors
    return false;
  }

  @override
  void dispose() {
    _flipController.dispose();
    
    // Cancel all Firestore subscriptions to prevent memory leaks
    _userDataSubscription?.cancel();
    _userStatsSubscription?.cancel();
    _followersSubscription?.cancel();
    _followingSubscription?.cancel();
    _followingRelationshipSubscription?.cancel();
    _followedByRelationshipSubscription?.cancel();
    
    super.dispose();
  }

  @override
  void activate() {
    super.activate();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
  }

  // MARK: - Connection Status
  Future<void> _checkConnectionStatus() async {
    if (widget.currentUserId == null || widget.currentUserId == widget.userId) {
      if (kDebugMode) {
        print("🔘 StreamerCardView: Skipping connection check - currentUserId: ${widget.currentUserId}, userId: ${widget.userId}");
      }
      return;
    }

    if (kDebugMode) {
      print("🔘 StreamerCardView: Checking connection status for currentUserId: ${widget.currentUserId}, userId: ${widget.userId}");
    }

    try {
      // Check if current user is following the streamer
      final isFollowing = await _checkIfFollowing(widget.userId);
      
      // Check if streamer is following the current user
      final isFollowedByStreamer = await _checkIfFollowedBy(widget.userId);
      
      // Connection = mutual follows
      final isConnected = isFollowing && isFollowedByStreamer;
      
      if (kDebugMode) {
        print("🔘 StreamerCardView: Connection check results - isFollowing: $isFollowing, isFollowedByStreamer: $isFollowedByStreamer, isConnected: $isConnected");
      }
      
      if (mounted) {
        setState(() {
          _isFollowing = isFollowing;
          _isFollowedByStreamer = isFollowedByStreamer;
          _isConnected = isConnected;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ StreamerCardView: Error checking connection status: $e");
      }
      if (mounted) {
        setState(() {
          _isFollowing = false;
          _isFollowedByStreamer = false;
          _isConnected = false;
        });
      }
    }
  }

  Future<bool> _checkIfFollowing(String userId) async {
    try {
      // Use FollowsService to check if current user follows the target user
      return await _followsService.isFollowing(userId);
    } catch (e) {
      if (kDebugMode) {
        print('❌ StreamerCardView: Error checking follow status: $e');
      }
      return false;
    }
  }

  Future<bool> _checkIfFollowedBy(String userId) async {
    try {
      // Use FollowsService to check if target user follows the current user
      return await _followsService.isFollowedBy(userId);
    } catch (e) {
      if (kDebugMode) {
        print('❌ StreamerCardView: Error checking followed by status: $e');
      }
      return false;
    }
  }




  Future<void> _toggleBookmark(CalendarEvent event) async {
    HapticFeedback.lightImpact();
    
    final isBookmarked = _bookmarkedEventIds.contains(event.id);
    
    if (kDebugMode) {
    // print('🔖 StreamerCardView: Toggling bookmark for event: ${event.id}');
    // print('🔖 StreamerCardView: Currently bookmarked: $isBookmarked');
    // print('🔖 StreamerCardView: Event title: ${event.title}');
    // print('🔖 StreamerCardView: Event date: ${event.date}');
    // print('🔖 StreamerCardView: Creator ID: ${widget.userId}');
    }
    
    // Check if user is authenticated
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (kDebugMode) {
    // print('❌ StreamerCardView: No authenticated user');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to bookmark events'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    if (kDebugMode) {
    // print('✅ StreamerCardView: User authenticated: ${currentUser.uid}');
    }
    
    // Optimistic UI update
    if (isBookmarked) {
      _bookmarkedEventIds.remove(event.id);
    } else {
      _bookmarkedEventIds.add(event.id);
    }
    setState(() {});
    
    try {
      bool success;
      String message;
      
      if (isBookmarked) {
        // Remove bookmark
        success = await _bookmarkService.deleteBookmark(eventId: event.id);
        message = success ? 'Event removed from bookmarks!' : 'Failed to remove bookmark';
      } else {
        // Add bookmark
        success = await _bookmarkService.bookmarkEvent(
          eventId: event.id,
          creatorId: widget.userId,
          title: event.title,
          startAt: event.date,
          notifyAt: event.date.subtract(const Duration(minutes: 15)),
          source: 'streamer_card',
        );
        message = success ? 'Event saved to your bookmarks! You can view it in the menu.' : 'Failed to save bookmark';
      }
      
      if (!success && mounted) {
        // Revert optimistic update on failure
        if (isBookmarked) {
          _bookmarkedEventIds.add(event.id);
        } else {
          _bookmarkedEventIds.remove(event.id);
        }
        setState(() {});
      }
      
      if (mounted) {
        // Show message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Revert optimistic update on error
      if (isBookmarked) {
        _bookmarkedEventIds.add(event.id);
      } else {
        _bookmarkedEventIds.remove(event.id);
      }
      setState(() {});
      
      if (kDebugMode) {
    // print('❌ StreamerCardView: Error toggling bookmark: $e');
    // print('❌ StreamerCardView: Error type: ${e.runtimeType}');
        if (e is FirebaseException) {
    // print('❌ StreamerCardView: Firebase error code: ${e.code}');
    // print('❌ StreamerCardView: Firebase error message: ${e.message}');
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _deleteEvent(String eventId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0E1220),
        title: const Text(
          'Delete Event',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this event?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement actual event deletion
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Event deleted'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 1),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }


  void _flipCard() {
    if (_isFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    _isFront = !_isFront;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }
    
    if (_error != null) {
      return _buildErrorState();
    }
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBody: true,
        extendBodyBehindAppBar: false, // SAFE AREA FIX: Don't extend behind system UI
        body: Stack(
        children: [
          // Main StreamerCardView
          AnimatedBuilder(
            animation: _flipAnimation,
            builder: (context, child) {
              final isShowingFront = _flipAnimation.value < 0.5;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(_flipAnimation.value * 3.14159),
                child: isShowingFront
                    ? _buildFrontView()
                    : Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(3.14159),
                        child: _buildBackView(),
                      ),
              );
            },
          ),
          // Chat View Overlay (Full Screen Cover)
          if (_showChatView) _buildChatView(),
        ],
      ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Error Loading Profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadUserData();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // Chat View Presentation - Full Screen Cover
  Widget _buildChatView() {
    if (_selectedChat == null) return const SizedBox.shrink();
    
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            // Chat Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1220),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha:0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showChatView = false;
                        _selectedChat = null;
                      });
                    },
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  UnifiedAvatarService().getAvatar(
                    imageUrl: avatarURL ?? '',
                    radius: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '@$username',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha:0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Chat Content Placeholder
            Expanded(
              child: Container(
                color: const Color(0xFF0E1220),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.white.withValues(alpha:0.3),
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chat with $displayName',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha:0.7),
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Chat ID: ${_selectedChat!['id']}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha:0.5),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Chat functionality will be implemented here',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha:0.5),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrontView() {
    return Container( // FIXED: Remove SafeArea to allow manual control
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6137EB), // Purple
              Color(0xFF1C135D), // Dark purple
            ],
          ),
        ),
        child: Column(
          children: [
            _buildTopBar(),
            const SizedBox(height: 8), // Add spacing after top bar
            _buildProfileSection(),
            _buildStatisticsRow(),
            _buildActionButtons(),
            const SizedBox(height: 24), // Spacing between buttons and tabs
            _buildContentTabs(),
            _buildContentArea(),
          ],
        ),
      );
  }

  Widget _buildTopBar() {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back button
              GestureDetector(
                onTap: widget.onDismiss,
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              // Center: No title, clean gradient background
              const SizedBox(width: 40), // Spacer for center
              // Right side action buttons
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _flipCard(),
                    child: const Icon(
                      Icons.flip,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  InstantResponseButton(
                    onPressed: () => _showShareSheet(context),
                    hapticType: HapticFeedbackType.lightImpact,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: const Icon(
                        Icons.more_horiz,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildProfileSection() {
    return Column(
      children: [
        const SizedBox(height: 20), // Add top spacing to match ProfileView
        _buildAvatarWithOnlineIndicator(),
        const SizedBox(height: 16),
        _buildProfileTextInfo(),
        const SizedBox(height: 4), // Minimal spacing to match ProfileView
      ],
    );
  }

  Widget _buildStatisticsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStatItem('Posts', _postsCount.toString()),
          const SizedBox(width: 54),
          _buildStatItem('Followers', _followersCount.toString()),
          const SizedBox(width: 54),
          _buildStatItem('Following', _followingCount.toString()),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha:0.7),
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Follow Button
          Expanded(
            child: _buildGradientPillButton(
              text: _getFollowButtonText(),
              onPressed: _getFollowButtonAction(),
          ),
          ),
          const SizedBox(width: 16),
          // Message Button
          Expanded(
            child: _buildGradientPillButton(
              text: 'Message',
              onPressed: _getMessageButtonAction(),
          ),
          ),
          const SizedBox(width: 16),
          // Share Button
          Expanded(
            child: _buildGradientPillButton(
              text: 'Share',
              onPressed: () => widget.onShare?.call(widget.userId),
            ),
          ),
        ],
      ),
    );
  }

  // MARK: - Gradient Pill Button (Original ProfileView Style)
  Widget _buildGradientPillButton({
    required String text,
    required VoidCallback? onPressed,
  }) {
    final isLoading = text == _getFollowButtonText() && (_isFollowingOperation || _isUnfollowingOperation);
    
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: onPressed != null ? _getFollowButtonGradient() : null,
          color: onPressed == null ? Colors.grey.withValues(alpha:0.3) : null,
          borderRadius: BorderRadius.circular(24),
          border: onPressed == null ? Border.all(color: Colors.grey.withValues(alpha:0.5)) : null,
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
            text,
                  style: TextStyle(
                    color: onPressed != null ? Colors.white : Colors.grey,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // MARK: - Button State Helpers (NetworkView Logic)
  String _getFollowButtonText() {
    // NetworkView-style follow button logic
    if (_isConnected) return 'Connected';
    if (_isFollowing) return 'Following';
    if (_isFollowedByStreamer) return 'Follow back';
    return 'Follow';
  }

  LinearGradient _getFollowButtonGradient() {
    // All follow button states use the same ProfileView edit button gradient
    return const LinearGradient(
      colors: [Color(0xFF955CFF), Color(0xFF3D99F7)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
  }

  VoidCallback? _getFollowButtonAction() {
    // Disable button during operations
    if (_isFollowingOperation || _isUnfollowingOperation) {
      return null;
    }
    return _handleFollowButtonTap;
  }

  VoidCallback? _getMessageButtonAction() {
    if (kDebugMode) {
      print("💬 StreamerCardView: _getMessageButtonAction - _isConnected: $_isConnected, _isFollowing: $_isFollowing, _isFollowedByStreamer: $_isFollowedByStreamer");
    }
    if (_isConnected) return _handleMessage; // Only enabled when connected (mutual follow)
    return null; // Disabled when not connected
  }




  // MARK: - Follow Button Action Handler (Real-time Updates)
  void _handleFollowButtonTap() {
    if (kDebugMode) {
      print("🔘 Follow button tapped for user: ${widget.userId}");
      print("🔘 Current follow state: $_isFollowing");
      print("🔘 Is followed by other: $_isFollowedByStreamer");
      print("🔘 Is connected: $_isConnected");
    }
    
    HapticFeedback.lightImpact();
    
    // Handle button actions based on current relationship state
    if (_isConnected) {
      // Both users follow each other - unfollow the other user
      _handleUnfollow();
    } else if (_isFollowing) {
      // Current user follows the other user - unfollow
      _handleUnfollow();
    } else {
      // No relationship or only the other user follows - follow the other user
      _handleFollow();
    }
  }

  Future<void> _handleFollow() async {
    if (_isFollowingOperation) return; // Prevent multiple simultaneous operations
    
    // Check if currentUserId is available
    if (widget.currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to follow users'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    if (kDebugMode) {
      print("🔘 StreamerCardView: Following user: ${widget.userId}");
      print("🔘 StreamerCardView: Current user ID: ${widget.currentUserId}");
    }
    
    // Store original state for rollback
    final originalFollowingState = _isFollowing;
    
    // Update local state optimistically
    setState(() {
      _isFollowing = true;
      _isFollowingOperation = true;
      _updateConnectionStatus();
    });
    
    // Call the parent callback first
    if (widget.onFollow != null) {
      try {
        await widget.onFollow!(widget.userId);
        
        // If parent callback succeeds, keep the optimistic state
        if (mounted) {
          setState(() {
            _isFollowingOperation = false;
          });
        }
        
        if (kDebugMode) {
          print("🔘 StreamerCardView: Parent follow callback completed successfully");
        }
        return; // Exit early if parent handles it successfully
      } catch (e) {
        if (kDebugMode) {
          print("🔘 StreamerCardView: Parent follow callback failed: $e");
        }
        
        // For demo content, simulate successful follow
        if (e.toString().contains('not-found') && widget.userId.startsWith('user')) {
          if (mounted) {
            setState(() {
              _isFollowingOperation = false;
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Demo: Successfully followed user!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
          return; // Simulate success for demo content
        }
        
        // Fall back to our own implementation for real errors
      }
    }
    
    // Fallback: Handle follow ourselves if no parent callback or it failed
    try {
      if (kDebugMode) {
        print("🔘 StreamerCardView: Starting Firebase follow operation using FollowsService");
      }
      
      // Use FollowsService to follow the user (this updates the 'follows' collection)
      final success = await _followsService.followUser(widget.userId);
      
      if (!success) {
        throw Exception('Failed to follow user via FollowsService');
      }
      
      if (kDebugMode) {
        print("✅ StreamerCardView: Successfully followed user via FollowsService");
      }
      
      // Create follow notification
      await _createFollowNotification();
      
      if (mounted) {
        setState(() {
          _isFollowingOperation = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully followed user!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Navigate to appropriate tab in NetworkView
        _navigateToAppropriateTab();
      }
      
      if (kDebugMode) {
        print("✅ Successfully followed user: ${widget.userId}");
      }
    } catch (error) {
      if (kDebugMode) {
        print("🔘 StreamerCardView: Error following user: $error");
      }
      
      // Rollback optimistic update
      if (mounted) {
        setState(() {
          _isFollowing = originalFollowingState;
          _isFollowingOperation = false;
          _updateConnectionStatus();
        });
      }
      
      // Show appropriate error message based on error type
      if (mounted) {
        String errorMessage = 'Failed to follow user';
        if (error.toString().contains('not-found')) {
          errorMessage = 'User not found (demo content)';
        } else if (error.toString().contains('permission-denied')) {
          errorMessage = 'Permission denied';
        } else if (error.toString().contains('network')) {
          errorMessage = 'Network error';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleUnfollow() async {
    if (_isUnfollowingOperation) return; // Prevent multiple simultaneous operations
    
    if (kDebugMode) {
      print("🔘 StreamerCardView: Unfollowing user: ${widget.userId}");
      print("🔘 StreamerCardView: Current state - _isFollowing: $_isFollowing, _isFollowedByStreamer: $_isFollowedByStreamer, _isConnected: $_isConnected");
    }
    
    // Store original state for rollback
    final originalFollowingState = _isFollowing;
    
    // Update local state optimistically
    setState(() {
      _isFollowing = false;
      _isUnfollowingOperation = true;
      _updateConnectionStatus();
    });
    
    if (kDebugMode) {
      print("🔘 StreamerCardView: After optimistic update - _isFollowing: $_isFollowing, _isConnected: $_isConnected");
    }
    
    try {
      // Use FollowsService to unfollow the user (this updates the 'follows' collection)
      final success = await _followsService.unfollowUser(widget.userId);
      
      if (!success) {
        throw Exception('Failed to unfollow user via FollowsService');
      }
      
      if (kDebugMode) {
        print("✅ StreamerCardView: Successfully unfollowed user via FollowsService");
      }
      
      // Remove follow notification
      await _removeFollowNotification();
      
      if (kDebugMode) {
        print("✅ Successfully unfollowed user: ${widget.userId}");
        print("🔘 StreamerCardView: Final state after unfollow - _isFollowing: $_isFollowing, _isFollowedByStreamer: $_isFollowedByStreamer, _isConnected: $_isConnected");
      }
      
      // Navigate to appropriate tab in NetworkView
      _navigateToAppropriateTab();
    } catch (error) {
      if (kDebugMode) {
    // print("❌ Error unfollowing user: $error");
      }
      
      // Rollback optimistic update
      setState(() {
        _isFollowing = originalFollowingState;
        _updateConnectionStatus();
      });
      
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unfollow user: ${error.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _handleUnfollow(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUnfollowingOperation = false;
        });
      }
    }
  }

  void _handleMessage() {
    if (kDebugMode) {
      print("💬 StreamerCardView: _handleMessage called - _isConnected: $_isConnected, _isFollowing: $_isFollowing, _isFollowedByStreamer: $_isFollowedByStreamer");
    }
    
    HapticFeedback.lightImpact();
    
    // Check if users are connected (mutual follow)
    if (!_isConnected) {
      if (kDebugMode) {
        print("💬 StreamerCardView: Users are not connected, showing error message");
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can only message users you are connected with'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    if (kDebugMode) {
      print("💬 StreamerCardView: Users are connected, proceeding with message");
    }
    
    // Call the parent callback first
    widget.onMessage?.call(widget.userId);
    
    // Navigate to chat view
    _navigateToChat();
  }

  Future<void> _navigateToChat() async {
    try {
      // Import the necessary services
      final chatService = ChatService.shared;
      final currentUser = FirebaseAuth.instance.currentUser;
      
      if (kDebugMode) {
        print("💬 StreamerCardView: Starting chat navigation for user: ${widget.userId}");
        print("💬 StreamerCardView: Current user: ${currentUser?.uid}");
        print("💬 StreamerCardView: User data: $_userData");
      }
      
      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in to send messages'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        );
      }

      // Create or fetch chat
      final chat = await chatService.fetchOrCreateChat(widget.userId);
      
      if (kDebugMode) {
        print("💬 StreamerCardView: Chat created/fetched: $chat");
      }
      
      // Hide loading indicator
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      if (chat != null && mounted) {
        // Get user data for the chat view
        final otherUserName = _userData?['displayName'] ?? _userData?['username'] ?? 'Unknown User';
        final otherUserAvatarURL = _userData?['avatarURL'] ?? _userData?['profileImageURL'] ?? '';
        final otherUserIsOnline = _userData?['isOnline'] ?? _userData?['onlineStatus'] == 'online' ?? false;
        
        if (kDebugMode) {
          print("💬 StreamerCardView: Navigating to chat with:");
          print("💬 StreamerCardView: - Name: $otherUserName");
          print("💬 StreamerCardView: - Avatar: $otherUserAvatarURL");
          print("💬 StreamerCardView: - Online: $otherUserIsOnline");
        }
        
        // Navigate to chat view
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatView(
              chat: chat,
              otherUserName: otherUserName,
              otherUserAvatarURL: otherUserAvatarURL,
              otherUserIsOnline: otherUserIsOnline,
            ),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to start conversation'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
        
        if (kDebugMode) {
          print("💬 StreamerCardView: Failed to create/fetch chat - chat is null");
        }
      }
    } catch (e) {
      // Hide loading indicator if still showing
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting conversation: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      if (kDebugMode) {
        print("💬 StreamerCardView: Error starting conversation: $e");
      }
    }
  }

  void _navigateToAppropriateTab() {
    if (widget.onNavigateToTab == null) return;
    
    // Determine which tab to navigate to based on current relationship state
    if (_isConnected) {
      // Both users follow each other - go to Connections tab
      widget.onNavigateToTab!('connections');
      if (kDebugMode) {
        print("🔘 StreamerCardView: Navigating to Connections tab (mutual follow)");
      }
    } else if (_isFollowing) {
      // Current user follows the other user - go to Following tab
      widget.onNavigateToTab!('following');
      if (kDebugMode) {
        print("🔘 StreamerCardView: Navigating to Following tab");
      }
    } else if (_isFollowedByStreamer) {
      // Other user follows current user - go to Followers tab
      widget.onNavigateToTab!('followers');
      if (kDebugMode) {
        print("🔘 StreamerCardView: Navigating to Followers tab");
      }
    } else {
      // No relationship - go to Following tab (where they'll be added)
      widget.onNavigateToTab!('following');
      if (kDebugMode) {
        print("🔘 StreamerCardView: Navigating to Following tab (new follow)");
      }
    }
  }

  // MARK: - Video Navigation
  
  void _navigateToPlayerScreen(ProfileVideoFeedType feedType) {
    try {
      // For now, we'll navigate to a simple player screen
      // In a real implementation, you would pass the actual video data
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              title: Text(_getFeedTypeTitle(feedType)),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.play_circle_outline,
                    color: Colors.white,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Video Player',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Feed Type: ${_getFeedTypeTitle(feedType)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'User: $displayName',
            style: const TextStyle(
                      color: Colors.white70,
              fontSize: 16,
                    ),
                  ),
                ],
            ),
          ),
        ),
      ),
    );
    } catch (e) {
      if (kDebugMode) {
    // print("❌ Error navigating to player screen: $e");
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening video player: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  String _getFeedTypeTitle(ProfileVideoFeedType feedType) {
    switch (feedType) {
      case ProfileVideoFeedType.videos:
        return 'Videos';
      case ProfileVideoFeedType.favorites:
        return 'Favorites';
      case ProfileVideoFeedType.tagged:
        return 'Tagged';
    }
  }

  // MARK: - Helper Methods for Follow/Unfollow Operations
  
  Future<void> _createFollowNotification() async {
    try {
      if (kDebugMode) {
        print("🔘 StreamerCardView: Creating follow notification");
      }
      
      final notificationDoc = await FirebaseFirestore.instance
          .collection('notifications')
          .add({
        'userId': widget.userId,
        'type': 'follow',
        'fromUserId': widget.currentUserId!,
        'fromUserName': 'Current User', // TODO: Get actual user name
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
      
      if (kDebugMode) {
        print("✅ StreamerCardView: Successfully created follow notification: ${notificationDoc.id}");
      }
    } catch (error) {
      if (kDebugMode) {
        print("❌ StreamerCardView: Error creating follow notification: $error");
      }
      // Don't throw here - notification is not critical for follow operation
    }
  }
  
  Future<void> _removeFollowNotification() async {
    try {
      final notificationQuery = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: widget.userId)
          .where('type', isEqualTo: 'follow')
          .where('fromUserId', isEqualTo: widget.currentUserId!)
          .get();
      
      for (final doc in notificationQuery.docs) {
        await doc.reference.delete();
      }
    } catch (error) {
      if (kDebugMode) {
    // print("❌ Error removing follow notification: $error");
      }
      // Don't throw here - notification cleanup is not critical
    }
  }









  Widget _buildContentTabs() {
    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(24),
          border: Border.all(
          color: Colors.white.withValues(alpha:0.15),
            width: 1,
          ),
        ),
        child: Row(
          children: [
          _buildTab('Video', 0),
          _buildTab('Favorites', 1),
          _buildTab('Tagged', 2),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTabIndex == index;
    
    return Expanded(
      child: GestureDetector(
      onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
      },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: isSelected ? Colors.white.withValues(alpha:0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: isSelected
                ? Border.all(
                    color: Colors.white.withValues(alpha:0.25),
                    width: 1,
                  )
                : null,
        ),
        child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
            style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withValues(alpha:0.7),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentArea() {
    return Expanded(
      child: _buildVideoFeed(),
    );
  }

  Widget _buildVideoFeed() {
    switch (_selectedTabIndex) {
      case 0: // Video
        return ProfileVideoFeedView(
          userId: widget.userId,
          feedType: ProfileVideoFeedType.videos,
          onVideoTap: () {
            _navigateToPlayerScreen(ProfileVideoFeedType.videos);
          },
        );
      case 1: // Favorites
        return ProfileVideoFeedView(
          userId: widget.userId,
          feedType: ProfileVideoFeedType.favorites,
          onVideoTap: () {
            _navigateToPlayerScreen(ProfileVideoFeedType.favorites);
          },
        );
      case 2: // Tagged
        return ProfileVideoFeedView(
          userId: widget.userId,
          feedType: ProfileVideoFeedType.tagged,
          onVideoTap: () {
            _navigateToPlayerScreen(ProfileVideoFeedType.tagged);
          },
        );
      default:
        return const Center(
        child: Text(
            'No content available',
            style: TextStyle(color: Colors.white70),
          ),
        );
    }
  }

  Widget _buildAvatarWithOnlineIndicator() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                Color(0xFFFF6CAB),
                Color(0xFF8E54E9),
                Color(0xFF3D99F7),
                Color(0xFFFF6CAB),
              ],
            ),
          ),
          child: Center(
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.2),
              ),
              child: ClipOval(
                child: avatarURL != null && avatarURL!.isNotEmpty
                    ? Image.network(
                        avatarURL!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 48,
                        ),
                      )
                    : const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 48,
                      ),
              ),
            ),
          ),
        ),
        // Online status indicator - show based on real-time status
        Consumer(
          builder: (context, ref, child) {
            final statusAsync = ref.watch(userStatusProvider(widget.userId));
            
            return statusAsync.when(
              data: (presence) {
                if (presence.status != UserStatus.offline) {
                  return Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _getStatusColor(presence.status),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: _getStatusColor(presence.status).withValues(alpha:0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              loading: () => const SizedBox.shrink(),
              error: (error, stack) => const SizedBox.shrink(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProfileTextInfo() {
    return Column(
      children: [
        Text(
          displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '@$username',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }





  Widget _buildBackView() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF6137EB),
            Color(0xFF1C135D),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          // Header with navigation buttons
          _buildHeader(),
          // Main content
          Padding(
            padding: const EdgeInsets.only(top: 80), // Space for the header buttons
            child: CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(child: _buildIdentity()),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(child: _buildTags()),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                SliverToBoxAdapter(child: _buildSectionHeader('Bio', _showBio, () => setState(() => _showBio = !_showBio))),
                if (_showBio) SliverToBoxAdapter(child: _buildBioBody()),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                SliverToBoxAdapter(child: _buildSectionHeader('Platforms', _showPlatforms, () => setState(() => _showPlatforms = !_showPlatforms))),
                if (_showPlatforms) SliverToBoxAdapter(child: _buildPlatforms(_platforms)),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                SliverToBoxAdapter(child: _buildSectionHeader('Calendar', _showCalendar, () => setState(() => _showCalendar = !_showCalendar))),
                if (_showCalendar) SliverToBoxAdapter(child: _buildCalendar(_calendarEvents)),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
            ),
          ],
        ),
      );
  }



  Widget _buildHeader() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              onPressed: _flipCard,
              icon: const Icon(Icons.flip, color: Colors.white, size: 24),
              tooltip: 'Flip',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentity() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _SmallAvatar(imageUrl: _userData?['avatarURL']),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userData?['displayName'] ?? 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${_userData?['username'] ?? 'username'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha:0.75),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTags() {
    final hashtagsData = _userData?['hashtags'];
    List<String> hashtags = [];
    
    if (hashtagsData != null) {
      if (hashtagsData is List) {
        hashtags = hashtagsData.map((tag) => tag.toString()).toList();
      } else if (hashtagsData is String) {
        // If it's a string, split by comma or space
        hashtags = hashtagsData.split(RegExp(r'[,\s]+')).where((tag) => tag.isNotEmpty).toList();
      }
    }
    
    if (hashtags.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: hashtags.map((hashtag) {
                final isSelected = _selectedHashtag == hashtag;
          return GestureDetector(
                    onTap: () {
                      setState(() {
                _selectedHashtag = isSelected ? "" : hashtag;
                      });
                    },
                    child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                gradient: isSelected ? _selectedHashtagGradient : null,
                color: isSelected ? null : Colors.white.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                  color: Colors.white.withValues(alpha:0.2),
                  width: 1,
                        ),
                      ),
                      child: Text(
                        '#$hashtag',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
        }).toList(),
      ),
    );
  }

  Widget _buildBioBody() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        _userData?['bio'] ?? 'No bio available',
            style: TextStyle(
          color: Colors.white.withValues(alpha: 0.75),
              fontSize: 16,
          fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildPlatforms(List<Map<String, dynamic>> platforms) {
    debugPrint('🔗 _buildPlatforms: Building platforms section with ${platforms.length} platforms');
    if (platforms.isEmpty) {
      debugPrint('🔗 _buildPlatforms: No platforms found, showing empty state');
    return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Text(
          'No platforms added yet.',
                  style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 16,
            fontWeight: FontWeight.w500,
                    ),
                  ),
                );
    }
    
    return Padding(
      padding: const EdgeInsets.only(top: 8),
                child: Column(
                  children: [
          for (final platform in platforms)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              child: _ClickablePlatformRow(
                platform: platform,
                onTap: () => _launchPlatformUrl(platform),
                      ),
                    ),
                  ],
      ),
    );
  }

  Widget _buildCalendar(List<CalendarEvent> events) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (events.isEmpty)
            const _EmptyStateWidget(
              icon: Icons.event,
              message: 'No upcoming events',
            )
          else ...[
            // Show first 5 events
            ...events.take(5).map((event) => _buildCalendarRow(event)),
            // Show "+X more..." if there are more than 5 events
                            if (events.length > 5) ...[
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  '+${events.length - 5} more…',
                  style: const TextStyle(
                    color: Color(0x80FFFFFF),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isExpanded, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: onTap,
            child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
              title,
              style: const TextStyle(
                                        color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            Icon(
              isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
              color: Colors.white.withValues(alpha: 0.9),
                    size: 24,
                ),
              ],
            ),
      ),
    );
  }







  Widget _buildCalendarRow(CalendarEvent event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.description,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatEventTime(event.date),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // MARK: - Role-based Actions (Owner vs Visitor)
          if (isOwner) ...[
            // Owner sees trash button for deletion
            GestureDetector(
              onTap: () => _deleteEvent(event.id),
              child: const Icon(
                Icons.delete,
                color: Colors.red,
                size: 20,
              ),
            ),
          ] else ...[
            // Visitors see bookmark button
            GestureDetector(
              onTap: () => _toggleBookmark(event),
              child: Icon(
                _bookmarkedEventIds.contains(event.id) 
                    ? Icons.bookmark 
                    : Icons.bookmark_border,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }





  String _formatEventTime(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;
    
    if (difference == 0) {
      return 'Today · ${_formatTime(date)}';
    } else if (difference == 1) {
      return 'Tomorrow · ${_formatTime(date)}';
    } else if (difference == -1) {
      return 'Yesterday · ${_formatTime(date)}';
    } else {
      return '${_formatDate(date)} · ${_formatTime(date)}';
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $period';
  }


  Color _getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return const Color(0xFF4CAF50); // Green
      case UserStatus.offline:
        return const Color(0xFF9E9E9E); // Grey
      case UserStatus.busy:
        return const Color(0xFFFF9800); // Orange
      case UserStatus.dnd:
        return const Color(0xFFF44336); // Red
      case UserStatus.streaming:
        return const Color(0xFF9C27B0); // Purple
    }
  }

  void _loadPlatforms() {
    debugPrint('🔗 _loadPlatforms: Starting to load platforms');
    if (_userData != null && _userData!['platforms'] != null) {
      debugPrint('🔗 _loadPlatforms: User data has platforms field');
      try {
        final platformsData = _userData!['platforms'];
        debugPrint('🔗 _loadPlatforms: Platforms data: $platformsData');
        if (platformsData is List) {
          debugPrint('🔗 _loadPlatforms: Platforms is a List with ${platformsData.length} items');
          setState(() {
            _platforms = platformsData.map((platform) {
              if (platform is Map<String, dynamic>) {
                return {
                  'id': platform['id']?.toString() ?? '',
                  'type': platform['type']?.toString() ?? '',
                  'username': platform['username']?.toString() ?? '',
                  'followers': (platform['followers'] as num?)?.toInt() ?? 0,
                  'url': platform['url']?.toString(),
                };
              }
              return null;
            }).where((platform) => platform != null).cast<Map<String, dynamic>>().toList();
          });
        } else {
          // If platforms is not a list, initialize as empty
          setState(() {
            _platforms = [];
          });
        }
      } catch (e) {
        if (kDebugMode) {
    // print('Error loading platforms: $e');
        }
        setState(() {
          _platforms = [];
        });
      }
    }
  }

  void _loadCalendarEvents() {
    if (_userData != null && _userData!['calendarEvents'] != null) {
      try {
        final eventsData = _userData!['calendarEvents'];
        if (eventsData is List) {
          setState(() {
            _calendarEvents = eventsData.map((eventData) {
              if (eventData is Map<String, dynamic> && 
                  eventData['id'] != null && 
                  eventData['title'] != null && 
                  eventData['description'] != null && 
                  eventData['date'] != null) {
                try {
                  return CalendarEvent(
                    id: eventData['id'] as String,
                    title: eventData['title'] as String,
                    description: eventData['description'] as String,
                    date: (eventData['date'] as Timestamp).toDate(),
                  );
                } catch (e) {
                  if (kDebugMode) {
    // print('Error creating CalendarEvent: $e');
                  }
                  return null;
                }
              }
              return null;
            }).where((event) => event != null).cast<CalendarEvent>().toList();
          });
        } else {
          // If calendarEvents is not a list, initialize as empty
          setState(() {
            _calendarEvents = [];
          });
        }
      } catch (e) {
        if (kDebugMode) {
    // print('Error loading calendar events: $e');
        }
        setState(() {
          _calendarEvents = [];
        });
      }
    }
  }

  void _launchPlatformUrl(Map<String, dynamic> platform) async {
    final url = platform['url'] as String?;
    debugPrint('🔗 StreamerCardView: Attempting to launch URL: $url');
    
    if (url != null && url.isNotEmpty) {
      try {
        final uri = Uri.parse(url);
        debugPrint('🔗 StreamerCardView: Parsed URI: $uri');
        
        final canLaunch = await canLaunchUrl(uri);
        debugPrint('🔗 StreamerCardView: Can launch URL: $canLaunch');
        
        if (canLaunch) {
          debugPrint('🔗 StreamerCardView: Launching URL...');
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          debugPrint('🔗 StreamerCardView: URL launched successfully');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Opening ${_getPlatformDisplayName(platform['type'])}...'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          debugPrint('🔗 StreamerCardView: Cannot launch URL');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not open platform URL'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('🔗 StreamerCardView: Error launching URL: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error opening URL: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      debugPrint('🔗 StreamerCardView: No URL provided');
    }
  }

  String _getPlatformDisplayName(String platformType) {
    switch (platformType.toLowerCase()) {
      case 'twitch': return 'Twitch';
      case 'youtube': return 'YouTube';
      case 'kick': return 'Kick';
      case 'tiktok': return 'TikTok';
      case 'facebook': return 'Facebook';
      case 'bluesky': return 'Bluesky';
      case 'twitter': return 'Twitter';
      case 'instagram': return 'Instagram';
      case 'reddit': return 'Reddit';
      case 'discord': return 'Discord';
      case 'other': return 'Website';
      default: return platformType;
    }
  }

  void _showShareSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => StreamerShareSheet(
        userId: widget.userId,
        displayName: _userData?['displayName'] as String?,
        profileImageUrl: _userData?['photoURL'] as String?,
        onDismiss: () {
          // Don't call Navigator.pop() here as it's already handled in the X button
          // This prevents double pop which causes black screen
        },
      ),
    );
  }

}

// MARK: - Calendar Event Sheet
class CalendarEventSheet extends StatefulWidget {
  final Function(CalendarEvent) onSave;

  const CalendarEventSheet({
    super.key,
    required this.onSave,
  });

  @override
  State<CalendarEventSheet> createState() => _CalendarEventSheetState();
}

class _CalendarEventSheetState extends State<CalendarEventSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Calendar Event',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Event Title',
              labelStyle: TextStyle(color: Colors.white.withValues(alpha:0.7)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha:0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha:0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF9248D2)),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha:0.1),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Description (Optional)',
              labelStyle: TextStyle(color: Colors.white.withValues(alpha:0.7)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha:0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha:0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF9248D2)),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha:0.1),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withValues(alpha:0.3)),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withValues(alpha:0.1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha:0.7),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: _selectTime,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withValues(alpha:0.3)),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withValues(alpha:0.1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Time',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha:0.7),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedTime.format(context),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9248D2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Save Event'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF9248D2),
              onPrimary: Colors.white,
              surface: Color(0xFF0E1220),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF9248D2),
              onPrimary: Colors.white,
              surface: Color(0xFF0E1220),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }

  void _saveEvent() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an event title'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final event = CalendarEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      date: DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      ),
    );

    widget.onSave(event);
    Navigator.pop(context);
  }
}

class _SmallAvatar extends StatelessWidget {
  final String? imageUrl;
  const _SmallAvatar({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [Color(0xFFFF6CAB), Color(0xFF8E54E9), Color(0xFF3D99F7), Color(0xFFFF6CAB)],
        ),
      ),
      child: Center(
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.2),
          ),
          child: ClipOval(
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? Image.network(imageUrl!, fit: BoxFit.cover)
                : const Icon(Icons.person, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}

class _ClickablePlatformRow extends StatelessWidget {
  final Map<String, dynamic> platform;
  final VoidCallback onTap;

  const _ClickablePlatformRow({
    required this.platform,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final platformType = platform['type'] as String? ?? '';
    final username = platform['username'] as String? ?? '';
    // final url = platform['url'] as String? ?? '';

    debugPrint('🔗 _ClickablePlatformRow: Building platform card - type: $platformType, username: $username');

    return GestureDetector(
      onTap: () {
        debugPrint('🔗 _ClickablePlatformRow: Platform card tapped!');
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            BrandIcon(
              platformType: platformType,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getPlatformDisplayName(platformType),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (username.isNotEmpty)
                    Text(
                      '@$username',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }


  String _getPlatformDisplayName(String platformType) {
    switch (platformType.toLowerCase()) {
      case 'twitch':
        return 'Twitch';
      case 'youtube':
        return 'YouTube';
      case 'kick':
        return 'Kick';
      case 'tiktok':
        return 'TikTok';
      case 'facebook':
        return 'Facebook';
      case 'twitter':
        return 'Twitter';
      case 'instagram':
        return 'Instagram';
      default:
        return platformType;
    }
  }
}

class _EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyStateWidget({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.4),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
