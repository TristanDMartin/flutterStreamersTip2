import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat.dart' as app_chat;
import '../models/user.dart' as app_user;
import '../services/chat_service.dart';
import '../services/inbox_service_optimized.dart';
import '../services/user_blocking_service.dart';
import 'chat_view_optimized.dart';
import 'choose_person_view.dart';

class NewMessageView extends ConsumerStatefulWidget {
  const NewMessageView({super.key});

  @override
  ConsumerState<NewMessageView> createState() => _NewMessageViewState();
}

class _NewMessageViewState extends ConsumerState<NewMessageView> {
  final TextEditingController _searchController = TextEditingController();
  final ChatService _chatService = ChatService.shared;
  final InboxServiceOptimized _inboxService = InboxServiceOptimized();
  final UserBlockingService _blockingService = UserBlockingService();
  String _searchQuery = '';
  List<app_chat.Chat> _recentChats = [];
  final Map<String, app_user.User> _chatUsers = {};
  bool _isLoadingRecentChats = true;

  @override
  void initState() {
    super.initState();
    _loadRecentChats();
    _blockingService.blockListRevision.addListener(_handleBlockListChanged);
  }

  @override
  void dispose() {
    _blockingService.blockListRevision.removeListener(_handleBlockListChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentChats() async {
    setState(() {
      _isLoadingRecentChats = true;
    });

    try {
      final chats = await _chatService.getUserChats();
      final currentUserId = _inboxService.auth.currentUser?.uid;
      final blockedUserIds = (await _blockingService.getBlockedUsers()).toSet();
      final userMap = <String, app_user.User>{};
      final visibleChats = <app_chat.Chat>[];

      for (final chat in chats) {
        final otherUserId = chat.participants.firstWhere(
          (id) => id != currentUserId,
          orElse: () => '',
        );
        if (otherUserId.isEmpty) continue;
        if (blockedUserIds.contains(otherUserId)) continue;

        final profile = await _inboxService.getUserProfile(otherUserId);
        if (profile != null) {
          visibleChats.add(chat);
          userMap[chat.id ?? otherUserId] = profile;
        }
      }

      if (!mounted) return;
      setState(() {
        _recentChats = visibleChats;
        _chatUsers
          ..clear()
          ..addAll(userMap);
        _isLoadingRecentChats = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recentChats = [];
        _chatUsers.clear();
        _isLoadingRecentChats = false;
      });
    }
  }

  void _handleBlockListChanged() {
    _loadRecentChats();
  }

  List<app_chat.Chat> get _filteredRecentChats {
    if (_searchQuery.trim().isEmpty) {
      return _recentChats;
    }

    final lowerQuery = _searchQuery.toLowerCase();
    return _recentChats.where((chat) {
      final chatId = chat.id ?? '';
      final otherUser = _chatUsers[chatId];
      final displayName = otherUser?.displayName.toLowerCase() ?? '';
      final username = otherUser?.username.toLowerCase() ?? '';
      final lastMessage = (chat.lastMessage ?? '').toLowerCase();
      return displayName.contains(lowerQuery) ||
          username.contains(lowerQuery) ||
          lastMessage.contains(lowerQuery);
    }).toList();
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
    if (_isLoadingRecentChats) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final chats = _filteredRecentChats;
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
            child: chats.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No recent chats yet'
                          : 'No chats match your search',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: chats.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final chat = chats[index];
                      final otherUser = _chatUsers[chat.id ?? ''];
                      return _buildRecentChatTile(chat, otherUser);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentChatTile(
    app_chat.Chat chat,
    app_user.User? otherUser,
  ) {
    final displayName = otherUser?.displayName ?? 'Conversation';
    final username = otherUser?.username ?? '';
    final avatarUrl = otherUser?.avatarURL;

    return GestureDetector(
      onTap: () => _openRecentChat(chat, otherUser),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              backgroundImage:
                  avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (username.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '@$username',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    (chat.lastMessage ?? '').isEmpty
                        ? 'Start the conversation'
                        : chat.lastMessage!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ],
        ),
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

  void _openRecentChat(app_chat.Chat chat, app_user.User? otherUser) {
    final currentUserId = _inboxService.auth.currentUser?.uid;
    final otherUserId = chat.participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    if (otherUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open this conversation'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatViewOptimized(
          chat: chat,
          otherUserId: otherUserId,
          otherUserName: otherUser?.displayName ?? 'Conversation',
          otherUserAvatarURL: otherUser?.avatarURL,
          otherUserIsOnline: (otherUser?.onlineStatus ?? 'offline') == 'online',
        ),
      ),
    );
  }

}
