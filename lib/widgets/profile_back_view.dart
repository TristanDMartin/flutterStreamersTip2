import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../models/calendar_event.dart';
import '../core/theme/support_shell_style.dart';
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
import '../constants/app_colors.dart';
import '../features/creator_score/creator_score_widgets.dart';
import 'profile/profile_username_utils.dart';

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
          UserProfileFirestore.logPlatformRead(
            uid: userId,
            view: 'ProfileBackView',
            count: platforms.length,
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

  ColorScheme get _scheme => Theme.of(context).colorScheme;
  Color get _onSurface => _scheme.onSurface;
  Color get _onPrimary => _scheme.onPrimary;
  StSupportShellStyle get _shell => StSupportShellStyle.of(context);
  List<Color> get _accentGradientColors =>
      <Color>[_scheme.primary, _scheme.secondary];

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
      if (uid.isNotEmpty) {
        UserProfileFirestore.logPlatformRead(
          uid: uid,
          view: 'ProfileBackView',
          count: platforms.length,
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

      return _buildContent(events, platforms);
    } catch (e) {
      return _buildErrorState(e);
    }
  }

  Widget _buildErrorState(Object? error) {
    final StSupportShellStyle shell = _shell;
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.profileViewBackground,
          ),
          child: SizedBox.expand(),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: shell.onChrome,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error Loading Profile',
                  style: TextStyle(
                    color: shell.onChrome,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try again later',
                  style: TextStyle(
                    color: shell.muted,
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
      ],
    );
  }

  Widget _buildContent(
      List<CalendarEvent> events, List<Map<String, dynamic>> platforms) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.profileViewBackground,
          ),
          child: SizedBox.expand(),
        ),
        Scaffold(
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
                    onTap: () => setState(
                      () => isPlatformsExpanded = !isPlatformsExpanded,
                    ),
                    child: _buildPlatforms(platforms),
                  ),
                ),
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
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
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
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _SmallAvatar(imageUrl: resolveAvatarUrl(_currentUserData)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    displayName.isNotEmpty ? displayName : 'Creator',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                  ),
                ),
                if (atHandle.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    atHandle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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
        itemBuilder: (BuildContext context, int index) {
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
                        colors: <Color>[
                          AppColors.primary,
                          Color(0xFF7768DF),
                          Color(0xFF4897D2),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                color: isSelected
                    ? null
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.10),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '#$tag',
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.68),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: 12),
        itemCount: tags.length,
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool expanded, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                color: Colors.white.withValues(alpha: 0.55),
                size: 24,
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
          color: Colors.white.withValues(alpha: 0.72),
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildPlatforms(List<Map<String, dynamic>> platforms) {
    if (platforms.isEmpty) {
      final StSupportShellStyle shell = _shell;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: shell.surfaceCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: shell.surfaceCardBorder,
              width: 1,
            ),
          ),
          child: Text(
            'No platforms added yet.',
            style: TextStyle(
              color: shell.muted,
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
                final originalEvents = List<CalendarEvent>.from(events);
                setState(() {
                  events.removeWhere((x) => x.id == e.id);
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
                    // Legacy array-only row: strip from calendarEvents.
                    final List<CalendarEvent> legacyOnly =
                        UserProfileFirestore.parseCalendarEventsFromUserData(
                      _currentUserData,
                    ).where((CalendarEvent x) => x.id != e.id).toList();
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
            gradient: LinearGradient(
              colors: _accentGradientColors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: _scheme.primary.withValues(alpha: 0.35),
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
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.96),
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
                                  color: _onSurface.withValues(alpha: 0.45)),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: _onSurface.withValues(alpha: 0.24),
                                ),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: _onSurface.withValues(alpha: 0.7),
                                ),
                              ),
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
                                  color: _onSurface.withValues(alpha: 0.45)),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: _onSurface.withValues(alpha: 0.24),
                                ),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: _onSurface.withValues(alpha: 0.7),
                                ),
                              ),
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
                              gradient: LinearGradient(
                                colors: _accentGradientColors,
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
                              ? _scheme.primary
                              : Colors.grey.withValues(alpha: 0.3),
                          foregroundColor: isValid ? _onPrimary : _onSurface,
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

                                final String? uid = (_currentUserData['id'] ??
                                        _currentUserData['uid'])
                                    ?.toString();
                                if (uid != null && uid.isNotEmpty) {
                                  UserProfileFirestore.logCalendarSave(
                                    uid: uid,
                                    source: 'ProfileBackView',
                                    count: 1,
                                  );

                                  // Dismiss sheet immediately for instant feel
                                  navigator.pop();

                                  // Show optimistic success message
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Event added to your profile',
                                      ),
                                      backgroundColor:
                                          Theme.of(context).colorScheme.primary,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );

                                  // Phase 0: write via Worker → contentPlans
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
  const _SmallAvatar({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final Color inner = shell.isLight
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.85)
        : Colors.black.withValues(alpha: 0.2);
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: <Color>[
            scheme.primary,
            scheme.secondary,
            scheme.primary,
            scheme.secondary,
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: inner,
          ),
          child: ClipOval(
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? Image.network(imageUrl!, fit: BoxFit.cover)
                : Icon(
                    Icons.person,
                    color: scheme.onSurface,
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
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final String platformType = PlatformRules.normalizePlatformType(
      platform['type'] as String? ?? '',
    );
    final String username = platform['username'] as String? ?? '';
    final bool isAgeRestricted = PlatformRules.isAgeRestrictedEntry(platform);
    return GestureDetector(
      onTap: () {
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: shell.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: shell.surfaceCardBorder,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: shell.chipUnselectedBg,
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
                      color: shell.onChrome,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    isAgeRestricted
                        ? '18+ external link'
                        : (username.isNotEmpty ? '@$username' : 'Open link'),
                    style: TextStyle(
                      color: shell.muted,
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
                color: shell.chipUnselectedBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isAgeRestricted ? Icons.lock_outline : Icons.arrow_forward_ios,
                color: shell.muted,
                size: isAgeRestricted ? 16 : 14,
              ),
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
  const _CalendarCard(
      {required this.title,
      required this.subtitle,
      required this.meta,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: shell.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: shell.surfaceCardBorder,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            color: shell.onChrome,
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
                    color: shell.onChrome,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: shell.muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  meta,
                  style: TextStyle(
                    color: shell.muted,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}
