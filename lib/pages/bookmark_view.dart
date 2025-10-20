import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/bookmark_event.dart';
import '../services/enhanced_bookmark_service.dart';

class BookmarkView extends StatefulWidget {
  const BookmarkView({super.key});

  @override
  State<BookmarkView> createState() => _BookmarkViewState();
}

class _BookmarkViewState extends State<BookmarkView> with TickerProviderStateMixin {
  late final EnhancedBookmarkService _bookmarkService;
  late final TabController _tabController;
  
  List<BookmarkEvent> _bookmarks = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bookmarkService = EnhancedBookmarkService();
    _tabController = TabController(length: 3, vsync: this);
    _initializeBookmarks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeBookmarks() async {
    try {
      await _bookmarkService.initialize();
      _loadBookmarks();
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize bookmarks: $e';
        _isLoading = false;
      });
    }
  }

  void _loadBookmarks() {
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
      onError: (error) {
        if (mounted) {
          setState(() {
            _error = 'Failed to load bookmarks: $error';
            _isLoading = false;
          });
        }
      },
    );
  }

  Map<EventStatus, List<BookmarkEvent>> _getBookmarksByStatus() {
    final Map<EventStatus, List<BookmarkEvent>> grouped = {
      EventStatus.upcoming: [],
      EventStatus.live: [],
      EventStatus.past: [],
    };

    for (final bookmark in _bookmarks) {
      grouped[bookmark.status]!.add(bookmark);
    }

    return grouped;
  }

  Future<void> _deleteBookmark(BookmarkEvent bookmark) async {
    HapticFeedback.lightImpact();
    
    // Optimistic UI update
    setState(() {
      _bookmarks.removeWhere((b) => b.eventId == bookmark.eventId);
    });

    try {
      final success = await _bookmarkService.deleteBookmark(eventId: bookmark.eventId);
      
      if (!success && mounted) {
        // Revert optimistic update on failure
        setState(() {
          _bookmarks.add(bookmark);
          _bookmarks.sort((a, b) => a.notifyAt.compareTo(b.notifyAt));
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete bookmark'),
            backgroundColor: Colors.red,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bookmark deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Revert optimistic update on error
      if (mounted) {
        setState(() {
          _bookmarks.add(bookmark);
          _bookmarks.sort((a, b) => a.notifyAt.compareTo(b.notifyAt));
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleNotification(BookmarkEvent bookmark) async {
    HapticFeedback.lightImpact();
    
    final newNotify = !bookmark.notify;
    
    // Optimistic UI update
    setState(() {
      final index = _bookmarks.indexWhere((b) => b.eventId == bookmark.eventId);
      if (index != -1) {
        _bookmarks[index] = bookmark.copyWith(notify: newNotify);
      }
    });

    try {
      final success = await _bookmarkService.toggleNotification(
        eventId: bookmark.eventId,
        notify: newNotify,
      );
      
      if (!success && mounted) {
        // Revert optimistic update on failure
        setState(() {
          final index = _bookmarks.indexWhere((b) => b.eventId == bookmark.eventId);
          if (index != -1) {
            _bookmarks[index] = bookmark;
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update notification settings'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Revert optimistic update on error
      if (mounted) {
        setState(() {
          final index = _bookmarks.indexWhere((b) => b.eventId == bookmark.eventId);
          if (index != -1) {
            _bookmarks[index] = bookmark;
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
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
              controller: _tabController,
              indicatorColor: const Color(0xFF955CFF),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: 'Upcoming'),
                Tab(text: 'Live'),
                Tab(text: 'Past'),
              ],
            ),
          ),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF955CFF),
                  ),
                )
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _initializeBookmarks,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildBookmarkList(EventStatus.upcoming),
                        _buildBookmarkList(EventStatus.live),
                        _buildBookmarkList(EventStatus.past),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildBookmarkList(EventStatus status) {
    final groupedBookmarks = _getBookmarksByStatus();
    final bookmarks = groupedBookmarks[status] ?? [];

    if (bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getEmptyIcon(status),
              color: Colors.grey,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _getEmptyMessage(status),
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = bookmarks[index];
        return _buildBookmarkCard(bookmark);
      },
    );
  }

  Widget _buildBookmarkCard(BookmarkEvent bookmark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showBookmarkDetails(bookmark),
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
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(bookmark.status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    color: Colors.grey[400],
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDateTime(bookmark.startAt),
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    bookmark.formattedStartTime,
                    style: TextStyle(
                      color: _getTimeColor(bookmark.status),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    onPressed: () => _toggleNotification(bookmark),
                    icon: Icon(
                      bookmark.notify ? Icons.notifications : Icons.notifications_off,
                      color: bookmark.notify ? const Color(0xFF955CFF) : Colors.grey,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _showDeleteConfirmation(bookmark),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(EventStatus status) {
    Color color;
    switch (status) {
      case EventStatus.upcoming:
        color = Colors.blue;
        break;
      case EventStatus.live:
        color = Colors.green;
        break;
      case EventStatus.past:
        color = Colors.grey;
        break;
    }

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
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ${difference.inHours % 24}h';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Now';
    }
  }

  Color _getTimeColor(EventStatus status) {
    switch (status) {
      case EventStatus.upcoming:
        return Colors.blue;
      case EventStatus.live:
        return Colors.green;
      case EventStatus.past:
        return Colors.grey;
    }
  }

  IconData _getEmptyIcon(EventStatus status) {
    switch (status) {
      case EventStatus.upcoming:
        return Icons.schedule;
      case EventStatus.live:
        return Icons.live_tv;
      case EventStatus.past:
        return Icons.history;
    }
  }

  String _getEmptyMessage(EventStatus status) {
    switch (status) {
      case EventStatus.upcoming:
        return 'No upcoming events bookmarked';
      case EventStatus.live:
        return 'No live events right now';
      case EventStatus.past:
        return 'No past events bookmarked';
    }
  }

  void _showBookmarkDetails(BookmarkEvent bookmark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          bookmark.title,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Creator: ${bookmark.creatorName}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Start Time: ${_formatDateTime(bookmark.startAt)}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Notifications: ${bookmark.notify ? "On" : "Off"}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BookmarkEvent bookmark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Delete Bookmark',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${bookmark.title}" from your bookmarks?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteBookmark(bookmark);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
