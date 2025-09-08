import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/streamer_card.dart';
import '../models/user.dart' as app_user;
import '../models/home_video.dart';
import '../services/following_service.dart';
import '../services/share_service_optimized.dart';
import '../widgets/chat_view_optimized.dart';
import '../models/chat.dart' as app_chat;

class StreamerCardViewOptimized extends StatefulWidget {
  final StreamerCard displayStreamer;
  final String? currentUserId;
  final VoidCallback? onDismiss;

  const StreamerCardViewOptimized({
    super.key,
    required this.displayStreamer,
    this.currentUserId,
    this.onDismiss,
  });

  @override
  State<StreamerCardViewOptimized> createState() => _StreamerCardViewOptimizedState();
}

class _StreamerCardViewOptimizedState extends State<StreamerCardViewOptimized>
    with TickerProviderStateMixin {
  // Pre-defined gradients for better performance - using your preferred color palette
  static const LinearGradient _mainGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF9248D2), // Rich purple
      Color(0xFF7768DF), // Purple
      Color(0xFF1670DE), // Blue
      Color(0xFF3C8BD6), // Lighter blue
      Color(0xFF4897D2), // Lightest blue
    ],
  );
  
  static const LinearGradient _connectedGradient = LinearGradient(
    colors: [Color(0xFF25E5D2), Color(0xFF3D99F7)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  
  static const LinearGradient _followingGradient = LinearGradient(
    colors: [Color(0xFF9248D2), Color(0xFF7768DF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  
  static const LinearGradient _shareGradient = LinearGradient(
    colors: [Color(0xFF9248D2), Color(0xFF3C8BD6)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFront = true;
  
  // State Management
  String _selectedHashtag = "";
  bool _showPlatforms = true;
  bool _showCalendar = true;
  bool _isFollowing = false;
  bool _isFollowedByStreamer = false;
  bool _isConnected = false;
  bool _isCheckingConnection = false;
  
  // Content tabs
  int _selectedTabIndex = 0; // 0: Video, 1: Favorites, 2: Tagged
  
  // Chat UI State
  bool _showChatView = false;
  Map<String, dynamic>? _selectedChat;
  
  // Calendar and platforms data
  List<Map<String, dynamic>> _calendarEvents = [];
  List<Map<String, dynamic>> _platforms = [];

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
    
    // Load additional data
    _loadCalendarEvents();
    _loadPlatforms();
  }

  // Computed Properties
  StreamerCard get displayStreamer => widget.displayStreamer;
  
  List<String> get hashtags => displayStreamer.hashtags;
  
  int get selectedHashtagIndex {
    final index = hashtags.indexOf(_selectedHashtag);
    return index >= 0 ? index : 0;
  }
  
  bool get isOwner {
    final currentUserId = widget.currentUserId ?? '';
    return currentUserId == displayStreamer.id;
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  // Connection Status - Optimized with caching
  Future<void> _checkConnectionStatus() async {
    if (widget.currentUserId == null || widget.currentUserId == displayStreamer.id) {
      return;
    }

    // Skip if already checked
    if (!_isCheckingConnection && (_isFollowing || _isFollowedByStreamer)) {
      return;
    }

    if (mounted) {
      setState(() {
        _isCheckingConnection = true;
      });
    }

    try {
      // Run both checks in parallel for better performance
      final results = await Future.wait([
        _checkIfFollowing(displayStreamer.id),
        _checkIfFollowedBy(displayStreamer.id),
      ]);
      
      final isFollowing = results[0] as bool;
      final isFollowedByStreamer = results[1] as bool;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main content
          Container(
            decoration: const BoxDecoration(
              gradient: _mainGradient,
            ),
            child: SafeArea(
              child: AnimatedBuilder(
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
            ),
          ),
          
          // Chat overlay
          if (_showChatView && _selectedChat != null)
            _buildChatOverlay(),
        ],
      ),
    );
  }

  Widget _buildFrontView() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: _mainGradient,
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

  Widget _buildBackView() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: _mainGradient,
      ),
      child: Stack(
        children: [
          // Main content with scroll-based header
          SingleChildScrollView(
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
          
          // Top bar with scroll-based title and flip button
          _buildBackViewTopBar(),
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
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onDismiss?.call();
            },
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
                onTap: () {
                  HapticFeedback.lightImpact();
                  _flipCard();
                },
                child: const Text(
                  'Flip',
                  style: TextStyle(
                    color: Color(0xFF25E5D2), // Teal/greenish color
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
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
        const SizedBox(height: 20),
        _buildAvatarWithOnlineIndicator(),
        const SizedBox(height: 16),
        _buildProfileTextInfo(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildAvatarWithOnlineIndicator() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundImage: displayStreamer.avatarURL != null
              ? NetworkImage(displayStreamer.avatarURL!)
              : null,
          child: displayStreamer.avatarURL == null
              ? Text(
                  displayStreamer.displayName.isNotEmpty
                      ? displayStreamer.displayName[0].toUpperCase()
                      : 'S',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF00D4AA),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTextInfo() {
    return Column(
      children: [
        Text(
          displayStreamer.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '@${displayStreamer.username}',
          style: const TextStyle(
            color: Color(0xFFB3FFFFFF), // Pre-computed opacity
            fontSize: 16,
          ),
        ),
        if (displayStreamer.bio.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            displayStreamer.bio,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFCCFFFFFF), // Pre-computed opacity
              fontSize: 14,
            ),
          ),
        ],
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
          style: const TextStyle(
            color: Color(0xFFB3FFFFFF), // Pre-computed opacity
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
          // Follow Button (First)
          Expanded(
            child: _buildFollowButton(),
          ),
          const SizedBox(width: 12),
          // Message Button (Second)
          Expanded(
            child: _buildMessageButton(),
          ),
          const SizedBox(width: 12),
          // Share Button (Third)
          Expanded(
            child: _buildShareButton(),
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
      onTap: _isConnected ? _handleMessageButtonTap : null,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: _isConnected 
              ? Colors.white.withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isConnected 
                ? Colors.white.withOpacity(0.2)
                : Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            'Message',
            style: TextStyle(
              color: _isConnected 
                  ? Colors.white 
                  : Colors.white.withOpacity(0.3),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShareButton() {
    return GestureDetector(
      onTap: _handleShareButtonTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          gradient: _shareGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: const Center(
          child: Text(
            'Share',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildTab('Video', 0),
            ),
            Expanded(
              child: _buildTab('Favorites', 1),
            ),
            Expanded(
              child: _buildTab('Tagged', 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String text, int index) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: Container(
        height: 32,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
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
      child: _buildTabContent(),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0: // Videos
        return _buildVideosTab();
      case 1: // Favorites
        return _buildFavoritesTab();
      case 2: // Tagged
        return _buildTaggedTab();
      default:
        return _buildVideosTab();
    }
  }

  Widget _buildVideosTab() {
    return const _EmptyStateWidget(
      icon: Icons.video_library_outlined,
      message: 'No videos yet',
    );
  }

  Widget _buildFavoritesTab() {
    return const _EmptyStateWidget(
      icon: Icons.favorite_outline,
      message: 'No favorites yet',
    );
  }

  Widget _buildTaggedTab() {
    return const _EmptyStateWidget(
      icon: Icons.tag,
      message: 'No tagged content yet',
    );
  }

  // Back View Components
  Widget _buildBackViewTopBar() {
    return Positioned(
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF6137EB).withOpacity(0.9),
              const Color(0xFF6137EB).withOpacity(0.0),
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onDismiss?.call();
              },
              child: const Icon(
                Icons.chevron_left,
                color: Colors.white,
                size: 24,
              ),
            ),
            Text(
              displayStreamer.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _flipCard();
              },
              child: const Text(
                'Flip',
                style: TextStyle(
                  color: Color(0xFF25E5D2),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: displayStreamer.avatarURL != null
                ? NetworkImage(displayStreamer.avatarURL!)
                : null,
            child: displayStreamer.avatarURL == null
                ? Text(
                    displayStreamer.displayName.isNotEmpty
                        ? displayStreamer.displayName[0].toUpperCase()
                        : 'S',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
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
                Text(
                  '@${displayStreamer.username}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: hashtags.length,
          itemBuilder: (context, index) {
            final hashtag = hashtags[index];
            final isSelected = hashtag == _selectedHashtag;
            
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedHashtag = hashtag;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Colors.white.withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '#$hashtag',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBioSection() {
    if (displayStreamer.bio.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Text(
          displayStreamer.bio,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Platforms',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _showPlatforms = !_showPlatforms;
                  });
                },
                icon: Icon(
                  _showPlatforms ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          if (_showPlatforms) ...[
            const SizedBox(height: 8),
            if (_platforms.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'No platforms connected yet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              )
            else
              ..._platforms.map((platform) => _buildPlatformCard(platform)),
          ],
        ],
      ),
    );
  }

  Widget _buildPlatformCard(Map<String, dynamic> platform) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getPlatformIcon(platform['type']),
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  platform['type'].toString().toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '@${platform['username']}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _openPlatform(platform['url']),
            icon: const Icon(Icons.open_in_new, color: Colors.white, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Calendar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _showCalendar = !_showCalendar;
                  });
                },
                icon: Icon(
                  _showCalendar ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          if (_showCalendar) ...[
            const SizedBox(height: 8),
            if (_calendarEvents.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'No upcoming events',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              )
            else
              ..._calendarEvents.map((event) => _buildEventCard(event)),
          ],
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event['title'] ?? 'Event',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (event['description'] != null) ...[
            const SizedBox(height: 4),
            Text(
              event['description'],
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
          if (event['date'] != null) ...[
            const SizedBox(height: 4),
            Text(
              _formatEventDate(event['date']),
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Data loading methods - Optimized with caching
  Future<void> _loadCalendarEvents() async {
    // Skip if already loaded
    if (_calendarEvents.isNotEmpty) return;
    
    try {
      // TODO: Load calendar events from Firebase with caching
      // This would typically fetch from a calendar events collection
      if (mounted) {
        setState(() {
          _calendarEvents = [];
        });
      }
    } catch (e) {
      print('Error loading calendar events: $e');
    }
  }

  Future<void> _loadPlatforms() async {
    // Skip if already loaded
    if (_platforms.isNotEmpty) return;
    
    try {
      // TODO: Load platforms from Firebase with caching
      // This would typically fetch from a platforms collection
      if (mounted) {
        setState(() {
          _platforms = [];
        });
      }
    } catch (e) {
      print('Error loading platforms: $e');
    }
  }

  // Utility methods
  String _formatEventDate(dynamic date) {
    if (date is DateTime) {
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'TBD';
  }

  IconData _getPlatformIcon(String type) {
    switch (type.toLowerCase()) {
      case 'youtube':
        return Icons.play_circle_filled;
      case 'twitch':
        return Icons.live_tv;
      case 'instagram':
        return Icons.camera_alt;
      case 'tiktok':
        return Icons.music_note;
      case 'facebook':
        return Icons.facebook;
      case 'twitter':
        return Icons.alternate_email;
      case 'bluesky':
        return Icons.cloud;
      case 'kick':
        return Icons.sports_esports;
      case 'rednote':
        return Icons.note;
      default:
        return Icons.link;
    }
  }

  void _openPlatform(String? url) {
    HapticFeedback.lightImpact();
    // TODO: Open platform URL using url_launcher
    print('Opening platform: $url');
  }

  Widget _buildChatOverlay() {
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            // Chat header
            Container(
              padding: const EdgeInsets.all(16),
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
                  const Expanded(
                    child: Text(
                      'Chat',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the back button
                ],
              ),
            ),
            // Chat content
            Expanded(
              child: ChatViewOptimized(
                chat: app_chat.Chat(
                  id: _selectedChat!['id'],
                  participants: List<String>.from(_selectedChat!['participants'] ?? []),
                  lastMessage: _selectedChat!['lastMessage'] ?? '',
                  lastTimestamp: DateTime.now(),
                  chatType: 'direct',
                ),
                otherUserId: displayStreamer.id,
                otherUserName: displayStreamer.displayName,
                otherUserAvatarURL: displayStreamer.avatarURL,
                otherUserIsOnline: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Action Handlers
  void _flipCard() {
    HapticFeedback.lightImpact();
    if (_isFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    _isFront = !_isFront;
  }

  String _getFollowButtonText() {
    if (_isFollowing) {
      return _isConnected ? "Connected" : "Following";
    } else {
      return "Follow";
    }
  }

  LinearGradient _getFollowButtonGradient() {
    if (_isFollowing) {
      return _isConnected ? _connectedGradient : _followingGradient;
    } else {
      return _followingGradient;
    }
  }

  void _handleFollowButtonTap() {
    HapticFeedback.lightImpact();
    
    if (_isFollowing) {
      _handleUnfollow();
    } else {
      _handleFollow();
    }
  }

  void _handleFollow() async {
    try {
      final success = await FollowingService.followUser(displayStreamer.id);
      
      if (success) {
        setState(() {
          _isFollowing = true;
          _isConnected = _isFollowing && _isFollowedByStreamer;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Now following ${displayStreamer.displayName}!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Failed to follow user');
      }
    } catch (e) {
      print('Error following streamer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error following ${displayStreamer.displayName}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _handleUnfollow() async {
    try {
      final success = await FollowingService.unfollowUser(displayStreamer.id);
      
      if (success) {
        setState(() {
          _isFollowing = false;
          _isConnected = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unfollowed ${displayStreamer.displayName}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Failed to unfollow user');
      }
    } catch (e) {
      print('Error unfollowing streamer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error unfollowing ${displayStreamer.displayName}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _handleMessageButtonTap() {
    HapticFeedback.lightImpact();
    
    if (!_isConnected) {
      _showConnectionRequiredDialog();
      return;
    }

    _findOrCreateChat();
  }

  void _handleShareButtonTap() {
    HapticFeedback.lightImpact();
    
    // Create user object for sharing
    final user = app_user.User(
      id: displayStreamer.id,
      username: displayStreamer.username,
      displayName: displayStreamer.displayName,
      avatarURL: displayStreamer.avatarURL,
      bio: displayStreamer.bio,
      hashtags: displayStreamer.hashtags,
    );
    
    // Create HomeVideo object for sharing
    final homeVideo = HomeVideo(
      id: 'profile_${displayStreamer.id}',
      videoURL: '',
      thumbnailURL: displayStreamer.avatarURL ?? '',
      caption: 'Check out ${displayStreamer.displayName} on StreamersTip!\n\n@${displayStreamer.username}\n\n${displayStreamer.bio}\n\n#StreamersTip',
      creator: user,
      likes: 0,
      comments: 0,
      isLiked: false,
      isFavorited: false,
    );
    
    // Share using the optimized service
    ShareServiceOptimized().shareVideo(homeVideo);
  }

  void _showConnectionRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Connection Required',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'You need to be connected with this streamer to send messages. Follow them and wait for them to follow you back.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFF9248D2)),
            ),
          ),
        ],
      ),
    );
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
        setState(() {
          _showChatView = true;
        });
        return;
      }

      // If no existing chat, create a new one
      print('📝 Creating new chat...');
      final newChat = await _createNewChat();
      if (newChat != null) {
        print('✅ Created new chat: ${newChat['id']}');
        _selectedChat = newChat;
        setState(() {
          _showChatView = true;
        });
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
        'chatType': 'direct',
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
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Error',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFF9248D2)),
            ),
          ),
        ],
      ),
    );
  }
}

// Optimized const widget for empty states
class _EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyStateWidget({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: const Color(0xFF80FFFFFF), // Pre-computed opacity
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFFB3FFFFFF), // Pre-computed opacity
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
