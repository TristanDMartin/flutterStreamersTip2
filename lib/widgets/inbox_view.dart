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

  Future<void> _deleteSelectedChats() async {
    if (_selectedChatIds.isEmpty) return;

    final confirmed = await _showConfirmationDialog(
      'Delete Chats',
      'Are you sure you want to delete ${_selectedChatIds.length} chat(s)? This action cannot be undone.',
    );

    if (confirmed) {
      try {
        await ChatService.shared.deleteMultipleChats(_selectedChatIds.toList());
        _clearSelection();
        _toggleSelectionMode();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted ${_selectedChatIds.length} chat(s)'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting chats: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _muteSelectedChats() async {
    if (_selectedChatIds.isEmpty) return;

    final currentUser = fa.FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final confirmed = await _showConfirmationDialog(
      'Mute Chats',
      'Are you sure you want to mute ${_selectedChatIds.length} chat(s)? You won\'t receive notifications from these chats.',
    );

    if (confirmed) {
      try {
        await ChatService.shared.muteMultipleChats(_selectedChatIds.toList(), currentUser.uid);
        _clearSelection();
        _toggleSelectionMode();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Muted ${_selectedChatIds.length} chat(s)'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error muting chats: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _archiveSelectedChats() async {
    if (_selectedChatIds.isEmpty) return;

    final currentUser = fa.FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final confirmed = await _showConfirmationDialog(
      'Archive Chats',
      'Are you sure you want to archive ${_selectedChatIds.length} chat(s)? These chats will be moved to your archived chats.',
    );

    if (confirmed) {
      try {
        await ChatService.shared.archiveMultipleChats(_selectedChatIds.toList(), currentUser.uid);
        _clearSelection();
        _toggleSelectionMode();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Archived ${_selectedChatIds.length} chat(s)'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error archiving chats: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<bool> _showConfirmationDialog(String title, String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C135D),
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
            colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
          ),
        ),
        child: Column(
          children: [
            // Custom top bar that goes to the very top
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              child: Stack(
                children: [
                  // Centered title or selection info
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
                  // Back button or Cancel button positioned on the left
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
                  // Selection mode button or bulk actions positioned on the right
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
            ),
            // Tab bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.2),
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
                            // TODO: Add unread messages count provider
                            const unreadCount = 0; // Placeholder
                            if (unreadCount > 0) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  '$unreadCount',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
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
                            if (unreadDrafts > 0) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF9248d2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$unreadDrafts',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Search bar
            Padding(
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
                  fillColor: Colors.white.withValues(alpha:0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white24, height: 1),
            // Content based on selected tab
            Expanded(
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
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF9248D2), // purple
              Color(0xFF7768DF), // lighter purple
              Color(0xFF1670DE), // blue
              Color(0xFF3C8BD6), // lighter blue
              Color(0xFF4897D2), // lightest blue
            ],
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
      ),
    );
  }

  Widget _buildChatList(String currentUserId) {
    // Use fallback query if index is not ready
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
          final error = snapshot.error.toString();
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
                    // Try fallback query if index error
                    if (isIndexError) {
                      setState(() {
                        _useFallbackQuery = true;
                      });
                    } else {
                      // Force a rebuild by calling setState
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text(
                    'Retry',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha:0.2),
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

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const _EmptyInboxView();
        }

        final chats = snapshot.data!.docs
            .map((doc) => Chat.fromJson(doc.data() as Map<String, dynamic>).copyWith(id: doc.id))
            .toList();
        
        // Sort manually if using fallback query
        if (_useFallbackQuery) {
          chats.sort((a, b) => b.lastTimestamp.compareTo(a.lastTimestamp));
        }

        // Filter chats based on search query
        final filteredChats = _searchQuery.isEmpty
            ? chats
            : chats.where((chat) {
                // For now, we'll filter by chat type or last message
                // In a real app, you'd want to search by participant names
                return chat.lastMessage?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
              }).toList();

        return Column(
          children: [
            // Select All button when in selection mode
            if (_isSelectionMode && filteredChats.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ElevatedButton.icon(
                  onPressed: () => _selectAllChats(filteredChats),
                  icon: const Icon(Icons.select_all, color: Colors.white),
                  label: const Text(
                    'Select All',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha:0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            // Chat list
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

  void _openChat(BuildContext context, Chat chat, String currentUserId) {
    // Navigate to chat view
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatView(
          chat: chat,
          otherUserName: 'User', // We'll need to fetch this from Firestore
          otherUserAvatarURL: null,
          otherUserIsOnline: false, // We'll need to check this from status
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

            // Filter drafts based on search query
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
    // Mark as viewed
    ref.read(sharedDraftNotifierProvider.notifier).markAsViewed(sharedDraft.id);
    
    // Navigate to video player or draft preview
    // This would open the shared draft in a video player
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening draft: ${sharedDraft.draftTitle}'),
        backgroundColor: const Color(0xFF9248d2),
      ),
    );
  }

  void _acceptSharedDraft(SharedDraft sharedDraft) {
    // Mark as viewed
    ref.read(sharedDraftNotifierProvider.notifier).markAsViewed(sharedDraft.id);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Accepted draft: ${sharedDraft.draftTitle}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _declineSharedDraft(SharedDraft sharedDraft) {
    ref.read(sharedDraftNotifierProvider.notifier).declineDraft(sharedDraft.id);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Declined draft: ${sharedDraft.draftTitle}'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}

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
                      ? Colors.white.withValues(alpha:0.2)
                      : Colors.white.withValues(alpha:0.1),
                  isSelected 
                      ? Colors.white.withValues(alpha:0.15)
                      : Colors.white.withValues(alpha:0.05),
                ],
              ),
              border: Border.all(
                color: isSelected 
                    ? Colors.white.withValues(alpha:0.3)
                    : Colors.white.withValues(alpha:0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Selection checkbox or avatar
                if (isSelectionMode)
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                      color: isSelected ? Colors.white : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Color(0xFF1C135D),
                            size: 16,
                          )
                        : null,
                  )
                else
                  _buildAvatar(otherUserId),
                const SizedBox(width: 16),
                // Chat info
                Expanded(
                  child: Column(
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
                              color: Colors.white.withValues(alpha:0.6),
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
                                color: Colors.white.withValues(alpha:0.7),
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          // Unread count badge (placeholder for now)
                          if (_hasUnreadMessages())
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                '1', // Placeholder unread count
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
                    color: Colors.white.withValues(alpha:0.2),
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
              // Dynamic online status indicator
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
      color: Colors.grey.withValues(alpha:0.3),
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
    
    // For direct chats, we'll show the other user's name
    // This is a simplified version - in a real app you'd cache user data
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

  bool _hasUnreadMessages() {
    // Placeholder logic - in a real app you'd track read status
    return false;
  }
}

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
        // Sample data button for testing
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
            backgroundColor: Colors.white.withValues(alpha:0.2),
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
