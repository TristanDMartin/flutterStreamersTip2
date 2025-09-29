import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/streamer_card.dart';
import '../models/calendar_event.dart';
import '../services/bookmark_service.dart';
import 'brand_icons.dart';

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
  
  // Hashtag chip gradients - matching Add to Calendar button
  static const LinearGradient _selectedHashtagGradient = LinearGradient(
    colors: [Color(0xFF955CFF), Color(0xFF3D99F7)], // Match Add to Calendar button
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Services
  late final BookmarkService _bookmarkService;


  // Firebase listener
  StreamSubscription<DocumentSnapshot>? _profileListener;

  // State management - matching SwiftUI @State variables
  bool _showBio = true;
  bool _showPlatforms = true;
  bool _showCalendar = true;
  String _selectedHashtag = "";
  Set<String> _bookmarkedEventIds = {};
  StreamerCard? _loadedStreamer;

  // Data
  List<CalendarEvent> _calendarEvents = [];
  List<Map<String, dynamic>> _platforms = [];
  bool _isLoading = false;


  @override
  void initState() {
    super.initState();
    _bookmarkService = BookmarkService();
    

    // Initialize with first hashtag selected
    if (widget.streamer.hashtags.isNotEmpty) {
      _selectedHashtag = widget.streamer.hashtags.first;
    }

    // Initialize bookmark service and load bookmarks
    _initializeBookmarks();

    // Set up real-time listeners
    _setupProfileListener();
    
    // Load data
    _loadUserData();
  }

  @override
  void dispose() {
    _cleanupListener();
    super.dispose();
  }

  // Computed properties
  StreamerCard get displayStreamer => _loadedStreamer ?? widget.streamer;
  
  bool get isOwner {
    // For StreamerBackView, visitors should never be able to delete events
    // Only the actual streamer can delete their own events
    // Since this is a "back view" for visitors, always return false
    return false;
  }

  // Real-time data management
  Future<void> _loadUserData() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Load updated streamer data from Firebase
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
    // print('❌ Failed to load user data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
    // print('📡 Profile update detected, reloading data...');
          _loadUserData(); // Reload data when changes detected
        }
      },
      onError: (error) {
    // print('❌ Error listening for profile updates: $error');
      },
    );
  }

  // Cleanup listener
  void _cleanupListener() {
    _profileListener?.cancel();
    _profileListener = null;
  }

  /// Initialize bookmark service and load bookmarks for this streamer
  Future<void> _initializeBookmarks() async {
    await _bookmarkService.initialize();
    await _fetchBookmarkedEventIds();
  }

  /// Fetch bookmarked event IDs for this streamer
  Future<void> _fetchBookmarkedEventIds() async {
    try {
      final bookmarkedEvents = _bookmarkService.getBookmarkedEventsForOwner(widget.streamer.id);
      final eventIds = bookmarkedEvents.map((e) => e.eventId).toSet();
      
      if (mounted) {
        setState(() {
          _bookmarkedEventIds = eventIds;
        });
      }
    } catch (e) {
      if (kDebugMode) {
    // print('❌ Error fetching bookmarked event IDs: $e');
      }
    }
  }

  Future<void> _loadCalendarEvents() async {
    try {
      // Load calendar events from Firebase
      // For now, create sample events to demonstrate the bookmark functionality
      if (mounted) {
        setState(() {
          _calendarEvents = [
            CalendarEvent(
              title: 'Gaming Stream',
              description: 'Playing the latest games with viewers',
              date: DateTime.now().add(const Duration(days: 1)),
            ),
            CalendarEvent(
              title: 'Q&A Session',
              description: 'Answering questions from the community',
              date: DateTime.now().add(const Duration(days: 3)),
            ),
            CalendarEvent(
              title: 'Tutorial Stream',
              description: 'Learn new techniques and strategies',
              date: DateTime.now().add(const Duration(days: 5)),
            ),
            CalendarEvent(
              title: 'Community Event',
              description: 'Special community celebration',
              date: DateTime.now().add(const Duration(days: 7)),
            ),
            CalendarEvent(
              title: 'Collaboration Stream',
              description: 'Streaming with other creators',
              date: DateTime.now().add(const Duration(days: 10)),
            ),
            CalendarEvent(
              title: 'Charity Stream',
              description: 'Raising money for a good cause',
              date: DateTime.now().add(const Duration(days: 14)),
            ),
          ];
        });
      }
    } catch (e) {
      if (kDebugMode) {
    // print('❌ Error loading calendar events: $e');
      }
    }
  }

  Future<void> _loadPlatforms() async {
    try {
      // Load platforms from Firebase
      // This would typically fetch from a platforms collection
      if (mounted) {
        setState(() {
          _platforms = [];
        });
      }
    } catch (e) {
    // print('Error loading platforms: $e');
    }
  }

  Future<void> _loadSocialLinks() async {
    try {
      // Load social links from Firebase
      // This would typically fetch from a social links collection
      if (mounted) {
        setState(() {
          // Social links loading completed
        });
      }
    } catch (e) {
    // print('Error loading social links: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
        body: Stack(
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
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                widget.onDismiss?.call();
              },
              icon: const Icon(Icons.close, color: Colors.white, size: 24),
              tooltip: 'Close',
            ),
            IconButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                _handleFlip();
              },
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
          _SmallAvatar(imageUrl: widget.streamer.avatarURL),
          const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  widget.streamer.displayName,
                style: const TextStyle(
                  color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                ),
              ),
                const SizedBox(height: 4),
              Text(
                  '@${widget.streamer.username}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                fontSize: 18,
                    fontWeight: FontWeight.w600,
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
    final hashtags = widget.streamer.hashtags;
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
                hashtag,
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

  Widget _buildBioBody() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        widget.streamer.bio,
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

  Future<void> _launchPlatformUrl(Map<String, dynamic> platform) async {
    final url = platform['url'] as String?;
    if (url != null && url.isNotEmpty) {
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      } catch (e) {
        if (kDebugMode) {
    // print('Error launching URL: $e');
        }
      }
    }
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

  /// Build calendar row matching SwiftUI CalendarRow implementation
  Widget _buildCalendarRow(CalendarEvent event) {
    final isBookmarked = _bookmarkedEventIds.contains(event.id);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Calendar icon - matching SwiftUI implementation
          const Icon(
            Icons.calendar_today_outlined,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(width: 12),
          
          // Event details - matching SwiftUI VStack layout
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title - matching SwiftUI subheadline semibold
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
                  _formatDateAndTime(event.date),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // Action buttons based on ownership - matching SwiftUI logic
          if (isOwner) ...[
            // Owner: Delete button (trash icon)
            IconButton(
              onPressed: () => _deleteEvent(event.id),
              icon: const Icon(
                Icons.delete,
                color: Colors.red,
                size: 16,
              ),
            ),
          ] else ...[
            // Visitor: Bookmark button - matching SwiftUI bookmark logic
            IconButton(
              onPressed: () => _toggleBookmark(event),
              icon: Icon(
                isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: Colors.white,
              size: 16,
            ),
            ),
          ],
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


  // IconData _getPlatformIcon(String type) {
  //   switch (type.toLowerCase()) {
  //     case 'youtube':
  //       return Icons.play_circle_filled;
  //     case 'twitch':
  //       return Icons.live_tv;
  //     case 'instagram':
  //       return Icons.camera_alt;
  //     case 'tiktok':
  //       return Icons.music_note;
  //     case 'facebook':
  //       return Icons.facebook;
  //     case 'twitter':
  //       return Icons.alternate_email;
  //     case 'bluesky':
  //       return Icons.cloud;
  //     case 'kick':
  //       return Icons.sports_esports;
  //     case 'reddit':
  //       return Icons.note;
  //     default:
  //       return Icons.link;
  //   }
  // }

  // IconData _getSocialLinkIcon(String type) {
  //   switch (type.toLowerCase()) {
  //     case 'website':
  //       return Icons.language;
  //     case 'email':
  //       return Icons.email;
  //     case 'phone':
  //       return Icons.phone;
  //     case 'discord':
  //       return Icons.chat;
  //     case 'patreon':
  //       return Icons.favorite;
  //     case 'ko-fi':
  //       return Icons.coffee;
  //     default:
  //       return Icons.link;
  //   }
  // }


  // Flip functionality
  void _handleFlip() {
    HapticFeedback.lightImpact();
    // This would typically flip to the front view of the streamer card
    // For now, show a message indicating the functionality
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Flip functionality - would show front view'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Event management methods
  Future<void> _deleteEvent(String eventId) async {
    HapticFeedback.lightImpact();
    
    try {
      // TODO: Implement Firebase deletion when service is available
      // await _calendarService.deleteEvent(eventId);
      
      if (mounted) {
        setState(() {
          _calendarEvents.removeWhere((event) => event.id == eventId);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event deleted'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting event: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete event'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Toggle bookmark for a calendar event - matching SwiftUI implementation
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
          ownerId: widget.streamer.id,
        );
        message = success ? 'Event removed from bookmarks!' : 'Failed to remove bookmark';
      } else {
        // Add bookmark
        success = await _bookmarkService.addEventBookmark(
          event: event,
          ownerId: widget.streamer.id,
          ownerDisplayName: widget.streamer.displayName,
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
    // print('❌ Error toggling bookmark: $e');
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
                      color: Colors.white.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
          color: Colors.white.withValues(alpha:0.2),
          width: 1,
        ),
      ),
      child: Center(
                          child: Column(
                            children: [
            Icon(
              icon,
              size: 40,
              color: const Color(0x80FFFFFF),
            ),
            const SizedBox(height: 8),
                                Text(
              message,
              style: const TextStyle(
                color: Color(0xB3FFFFFF),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
        ),
      ),
    );
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
