import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/bookmark_event.dart';
import '../services/enhanced_bookmark_service.dart';
import '../widgets/profile_video_feed_view.dart';

class BookmarkView extends StatefulWidget {
  const BookmarkView({super.key});

  @override
  State<BookmarkView> createState() => _BookmarkViewState();
}

class _BookmarkViewState extends State<BookmarkView>
    with TickerProviderStateMixin {
  late final TabController _outerTabController;
  late final TabController _eventTabController;
  late final EnhancedBookmarkService _bookmarkService;

  List<BookmarkEvent> _bookmarks = [];
  bool _isLoading = true;
  String? _error;

  static const Color _purple = Color(0xFF955CFF);
  static const Color _gradientStart = Color(0xFF6137EB);
  static const Color _gradientEnd = Color(0xFF1C135D);

  @override
  void initState() {
    super.initState();
    _outerTabController = TabController(length: 2, vsync: this);
    _eventTabController = TabController(length: 3, vsync: this);
    _bookmarkService = EnhancedBookmarkService();
    _initializeBookmarks();
  }

  @override
  void dispose() {
    _outerTabController.dispose();
    _eventTabController.dispose();
    super.dispose();
  }

  Future<void> _initializeBookmarks() async {
    try {
      await _bookmarkService.initialize();
      _bookmarkService.getBookmarksStream().listen(
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
              _error = 'Failed to load bookmarks: $error';
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to initialize bookmarks: $e';
          _isLoading = false;
        });
      }
    }
  }

  Map<EventStatus, List<BookmarkEvent>> _getBookmarksByStatus() {
    return {
      EventStatus.upcoming: _bookmarks
          .where((b) => b.status == EventStatus.upcoming)
          .toList(),
      EventStatus.live:
          _bookmarks.where((b) => b.status == EventStatus.live).toList(),
      EventStatus.past:
          _bookmarks.where((b) => b.status == EventStatus.past).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_gradientStart, _gradientEnd],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Bookmarks',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            bottom: TabBar(
              controller: _outerTabController,
              indicatorColor: _purple,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              tabs: const [
                Tab(text: 'Videos'),
                Tab(text: 'Events'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _outerTabController,
            children: [
              _SavedVideosTab(userId: currentUser?.uid),
              _EventsTab(
                isLoading: _isLoading,
                error: _error,
                bookmarksByStatus: _getBookmarksByStatus(),
                tabController: _eventTabController,
                onRetry: _initializeBookmarks,
                onDelete: _deleteBookmark,
                onToggleNotification: _toggleNotification,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteBookmark(BookmarkEvent bookmark) async {
    HapticFeedback.lightImpact();
    setState(() => _bookmarks.removeWhere((b) => b.eventId == bookmark.eventId));
    final success =
        await _bookmarkService.deleteBookmark(eventId: bookmark.eventId);
    if (!success && mounted) {
      setState(() {
        _bookmarks.add(bookmark);
        _bookmarks.sort((a, b) => a.notifyAt.compareTo(b.notifyAt));
      });
    }
  }

  Future<void> _toggleNotification(BookmarkEvent bookmark) async {
    HapticFeedback.lightImpact();
    final newNotify = !bookmark.notify;
    setState(() {
      final index = _bookmarks.indexWhere((b) => b.eventId == bookmark.eventId);
      if (index != -1) _bookmarks[index] = bookmark.copyWith(notify: newNotify);
    });
    final success = await _bookmarkService.toggleNotification(
      eventId: bookmark.eventId,
      notify: newNotify,
    );
    if (!success && mounted) {
      setState(() {
        final index =
            _bookmarks.indexWhere((b) => b.eventId == bookmark.eventId);
        if (index != -1) _bookmarks[index] = bookmark;
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
    if (userId == null) {
      return const Center(
        child: Text(
          'Sign in to view saved videos',
          style: TextStyle(color: Colors.white70),
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
  final Map<EventStatus, List<BookmarkEvent>> bookmarksByStatus;
  final TabController tabController;
  final VoidCallback onRetry;
  final Future<void> Function(BookmarkEvent) onDelete;
  final Future<void> Function(BookmarkEvent) onToggleNotification;

  static const Color _purple = Color(0xFF955CFF);

  const _EventsTab({
    required this.isLoading,
    required this.error,
    required this.bookmarksByStatus,
    required this.tabController,
    required this.onRetry,
    required this.onDelete,
    required this.onToggleNotification,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _purple),
      );
    }
    if (error != null) {
      return _ErrorState(error: error!, onRetry: onRetry);
    }
    return Column(
      children: [
        _buildEventTabBar(),
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

  Widget _buildEventTabBar() {
    return TabBar(
      controller: tabController,
      indicatorColor: _purple,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.grey,
      tabs: const [
        Tab(text: 'Upcoming'),
        Tab(text: 'Live'),
        Tab(text: 'Past'),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          Text(
            error,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, color: Colors.grey, size: 64),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(color: Colors.grey, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookmarks.length,
      itemBuilder: (context, index) =>
          _EventCard(
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

  static const Color _purple = Color(0xFF955CFF);

  const _EventCard({
    required this.bookmark,
    required this.onDelete,
    required this.onToggleNotification,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: () => _showDetails(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bookmark.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bookmark.creatorName,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(status: bookmark.status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule, color: Colors.grey[400], size: 16),
                  const SizedBox(width: 8),
                  Text(
                    _formatRelative(bookmark.startAt),
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    bookmark.formattedStartTime,
                    style: TextStyle(
                      color: _timeColor(bookmark.status),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: () => onToggleNotification(bookmark),
                    icon: Icon(
                      bookmark.notify
                          ? Icons.notifications
                          : Icons.notifications_off,
                      color: bookmark.notify ? _purple : Colors.grey,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _confirmDelete(context),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
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
    final diff = dt.difference(DateTime.now());
    if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours % 24}h';
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'Now';
  }

  Color _timeColor(EventStatus status) {
    switch (status) {
      case EventStatus.upcoming:
        return Colors.blue;
      case EventStatus.live:
        return Colors.green;
      case EventStatus.past:
        return Colors.grey;
    }
  }

  void _showDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(bookmark.title,
            style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Creator: ${bookmark.creatorName}',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Text('Start: ${_formatRelative(bookmark.startAt)}',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Text(
                'Notifications: ${bookmark.notify ? "On" : "Off"}',
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close')),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Delete Bookmark',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove "${bookmark.title}" from your bookmarks?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDelete(bookmark);
            },
            child:
                const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final EventStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      EventStatus.upcoming => Colors.blue,
      EventStatus.live => Colors.green,
      EventStatus.past => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
