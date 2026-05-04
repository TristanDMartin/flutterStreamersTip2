import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/streamer_card.dart';
import '../services/following_service.dart';
import '../services/global_post_count_fix.dart';
import '../widgets/chat_view_optimized.dart';
import '../models/chat.dart' as app_chat;
import 'online_status_indicator.dart';
import 'brand_icons.dart';
import '../constants/app_colors.dart';
import '../core/theme/support_shell_style.dart';

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
  State<StreamerCardViewOptimized> createState() =>
      _StreamerCardViewOptimizedState();
}

class _StreamerCardViewOptimizedState extends State<StreamerCardViewOptimized>
    with TickerProviderStateMixin {
  // Pre-defined gradients for better performance - using your preferred color palette
  static const LinearGradient _mainGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: AppColors.supportSurfaceGradient,
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
  final bool _isFollowedByStreamer = false;
  bool _isConnected = false;
  final bool _isCheckingConnection = false;

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

    // Fix post count for this user automatically
    _fixUserPostCountIfNeeded();

    // TEMPORARY: Disable ALL async operations to prevent app backgrounding // cspell:ignore backgrounding
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

  /// Fix post count for this user using the global fix service
  Future<void> _fixUserPostCountIfNeeded() async {
    try {
      if (kDebugMode) {
        debugPrint(
            '🌍 STREAMER CARD: Auto-fixing post count for user ${widget.displayStreamer.id}');
      }

      final globalFix = GlobalPostCountFix();
      final success =
          await globalFix.fixUserPostCount(widget.displayStreamer.id);

      if (success) {
        if (kDebugMode) {
          debugPrint(
              '🌍 STREAMER CARD: Successfully fixed post count for user ${widget.displayStreamer.id}');
        }
      } else {
        if (kDebugMode) {
          debugPrint(
              '🌍 STREAMER CARD: Failed to fix post count for user ${widget.displayStreamer.id}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '🌍 STREAMER CARD: Error fixing post count for user ${widget.displayStreamer.id}: $e');
      }
    }
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
          if (_showChatView && _selectedChat != null) _buildChatOverlay(),
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
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Container(
      color: shell.scaffold,
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
              SliverToBoxAdapter(
                  child: _buildSectionHeader('Bio', _showBio,
                      () => setState(() => _showBio = !_showBio))),
              if (_showBio) SliverToBoxAdapter(child: _buildBioBody()),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(
                  child: _buildSectionHeader('Platforms', _showPlatforms,
                      () => setState(() => _showPlatforms = !_showPlatforms))),
              if (_showPlatforms)
                SliverToBoxAdapter(child: _buildPlatformsBody()),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(
                  child: _buildSectionHeader('Calendar', _showCalendar,
                      () => setState(() => _showCalendar = !_showCalendar))),
              if (_showCalendar)
                SliverToBoxAdapter(child: _buildCalendarBody()),
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
          16, MediaQuery.of(context).padding.top + 14, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
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
                Icons.arrow_back,
                color: Colors.white,
                size: 22,
              ),
            ),
            Text(
              'Streamer Profile',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
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
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.more_horiz,
                  color: Colors.white,
                  size: 22,
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
        const SizedBox(height: 14),
        _buildAvatarWithOnlineIndicator(),
        const SizedBox(height: 14),
        _buildProfileTextInfo(),
        const SizedBox(height: 8),
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
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '@${_currentStreamerCard.username}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.74),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (_currentStreamerCard.bio.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _currentStreamerCard.bio,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatisticsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
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
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
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
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          gradient: _getFollowButtonGradient(),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.16),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.supportAccent.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            _getFollowButtonText(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onMessage?.call(displayStreamer.id);
      },
      child: Container(
        height: 46,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: const Center(
          child: Text(
            'Message',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShareButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onShare?.call(displayStreamer.id);
      },
      child: Container(
        height: 46,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: const Center(
          child: Text(
            'Share',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Row(
          children: _buildTabs(),
        ),
      ),
    );
  }

  List<Widget> _buildTabs() {
    final tabs = <Widget>[
      Expanded(child: _buildTab('Video', 0)),
    ];

    // Only show Favorites tab if privacy allows it
    if (displayStreamer.privacy.showFavoritesOnCard) {
      tabs.add(Expanded(child: _buildTab('Favorites', 1)));
    }

    tabs.add(Expanded(child: _buildTab('Tagged', 2)));

    return tabs;
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
        height: 40,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: AppColors.supportAccentGradient,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.72),
              fontSize: 15,
              fontWeight: FontWeight.w700,
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
    // Get the actual tab type based on current selection and privacy settings
    final tabType = _getTabType(_selectedTabIndex);

    switch (tabType) {
      case TabType.videos:
        return _buildVideosTab();
      case TabType.favorites:
        return _buildFavoritesTab();
      case TabType.tagged:
        return _buildTaggedTab();
    }
  }

  TabType _getTabType(int selectedIndex) {
    if (selectedIndex == 0) return TabType.videos;

    // If Favorites are hidden, Tagged is at index 1
    if (!displayStreamer.privacy.showFavoritesOnCard) {
      return selectedIndex == 1 ? TabType.tagged : TabType.videos;
    }

    // If Favorites are shown, they're at index 1, Tagged at index 2
    if (selectedIndex == 1) return TabType.favorites;
    if (selectedIndex == 2) return TabType.tagged;

    return TabType.videos;
  }

  Widget _buildVideosTab() {
    return const _EmptyStateWidget(
      icon: Icons.video_library_outlined,
      message: 'No videos yet',
    );
  }

  Widget _buildFavoritesTab() {
    // Check if this is the owner viewing their own card
    if (isOwner && !displayStreamer.privacy.showFavoritesOnCard) {
      return _buildOwnerNotice();
    }

    return const _EmptyStateWidget(
      icon: Icons.favorite_outline,
      message: 'No favorites yet',
    );
  }

  Widget _buildOwnerNotice() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.visibility_off,
            color: Colors.white.withValues(alpha: 0.6),
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Favorites are hidden on your public card',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Change in Edit Profile',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              'Streamer Details',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: _flipCard,
              icon: const Icon(Icons.flip, color: Colors.white, size: 22),
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
            child: displayStreamer.avatarURL != null &&
                    displayStreamer.avatarURL!.isNotEmpty
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
                  color: isSelected
                      ? Colors.transparent
                      : Colors.white.withValues(alpha: 0.2),
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

  Widget _buildSectionHeader(
      String title, bool isExpanded, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
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
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: 1,
            ),
          ),
          child: Text(
            'No platforms connected',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: BrandIcon(
                      platformType: platform.type.name,
                      size: 22,
                    ),
                  ),
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
                const Icon(Icons.calendar_today_outlined,
                    color: Colors.white, size: 22),
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
                  participants:
                      List<String>.from(_selectedChat!['participants'] ?? []),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.supportAccentGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon,
                  size: 30,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This section will show up here once there is something to share.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum TabType {
  videos,
  favorites,
  tagged,
}
