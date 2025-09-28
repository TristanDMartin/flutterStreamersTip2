import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../pages/bookmark_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tiktok_account_switcher_modal.dart';

class ProfileMenuSheetView extends ConsumerStatefulWidget {
  final VoidCallback onDismiss;
  final User user;

  const ProfileMenuSheetView({
    super.key,
    required this.onDismiss,
    required this.user,
  });

  @override
  ConsumerState<ProfileMenuSheetView> createState() => _ProfileMenuSheetViewState();
}

class _ProfileMenuSheetViewState extends ConsumerState<ProfileMenuSheetView> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF9248D2), // Rich purple
              Color(0xFF7768DF), // Purple-blue
              Color(0xFF1670DE), // Blue
              Color(0xFF3C8BD6), // Lighter blue
              Color(0xFF4897D2), // Lightest blue
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with close button
              _buildHeader(),
              
              // Menu items
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildMenuItem(
                        icon: Icons.bookmark,
                        label: 'Bookmarks',
                        onTap: () => _showBookmarksView(),
                      ),
                      const SizedBox(height: 12),
                      _buildMenuItem(
                        icon: Icons.calendar_today,
                        label: 'Scheduled Content',
                        onTap: () {
                          // Placeholder
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildMenuItem(
                        icon: Icons.bar_chart,
                        label: 'Insights',
                        onTap: () {
                          // Placeholder for insights modal
                        },
                      ),
                      const SizedBox(height: 12),
                      
                      // Switch Account Button with Dropdown
                      _buildSwitchAccountSection(),
                      const SizedBox(height: 12),
                      
                      _buildMenuItem(
                        icon: Icons.logout,
                        label: 'Log out',
                        color: Colors.red,
                        onTap: () => _showLogoutDialog(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onDismiss,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha:0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const Spacer(),
          const Text(
            'Menu',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 44), // Balance the close button
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 28),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: color,
              size: 22,
            ),
            const SizedBox(width: 18),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchAccountSection() {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            // Close the menu and show TikTok account switcher
            widget.onDismiss();
            _showTikTokAccountSwitcher();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 28),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.people,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 18),
                const Text(
                  'Switch Account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                // TikTok-style account switcher indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6633CC), Color(0xFF1A1A4D)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha:0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'TikTok Style',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.swap_horiz,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        
        // TikTok-style account switcher modal will handle everything
      ],
    );
  }


  void _showTikTokAccountSwitcher() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const TikTokAccountSwitcherModal(),
    );
  }

  void _showBookmarksView() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const BookmarkView(),
      ),
    );
  }



  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C135D),
        title: const Text(
          'Log out?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _logout();
            },
            child: const Text(
              'Log out',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _logout() async {
    try {
      // Check if widget is still mounted
      if (!mounted) return;
      
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
      
      // Check if widget is still mounted before dismissing
      if (mounted) {
        widget.onDismiss();
      }
    } catch (e) {
      // Handle logout error gracefully
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class BookmarksListView extends ConsumerStatefulWidget {
  final User user;
  final VoidCallback onDismiss;

  const BookmarksListView({
    super.key,
    required this.user,
    required this.onDismiss,
  });

  @override
  ConsumerState<BookmarksListView> createState() => _BookmarksListViewState();
}

class _BookmarksListViewState extends ConsumerState<BookmarksListView> {
  bool _isLoading = true;
  List<BookmarkedEvent> _bookmarks = [];

  @override
  void initState() {
    super.initState();
    _fetchBookmarks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF9248D2), // Purple
              Color(0xFF7768DF), // Another purple
              Color(0xFF1670DE), // Blue
              Color(0xFF3C8BD6), // Lighter blue
              Color(0xFF4897D2), // Lightest blue
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),
              
              // Content
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _bookmarks.isEmpty
                        ? _buildEmptyState()
                        : _buildBookmarksList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onDismiss,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha:0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const Spacer(),
          const Text(
            'Bookmarks',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 44), // Balance the close button
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Loading bookmarks...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_remove,
            color: Colors.white54,
            size: 48,
          ),
          SizedBox(height: 16),
          Text(
            'No bookmarks yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Events you bookmark will appear here',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarksList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      itemCount: _bookmarks.length,
      itemBuilder: (context, index) {
        final event = _bookmarks[index];
        return _buildBookmarkCard(event);
      },
    );
  }

  Widget _buildBookmarkCard(BookmarkedEvent event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                      event.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.bookmark,
                color: Color(0xFF25E5D2),
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                color: Colors.white54,
                size: 12,
              ),
              const SizedBox(width: 8),
              Text(
                '${event.date.day}/${event.date.month}/${event.date.year}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.access_time,
                color: Colors.white54,
                size: 12,
              ),
              const SizedBox(width: 8),
              Text(
                '${event.date.hour.toString().padLeft(2, '0')}:${event.date.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.person,
                color: Colors.white54,
                size: 12,
              ),
              const SizedBox(width: 8),
              Text(
                'by ${event.ownerDisplayName}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _fetchBookmarks() async {
    try {
      final db = FirebaseFirestore.instance;
      final snapshot = await db
          .collection('users')
          .doc(widget.user.id)
          .collection('bookmarkedEvents')
          .orderBy('date')
          .get();

      final bookmarks = snapshot.docs.map((doc) {
        final data = doc.data();
        return BookmarkedEvent(
          id: doc.id,
          title: data['title'] ?? '',
          description: data['description'] ?? '',
          date: (data['date'] as Timestamp).toDate(),
          ownerDisplayName: data['ownerDisplayName'] ?? '',
        );
      }).toList();

      setState(() {
        _bookmarks = bookmarks;
        _isLoading = false;
      });
    } catch (e) {
    // print('Error fetching bookmarks: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
}

class BookmarkedEvent {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String ownerDisplayName;

  BookmarkedEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.ownerDisplayName,
  });
}