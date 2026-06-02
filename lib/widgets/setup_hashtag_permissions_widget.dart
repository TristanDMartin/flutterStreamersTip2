import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/hashtag_lock_service.dart';

class SetupHashtagPermissionsWidget extends StatefulWidget {
  const SetupHashtagPermissionsWidget({super.key});

  @override
  State<SetupHashtagPermissionsWidget> createState() =>
      _SetupHashtagPermissionsWidgetState();
}

class _SetupHashtagPermissionsWidgetState
    extends State<SetupHashtagPermissionsWidget> {
  final _hashtagService = HashtagLockService();
  bool _isLoading = false;
  String? _currentUserId;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
  }

  void _getCurrentUserId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.uid;
        _status = 'Current User ID: ${user.uid}';
      });
    } else {
      setState(() {
        _status = 'No user logged in. Please log in first.';
      });
    }
  }

  Future<void> _setupPermissions() async {
    if (_currentUserId == null) {
      setState(() {
        _status = 'Error: No user logged in';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Setting up permissions...';
    });

    try {
      // Grant Owner permission
      final ownerSuccess = await _hashtagService.grantHashtagPermission(
          'owner', _currentUserId!);

      // Grant Founder permission
      final founderSuccess = await _hashtagService.grantHashtagPermission(
          'founder', _currentUserId!);

      if (ownerSuccess && founderSuccess) {
        setState(() {
          _status = '✅ Success! You can now use #owner and #founder hashtags\n'
              'Your User ID: $_currentUserId';
        });
      } else if (ownerSuccess || founderSuccess) {
        setState(() {
          _status = '⚠️ Partial success:\n'
              'Owner: ${ownerSuccess ? "✅" : "❌"}\n'
              'Founder: ${founderSuccess ? "✅" : "❌"}\n'
              'Try again for the failed permission.';
        });
      } else {
        setState(() {
          _status = '❌ Failed to set up permissions. Please check:\n'
              '1. You are logged in\n'
              '2. Internet connection is working\n'
              '3. Try again in a few seconds';
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e\n\nPlease try again or check your connection.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkPermissions() async {
    if (_currentUserId == null) {
      setState(() {
        _status = 'Error: No user logged in';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Checking permissions...';
    });

    try {
      final ownerUsers = await _hashtagService.getAuthorizedUsers('owner');
      final founderUsers = await _hashtagService.getAuthorizedUsers('founder');

      final hasOwnerPermission = ownerUsers.contains(_currentUserId);
      final hasFounderPermission = founderUsers.contains(_currentUserId);

      setState(() {
        _status = 'Owner permission: ${hasOwnerPermission ? "✅" : "❌"}\n'
            'Founder permission: ${hasFounderPermission ? "✅" : "❌"}';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error checking permissions: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Hashtag Permissions'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hashtag Permission Setup',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _status,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _setupPermissions,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Grant Me Permissions'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _checkPermissions,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Check Permissions'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Instructions:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Make sure you are logged in as "technqs"\n'
              '2. Click "Grant Me Permissions" to set up hashtag access\n'
              '3. Click "Check Permissions" to verify the setup\n'
              '4. Once set up, you can use #owner and #founder hashtags\n'
              '5. Other users will be blocked from using these hashtags',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
