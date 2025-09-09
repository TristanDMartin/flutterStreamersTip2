import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/streamer_card.dart';
import '../models/calendar_event.dart';
import '../providers/status_provider.dart';
import '../models/user_status.dart';

class StreamerCardView extends ConsumerStatefulWidget {
  final StreamerCard displayStreamer;
  final String? currentUserId;
  final VoidCallback? onDismiss;
  final Function(StreamerCard)? onFollow;
  final Function(StreamerCard)? onMessage;
  final Function(StreamerCard)? onShare;

  const StreamerCardView({
    super.key,
    required this.displayStreamer,
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
  bool _showPlatforms = true;
  bool _showCalendar = true;
  final Set<String> _bookmarkedEventIds = {};
  double _scrollOffset = 0.0;
  StreamerCard? _loadedStreamer;
  bool _isFollowing = false;
  bool _isFollowedByStreamer = false;
  bool _isConnected = false;
  bool _isCheckingConnection = false;
  
  // Chat UI State
  bool _showChatView = false;
  Map<String, dynamic>? _selectedChat;

  @override
  void initState() {
    super.initState();
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
    
    // Initialize with first hashtag selected
    if (hashtags.isNotEmpty) {
      _selectedHashtag = hashtags.first;
    }
    
    // Check connection status for messaging
    _checkConnectionStatus();
  }

  // MARK: - Computed Properties
  StreamerCard get displayStreamer => _loadedStreamer ?? widget.displayStreamer;
  
  List<String> get hashtags => displayStreamer.hashtags;
  
  int get selectedHashtagIndex {
    final index = hashtags.indexOf(_selectedHashtag);
    return index >= 0 ? index : 0;
  }
  
  bool get isOwner {
    // Check if current user is the owner of this streamer card
    final currentUserId = widget.currentUserId ?? '';
    return currentUserId == displayStreamer.id;
  }

  @override
  void dispose() {
    _flipController.dispose();
    // Firestore listeners are automatically cleaned up when the widget is disposed
    // No manual cleanup needed for this implementation
    super.dispose();
  }

  // MARK: - Connection Status
  Future<void> _checkConnectionStatus() async {
    if (widget.currentUserId == null || widget.currentUserId == displayStreamer.id) {
      return;
    }

    setState(() {
      _isCheckingConnection = true;
    });

    try {
      // Check if current user is following the streamer
      final isFollowing = await _checkIfFollowing(displayStreamer.id);
      
      // Check if streamer is following the current user
      final isFollowedByStreamer = await _checkIfFollowedBy(displayStreamer.id);
      
      // Connection = mutual follows
      final isConnected = isFollowing && isFollowedByStreamer;
      
      if (mounted) {
        setState(() {
          _isFollowing = isFollowing;
          _isFollowedByStreamer = isFollowedByStreamer;
          _isConnected = isConnected;
          _isCheckingConnection = false;
        });
      }
    } catch (e) {
      print('Error checking connection status: $e');
      if (mounted) {
        setState(() {
          _isFollowing = false;
          _isFollowedByStreamer = false;
          _isConnected = false;
          _isCheckingConnection = false;
        });
      }
    }
  }

  Future<bool> _checkIfFollowing(String userId) async {
    try {
      // Check if current user follows the target user
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId!)
          .collection('following')
          .doc(userId)
          .get();
      return doc.exists;
    } catch (e) {
      print('Error checking follow status: $e');
      return false;
    }
  }

  Future<bool> _checkIfFollowedBy(String userId) async {
    try {
      // Check if target user follows the current user
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('following')
          .doc(widget.currentUserId!)
          .get();
      return doc.exists;
    } catch (e) {
      print('Error checking followed by status: $e');
      return false;
    }
  }

  // MARK: - Platform URL Opening Algorithm
  void _openPlatformURL(String? url) async {
    if (url != null && url.isNotEmpty) {
      try {
        await launchUrl(Uri.parse(url));
        print("Opening platform URL: $url");
      } catch (error) {
        print("Failed to open URL: $url - Error: $error");
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

  void _toggleBookmark(String eventId) {
    setState(() {
      if (_bookmarkedEventIds.contains(eventId)) {
        _bookmarkedEventIds.remove(eventId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event removed from bookmarks'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        _bookmarkedEventIds.add(eventId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event bookmarked!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    });
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

  // MARK: - Date Formatting Algorithm
  String _formatDateAndTime(DateTime date) {
    final dateFormatter = DateFormat('MMM d');
    final timeFormatter = DateFormat('h:mm a');
    
    final dateString = dateFormatter.format(date);
    final timeString = timeFormatter.format(date);
    
    return '$dateString · $timeString';
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
                    backgroundImage: displayStreamer.avatarURL != null
                        ? NetworkImage(displayStreamer.avatarURL!)
                        : null,
                    child: displayStreamer.avatarURL == null
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayStreamer.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '@${displayStreamer.username}',
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
                        'Chat with ${displayStreamer.displayName}',
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
        const SizedBox(height: 20), // Add bottom spacing to match ProfileView
      ],
    );
  }

  Widget _buildStatisticsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStatItem('0', 'Posts'),
          const SizedBox(width: 54),
          _buildStatItem('1', 'Followers'),
          const SizedBox(width: 54),
          _buildStatItem('1', 'Following'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String number, String label) {
    return Column(
      children: [
        Text(
          number,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildFollowButton(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMessageButton(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              'Share',
              () => widget.onShare?.call(widget.displayStreamer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF955CFF), Color(0xFF3D99F7)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageButton() {
    // Don't show message button for owner
    if (isOwner) {
      return const SizedBox.shrink();
    }

    // Show loading state while checking connection
    if (_isCheckingConnection) {
      return Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

    // Message button - disabled when not connected
    return GestureDetector(
      onTap: _isConnected ? _handleMessageButtonTap : null, // null = disabled
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: _isConnected 
            ? Colors.white.withOpacity(0.15) // ultraThinMaterial equivalent
            : Colors.white.withOpacity(0.05), // Disabled state
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isConnected 
              ? Colors.white.withOpacity(0.2)
              : Colors.white.withOpacity(0.1), // Disabled border
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            'Message',
            style: TextStyle(
              color: _isConnected 
                ? Colors.white 
                : Colors.white.withOpacity(0.3), // Disabled text color
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _handleMessageButtonTap() {
    if (!_isConnected) {
      _showConnectionRequiredDialog();
      return;
    }

    // Find or create chat and navigate to it
    _findOrCreateChat();
  }

  Future<void> _findOrCreateChat() async {
    if (widget.currentUserId == null) return;

    try {
      print('🔍 Finding or creating chat with: ${displayStreamer.id}');
      
      // First, try to find existing chat
      final existingChat = await _findExistingChat();
      if (existingChat != null) {
        print('✅ Found existing chat: ${existingChat['id']}');
        _selectedChat = existingChat;
        _showChatView = true;
        return;
      }

      // If no existing chat, create a new one
      print('📝 Creating new chat...');
      final newChat = await _createNewChat();
      if (newChat != null) {
        print('✅ Created new chat: ${newChat['id']}');
        _selectedChat = newChat;
        _showChatView = true;
      } else {
        print('❌ Failed to create chat');
        _showErrorDialog('Failed to create chat. Please try again.');
      }
    } catch (e) {
      print('❌ Error in chat creation: $e');
      _showErrorDialog('Error creating chat: $e');
    }
  }

  Future<Map<String, dynamic>?> _findExistingChat() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: widget.currentUserId!)
          .get();

      for (final doc in query.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        
        if (participants.contains(displayStreamer.id)) {
          return {
            'id': doc.id,
            ...data,
          };
        }
      }
      return null;
    } catch (e) {
      print('Error finding existing chat: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _createNewChat() async {
    try {
      final chatData = {
        'participants': [widget.currentUserId!, displayStreamer.id],
        'lastMessage': '',
        'lastTimestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      final docRef = await FirebaseFirestore.instance
          .collection('chats')
          .add(chatData);

      return {
        'id': docRef.id,
        ...chatData,
      };
    } catch (e) {
      print('Error creating new chat: $e');
      return null;
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0E1220),
        title: const Text(
          'Error',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFF9248d2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowButton() {
    // Don't show follow button for owner
    if (isOwner) {
      return const SizedBox.shrink();
    }

    // Show loading state while checking connection
    if (_isCheckingConnection) {
      return Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

    // Follow button with proper states
    return GestureDetector(
      onTap: _handleFollowButtonTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          gradient: _getFollowButtonGradient(),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            _getFollowButtonText(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  String _getFollowButtonText() {
    if (_isFollowing) {
      return _isConnected ? "Connected" : "Following";
    } else {
      return "Follow";
    }
  }

  LinearGradient? _getFollowButtonGradient() {
    if (_isFollowing) {
      return _isConnected 
        ? const LinearGradient(
            colors: [Color(0xFF25E5D2), Color(0xFF3D99F7)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF955CFF), Color(0xFF3D99F7)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          );
    } else {
      return const LinearGradient(
        colors: [Color(0xFF955CFF), Color(0xFF3D99F7)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );
    }
  }

  void _handleFollowButtonTap() {
    if (_isFollowing) {
      // Handle unfollow logic
      _handleUnfollow();
    } else {
      // Handle follow logic
      _handleFollow();
    }
  }

  void _handleFollow() {
    // Call the follow callback
    widget.onFollow?.call(widget.displayStreamer);
    
    // Update local state optimistically
    setState(() {
      _isFollowing = true;
      _isConnected = _isFollowing && _isFollowedByStreamer;
    });
    
    print('📱 Follow button tapped: ${displayStreamer.displayName}');
  }

  void _handleUnfollow() {
    // Call the unfollow callback
    widget.onFollow?.call(widget.displayStreamer);
    
    // Update local state optimistically
    setState(() {
      _isFollowing = false;
      _isConnected = false;
    });
    
    print('📱 Unfollow button tapped: ${displayStreamer.displayName}');
  }

  void _showConnectionRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0E1220),
        title: const Text(
          'Connection Required',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'You need to be connected with ${displayStreamer.displayName} to send messages. Both users must follow each other.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to follow the user
              _handleFollow();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Follow ${displayStreamer.displayName} to connect!'),
                  backgroundColor: const Color(0xFF9248d2),
                ),
              );
            },
            child: const Text(
              'Follow',
              style: TextStyle(color: Color(0xFF9248d2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildTab('Video', true),
            ),
            Expanded(
              child: _buildTab('Favorites', false),
            ),
            Expanded(
              child: _buildTab('Tagged', false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String text, bool isSelected) {
    return GestureDetector(
      onTap: () {
        // TODO: Implement tab switching
      },
      child: Container(
        height: 32,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentArea() {
    return Expanded(
      child: Center(
        child: Text(
          'No videos yet.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
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
                child: widget.displayStreamer.avatarURL != null && widget.displayStreamer.avatarURL!.isNotEmpty
                    ? Image.network(
                        widget.displayStreamer.avatarURL!,
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
            final statusAsync = ref.watch(userStatusProvider(widget.displayStreamer.id));
            
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
          widget.displayStreamer.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '@${widget.displayStreamer.username}',
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
          // Main content with scroll-based header
          NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (scrollInfo is ScrollUpdateNotification) {
                setState(() {
                  _scrollOffset = scrollInfo.metrics.pixels;
                });
              }
              return false;
            },
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top padding to push content below header
                  SizedBox(height: MediaQuery.of(context).padding.top + 80),
                  
                  // Header section with avatar and basic info
                  _buildHeaderSection(),
                  const SizedBox(height: 24),
                  
                  // Hashtags picker
                  _buildHashtagsPicker(),
                  const SizedBox(height: 24),
                  
                  // Bio section
                  _buildBioSection(),
                  const SizedBox(height: 24),
                  
                  // Platforms section (expandable)
                  _buildPlatformsSection(),
                  const SizedBox(height: 24),
                  
                  // Calendar section (expandable)
                  _buildCalendarSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          
          // Top bar with scroll-based title and flip button
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.of(context).padding.top + 16,
                16,
                16,
              ),
              child: Row(
                children: [
                  AnimatedOpacity(
                    opacity: _scrollOffset > 20 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      displayStreamer.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _flipCard,
                    child: const Icon(
                      Icons.flip,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Avatar with angular gradient border
          Stack(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      Color(0xFF25E5D2),
                      Color(0xFF17C2AD),
                      Color(0xFF8B5CF6),
                      Color(0xFFEC4899),
                      Color(0xFF25E5D2),
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
                      child: displayStreamer.avatarURL != null && displayStreamer.avatarURL!.isNotEmpty
                          ? Image.network(
                              displayStreamer.avatarURL!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Text(
                                  displayStreamer.displayName.isNotEmpty 
                                      ? displayStreamer.displayName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                displayStreamer.displayName.isNotEmpty 
                                    ? displayStreamer.displayName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayStreamer.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${displayStreamer.username}',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHashtagsPicker() {
    if (hashtags.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: hashtags.length,
              itemBuilder: (context, index) {
                final hashtag = hashtags[index];
                final isSelected = _selectedHashtag == hashtag;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () {
                      // MARK: - Hashtag Selection Algorithm
                      setState(() {
                        _selectedHashtag = hashtag; // Always select, no toggle
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFF25E5D2)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isSelected ? null : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected 
                              ? const Color(0xFF25E5D2).withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text(
                        '#$hashtag',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBioSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bio',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            displayStreamer.bio.isEmpty ? 'No bio available.' : displayStreamer.bio,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _showPlatforms = !_showPlatforms;
              });
            },
            child: Row(
              children: [
                const Text(
                  'Platforms',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _showPlatforms ? 0.5 : 0.0,
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
            height: _showPlatforms ? null : 0,
            child: _showPlatforms
                ? StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(displayStreamer.id)
                        .snapshots(),
                    builder: (context, snapshot) {
                      List<Platform> platforms = [];
                      
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data = snapshot.data!.data() as Map<String, dynamic>?;
                        if (data != null && data['platforms'] != null) {
                          final platformsData = data['platforms'] as List<dynamic>;
                          platforms = platformsData.map((platformData) {
                            final platformMap = platformData as Map<String, dynamic>;
                            return Platform(
                              id: (platformMap['id'] ?? '').toString(),
                              type: PlatformType.values.firstWhere(
                                (e) => e.name == (platformMap['type'] ?? '').toString(),
                                orElse: () => PlatformType.other,
                              ),
                              username: (platformMap['username'] ?? '').toString(),
                              followers: platformMap['followers'] as int? ?? 0,
                              url: platformMap['url']?.toString(),
                            );
                          }).toList();
                          print('🔗 StreamerCardView: Loaded ${platforms.length} platforms from real-time listener');
                        }
                      }
                      
                      if (platforms.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      
                      return Column(
                        children: [
                          const SizedBox(height: 16),
                          ...platforms.map((platform) {
                            return _buildPlatformRow(platform);
                          }),
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
                        .doc(displayStreamer.id)
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
                          print('📅 StreamerCardView: Loaded ${events.length} events from real-time listener');
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
              onTap: () => _toggleBookmark(event.id),
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
}
