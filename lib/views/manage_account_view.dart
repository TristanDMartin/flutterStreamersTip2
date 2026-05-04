import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/two_factor_settings_view.dart';
import '../widgets/tiktok_account_switcher_modal.dart';
import '../services/tiktok_account_switcher.dart';
import '../utils/avatar_url_resolver.dart';

class ManageAccountView extends ConsumerStatefulWidget {
  const ManageAccountView({super.key});

  @override
  ConsumerState<ManageAccountView> createState() => _ManageAccountViewState();
}

class _ManageAccountViewState extends ConsumerState<ManageAccountView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    debugPrint('🆕 ManageAccountView initState called');
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    if (kDebugMode) {
      try {
        final token = await user.getIdToken(true);
        debugPrint('🔑 Firebase ID Token (for Mux Worker test): $token');
      } catch (_) {}
    }
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (mounted && doc.exists) {
        setState(() {
          _userData = doc.data();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _switchAccount() async {
    final accountSwitcher = TikTokAccountSwitcher();
    await accountSwitcher.initialize();
    final savedAccounts = accountSwitcher.savedAccounts;

    debugPrint('🔄 Switch Account - Saved accounts: ${savedAccounts.length}');

    if (savedAccounts.isEmpty || savedAccounts.length == 1) {
      debugPrint('⚠️ Only one account, triggering Add Account instead');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add another account to enable switching'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }
      _addAccount();
      return;
    }

    debugPrint('✅ Showing account switcher modal');
    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const TikTokAccountSwitcherModal(),
      );
    }
  }

  Future<void> _addAccount() async {
    debugPrint('➕ Add Account button tapped');

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Signing in with Google...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );

    try {
      final accountSwitcher = TikTokAccountSwitcher();
      debugPrint('🔄 Calling performGoogleSignIn...');
      final success = await accountSwitcher.performGoogleSignIn();
      debugPrint('✅ Google Sign-In result: $success');

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
      }

      if (success && mounted) {
        debugPrint('✅ Adding account to saved list...');
        await accountSwitcher.addCurrentAccount();
        debugPrint('✅ Account added successfully');

        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Account added successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to add account. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error in _addAccount: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Sign Out',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to sign out? Your saved accounts will remain so you can switch back later.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await firebase_auth.FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pop();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const TikTokAccountSwitcherModal(),
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // First confirmation
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete your account and all data.',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 16),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'All of the following will be deleted:',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '• Your profile and account',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              '• All your videos',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              '• All your followers and following',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              '• All your likes and comments',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              '• All your messages',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              '• All your bookmarks and saved content',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Continue',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (firstConfirm != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    // Final confirmation with text input
    final textController = TextEditingController();
    final finalConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Final Confirmation',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Type "DELETE" to confirm account deletion:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.5),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (textController.text.trim() == 'DELETE') {
                Navigator.of(context).pop(true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please type "DELETE" exactly'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Text(
              'Delete Account',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (finalConfirm == true && mounted) {
      await _performAccountDeletion();
    }
  }

  Future<void> _performAccountDeletion() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        backgroundColor: Color(0xFF1C1C1E),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Deleting account...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );

    try {
      final userId = user.uid;

      // Delete user data from Firestore
      await _deleteUserData(userId);

      // Delete Firebase Auth account
      await user.delete();

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        Navigator.of(context).pop(); // Pop manage account view
        Navigator.of(context).pop(); // Pop settings view

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting account: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteUserData(String userId) async {
    final batch = _firestore.batch();

    // Delete user document
    final userRef = _firestore.collection('users').doc(userId);
    batch.delete(userRef);

    // Delete user's videos
    final videosSnapshot = await _firestore
        .collection('videos')
        .where('userId', isEqualTo: userId)
        .get();
    for (var doc in videosSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete user's messages
    final messagesSnapshot = await _firestore
        .collection('messages')
        .where('userId', isEqualTo: userId)
        .get();
    for (var doc in messagesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete user's comments
    final commentsSnapshot = await _firestore
        .collection('comments')
        .where('userId', isEqualTo: userId)
        .get();
    for (var doc in commentsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete user's bookmarks
    final bookmarksSnapshot = await _firestore
        .collection('bookmarks')
        .where('userId', isEqualTo: userId)
        .get();
    for (var doc in bookmarksSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete user's calendar events
    final calendarSnapshot = await _firestore
        .collection('calendar_events')
        .where('userId', isEqualTo: userId)
        .get();
    for (var doc in calendarSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Commit batch delete
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF1C135D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Manage Account',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHeader(user),
                  const SizedBox(height: 32),
                  _buildAccountInfo(user),
                  const SizedBox(height: 32),
                  _buildSecuritySection(),
                  const SizedBox(height: 32),
                  _buildAccountActions(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader(firebase_auth.User? user) {
    final avatarURL = resolveAvatarUrl(_userData);
    final displayName = _userData?['displayName'] as String? ?? user?.displayName ?? 'User';
    final username = _userData?['username'] as String? ?? 'username';

    return Column(
      children: [
        _buildAvatarWithGradientRing(avatarURL),
        const SizedBox(height: 16),
        Text(
          displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '@$username',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarWithGradientRing(String? avatarURL) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                Color(0xFFFF6CAB),
                Color(0xFF8E54E9),
                Color(0xFF3D99F7),
                Color(0xFFFF6CAB),
              ],
            ),
          ),
          child: Center(
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.2),
              ),
              child: ClipOval(
                child: avatarURL != null && avatarURL.isNotEmpty
                    ? Image.network(
                        avatarURL,
                        key: ValueKey(avatarURL),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 48,
                        ),
                      )
                    : const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 48,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountInfo(firebase_auth.User? user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Information',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoRow(Icons.email, 'Email', user?.email ?? 'Not provided'),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.person,
            'Username',
            _userData?['username'] ?? 'Not set',
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.badge,
            'Display Name',
            _userData?['displayName'] ?? 'Not set',
          ),
          if (user?.emailVerified == true) ...[
            const SizedBox(height: 16),
            _buildVerifiedBadge(),
          ] else ...[
            const SizedBox(height: 16),
            _buildUnverifiedBadge(),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildVerifiedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 16),
          SizedBox(width: 4),
          Text(
            'Email Verified',
            style: TextStyle(
              color: Colors.green,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnverifiedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning, color: Colors.orange, size: 16),
          SizedBox(width: 4),
          Text(
            'Email Not Verified',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Security',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.security, color: Colors.white, size: 20),
            ),
            title: const Text(
              'Two-Factor Authentication',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Add an extra layer of security',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white54,
              size: 16,
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const TwoFactorSettingsView(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAccountActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Account Actions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.swap_horiz,
                      color: Colors.white, size: 20),
                ),
                title: const Text(
                  'Switch Account',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Switch to another account',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  debugPrint('🔥 Switch Account button ONTAP FIRED!');
                  _switchAccount();
                },
              ),
              Divider(
                color: Colors.white.withValues(alpha: 0.1),
                height: 1,
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add_circle_outline,
                      color: Colors.white, size: 20),
                ),
                title: const Text(
                  'Add Account',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Add a new Google account',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  debugPrint('🔥 Add Account button ONTAP FIRED!');
                  _addAccount();
                },
              ),
              Divider(
                color: Colors.white.withValues(alpha: 0.1),
                height: 1,
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.logout, color: Colors.red, size: 20),
                ),
                title: const Text(
                  'Sign Out',
                  style:
                      TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Sign out of your account',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                onTap: _signOut,
              ),
              Divider(
                color: Colors.white.withValues(alpha: 0.1),
                height: 1,
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_forever,
                      color: Colors.red, size: 20),
                ),
                title: const Text(
                  'Delete Account',
                  style:
                      TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Permanently delete your account',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                onTap: _deleteAccount,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
