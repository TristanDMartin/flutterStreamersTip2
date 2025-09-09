import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart' as app_user;
import '../services/profile_update_service.dart';
import '../views/menu_view.dart';
import 'edit_profile_view.dart';
import 'share_profile_view.dart';
import 'profile_back_view.dart';
import 'online_status_indicator.dart';

class ProfileViewOptimized extends ConsumerStatefulWidget {
  final app_user.User user;
  final bool isCurrentUser;

  const ProfileViewOptimized({
    super.key,
    required this.user,
    required this.isCurrentUser,
  });

  @override
  ConsumerState<ProfileViewOptimized> createState() => _ProfileViewOptimizedState();
}

class _ProfileViewOptimizedState extends ConsumerState<ProfileViewOptimized>
    with TickerProviderStateMixin {
  late AnimationController _segmentedController;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  int _selectedTabIndex = 0; // 0: Video, 1: Favorites, 2: Tagged
  bool _isFront = true;
  late ProfileUpdateService _profileUpdateService;

  @override
  void initState() {
    super.initState();
    _segmentedController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
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
    _profileUpdateService = ProfileUpdateService();
    
    // Listen for profile updates
    _profileUpdateService.addProfileViewListener(_onProfileUpdated);
  }

  @override
  void dispose() {
    _profileUpdateService.removeProfileViewListener(_onProfileUpdated);
    _segmentedController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  void _onProfileUpdated() {
    if (mounted) {
      debugPrint('🔄 ProfileViewOptimized: Profile updated, triggering rebuild');
      debugPrint('🔄 ProfileViewOptimized: Current user data: ${_profileUpdateService.userData}');
      setState(() {
        // Trigger rebuild when profile data is updated
        // The ProfileUpdateService will have the latest user data
      });
    }
  }

  void _flipCard() {
    HapticFeedback.lightImpact();
    if (_isFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    _isFront = !_isFront;
  }

  /// Get the current user data, either from widget or from ProfileUpdateService
  Map<String, dynamic> get _currentUserData {
    // Check if this is the current user by comparing user IDs
    final currentUserId = _profileUpdateService.currentUser?.uid;
    final isCurrentUser = currentUserId != null && currentUserId == widget.user.id;
    
    debugPrint('🔍 ProfileViewOptimized: currentUserId: $currentUserId, widget.user.id: ${widget.user.id}');
    debugPrint('🔍 ProfileViewOptimized: isCurrentUser: $isCurrentUser, isDataLoaded: ${_profileUpdateService.isDataLoaded}');
    
    // If this is the current user, get data from ProfileUpdateService
    if (isCurrentUser && _profileUpdateService.isDataLoaded) {
      debugPrint('🔍 ProfileViewOptimized: Using ProfileUpdateService data: ${_profileUpdateService.userData}');
      return _profileUpdateService.userData ?? widget.user.toMap();
    }
    // Otherwise use the widget user data
    debugPrint('🔍 ProfileViewOptimized: Using widget user data: ${widget.user.toMap()}');
    return widget.user.toMap();
  }

  void _onTabSelected(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedTabIndex = index;
    });
    _segmentedController.forward().then((_) {
      _segmentedController.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: AnimatedBuilder(
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
    );
  }

  Widget _buildFrontView() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF6633CC), // Purple (matches NetworkView)
            Color(0xFF1A1A4D), // Dark blue (matches NetworkView)
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: null,
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(
                Icons.flip,
                color: Colors.white,
                size: 24,
              ),
              onPressed: _flipCard,
            ),
            IconButton(
              icon: Icon(
                Icons.more_horiz,
                color: Colors.white.withOpacity(0.7),
                size: 24,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const MenuView(),
                  ),
                );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 24),
              _buildProfileHeader(),
              const SizedBox(height: 24),
              _buildProfileContent(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackView() {
    return ProfileBackView(
      user: _currentUserData,
      onFlip: _flipCard,
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        _buildAvatarWithGradientRing(),
        const SizedBox(height: 16),
        _buildNameAndHandle(),
        const SizedBox(height: 24),
        _buildStatsRow(),
        const SizedBox(height: 24),
        _buildPrimaryButtonsRow(),
        const SizedBox(height: 24),
        _buildSegments(),
        const SizedBox(height: 16),
        _buildContentArea(),
      ],
    );
  }

  Widget _buildAvatarWithGradientRing() {
    return Stack(
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(
              colors: [
                Color(0xFFFF6B9D), // Pink
                Color(0xFF955CFF), // Purple
                Color(0xFF3D99F7), // Blue
                Color(0xFFFF6B9D), // Pink
              ],
            ),
          ),
          padding: const EdgeInsets.all(4),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0A0A0A),
            ),
            padding: const EdgeInsets.all(4),
            child: CircleAvatar(
              radius: 48,
              backgroundImage: _currentUserData['avatarURL'] != null
                  ? NetworkImage(_currentUserData['avatarURL'])
                  : null,
              child: _currentUserData['avatarURL'] == null
                  ? const Icon(
                      Icons.person,
                      size: 48,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),
        ),
        // Online status indicator
        if (widget.isCurrentUser)
          AvatarOnlineIndicator(
            userId: _currentUserData['id'] ?? '',
            avatarSize: 112,
            indicatorSize: 18,
            showBorder: true,
            borderColor: Colors.white,
            borderWidth: 3,
            showShadow: true,
          ),
      ],
    );
  }

  Widget _buildNameAndHandle() {
    return Column(
      children: [
        Text(
          _currentUserData['displayName'] ?? 'Unknown User',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '@${_currentUserData['username'] ?? 'unknown'}',
          style: TextStyle(
            color: Colors.white.withOpacity(0.75),
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatItem('Posts', '0'),
        const SizedBox(width: 54),
        _buildStatItem('Followers', '0'),
        const SizedBox(width: 54),
        _buildStatItem('Following', '0'),
      ],
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

  Widget _buildPrimaryButtonsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildGradientPillButton(
              text: 'Edit Profile',
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => EditProfileView(
                      user: _currentUserData,
                      onUserUpdated: (updatedUser) {
                        // TODO: Handle user update
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildGradientPillButton(
              text: 'Share Profile',
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ShareProfileView(
                      user: _currentUserData,
                      dismiss: () => Navigator.of(context).pop(),
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

  Widget _buildGradientPillButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF955CFF), Color(0xFF3D99F7)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(24),
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

  Widget _buildSegments() {
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
        onTap: () => _onTabSelected(index),
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
    switch (_selectedTabIndex) {
      case 0:
        return _buildVideoContent();
      case 1:
        return _buildFavoritesContent();
      case 2:
        return _buildTaggedContent();
      default:
        return _buildVideoContent();
    }
  }

  Widget _buildVideoContent() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Text(
          'No videos yet.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildFavoritesContent() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Text(
          'No videos yet.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTaggedContent() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Text(
          'No videos yet.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent() {
    return const SizedBox.shrink();
  }
}