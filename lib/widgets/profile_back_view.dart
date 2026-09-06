import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../models/calendar_event.dart';
import '../core/theme/st_theme_tokens.dart';
import '../features/content_planning/content_planning_api_client.dart';
import '../features/content_planning/calendar_visibility_contract.dart';
import '../services/robust_auth_service.dart';
import '../services/profile_update_service.dart';
import '../services/calendar_cleanup_service.dart';
import '../utils/avatar_url_resolver.dart';
import 'brand_icons.dart';
import 'adult_external_link_dialog.dart';
import '../utils/platform_rules.dart';
import '../utils/user_profile_firestore.dart';
import '../services/public_profile_firestore.dart';
import '../features/creator_score/creator_score_widgets.dart';
import 'profile/profile_username_utils.dart';
import 'streamer_card_sections.dart';

class ProfileBackView extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onFlip;

  /// When true, skip Firestore listeners and keep [user] as the source of truth
  /// (Tippy onboarding review preview before profile is written).
  final bool useInitialDataOnly;

  const ProfileBackView({
    super.key,
    required this.user,
    this.onFlip,
    this.useInitialDataOnly = false,
  });

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
  final ContentPlanningApiClient _contentPlanningApi =
      ContentPlanningApiClient();
  final ProfileUpdateService _profileUpdateService = ProfileUpdateService();

  @override
  void initState() {
    super.initState();
    if (widget.useInitialDataOnly) {
      return;
    }
    _profileUpdateService.addProfileBackViewListener(_onProfileServiceUpdated);
    unawaited(_profileUpdateService.initialize());
    _setupRealtimeListener();
    _runCalendarCleanup();
  }

  /// Run calendar cleanup + projection rebuild on initialization
  void _runCalendarCleanup() {
    final userId = widget.user['id'] as String?;
    if (userId != null && userId.isNotEmpty) {
      // Run cleanup in background (non-blocking)
      CalendarCleanupService()
          .cleanupExpiredEvents(userId)
          .catchError((_) => null);
      // Phase 0: move leftover users.calendarEvents into contentPlans once.
      _contentPlanningApi
          .migrateLegacyCalendarEvents(userId: userId)
          .catchError((_) {});
      // Phase 4: rebuild contentPlan*CalendarEvents from contentItems.
      _contentPlanningApi
          .syncProfileCalendar(userId: userId)
          .catchError((_) {});
    }
  }

  @override
  void didUpdateWidget(covariant ProfileBackView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.useInitialDataOnly) {
      return;
    }
    if (widget.user.containsKey(UserProfileFirestore.linkedPlatformsField) ||
        widget.user.containsKey(UserProfileFirestore.platformsField)) {
      _patchLivePlatformsFromUserData(widget.user);
    }
  }

  @override
  void dispose() {
    _profileUpdateService
        .removeProfileBackViewListener(_onProfileServiceUpdated);
    _userDataSubscription?.cancel();
    super.dispose();
  }

  void _onProfileServiceUpdated() {
    if (!mounted || widget.useInitialDataOnly) {
      return;
    }
    final Map<String, dynamic>? serviceData = _profileUpdateService.userData;
    if (serviceData == null) {
      return;
    }
    final String liveId =
        (_liveUserData?['id'] ?? _liveUserData?['uid'] ?? '').toString();
    final String serviceId =
        (serviceData['id'] ?? serviceData['uid'] ?? '').toString();
    final String widgetId =
        (widget.user['id'] ?? widget.user['uid'] ?? '').toString();
    if (serviceId.isNotEmpty &&
        widgetId.isNotEmpty &&
        serviceId != widgetId &&
        liveId.isNotEmpty &&
        serviceId != liveId) {
      return;
    }
    if (!serviceData.containsKey(UserProfileFirestore.platformsField) &&
        !serviceData.containsKey(UserProfileFirestore.linkedPlatformsField)) {
      return;
    }
    _patchLivePlatformsFromUserData(serviceData);
  }

  void _patchLivePlatformsFromUserData(Map<String, dynamic> userData) {
    if (!mounted) {
      return;
    }
    setState(() {
      final Map<String, dynamic> next = Map<String, dynamic>.from(
        _liveUserData ?? widget.user,
      );
      if (userData.containsKey(UserProfileFirestore.linkedPlatformsField)) {
        next[UserProfileFirestore.linkedPlatformsField] =
            userData[UserProfileFirestore.linkedPlatformsField];
      }
      if (userData.containsKey(UserProfileFirestore.platformsField)) {
        next[UserProfileFirestore.platformsField] =
            userData[UserProfileFirestore.platformsField];
      }
      _liveUserData = next;
    });
  }

  /// Set up real-time listener for user data changes (e.g., from website)
  void _setupRealtimeListener() {
    final userId = widget.user['id'] as String?;
    if (userId == null || userId.isEmpty) {
      return;
    }

    _userDataSubscription = PublicProfileFirestore.instance
        .watchProfile(userId)
        .listen(
      (snapshot) {
        if (snapshot.exists && mounted) {
          final Map<String, dynamic> data =
              snapshot.data() ?? <String, dynamic>{};
          final List<Map<String, dynamic>> platforms =
              UserProfileFirestore.parsePlatformsFromUserData(
            data,
            connectedOnly: true,
          );
          final List<Map<String, dynamic>> visiblePlatforms =
              platforms.isNotEmpty
                  ? platforms
                  : UserProfileFirestore.parsePlatformsFromUserData(data);
          UserProfileFirestore.logPlatformRead(
            uid: userId,
            view: 'ProfileBackView',
            count: visiblePlatforms.length,
          );
          final List<CalendarEvent> projected =
              UserProfileFirestore.parseProfileCalendarProjection(data);
          UserProfileFirestore.logCalendarRead(
            uid: userId,
            source: 'ProfileBackView',
            count: projected.length,
            readPath:
                UserProfileFirestore.profileCalendarProjectionPath(userId),
          );
          setState(() {
            _liveUserData = data;
          });
        }
      },
      onError: (_) {},
    );
  }

  /// Get the current user data (prioritize live data from Firestore)
  Map<String, dynamic> get _currentUserData {
    final Map<String, dynamic> liveOrWidget = _liveUserData ?? widget.user;
    final Map<String, dynamic> merged = UserProfileFirestore.mergeDisplayUserData(
      fresh: liveOrWidget,
      seed: widget.user,
    );
    // If live snapshot is still empty but the in-memory service already has
    // platforms (local-first save), surface them immediately.
    final List<Map<String, dynamic>> mergedPlatforms =
        UserProfileFirestore.parsePlatformsFromUserData(
      merged,
      connectedOnly: true,
    );
    if (mergedPlatforms.isNotEmpty) {
      return merged;
    }
    final Map<String, dynamic>? serviceData = _profileUpdateService.userData;
    final String widgetId =
        (widget.user['id'] ?? widget.user['uid'] ?? '').toString();
    final String serviceId =
        (serviceData?['id'] ?? serviceData?['uid'] ?? _profileUpdateService.currentUser?.uid ?? '')
            .toString();
    if (serviceData != null &&
        serviceId.isNotEmpty &&
        (widgetId.isEmpty || serviceId == widgetId) &&
        (serviceData.containsKey(UserProfileFirestore.platformsField) ||
            serviceData
                .containsKey(UserProfileFirestore.linkedPlatformsField))) {
      return UserProfileFirestore.mergeDisplayUserData(
        fresh: serviceData,
        seed: merged,
      );
    }
    return merged;
  }

  @override
  Widget build(BuildContext context) {
    try {
      // ProfileBackView displays the user data passed to it directly
      // No need to fetch from Firestore again
      // Extract platforms and events from the user data
      final String uid =
          (_currentUserData['id'] ?? _currentUserData['uid'] ?? '').toString();
      final List<Map<String, dynamic>> platforms =
          UserProfileFirestore.parsePlatformsFromUserData(
        _currentUserData,
        connectedOnly: true,
      );
      final List<Map<String, dynamic>> visiblePlatforms = platforms.isNotEmpty
          ? platforms
          : UserProfileFirestore.parsePlatformsFromUserData(
              _currentUserData,
            );
      if (uid.isNotEmpty) {
        UserProfileFirestore.logPlatformRead(
          uid: uid,
          view: 'ProfileBackView',
          count: visiblePlatforms.length,
        );
      }
      final List<CalendarEvent> events =
          filterActiveUpcomingCalendarEvents(
        events: UserProfileFirestore.mergeCalendarEventLists(
          UserProfileFirestore.parseProfileCalendarProjection(_currentUserData),
          UserProfileFirestore.parseCalendarEventsFromUserData(_currentUserData),
        ),
        startsAtOf: (CalendarEvent e) => e.date,
      );
      if (uid.isNotEmpty) {
        UserProfileFirestore.logCalendarRead(
          uid: uid,
          source: 'ProfileBackView',
          count: events.length,
          readPath: UserProfileFirestore.profileCalendarProjectionPath(uid),
        );
      }

      return _buildContent(events, visiblePlatforms);
    } catch (e) {
      return _buildErrorState(e);
    }
  }

  Widget _buildErrorState(Object? error) {
    return ColoredBox(
      color: StreamerCardBackStyle.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.error_outline,
              color: StreamerCardBackStyle.softText,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Error Loading Profile',
              style: TextStyle(
                color: StreamerCardBackStyle.softText,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please try again later',
              style: TextStyle(
                color: StreamerCardBackStyle.muted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => setState(() {}),
              child: const Text(
                'Retry',
                style: TextStyle(color: StreamerCardBackStyle.lavender),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
      List<CalendarEvent> events, List<Map<String, dynamic>> platforms) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(
          color: StreamerCardBackStyle.background,
          child: SizedBox.expand(),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: <Widget>[
                SliverToBoxAdapter(child: _buildHeader()),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                SliverToBoxAdapter(child: _buildIdentity()),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(child: _buildTags()),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(
                  child: _buildExpandableSection(
                    title: 'Bio',
                    expanded: isBioExpanded,
                    onTap: () => setState(() => isBioExpanded = !isBioExpanded),
                    child: _buildBioBody(),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                SliverToBoxAdapter(
                  child: _buildExpandableSection(
                    title: 'Platforms',
                    expanded: isPlatformsExpanded,
                    onTap: () => setState(
                      () => isPlatformsExpanded = !isPlatformsExpanded,
                    ),
                    child: _buildPlatforms(platforms),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                SliverToBoxAdapter(
                  child: _buildExpandableSection(
                    title: 'Calendar',
                    expanded: isCalendarExpanded,
                    onTap: () => setState(
                      () => isCalendarExpanded = !isCalendarExpanded,
                    ),
                    child: _buildCalendar(events),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: widget.onFlip,
            icon: const Icon(
              Icons.flip,
              color: Colors.white,
              size: 22,
            ),
            tooltip: 'Flip',
          ),
          const Expanded(
            child: Text(
              'Profile Details',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: StreamerCardBackStyle.softText,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildIdentity() {
    final String displayName =
        ProfileUsernameUtils.resolveDisplayName(_currentUserData);
    final String atHandle =
        ProfileUsernameUtils.formatAtHandle(_currentUserData);
    final String profileUserId =
        (_currentUserData['id'] ?? _currentUserData['uid'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _SmallAvatar(
            imageUrl: resolveAvatarUrl(_currentUserData),
            userData: _currentUserData,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  displayName.isNotEmpty ? displayName : 'Creator',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                  ),
                ),
                if (atHandle.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    atHandle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: StreamerCardBackStyle.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (profileUserId.isNotEmpty) ...<Widget>[
            const SizedBox(width: 12),
            CreatorScoreBadge(
              userId: profileUserId,
              compact: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTags() {
    final Object? hashtagsData = _currentUserData['hashtags'];
    final List<String> tags = <String>[];
    if (hashtagsData is List) {
      for (final Object? item in hashtagsData) {
        final String tag = item?.toString().trim() ?? '';
        if (tag.isNotEmpty) {
          tags.add(tag);
        }
      }
    } else if (hashtagsData is String && hashtagsData.trim().isNotEmpty) {
      tags.addAll(
        hashtagsData
            .split(RegExp(r'[,\s]+'))
            .map((String tag) => tag.trim())
            .where((String tag) => tag.isNotEmpty),
      );
    }
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }
    if (_selectedHashtag == null && tags.isNotEmpty) {
      _selectedHashtag = tags.first;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: tags.map((String tag) {
          final String cleaned = tag.replaceAll('#', '').trim();
          final bool isSelected = _selectedHashtag == tag;
          final bool isRole = StreamerCardBackStyle.roleHashtagKeys
              .contains(cleaned.toLowerCase());
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _selectedHashtag = tag;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected || isRole
                    ? StreamerCardBackStyle.accent.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected || isRole
                      ? StreamerCardBackStyle.accent.withValues(alpha: 0.28)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                '#$cleaned',
                style: TextStyle(
                  color: isSelected || isRole
                      ? StreamerCardBackStyle.lavender
                      : const Color(0xFFC0C0C8),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool expanded, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: StreamerCardBackStyle.softText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                color: StreamerCardBackStyle.muted,
                size: 20,
              ),
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
    return Column(
      children: <Widget>[
        _buildSectionHeader(title, expanded, onTap),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (Widget child, Animation<double> animation) {
              final Animation<double> fade = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              );
              final Animation<Offset> slide = Tween<Offset>(
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
    );
  }

  Widget _buildBackCard({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: DecoratedBox(
        decoration: StreamerCardBackStyle.cardDecoration,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: child,
        ),
      ),
    );
  }

  Widget _buildBioBody() {
    final String bio = (_currentUserData['bio'] ?? '').toString().trim();
    if (bio.isEmpty) {
      return _buildBackCard(
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'No bio yet.',
            style: TextStyle(
              color: StreamerCardBackStyle.muted,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      );
    }
    return _buildBackCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          bio,
          style: const TextStyle(
            color: StreamerCardBackStyle.softText,
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildPlatforms(List<Map<String, dynamic>> platforms) {
    if (platforms.isEmpty) {
      return _buildBackCard(
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'No platforms added yet.',
            style: TextStyle(
              color: StreamerCardBackStyle.muted,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      );
    }
    return _buildBackCard(
      child: Column(
        children: platforms
            .map(
              (Map<String, dynamic> platform) => _ClickablePlatformRow(
                platform: platform,
                onTap: () => _launchPlatformUrl(platform),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildCalendar(List<CalendarEvent> events) {
    return _buildBackCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: <Widget>[
            for (final CalendarEvent e in events)
              _CalendarCard(
                title: e.title,
                subtitle: e.description,
                meta: _formatDate(e.date),
                onDelete: () async {
                  final List<CalendarEvent> originalEvents =
                      List<CalendarEvent>.from(events);
                  setState(() {
                    events.removeWhere((CalendarEvent x) => x.id == e.id);
                  });
                  final String? uid = (_currentUserData['id'] ??
                          _currentUserData['uid'])
                      ?.toString();
                  if (uid == null || uid.isEmpty) {
                    return;
                  }
                  try {
                    final ({String planId, String itemId})? planRef =
                        UserProfileFirestore.parseContentPlanEventRef(e.id);
                    if (planRef != null) {
                      await _contentPlanningApi.deleteProfileCalendarItem(
                        userId: uid,
                        planId: planRef.planId,
                        itemId: planRef.itemId,
                      );
                    } else {
                      final List<CalendarEvent> legacyOnly =
                          UserProfileFirestore.parseCalendarEventsFromUserData(
                        _currentUserData,
                      )
                              .where((CalendarEvent x) => x.id != e.id)
                              .toList();
                      await ref
                          .read(robustAuthServiceProvider)
                          .updateUserCalendarEvents(legacyOnly);
                    }
                    await ProfileUpdateService().initialize();
                  } catch (error) {
                    if (mounted) {
                      setState(() {
                        events.clear();
                        events.addAll(originalEvents);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to delete event: $error'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                },
              ),
            if (events.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No upcoming events.',
                    style: TextStyle(
                      color: StreamerCardBackStyle.muted,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            _addToCalendarButton(),
          ],
        ),
      ),
    );
  }

  Widget _addToCalendarButton() {
    return GestureDetector(
      onTap: _showAddEventSheet,
      child: Container(
        height: 44,
        width: double.infinity,
        decoration: BoxDecoration(
          color: StreamerCardBackStyle.accent.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: StreamerCardBackStyle.accent.withValues(alpha: 0.35),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.add_circle_outline,
              color: StreamerCardBackStyle.lavender,
              size: 18,
            ),
            SizedBox(width: 8),
            Text(
              'Add to Calendar',
              style: TextStyle(
                color: StreamerCardBackStyle.lavender,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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
                  color: StreamerCardBackStyle.card,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: StreamerCardBackStyle.muted
                              .withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: <Widget>[
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Add Event',
                                style: TextStyle(
                                  color: StreamerCardBackStyle.softText,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Share your next stream, drop, or meetup.',
                                style: TextStyle(
                                  color: StreamerCardBackStyle.muted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: StreamerCardBackStyle.softText,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        children: <Widget>[
                          TextField(
                            onChanged: (String v) {
                              title = v;
                              setModalState(() {
                                isValid = title.trim().isNotEmpty;
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: 'Title *',
                              labelStyle: TextStyle(
                                color: StreamerCardBackStyle.muted,
                              ),
                              hintText: 'Event title',
                              hintStyle: TextStyle(
                                color: StreamerCardBackStyle.muted,
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0x33FFFFFF),
                                ),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: StreamerCardBackStyle.lavender,
                                ),
                              ),
                            ),
                            style: const TextStyle(
                              color: StreamerCardBackStyle.softText,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            onChanged: (String v) => description = v,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              labelStyle: TextStyle(
                                color: StreamerCardBackStyle.muted,
                              ),
                              hintText: 'Event description (optional)',
                              hintStyle: TextStyle(
                                color: StreamerCardBackStyle.muted,
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0x33FFFFFF),
                                ),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: StreamerCardBackStyle.lavender,
                                ),
                              ),
                            ),
                            style: const TextStyle(
                              color: StreamerCardBackStyle.softText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: StreamerCardBackStyle.accent
                                  .withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.calendar_today_rounded,
                              color: StreamerCardBackStyle.lavender,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Date & Time',
                              style: TextStyle(
                                color: StreamerCardBackStyle.muted,
                                fontSize: 13,
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
                              style: const TextStyle(
                                color: StreamerCardBackStyle.lavender,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isValid
                              ? StreamerCardBackStyle.accent
                              : Colors.white.withValues(alpha: 0.08),
                          foregroundColor: isValid
                              ? Colors.white
                              : StreamerCardBackStyle.muted,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: isValid
                            ? () async {
                                final NavigatorState navigator =
                                    Navigator.of(context);
                                final ScaffoldMessengerState
                                    scaffoldMessenger =
                                    ScaffoldMessenger.of(context);
                                final CalendarEvent ev = CalendarEvent.create(
                                  title: title.trim(),
                                  description: description.trim(),
                                  date: when,
                                );
                                final String? uid = (_currentUserData['id'] ??
                                        _currentUserData['uid'])
                                    ?.toString();
                                if (uid != null && uid.isNotEmpty) {
                                  UserProfileFirestore.logCalendarSave(
                                    uid: uid,
                                    source: 'ProfileBackView',
                                    count: 1,
                                  );
                                  navigator.pop();
                                  scaffoldMessenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Event added to your profile',
                                      ),
                                      backgroundColor:
                                          StreamerCardBackStyle.accent,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  _contentPlanningApi
                                      .createProfileCalendarItem(
                                    userId: uid,
                                    title: ev.title,
                                    description: ev.description,
                                    date: ev.date,
                                  )
                                      .then((_) async {
                                    await ProfileUpdateService().initialize();
                                  }).catchError((Object e) {
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
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
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
    final String platformType =
        PlatformRules.normalizePlatformType(platform['type']?.toString() ?? '');
    if (PlatformRules.isAgeRestrictedEntry(platform)) {
      final bool confirmed = await showAdultExternalLinkDialog(context);
      if (!confirmed || !mounted) {
        return;
      }
    }
    final url = platform['url'];
    final username = platform['username'] ?? '';
    final String? resolvedUrl = (() {
      final String raw = (url?.toString() ?? '').trim();
      if (raw.isNotEmpty) {
        return raw;
      }
      final String handle = username.toString().trim();
      if (handle.isEmpty) {
        return null;
      }
      return PlatformRules.previewPlatformUrl(platformType, handle) ??
          _constructPlatformUrl(platformType, handle);
    })();

    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
      try {
        // Add timeout to prevent hanging
        await Future.any([
          _launchUrlWithTimeout(resolvedUrl),
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
          backgroundColor: Theme.of(context).colorScheme.error,
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
          backgroundColor: StThemeColors.successGreen,
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
      case 'x':
        return 'https://x.com/$cleanUsername';
      case 'instagram':
        return 'https://instagram.com/$cleanUsername';
      case 'reddit':
        return 'https://reddit.com/user/$cleanUsername';
      case 'discord':
        return 'https://discord.com';
      case 'patreon':
        return 'https://patreon.com/$cleanUsername';
      case 'onlyfans':
        return 'https://onlyfans.com/$cleanUsername';
      default:
        return null;
    }
  }

  String _getPlatformDisplayName(String platformType) {
    return PlatformRules.displayNameForType(platformType);
  }
}

class _SmallAvatar extends StatelessWidget {
  final String? imageUrl;
  final Map<String, dynamic> userData;
  const _SmallAvatar({
    required this.imageUrl,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    final String letter =
        ProfileUsernameUtils.resolveAvatarInitialLetter(userData);
    return Container(
      width: 56,
      height: 56,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            StreamerCardBackStyle.ringBlue,
            StreamerCardBackStyle.ringPurple,
          ],
        ),
      ),
      child: ClipOval(
        child: ColoredBox(
          color: StreamerCardBackStyle.avatarFill,
          child: imageUrl != null && imageUrl!.isNotEmpty
              ? Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                      Center(
                    child: Text(
                      letter,
                      style: const TextStyle(
                        color: StreamerCardBackStyle.softText,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    letter,
                    style: const TextStyle(
                      color: StreamerCardBackStyle.softText,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
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
    final String platformType = PlatformRules.normalizePlatformType(
      platform['type'] as String? ?? '',
    );
    final String username = platform['username'] as String? ?? '';
    final bool isAgeRestricted = PlatformRules.isAgeRestrictedEntry(platform);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: <Widget>[
            BrandIcon(
              platformType: platformType,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _getPlatformDisplayName(platformType),
                    style: const TextStyle(
                      color: StreamerCardBackStyle.softText,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    isAgeRestricted
                        ? '18+ external link'
                        : (username.isNotEmpty
                            ? (username.startsWith('@')
                                ? username
                                : '@$username')
                            : 'Open link'),
                    style: const TextStyle(
                      color: StreamerCardBackStyle.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isAgeRestricted ? Icons.lock_outline : Icons.arrow_forward_ios,
              color: StreamerCardBackStyle.muted,
              size: isAgeRestricted ? 14 : 12,
            ),
          ],
        ),
      ),
    );
  }

  String _getPlatformDisplayName(String platformType) {
    return PlatformRules.displayNameForType(platformType);
  }
}

class _CalendarCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String meta;
  final VoidCallback onDelete;
  const _CalendarCard({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.event_outlined,
            color: StreamerCardBackStyle.lavender,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: StreamerCardBackStyle.softText,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: StreamerCardBackStyle.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: const TextStyle(
                    color: StreamerCardBackStyle.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.85),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}
