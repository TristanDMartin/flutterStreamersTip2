import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../models/calendar_event.dart';
import '../constants/app_colors.dart';
import '../services/robust_auth_service.dart';
import '../services/profile_update_service.dart';
import '../services/calendar_cleanup_service.dart';
import '../utils/avatar_url_resolver.dart';
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
  StreamSubscription<DocumentSnapshot>? _userDataSubscription;
  Map<String, dynamic>? _liveUserData;

  @override
  void initState() {
    super.initState();
    _setupRealtimeListener();
    _runCalendarCleanup();
  }

  /// Run calendar cleanup on initialization
  void _runCalendarCleanup() {
    final userId = widget.user['id'] as String?;
    if (userId != null && userId.isNotEmpty) {
      // Run cleanup in background (non-blocking)
      CalendarCleanupService()
          .cleanupExpiredEvents(userId)
          .catchError((_) => null);
    }
  }

  @override
  void dispose() {
    _userDataSubscription?.cancel();
    super.dispose();
  }

  /// Set up real-time listener for user data changes (e.g., from website)
  void _setupRealtimeListener() {
    final userId = widget.user['id'] as String?;
    if (userId == null || userId.isEmpty) {
      return;
    }

    _userDataSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.exists && mounted) {
          setState(() {
            _liveUserData = snapshot.data();
          });
        }
      },
      onError: (_) {},
    );
  }

  /// Get the current user data (prioritize live data from Firestore)
  Map<String, dynamic> get _currentUserData {
    // Use live data if available (from Firestore listener), otherwise use widget data
    return _liveUserData ?? widget.user;
  }
  Color get _onSurface => Theme.of(context).colorScheme.onSurface;
  Color get _onPrimary => Theme.of(context).colorScheme.onPrimary;

  /// Safely parse date from various formats
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
        return DateTime.now();
      }
    }

    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    try {
      // ProfileBackView displays the user data passed to it directly
      // No need to fetch from Firestore again
      // Extract platforms and events from the user data
      List<CalendarEvent> events = [];
      List<Map<String, dynamic>> platforms = [];

      // Load calendar events from user data
      if (_currentUserData['calendarEvents'] != null) {
        final eventsData = _currentUserData['calendarEvents'];
        if (eventsData is List<dynamic>) {
          events = eventsData
              .map((eventData) {
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
                    date: _parseDate(eventMap['date']),
                  );
                }
                return null;
              })
              .where((event) => event != null)
              .cast<CalendarEvent>()
              .toList();
        }
      }

      // Load platforms from user data
      if (_currentUserData['platforms'] != null) {
        final platformsData = _currentUserData['platforms'];
        if (platformsData is List<dynamic>) {
          platforms = platformsData
              .map((platformData) {
                final platformMap = platformData as Map<String, dynamic>?;
                if (platformMap != null) {
                  return {
                    'id': platformMap['id']?.toString() ?? '',
                    'type': platformMap['type']?.toString() ?? '',
                    'username': platformMap['username']?.toString() ?? '',
                    'followers':
                        (platformMap['followers'] as num?)?.toInt() ?? 0,
                    'url': platformMap['url']?.toString(),
                  };
                }
                return null;
              })
              .where((platform) => platform != null)
              .cast<Map<String, dynamic>>()
              .toList();
        }
      }

      return _buildContent(events, platforms);
    } catch (e) {
      return _buildErrorState(e);
    }
  }

  Widget _buildErrorState(Object? error) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Theme.of(context).colorScheme.surface,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: _onSurface,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Error Loading Profile',
                style: TextStyle(
                  color: _onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please try again later',
                style: TextStyle(
                  color: _onSurface.withValues(alpha: 0.7),
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

  Widget _buildContent(
      List<CalendarEvent> events, List<Map<String, dynamic>> platforms) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
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
              SliverToBoxAdapter(
                child: _buildExpandableSection(
                  title: 'Bio',
                  expanded: isBioExpanded,
                  onTap: () => setState(() => isBioExpanded = !isBioExpanded),
                  child: _buildBioBody(),
                ),
              ),
              SliverToBoxAdapter(
                child: _buildExpandableSection(
                  title: 'Platforms',
                  expanded: isPlatformsExpanded,
                  onTap: () =>
                      setState(() => isPlatformsExpanded = !isPlatformsExpanded),
                  child: _buildPlatforms(platforms),
                ),
              ),
              SliverToBoxAdapter(
                child: _buildExpandableSection(
                  title: 'Calendar',
                  expanded: isCalendarExpanded,
                  onTap: () =>
                      setState(() => isCalendarExpanded = !isCalendarExpanded),
                  child: _buildCalendar(events),
                ),
              ),
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _onSurface.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _onSurface.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              'Profile Details',
              style: TextStyle(
                color: _onSurface.withValues(alpha: 0.92),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: widget.onFlip,
              icon: Icon(
                Icons.flip,
                color: _onSurface,
                size: 22,
              ),
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
          _SmallAvatar(imageUrl: resolveAvatarUrl(_currentUserData)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentUserData['displayName'] ?? 'Techniques',
                  style: TextStyle(
                    color: _onSurface,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${_currentUserData['username'] ?? 'techniques'}',
                  style: TextStyle(
                    color: _onSurface.withValues(alpha: 0.75),
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
        tags = hashtagsData
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList();
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
                        colors: AppColors.supportAccentGradient,
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                color: isSelected ? null : _onSurface.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSelected
                        ? _onSurface.withValues(alpha: 0.3)
                        : _onSurface.withValues(alpha: 0.15),
                    width: 1),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color:
                              AppColors.supportAccent.withValues(alpha: 0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                '#$tag',
                style: TextStyle(
                  color: isSelected ? _onPrimary : _onSurface,
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
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _onSurface.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _onSurface.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                color: _onSurface.withValues(alpha: 0.9)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required bool expanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          _buildSectionHeader(title, expanded, onTap),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final fade = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                );
                final slide = Tween<Offset>(
                  begin: const Offset(0, -0.03),
                  end: Offset.zero,
                ).animate(fade);
                return FadeTransition(
                  opacity: fade,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: expanded
                  ? KeyedSubtree(
                      key: ValueKey<String>('section-$title-open'),
                      child: child,
                    )
                  : const SizedBox(
                      key: ValueKey<String>('section-collapsed'),
                    ),
            ),
          ),
        ],
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
        style: TextStyle(
            color: _onSurface.withValues(alpha: 0.75),
            fontSize: 16,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildPlatforms(List<Map<String, dynamic>> platforms) {
    if (platforms.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _onSurface.withValues(alpha: 0.10),
              width: 1,
            ),
          ),
          child: Text(
            'No platforms added yet.',
            style: TextStyle(
              color: _onSurface.withValues(alpha: 0.68),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        children: [
          for (final e in events)
            _CalendarCard(
              title: e.title,
              subtitle: e.description,
              meta: _formatDate(e.date),
              onDelete: () async {
                // Save reference for potential rollback
                final originalEvents = List<CalendarEvent>.from(events);

                // Optimistic UI update - INSTANT deletion from UI
                setState(() {
                  events.removeWhere((x) => x.id == e.id);
                });

                // Save to Firestore and WAIT for completion
                final authService = ref.read(robustAuthServiceProvider);
                authService.updateUserCalendarEvents(events).then((_) async {
                  // NOW refresh ProfileUpdateService after save completes
                  // This ensures we get the updated data, not stale data
                  await ProfileUpdateService().initialize();
                }).catchError((error) {
                  // Revert optimistic update on error
                  if (mounted) {
                    setState(() {
                      events.clear();
                      events.addAll(originalEvents);
                    });

                    // Show error feedback
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete event: $error'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                });
              },
            ),
          const SizedBox(height: 16),
          _addToCalendarButton(),
        ],
      ),
    );
  }

  Widget _addToCalendarButton() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: GestureDetector(
        onTap: () {
          _showAddEventSheet();
        },
        child: Container(
          height: 60,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.supportAccentGradient,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.supportAccent.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: _onSurface.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle,
                color: _onPrimary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Add to Calendar',
                style: TextStyle(
                  color: _onPrimary,
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
                  color:
                      Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(
                    color: _onSurface.withValues(alpha: 0.14),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .shadow
                          .withValues(alpha: 0.35),
                      blurRadius: 28,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _onSurface.withValues(alpha: 0.24),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add Event',
                              style: TextStyle(
                                color: _onSurface,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Share your next stream, drop, or meetup.',
                              style: TextStyle(
                                color: _onSurface.withValues(alpha: 0.65),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _onSurface.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _onSurface.withValues(alpha: 0.12),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.close,
                              color: _onSurface,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: _onSurface.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: _onSurface.withValues(alpha: 0.10),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            onChanged: (v) {
                              title = v;
                              setModalState(() {
                                isValid = title.trim().isNotEmpty;
                              });
                            },
                            decoration: InputDecoration(
                              labelText: 'Title *',
                              labelStyle: TextStyle(
                                color: _onSurface.withValues(alpha: 0.7),
                              ),
                              hintText: 'Event title',
                              hintStyle: TextStyle(
                                  color:
                                      _onSurface.withValues(alpha: 0.45)),
                              enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                color: _onSurface.withValues(alpha: 0.24),
                              ),),
                              focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                color: _onSurface.withValues(alpha: 0.7),
                              ),),
                            ),
                            style: TextStyle(color: _onSurface),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            onChanged: (v) => description = v,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Description',
                              labelStyle: TextStyle(
                                color: _onSurface.withValues(alpha: 0.7),
                              ),
                              hintText: 'Event description (optional)',
                              hintStyle: TextStyle(
                                  color:
                                      _onSurface.withValues(alpha: 0.45)),
                              enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                color: _onSurface.withValues(alpha: 0.24),
                              ),),
                              focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                color: _onSurface.withValues(alpha: 0.7),
                              ),),
                            ),
                            style: TextStyle(color: _onSurface),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: _onSurface.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _onSurface.withValues(alpha: 0.10),
                          width: 1,
                        ),
                      ),
                      child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: AppColors.supportAccentGradient,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.calendar_today_rounded,
                            color: _onPrimary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Date & Time',
                            style: TextStyle(
                              color: _onSurface.withValues(alpha: 0.7),
                              fontSize: 15,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: when,
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              if (!context.mounted) {
                                return;
                              }
                              final TimeOfDay? tod = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(when),
                              );
                              if (tod != null && context.mounted) {
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
                            style: TextStyle(
                              color: _onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    ),
                    const SizedBox(height: 22),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isValid
                              ? AppColors.supportAccent
                              : Colors.grey.withValues(alpha: 0.3),
                          foregroundColor:
                              isValid ? _onPrimary : _onSurface,
                          elevation: isValid ? 6 : 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        onPressed: isValid
                            ? () async {
                                final navigator = Navigator.of(context);
                                final scaffoldMessenger =
                                    ScaffoldMessenger.of(context);

                                // Create event object with your exact spec
                                final CalendarEvent ev = CalendarEvent.create(
                                  title: title.trim(),
                                  description: description.trim(),
                                  date: when,
                                );

                                // Get current events and add new one
                                final authService =
                                    ref.read(robustAuthServiceProvider);
                                final currentUser = authService.currentUser;
                                if (currentUser != null) {
                                  final List<CalendarEvent> next = [
                                    ...currentUser.calendarEvents,
                                    ev
                                  ];

                                  // Dismiss sheet immediately for instant feel
                                  navigator.pop();

                                  // Show optimistic success message
                                  scaffoldMessenger.showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Event added to your profile'),
                                      backgroundColor:
                                          AppColors.supportAccent,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );

                                  // Save to Firestore and WAIT for completion
                                  authService
                                      .updateUserCalendarEvents(next)
                                      .then((_) async {
                                    // NOW refresh ProfileUpdateService after save completes
                                    await ProfileUpdateService().initialize();
                                  }).catchError((e) {
                                    // Show error feedback
                                    scaffoldMessenger.showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('Failed to save event: $e'),
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  });
                                }
                              }
                            : null,
                        child: const Text(
                          'Save Event',
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
    final List<String> months = [
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
    final username = platform['username'] ?? '';

    if (url != null && url.isNotEmpty) {
      try {
        // Add timeout to prevent hanging
        await Future.any([
          _launchUrlWithTimeout(url),
          Future.delayed(const Duration(seconds: 10), () {
            throw TimeoutException(
                'URL launch timed out', const Duration(seconds: 10));
          }),
        ]);

        _showSuccessSnackBar(
            'Opening ${_getPlatformDisplayName(platformType)}...');
      } catch (e) {
        _showErrorSnackBar('Cannot open this link');
      }
    } else if (username.isNotEmpty) {
      // Fallback logic with timeout
      try {
        final constructedUrl = _constructPlatformUrl(platformType, username);
        if (constructedUrl != null) {
          await Future.any([
            _launchUrlWithTimeout(constructedUrl),
            Future.delayed(const Duration(seconds: 10), () {
              throw TimeoutException(
                  'URL launch timed out', const Duration(seconds: 10));
            }),
          ]);
          _showSuccessSnackBar(
              'Opening ${_getPlatformDisplayName(platformType)}...');
        } else {
          _showErrorSnackBar('No link available for this platform');
        }
      } catch (e) {
        _showErrorSnackBar('Cannot open this link');
      }
    } else {
      _showErrorSnackBar('No link available for this platform');
    }
  }

  Future<void> _launchUrlWithTimeout(String url) async {
    String finalUrl = url;
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }

    final uri = Uri.parse(finalUrl);

    // Try different launch modes
    bool canLaunch = await canLaunchUrl(uri);

    if (canLaunch) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
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

  String? _constructPlatformUrl(String platformType, String username) {
    final cleanUsername = username.replaceAll('@', '');

    switch (platformType.toLowerCase()) {
      case 'twitch':
        return 'https://twitch.tv/$cleanUsername';
      case 'youtube':
        return 'https://youtube.com/@$cleanUsername';
      case 'kick':
        return 'https://kick.com/$cleanUsername';
      case 'tiktok':
        return 'https://tiktok.com/@$cleanUsername';
      case 'facebook':
        return 'https://facebook.com/$cleanUsername';
      case 'bluesky':
        return 'https://bsky.app/profile/$cleanUsername';
      case 'twitter':
        return 'https://twitter.com/$cleanUsername';
      case 'instagram':
        return 'https://instagram.com/$cleanUsername';
      case 'reddit':
        return 'https://reddit.com/user/$cleanUsername';
      case 'discord':
        // Discord doesn't have direct profile URLs, but we can open the Discord app or website
        return 'https://discord.com';
      default:
        return null;
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
      case 'discord':
        return 'Discord';
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
    final Color onSurface = Theme.of(context).colorScheme.onSurface;
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
            color: onSurface.withValues(alpha: 0.2),
          ),
          child: ClipOval(
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? Image.network(imageUrl!, fit: BoxFit.cover)
                : Icon(
                    Icons.person,
                    color: onSurface,
                    size: 28,
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
    final Color onSurface = Theme.of(context).colorScheme.onSurface;
    final platformType = platform['type'] as String? ?? '';
    final username = platform['username'] as String? ?? '';
    return GestureDetector(
      onTap: () {
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: onSurface.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: onSurface.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: onSurface.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: BrandIcon(
                  platformType: platformType,
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
                    _getPlatformDisplayName(platformType),
                    style: TextStyle(
                      color: onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (username.isNotEmpty)
                    Text(
                      '@$username',
                      style: TextStyle(
                        color: onSurface.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: onSurface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                color: onSurface.withValues(alpha: 0.7),
                size: 14,
              ),
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
      case 'bluesky':
        return 'Bluesky';
      case 'reddit':
        return 'Reddit';
      case 'discord':
        return 'Discord';
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
  const _CalendarCard(
      {required this.title,
      required this.subtitle,
      required this.meta,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final Color onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: onSurface.withValues(alpha: 0.12), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            color: onSurface,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: onSurface.withValues(alpha: 0.65),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  meta,
                  style: TextStyle(
                    color: onSurface.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent)),
        ],
      ),
    );
  }
}
