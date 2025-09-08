import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/streamer_card.dart';
import '../models/user.dart' as app_user;
import '../services/user_service.dart';

class StreamerBackView extends StatefulWidget {
  final StreamerCard streamer;
  final VoidCallback? onDismiss;
  
  const StreamerBackView({
    super.key,
    required this.streamer,
    this.onDismiss,
  });

  @override
  State<StreamerBackView> createState() => _StreamerBackViewState();
}

class _StreamerBackViewState extends State<StreamerBackView>
    with TickerProviderStateMixin {
  // Pre-defined gradients for better performance - matching SwiftUI specifications
  static const LinearGradient _mainGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF6633CC), // Purple (red: 0.4, green: 0.2, blue: 0.8)
      Color(0xFF1A1A4D), // Dark blue (red: 0.1, green: 0.1, blue: 0.3)
    ],
  );
  
  // Hashtag chip gradients
  static const LinearGradient _selectedHashtagGradient = LinearGradient(
    colors: [Color(0xFF9248D2), Color(0xFF25E5D2)], // Purple to cyan
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Services
  late final UserService _userService;

  // Animation controllers
  late AnimationController _scrollController;
  late Animation<double> _fadeAnimation;

  // Firebase listener
  StreamSubscription<DocumentSnapshot>? _profileListener;

  // State management - matching SwiftUI @State variables
  bool _showPlatforms = true;
  bool _showCalendar = true;
  bool _showConnect = true;
  bool _showSocialLinks = true;
  String _selectedHashtag = "";
  Set<String> _bookmarkedEventIds = {};
  double _scrollOffset = 0.0;
  StreamerCard? _loadedStreamer;

  // Data
  List<Map<String, dynamic>> _calendarEvents = [];
  List<Map<String, dynamic>> _platforms = [];
  List<Map<String, dynamic>> _socialLinks = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _userService = UserService();
    
    _scrollController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scrollController,
      curve: Curves.easeInOut,
    ));

    // Initialize with first hashtag selected
    if (widget.streamer.hashtags.isNotEmpty) {
      _selectedHashtag = widget.streamer.hashtags.first;
    }

    // Set up real-time listeners
    _setupProfileListener();
    
    // Load data
    _loadUserData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _cleanupListener();
    super.dispose();
  }

  // Computed properties
  StreamerCard get displayStreamer => _loadedStreamer ?? widget.streamer;
  
  bool get isOwner {
    // TODO: Implement proper ownership check with authentication service
    return false; // For now, return false for testing
  }

  // Real-time data management
  Future<void> _loadUserData() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Load updated streamer data
      // final updatedStreamer = await _userService.loadUserForStreamerCard(widget.streamer.id);
      
      if (mounted) {
        setState(() {
          _loadedStreamer = widget.streamer; // Use the passed streamer for now
        });
      }

      // Load additional data in parallel
      await Future.wait([
        _loadCalendarEvents(),
        _loadPlatforms(),
        _loadSocialLinks(),
      ]);
    } catch (e) {
      print('❌ Failed to load user data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _scrollController.forward();
      }
    }
  }

  // Firebase listener setup
  void _setupProfileListener() {
    _profileListener = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.streamer.id)
        .snapshots()
        .listen(
      (DocumentSnapshot documentSnapshot) {
        if (documentSnapshot.exists) {
          print('📡 Profile update detected, reloading data...');
          _loadUserData(); // Reload data when changes detected
        }
      },
      onError: (error) {
        print('❌ Error listening for profile updates: $error');
      },
    );
  }

  // Cleanup listener
  void _cleanupListener() {
    _profileListener?.cancel();
    _profileListener = null;
  }

  Future<void> _loadCalendarEvents() async {
    try {
      // TODO: Load calendar events from Firebase
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
    try {
      // TODO: Load platforms from Firebase
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

  Future<void> _loadSocialLinks() async {
    try {
      // TODO: Load social links from Firebase
      // This would typically fetch from a social links collection
      if (mounted) {
        setState(() {
          _socialLinks = [];
        });
      }
    } catch (e) {
      print('Error loading social links: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: _mainGradient,
        ),
        child: SafeArea(
        child: Stack(
          children: [
              // Main content with scroll-based header
              SingleChildScrollView(
                child: FadeTransition(
                  opacity: _fadeAnimation,
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
                                const SizedBox(height: 24),
                      
                      // Social links section (expandable)
                      _buildSocialLinksSection(),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
              ),
              
              // Top bar with scroll-based title and flip button
            _buildTopBar(),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
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
              widget.streamer.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onDismiss?.call();
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
            backgroundImage: widget.streamer.avatarURL != null
                ? NetworkImage(widget.streamer.avatarURL!)
                : null,
            child: widget.streamer.avatarURL == null
                ? Text(
                    widget.streamer.displayName.isNotEmpty
                        ? widget.streamer.displayName[0].toUpperCase()
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
                  widget.streamer.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                  '@${widget.streamer.username}',
                  style: const TextStyle(
                    color: Color(0xFFB3FFFFFF), // Pre-computed opacity
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
    if (displayStreamer.hashtags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
        scrollDirection: Axis.horizontal,
          itemCount: displayStreamer.hashtags.length,
        itemBuilder: (context, index) {
            final hashtag = displayStreamer.hashtags[index];
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
                    gradient: isSelected 
                        ? _selectedHashtagGradient
                    : null,
                    color: isSelected 
                        ? null
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
              const _EmptyStateWidget(
                icon: Icons.link,
                message: 'No platforms connected yet',
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
                  style: const TextStyle(
                    color: Color(0xFFB3FFFFFF),
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
              const _EmptyStateWidget(
                icon: Icons.event,
                message: 'No upcoming events',
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
      child: Row(
        children: [
          // Calendar icon
          const Icon(
              Icons.calendar_today,
            color: Colors.white,
              size: 16,
            ),
          const SizedBox(width: 12),
          
          // Event details
          Expanded(
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
                  const SizedBox(height: 2),
                  Text(
                    event['description'],
                    style: const TextStyle(
                      color: Color(0xFFB3FFFFFF),
                      fontSize: 12,
                    ),
                  ),
                ],
                if (event['date'] != null) ...[
                const SizedBox(height: 2),
                Text(
                    _formatDateAndTime(event['date']),
                    style: const TextStyle(
                      color: Color(0xFF80FFFFFF),
                    fontSize: 10,
                  ),
                ),
                ],
              ],
            ),
          ),
          
          // Action buttons based on ownership
          if (isOwner) ...[
            // Owner: Delete button
            IconButton(
              onPressed: () => _deleteEvent(event['id']),
              icon: const Icon(
                Icons.delete,
                color: Colors.red,
                size: 16,
              ),
            ),
          ] else ...[
            // Visitor: Bookmark button
            IconButton(
              onPressed: () => _toggleBookmark(event['id']),
              icon: Icon(
                _bookmarkedEventIds.contains(event['id'])
                    ? Icons.bookmark
                    : Icons.bookmark_border,
              color: Colors.white,
              size: 16,
            ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSocialLinksSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Row(
            children: [
              const Text(
                'Social Links',
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
                    _showSocialLinks = !_showSocialLinks;
                  });
                },
                icon: Icon(
                  _showSocialLinks ? Icons.expand_less : Icons.expand_more,
                color: Colors.white,
                ),
              ),
            ],
          ),
          if (_showSocialLinks) ...[
            const SizedBox(height: 8),
            if (_socialLinks.isEmpty)
              const _EmptyStateWidget(
                icon: Icons.share,
                message: 'No social links added yet',
              )
            else
              ..._socialLinks.map((link) => _buildSocialLinkCard(link)),
          ],
        ],
      ),
    );
  }

  Widget _buildSocialLinkCard(Map<String, dynamic> link) {
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
            _getSocialLinkIcon(link['type']),
              color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(
                  link['title'] ?? 'Social Link',
              style: const TextStyle(
                color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  link['url'] ?? '',
                  style: const TextStyle(
                    color: Color(0xFFB3FFFFFF),
                    fontSize: 12,
                  ),
            ),
          ],
        ),
      ),
          IconButton(
            onPressed: () => _openSocialLink(link['url']),
            icon: const Icon(Icons.open_in_new, color: Colors.white, size: 16),
          ),
        ],
      ),
    );
  }

  // Utility methods
  String _formatDateAndTime(dynamic date) {
    if (date is DateTime) {
      final monthNames = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      
      final month = monthNames[date.month - 1];
    final day = date.day;
      final hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour < 12 ? 'AM' : 'PM';
      
      return '$month $day · $hour:$minute $period';
    }
    return 'TBD';
  }

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

  IconData _getSocialLinkIcon(String type) {
    switch (type.toLowerCase()) {
      case 'website':
        return Icons.language;
      case 'email':
        return Icons.email;
      case 'phone':
        return Icons.phone;
      case 'discord':
        return Icons.chat;
      case 'patreon':
        return Icons.favorite;
      case 'ko-fi':
        return Icons.coffee;
      default:
        return Icons.link;
    }
  }

  void _openPlatform(String? url) {
    HapticFeedback.lightImpact();
    // TODO: Open platform URL using url_launcher
    print('Opening platform: $url');
  }

  void _openSocialLink(String? url) {
    HapticFeedback.lightImpact();
    // TODO: Open social link URL using url_launcher
    print('Opening social link: $url');
  }

  // Event management methods
  void _deleteEvent(String eventId) {
    HapticFeedback.lightImpact();
    // TODO: Delete event from Firebase
    print('Deleting event: $eventId');
    
    setState(() {
      _calendarEvents.removeWhere((event) => event['id'] == eventId);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Event deleted'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _toggleBookmark(String eventId) {
    HapticFeedback.lightImpact();
    
    setState(() {
      if (_bookmarkedEventIds.contains(eventId)) {
        _bookmarkedEventIds.remove(eventId);
        print('Unbookmarked event: $eventId');
      } else {
        _bookmarkedEventIds.add(eventId);
        print('Bookmarked event: $eventId');
      }
    });
    
    // TODO: Save bookmark state to Firebase
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
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Center(
                          child: Column(
                            children: [
            Icon(
              icon,
              size: 40,
              color: const Color(0xFF80FFFFFF),
            ),
            const SizedBox(height: 8),
                                Text(
              message,
              style: const TextStyle(
                color: Color(0xFFB3FFFFFF),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
        ),
      ),
    );
  }
}