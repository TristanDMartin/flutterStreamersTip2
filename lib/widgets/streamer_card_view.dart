import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
import '../providers/follows_provider.dart';
import '../services/user_blocking_service.dart';
import '../services/global_playback_manager.dart';
import 'chat_view.dart';

class StreamerCardView extends ConsumerStatefulWidget {
  final String userId; // Changed from StreamerCard to userId for live data
  final String? currentUserId;
  final VoidCallback? onDismiss;
  final Function(String userId)? onFollow;
  final Function(String userId)? onMessage;
  final Function(String userId)? onShare;
  final Function(String tabName)?
      onNavigateToTab; // New callback for tab navigation

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
  late final FollowsService _followsService;
  late final GlobalPlaybackManager _playbackManager;
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

  // Blocking service
  late final UserBlockingService _blockingService;

  // Real-time data
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _error;

  // Relationship states (matching the exact algorithm)
  bool _isFollowing = false;
  bool _isFollowedByStreamer = false;
  bool _isConnected = false;
  bool _isFollowingPrimary = false;
  bool _isFollowingLegacy = false;
  bool _isFollowedByPrimary = false;
  bool _isFollowedByLegacy = false;
  bool _isFollowedByPrimaryReady = false;
  bool _isFollowedByLegacyReady = false;
  bool _isFollowedByLegacyAltReady = false;

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
  StreamSubscription<QuerySnapshot>? _followingRelationshipPrimarySubscription;
  StreamSubscription<QuerySnapshot>? _followedByRelationshipPrimarySubscription;
  StreamSubscription<QuerySnapshot>?
      _followingRelationshipLegacyAltSubscription;
  StreamSubscription<QuerySnapshot>?
      _followedByRelationshipLegacyAltSubscription;

  // Loading states for async operations
  bool _isFollowingOperation = false;
  bool _isUnfollowingOperation = false;

  // ✅ FIX #6: Debouncing timer for batched rebuilds
  Timer? _rebuildDebouncer;

  @override
  void initState() {
    super.initState();

    // Initialize FollowsService with EventTriggerService for notifications
    _followsService = ref.read(followsServiceProvider);
    _playbackManager = GlobalPlaybackManager.instance;
    _playbackManager.pauseAll();

    // Debug Firestore data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _debugFirestoreData();
    });

    _bookmarkService = EnhancedBookmarkService();
    _blockingService = UserBlockingService();
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

    // ✅ FIX #4: Schedule async load to avoid blocking initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint(
          '🔍 StreamerCardView: User ID from NetworkView: ${widget.userId}');
      debugPrint(
          '🔍 StreamerCardView: User ID length: ${widget.userId.length}');

      // Check if this looks like a Firebase UID (long string)
      if (widget.userId.length > 20) {
        debugPrint(
            '🔍 StreamerCardView: Detected Firebase UID, trying to find user by ID first');
        _loadUserData();
      } else {
        debugPrint('🔍 StreamerCardView: Short user ID, trying direct load');
        _loadUserData();
      }
    });
  }

  // MARK: - Data Loading
  Future<void> _searchUserByUsernameOrDisplayName() async {
    debugPrint(
        '🔍 StreamerCardView: Searching for user by username or display name...');

    try {
      // Search for users with username containing 'buzzz' or display name containing 'buzzz'
      final usernameQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: 'buzzz')
          .get();

      final displayNameQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('displayName', isEqualTo: 'BuzZz')
          .get();

      debugPrint(
          '🔍 StreamerCardView: Username query results: ${usernameQuery.docs.length}');
      debugPrint(
          '🔍 StreamerCardView: Display name query results: ${displayNameQuery.docs.length}');

      if (usernameQuery.docs.isNotEmpty) {
        final userData = usernameQuery.docs.first.data();
        debugPrint(
            '✅ StreamerCardView: Found user by username: ${userData['displayName']}');
        _loadUserDataFromMap(userData);
        return;
      }

      if (displayNameQuery.docs.isNotEmpty) {
        final userData = displayNameQuery.docs.first.data();
        debugPrint(
            '✅ StreamerCardView: Found user by display name: ${userData['displayName']}');
        _loadUserDataFromMap(userData);
        return;
      }

      // If still not found, try broader search
      final broadQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: 'buzz')
          .where('username', isLessThan: 'buzzz' + '\uf8ff')
          .get();

      debugPrint(
          '🔍 StreamerCardView: Broad search results: ${broadQuery.docs.length}');

      if (broadQuery.docs.isNotEmpty) {
        final userData = broadQuery.docs.first.data();
        debugPrint(
            '✅ StreamerCardView: Found user by broad search: ${userData['displayName']}');
        _loadUserDataFromMap(userData);
        return;
      }

      // If still not found, fall back to sample data
      debugPrint(
          '❌ StreamerCardView: No user found in Firestore, using sample data');
      _loadSampleUserData();
    } catch (e) {
      debugPrint('❌ StreamerCardView: Error searching for user: $e');
      _loadSampleUserData();
    }
  }

  void _loadUserDataFromMap(Map<String, dynamic> userData) {
    if (mounted) {
      setState(() {
        _userData = userData;
        _isLoading = false;
        _error = null;
      });
      _loadStats();
      _checkRelationshipStatus();
      _loadPlatforms();
      _loadCalendarEvents();
      _updateFollowButtonState();
    }
  }

  Future<void> _initializeBookmarks() async {
    try {
      await _bookmarkService.initialize();
      await _fetchBookmarkedEventIds();
    } catch (e) {
      if (kDebugMode) {
        // debugPrint('❌ StreamerCardView: Error initializing bookmarks: $e');
      }
    }
  }

  Future<void> _fetchBookmarkedEventIds() async {
    try {
      if (kDebugMode) {
        // debugPrint('📚 StreamerCardView: Fetching bookmarked event IDs...');
      }
      final bookmarkedIds = await _bookmarkService.fetchBookmarkedEventIds();
      if (kDebugMode) {
        // debugPrint('📚 StreamerCardView: Found ${bookmarkedIds.length} bookmarked events: $bookmarkedIds');
      }
      if (mounted) {
        setState(() {
          _bookmarkedEventIds.clear();
          _bookmarkedEventIds.addAll(bookmarkedIds);
        });
      }
    } catch (e) {
      if (kDebugMode) {
        // debugPrint('❌ StreamerCardView: Error fetching bookmarked event IDs: $e');
      }
    }
  }

  Future<void> _loadUserData() async {
    // ✅ FIX #4: Wait for existing subscription to fully cancel to prevent race conditions
    await _userDataSubscription?.cancel();
    _userDataSubscription = null;

    // Small delay to ensure cleanup
    await Future.delayed(const Duration(milliseconds: 50));

    debugPrint(
        '🔍 StreamerCardView: Loading user data for userId: ${widget.userId}');

    // Set a timeout to prevent infinite loading
    Timer(const Duration(seconds: 3), () {
      if (mounted && _isLoading) {
        debugPrint('⏰ StreamerCardView: Timeout reached, using sample data');
        _loadSampleUserData();
      }
    });

    _userDataSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        if (snapshot.exists) {
          debugPrint(
              '✅ StreamerCardView: Found user in Firestore: ${widget.userId}');
          // ✅ FIX #2: Update data WITHOUT triggering setState yet
          _userData = snapshot.data();
          _isLoading = false;
          _error = null;

          // Load all dependent data synchronously (no setState in these methods)
          _loadStats();
          _checkRelationshipStatus();
          _loadPlatforms();
          _loadCalendarEvents();
          _updateFollowButtonState();

          // ✅ Single setState at the end to trigger one rebuild
          setState(() {
            // Data already updated above, this just triggers rebuild
          });
        } else {
          debugPrint(
              '⚠️ StreamerCardView: User not found in Firestore: ${widget.userId}, trying alternative search');
          // Try to find user by username or display name as fallback
          _searchUserByUsernameOrDisplayName();
        }
      }
    }, onError: (error) {
      debugPrint('❌ StreamerCardView: Error loading user data: $error');
      if (mounted) {
        // Try alternative search first, then sample data
        _searchUserByUsernameOrDisplayName();
      }
    });
  }

  void _loadSampleUserData() {
    debugPrint(
        '❌ StreamerCardView: No Firestore profile found for ${widget.userId}. Showing user-not-found message.');

    if (!mounted) return;

    setState(() {
      _userData = null;
      _isLoading = false;
      _error =
          'User not found. This account may not have completed profile setup yet.';
    });
  }

  void _loadStats() {
    if (_userData == null) return;

    // ✅ MATCHED TO PROFILEVIEW: Use live queries from follows collection
    // This ensures real-time accuracy and matches ProfileView behavior

    // Cancel existing subscriptions to prevent memory leaks
    _userStatsSubscription?.cancel();
    _followersSubscription?.cancel();
    _followingSubscription?.cancel();

    // Load posts count from user document (denormalized)
    _userStatsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .snapshots()
        .listen((snapshot) {
      if (mounted && snapshot.exists) {
        final data = snapshot.data()!;
        setState(() {
          _postsCount = data['postCount'] ?? 0;
        });

        if (kDebugMode) {
          debugPrint("📊 StreamerCardView: Posts count loaded: $_postsCount");
        }
      }
    });

    // ✅ MATCHED TO PROFILEVIEW: Live followers count from follows collection
    _followersSubscription = FirebaseFirestore.instance
        .collection('follows')
        .where('followedId', isEqualTo: widget.userId)
        .snapshots()
        .listen(
      (snapshot) {
        if (mounted) {
          setState(() {
            _followersCount = snapshot.docs.length;
          });

          if (kDebugMode) {
            debugPrint(
                "📊 StreamerCardView: Followers count updated: $_followersCount");
          }
        }
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint('❌ StreamerCardView: Error watching followers: $error');
        }
      },
      cancelOnError: false,
    );

    // ✅ MATCHED TO PROFILEVIEW: Live following count from follows collection
    _followingSubscription = FirebaseFirestore.instance
        .collection('follows')
        .where('followerId', isEqualTo: widget.userId)
        .snapshots()
        .listen(
      (snapshot) {
        if (mounted) {
          setState(() {
            _followingCount = snapshot.docs.length;
          });

          if (kDebugMode) {
            debugPrint(
                "📊 StreamerCardView: Following count updated: $_followingCount");
          }
        }
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint('❌ StreamerCardView: Error watching following: $error');
        }
      },
      cancelOnError: false,
    );
  }

  void _checkRelationshipStatus() {
    if (widget.currentUserId == null || widget.currentUserId == widget.userId) {
      if (kDebugMode) {
        debugPrint(
            "🔘 StreamerCardView: Skipping relationship check - currentUserId: ${widget.currentUserId}, userId: ${widget.userId}");
      }
      return;
    }

    if (kDebugMode) {
      debugPrint(
          "🔘 StreamerCardView: Checking relationship status for currentUserId: ${widget.currentUserId}, userId: ${widget.userId}");
    }

    // First do an initial check to set the current state
    _checkConnectionStatus().then((_) {
      if (kDebugMode) {
        debugPrint(
            "🔘 StreamerCardView: Initial relationship check complete - isFollowing: $_isFollowing, isFollowedByStreamer: $_isFollowedByStreamer, isConnected: $_isConnected");
      }

      // Then set up real-time listeners for relationship changes
      _setupRelationshipListeners();
    });
  }

  void _setupRelationshipListeners() {
    _followingRelationshipSubscription?.cancel();
    _followedByRelationshipSubscription?.cancel();
    _followingRelationshipPrimarySubscription?.cancel();
    _followedByRelationshipPrimarySubscription?.cancel();
    _followingRelationshipLegacyAltSubscription?.cancel();
    _followedByRelationshipLegacyAltSubscription?.cancel();
    _isFollowedByPrimaryReady = false;
    _isFollowedByLegacyReady = false;
    _isFollowedByLegacyAltReady = false;

    if (kDebugMode) {
      debugPrint("🔘 StreamerCardView: Setting up relationship listeners");
    }

    bool isActive(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final val = doc.data()['isActive'];
      if (val is bool) return val;
      return true;
    }

    bool allFollowedByReady() =>
        _isFollowedByPrimaryReady &&
        _isFollowedByLegacyReady &&
        _isFollowedByLegacyAltReady;

    void updateAggregatedState() {
      final following = _isFollowingPrimary || _isFollowingLegacy;
      final followed = _isFollowedByPrimary || _isFollowedByLegacy;

      final previousFollowed = _isFollowedByStreamer;
      final nextFollowed =
          followed || (!allFollowedByReady() && previousFollowed);

      if (mounted) {
        setState(() {
          _isFollowing = following;
          _isFollowedByStreamer = nextFollowed;
          _updateConnectionStatus();
        });
      }
    }

    _followingRelationshipPrimarySubscription = FirebaseFirestore.instance
        .collection('follows')
        .where('followerUserId', isEqualTo: widget.currentUserId)
        .where('targetUserId', isEqualTo: widget.userId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen(
      (snapshot) {
        _isFollowingPrimary = snapshot.docs.isNotEmpty;
        updateAggregatedState();
        if (kDebugMode) {
          debugPrint(
              "🔄 StreamerCardView: Primary following listener - isFollowingPrimary: $_isFollowingPrimary, docs: ${snapshot.docs.length}");
        }
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint(
              "❌ StreamerCardView: Error in primary following listener: $error");
        }
        _followingRelationshipPrimarySubscription?.cancel();
        _followingRelationshipPrimarySubscription = null;
        _isFollowingPrimary = false;
        updateAggregatedState();
      },
      cancelOnError: true,
    );

    _followingRelationshipSubscription = FirebaseFirestore.instance
        .collection('follows')
        .where('followerId', isEqualTo: widget.currentUserId)
        .where('followingId', isEqualTo: widget.userId)
        .snapshots()
        .listen(
      (snapshot) {
        final hasLegacy = snapshot.docs.any(isActive);
        _isFollowingLegacy = hasLegacy;
        updateAggregatedState();
        if (kDebugMode) {
          debugPrint(
              "🔄 StreamerCardView: Legacy following listener - isFollowingLegacy: $_isFollowingLegacy, docs: ${snapshot.docs.length}");
        }
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint(
              "❌ StreamerCardView: Error in legacy following listener: $error");
        }
        _followingRelationshipSubscription?.cancel();
        _followingRelationshipSubscription = null;
        _isFollowingLegacy = false;
        updateAggregatedState();
      },
      cancelOnError: true,
    );

    _followingRelationshipLegacyAltSubscription = FirebaseFirestore.instance
        .collection('follows')
        .where('followerId', isEqualTo: widget.currentUserId)
        .where('followedId', isEqualTo: widget.userId)
        .snapshots()
        .listen(
      (snapshot) {
        final hasLegacyAlt = snapshot.docs.any(isActive);
        _isFollowingLegacy = _isFollowingLegacy || hasLegacyAlt;
        updateAggregatedState();
        if (kDebugMode) {
          debugPrint(
              "🔄 StreamerCardView: Legacy alt following listener - hasLegacyAlt: $hasLegacyAlt, docs: ${snapshot.docs.length}");
        }
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint(
              "❌ StreamerCardView: Error in legacy alt following listener: $error");
        }
        _followingRelationshipLegacyAltSubscription?.cancel();
        _followingRelationshipLegacyAltSubscription = null;
        updateAggregatedState();
      },
      cancelOnError: true,
    );

    _followedByRelationshipPrimarySubscription = FirebaseFirestore.instance
        .collection('follows')
        .where('followerUserId', isEqualTo: widget.userId)
        .where('targetUserId', isEqualTo: widget.currentUserId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen(
      (snapshot) {
        _isFollowedByPrimary = snapshot.docs.isNotEmpty;
        _isFollowedByPrimaryReady = true;
        updateAggregatedState();
        if (kDebugMode) {
          debugPrint(
              "🔄 StreamerCardView: Primary followed-by listener - isFollowedByPrimary: $_isFollowedByPrimary, docs: ${snapshot.docs.length}");
        }
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint(
              "❌ StreamerCardView: Error in primary followed-by listener: $error");
        }
        _followedByRelationshipPrimarySubscription?.cancel();
        _followedByRelationshipPrimarySubscription = null;
        _isFollowedByPrimary = false;
        _isFollowedByPrimaryReady = true;
        updateAggregatedState();
      },
      cancelOnError: true,
    );

    _followedByRelationshipSubscription = FirebaseFirestore.instance
        .collection('follows')
        .where('followerId', isEqualTo: widget.userId)
        .where('followingId', isEqualTo: widget.currentUserId)
        .snapshots()
        .listen(
      (snapshot) {
        final hasLegacy = snapshot.docs.any(isActive);
        _isFollowedByLegacy = hasLegacy;
        _isFollowedByLegacyReady = true;
        updateAggregatedState();
        if (kDebugMode) {
          debugPrint(
              "🔄 StreamerCardView: Legacy followed-by listener - isFollowedByLegacy: $_isFollowedByLegacy, docs: ${snapshot.docs.length}");
        }
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint(
              "❌ StreamerCardView: Error in legacy followed-by listener: $error");
        }
        _followedByRelationshipSubscription?.cancel();
        _followedByRelationshipSubscription = null;
        _isFollowedByLegacy = false;
        _isFollowedByLegacyReady = true;
        updateAggregatedState();
      },
      cancelOnError: true,
    );

    _followedByRelationshipLegacyAltSubscription = FirebaseFirestore.instance
        .collection('follows')
        .where('followerId', isEqualTo: widget.userId)
        .where('followedId', isEqualTo: widget.currentUserId)
        .snapshots()
        .listen(
      (snapshot) {
        final hasLegacyAlt = snapshot.docs.any(isActive);
        _isFollowedByLegacy = _isFollowedByLegacy || hasLegacyAlt;
        _isFollowedByLegacyAltReady = true;
        updateAggregatedState();
        if (kDebugMode) {
          debugPrint(
              "🔄 StreamerCardView: Legacy alt followed-by listener - hasLegacyAlt: $hasLegacyAlt, docs: ${snapshot.docs.length}");
        }
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint(
              "❌ StreamerCardView: Error in legacy alt followed-by listener: $error");
        }
        _followedByRelationshipLegacyAltSubscription?.cancel();
        _followedByRelationshipLegacyAltSubscription = null;
        _isFollowedByLegacyAltReady = true;
        updateAggregatedState();
      },
      cancelOnError: true,
    );
  }

  /// Debug function to check what's actually in Firestore
  Future<void> _debugFirestoreData() async {
    if (!kDebugMode) return;

    try {
      debugPrint("🔍 StreamerCardView: DEBUG - Checking Firestore data");
      debugPrint("🔍 Current User ID: ${widget.currentUserId}");
      debugPrint("🔍 Target User ID: ${widget.userId}");

      // Check if current user follows target user
      final followingQuery = await FirebaseFirestore.instance
          .collection('follows')
          .where('followerId', isEqualTo: widget.currentUserId)
          .where('followedId', isEqualTo: widget.userId)
          .get();

      debugPrint(
          "🔍 Following query result: ${followingQuery.docs.length} docs");
      for (var doc in followingQuery.docs) {
        debugPrint("🔍 Following doc: ${doc.id} - ${doc.data()}");
      }

      // Check if target user follows current user
      final followedByQuery = await FirebaseFirestore.instance
          .collection('follows')
          .where('followerId', isEqualTo: widget.userId)
          .where('followedId', isEqualTo: widget.currentUserId)
          .get();

      debugPrint(
          "🔍 Followed by query result: ${followedByQuery.docs.length} docs");
      for (var doc in followedByQuery.docs) {
        debugPrint("🔍 Followed by doc: ${doc.id} - ${doc.data()}");
      }

      // Check all follows documents for these users
      final allFollowsQuery =
          await FirebaseFirestore.instance.collection('follows').get();

      debugPrint(
          "🔍 All follows collection: ${allFollowsQuery.docs.length} total docs");
      for (var doc in allFollowsQuery.docs) {
        final data = doc.data();
        if (data['followerId'] == widget.currentUserId ||
            data['followedId'] == widget.currentUserId ||
            data['followerId'] == widget.userId ||
            data['followedId'] == widget.userId) {
          debugPrint("🔍 Relevant follow doc: ${doc.id} - ${data}");
        }
      }

      // 🔧 FIX: Check for documents with wrong field names and fix them
      await _fixIncorrectFollowDocuments();
    } catch (e) {
      debugPrint("🔍 Error checking Firestore data: $e");
    }
  }

  /// Fix follow documents that have incorrect field names
  Future<void> _fixIncorrectFollowDocuments() async {
    try {
      debugPrint(
          "🔧 StreamerCardView: Checking for documents with incorrect field names...");

      // Check for the reverse follow document with wrong field names
      final incorrectDocId = '${widget.userId}_${widget.currentUserId}';
      final docRef =
          FirebaseFirestore.instance.collection('follows').doc(incorrectDocId);
      final doc = await docRef.get();

      if (doc.exists) {
        final data = doc.data()!;

        // Check if it has 'followingId' instead of 'followedId'
        if (data.containsKey('followingId') &&
            !data.containsKey('followedId')) {
          debugPrint("🔧 Found document with incorrect field names: ${doc.id}");
          debugPrint("🔧 Current data: $data");

          // Fix the document by updating field names
          await docRef.update({
            'followedId': data['followingId'],
            'followerId': data['followerId'],
            'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
          });

          // Remove the incorrect field
          await docRef.update({
            'followingId': FieldValue.delete(),
            'isActive': FieldValue.delete(),
          });

          debugPrint("✅ Fixed document field names: ${doc.id}");
        }
      }
    } catch (e) {
      debugPrint("🔧 Error fixing follow documents: $e");
    }
  }

  void _updateConnectionStatus() {
    final previousConnected = _isConnected;
    _isConnected = _isFollowing && _isFollowedByStreamer;

    if (kDebugMode) {
      debugPrint(
          "🔄 StreamerCardView: _updateConnectionStatus - _isFollowing: $_isFollowing, _isFollowedByStreamer: $_isFollowedByStreamer, _isConnected: $_isConnected");
      if (previousConnected != _isConnected) {
        debugPrint(
            "🔄 StreamerCardView: Connection status changed from $previousConnected to $_isConnected");
      }
    }
  }

  // MARK: - Computed Properties
  Map<String, dynamic> get userData => _userData ?? {};

  String get displayName =>
      userData['displayName'] as String? ?? 'Unknown User';
  String get username => userData['username'] as String? ?? 'unknown';
  String get bio => userData['bio'] as String? ?? '';
  String? get avatarURL => userData['avatarURL'] as String?;

  List<String> get hashtags {
    final hashtagsData = userData['hashtags'];
    if (hashtagsData == null) return [];

    if (hashtagsData is List<dynamic>) {
      return hashtagsData.cast<String>();
    } else if (hashtagsData is String) {
      return hashtagsData
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
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
    // ✅ FIX #6: Cancel debounce timer
    _rebuildDebouncer?.cancel();

    _flipController.dispose();

    // Cancel all Firestore subscriptions to prevent memory leaks
    _userDataSubscription?.cancel();
    _userStatsSubscription?.cancel();
    _followersSubscription?.cancel();
    _followingSubscription?.cancel();
    _followingRelationshipSubscription?.cancel();
    _followedByRelationshipSubscription?.cancel();
    _followingRelationshipPrimarySubscription?.cancel();
    _followedByRelationshipPrimarySubscription?.cancel();
    _followingRelationshipLegacyAltSubscription?.cancel();
    _followedByRelationshipLegacyAltSubscription?.cancel();

    // Unblock playback now that this card is closing
    _playbackManager.unblock();

    super.dispose();
  }

  // MARK: - Connection Status
  Future<void> _checkConnectionStatus() async {
    if (widget.currentUserId == null || widget.currentUserId == widget.userId) {
      if (kDebugMode) {
        debugPrint(
            "🔘 StreamerCardView: Skipping connection check - currentUserId: ${widget.currentUserId}, userId: ${widget.userId}");
      }
      return;
    }

    if (kDebugMode) {
      debugPrint(
          "🔘 StreamerCardView: Checking connection status for currentUserId: ${widget.currentUserId}, userId: ${widget.userId}");
    }

    try {
      // Check if current user is following the streamer
      final isFollowing = await _checkIfFollowing(widget.userId);

      // Check if streamer is following the current user
      final isFollowedByStreamer = await _checkIfFollowedBy(widget.userId);

      // Connection = mutual follows
      final isConnected = isFollowing && isFollowedByStreamer;

      if (kDebugMode) {
        debugPrint(
            "🔘 StreamerCardView: Connection check results - isFollowing: $isFollowing, isFollowedByStreamer: $isFollowedByStreamer, isConnected: $isConnected");
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
        debugPrint("❌ StreamerCardView: Error checking connection status: $e");
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
        debugPrint('❌ StreamerCardView: Error checking follow status: $e');
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
        debugPrint('❌ StreamerCardView: Error checking followed by status: $e');
      }
      return false;
    }
  }

  Future<void> _toggleBookmark(CalendarEvent event) async {
    HapticFeedback.lightImpact();

    final isBookmarked = _bookmarkedEventIds.contains(event.id);

    if (kDebugMode) {
      // debugPrint('🔖 StreamerCardView: Toggling bookmark for event: ${event.id}');
      // debugPrint('🔖 StreamerCardView: Currently bookmarked: $isBookmarked');
      // debugPrint('🔖 StreamerCardView: Event title: ${event.title}');
      // debugPrint('🔖 StreamerCardView: Event date: ${event.date}');
      // debugPrint('🔖 StreamerCardView: Creator ID: ${widget.userId}');
    }

    // Check if user is authenticated
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (kDebugMode) {
        // debugPrint('❌ StreamerCardView: No authenticated user');
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
      // debugPrint('✅ StreamerCardView: User authenticated: ${currentUser.uid}');
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
        message = success
            ? 'Event removed from bookmarks!'
            : 'Failed to remove bookmark';
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
        message = success
            ? 'Event saved to your bookmarks! You can view it in the menu.'
            : 'Failed to save bookmark';
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
        // debugPrint('❌ StreamerCardView: Error toggling bookmark: $e');
        // debugPrint('❌ StreamerCardView: Error type: ${e.runtimeType}');
        if (e is FirebaseException) {
          // debugPrint('❌ StreamerCardView: Firebase error code: ${e.code}');
          // debugPrint('❌ StreamerCardView: Firebase error message: ${e.message}');
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
              // Event deletion functionality - placeholder for future implementation
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
        extendBodyBehindAppBar:
            false, // SAFE AREA FIX: Don't extend behind system UI
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
                    color: Colors.white.withValues(alpha: 0.1),
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
                            color: Colors.white.withValues(alpha: 0.7),
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
                        color: Colors.white.withValues(alpha: 0.3),
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chat with $displayName',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Chat ID: ${_selectedChat!['id']}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Chat functionality will be implemented here',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
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
    return Stack(
      children: [
        // Background gradient - respects safe area
        Container(
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
        ),
        // Main content with proper safe area handling and scrolling
        SafeArea(
          child: SingleChildScrollView(
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
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          InstantResponseButton(
            onPressed: widget.onDismiss,
            hapticType: HapticFeedbackType.lightImpact,
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
              InstantResponseButton(
                onPressed: () => _flipCard(),
                hapticType: HapticFeedbackType.lightImpact,
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
            color: Colors.white.withValues(alpha: 0.7),
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
    final isLoading = text == _getFollowButtonText() &&
        (_isFollowingOperation || _isUnfollowingOperation);

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: onPressed != null ? _getFollowButtonGradient() : null,
          color: onPressed == null ? Colors.grey.withValues(alpha: 0.3) : null,
          borderRadius: BorderRadius.circular(24),
          border: onPressed == null
              ? Border.all(color: Colors.grey.withValues(alpha: 0.5))
              : null,
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
  /// 🎯 FOLLOW LOGIC: Update follow button state using centralized service
  Future<void> _updateFollowButtonState() async {
    if (widget.currentUserId == null || !mounted) return;
    try {
      await _checkConnectionStatus();
    } catch (e) {
      debugPrint('❌ StreamerCard: Error updating follow button state: $e');
    }
  }

  String _getFollowButtonText() {
    // 🎯 FOLLOW LOGIC: Use local state that's updated by real-time listeners
    // Check if viewing own profile
    if (widget.currentUserId == widget.userId) {
      return 'You';
    }

    // Use the same logic as _getConnectionStatusText for consistency
    if (_isConnected) {
      return 'Connected'; // Mutual follow
    } else if (_isFollowing && _isFollowedByStreamer) {
      return 'Connected'; // Both follow each other
    } else if (_isFollowing) {
      return 'Following'; // You follow them
    }

    return 'Follow'; // Not following
  }

  /// Get connection status text for NetworkView-style display
  /// Matches the three tabs: Connections | Followers | Following
  String _getConnectionStatusText() {
    if (_isConnected) {
      return 'Connected'; // Appears in Connections tab
    } else if (_isFollowing && _isFollowedByStreamer) {
      return 'Connected'; // Both follow each other
    } else if (_isFollowing) {
      return 'Following'; // You follow them (Following tab)
    } else if (_isFollowedByStreamer) {
      return 'Follows You'; // They follow you (Followers tab)
    }
    return 'Not Following';
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

    // 🎯 FOLLOW LOGIC: Hide button for viewing own profile
    if (widget.currentUserId == widget.userId) {
      return null;
    }

    return _handleFollowButtonTap;
  }

  VoidCallback? _getMessageButtonAction() {
    if (kDebugMode) {
      debugPrint(
          "💬 StreamerCardView: _getMessageButtonAction - _isConnected: $_isConnected, _isFollowing: $_isFollowing, _isFollowedByStreamer: $_isFollowedByStreamer");
    }
    if (_isConnected)
      return _handleMessage; // Only enabled when connected (mutual follow)
    return null; // Disabled when not connected
  }

  // MARK: - Follow Button Action Handler (Real-time Updates)
  void _handleFollowButtonTap() {
    if (kDebugMode) {
      debugPrint("🔘 Follow button tapped for user: ${widget.userId}");
      debugPrint("🔘 Current follow state: $_isFollowing");
      debugPrint("🔘 Is followed by other: $_isFollowedByStreamer");
      debugPrint("🔘 Is connected: $_isConnected");
    }

    HapticFeedback.lightImpact();

    // 🎯 NETWORKVIEW LOGIC: Match disjoint tabs model
    // Connected → Immediately unfollow (moves user from Connections to Followers)
    // Following → Immediately unfollow (removes from Following)
    // Follow → Follow user (adds to Following, or Connections if they follow back)

    if (_isConnected || _isFollowing) {
      // Both "Connected" and "Following" → Immediate unfollow
      _handleUnfollowWithOptimisticUpdate();
    } else {
      // "Follow" → Follow the user
      _handleFollow();
    }
  }

  /// Unfollow with optimistic UI update for instant feedback
  /// Matches NetworkView behavior: Connected → Follow, moves to Followers tab
  void _handleUnfollowWithOptimisticUpdate() {
    if (kDebugMode) {
      debugPrint("🔘 Unfollowing user: ${widget.userId}");
      debugPrint("🔘 Was connected: $_isConnected");
      debugPrint("🔘 Was following: $_isFollowing");
    }

    // Optimistic update: immediately show new state
    final wasConnected = _isConnected;

    setState(() {
      _isFollowing = false;
      _isConnected = false;
      // _isFollowedByStreamer stays the same (they still follow you)
    });

    // Show feedback based on what happened
    if (wasConnected) {
      // User moved from Connections → Followers (if they still follow you)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFollowedByStreamer
                  ? 'Removed from Connections. They\'re now in Followers.'
                  : 'Unfollowed successfully.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    // Perform the actual unfollow
    _handleUnfollow();
  }

  /// Show options menu for connected users (Message, Manage Connection, Report)
  /// NOTE: Currently not used for single-tap behavior (immediate unfollow)
  /// Keeping for potential future use (long-press, menu button, etc.)
  // ignore: unused_element
  void _showConnectedUserOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // User info header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    // Avatar
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: _buildAvatarWithOnlineIndicator(),
                    ),
                    const SizedBox(width: 12),
                    // Username
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userData?['username'] ?? 'Unknown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _getConnectionStatusText(), // Shows NetworkView-style status
                            style: const TextStyle(
                              color: Color(0xFF9248D2),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.grey, height: 1),

              // Option 1: Message
              _buildOptionTile(
                icon: Icons.chat_bubble_outline,
                title: 'Message',
                subtitle: 'Send a direct message',
                onTap: () {
                  Navigator.pop(context);
                  _handleMessage();
                },
              ),

              // Option 2: Manage Connection (Dynamic based on relationship)
              // Shows: "Unfollow" if following/connected, "Follow" if not following
              _buildOptionTile(
                icon: _isFollowing
                    ? Icons.person_remove_outlined
                    : Icons.person_add_outlined,
                title: _isFollowing ? 'Unfollow' : 'Follow',
                subtitle: _isConnected
                    ? 'Remove from Connections (both will be unfollowed)'
                    : (_isFollowing
                        ? 'Stop following this user'
                        : 'Follow this user'),
                onTap: () {
                  Navigator.pop(context);
                  if (_isFollowing) {
                    _confirmUnfollowWithConnectionWarning();
                  } else {
                    _handleFollow();
                  }
                },
                isDestructive: _isFollowing,
              ),

              // Option 3: Report
              _buildOptionTile(
                icon: Icons.flag_outlined,
                title: 'Report',
                subtitle: 'Report this user',
                onTap: () {
                  Navigator.pop(context);
                  _showReportOptions();
                },
                isDestructive: true,
              ),

              const SizedBox(height: 12),
              const Divider(color: Colors.grey, height: 1),

              // Option 4: Block
              _buildOptionTile(
                icon: Icons.block,
                title: 'Block',
                subtitle: 'Block this user',
                onTap: () {
                  Navigator.pop(context);
                  _handleBlockUser();
                },
                isDestructive: true,
              ),

              const SizedBox(height: 12),

              // Cancel button
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.grey[800],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build option tile for bottom sheet
  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red : Colors.white,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDestructive ? Colors.red : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[600],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// Show confirmation dialog before unfollowing (with connection awareness)
  void _confirmUnfollowWithConnectionWarning() {
    final username = _userData?['username'] ?? 'this user';

    // Different messages based on connection state
    final title = _isConnected ? 'Remove Connection?' : 'Unfollow User?';
    final message = _isConnected
        ? 'Are you sure you want to unfollow $username?\n\n'
            'This will remove them from your Connections and move them to Followers '
            '(if they still follow you).'
        : 'Are you sure you want to unfollow $username?';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            color: Colors.grey[300],
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleUnfollow();
            },
            child: const Text(
              'Unfollow',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show report options for the user
  void _showReportOptions() {
    final reportReasons = [
      'Spam or scam',
      'Inappropriate content',
      'Harassment or bullying',
      'Fake account',
      'Other',
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Why are you reporting this user?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.grey, height: 1),

              // Report reasons
              ...reportReasons.map((reason) => InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _submitReport(reason);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              reason,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  )),

              const SizedBox(height: 12),

              // Cancel button
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.grey[800],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Handle block user action
  Future<void> _handleBlockUser() async {
    final displayName = _userData?['displayName'] ?? 'this user';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Block User',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to block $displayName? They will not be able to interact with you and you will not see their content.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Block',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _blockingService.blockUser(
          targetUserId: widget.userId,
          reason: 'User blocked from StreamerCardView',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$displayName has been blocked'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );

          // Navigate back
          Navigator.of(context).pop();
          if (widget.onDismiss != null) {
            widget.onDismiss!();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to block user: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  /// Submit report to backend
  Future<void> _submitReport(String reason) async {
    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'reporterId': widget.currentUserId,
        'reportedUserId': widget.userId,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'user_report',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Report submitted. Thank you for keeping our community safe.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error submitting report: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit report. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleFollow() async {
    if (_isFollowingOperation)
      return; // Prevent multiple simultaneous operations

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
      debugPrint("🔘 StreamerCardView: Following user: ${widget.userId}");
      debugPrint(
          "🔘 StreamerCardView: Current user ID: ${widget.currentUserId}");
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

        // Verify persistence; if still not following, perform follow write
        final persisted = await _followsService.isFollowing(widget.userId);
        if (!persisted) {
          final persistedOk = await _followsService.followUser(widget.userId);
          if (!persistedOk) {
            throw Exception('Follow write failed after callback');
          }
        }

        if (mounted) {
          setState(() {
            _isFollowingOperation = false;
            _isFollowing = true;
            _updateConnectionStatus();
          });
          await _updateFollowButtonState();
        }

        if (kDebugMode) {
          debugPrint(
              "🔘 StreamerCardView: Parent follow callback completed successfully");
        }
        return; // Persistence ensured
      } catch (e) {
        if (kDebugMode) {
          debugPrint("🔘 StreamerCardView: Parent follow callback failed: $e");
        }

        // For demo content, simulate successful follow
        if (e.toString().contains('not-found') &&
            widget.userId.startsWith('user')) {
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
        debugPrint(
            "🔘 StreamerCardView: Starting Firebase follow operation using FollowsService");
      }

      // Use FollowsService to follow the user (this updates the 'follows' collection)
      final success = await _followsService.followUser(widget.userId);

      if (!success) {
        throw Exception('Failed to follow user via FollowsService');
      }

      if (kDebugMode) {
        debugPrint(
            "✅ StreamerCardView: Successfully followed user via FollowsService");
      }

      // Note: FollowsService already triggers EventTriggerService which creates the notification
      // No need to create it again here

      if (mounted) {
        setState(() {
          _isFollowingOperation = false;
        });

        // Update follow button state to reflect the new relationship
        await _updateFollowButtonState();

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
        debugPrint("✅ Successfully followed user: ${widget.userId}");
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint("🔘 StreamerCardView: Error following user: $error");
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
    if (_isUnfollowingOperation)
      return; // Prevent multiple simultaneous operations

    if (kDebugMode) {
      debugPrint("🔘 StreamerCardView: Unfollowing user: ${widget.userId}");
      debugPrint(
          "🔘 StreamerCardView: Current state - _isFollowing: $_isFollowing, _isFollowedByStreamer: $_isFollowedByStreamer, _isConnected: $_isConnected");
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
      debugPrint(
          "🔘 StreamerCardView: After optimistic update - _isFollowing: $_isFollowing, _isConnected: $_isConnected");
    }

    try {
      // Use FollowsService to unfollow the user (this updates the 'follows' collection)
      final success = await _followsService.unfollowUser(widget.userId);

      if (!success) {
        throw Exception('Failed to unfollow user via FollowsService');
      }

      if (kDebugMode) {
        debugPrint(
            "✅ StreamerCardView: Successfully unfollowed user via FollowsService");
      }

      // Update follow button state to reflect the new relationship
      await _updateFollowButtonState();

      // Remove follow notification
      await _removeFollowNotification();

      if (kDebugMode) {
        debugPrint("✅ Successfully unfollowed user: ${widget.userId}");
        debugPrint(
            "🔘 StreamerCardView: Final state after unfollow - _isFollowing: $_isFollowing, _isFollowedByStreamer: $_isFollowedByStreamer, _isConnected: $_isConnected");
      }

      // Navigate to appropriate tab in NetworkView
      _navigateToAppropriateTab();
    } catch (error) {
      if (kDebugMode) {
        // debugPrint("❌ Error unfollowing user: $error");
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
      debugPrint(
          "💬 StreamerCardView: _handleMessage called - _isConnected: $_isConnected, _isFollowing: $_isFollowing, _isFollowedByStreamer: $_isFollowedByStreamer");
    }

    HapticFeedback.lightImpact();

    // Check if users are connected (mutual follow)
    if (!_isConnected) {
      if (kDebugMode) {
        debugPrint(
            "💬 StreamerCardView: Users are not connected, showing error message");
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
      debugPrint(
          "💬 StreamerCardView: Users are connected, proceeding with message");
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
        debugPrint(
            "💬 StreamerCardView: Starting chat navigation for user: ${widget.userId}");
        debugPrint("💬 StreamerCardView: Current user: ${currentUser?.uid}");
        debugPrint("💬 StreamerCardView: User data: $_userData");
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
        debugPrint("💬 StreamerCardView: Chat created/fetched: $chat");
      }

      // Hide loading indicator
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (chat != null && mounted) {
        // Get user data for the chat view
        final otherUserName = _userData?['displayName'] ??
            _userData?['username'] ??
            'Unknown User';
        final otherUserAvatarURL =
            _userData?['avatarURL'] ?? _userData?['profileImageURL'] ?? '';
        final otherUserIsOnline = _userData?['isOnline'] ??
            _userData?['onlineStatus'] == 'online' ??
            false;

        if (kDebugMode) {
          debugPrint("💬 StreamerCardView: Navigating to chat with:");
          debugPrint("💬 StreamerCardView: - Name: $otherUserName");
          debugPrint("💬 StreamerCardView: - Avatar: $otherUserAvatarURL");
          debugPrint("💬 StreamerCardView: - Online: $otherUserIsOnline");
        }

        // Navigate to chat view
        Navigator.of(context).push(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/inbox'),
            builder: (context) => ChatView(
              chat: chat,
              otherUserId: widget.userId,
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
          debugPrint(
              "💬 StreamerCardView: Failed to create/fetch chat - chat is null");
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
        debugPrint("💬 StreamerCardView: Error starting conversation: $e");
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
        debugPrint(
            "🔘 StreamerCardView: Navigating to Connections tab (mutual follow)");
      }
    } else if (_isFollowing) {
      // Current user follows the other user - go to Following tab
      widget.onNavigateToTab!('following');
      if (kDebugMode) {
        debugPrint("🔘 StreamerCardView: Navigating to Following tab");
      }
    } else if (_isFollowedByStreamer) {
      // Other user follows current user - go to Followers tab
      widget.onNavigateToTab!('followers');
      if (kDebugMode) {
        debugPrint("🔘 StreamerCardView: Navigating to Followers tab");
      }
    } else {
      // No relationship - go to Following tab (where they'll be added)
      widget.onNavigateToTab!('following');
      if (kDebugMode) {
        debugPrint(
            "🔘 StreamerCardView: Navigating to Following tab (new follow)");
      }
    }
  }

  // MARK: - Video Navigation

  // ✅ FIX: Removed placeholder _navigateToPlayerScreen method
  // ProfileVideoFeedView now handles video taps directly and opens the real PlayerScreen

  // MARK: - Helper Methods for Follow/Unfollow Operations

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
        // debugPrint("❌ Error removing follow notification: $error");
      }
      // Don't throw here - notification cleanup is not critical
    }
  }

  Widget _buildContentTabs() {
    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
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
            color: isSelected
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: isSelected
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1,
                  )
                : null,
          ),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.7),
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
    return _buildVideoFeed();
  }

  Widget _buildVideoFeed() {
    switch (_selectedTabIndex) {
      case 0: // Video
        return ProfileVideoFeedView(
          userId: widget.userId,
          feedType: ProfileVideoFeedType.videos,
          // ✅ FIX: Let ProfileVideoFeedView handle video taps directly
          // It will open the real PlayerScreen with actual videos
          onVideoTap: null,
        );
      case 1: // Favorites
        return ProfileVideoFeedView(
          userId: widget.userId,
          feedType: ProfileVideoFeedType.favorites,
          // ✅ FIX: Let ProfileVideoFeedView handle video taps directly
          onVideoTap: null,
        );
      case 2: // Tagged
        return ProfileVideoFeedView(
          userId: widget.userId,
          feedType: ProfileVideoFeedType.tagged,
          // ✅ FIX: Let ProfileVideoFeedView handle video taps directly
          onVideoTap: null,
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
                child: buildCachedAvatarCircle(
                  url: avatarURL,
                  size: 104,
                  iconSize: 48,
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
                            color: _getStatusColor(presence.status)
                                .withValues(alpha: 0.5),
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
    return Stack(
      children: [
        // Background gradient - respects safe area
        Container(
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
        ),
        // Main content with proper safe area handling
        SafeArea(
          child: Stack(
            children: [
              // Header with navigation buttons
              _buildHeader(),
              // Main content
              Padding(
                padding: const EdgeInsets.only(
                    top: 80), // Space for the header buttons
                child: CustomScrollView(
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    SliverToBoxAdapter(child: _buildIdentity()),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    SliverToBoxAdapter(child: _buildTags()),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    SliverToBoxAdapter(
                        child: _buildSectionHeader('Bio', _showBio,
                            () => setState(() => _showBio = !_showBio))),
                    if (_showBio) SliverToBoxAdapter(child: _buildBioBody()),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    SliverToBoxAdapter(
                        child: _buildSectionHeader(
                            'Platforms',
                            _showPlatforms,
                            () => setState(
                                () => _showPlatforms = !_showPlatforms))),
                    if (_showPlatforms)
                      SliverToBoxAdapter(child: _buildPlatforms(_platforms)),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    SliverToBoxAdapter(
                        child: _buildSectionHeader(
                            'Calendar',
                            _showCalendar,
                            () => setState(
                                () => _showCalendar = !_showCalendar))),
                    if (_showCalendar)
                      SliverToBoxAdapter(
                          child: _buildCalendar(_calendarEvents)),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Right side: Flip button
          InstantResponseButton(
            onPressed: _flipCard,
            hapticType: HapticFeedbackType.lightImpact,
            child: const Icon(
              Icons.flip,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
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
                    color: Colors.white.withValues(alpha: 0.75),
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
        hashtags = hashtagsData
            .split(RegExp(r'[,\s]+'))
            .where((tag) => tag.isNotEmpty)
            .toList();
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
                color: isSelected ? null : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
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
    if (kDebugMode) {
      // ✅ FIX #5: Wrap in kDebugMode
      debugPrint(
          '🔗 _buildPlatforms: Building platforms section with ${platforms.length} platforms');
    }
    if (platforms.isEmpty) {
      if (kDebugMode) {
        // ✅ FIX #5: Wrap in kDebugMode
        debugPrint(
            '🔗 _buildPlatforms: No platforms found, showing empty state');
      }
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

  Widget _buildSectionHeader(
      String title, bool isExpanded, VoidCallback onTap) {
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
              isExpanded
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_right,
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
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
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

  /// ✅ FIX #2: Optimized to only setState when platforms actually change
  void _loadPlatforms() {
    if (_userData == null || _userData!['platforms'] == null) {
      // Only setState if platforms were previously non-empty
      if (_platforms.isNotEmpty) {
        _platforms = [];
      }
      return;
    }

    try {
      final platformsData = _userData!['platforms'];
      if (platformsData is! List) {
        if (_platforms.isNotEmpty) {
          _platforms = [];
        }
        return;
      }

      final newPlatforms = platformsData
          .where((p) => p is Map<String, dynamic>)
          .map((platform) => {
                'id': platform['id']?.toString() ?? '',
                'type': platform['type']?.toString() ?? '',
                'username': platform['username']?.toString() ?? '',
                'followers': (platform['followers'] as num?)?.toInt() ?? 0,
                'url': platform['url']?.toString(),
              })
          .toList();

      // ✅ Only update if platforms actually changed (no unnecessary setState)
      if (!_platformsEqual(newPlatforms, _platforms)) {
        _platforms = newPlatforms;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ StreamerCardView: Error loading platforms: $e');
      }
      if (_platforms.isNotEmpty) {
        _platforms = [];
      }
    }
  }

  /// Helper to compare platform lists
  bool _platformsEqual(
      List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i]['id'] != b[i]['id'] || a[i]['url'] != b[i]['url']) {
        return false;
      }
    }
    return true;
  }

  /// ✅ FIX #3: Optimized to only update when calendar events actually change
  void _loadCalendarEvents() {
    if (_userData == null || _userData!['calendarEvents'] == null) {
      // Only update if events were previously non-empty
      if (_calendarEvents.isNotEmpty) {
        _calendarEvents = [];
      }
      return;
    }

    try {
      final eventsData = _userData!['calendarEvents'];
      if (eventsData is! List) {
        if (_calendarEvents.isNotEmpty) {
          _calendarEvents = [];
        }
        return;
      }

      final newEvents = eventsData
          .where((e) =>
              e is Map<String, dynamic> &&
              e['id'] != null &&
              e['title'] != null &&
              e['description'] != null &&
              e['date'] != null)
          .map((eventData) {
            try {
              return CalendarEvent(
                id: eventData['id'] as String,
                title: eventData['title'] as String,
                description: eventData['description'] as String,
                date: _parseDate(
                    eventData['date']), // ✅ FIX #3: Safe date parsing
              );
            } catch (e) {
              if (kDebugMode) {
                debugPrint(
                    '❌ StreamerCardView: Error creating CalendarEvent: $e');
              }
              return null;
            }
          })
          .where((event) => event != null)
          .cast<CalendarEvent>()
          .toList();

      // ✅ Only update if events actually changed (no unnecessary setState)
      if (!_eventsEqual(newEvents, _calendarEvents)) {
        _calendarEvents = newEvents;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ StreamerCardView: Error loading calendar events: $e');
      }
      if (_calendarEvents.isNotEmpty) {
        _calendarEvents = [];
      }
    }
  }

  /// Helper to compare calendar event lists
  bool _eventsEqual(List<CalendarEvent> a, List<CalendarEvent> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].date != b[i].date) {
        return false;
      }
    }
    return true;
  }

  /// ✅ FIX #3: Safely parse date from various formats (copied from ProfileBackView)
  DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) {
      return DateTime.now();
    }

    if (dateValue is Timestamp) {
      return dateValue.toDate();
    }

    if (dateValue is DateTime) {
      return dateValue;
    }

    if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              '❌ StreamerCardView: Error parsing date string: $dateValue');
        }
        return DateTime.now();
      }
    }

    if (kDebugMode) {
      debugPrint(
          '❌ StreamerCardView: Unknown date type: ${dateValue.runtimeType}');
    }
    return DateTime.now();
  }

  /// ✅ FIX #4: Added timeout protection to prevent UI freeze
  Future<void> _launchPlatformUrl(Map<String, dynamic> platform) async {
    final url = platform['url'] as String?;
    final platformType = platform['type'] as String?;

    if (url == null || url.isEmpty) return;

    try {
      // ✅ FIX #4: Add timeout to prevent hanging (10 seconds)
      await Future.any([
        _launchUrlWithTimeout(url),
        Future.delayed(const Duration(seconds: 10), () {
          throw TimeoutException(
              'URL launch timed out', const Duration(seconds: 10));
        }),
      ]);

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Opening ${_getPlatformDisplayName(platformType)}...'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        // ✅ FIX #5: Wrap in kDebugMode
        debugPrint('❌ StreamerCardView: Error launching URL: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot open this link'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// ✅ FIX #4: Helper method for URL launching with proper error handling
  Future<void> _launchUrlWithTimeout(String url) async {
    String finalUrl = url;
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }

    if (kDebugMode) {
      // ✅ FIX #5: Wrap in kDebugMode
      debugPrint('🔗 StreamerCardView: Launching URL: $finalUrl');
    }

    final uri = Uri.parse(finalUrl);
    final canLaunch = await canLaunchUrl(uri);

    if (canLaunch) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  String _getPlatformDisplayName(String? platformType) {
    if (platformType == null) return 'Platform';
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
      case 'bluesky':
        return 'Bluesky';
      case 'twitter':
        return 'Twitter';
      case 'instagram':
        return 'Instagram';
      case 'reddit':
        return 'Reddit';
      case 'discord':
        return 'Discord';
      case 'other':
        return 'Website';
      default:
        return platformType;
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

Widget buildCachedAvatarCircle({
  required String? url,
  required double size,
  required double iconSize,
}) {
  final placeholder = Container(
    width: size,
    height: size,
    color: Colors.grey.shade800,
    child: Icon(
      Icons.person,
      color: Colors.white,
      size: iconSize,
    ),
  );

  if (url == null || url.isEmpty) {
    return placeholder;
  }

  final cacheSize = (size * 2).round();

  return CachedNetworkImage(
    imageUrl: url,
    memCacheWidth: cacheSize,
    memCacheHeight: cacheSize,
    fadeInDuration: const Duration(milliseconds: 120),
    imageBuilder: (context, imageProvider) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(
          image: imageProvider,
          fit: BoxFit.cover,
        ),
      ),
    ),
    placeholder: (context, _) => placeholder,
    errorWidget: (context, _, __) => placeholder,
  );
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
              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF9248D2)),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Description (Optional)',
              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF9248D2)),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
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
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
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
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Time',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
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
          colors: [
            Color(0xFFFF6CAB),
            Color(0xFF8E54E9),
            Color(0xFF3D99F7),
            Color(0xFFFF6CAB)
          ],
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
            child: buildCachedAvatarCircle(
              url: imageUrl,
              size: 56,
              iconSize: 28,
            ),
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

    debugPrint(
        '🔗 _ClickablePlatformRow: Building platform card - type: $platformType, username: $username');

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
