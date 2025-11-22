import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:giphy_picker/giphy_picker.dart'; // cspell:ignore giphy
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'dart:async';
import '../models/chat.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../providers/unread_messages_provider.dart';
import '../config/giphy_config.dart'; // cspell:ignore giphy
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/report_service.dart';
import '../services/user_blocking_service.dart';
import '../services/notification_navigation_service.dart';
import '../providers/home_provider.dart' as hp;

// Provider for ChatNotifier
final chatNotifierProvider =
    StateNotifierProvider.family<ChatNotifier, ChatState, Chat>((ref, chat) {
  return ChatNotifier(chat, ref.read(authServiceProvider));
});

class ChatView extends ConsumerStatefulWidget {
  final Chat chat;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatarURL;
  final bool otherUserIsOnline;
  final Map<String, dynamic>? draftToSend;

  const ChatView({
    super.key,
    required this.chat,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatarURL,
    required this.otherUserIsOnline,
    this.draftToSend,
  });

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  bool _isPickingGif = false;
  String _otherUserId = '';
  String _otherUserDisplayName = '';
  String _otherUserUsername = '';
  String? _otherUserAvatarURL;
  String? _currentUserAvatarURL;
  String _currentUserDisplayName = '';
  bool _otherUserIsOnline = false;
  bool _isMuted = false;

  // Add stream subscription for user data
  StreamSubscription<DocumentSnapshot>? _otherUserSubscription;
  StreamSubscription<DocumentSnapshot>? _currentUserSubscription;

  // Keyboard visibility tracking
  bool _isKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadOtherUserData();
    _checkMuteStatus();

    // Handle draft to send if provided
    if (widget.draftToSend != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleDraftToSend(widget.draftToSend!);
      });
    }

    // Mark messages as read when chat is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.chat.id != null) {
        UnreadMessagesService.markChatAsRead(widget.chat.id!);
      }
    });

    // Listen to keyboard changes to auto-scroll - multiple attempts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToBottom();
      }
    });

    // Additional scroll attempts to ensure we reach the bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _scrollToBottom();
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _scrollToBottom();
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _scrollToBottom();
    });

    // Listen for shared content from keyboards
    _listenForSharedContent();
  }

  // Track previous message count for efficient auto-scroll
  int _previousMessageCount = 0;

  void _checkForNewMessages(int currentMessageCount) {
    if (currentMessageCount > _previousMessageCount) {
      // New messages arrived, scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToBottom();
        }
      });
    }
    _previousMessageCount = currentMessageCount;
  }

  /// Check if the current user has muted this chat
  void _checkMuteStatus() {
    final currentUserId = fa.FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null && widget.chat.mutedBy.contains(currentUserId)) {
      _isMuted = true;
    } else {
      _isMuted = false;
    }
  }

  void _listenForSharedContent() {
    // This would typically be handled by a plugin like share_plus
    // For now, we'll add a listener for when the app receives shared content
    try {
      // Listen for shared images/GIFs from keyboard
      // This is a placeholder - in a real implementation, you'd use a plugin
      // like share_plus or receive_sharing_intent to handle this
      debugPrint('ChatView: Listening for shared content from keyboard');
    } catch (e) {
      debugPrint('ChatView: Error setting up shared content listener: $e');
    }
  }

  void _handleDraftToSend(Map<String, dynamic> draft) {
    // Show a dialog to confirm sending the draft
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Send Draft Video?',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Caption: ${draft['caption']?.isNotEmpty == true ? draft['caption'] : 'Untitled Draft'}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            if (draft['hashtags'] != null &&
                (draft['hashtags'] as List).isNotEmpty)
              Text(
                'Hashtags: ${(draft['hashtags'] as List).join(' ')}',
                style: const TextStyle(color: Color(0xFF9248D2), fontSize: 14),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _sendDraftVideo(draft);
            },
            child:
                const Text('Send', style: TextStyle(color: Color(0xFF9248D2))),
          ),
        ],
      ),
    );
  }

  void _sendDraftVideo(Map<String, dynamic> draft) async {
    try {
      final videoPath = draft['videoPath'] as String?;
      if (videoPath == null || videoPath.isEmpty) {
        _showErrorSnackBar('Draft video file not found');
        return;
      }

      final videoFile = File(videoPath);
      if (!videoFile.existsSync()) {
        _showErrorSnackBar('Draft video file is missing');
        return;
      }

      // Create a temporary message with the draft caption
      final caption = draft['caption']?.isNotEmpty == true
          ? draft['caption']
          : 'Untitled Draft';

      // For now, we'll send the caption as a text message
      // In a full implementation, you'd upload the video file and send the video URL
      // We'll use the existing send method by setting the text in the input field
      _textController.text = caption;

      // Trigger the send action
      final chatNotifier = ref.read(chatProvider(widget.chat).notifier);
      await chatNotifier.send();

      _showSuccessSnackBar('Draft sent successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to send draft: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF9248D2),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _scrollToBottom({bool smooth = true}) {
    if (_scrollController.hasClients) {
      // Add extra padding to ensure we scroll past the keyboard
      final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
      final extraPadding =
          keyboardHeight > 0 ? 200.0 : 100.0; // Even more aggressive padding

      // Wait for the layout to complete before scrolling
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          // Force scroll to absolute maximum
          final maxScrollExtent = _scrollController.position.maxScrollExtent;
          final targetPosition = maxScrollExtent + extraPadding;

          if (smooth) {
            _scrollController.animateTo(
              targetPosition,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          } else {
            _scrollController.jumpTo(targetPosition);
          }

          debugPrint(
              'ChatView: Scrolled to bottom - keyboard: ${keyboardHeight}px, extra: ${extraPadding}px, maxScroll: ${maxScrollExtent}px, target: ${targetPosition}px');
        }
      });
    }
  }

  void _loadOtherUserData() {
    final currentUser = fa.FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      // Use the provided otherUserId instead of deriving it
      _otherUserId = widget.otherUserId;

      // Load current user's data with proper subscription management
      _currentUserSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && mounted) {
          final data = snapshot.data()!;
          debugPrint(
              'ChatView: Loading current user data - displayName: ${data['displayName']}, avatarURL: ${data['avatarURL']}');
          setState(() {
            _currentUserDisplayName = data['displayName'] ?? 'You';
            _currentUserAvatarURL = data['avatarURL'];
          });
        }
      }, onError: (error) {
        debugPrint('ChatView: Error loading current user data: $error');
      });

      // Listen to other user's data with proper subscription management
      _otherUserSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(_otherUserId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && mounted) {
          final data = snapshot.data()!;
          setState(() {
            _otherUserDisplayName = data['displayName'] ?? 'User';
            _otherUserUsername = data['username'] ?? 'user';
            _otherUserAvatarURL = data['avatarURL'];
            _otherUserIsOnline = data['onlineStatus'] == 'online';
          });
        }
      }, onError: (error) {
        debugPrint('ChatView: Error loading other user data: $error');
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _textController.dispose();
    _otherUserSubscription?.cancel();
    _currentUserSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Handle keyboard visibility changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        final isKeyboardVisible = keyboardHeight > 0;

        if (_isKeyboardVisible != isKeyboardVisible) {
          setState(() {
            _isKeyboardVisible = isKeyboardVisible;
          });

          // Scroll to bottom when keyboard appears/disappears
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              _scrollToBottom();
            }
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () {
          // Hide keyboard when tapping on the screen
          FocusScope.of(context).unfocus();
        },
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
            ),
          ),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildMessagesList()),
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  // Header
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      child: Row(
        children: [
          // Back arrow
          GestureDetector(
            onTap: () {
              debugPrint('ChatView: Back button tapped');
              try {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  debugPrint('ChatView: Cannot pop, using system back');
                  SystemNavigator.pop();
                }
              } catch (e) {
                debugPrint('ChatView: Navigation error: $e');
                // Fallback to system navigation
                SystemNavigator.pop();
              }
            },
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 24,
            ),
          ),

          const SizedBox(width: 16),

          // Avatar with online indicator + Display name + Username
          Expanded(
            child: Row(
              children: [
                // Avatar with online indicator
                Stack(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                      child: ClipOval(
                        child: _otherUserAvatarURL != null &&
                                _otherUserAvatarURL!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: _otherUserAvatarURL!,
                                fit: BoxFit.cover,
                                width: 40,
                                height: 40,
                                placeholder: (context, url) =>
                                    _buildDefaultAvatar(),
                                errorWidget: (context, url, error) {
                                  debugPrint(
                                      'ChatView: Error loading other user avatar: $error');
                                  return _buildDefaultAvatar();
                                },
                              )
                            : _buildDefaultAvatar(),
                      ),
                    ),
                    // Online indicator dot
                    if (_otherUserIsOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D4AA),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 12),

                // Display name and username
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _otherUserDisplayName.isNotEmpty
                            ? _otherUserDisplayName
                            : 'User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '@${_otherUserUsername.isNotEmpty ? _otherUserUsername : 'user'}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Mute icon (if user is muted)
          if (_isMuted) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.volume_off,
                color: Colors.red,
                size: 16,
              ),
            ),
          ],

          const SizedBox(width: 8),

          // Info icon
          GestureDetector(
            onTap: () => _showChatSettings(),
            child: const Icon(
              Icons.more_horiz,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF9248D2).withValues(alpha: 0.8),
            const Color(0xFF7B2CBF).withValues(alpha: 0.8),
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          _otherUserDisplayName.isNotEmpty
              ? _otherUserDisplayName[0].toUpperCase()
              : 'U',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showChatSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              _buildSettingsOption(
                  _isMuted ? Icons.volume_up : Icons.volume_off,
                  _isMuted ? 'Unmute' : 'Mute',
                  () => _handleMuteUser()),
              _buildSettingsOption(
                  Icons.flag, 'Report', () => _handleReportUser()),
              _buildSettingsOption(
                  Icons.block, 'Block', () => _handleBlockUser()),
              const SizedBox(height: 20),
              // Add extra padding at the bottom to ensure content is not cut off
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsOption(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  /// Handle mute user functionality
  Future<void> _handleMuteUser() async {
    try {
      final currentUserId = fa.FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      final chatService = ChatService.shared;

      if (_isMuted) {
        // Unmute the user
        await chatService.unmuteChat(widget.chat.id!, currentUserId);
        setState(() {
          _isMuted = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${_otherUserDisplayName.isNotEmpty ? _otherUserDisplayName : 'User'} has been unmuted'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Mute the user
        await chatService.muteChat(widget.chat.id!, currentUserId);
        setState(() {
          _isMuted = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${_otherUserDisplayName.isNotEmpty ? _otherUserDisplayName : 'User'} has been muted'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error toggling mute status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${_isMuted ? 'unmute' : 'mute'} user: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Handle report user functionality
  Future<void> _handleReportUser() async {
    try {
      final currentUserId = fa.FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      // Show reason selection dialog
      final reason = await _showReportReasonDialog();
      if (reason == null) return; // User cancelled

      final reportService = ReportService();
      await reportService.reportUser(
        userId: _otherUserId,
        reason: reason,
        additionalDetails: 'Reported from chat view',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_otherUserDisplayName.isNotEmpty ? _otherUserDisplayName : 'User'} has been reported'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error reporting user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to report user: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Handle block user functionality
  Future<void> _handleBlockUser() async {
    try {
      final currentUserId = fa.FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      // Show confirmation dialog
      final confirmed = await _showBlockConfirmationDialog();
      if (!confirmed) return;

      final blockingService = UserBlockingService();
      await blockingService.blockUser(
        targetUserId: _otherUserId,
        reason: 'Blocked from chat view',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_otherUserDisplayName.isNotEmpty ? _otherUserDisplayName : 'User'} has been blocked'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate back to inbox after blocking
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error blocking user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to block user: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Show report reason selection dialog
  Future<String?> _showReportReasonDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Report User',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Why are you reporting this user?',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ...['Spam', 'Harassment', 'Inappropriate Content', 'Other'].map(
              (reason) => ListTile(
                title:
                    Text(reason, style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context, reason),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  /// Show block confirmation dialog
  Future<bool> _showBlockConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Block User',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to block ${_otherUserDisplayName.isNotEmpty ? _otherUserDisplayName : 'this user'}? You won\'t be able to see their messages or interact with them.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // Message List
  Widget _buildMessagesList() {
    return Consumer(
      builder: (context, ref, child) {
        final chatNotifier =
            ref.watch(chatNotifierProvider(widget.chat).notifier);
        final chatState = ref.watch(chatNotifierProvider(widget.chat));

        if (chatState.isLoading) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
        }

        if (chatState.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Unable to load messages. Please check your connection and try again.',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Retry by invalidating the provider
                    ref.invalidate(chatNotifierProvider(widget.chat));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9248D2),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (chatState.messages.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    color: Colors.white70, size: 48),
                SizedBox(height: 16),
                Text(
                  'No messages yet',
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),
                SizedBox(height: 8),
                Text(
                  'Start the conversation!',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          );
        }

        // Efficient auto-scroll only when new messages arrive
        _checkForNewMessages(chatState.messages.length);

        return GestureDetector(
          onTap: () {
            // Hide keyboard when tapping on messages area
            FocusScope.of(context).unfocus();
          },
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 20,
              bottom: 20 +
                  MediaQuery.of(context)
                      .viewInsets
                      .bottom, // Add keyboard height to bottom padding
            ),
            itemCount: chatState.messages.length,
            itemBuilder: (context, index) {
              final message = chatState.messages[index];
              final isFromCurrentUser = chatNotifier.isFromCurrentUser(message);

              return _buildMessageBubble(message, isFromCurrentUser,
                  chatState.messages, index, chatNotifier);
            },
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(Message message, bool isFromCurrentUser,
      List<Message> messages, int index, ChatNotifier chatNotifier) {
    final showAvatar = _shouldShowAvatar(messages, index, chatNotifier);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isFromCurrentUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: isFromCurrentUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              // For incoming messages (left side)
              if (!isFromCurrentUser) ...[
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 8),
                  child: showAvatar
                      ? ClipOval(
                          child: _otherUserAvatarURL != null &&
                                  _otherUserAvatarURL!.isNotEmpty
                              ? Image.network(
                                  _otherUserAvatarURL!,
                                  fit: BoxFit.cover,
                                  width: 32,
                                  height: 32,
                                  errorBuilder: (context, error, stackTrace) {
                                    debugPrint(
                                        'ChatView: Error loading other user small avatar: $error');
                                    return _buildSmallAvatar(
                                        _otherUserDisplayName);
                                  },
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return _buildSmallAvatar(
                                        _otherUserDisplayName);
                                  },
                                )
                              : _buildSmallAvatar(_otherUserDisplayName),
                        )
                      : const SizedBox(width: 32),
                ),
                // Message bubble for incoming
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.15),
                          Colors.white.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(24),
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: message.messageType == 'video_share' &&
                            message.videoId != null
                        ? _buildVideoShareMessage(message)
                        : message.messageType == 'gif' && message.gifUrl != null
                            ? Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      message.gifUrl!,
                                      fit: BoxFit.cover,
                                      width: 200,
                                      height: 150,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          width: 200,
                                          height: 150,
                                          color: Colors.grey
                                              .withValues(alpha: 0.3),
                                          child: const Center(
                                            child: Text(
                                              'GIF',
                                              style: TextStyle(
                                                  color: Colors.white),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  // Device GIF indicator
                                  if (message.isDeviceGif)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF9248D2),
                                              Color(0xFF7B2CBF)
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.phone_android,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            : Text(
                                message.text,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                                softWrap: true,
                                overflow: TextOverflow.visible,
                                textAlign: TextAlign.start,
                              ),
                  ),
                ),
              ],

              // For outgoing messages (right side)
              if (isFromCurrentUser) ...[
                // Spacer to push message to the right
                const Spacer(),
                // Message bubble for outgoing
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
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
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(8),
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF9248D2).withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: const Color(0xFF1670DE).withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: message.messageType == 'video_share' &&
                          message.videoId != null
                      ? _buildVideoShareMessage(message)
                      : message.messageType == 'gif' && message.gifUrl != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    message.gifUrl!,
                                    fit: BoxFit.cover,
                                    width: 200,
                                    height: 150,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 200,
                                        height: 150,
                                        color:
                                            Colors.grey.withValues(alpha: 0.3),
                                        child: const Center(
                                          child: Text(
                                            'GIF',
                                            style:
                                                TextStyle(color: Colors.white),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                // Device GIF indicator
                                if (message.isDeviceGif)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF9248D2),
                                            Color(0xFF7B2CBF)
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.phone_android,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          : Text(
                              message.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                              softWrap: true,
                              overflow: TextOverflow.visible,
                              textAlign: TextAlign.start,
                            ),
                ),
                // Avatar for outgoing messages
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(left: 8),
                  child: showAvatar
                      ? ClipOval(
                          child: _currentUserAvatarURL != null &&
                                  _currentUserAvatarURL!.isNotEmpty
                              ? Image.network(
                                  _currentUserAvatarURL!,
                                  fit: BoxFit.cover,
                                  width: 32,
                                  height: 32,
                                  errorBuilder: (context, error, stackTrace) {
                                    debugPrint(
                                        'ChatView: Error loading current user avatar: $error');
                                    return _buildSmallAvatar(
                                        _currentUserDisplayName);
                                  },
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return _buildSmallAvatar(
                                        _currentUserDisplayName);
                                  },
                                )
                              : _buildSmallAvatar(_currentUserDisplayName),
                        )
                      : const SizedBox(width: 32),
                ),
              ],
            ],
          ),

          // Timestamp and status
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: isFromCurrentUser
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                Text(
                  _formatTimestamp(message.timestamp),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
                if (isFromCurrentUser) ...[
                  const SizedBox(width: 4),
                  _buildMessageStatus(message),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallAvatar(String? displayName) {
    final name = displayName ?? 'User';
    debugPrint('ChatView: Building small avatar for name: $name');
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF9248D2).withValues(alpha: 0.8),
            const Color(0xFF7B2CBF).withValues(alpha: 0.8),
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9248D2).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return 'Just now';

    final hour = timestamp.hour;
    final minute = timestamp.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  Widget _buildMessageStatus(Message message) {
    // For now, we'll show a simple sent indicator
    // In a real app, you'd check readBy array and recipients
    final isRead = message.readBy.length > 1; // More than just the sender

    return Icon(
      isRead ? Icons.done_all : Icons.done,
      size: 12,
      color: isRead
          ? const Color(0xFF00D4AA)
          : Colors.white.withValues(alpha: 0.6),
    );
  }

  bool _shouldShowAvatar(
      List<Message> messages, int index, ChatNotifier chatNotifier) {
    // Always show avatar with every message
    return true;
  }

  // Input Bar
  Widget _buildInputBar() {
    return Consumer(
      builder: (context, ref, child) {
        final chatNotifier =
            ref.watch(chatNotifierProvider(widget.chat).notifier);
        final chatState = ref.watch(chatNotifierProvider(widget.chat));

        return Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Text field
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 40,
                    maxHeight: 120,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: TextFormField(
                    controller: _textController,
                    onChanged: (value) {
                      chatNotifier.updateComposedText(value);
                    },
                    onTap: () {
                      // Scroll to bottom when user taps to type - multiple attempts
                      Future.delayed(const Duration(milliseconds: 50), () {
                        _scrollToBottom();
                      });
                      Future.delayed(const Duration(milliseconds: 200), () {
                        _scrollToBottom();
                      });
                      Future.delayed(const Duration(milliseconds: 500), () {
                        _scrollToBottom();
                      });
                      Future.delayed(const Duration(milliseconds: 800), () {
                        _scrollToBottom();
                      });
                    },
                    onFieldSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        chatNotifier.send();
                        _textController.clear();
                        // Ensure we scroll to bottom after sending - multiple attempts
                        Future.delayed(const Duration(milliseconds: 50), () {
                          _scrollToBottom();
                        });
                        Future.delayed(const Duration(milliseconds: 200), () {
                          _scrollToBottom();
                        });
                        Future.delayed(const Duration(milliseconds: 500), () {
                          _scrollToBottom();
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      hintText: 'Message…',
                      hintStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    enableSuggestions: true,
                    autocorrect: true,
                    // Enable keyboard GIF and image support
                    enableInteractiveSelection: true,
                    // Allow rich content from keyboard
                    enableIMEPersonalizedLearning: true,
                    smartDashesType: SmartDashesType.enabled,
                    smartQuotesType: SmartQuotesType.enabled,
                    // Allow all input types - remove any restrictions
                    readOnly: false,
                    // Enable all content types
                    buildCounter: null,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Action buttons row
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Test message button (temporary for demonstration)
                  GestureDetector(
                    onTap: () => _sendTestMessage(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.text_fields,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // GIF picker button
                  GestureDetector(
                    onTap: _isPickingGif ? null : () => _showGiphyPicker(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: _isPickingGif
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(
                              Icons.gif_box_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Send button
                  if (chatState.composedText.trim().isNotEmpty ||
                      chatState.isLoading)
                    GestureDetector(
                      onTap: chatState.isLoading
                          ? null
                          : () {
                              chatNotifier.send();
                              _textController.clear();
                            },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: chatState.isLoading
                              ? LinearGradient(
                                  colors: [
                                    Colors.grey.withValues(alpha: 0.6),
                                    Colors.grey.withValues(alpha: 0.4),
                                  ],
                                )
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFF9248D2),
                                    Color(0xFF7768DF),
                                    Color(0xFF1670DE),
                                    Color(0xFF3C8BD6),
                                    Color(0xFF4897D2),
                                  ],
                                ),
                          shape: BoxShape.circle,
                        ),
                        child: chatState.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _sendTestMessage() async {
    // Send a test message to demonstrate text wrapping
    final testMessage =
        "This is a very long test message to demonstrate that the text wrapping is working correctly in the message bubbles. The text should now wrap properly within the bubble instead of being compressed or squished. This message contains multiple sentences and should show how the text flows naturally within the message bubble container. The ConstrainedBox and proper text alignment should ensure that long messages display beautifully just like the other user's messages.";

    final chatNotifier = ref.read(chatNotifierProvider(widget.chat).notifier);

    // Set the composed text and send
    chatNotifier.updateComposedText(testMessage);
    await chatNotifier.send();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Test message sent to demonstrate text wrapping!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _showGiphyPicker() async {
    // cspell:ignore Giphy
    if (_isPickingGif) return; // Prevent multiple simultaneous picks

    setState(() {
      _isPickingGif = true;
    });

    try {
      debugPrint(
          'ChatView: Opening Giphy picker with API key: ${GiphyConfig.bestApiKey}');

      // Show immediate feedback that picker is opening
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎬 Opening GIF picker...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Try a simpler configuration first
      final gif = await GiphyPicker.pickGif(
        // cspell:ignore Giphy
        context: context,
        apiKey: GiphyConfig.bestApiKey, // cspell:ignore Giphy
        fullScreenDialog: false, // Try without full screen
        previewType: GiphyPreviewType.previewWebp, // cspell:ignore Giphy Webp
        showGiphyAttribution: false, // Try without attribution
        showPreviewPage: false, // Try without preview page
      );

      debugPrint(
          'ChatView: Giphy picker returned: ${gif?.id ?? "No GIF selected"}');
      debugPrint('ChatView: Complete GIF object: $gif');

      if (gif != null && mounted) {
        debugPrint('ChatView: GIF images object: ${gif.images}');
        debugPrint('ChatView: Original URL: ${gif.images.original?.url}');
        debugPrint(
            'ChatView: Fixed height URL: ${gif.images.fixedHeight?.url}');
        debugPrint('ChatView: Downsized URL: ${gif.images.downsized?.url}');
        debugPrint('ChatView: Fixed width URL: ${gif.images.fixedWidth?.url}');
        // Try multiple URL sources for better compatibility
        final gifUrl = gif.images.original?.url ??
            gif.images.fixedHeight?.url ??
            gif.images.fixedWidth?.url ??
            gif.images.downsized?.url ??
            '';

        debugPrint('ChatView: Final GIF URL: $gifUrl');

        if (gifUrl.isNotEmpty) {
          // Show loading feedback immediately
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('📤 Sending GIF...'),
                backgroundColor: Colors.blue,
                duration: Duration(seconds: 1),
              ),
            );
          }

          // Send the GIF using the chat notifier
          await ref
              .read(chatNotifierProvider(widget.chat).notifier)
              .sendGif(gifUrl);

          debugPrint('ChatView: GIF message sent successfully');

          // Show success feedback
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ GIF sent!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          debugPrint('ChatView: No valid GIF URL found');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Could not load GIF. Please try another one.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        debugPrint('ChatView: User cancelled GIF selection or GIF is null');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('GIF selection cancelled'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('ChatView: Error in Giphy picker: $e');

      // Check if it's a 403/API key error
      if (e.toString().contains('403') ||
          e.toString().contains('banned') ||
          e.toString().contains('Forbidden')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '🚫 GIF service temporarily unavailable. Please try again later.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error loading GIFs: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () {
                  _showGiphyPicker();
                },
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingGif = false;
        });
      }
    }
  }

  Widget _buildVideoShareMessage(Message message) {
    debugPrint(
        '🎬 ChatView: Building video share message - videoId: ${message.videoId}, title: "${message.videoTitle}", thumbnail: "${message.videoThumbnailUrl}"');

    return GestureDetector(
      onTap: () {
        _navigateToVideo(message.videoId!);
      },
      child: Container(
        width: 240,
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Video thumbnail background
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.purple.withValues(alpha: 0.8),
                      Colors.blue.withValues(alpha: 0.8),
                      Colors.pink.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: message.videoThumbnailUrl != null &&
                        message.videoThumbnailUrl!.isNotEmpty
                    ? Image.network(
                        message.videoThumbnailUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildGradientBackground();
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return _buildGradientBackground();
                        },
                      )
                    : _buildGradientBackground(),
              ),

              // Dark overlay for better text visibility
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),

              // Play button overlay
              Center(
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.black,
                    size: 35,
                  ),
                ),
              ),

              // Video info at bottom
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Video title
                    Text(
                      message.videoTitle ?? 'Shared a video',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Duration or share indicator
                    Row(
                      children: [
                        Icon(
                          Icons.play_circle_outline,
                          color: Colors.white.withValues(alpha: 0.8),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Tap to watch',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            shadows: const [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // TikTok-style corner indicator
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.videocam,
                        color: Colors.white,
                        size: 12,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'VIDEO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
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

  Widget _buildGradientBackground() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.withValues(alpha: 0.8),
            Colors.blue.withValues(alpha: 0.8),
            Colors.pink.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.videocam,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }

  /// Navigate to video player using NotificationNavigationService
  void _navigateToVideo(String videoId) {
    try {
      debugPrint('🎬 ChatView: Navigating to video: $videoId');

      final navigationService = NotificationNavigationService();
      final homeViewModel = ref.read(hp.homeProvider.notifier);

      // Get available videos from home provider
      final homeState = ref.read(hp.homeProvider);
      final availableVideos = [
        ...homeState.forYouVideos,
        ...homeState.followingVideos
      ];

      navigationService.navigateToVideo(
        context: context,
        videoId: videoId,
        homeViewModel: homeViewModel,
        availableVideos: availableVideos,
      );
    } catch (e) {
      debugPrint('❌ ChatView: Error navigating to video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open video: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

class EmojiViewConfig {}
