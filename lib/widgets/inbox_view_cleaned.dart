import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import '../models/chat.dart';
import '../services/chat_service.dart';
import '../providers/unread_messages_provider.dart';
import '../providers/shared_draft_provider.dart';
import '../models/shared_draft.dart';
import 'new_message_view.dart';
import 'online_status_indicator.dart';
import 'chat_view.dart';
import 'shared_draft_item.dart';

class InboxView extends ConsumerStatefulWidget {
  const InboxView({super.key});

  @override
  ConsumerState<InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends ConsumerState<InboxView> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _useFallbackQuery = false;
  bool _isSelectionMode = false;
  Set<String> _selectedChatIds = {};
  late TabController _tabController;
  int _selectedTabIndex = 0;

  // Theme colors
  static const _primaryColor = Color(0xFF6137EB);
  static const _secondaryColor = Color(0xFF1C135D);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });
    // Mark all messages as read when InboxView is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UnreadMessagesService.markAllVisibleAsRead();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Helper method for showing SnackBars
  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  // Helper method for bulk actions
  Future<void> _performBulkAction({
    required String title,
    required String message,
    required Future<void> Function() action,
    required String successMessage,
    required Color successColor,
  }) async {
    if (_selectedChatIds.isEmpty) return;

    final confirmed = await _showConfirmationDialog(title, message);
    if (!confirmed) return;

    try {
      await action();
      _clearSelection();
      _toggleSelectionMode();
      _showSnackBar(successMessage, successColor);
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  // Selection mode methods
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedChatIds.clear();
      }
    });
  }

  void _toggleChatSelection(String chatId) {
    setState(() {
      if (_selectedChatIds.contains(chatId)) {
        _selectedChatIds.remove(chatId);
      } else {
        _selectedChatIds.add(chatId);
      }
    });
  }

  void _selectAllChats(List<Chat> chats) {
    setState(() {
      _selectedChatIds = chats.map((chat) => chat.id!).where((id) => id.isNotEmpty).toSet();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedChatIds.clear();
    });
  }

  // Bulk action methods
  Future<void> _deleteSelectedChats() async {
    await _performBulkAction(
      title: 'Delete Chats',
      message: 'Are you sure you want to delete ${_selectedChatIds.length} chat(s)? This action cannot be undone.',
      action: () => ChatService.shared.deleteMultipleChats(_selectedChatIds.toList()),
      successMessage: 'Deleted ${_selectedChatIds.length} chat(s)',
      successColor: Colors.green,
    );
  }

  Future<void> _muteSelectedChats() async {
    final currentUser = fa.FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await _performBulkAction(
      title: 'Mute Chats',
      message: 'Are you sure you want to mute ${_selectedChatIds.length} chat(s)? You won\'t receive notifications from these chats.',
      action: () => ChatService.shared.muteMultipleChats(_selectedChatIds.toList(), currentUser.uid),
      successMessage: 'Muted ${_selectedChatIds.length} chat(s)',
      successColor: Colors.orange,
    );
  }

  Future<void> _archiveSelectedChats() async {
    final currentUser = fa.FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await _performBulkAction(
      title: 'Archive Chats',
      message: 'Are you sure you want to archive ${_selectedChatIds.length} chat(s)? These chats will be moved to your archived chats.',
      action: () => ChatService.shared.archiveMultipleChats(_selectedChatIds.toList(), currentUser.uid),
      successMessage: 'Archived ${_selectedChatIds.length} chat(s)',
      successColor: Colors.blue,
    );
  }

  Future<bool> _showConfirmationDialog(String title, String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _secondaryColor,
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Confirm',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  // Helper widget for unread count badges
  Widget _buildUnreadBadge(int count, Color color) {
    if (count <= 0) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = fa.FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_primaryColor, _secondaryColor],
          ),
        ),
        child: Column(
          children: [
            _buildTopBar(),
            _buildTabBar(),
            const SizedBox(height: 16),
            _buildSearchBar(),
            const SizedBox(height: 16),
            const Divider(color: Colors.white24, height: 1),
            _buildContent(currentUser),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      child: Stack(
        children: [
          Center(
            child: _isSelectionMode
                ? Text(
                    '${_selectedChatIds.length} selected',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : const Text(
                    'Inbox',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: IconButton(
              icon: Icon(
                _isSelectionMode ? Icons.close : Icons.arrow_back,
                color: Colors.white,
              ),
              onPressed: _isSelectionMode ? _toggleSelectionMode : () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: _isSelectionMode
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selectedChatIds.isNotEmpty) ...[
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: _deleteSelectedChats,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.volume_off, color: Colors.orange),
                          onPressed: _muteSelectedChats,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.archive, color: Colors.blue),
                          onPressed: _archiveSelectedChats,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ],
                  )
                : IconButton(
                    icon: const Icon(Icons.checklist, color: Colors.white),
                    onPressed: _toggleSelectionMode,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.message, size: 18),
                const SizedBox(width: 8),
                const Text('Messages'),
                const SizedBox(width: 4),
                Consumer(
                  builder: (context, ref, child) {
                    final unreadCountAsync = ref.watch(unreadMessagesProvider);
                    return unreadCountAsync.when(
                      data: (unreadCount) => _buildUnreadBadge(unreadCount, Colors.red),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    );
                  },
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.video_library, size: 18),
                const SizedBox(width: 8),
                const Text('Drafts'),
                const SizedBox(width: 4),
                Consumer(
                  builder: (context, ref, child) {
                    final unreadDrafts = ref.watch(unreadSharedDraftsCountProvider);
                    return _buildUnreadBadge(unreadDrafts, _primaryColor);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: _selectedTabIndex == 0 ? 'Search messages' : 'Search shared drafts',
          hintStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
        ),
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildContent(fa.User? currentUser) {
    return Expanded(
      child: currentUser != null
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildChatList(currentUser.uid),
                _buildSharedDraftsList(),
              ],
            )
          : const Center(
              child: Text(
                'Please sign in to view messages',
                style: TextStyle(color: Colors.white70),
              ),
            ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryColor, _secondaryColor],
        ),
      ),
      child: IconButton(
        icon: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const NewMessageView(),
              fullscreenDialog: true,
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatList(String currentUserId) {
    final query = _useFallbackQuery
        ? FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUserId)
            .snapshots()
        : FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUserId)
            .orderBy('lastTimestamp', descending: true)
            .snapshots();
    
    return StreamBuilder<QuerySnapshot>(
      stream: query,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorWidget(snapshot.error.toString());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const _EmptyInboxView();
        }

        final chats = snapshot.data!.docs
            .map((doc) => Chat.fromJson(doc.data() as Map<String, dynamic>).copyWith(id: doc.id))
            .toList();
        
        if (_useFallbackQuery) {
          chats.sort((a, b) => b.lastTimestamp.compareTo(a.lastTimestamp));
        }

        final filteredChats = _searchQuery.isEmpty
            ? chats
            : chats.where((chat) {
                return chat.lastMessage?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
              }).toList();

        return Column(
          children: [
            if (_isSelectionMode && filteredChats.isNotEmpty)
              _buildSelectAllButton(filteredChats),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredChats.length,
                itemBuilder: (context, index) {
                  final chat = filteredChats[index];
                  return _ChatListItem(
                    chat: chat,
                    currentUserId: currentUserId,
                    isSelectionMode: _isSelectionMode,
                    isSelected: _selectedChatIds.contains(chat.id),
                    onTap: () => _isSelectionMode 
                        ? _toggleChatSelection(chat.id!)
                        : _openChat(context, chat, currentUserId),
                    onLongPress: () {
                      if (!_isSelectionMode) {
                        _toggleSelectionMode();
                        _toggleChatSelection(chat.id!);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildErrorWidget(String error) {
    final isIndexError = error.contains('index') || error.contains('FAILED_PRECONDITION');
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            isIndexError 
              ? 'Setting up message system...\nThis may take a moment.'
              : 'Error loading messages',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (isIndexError)
            const Text(
              'The database is being optimized for better performance.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            )
          else
            Text(
              error,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              if (isIndexError) {
                setState(() {
                  _useFallbackQuery = true;
                });
              } else {
                setState(() {});
              }
            },
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text(
              'Retry',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectAllButton(List<Chat> chats) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ElevatedButton.icon(
        onPressed: () => _selectAllChats(chats),
        icon: const Icon(Icons.select_all, color: Colors.white),
        label: const Text(
          'Select All',
          style: TextStyle(color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _openChat(BuildContext context, Chat chat, String currentUserId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatView(
          chat: chat,
          otherUserName: 'User', // TODO: Fetch from Firestore
          otherUserAvatarURL: null,
          otherUserIsOnline: false, // TODO: Check from status
        ),
      ),
    );
  }

  Widget _buildSharedDraftsList() {
    return Consumer(
      builder: (context, ref, child) {
        final sharedDraftsAsync = ref.watch(sharedDraftsProvider);
        
        return sharedDraftsAsync.when(
          data: (sharedDrafts) {
            if (sharedDrafts.isEmpty) {
              return const _EmptySharedDraftsView();
            }

            final filteredDrafts = _searchQuery.isEmpty
                ? sharedDrafts
                : sharedDrafts.where((draft) {
                    return draft.draftTitle.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                           draft.senderName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                           (draft.message?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
                  }).toList();

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredDrafts.length,
              itemBuilder: (context, index) {
                final draft = filteredDrafts[index];
                return SharedDraftItem(
                  sharedDraft: draft,
                  onTap: () => _openSharedDraft(draft),
                  onAccept: () => _acceptSharedDraft(draft),
                  onDecline: () => _declineSharedDraft(draft),
                );
              },
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Error loading shared drafts',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openSharedDraft(SharedDraft sharedDraft) {
    ref.read(sharedDraftNotifierProvider.notifier).markAsViewed(sharedDraft.id);
    _showSnackBar('Opening draft: ${sharedDraft.draftTitle}', _primaryColor);
  }

  void _acceptSharedDraft(SharedDraft sharedDraft) {
    ref.read(sharedDraftNotifierProvider.notifier).markAsViewed(sharedDraft.id);
    _showSnackBar('Accepted draft: ${sharedDraft.draftTitle}', Colors.green);
  }

  void _declineSharedDraft(SharedDraft sharedDraft) {
    ref.read(sharedDraftNotifierProvider.notifier).declineDraft(sharedDraft.id);
    _showSnackBar('Declined draft: ${sharedDraft.draftTitle}', Colors.orange);
  }
}

// Chat List Item Widget
class _ChatListItem extends StatelessWidget {
  final Chat chat;
  final String currentUserId;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelectionMode;
  final bool isSelected;

  const _ChatListItem({
    required this.chat,
    required this.currentUserId,
    required this.onTap,
    this.onLongPress,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final otherUserId = chat.participants.firstWhere((id) => id != currentUserId);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  isSelected 
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.1),
                  isSelected 
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(
                color: isSelected 
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                if (isSelectionMode)
                  _buildSelectionCheckbox()
                else
                  _buildAvatar(otherUserId),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildChatInfo(otherUserId),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionCheckbox() {
    return Container(
      width: 24,
      height: 24,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        color: isSelected ? Colors.white : Colors.transparent,
      ),
      child: isSelected
          ? const Icon(
              Icons.check,
              color: Color(0xFF1C135D),
              size: 16,
            )
          : null,
    );
  }

  Widget _buildChatInfo(String otherUserId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _getChatTitle(otherUserId),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              _formatTimestamp(chat.lastTimestamp),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                chat.lastMessage ?? 'No messages yet',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatar(String userId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final avatarURL = userData['avatarURL'] as String?;
          final displayName = userData['displayName'] as String? ?? 'User';
          
          return Stack(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: avatarURL != null
                      ? Image.network(
                          avatarURL,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultAvatar(displayName);
                          },
                        )
                      : _buildDefaultAvatar(displayName),
                ),
              ),
              AvatarOnlineIndicator(
                userId: userId,
                avatarSize: 50,
                indicatorSize: 14,
                showBorder: true,
                borderColor: Colors.black,
                borderWidth: 2,
                showShadow: false,
              ),
            ],
          );
        }
        
        return _buildDefaultAvatar('User');
      },
    );
  }

  Widget _buildDefaultAvatar(String displayName) {
    return Container(
      color: Colors.grey.withValues(alpha: 0.3),
      child: Center(
        child: Text(
          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _getChatTitle(String otherUserId) {
    if (chat.chatType == 'group' && chat.groupName != null) {
      return chat.groupName!;
    }
    return 'User $otherUserId';
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
}

// Empty Views
class _EmptyInboxView extends StatelessWidget {
  const _EmptyInboxView();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.inbox, size: 80, color: Colors.white),
        const SizedBox(height: 16),
        const Text(
          'Your inbox is empty',
          style: TextStyle(color: Colors.white, fontSize: 18),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Tap + to start a new message',
          style: TextStyle(color: Colors.white70, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () async {
            try {
              await ChatService.shared.createSampleChats();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sample chats created!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error creating sample chats: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
          label: const Text(
            'Create Sample Chats',
            style: TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptySharedDraftsView extends StatelessWidget {
  const _EmptySharedDraftsView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: 40),
        Icon(Icons.video_library_outlined, size: 80, color: Colors.white),
        SizedBox(height: 16),
        Text(
          'No shared drafts yet',
          style: TextStyle(color: Colors.white, fontSize: 18),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          'When friends share their drafts with you,\nthey\'ll appear here',
          style: TextStyle(color: Colors.white70, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
