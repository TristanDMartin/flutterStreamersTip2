import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/calendar_event.dart';
import '../services/robust_auth_service.dart';
import 'brand_icons.dart';

class ProfileBackView extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onFlip;
  const ProfileBackView({super.key, required this.user, this.onFlip});

  @override
  ConsumerState<ProfileBackView> createState() => _ProfileBackViewState();
}

class _ProfileBackViewState extends ConsumerState<ProfileBackView> {
  bool isBioExpanded = true;
  bool isPlatformsExpanded = true;
  bool isCalendarExpanded = true;
  String? _selectedHashtag;

  @override
  void initState() {
    super.initState();
    // ProfileBackView doesn't need to listen for updates since it displays static user data
    // This prevents infinite loading loops
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Get the current user data from widget
  Map<String, dynamic> get _currentUserData {
    // ProfileBackView displays static user data from the widget
    return widget.user;
  }

  @override
  Widget build(BuildContext context) {
    // ProfileBackView displays the user data passed to it directly
    // No need to fetch from Firestore again
    debugPrint("🔍 ProfileBackView: Building with user data: ${_currentUserData['username']}");
    
    // Extract platforms and events from the user data
    List<CalendarEvent> events = [];
    List<Map<String, dynamic>> platforms = [];
    
    // Load calendar events from user data
    if (_currentUserData['calendarEvents'] != null) {
      final eventsData = _currentUserData['calendarEvents'];
      if (eventsData is List<dynamic>) {
        events = eventsData.map((eventData) {
          final eventMap = eventData as Map<String, dynamic>?;
          if (eventMap != null && 
              eventMap['id'] != null && 
              eventMap['title'] != null && 
              eventMap['description'] != null && 
              eventMap['date'] != null) {
            return CalendarEvent(
              id: eventMap['id'] as String,
              title: eventMap['title'] as String,
              description: eventMap['description'] as String,
              date: (eventMap['date'] as Timestamp).toDate(),
            );
          }
          return null;
        }).where((event) => event != null).cast<CalendarEvent>().toList();
      }
    }
    
    // Load platforms from user data
    if (_currentUserData['platforms'] != null) {
      final platformsData = _currentUserData['platforms'];
      if (platformsData is List<dynamic>) {
        platforms = platformsData.map((platformData) {
          final platformMap = platformData as Map<String, dynamic>?;
          if (platformMap != null) {
            return {
              'id': platformMap['id']?.toString() ?? '',
              'type': platformMap['type']?.toString() ?? '',
              'username': platformMap['username']?.toString() ?? '',
              'followers': (platformMap['followers'] as num?)?.toInt() ?? 0,
              'url': platformMap['url']?.toString(),
            };
          }
          return null;
        }).where((platform) => platform != null).cast<Map<String, dynamic>>().toList();
      }
    }
    
    return _buildContent(events, platforms);
  }

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
        ),
      ),
      child: SafeArea(
        child: const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
                'Please try again later',
                style: TextStyle(
                  color: Colors.white.withValues(alpha:0.7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => setState(() {}),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoDataState() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.person_outline,
                color: Colors.white,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Profile Not Found',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This profile may not exist',
                style: TextStyle(
                  color: Colors.white.withValues(alpha:0.7),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<CalendarEvent> events, List<Map<String, dynamic>> platforms) {
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
              SliverToBoxAdapter(child: _buildHeader()),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(child: _buildIdentity()),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(child: _buildTags()),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(child: _buildSectionHeader('Bio', isBioExpanded, () => setState(() => isBioExpanded = !isBioExpanded))),
              if (isBioExpanded) SliverToBoxAdapter(child: _buildBioBody()),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(child: _buildSectionHeader('Platforms', isPlatformsExpanded, () => setState(() => isPlatformsExpanded = !isPlatformsExpanded))),
              if (isPlatformsExpanded) SliverToBoxAdapter(child: _buildPlatforms(platforms)),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(child: _buildSectionHeader('Calendar', isCalendarExpanded, () => setState(() => isCalendarExpanded = !isCalendarExpanded))),
              if (isCalendarExpanded) SliverToBoxAdapter(child: _buildCalendar(events)),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        ),
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
            onPressed: widget.onFlip,
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
          _SmallAvatar(imageUrl: _currentUserData['avatarURL']),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentUserData['displayName'] ?? 'Techniques',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${_currentUserData['username'] ?? 'techniques'}',
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
    final hashtagsData = _currentUserData['hashtags'];
    List<String> tags = [];
    
    if (hashtagsData != null) {
      if (hashtagsData is List) {
        // If it's already a list, convert it
        tags = List<String>.from(hashtagsData);
      } else if (hashtagsData is String) {
        // If it's a string, split by comma and trim whitespace
        tags = hashtagsData.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList();
      }
    }
    
    if (tags.isEmpty) return const SizedBox.shrink();
    
    // Set first hashtag as selected if none is selected
    if (_selectedHashtag == null && tags.isNotEmpty) {
      _selectedHashtag = tags.first;
    }
    
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final String tag = tags[index];
          final bool isSelected = _selectedHashtag == tag;
          
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _selectedHashtag = tag;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF955CFF), Color(0xFF3D99F7)], // Match Add to Calendar button
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                color: isSelected ? null : Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected 
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.15), 
                  width: 1
                ),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: const Color(0xFF955CFF).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ] : null,
              ),
              alignment: Alignment.center,
              child: Text(
                '#$tag',
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 16, 
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: tags.length,
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool expanded, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Icon(expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right, color: Colors.white.withValues(alpha: 0.9)),
          ],
        ),
      ),
    );
  }

  Widget _buildBioBody() {
    final String bio = (_currentUserData['bio'] ?? '') as String;
    if (bio.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Text(
        bio,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 16, fontWeight: FontWeight.w600),
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
    debugPrint('📅 Building calendar with ${events.length} events');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        children: [
          for (final e in events)
            _CalendarCard(
              title: e.title,
              subtitle: e.description,
              meta: _formatDate(e.date),
              onDelete: () async {
                debugPrint('🗑️ Deleting calendar event: ${e.title}');
                final List<CalendarEvent> updatedEvents = events.where((x) => x.id != e.id).toList();
                
                try {
                  final authService = ref.read(robustAuthServiceProvider);
                  await authService.updateUserCalendarEvents(updatedEvents);
                  debugPrint('✅ Calendar event deleted successfully - StreamBuilder will auto-update');
                } catch (error) {
                  debugPrint('❌ Error deleting calendar event: $error');
                }
              },
            ),
          const SizedBox(height: 16),
          _addToCalendarButton(),
        ],
      ),
    );
  }

  Widget _addToCalendarButton() {
    debugPrint('🔘 Rendering Add to Calendar button');
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: GestureDetector(
        onTap: () {
          debugPrint('➕ Add to Calendar button tapped');
          _showAddEventSheet();
        },
        child: Container(
          height: 60,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF955CFF), Color(0xFF3D99F7)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF955CFF).withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'Add to Calendar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddEventSheet() {
    String title = '';
    String description = '';
    DateTime when = DateTime.now();
    bool isValid = false;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Text(
                          'Add Event',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Title field (required)
                    TextField(
                      onChanged: (v) {
                        title = v;
                        setModalState(() {
                          isValid = title.trim().isNotEmpty;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Title *',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: 'Event title',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    
                    // Description field (optional)
                    TextField(
                      onChanged: (v) => description = v,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: 'Event description (optional)',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    
                    // Date & Time picker
                    Row(
                      children: [
                        const Text(
                          'Date & Time *',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: when,
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              final currentContext = context;
                              final TimeOfDay? tod = await showTimePicker(
                                context: currentContext,
                                initialTime: TimeOfDay.fromDateTime(when),
                              );
                              if (tod != null && currentContext.mounted) {
                                setModalState(() {
                                  when = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    tod.hour,
                                    tod.minute,
                                  );
                                });
                              }
                            }
                          },
                          child: Text(
                            _formatDate(when),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isValid 
                              ? const Color(0xFF3D99F7)
                              : Colors.grey.withValues(alpha: 0.3),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        onPressed: isValid
                            ? () async {
                                final navigator = Navigator.of(context);
                                final scaffoldMessenger = ScaffoldMessenger.of(context);
                                
                                debugPrint('📅 Creating new calendar event...');
                                debugPrint('📅 Title: ${title.trim()}');
                                debugPrint('📅 Description: ${description.trim()}');
                                debugPrint('📅 Date: $when');
                                
                                // Create event object with your exact spec
                                final CalendarEvent ev = CalendarEvent.create(
                                  title: title.trim(),
                                  description: description.trim(),
                                  date: when,
                                );
                                debugPrint('📅 Created event with ID: ${ev.id}');
                                
                                // Get current events and add new one
                                final authService = ref.read(robustAuthServiceProvider);
                                final currentUser = authService.currentUser;
                                if (currentUser != null) {
                                  final List<CalendarEvent> next = [...currentUser.calendarEvents, ev];
                                  debugPrint('📅 Total events after adding: ${next.length}');
                                  
                                  try {
                                    // Persist to backend via AuthenticationService
                                    await authService.updateUserCalendarEvents(next);
                                    debugPrint('📅 Successfully saved to Firestore - StreamBuilder will auto-update');
                                    
                                    // Dismiss sheet
                                    navigator.pop();
                                    
                                    // Show success toast (optional)
                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Event added to your profile'),
                                        backgroundColor: Color(0xFF3D99F7),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  } catch (e) {
                                    debugPrint('❌ Error saving calendar event: $e');
                                    // Show error with retry option
                                    scaffoldMessenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to save event: $e'),
                                        backgroundColor: Colors.red,
                                        action: SnackBarAction(
                                          label: 'Retry',
                                          textColor: Colors.white,
                                          onPressed: () {
                                            // Retry logic could go here
                                          },
                                        ),
                                      ),
                                    );
                                  }
                                }
                              }
                            : null,
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    // Format date as "MMM d" (e.g., "Sep 2")
    final List<String> months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final String dateString = '${months[date.month - 1]} ${date.day}';
    
    // Format time as "h:mm a" (e.g., "5:10 PM")
    final int hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final String minute = date.minute.toString().padLeft(2, '0');
    // cspell:ignore ampm
    final String ampm = date.hour >= 12 ? 'PM' : 'AM';
    final String timeString = '$hour:$minute $ampm';
    
    return '$dateString · $timeString';
  }

  Future<void> _launchPlatformUrl(Map<String, dynamic> platform) async {
    final url = platform['url'];
    final platformType = platform['type'] ?? '';
    
    if (url != null && url.isNotEmpty) {
      try {
        final uri = Uri.parse(url);
        
        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          _showSuccessSnackBar('Opening ${_getPlatformDisplayName(platformType)}...');
        } else {
          _showErrorSnackBar('Cannot open this link');
        }
      } catch (e) {
        _showErrorSnackBar('Error opening link: ${e.toString()}');
      }
    } else {
      _showErrorSnackBar('No link available for this platform');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red[600],
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green[600],
          duration: const Duration(seconds: 2),
        ),
      );
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
      case 'bluesky':
        return 'Bluesky';
      case 'twitter':
        return 'Twitter';
      case 'instagram':
        return 'Instagram';
      // cspell:ignore reddit
      case 'reddit':
        return 'RedNote';
      default:
        return platformType;
    }
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
    final platformType = platform['type'] ?? '';
    final username = platform['username'] ?? '';
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
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
                size: 40,
              ),
              
              const SizedBox(width: 16),
              
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
                  ],
                ),
              ),
              
              Text(
                '@$username',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
              
              const SizedBox(width: 8),
              
              const Icon(
                Icons.chevron_right,
                color: Colors.white,
                size: 16,
              ),
            ],
          ),
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
      case 'bluesky':
        return 'Bluesky';
      case 'twitter':
        return 'Twitter';
      case 'instagram':
        return 'Instagram';
      // cspell:ignore reddit
      case 'reddit':
        return 'RedNote';
      default:
        return platformType;
    }
  }
}



class _CalendarCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String meta;
  final VoidCallback onDelete;
  const _CalendarCard({required this.title, required this.subtitle, required this.meta, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
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
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(meta, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
              ],
            ),
          ),
          IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: Colors.redAccent)),
        ],
      ),
    );
  }
}


