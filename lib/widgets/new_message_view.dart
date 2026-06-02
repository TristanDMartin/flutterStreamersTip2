import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/support_shell_style.dart';
import '../models/chat.dart' as app_chat;
import '../models/user.dart' as app_user;
import '../services/chat_service.dart';
import '../services/inbox_service_optimized.dart';
import '../services/unified_avatar_service.dart';
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
      final List<app_chat.Chat> chats = await _chatService.getUserChats();
      final String? currentUserId = _inboxService.auth.currentUser?.uid;
      final Set<String> blockedUserIds =
          (await _blockingService.getBlockedUsers()).toSet();
      final Map<String, app_user.User> userMap = <String, app_user.User>{};
      final List<app_chat.Chat> visibleChats = <app_chat.Chat>[];

      for (final app_chat.Chat chat in chats) {
        final String otherUserId = chat.participants.firstWhere(
          (String id) => id != currentUserId,
          orElse: () => '',
        );
        if (otherUserId.isEmpty) continue;
        if (blockedUserIds.contains(otherUserId)) continue;

        final app_user.User? profile =
            await _inboxService.getUserProfile(otherUserId);
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

    final String lowerQuery = _searchQuery.toLowerCase();
    return _recentChats.where((app_chat.Chat chat) {
      final String chatId = chat.id ?? '';
      final app_user.User? otherUser = _chatUsers[chatId];
      final String displayName = otherUser?.displayName.toLowerCase() ?? '';
      final String username = otherUser?.username.toLowerCase() ?? '';
      final String lastMessage = (chat.lastMessage ?? '').toLowerCase();
      return displayName.contains(lowerQuery) ||
          username.contains(lowerQuery) ||
          lastMessage.contains(lowerQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: shell.pageGradient,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _buildHeader(context),
              _buildSearchBar(context),
              Divider(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  height: 1),
              _buildPrimaryActions(context),
              Divider(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  height: 1),
              Expanded(child: _buildRecentChats(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final TextTheme tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(
        top: 16,
        left: 8,
        right: 16,
        bottom: 16,
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back_rounded, color: shell.onChrome),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          Expanded(
            child: Text(
              'New Message',
              style: tt.titleLarge?.copyWith(
                color: shell.onChrome,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final TextTheme tt = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color:
            shell.panelSurface.withValues(alpha: shell.isLight ? 0.95 : 0.58),
        border: Border.all(color: shell.panelBorder),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.search_rounded, color: shell.iconDim, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (String value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: tt.bodyMedium?.copyWith(color: shell.onChrome),
              decoration: InputDecoration(
                hintText: 'Search connections...',
                hintStyle: tt.bodyMedium?.copyWith(color: shell.muted),
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
              icon: Icon(Icons.close_rounded, color: shell.iconDim, size: 20),
            ),
        ],
      ),
    );
  }

  Widget _buildPrimaryActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _buildActionCard(
        context,
        icon: Icons.message_rounded,
        title: 'New Message',
        subtitle: 'Start a direct message with a connection',
        onTap: _navigateToChoosePerson,
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final TextTheme tt = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: shell.surfaceCard,
            border: Border.all(color: shell.surfaceCardBorder),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: shell.shadowSoft,
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: shell.heroGradient,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: shell.heroBorder),
                ),
                child: Icon(icon, color: shell.chipSelectedFg, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: tt.titleSmall?.copyWith(
                        color: shell.onChrome,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: tt.bodySmall?.copyWith(color: shell.muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: shell.iconDim, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentChats(BuildContext context) {
    if (_isLoadingRecentChats) {
      return Center(child: _buildStatusCard(context, isLoading: true));
    }

    final List<app_chat.Chat> chats = _filteredRecentChats;
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final TextTheme tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Recent Chats',
            style: tt.titleMedium?.copyWith(
              color: shell.onChrome,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: chats.isEmpty
                ? Center(
                    child: _buildStatusCard(
                      context,
                      isLoading: false,
                      isSearchEmpty: _searchQuery.isEmpty,
                    ),
                  )
                : ListView.separated(
                    itemCount: chats.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (BuildContext _, int index) {
                      final app_chat.Chat chat = chats[index];
                      final app_user.User? otherUser =
                          _chatUsers[chat.id ?? ''];
                      return _buildRecentChatTile(context, chat, otherUser);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context, {
    required bool isLoading,
    bool isSearchEmpty = true,
  }) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    final String title = isLoading
        ? 'Loading recent chats'
        : isSearchEmpty
            ? 'No recent chats yet'
            : 'No chats match your search';
    final String subtitle = isLoading
        ? 'Fetching your conversations…'
        : isSearchEmpty
            ? 'Start a new message and your recent conversations will show up here.'
            : 'Try a different name or username.';
    final IconData icon = isLoading
        ? Icons.forum_outlined
        : isSearchEmpty
            ? Icons.forum_outlined
            : Icons.search_off_rounded;

    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: shell.surfaceCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: shell.surfaceCardBorder),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: shell.shadowSoft,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (isLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: CircularProgressIndicator(color: cs.primary),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Icon(icon, color: shell.iconDim, size: 36),
            ),
          Text(
            title,
            style: tt.titleMedium?.copyWith(
              color: shell.onChrome,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: tt.bodySmall?.copyWith(
              color: shell.muted,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentChatTile(
    BuildContext context,
    app_chat.Chat chat,
    app_user.User? otherUser,
  ) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final TextTheme tt = Theme.of(context).textTheme;
    final String displayName = otherUser?.displayName ?? 'Conversation';
    final String username = otherUser?.username ?? '';
    final String? avatarUrl = otherUser?.avatarURL;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openRecentChat(chat, otherUser),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: shell.surfaceCard,
            border: Border.all(color: shell.surfaceCardBorder),
          ),
          child: Row(
            children: <Widget>[
              _RecentChatAvatar(
                avatarUrl: avatarUrl,
                displayName: displayName,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      displayName,
                      style: tt.titleSmall?.copyWith(
                        color: shell.onChrome,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (username.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        '@$username',
                        style: tt.labelSmall?.copyWith(color: shell.muted),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      (chat.lastMessage ?? '').isEmpty
                          ? 'Start the conversation'
                          : chat.lastMessage!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(color: shell.mutedStrong),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: shell.iconDim),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToChoosePerson() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const ChoosePersonView(),
        fullscreenDialog: true,
      ),
    );
  }

  void _openRecentChat(app_chat.Chat chat, app_user.User? otherUser) {
    final String? currentUserId = _inboxService.auth.currentUser?.uid;
    final String otherUserId = chat.participants.firstWhere(
      (String id) => id != currentUserId,
      orElse: () => '',
    );

    if (otherUserId.isEmpty) {
      final ColorScheme cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: cs.errorContainer,
          content: Text(
            'Unable to open this conversation',
            style: TextStyle(color: cs.onErrorContainer),
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ChatViewOptimized(
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

class _RecentChatAvatar extends StatelessWidget {
  const _RecentChatAvatar({
    required this.avatarUrl,
    required this.displayName,
  });

  final String? avatarUrl;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final bool hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    final String initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'C';
    final StSupportShellStyle shell = StSupportShellStyle.of(context);

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasAvatar
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: shell.heroGradient,
              ),
        border: hasAvatar ? null : Border.all(color: shell.heroBorder),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: shell.shadowSoft,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: hasAvatar
            ? UnifiedAvatarService().getAvatar(
                imageUrl: avatarUrl!,
                radius: 24,
                useProfileViewStyling: false,
                showLoadingIndicator: false,
                errorWidget: _RecentChatAvatarFallback(initial: initial),
              )
            : _RecentChatAvatarFallback(initial: initial),
      ),
    );
  }
}

class _RecentChatAvatarFallback extends StatelessWidget {
  const _RecentChatAvatarFallback({
    required this.initial,
  });

  final String initial;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: shell.chipSelectedFg,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
