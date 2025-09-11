import 'package:flutter/material.dart';
import 'dart:io';
import '../models/user.dart';
import '../models/chat.dart';

class GroupChatSelectionView extends StatefulWidget {
  final VoidCallback? onDismiss;
  final Function(Chat)? onGroupCreated;

  const GroupChatSelectionView({
    super.key,
    this.onDismiss,
    this.onGroupCreated,
  });

  @override
  State<GroupChatSelectionView> createState() => _GroupChatSelectionViewState();
}

class _GroupChatSelectionViewState extends State<GroupChatSelectionView> {
  final TextEditingController _groupNameController = TextEditingController();
  final List<User> _selectedUsers = [];
  File? _groupAvatar;
  // Image picking disabled in this build

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: widget.onDismiss,
        ),
        title: const Text(
          "New Group",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: _canCreateGroup() ? _createGroup : null,
            child: const Text(
              "Create",
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group Avatar
            _buildGroupAvatarSection(),
            
            const SizedBox(height: 20),
            
            // Group Name
            _buildGroupNameSection(),
            
            const SizedBox(height: 20),
            
            // Selected Users
            _buildSelectedUsersSection(),
            
            const SizedBox(height: 20),
            
            // Add Users Button
            _buildAddUsersButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupAvatarSection() {
    return Center(
      child: Column(
        children: [
          // Avatar Circle
          GestureDetector(
            onTap: _showImagePicker,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.withValues(alpha:0.3),
                border: Border.all(
                  color: Colors.white.withValues(alpha:0.2),
                  width: 2,
                ),
              ),
              child: _groupAvatar != null
                  ? ClipOval(
                      child: Image.file(
                        _groupAvatar!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt,
                      color: Colors.grey,
                      size: 32,
                    ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          TextButton(
            onPressed: _showImagePicker,
            child: const Text(
              "Add Photo",
              style: TextStyle(
                color: Colors.blue,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupNameSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Group Name",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _groupNameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Enter group name",
            hintStyle: TextStyle(color: Colors.white.withValues(alpha:0.5)),
            filled: true,
            fillColor: Colors.white.withValues(alpha:0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedUsersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Selected Users (${_selectedUsers.length})",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        if (_selectedUsers.isNotEmpty)
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedUsers.length,
              itemBuilder: (context, index) {
                final user = _selectedUsers[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha:0.3),
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child: user.avatarURL != null
                                  ? Image.network(
                                      user.avatarURL!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.grey.withValues(alpha:0.3),
                                          child: Icon(
                                            Icons.person,
                                            color: Colors.white.withValues(alpha:0.6),
                                          ),
                                        );
                                      },
                                    )
                                  : Container(
                                      color: Colors.grey.withValues(alpha:0.3),
                                      child: Icon(
                                        Icons.person,
                                        color: Colors.white.withValues(alpha:0.6),
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              onTap: () => _removeUser(user),
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 60,
                        child: Text(
                          user.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha:0.1),
              ),
            ),
            child: const Center(
              child: Text(
                "No users selected",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAddUsersButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _showUserPicker,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          "Add Users",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showImagePicker() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image picking is not available in this build.')),
    );
  }

  void _showUserPicker() {
    // This would typically show a modal with user selection
    // For now, we'll add some sample users
    _showUserSelectionDialog();
  }

  void _showUserSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          "Select Users",
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: _getAvailableUsers().length,
            itemBuilder: (context, index) {
              final user = _getAvailableUsers()[index];
              final isSelected = _selectedUsers.contains(user);
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: user.avatarURL != null
                      ? NetworkImage(user.avatarURL!)
                      : null,
                  child: user.avatarURL == null
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
                ),
                title: Text(
                  user.displayName,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  user.username,
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: Icon(
                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isSelected ? Colors.blue : Colors.white70,
                ),
                onTap: () {
                  if (isSelected) {
                    _removeUser(user);
                  } else {
                    _addUser(user);
                  }
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  List<User> _getAvailableUsers() {
    // This would typically fetch from your user service
    // For now, return sample users
    return [
      const User(
        id: "user1",
        username: "john_doe",
        displayName: "John Doe",
        bio: "Software Developer",
        avatarURL: null,
        onlineStatus: 'online',
        hashtags: [],
      ),
      const User(
        id: "user2",
        username: "jane_smith",
        displayName: "Jane Smith",
        bio: "Designer",
        avatarURL: null,
        onlineStatus: 'online',
        hashtags: [],
      ),
      const User(
        id: "user3",
        username: "mike_wilson",
        displayName: "Mike Wilson",
        bio: "Product Manager",
        avatarURL: null,
        onlineStatus: 'offline',
        hashtags: [],
      ),
    ];
  }

  void _addUser(User user) {
    if (!_selectedUsers.contains(user)) {
      setState(() {
        _selectedUsers.add(user);
      });
    }
  }

  void _removeUser(User user) {
    setState(() {
      _selectedUsers.remove(user);
    });
  }

  bool _canCreateGroup() {
    return _groupNameController.text.trim().isNotEmpty && _selectedUsers.isNotEmpty;
  }

  void _createGroup() {
    if (!_canCreateGroup()) return;

    final groupName = _groupNameController.text.trim();
    
    // Create a new group chat
    final groupChat = Chat(
      participants: _selectedUsers.map((u) => u.id).toList(),
      lastMessage: "Group created",
      lastTimestamp: DateTime.now(),
      groupName: groupName,
      groupAvatarURL: null, // You would upload the image and get the URL
    );

    // Call the callback
    widget.onGroupCreated?.call(groupChat);
    
    // Dismiss the view
    widget.onDismiss?.call();
  }
}
