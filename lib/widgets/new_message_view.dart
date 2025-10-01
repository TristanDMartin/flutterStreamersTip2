import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'choose_person_view.dart';
// import 'invite_friends_view.dart'; // Removed - unused
// import 'start_group_view.dart'; // Removed - unused
// import 'draft_selection_view.dart'; // Removed - unused

class NewMessageView extends ConsumerStatefulWidget {
  const NewMessageView({super.key});

  @override
  ConsumerState<NewMessageView> createState() => _NewMessageViewState();
}

class _NewMessageViewState extends ConsumerState<NewMessageView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),
              
              // Search Bar
              _buildSearchBar(),
              
              const Divider(color: Colors.white24, height: 1),
              
              // Primary Actions
              _buildPrimaryActions(),
              
              const Divider(color: Colors.white24, height: 1),
              
              // Recent Chats (Optional)
              Expanded(
                child: _buildRecentChats(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const Expanded(
            child: Text(
              'New Message',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.1),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: Colors.white.withValues(alpha:0.7),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Search connections...',
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
              },
              icon: Icon(
                Icons.close,
                color: Colors.white.withValues(alpha:0.7),
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPrimaryActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // New Message (single chat) - placed above Invite
          _buildActionCard(
            icon: Icons.message,
            title: 'New Message',
            subtitle: 'Start a direct message with a connection',
            onTap: () => _navigateToChoosePerson(),
          ),
          
          const SizedBox(height: 12),
          
          // Invite (send connection requests)
          _buildActionCard(
            icon: Icons.person_add,
            title: 'Invite',
            subtitle: 'Send connection requests to friends',
            onTap: () => _navigateToInviteFriends(),
          ),
          
          const SizedBox(height: 12),
          
          // Send Draft
          _buildActionCard(
            icon: Icons.drafts,
            title: 'Send Draft',
            subtitle: 'Share a draft video with your connections',
            onTap: () => _navigateToDraftSelection(),
          ),
          
          const SizedBox(height: 12),
          
          // Group Chat (multi-select, then create)
          _buildActionCard(
            icon: Icons.group,
            title: 'Group Chat',
            subtitle: 'Create a group message with multiple connections',
            onTap: () => _navigateToStartGroup(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha:0.1),
              Colors.white.withValues(alpha:0.05),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha:0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha:0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha:0.5),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentChats() {
    // This would show recent chats if implemented
    // For now, show a placeholder
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Chats',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Text(
                'No recent chats',
                style: TextStyle(
                  color: Colors.white.withValues(alpha:0.7),
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToChoosePerson() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ChoosePersonView(),
        fullscreenDialog: true,
      ),
    );
  }

  void _navigateToInviteFriends() {
    // Navigator.of(context).push(
    //   MaterialPageRoute(
    //     builder: (context) => const InviteFriendsView(),
    //     fullscreenDialog: true,
    //   ),
    // );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite friends feature coming soon!')),
    );
  }

  void _navigateToStartGroup() {
    // Navigator.of(context).push(
    //   MaterialPageRoute(
    //     builder: (context) => const StartGroupView(),
    //     fullscreenDialog: true,
    //   ),
    // );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Start group feature coming soon!')),
    );
  }

  void _navigateToDraftSelection() {
    // Navigator.of(context).push(
    //   MaterialPageRoute(
    //     builder: (context) => const DraftSelectionView(),
    //     fullscreenDialog: true,
    //   ),
    // );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Draft selection feature coming soon!')),
    );
  }
}