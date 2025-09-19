import 'package:flutter/material.dart';
import '../services/hashtag_lock_service.dart';

class HashtagAdminView extends StatefulWidget {
  const HashtagAdminView({super.key});

  @override
  State<HashtagAdminView> createState() => _HashtagAdminViewState();
}

class _HashtagAdminViewState extends State<HashtagAdminView> {
  final _hashtagController = TextEditingController();
  final _userIdController = TextEditingController();
  final _hashtagService = HashtagLockService();
  
  List<String> _authorizedUsers = [];
  String _selectedHashtag = 'owner';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAuthorizedUsers();
  }

  @override
  void dispose() {
    _hashtagController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _loadAuthorizedUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _hashtagService.getAuthorizedUsers(_selectedHashtag);
      setState(() {
        _authorizedUsers = users;
      });
    } catch (e) {
      _showError('Failed to load authorized users: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _grantPermission() async {
    if (_userIdController.text.isEmpty) {
      _showError('Please enter a user ID');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final success = await _hashtagService.grantHashtagPermission(
        _selectedHashtag, 
        _userIdController.text.trim()
      );
      
      if (success) {
        _showSuccess('Permission granted successfully');
        _userIdController.clear();
        _loadAuthorizedUsers();
      } else {
        _showError('Failed to grant permission');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _revokePermission(String userId) async {
    setState(() => _isLoading = true);
    try {
      final success = await _hashtagService.revokeHashtagPermission(
        _selectedHashtag, 
        userId
      );
      
      if (success) {
        _showSuccess('Permission revoked successfully');
        _loadAuthorizedUsers();
      } else {
        _showError('Failed to revoke permission');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hashtag Admin'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hashtag Selection
            const Text(
              'Select Hashtag:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _selectedHashtag,
              dropdownColor: Colors.grey[800],
              style: const TextStyle(color: Colors.white),
              items: const [
                DropdownMenuItem(value: 'owner', child: Text('Owner')),
                DropdownMenuItem(value: 'founder', child: Text('Founder')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
                DropdownMenuItem(value: 'moderator', child: Text('Moderator')),
                DropdownMenuItem(value: 'staff', child: Text('Staff')),
                DropdownMenuItem(value: 'official', child: Text('Official')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedHashtag = value;
                  });
                  _loadAuthorizedUsers();
                }
              },
            ),
            
            const SizedBox(height: 24),
            
            // Grant Permission Section
            const Text(
              'Grant Permission:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _userIdController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Enter User ID',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _grantPermission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Grant'),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Authorized Users List
            const Text(
              'Authorized Users:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              )
            else if (_authorizedUsers.isEmpty)
              const Text(
                'No authorized users',
                style: TextStyle(color: Colors.grey),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _authorizedUsers.length,
                  itemBuilder: (context, index) {
                    final userId = _authorizedUsers[index];
                    return Card(
                      color: Colors.grey[800],
                      child: ListTile(
                        title: Text(
                          userId,
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.remove_circle,
                            color: Colors.red,
                          ),
                          onPressed: _isLoading ? null : () => _revokePermission(userId),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
