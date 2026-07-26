import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../core/theme/support_shell_style.dart';
import '../models/bookmark_event.dart';
import '../services/unified_bookmark_service.dart';
import '../utils/user_facing_error.dart';
import '../widgets/profile_video_feed_view.dart';
import '../widgets/screen_feedback_state.dart';

class BookmarkView extends StatefulWidget {
  const BookmarkView({super.key});

  @override
  State<BookmarkView> createState() => _BookmarkViewState();
}

class _BookmarkViewState extends State<BookmarkView>
    with TickerProviderStateMixin {
  late final TabController _outerTabController;
  late final TabController _eventTabController;
  final UnifiedBookmarkService _bookmarkService =
      UnifiedBookmarkService.instance;

  List<BookmarkEvent> _bookmarks = [];
  bool _isLoading = true;
  String? _error;
  String? _actionError;
  StreamSubscription<List<BookmarkEvent>>? _bookmarkSubscription;

  @override
  void initState() {
    super.initState();
    _outerTabController = TabController(length: 2, vsync: this);
    _eventTabController = TabController(length: 3, vsync: this);
    _initializeBookmarks();
  }

  @override
  void dispose() {
    _bookmarkSubscription?.cancel();
    _outerTabController.dispose();
    _eventTabController.dispose();
    super.dispose();
  }

  Future<void> _initializeBookmarks() async {
    try {
      await _bookmarkService.initializeCalendarEventBookmarks();
      await _bookmarkSubscription?.cancel();
      _bookmarkSubscription =
          _bookmarkService.calendarEventBookmarksStream().listen(
        (bookmarks) {
          if (mounted) {
            setState(() {
              _bookmarks = bookmarks;
              _isLoading = false;
              _error = null;
            });
          }
        },
        onError: (Object error) {
          if (mounted) {
            setState(() {
              _error = UserFacingError.message(error);
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = UserFacingError.message(e);
          _isLoading = false;
        });
      }
    }
  }

  Map<EventStatus, List<BookmarkEvent>> _getBookmarksByStatus() {
    return {
      EventStatus.upcoming:
          _bookmarks.where((b) => b.status == EventStatus.upcoming).toList(),
      EventStatus.live:
          _bookmarks.where((b) => b.status == EventStatus.live).toList(),
      EventStatus.past:
          _bookmarks.where((b) => b.status == EventStatus.past).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final firebase_auth.User? currentUser =
        firebase_auth.FirebaseAuth.instance.currentUser;
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: shell.pageGradient,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: shell.onChrome,
          title: Text(
            'Bookmarks',
            style: TextStyle(
              color: shell.onChrome,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          bottom: TabBar(
            controller: _outerTabController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            indicator: BoxDecoration(
              color: shell.chipSelectedBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: shell.chipSelectedBorder),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: cs.outlineVariant.withValues(alpha: 0.35),
            labelColor: shell.chipSelectedFg,
            unselectedLabelColor: shell.muted,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
            tabs: const <Widget>[
              Tab(text: 'Videos'),
              Tab(text: 'Events'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _outerTabController,
          children: <Widget>[
            _SavedVideosTab(userId: currentUser?.uid),
            _EventsTab(
              isLoading: _isLoading,
              error: _error,
              actionError: _actionError,
              bookmarksByStatus: _getBookmarksByStatus(),
              tabController: _eventTabController,
              onRetry: _initializeBookmarks,
              onDismissActionError: () {
                if (mounted) {
                  setState(() => _actionError = null);
                }
              },
              onDelete: _deleteBookmark,
              onToggleNotification: _toggleNotification,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteBookmark(BookmarkEvent bookmark) async {
    HapticFeedback.lightImpact();
    setState(() {
      _actionError = null;
      _bookmarks.removeWhere((b) => b.eventId == bookmark.eventId);
    });
    final bool success = await _bookmarkService.deleteCalendarEventBookmark(
      eventId: bookmark.eventId,
    );
    if (!success && mounted) {
      setState(() {
        _bookmarks.add(bookmark);
        _bookmarks.sort((a, b) => a.notifyAt.compareTo(b.notifyAt));
        _actionError = 'Could not remove bookmark. Please try again.';
      });
    }
  }

  Future<void> _toggleNotification(BookmarkEvent bookmark) async {
    HapticFeedback.lightImpact();
    final bool newNotify = !bookmark.notify;
    setState(() {
      _actionError = null;
      final int index =
          _bookmarks.indexWhere((b) => b.eventId == bookmark.eventId);
      if (index != -1) {
        _bookmarks[index] = bookmark.copyWith(notify: newNotify);
      }
    });
    final bool success =
        await _bookmarkService.toggleCalendarEventNotification(
      eventId: bookmark.eventId,
      notify: newNotify,
    );
    if (!success && mounted) {
      setState(() {
        final int index =
            _bookmarks.indexWhere((b) => b.eventId == bookmark.eventId);
        if (index != -1) {
          _bookmarks[index] = bookmark;
        }
        _actionError = 'Could not update notification. Please try again.';
      });
    }
  }
}

// ─── Saved Videos Tab ────────────────────────────────────────────────────────

class _SavedVideosTab extends StatelessWidget {
  final String? userId;

  const _SavedVideosTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    if (userId == null) {
      return Center(
        child: Text(
          'Sign in to view saved videos',
          style: TextStyle(color: shell.muted, fontWeight: FontWeight.w600),
        ),
      );
    }
    return ProfileVideoFeedView(
      feedType: ProfileVideoFeedType.favorites,
      userId: userId,
    );
  }
}

// ─── Events Tab ──────────────────────────────────────────────────────────────

class _EventsTab extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final String? actionError;
  final Map<EventStatus, List<BookmarkEvent>> bookmarksByStatus;
  final TabController tabController;
  final VoidCallback onRetry;
  final VoidCallback onDismissActionError;
  final Future<void> Function(BookmarkEvent) onDelete;
  final Future<void> Function(BookmarkEvent) onToggleNotification;

  const _EventsTab({
    required this.isLoading,
    required this.error,
    required this.actionError,
    required this.bookmarksByStatus,
    required this.tabController,
    required this.onRetry,
    required this.onDismissActionError,
    required this.onDelete,
    required this.onToggleNotification,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }
    if (error != null) {
      return ScreenErrorState(
        title: 'Couldn’t load bookmarks',
        message: error!,
        onRetry: onRetry,
      );
    }
    return Column(
      children: <Widget>[
        if (actionError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ScreenInlineErrorBanner(
              message: actionError!,
              onDismiss: onDismissActionError,
            ),
          ),
        _buildEventTabBar(context),
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              _EventList(
                bookmarks: bookmarksByStatus[EventStatus.upcoming] ?? [],
                emptyIcon: Icons.schedule,
                emptyMessage: 'No upcoming events bookmarked',
                onDelete: onDelete,
                onToggleNotification: onToggleNotification,
              ),
              _EventList(
                bookmarks: bookmarksByStatus[EventStatus.live] ?? [],
                emptyIcon: Icons.live_tv,
                emptyMessage: 'No live events right now',
                onDelete: onDelete,
                onToggleNotification: onToggleNotification,
              ),
              _EventList(
                bookmarks: bookmarksByStatus[EventStatus.past] ?? [],
                emptyIcon: Icons.history,
                emptyMessage: 'No past events bookmarked',
                onDelete: onDelete,
                onToggleNotification: onToggleNotification,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEventTabBar(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    return TabBar(
      controller: tabController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      indicator: BoxDecoration(
        color: shell.chipSelectedBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: shell.chipSelectedBorder),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: cs.outlineVariant.withValues(alpha: 0.35),
      labelColor: shell.chipSelectedFg,
      unselectedLabelColor: shell.muted,
      tabs: const <Widget>[
        Tab(text: 'Upcoming'),
        Tab(text: 'Live'),
        Tab(text: 'Past'),
      ],
    );
  }
}

class _EventList extends StatelessWidget {
  final List<BookmarkEvent> bookmarks;
  final IconData emptyIcon;
  final String emptyMessage;
  final Future<void> Function(BookmarkEvent) onDelete;
  final Future<void> Function(BookmarkEvent) onToggleNotification;

  const _EventList({
    required this.bookmarks,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.onDelete,
    required this.onToggleNotification,
  });

  @override
  Widget build(BuildContext context) {
    if (bookmarks.isEmpty) {
      return ScreenEmptyState(
        title: emptyMessage,
        icon: emptyIcon,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookmarks.length,
      itemBuilder: (context, index) => _EventCard(
        bookmark: bookmarks[index],
        onDelete: onDelete,
        onToggleNotification: onToggleNotification,
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final BookmarkEvent bookmark;
  final Future<void> Function(BookmarkEvent) onDelete;
  final Future<void> Function(BookmarkEvent) onToggleNotification;

  const _EventCard({
    required this.bookmark,
    required this.onDelete,
    required this.onToggleNotification,
  });

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: shell.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: shell.surfaceCardBorder),
      ),
      child: InkWell(
        onTap: () => _showDetails(context),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          bookmark.title,
                          style: TextStyle(
                            color: shell.onChrome,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bookmark.creatorName,
                          style: TextStyle(
                            color: shell.muted,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(status: bookmark.status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Icon(Icons.schedule_rounded, color: shell.iconDim, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    _formatRelative(bookmark.startAt),
                    style: TextStyle(
                      color: shell.muted,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      bookmark.formattedStartTime,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: _timeColor(bookmark.status, cs),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  IconButton.filledTonal(
                    onPressed: () => onToggleNotification(bookmark),
                    icon: Icon(
                      bookmark.notify
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_off_outlined,
                      color: bookmark.notify ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: () => _confirmDelete(context),
                    icon: Icon(Icons.delete_outline_rounded, color: cs.error),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRelative(DateTime dt) {
    final Duration diff = dt.difference(DateTime.now());
    if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours % 24}h';
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'Now';
  }

  Color _timeColor(EventStatus status, ColorScheme cs) {
    switch (status) {
      case EventStatus.upcoming:
        return cs.primary;
      case EventStatus.live:
        return cs.tertiary;
      case EventStatus.past:
        return cs.onSurfaceVariant;
    }
  }

  void _showDetails(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(bookmark.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Creator: ${bookmark.creatorName}',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Text(
                'Start: ${_formatRelative(bookmark.startAt)}',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Text(
                'Notifications: ${bookmark.notify ? "On" : "Off"}',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete bookmark'),
          content: Text(
            'Remove "${bookmark.title}" from your bookmarks?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onDelete(bookmark);
              },
              child: Text(
                'Delete',
                style: TextStyle(color: cs.error, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final EventStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color color = switch (status) {
      EventStatus.upcoming => cs.primary,
      EventStatus.live => cs.tertiary,
      EventStatus.past => cs.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
