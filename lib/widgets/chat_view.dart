import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:giphy_picker/giphy_picker.dart'; // cspell:ignore giphy
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/chat.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../providers/unread_messages_provider.dart';
import '../config/giphy_config.dart'; // cspell:ignore giphy

// Provider for ChatNotifier
final chatNotifierProvider = StateNotifierProvider.family<ChatNotifier, ChatState, Chat>((ref, chat) {
  return ChatNotifier(chat, Object());
});

class ChatView extends ConsumerStatefulWidget {
  final Chat chat;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatarURL;
  final bool otherUserIsOnline;

  const ChatView({
    super.key,
    required this.chat,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatarURL,
    required this.otherUserIsOnline,
  });

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  String _otherUserId = '';
  String _otherUserDisplayName = '';
  String? _otherUserAvatarURL;
  String? _currentUserAvatarURL;
  String _currentUserDisplayName = '';
  bool _otherUserIsOnline = false;

  @override
  void initState() {
    super.initState();
    _loadOtherUserData();
    // Mark messages as read when chat is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.chat.id != null) {
        UnreadMessagesService.markChatAsRead(widget.chat.id!);
      }
    });
  }

  void _loadOtherUserData() {
    final currentUser = fa.FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      // Use the provided otherUserId instead of deriving it
      _otherUserId = widget.otherUserId;
      
      // Load current user's data
      FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get()
          .then((snapshot) {
        if (snapshot.exists && mounted) {
          final data = snapshot.data()!;
          debugPrint('ChatView: Loading current user data - displayName: ${data['displayName']}, avatarURL: ${data['avatarURL']}');
          setState(() {
            _currentUserDisplayName = data['displayName'] ?? 'You';
            _currentUserAvatarURL = data['avatarURL'];
          });
        }
      }).catchError((error) {
        debugPrint('ChatView: Error loading current user data: $error');
      });
      
      // Listen to other user's data
      FirebaseFirestore.instance
          .collection('users')
          .doc(_otherUserId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && mounted) {
          final data = snapshot.data()!;
          setState(() {
            _otherUserDisplayName = data['displayName'] ?? 'User';
            _otherUserAvatarURL = data['avatarURL'];
            _otherUserIsOnline = data['onlineStatus'] == 'online';
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildMessagesList()),
          _buildInputBar(),
        ],
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
            onTap: () => Navigator.of(context).pop(),
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
                        child: _otherUserAvatarURL != null
                            ? Image.network(
                                _otherUserAvatarURL!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
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
                        _otherUserDisplayName.isNotEmpty ? _otherUserDisplayName : 'User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '@${_otherUserId.isNotEmpty ? _otherUserId.substring(0, 8) : 'user'}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha:0.6),
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
      color: Colors.grey.withValues(alpha:0.3),
      child: Center(
        child: Text(
          _otherUserDisplayName.isNotEmpty ? _otherUserDisplayName[0].toUpperCase() : 'U',
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
      builder: (context) => Container(
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
                color: Colors.white.withValues(alpha:0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _buildSettingsOption(Icons.volume_off, 'Mute', () {}),
            _buildSettingsOption(Icons.flag, 'Report', () {}),
            _buildSettingsOption(Icons.block, 'Block', () {}),
            const SizedBox(height: 20),
          ],
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

  // Message List
  Widget _buildMessagesList() {
    return Consumer(
      builder: (context, ref, child) {
        final chatNotifier = ref.watch(chatNotifierProvider(widget.chat).notifier);
        final chatState = ref.watch(chatNotifierProvider(widget.chat));
        
        if (chatState.isLoading) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }
        
        if (chatState.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error: ${chatState.error}',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
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
                Icon(Icons.chat_bubble_outline, color: Colors.white70, size: 48),
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
        
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: chatState.messages.length,
          itemBuilder: (context, index) {
            final message = chatState.messages[index];
            final isFromCurrentUser = chatNotifier.isFromCurrentUser(message);
            
            return _buildMessageBubble(message, isFromCurrentUser, chatState.messages, index, chatNotifier);
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(Message message, bool isFromCurrentUser, List<Message> messages, int index, ChatNotifier chatNotifier) {
    final showAvatar = _shouldShowAvatar(messages, index, chatNotifier);
    debugPrint('ChatView: Building message bubble - isFromCurrentUser: $isFromCurrentUser, showAvatar: $showAvatar, currentUserDisplayName: $_currentUserDisplayName, currentUserAvatarURL: $_currentUserAvatarURL');
    
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(
            opacity: value,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: isFromCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: isFromCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
              // For incoming messages (left side)
              if (!isFromCurrentUser) ...[
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 8),
                  child: showAvatar
                      ? ClipOval(
                          child: _otherUserAvatarURL != null
                              ? Image.network(
                                  _otherUserAvatarURL!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildSmallAvatar(_otherUserDisplayName);
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha:0.15),
                          Colors.white.withValues(alpha:0.05),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(24),
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha:0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha:0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: message.messageType == 'gif' && message.gifUrl != null
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
                                  color: Colors.grey.withValues(alpha:0.3),
                                  child: const Center(
                                    child: Text(
                                      'GIF',
                                      style: TextStyle(color: Colors.white),
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
                                        colors: [Color(0xFF9248D2), Color(0xFF7B2CBF)],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha:0.3),
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
                          ),
                  ),
                ),
              ],
              
              // For outgoing messages (right side)
              if (isFromCurrentUser) ...[
                const Spacer(),
                // Message bubble for outgoing
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              color: Colors.white.withValues(alpha:0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9248D2).withValues(alpha:0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: const Color(0xFF1670DE).withValues(alpha:0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
                    child: message.messageType == 'gif' && message.gifUrl != null
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
                                  color: Colors.grey.withValues(alpha:0.3),
                                  child: const Center(
                                    child: Text(
                                      'GIF',
                                      style: TextStyle(color: Colors.white),
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
                                        colors: [Color(0xFF9248D2), Color(0xFF7B2CBF)],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha:0.3),
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
                          ),
                  ),
                ),
                // Avatar for outgoing messages
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(left: 8),
                  child: showAvatar
                      ? ClipOval(
                          child: _currentUserAvatarURL != null
                              ? Image.network(
                                  _currentUserAvatarURL!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildSmallAvatar(_currentUserDisplayName);
                                  },
                                )
                              : _buildSmallAvatar(_currentUserDisplayName),
                        )
                      : const SizedBox(width: 32),
                ),
              ],
            ],
          ),
          
                  // Timestamp
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _formatTimestamp(message.timestamp),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha:0.6),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
            const Color(0xFF9248D2).withValues(alpha:0.8),
            const Color(0xFF7B2CBF).withValues(alpha:0.8),
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha:0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9248D2).withValues(alpha:0.3),
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

  String _formatTimestamp(DateTime timestamp) {
    final hour = timestamp.hour;
    final minute = timestamp.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  bool _shouldShowAvatar(List<Message> messages, int index, ChatNotifier chatNotifier) {
    if (index == 0) return true;
    
    final currentMessage = messages[index];
    final previousMessage = messages[index - 1];
    
    // Show avatar if the previous message is from a different user
    // or if there's a time gap of more than 5 minutes
    return chatNotifier.isFromCurrentUser(currentMessage) != chatNotifier.isFromCurrentUser(previousMessage) ||
           currentMessage.timestamp.difference(previousMessage.timestamp).inMinutes > 5;
  }

  // Input Bar
  Widget _buildInputBar() {
    return Consumer(
      builder: (context, ref, child) {
        final chatNotifier = ref.watch(chatNotifierProvider(widget.chat).notifier);
        final chatState = ref.watch(chatNotifierProvider(widget.chat));
        
        return Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 12,
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
                    color: Colors.white.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.white.withValues(alpha:0.2),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _textController,
                    onChanged: (value) {
                      chatNotifier.updateComposedText(value);
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
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Action buttons row
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // GIF picker button
                  GestureDetector(
                    onTap: () => _showGifOptions(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha:0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.gif_box_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Send button
                  if (chatState.composedText.trim().isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        chatNotifier.send();
                        _textController.clear();
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
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
                        child: const Icon(
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



  void _showGifOptions() {
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
                  color: Colors.white.withValues(alpha:0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Choose GIF Source',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildGifOption(
                icon: Icons.gif_box_outlined,
                title: 'Giphy GIFs', // cspell:ignore Giphy
                subtitle: 'Browse trending GIFs online',
                onTap: () {
                  Navigator.pop(context);
                  _showGiphyPicker(); // cspell:ignore Giphy
                },
              ),
              _buildGifOption(
                icon: Icons.photo_library_outlined,
                title: 'Device GIFs',
                subtitle: 'Use GIFs from your gallery',
                onTap: () {
                  Navigator.pop(context);
                  _pickDeviceGif();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGifOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha:0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.white.withValues(alpha:0.7),
          fontSize: 14,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showGiphyPicker() async { // cspell:ignore Giphy
    try {
      debugPrint('ChatView: Opening Giphy picker with API key: ${GiphyConfig.apiKey}');
      
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening Giphy...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 1),
          ),
        );
      }
      
      final gif = await GiphyPicker.pickGif( // cspell:ignore Giphy
        context: context,
        apiKey: GiphyConfig.apiKey, // cspell:ignore Giphy
        fullScreenDialog: false,
        previewType: GiphyPreviewType.previewWebp, // cspell:ignore Giphy Webp
      );

      debugPrint('ChatView: Giphy picker returned: ${gif != null ? "GIF selected" : "No GIF selected"}');
      
      if (gif != null && mounted) {
        debugPrint('ChatView: GIF details - title: ${gif.title}, URL: ${gif.images.original?.url}');
        
        final gifUrl = gif.images.original?.url ?? '';
        if (gifUrl.isNotEmpty) {
          final chatNotifier = ref.read(chatNotifierProvider(widget.chat).notifier);
          await chatNotifier.sendGif(gifUrl);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('GIF sent successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to get GIF URL. Please try again.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } else if (mounted) {
        // User cancelled or no GIF selected
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No GIF selected'),
            backgroundColor: Colors.grey,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('ChatView: Giphy picker error: $e');
      
      if (mounted) {
        String errorMessage = 'GIF picker temporarily unavailable';
        if (e.toString().contains('403') || e.toString().contains('banned')) {
          errorMessage = 'GIF picker needs API key setup. Please get a free Giphy API key from https://developers.giphy.com/'; // cspell:ignore Giphy
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your internet connection and try again.';
        } else {
          errorMessage = 'Failed to open GIF picker: ${e.toString()}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
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
  }

  void _pickDeviceGif() async {
    try {
      final ImagePicker picker = ImagePicker();
      
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening gallery...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 1),
          ),
        );
      }
      
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null && mounted) {
        // Check if the file is a GIF
        final file = File(image.path);
        final extension = image.path.toLowerCase().split('.').last;
        
        debugPrint('Selected file: ${image.path}, extension: $extension');
        
        if (extension == 'gif') {
          // Upload the GIF file to Firebase Storage and get the URL
          final chatNotifier = ref.read(chatNotifierProvider(widget.chat).notifier);
          await chatNotifier.sendDeviceGif(file);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('GIF sent successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Please select a GIF file. Selected file type: $extension'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else if (mounted) {
        // User cancelled or no file selected
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No file selected'),
            backgroundColor: Colors.grey,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error picking device GIF: $e');
      
      if (mounted) {
        String errorMessage = 'Failed to access gallery';
        
        if (e.toString().contains('Permission denied')) {
          errorMessage = 'Gallery permission denied. Please enable storage permissions in app settings.';
        } else if (e.toString().contains('No application found')) {
          errorMessage = 'No gallery app found. Please install a gallery app or file manager.';
        } else if (e.toString().contains('User cancelled')) {
          errorMessage = 'Gallery access cancelled';
        } else {
          errorMessage = 'Failed to pick GIF: ${e.toString()}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

class EmojiViewConfig {
}