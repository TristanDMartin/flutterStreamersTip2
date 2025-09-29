import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/streamer_card.dart';
import '../services/following_service.dart';
import '../widgets/chat_view_optimized.dart';
import '../models/chat.dart' as app_chat;
import 'online_status_indicator.dart';
import 'brand_icons.dart';

class StreamerCardViewOptimized extends StatefulWidget {
  final StreamerCard displayStreamer;
  final String? currentUserId;
  final VoidCallback? onDismiss;
  final Function(String userId)? onFollow;
  final Function(String userId)? onMessage;
  final Function(String userId)? onShare;

  const StreamerCardViewOptimized({
    super.key,
    required this.displayStreamer,
    this.currentUserId,
    this.onDismiss,
    this.onFollow,
    this.onMessage,
    this.onShare,
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
  

  
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFront = true;
  
  // State Management
  String _selectedHashtag = "";
  bool _showBio = true;
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
    
    // TEMPORARY: Disable ALL async operations to prevent app backgrounding
    // _checkConnectionStatus();
    // _loadCalendarEvents();
    // _loadPlatforms();
    // _profileUpdateService = ProfileUpdateService();
    // _profileUpdateService?.addStreamerCardViewListener(_onProfileUpdated);
  }

  // Computed Properties
  StreamerCard get displayStreamer => widget.displayStreamer;
  
  List<String> get hashtags => _currentStreamerCard.hashtags;
  
  int get selectedHashtagIndex {
    final index = hashtags.indexOf(_selectedHashtag);
    return index >= 0 ? index : 0;
  }
  
  bool get isOwner {
    final currentUserId = widget.currentUserId ?? '';
    return currentUserId == _currentStreamerCard.id;
  }

  @override
  void dispose() {
    // TEMPORARY: Disable cleanup to prevent issues
    // _profileUpdateService?.removeStreamerCardViewListener(_onProfileUpdated);
    _flipController.dispose();
    super.dispose();
  }


  /// Get the current streamer card data - simplified for testing
  StreamerCard get _currentStreamerCard {
    // TEMPORARY: Always use widget data to prevent any async issues
    return displayStreamer;
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildBackViewHeader()),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(child: _buildIdentity()),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(child: _buildTags()),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(child: _buildSectionHeader('Bio', _showBio, () => setState(() => _showBio = !_showBio))),
              if (_showBio) SliverToBoxAdapter(child: _buildBioBody()),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(child: _buildSectionHeader('Platforms', _showPlatforms, () => setState(() => _showPlatforms = !_showPlatforms))),
              if (_showPlatforms) SliverToBoxAdapter(child: _buildPlatformsBody()),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(child: _buildSectionHeader('Calendar', _showCalendar, () => setState(() => _showCalendar = !_showCalendar))),
              if (_showCalendar) SliverToBoxAdapter(child: _buildCalendarBody()),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        ),
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
                onTap: () {
                  HapticFeedback.lightImpact();
                  _flipCard();
                },
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
          backgroundImage: _currentStreamerCard.avatarURL != null
              ? NetworkImage(_currentStreamerCard.avatarURL!)
              : null,
          child: _currentStreamerCard.avatarURL == null
              ? Text(
                  _currentStreamerCard.displayName.isNotEmpty
                      ? _currentStreamerCard.displayName[0].toUpperCase()
                      : 'S',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        // Dynamic online status indicator
        AvatarOnlineIndicator(
          userId: _currentStreamerCard.id,
          avatarSize: 100, // 50 * 2 (radius * 2)
          indicatorSize: 20,
          showBorder: true,
          borderColor: Colors.black,
          borderWidth: 2,
          showShadow: true,
        ),
      ],
    );
  }

  Widget _buildProfileTextInfo() {
    return Column(
      children: [
        Text(
          _currentStreamerCard.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '@${_currentStreamerCard.username}',
          style: const TextStyle(
            color: Color(0xB3FFFFFF), // Pre-computed opacity
            fontSize: 16,
          ),
        ),
        if (_currentStreamerCard.bio.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _currentStreamerCard.bio,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xCCFFFFFF), // Pre-computed opacity
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
            color: Color(0xB3FFFFFF), // Pre-computed opacity
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    print('🔵 StreamerCardView: _buildActionButtons called');
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
          color: Colors.white.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha:0.2),
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
            color: Colors.white.withValues(alpha:0.2),
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
    print('🔵 StreamerCardView: _buildMessageButton called - isOwner: $isOwner, _isCheckingConnection: $_isCheckingConnection, _isConnected: $_isConnected');
    
    // ULTRA SIMPLE TEST: Just a basic container with tap
    return GestureDetector(
      onTap: () {
        print('🔵 ULTRA SIMPLE: Message button tapped!');
        print('🔵 ULTRA SIMPLE: Current _isCheckingConnection: $_isCheckingConnection');
        // Show a very obvious visual change
        setState(() {
          _isCheckingConnection = !_isCheckingConnection;
        });
        print('🔵 ULTRA SIMPLE: After setState _isCheckingConnection: $_isCheckingConnection');
      },
      child: Container(
        height: 60, // Make it bigger and more obvious
        width: double.infinity,
        decoration: BoxDecoration(
          color: _isCheckingConnection ? Colors.red : Colors.blue,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 2), // Add white border
        ),
        child: Center(
          child: Text(
            _isCheckingConnection ? 'TAPPED!' : 'Message',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18, // Make text bigger
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShareButton() {
    // ULTRA SIMPLE TEST: Just a basic container with tap
    return GestureDetector(
      onTap: () {
        print('🔵 ULTRA SIMPLE: Share button tapped!');
        print('🔵 ULTRA SIMPLE: Current _showBio: $_showBio');
        // Show a very obvious visual change
        setState(() {
          _showBio = !_showBio; // Toggle some state
        });
        print('🔵 ULTRA SIMPLE: After setState _showBio: $_showBio');
      },
      child: Container(
        height: 60, // Make it bigger and more obvious
        width: double.infinity,
        decoration: BoxDecoration(
          color: _showBio ? Colors.green : Colors.orange,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 2), // Add white border
        ),
        child: Center(
          child: Text(
            _showBio ? 'TAPPED!' : 'Share',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18, // Make text bigger
              fontWeight: FontWeight.bold,
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
          color: Colors.white.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha:0.2),
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
          color: isSelected ? Colors.white.withValues(alpha:0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withValues(alpha:0.7),
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
  Widget _buildBackViewHeader() {
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
        children: [
          _buildAvatarWithGradient(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
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

  Widget _buildAvatarWithGradient() {
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
            child: displayStreamer.avatarURL != null && displayStreamer.avatarURL!.isNotEmpty
                ? Image.network(displayStreamer.avatarURL!, fit: BoxFit.cover)
                : const Icon(Icons.person, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildTags() {
    if (displayStreamer.hashtags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: displayStreamer.hashtags.map((tag) {
          final isSelected = _selectedHashtag == tag;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedHashtag = isSelected ? '' : tag;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: isSelected ? _connectedGradient : null,
                color: isSelected ? null : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Text(
                '#$tag',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isExpanded, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(
                isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.white,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBioBody() {
    if (displayStreamer.bio.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'No bio available',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
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

  Widget _buildPlatformsBody() {
    if (displayStreamer.platforms.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'No platforms connected',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: displayStreamer.platforms.map((platform) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
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
                    platformType: platform.type.name,
                    size: 40,
                  ),
                const SizedBox(width: 12),
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
                      if (platform.username.isNotEmpty)
                        Text(
                          '@${platform.username}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                if (platform.followers > 0)
                  Text(
                    '${platform.followers} followers',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendarBody() {
    if (displayStreamer.calendarEvents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'No upcoming events',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: displayStreamer.calendarEvents.map((event) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.calendar_today_outlined, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event.description,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatEventDate(event.date),
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
          );
        }).toList(),
      ),
    );
  }

  String _formatEventDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;
    
    if (difference == 0) {
      return 'Today at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference == 1) {
      return 'Tomorrow at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference > 0) {
      return 'In $difference days';
    } else {
      return 'Past event';
    }
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
    // print('Error following streamer: $e');
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
    // print('Error unfollowing streamer: $e');
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
            color: const Color(0x80FFFFFF), // Pre-computed opacity
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xB3FFFFFF), // Pre-computed opacity
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
