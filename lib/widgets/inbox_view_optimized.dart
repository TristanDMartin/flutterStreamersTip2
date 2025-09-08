import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat.dart' as app_chat;
import '../models/shared_draft.dart';
import '../services/inbox_service_optimized.dart';
import 'chat_view_optimized.dart';

class InboxViewOptimized extends StatefulWidget {
  const InboxViewOptimized({super.key});

  @override
  State<InboxViewOptimized> createState() => _InboxViewOptimizedState();
}

class _InboxViewOptimizedState extends State<InboxViewOptimized>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final InboxServiceOptimized _inboxService = InboxServiceOptimized();
  final TextEditingController _searchController = TextEditingController();

  // Data
  List<app_chat.Chat> _chats = [];
  List<SharedDraft> _sharedDrafts = [];
  List<app_chat.Chat> _filteredChats = [];
  List<SharedDraft> _filteredDrafts = [];

  // State
  bool _isLoading = true;
  String? _error;
  bool _isSelectionMode = false;
  Set<String> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load chats and drafts in parallel
      final results = await Future.wait([
        _inboxService.getChats(),
        _inboxService.getSharedDrafts(),
      ]);

      setState(() {
        _chats = results[0] as List<app_chat.Chat>;
        _sharedDrafts = results[1] as List<SharedDraft>;
        _filteredChats = _chats;
        _filteredDrafts = _sharedDrafts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredChats = _chats;
        _filteredDrafts = _sharedDrafts;
      } else {
        _filteredChats = _chats.where((chat) {
          final lastMessage = chat.lastMessage?.toLowerCase() ?? '';
          final participants = chat.participants.join(' ').toLowerCase();
          return lastMessage.contains(query.toLowerCase()) || 
                 participants.contains(query.toLowerCase());
        }).toList();
        
        _filteredDrafts = _sharedDrafts.where((draft) {
          final title = draft.draftTitle.toLowerCase();
          final message = draft.message?.toLowerCase() ?? '';
          return title.contains(query.toLowerCase()) || 
                 message.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildTabBar(),
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _error != null
                      ? _buildErrorState()
                      : _buildTabContent(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewMessage,
        backgroundColor: const Color(0xFF9248D2),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const Expanded(
            child: Text(
              'Inbox',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: _toggleSelectionMode,
            icon: Icon(
              _isSelectionMode ? Icons.close : Icons.checklist,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search messages...',
          hintStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.grey[900],
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

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF9248D2),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey,
        tabs: const [
          Tab(text: 'Messages'),
          Tab(text: 'Drafts'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildChatList(),
        _buildDraftsList(),
      ],
    );
  }

  Widget _buildChatList() {
    if (_filteredChats.isEmpty) {
      return _buildEmptyState('No messages yet', Icons.chat_bubble_outline);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _filteredChats.length,
      itemBuilder: (context, index) {
        final chat = _filteredChats[index];
        return _buildChatTile(chat);
      },
    );
  }

  Widget _buildDraftsList() {
    if (_filteredDrafts.isEmpty) {
      return _buildEmptyState('No shared drafts yet', Icons.drafts);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _filteredDrafts.length,
      itemBuilder: (context, index) {
        final draft = _filteredDrafts[index];
        return _buildDraftTile(draft);
      },
    );
  }

  Widget _buildChatTile(app_chat.Chat chat) {
    final isSelected = _selectedItems.contains(chat.id);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF9248D2),
          child: Text(
            chat.participants.isNotEmpty 
                ? chat.participants.first[0].toUpperCase()
                : 'U',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          chat.participants.join(', '),
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          chat.lastMessage ?? 'No messages yet',
          style: TextStyle(color: Colors.grey[400]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: null, // Chat model doesn't have unreadCount
        selected: isSelected,
        selectedTileColor: Colors.grey[800],
        onTap: _isSelectionMode 
            ? () => _toggleSelection(chat.id ?? '')
            : () => _openChat(chat),
        onLongPress: () {
          HapticFeedback.lightImpact();
          _toggleSelectionMode();
          _toggleSelection(chat.id ?? '');
        },
      ),
    );
  }

  Widget _buildDraftTile(SharedDraft draft) {
    final isSelected = _selectedItems.contains(draft.id);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF9248D2),
          child: const Icon(Icons.drafts, color: Colors.white),
        ),
        title: Text(
          draft.draftTitle,
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          draft.message ?? 'No message',
          style: TextStyle(color: Colors.grey[400]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: draft.status != SharedDraftStatus.viewed
            ? const Icon(Icons.circle, color: Color(0xFF9248D2), size: 8)
            : null,
        selected: isSelected,
        selectedTileColor: Colors.grey[800],
        onTap: _isSelectionMode 
            ? () => _toggleSelection(draft.id)
            : () => _openDraft(draft),
        onLongPress: () {
          HapticFeedback.lightImpact();
          _toggleSelectionMode();
          _toggleSelection(draft.id);
        },
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
          ),
          SizedBox(height: 16),
          Text(
            'Loading inbox...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading inbox',
            style: TextStyle(
              color: Colors.red[400],
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error',
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9248D2),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedItems.clear();
      }
    });
  }

  void _toggleSelection(String itemId) {
    setState(() {
      if (_selectedItems.contains(itemId)) {
        _selectedItems.remove(itemId);
      } else {
        _selectedItems.add(itemId);
      }
    });
  }

  void _createNewMessage() {
    HapticFeedback.lightImpact();
    // TODO: Navigate to new message screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('New message feature coming soon'),
        backgroundColor: Color(0xFF9248D2),
      ),
    );
  }

  void _openChat(app_chat.Chat chat) {
    HapticFeedback.lightImpact();
    
    // Get other user ID
    final currentUser = _inboxService.auth.currentUser;
    if (currentUser == null) return;
    
    final otherUserId = chat.participants.firstWhere(
      (id) => id != currentUser.uid,
      orElse: () => chat.participants.first,
    );
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatViewOptimized(
          chat: chat,
          otherUserId: otherUserId,
          otherUserName: 'User', // TODO: Fetch actual user name
          otherUserAvatarURL: null, // TODO: Fetch actual avatar
          otherUserIsOnline: false, // TODO: Check online status
        ),
      ),
    );
  }

  void _openDraft(SharedDraft draft) {
    HapticFeedback.lightImpact();
    // TODO: Navigate to draft screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Draft feature coming soon'),
        backgroundColor: Color(0xFF9248D2),
      ),
    );
  }
}
