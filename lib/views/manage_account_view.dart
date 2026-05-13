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

  bool get _isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  double get _pagePadding => _isIos ? 14 : 24;

  double get _profileNameSize => _isIos ? 17 : 24;

  double get _profileHandleSize => _isIos ? 12.5 : 16;

  double get _sectionTitleSize => _isIos ? 15 : 20;

  double get _infoRowFontSize => _isIos ? 11 : 14;

  double get _listTitleSize => _isIos ? 13.5 : 16;

  double get _listSubtitleSize => _isIos ? 10 : 12;

  Widget _wrapIosTextScale(BuildContext context, Widget child) {
    if (!_isIos) {
      return child;
    }
    final MediaQueryData data = MediaQuery.of(context);
    return MediaQuery(
      data: data.copyWith(
        textScaler: data.textScaler.clamp(
          minScaleFactor: 0.82,
          maxScaleFactor: 1.04,
        ),
      ),
      child: child,
    );
  }

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
        final ColorScheme cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Add another account to enable switching',
              style: TextStyle(color: cs.onInverseSurface),
            ),
            backgroundColor: cs.inverseSurface,
            duration: const Duration(seconds: 2),
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
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        final ColorScheme cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surfaceContainerHigh,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(color: cs.primary),
              const SizedBox(height: 16),
              Text(
                'Signing in with Google...',
                style: TextStyle(color: cs.onSurface),
              ),
            ],
          ),
        );
      },
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
        final ColorScheme csOk = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Account added successfully.',
              style: TextStyle(color: csOk.onInverseSurface),
            ),
            backgroundColor: csOk.inverseSurface,
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (mounted) {
        final ColorScheme csErr = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Failed to add account. Please try again.',
              style: TextStyle(color: csErr.onErrorContainer),
            ),
            backgroundColor: csErr.errorContainer,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error in _addAccount: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        final ColorScheme csE = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Error: $e',
              style: TextStyle(color: csE.onErrorContainer),
            ),
            backgroundColor: csE.errorContainer,
          ),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        final ColorScheme cs = Theme.of(ctx).colorScheme;
        final TextTheme tt = Theme.of(ctx).textTheme;
        return AlertDialog(
          backgroundColor: cs.surfaceContainerHigh,
          title: Text(
            'Sign Out',
            style: tt.titleLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to sign out? Your saved accounts will '
            'remain so you can switch back later.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: TextStyle(color: cs.primary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Sign Out',
                style: TextStyle(
                  color: cs.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
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
    final bool? firstConfirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        final ColorScheme cs = Theme.of(ctx).colorScheme;
        final TextTheme tt = Theme.of(ctx).textTheme;
        return AlertDialog(
          backgroundColor: cs.surfaceContainerHigh,
          title: Text(
            'Delete Account',
            style: tt.titleLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'This will permanently delete your account and all data.',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Text(
                'This action cannot be undone.',
                style: tt.bodyMedium?.copyWith(
                  color: cs.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'All of the following will be deleted:',
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '• Your profile and account',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                '• All your videos',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                '• All your followers and following',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                '• All your likes and comments',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                '• All your messages',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                '• All your bookmarks and saved content',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: TextStyle(color: cs.primary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Continue',
                style: TextStyle(
                  color: cs.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (firstConfirm != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    // Final confirmation with text input
    final textController = TextEditingController();
    final bool? finalConfirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        final ColorScheme cs = Theme.of(ctx).colorScheme;
        final TextTheme tt = Theme.of(ctx).textTheme;
        return AlertDialog(
          backgroundColor: cs.surfaceContainerHigh,
          title: Text(
            'Final Confirmation',
            style: tt.titleLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Type "DELETE" to confirm account deletion:',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: TextStyle(color: cs.primary)),
            ),
            TextButton(
              onPressed: () {
                if (textController.text.trim() == 'DELETE') {
                  Navigator.of(ctx).pop(true);
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text(
                        'Please type "DELETE" exactly',
                        style: TextStyle(color: cs.onInverseSurface),
                      ),
                      backgroundColor: cs.inverseSurface,
                    ),
                  );
                }
              },
              child: Text(
                'Delete Account',
                style: TextStyle(
                  color: cs.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (finalConfirm == true && mounted) {
      await _performAccountDeletion();
    }
  }

  Future<void> _performAccountDeletion() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Show loading dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        final ColorScheme cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surfaceContainerHigh,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(color: cs.primary),
              const SizedBox(height: 16),
              Text(
                'Deleting account...',
                style: TextStyle(color: cs.onSurface),
              ),
            ],
          ),
        );
      },
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
        final ColorScheme csDel = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Account deleted successfully',
              style: TextStyle(color: csDel.onInverseSurface),
            ),
            backgroundColor: csDel.inverseSurface,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        final ColorScheme csX = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Error deleting account: ${e.toString()}',
              style: TextStyle(color: csX.onErrorContainer),
            ),
            backgroundColor: csX.errorContainer,
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
    final firebase_auth.User? user =
        firebase_auth.FirebaseAuth.instance.currentUser;
    final ColorScheme c = Theme.of(context).colorScheme;
    final Widget scaffold = Scaffold(
      backgroundColor: c.surface,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.onSurface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Manage Account',
          style: TextStyle(
            color: c.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: _isIos ? 16 : 20,
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[c.surface, c.surfaceContainerLow],
          ),
        ),
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: c.primary))
            : SafeArea(
                top: false,
                bottom: true,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    _pagePadding,
                    _pagePadding,
                    _pagePadding,
                    _pagePadding + 28,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
              ),
      ),
    );
    return _wrapIosTextScale(context, scaffold);
  }

  Widget _buildProfileHeader(firebase_auth.User? user) {
    final String? avatarURL = resolveAvatarUrl(_userData);
    final String displayName =
        _userData?['displayName'] as String? ??
            user?.displayName ??
            'User';
    final String username =
        _userData?['username'] as String? ?? 'username';
    final ColorScheme c = Theme.of(context).colorScheme;
    return Column(
      children: [
        _buildAvatarWithGradientRing(avatarURL),
        const SizedBox(height: 16),
        Text(
          displayName,
          style: TextStyle(
            color: c.onSurface,
            fontSize: _profileNameSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '@$username',
          style: TextStyle(
            color: c.onSurfaceVariant,
            fontSize: _profileHandleSize,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarWithGradientRing(String? avatarURL) {
    final ColorScheme c = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: <Color>[
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
                color: c.surfaceContainerHighest,
              ),
              child: ClipOval(
                child: avatarURL != null && avatarURL.isNotEmpty
                    ? Image.network(
                        avatarURL,
                        key: ValueKey<String>(avatarURL),
                        fit: BoxFit.cover,
                        errorBuilder:
                            (BuildContext ctx, Object error, StackTrace? st) =>
                                Icon(
                          Icons.person,
                          color: c.onSurfaceVariant,
                          size: 48,
                        ),
                      )
                    : Icon(
                        Icons.person,
                        color: c.onSurfaceVariant,
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
    final ColorScheme c = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(_isIos ? 16 : 20),
      decoration: BoxDecoration(
        color: c.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Information',
            style: TextStyle(
              color: c.onSurface,
              fontSize: _sectionTitleSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: _isIos ? 16 : 20),
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
    final ColorScheme c = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: c.onSurfaceVariant,
          size: _isIos ? 18 : 20,
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: c.onSurfaceVariant,
            fontSize: _infoRowFontSize,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: c.onSurface,
              fontSize: _infoRowFontSize,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.end,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: _isIos ? 14 : 16),
          const SizedBox(width: 4),
          Text(
            'Email Verified',
            style: TextStyle(
              color: Colors.green,
              fontSize: _isIos ? 11 : 12,
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning, color: Colors.orange, size: _isIos ? 14 : 16),
          const SizedBox(width: 4),
          Text(
            'Email Not Verified',
            style: TextStyle(
              color: Colors.orange,
              fontSize: _isIos ? 11 : 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection() {
    final ColorScheme c = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Security',
          style: TextStyle(
            color: c.onSurface,
            fontSize: _sectionTitleSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: c.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.outlineVariant),
          ),
          child: ListTile(
            dense: _isIos,
            visualDensity:
                _isIos ? VisualDensity.compact : VisualDensity.standard,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.security,
                color: c.primary,
                size: _isIos ? 18 : 20,
              ),
            ),
            title: Text(
              'Two-Factor Authentication',
              style: TextStyle(
                color: c.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: _listTitleSize,
              ),
            ),
            subtitle: Text(
              'Add an extra layer of security',
              style: TextStyle(
                color: c.onSurfaceVariant,
                fontSize: _listSubtitleSize,
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              color: c.outline,
              size: _isIos ? 14 : 16,
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
    final ColorScheme c = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account Actions',
          style: TextStyle(
            color: c.onSurface,
            fontSize: _sectionTitleSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: c.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.outlineVariant),
          ),
          child: Column(
            children: [
              ListTile(
                dense: _isIos,
                visualDensity:
                    _isIos ? VisualDensity.compact : VisualDensity.standard,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.swap_horiz,
                    color: c.onSurface,
                    size: _isIos ? 18 : 20,
                  ),
                ),
                title: Text(
                  'Switch Account',
                  style: TextStyle(
                    color: c.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: _listTitleSize,
                  ),
                ),
                subtitle: Text(
                  'Switch to another account',
                  style: TextStyle(
                    color: c.onSurfaceVariant,
                    fontSize: _listSubtitleSize,
                  ),
                ),
                onTap: () {
                  debugPrint('🔥 Switch Account button ONTAP FIRED!');
                  _switchAccount();
                },
              ),
              Divider(color: c.outlineVariant, height: 1),
              ListTile(
                dense: _isIos,
                visualDensity:
                    _isIos ? VisualDensity.compact : VisualDensity.standard,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.add_circle_outline,
                    color: c.onSurface,
                    size: _isIos ? 18 : 20,
                  ),
                ),
                title: Text(
                  'Add Account',
                  style: TextStyle(
                    color: c.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: _listTitleSize,
                  ),
                ),
                subtitle: Text(
                  'Add a new Google account',
                  style: TextStyle(
                    color: c.onSurfaceVariant,
                    fontSize: _listSubtitleSize,
                  ),
                ),
                onTap: () {
                  debugPrint('🔥 Add Account button ONTAP FIRED!');
                  _addAccount();
                },
              ),
              Divider(color: c.outlineVariant, height: 1),
              ListTile(
                dense: _isIos,
                visualDensity:
                    _isIos ? VisualDensity.compact : VisualDensity.standard,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.errorContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.logout,
                    color: c.error,
                    size: _isIos ? 18 : 20,
                  ),
                ),
                title: Text(
                  'Sign Out',
                  style: TextStyle(
                    color: c.error,
                    fontWeight: FontWeight.w600,
                    fontSize: _listTitleSize,
                  ),
                ),
                subtitle: Text(
                  'Sign out of your account',
                  style: TextStyle(
                    color: c.onSurfaceVariant,
                    fontSize: _listSubtitleSize,
                  ),
                ),
                onTap: _signOut,
              ),
              Divider(color: c.outlineVariant, height: 1),
              ListTile(
                dense: _isIos,
                visualDensity:
                    _isIos ? VisualDensity.compact : VisualDensity.standard,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.errorContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.delete_forever,
                    color: c.error,
                    size: _isIos ? 18 : 20,
                  ),
                ),
                title: Text(
                  'Delete Account',
                  style: TextStyle(
                    color: c.error,
                    fontWeight: FontWeight.w600,
                    fontSize: _listTitleSize,
                  ),
                ),
                subtitle: Text(
                  'Permanently delete your account',
                  style: TextStyle(
                    color: c.onSurfaceVariant,
                    fontSize: _listSubtitleSize,
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
