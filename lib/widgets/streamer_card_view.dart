import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/streamer_card.dart';
import '../models/calendar_event.dart';
import '../providers/status_provider.dart';
import '../models/user_status.dart';
import '../widgets/profile_video_feed_view.dart';
import '../services/bookmark_service.dart';

class StreamerCardView extends ConsumerStatefulWidget {
  final String userId; // Changed from StreamerCard to userId for live data
  final String? currentUserId;
  final VoidCallback? onDismiss;
  final Function(String userId)? onFollow;
  final Function(String userId)? onMessage;
  final Function(String userId)? onShare;

  const StreamerCardView({
    super.key,
    required this.userId,
    this.currentUserId,
    this.onDismiss,
    this.onFollow,
    this.onMessage,
    this.onShare,
  });

  @override
  ConsumerState<StreamerCardView> createState() => _StreamerCardViewState();
}

class _StreamerCardViewState extends ConsumerState<StreamerCardView>
    with TickerProviderStateMixin {
  late AnimationController _flipController;
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
  late final BookmarkService _bookmarkService;
  
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
  StreamSubscription<QuerySnapshot>? _postsSubscription;
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
    _bookmarkService = BookmarkService();
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
    
    // Load user data and set up real-time listeners
    _loadUserData();
    _checkConnectionStatus();
  }

  // MARK: - Data Loading
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
          setState(() {
            _error = 'User not found';
            _isLoading = false;
          });
        }
      }
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _isLoading = false;
        });
      }
    });
  }

  void _loadStats() {
    if (_userData == null) return;
    
    // Cancel existing subscriptions
    _postsSubscription?.cancel();
    _followersSubscription?.cancel();
    _followingSubscription?.cancel();
    
    // Load posts count
    _postsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('videos')
        .where('status', isEqualTo: 'published')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _postsCount = snapshot.docs.length;
        });
      }
    });

    // Load followers count
    _followersSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('followers')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _followersCount = snapshot.docs.length;
        });
      }
    });

    // Load following count
    _followingSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('following')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _followingCount = snapshot.docs.length;
        });
      }
    });
  }

  void _checkRelationshipStatus() {
    if (widget.currentUserId == null || widget.currentUserId == widget.userId) return;
    
    // Set up real-time listeners for relationship changes
    _setupRelationshipListeners();
  }

  void _setupRelationshipListeners() {
    // Cancel existing subscriptions
    _followingRelationshipSubscription?.cancel();
    _followedByRelationshipSubscription?.cancel();
    
    // Listen for changes in current user's following list
    _followingRelationshipSubscription = FirebaseFirestore.instance
        .collection('relationships')
        .where('followerId', isEqualTo: widget.currentUserId)
        .where('followingId', isEqualTo: widget.userId)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _isFollowing = snapshot.docs.isNotEmpty;
          _updateConnectionStatus();
        });
        
        if (kDebugMode) {
          print("🔄 StreamerCardView: Following updated - isFollowing: $_isFollowing");
        }
      }
    });

    // Listen for changes in this user's following list (to check if they follow current user)
    _followedByRelationshipSubscription = FirebaseFirestore.instance
        .collection('relationships')
        .where('followerId', isEqualTo: widget.userId)
        .where('followingId', isEqualTo: widget.currentUserId)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _isFollowedByStreamer = snapshot.docs.isNotEmpty;
          _updateConnectionStatus();
        });
        
        if (kDebugMode) {
          print("🔄 StreamerCardView: Followed by streamer updated - isFollowedByStreamer: $_isFollowedByStreamer");
          print("🔄 StreamerCardView: Updated connection state - isConnected: $_isConnected");
        }
      }
    });
  }

  void _updateConnectionStatus() {
    _isConnected = _isFollowing && _isFollowedByStreamer;
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
    _postsSubscription?.cancel();
    _followersSubscription?.cancel();
    _followingSubscription?.cancel();
    _followingRelationshipSubscription?.cancel();
    _followedByRelationshipSubscription?.cancel();
    
    super.dispose();
  }

  // MARK: - Connection Status
  Future<void> _checkConnectionStatus() async {
    if (widget.currentUserId == null || widget.currentUserId == widget.userId) {
      return;
    }


    try {
      // Check if current user is following the streamer
      final isFollowing = await _checkIfFollowing(widget.userId);
      
      // Check if streamer is following the current user
      final isFollowedByStreamer = await _checkIfFollowedBy(widget.userId);
      
      // Connection = mutual follows
      final isConnected = isFollowing && isFollowedByStreamer;
      
      if (mounted) {
        setState(() {
          _isFollowing = isFollowing;
          _isFollowedByStreamer = isFollowedByStreamer;
          _isConnected = isConnected;
        });
      }
    } catch (e) {
      if (kDebugMode) {
      print('Error checking connection status: $e');
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
      // Check if current user follows the target user using relationships collection
      final query = await FirebaseFirestore.instance
          .collection('relationships')
          .where('followerId', isEqualTo: widget.currentUserId!)
          .where('followingId', isEqualTo: userId)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
      print('Error checking follow status: $e');
      }
      return false;
    }
  }

  Future<bool> _checkIfFollowedBy(String userId) async {
    try {
      // Check if target user follows the current user using relationships collection
      final query = await FirebaseFirestore.instance
          .collection('relationships')
          .where('followerId', isEqualTo: userId)
          .where('followingId', isEqualTo: widget.currentUserId!)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
      print('Error checking followed by status: $e');
      }
      return false;
    }
  }

  // MARK: - Platform URL Opening Algorithm
  void _openPlatformURL(String? url) async {
    if (url != null && url.isNotEmpty) {
      try {
        await launchUrl(Uri.parse(url));
        if (kDebugMode) {
        print("Opening platform URL: $url");
        }
      } catch (error) {
        if (kDebugMode) {
        print("Failed to open URL: $url - Error: $error");
        }
      }
    }
  }


  // MARK: - Calendar Management
  void _showCalendarSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E1220),
      isScrollControlled: true,
      builder: (context) => CalendarEventSheet(
        onSave: (event) => _saveCalendarEvent(event),
      ),
    );
  }

  void _saveCalendarEvent(CalendarEvent event) {
    // TODO: Implement actual calendar event saving
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Event "${event.title}" added to calendar!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleBookmark(CalendarEvent event) async {
    HapticFeedback.lightImpact();
    
    final isBookmarked = _bookmarkedEventIds.contains(event.id);
    
    try {
      bool success;
      String message;
      
      if (isBookmarked) {
        // Remove bookmark
        success = await _bookmarkService.removeEventBookmark(
          eventId: event.id,
          ownerId: widget.userId,
        );
        message = success ? 'Event removed from bookmarks!' : 'Failed to remove bookmark';
      } else {
        // Add bookmark
        success = await _bookmarkService.addEventBookmark(
          event: event,
          ownerId: widget.userId,
          ownerDisplayName: _userData?['displayName'] ?? 'Unknown',
        );
        message = success ? 'Event saved to your bookmarks! You can view it in the menu.' : 'Failed to save bookmark';
      }
      
      if (success && mounted) {
        // Update local state
    setState(() {
          if (isBookmarked) {
            _bookmarkedEventIds.remove(event.id);
          } else {
            _bookmarkedEventIds.add(event.id);
          }
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (mounted) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error toggling bookmark: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update bookmark'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
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
    
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      extendBodyBehindAppBar: true,
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
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: const Center(
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
            Text(
              'Error Loading Profile',
              style: const TextStyle(
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
                    color: Colors.white.withOpacity(0.1),
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
                  CircleAvatar(
                    backgroundImage: avatarURL != null
                        ? NetworkImage(avatarURL!)
                        : null,
                    child: avatarURL == null
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
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
                          '@${username}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
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
                        color: Colors.white.withOpacity(0.3),
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chat with ${displayName}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Chat ID: ${_selectedChat!['id']}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Chat functionality will be implemented here',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
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
    return Container(
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16, 
        MediaQuery.of(context).padding.top + 16, 
        16, 
        16
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          GestureDetector(
            onTap: widget.onDismiss,
            child: const Icon(
              Icons.chevron_left,
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
              const Icon(
                Icons.more_horiz,
                color: Colors.white,
                size: 24,
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
            color: Colors.white.withOpacity(0.7),
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
          gradient: onPressed != null ? const LinearGradient(
            colors: [Color(0xFF955CFF), Color(0xFF3D99F7)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ) : null,
          color: onPressed == null ? Colors.grey.withOpacity(0.3) : null,
          borderRadius: BorderRadius.circular(24),
          border: onPressed == null ? Border.all(color: Colors.grey.withOpacity(0.5)) : null,
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

  // MARK: - Button State Helpers
  String _getFollowButtonText() {
    if (_isConnected) return 'Connected';
    if (_isFollowing) return 'Following';
    return 'Follow';
  }

  VoidCallback? _getFollowButtonAction() {
    // Disable button during operations
    if (_isFollowingOperation || _isUnfollowingOperation) {
      return null;
    }
    return _handleFollowButtonTap;
  }

  VoidCallback? _getMessageButtonAction() {
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
    
    if (_isFollowing) {
      _handleUnfollow();
      } else {
      _handleFollow();
    }
  }

  Future<void> _handleFollow() async {
    if (_isFollowingOperation) return; // Prevent multiple simultaneous operations
    
    if (kDebugMode) {
      print("🔘 Following user: ${widget.userId}");
    }
    
    // Store original state for rollback
    final originalFollowingState = _isFollowing;
    
    // Update local state optimistically
    setState(() {
      _isFollowing = true;
      _isFollowingOperation = true;
      _updateConnectionStatus();
    });
    
    // Call the parent callback
    widget.onFollow?.call(widget.userId);
    
    try {
      // 1. Create relationship document in Firestore
      await FirebaseFirestore.instance
          .collection('relationships')
          .add({
        'followerId': widget.currentUserId!,
        'followingId': widget.userId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // 2. Update follower count
      await _updateFollowerCount(widget.userId, 1);
      
      // 3. Create follow notification
      await _createFollowNotification();
      
      if (kDebugMode) {
        print("✅ Successfully followed user: ${widget.userId}");
      }
    } catch (error) {
      if (kDebugMode) {
        print("❌ Error following user: $error");
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
            content: Text('Failed to follow user: ${error.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _handleFollow(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFollowingOperation = false;
        });
      }
    }
  }

  Future<void> _handleUnfollow() async {
    if (_isUnfollowingOperation) return; // Prevent multiple simultaneous operations
    
    if (kDebugMode) {
      print("🔘 Unfollowing user: ${widget.userId}");
    }
    
    // Store original state for rollback
    final originalFollowingState = _isFollowing;
    
    // Update local state optimistically
    setState(() {
      _isFollowing = false;
      _isUnfollowingOperation = true;
      _updateConnectionStatus();
    });
    
    try {
      // 1. Find and delete relationship document from Firestore
      final relationshipQuery = await FirebaseFirestore.instance
          .collection('relationships')
          .where('followerId', isEqualTo: widget.currentUserId!)
          .where('followingId', isEqualTo: widget.userId)
          .get();
      
      for (final doc in relationshipQuery.docs) {
        await doc.reference.delete();
      }
      
      // 2. Update follower count
      await _updateFollowerCount(widget.userId, -1);
      
      // 3. Remove follow notification
      await _removeFollowNotification();
      
      if (kDebugMode) {
        print("✅ Successfully unfollowed user: ${widget.userId}");
      }
    } catch (error) {
      if (kDebugMode) {
        print("❌ Error unfollowing user: $error");
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
    HapticFeedback.lightImpact();
    widget.onMessage?.call(widget.userId);
    
    // TODO: Implement message functionality
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
                  Text(
                    'Video Player',
                    style: const TextStyle(
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
                    'User: ${displayName}',
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
        print("❌ Error navigating to player screen: $e");
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
  
  Future<void> _updateFollowerCount(String userId, int increment) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'followerCount': FieldValue.increment(increment),
      });
    } catch (error) {
      if (kDebugMode) {
        print("❌ Error updating follower count: $error");
      }
      // Don't throw here - follower count is not critical for follow operation
    }
  }
  
  Future<void> _createFollowNotification() async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .add({
        'userId': widget.userId,
        'type': 'follow',
        'fromUserId': widget.currentUserId!,
        'fromUserName': 'Current User', // TODO: Get actual user name
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (error) {
      if (kDebugMode) {
        print("❌ Error creating follow notification: $error");
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
        print("❌ Error removing follow notification: $error");
      }
      // Don't throw here - notification cleanup is not critical
    }
  }









  Widget _buildContentTabs() {
    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
          border: Border.all(
          color: Colors.white.withOpacity(0.15),
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
            color: isSelected ? Colors.white.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: isSelected
                ? Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 1,
                  )
                : null,
        ),
        child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
            style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
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
                            color: _getStatusColor(presence.status).withOpacity(0.5),
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
          // Main content
          SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
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
    return Padding(
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
                    color: Colors.white.withOpacity(0.75),
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

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatItem('Posts', _postsCount.toString()),
        const SizedBox(width: 54),
        _buildStatItem('Followers', _followersCount.toString()),
        const SizedBox(width: 54),
        _buildStatItem('Following', _followingCount.toString()),
      ],
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
                color: isSelected ? null : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                  color: Colors.white.withOpacity(0.2),
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
    if (platforms.isEmpty) {
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
                    color: Color(0xFF80FFFFFF),
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



  Widget _buildPlatformRow(Platform platform) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          // MARK: - Platform URL Opening Algorithm
          _openPlatformURL(platform.url);
        },
        child: Container(
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(platform.type.colorValue),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getPlatformIcon(platform.type),
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      platform.type.name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '@${platform.username}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildCalendarSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _showCalendar = !_showCalendar;
              });
            },
            child: Row(
              children: [
                const Text(
                  'Calendar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _showCalendar ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _showCalendar ? null : 0,
            child: _showCalendar
                ? StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.userId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      List<CalendarEvent> events = [];
                      
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data = snapshot.data!.data() as Map<String, dynamic>?;
                        if (data != null && data['calendarEvents'] != null) {
                          final eventsData = data['calendarEvents'] as List<dynamic>;
                          events = eventsData.map((eventData) {
                            final eventMap = eventData as Map<String, dynamic>;
                            return CalendarEvent(
                              id: (eventMap['id'] ?? '').toString(),
                              title: (eventMap['title'] ?? '').toString(),
                              description: (eventMap['description'] ?? '').toString(),
                              date: (eventMap['date'] as Timestamp).toDate(),
                            );
                          }).toList();
                          if (kDebugMode) {
                          print('📅 StreamerCardView: Loaded ${events.length} events from real-time listener');
                          }
                        }
                      }
                      
                      return Column(
                        children: [
                          const SizedBox(height: 16),
                          if (events.isEmpty) ...[
                            Text(
                              'No Calendar',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 16,
                              ),
                            ),
                          ] else ...[
                            ...events.take(5).map((event) {
                              return _buildCalendarRow(event);
                            }),
                            if (events.length > 5) ...[
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  '+${events.length - 5} more…',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ],
                          const SizedBox(height: 16),
                          // MARK: - Add to Calendar button (only for owner)
                          if (isOwner) ...[
                            GestureDetector(
                              onTap: () {
                                _showCalendarSheet();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    width: 0.5,
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.add_circle,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Add to Calendar',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Spacer(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  )
                : const SizedBox.shrink(),
          ),
        ],
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
                  _formatDateAndTime(event.date),
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





  IconData _getPlatformIcon(PlatformType type) {
    switch (type) {
      case PlatformType.twitch:
        return Icons.videogame_asset;
      case PlatformType.youtube:
        return Icons.play_circle;
      case PlatformType.kick:
        return Icons.sports_esports;
      case PlatformType.tiktok:
        return Icons.music_note;
      case PlatformType.facebook:
        return Icons.facebook;
      case PlatformType.bluesky:
        return Icons.cloud;
      case PlatformType.twitter:
        return Icons.alternate_email;
      case PlatformType.instagram:
        return Icons.camera_alt;
      case PlatformType.rednote:
        return Icons.note;
      case PlatformType.other:
        return Icons.link;
    }
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
    if (_userData != null && _userData!['platforms'] != null) {
      try {
        final platformsData = _userData!['platforms'];
        if (platformsData is List) {
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
          print('Error loading platforms: $e');
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
                    print('Error creating CalendarEvent: $e');
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
          print('Error loading calendar events: $e');
        }
        setState(() {
          _calendarEvents = [];
        });
      }
    }
  }

  void _launchPlatformUrl(Map<String, dynamic> platform) async {
    final url = platform['url'] as String?;
    if (url != null && url.isNotEmpty) {
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error opening URL: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatDateAndTime(DateTime date) {
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
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF9248D2)),
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Description (Optional)',
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF9248D2)),
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
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
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withOpacity(0.1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
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
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withOpacity(0.1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Time',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
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


  String _formatDateAndTime(DateTime date) {
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
    final url = platform['url'] as String? ?? '';

    return GestureDetector(
      onTap: onTap,
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
            Icon(
              _getPlatformIcon(platformType),
              color: Colors.white,
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

  IconData _getPlatformIcon(String platformType) {
    switch (platformType.toLowerCase()) {
      case 'twitch':
        return Icons.live_tv;
      case 'youtube':
        return Icons.play_circle;
      case 'kick':
        return Icons.sports_esports;
      case 'tiktok':
        return Icons.music_note;
      case 'facebook':
        return Icons.facebook;
      case 'twitter':
        return Icons.alternate_email;
      case 'instagram':
        return Icons.camera_alt;
      default:
        return Icons.link;
    }
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
