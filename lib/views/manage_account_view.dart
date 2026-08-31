import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/two_factor_settings_view.dart';
import '../widgets/screen_feedback_state.dart';
import '../services/account_management_service.dart';
import '../services/account_deletion_service.dart';
import '../services/account_visibility_service.dart';
import '../routing/app_routes.dart';
import '../services/unified_avatar_service.dart' as nav;
import '../utils/avatar_url_resolver.dart';
import '../utils/swallow_non_fatal.dart';
import '../utils/user_facing_error.dart';

class ManageAccountView extends ConsumerStatefulWidget {
  const ManageAccountView({super.key});

  @override
  ConsumerState<ManageAccountView> createState() => _ManageAccountViewState();
}

class _ManageAccountViewState extends ConsumerState<ManageAccountView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AccountManagementService _accountManagementService =
      const AccountManagementService();
  final AccountVisibilityService _accountVisibilityService =
      AccountVisibilityService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isAccountActionInFlight = false;
  String? _loadError;
  String? _actionError;

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
        _loadError = 'Please sign in to manage your account.';
      });
      return;
    }
    if (kDebugMode) {
      try {
        await user.getIdToken(true);
      } catch (e, st) {
        swallowNonFatal('ManageAccountView.tokenWarmup', e, st);
      }
    }
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!mounted) {
        return;
      }
      if (doc.exists) {
        setState(() {
          _userData = doc.data();
          _isLoading = false;
          _loadError = null;
        });
        return;
      }
      setState(() {
        _userData = null;
        _isLoading = false;
        _loadError = 'Account profile could not be found.';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadError = UserFacingError.message(e);
      });
    }
  }

  void _setActionError(String message) {
    if (!mounted) {
      return;
    }
    setState(() => _actionError = message);
  }

  void _clearActionError() {
    if (!mounted || _actionError == null) {
      return;
    }
    setState(() => _actionError = null);
  }

  Future<void> _switchAccount() async {
    if (_isAccountActionInFlight) {
      return;
    }
    setState(() => _isAccountActionInFlight = true);
    try {
      await _accountManagementService.showAccountSwitcher(context);
    } finally {
      if (mounted) {
        setState(() => _isAccountActionInFlight = false);
      }
    }
  }

  Future<void> _addAccount() async {
    if (_isAccountActionInFlight) {
      return;
    }
    setState(() => _isAccountActionInFlight = true);
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
                'Adding account...',
                style: TextStyle(color: cs.onSurface),
              ),
            ],
          ),
        );
      },
    );
    try {
      final AddAccountResult result = await _accountManagementService.addAccount(
        context: context,
        ref: ref,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
      if (!mounted || result.outcome == AddAccountOutcome.cancelled) {
        return;
      }
      if (result.outcome == AddAccountOutcome.failed) {
        _setActionError(
          result.message ?? 'Failed to add account. Please try again.',
        );
        return;
      }
      _clearActionError();
      if (result.isSuccess) {
        await _loadUserData();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _setActionError(UserFacingError.message(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isAccountActionInFlight = false);
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
      if (_isAccountActionInFlight || !mounted) {
        return;
      }
      setState(() => _isAccountActionInFlight = true);
      try {
        await _accountManagementService.signOut(
          context: context,
          ref: ref,
        );
      } finally {
        if (mounted) {
          setState(() => _isAccountActionInFlight = false);
        }
      }
    }
  }

  bool get _isDeactivated =>
      (_userData?['accountStatus'] as String?) == 'deactivated';

  Future<void> _deactivateAccount() async {
    if (_isAccountActionInFlight) {
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        final ColorScheme cs = Theme.of(ctx).colorScheme;
        final TextTheme tt = Theme.of(ctx).textTheme;
        return AlertDialog(
          backgroundColor: cs.surfaceContainerHigh,
          title: Text(
            'Deactivate Account',
            style: tt.titleLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Your profile, videos, and public links will be hidden '
            'immediately. Your data stays until you reactivate or delete. '
            'This is reversible.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Deactivate'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _isAccountActionInFlight = true);
    _clearActionError();
    final AccountVisibilityResult result =
        await _accountVisibilityService.deactivateCurrentAccount();
    if (!mounted) {
      return;
    }
    setState(() => _isAccountActionInFlight = false);
    if (!result.ok) {
      _setActionError(result.message ?? 'Failed to deactivate account.');
      return;
    }
    await _loadUserData();
  }

  Future<void> _reactivateAccount() async {
    if (_isAccountActionInFlight) {
      return;
    }
    setState(() => _isAccountActionInFlight = true);
    _clearActionError();
    final AccountVisibilityResult result =
        await _accountVisibilityService.reactivateCurrentAccount();
    if (!mounted) {
      return;
    }
    setState(() => _isAccountActionInFlight = false);
    if (!result.ok) {
      _setActionError(result.message ?? 'Failed to reactivate account.');
      return;
    }
    await _loadUserData();
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
      final AccountDeletionResult result =
          await _accountManagementService.deleteAccount(
        context: context,
        ref: ref,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      final ColorScheme cs = Theme.of(context).colorScheme;
      if (result.isSuccess) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.root,
          (Route<dynamic> route) => false,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 350));
          final BuildContext? rootContext =
              nav.NavigationService.navigatorKey.currentContext;
          if (rootContext == null || !rootContext.mounted) {
            return;
          }
          ScaffoldMessenger.of(rootContext).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(
                result.message ?? 'Account deleted successfully',
                style: TextStyle(color: cs.onInverseSurface),
              ),
              backgroundColor: cs.inverseSurface,
            ),
          );
        });
        return;
      }
      if (result.outcome == AccountDeletionOutcome.cancelled) {
        return;
      }
      _setActionError(
        result.message ?? 'Error deleting account. Please try again.',
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _setActionError(UserFacingError.message(e));
      }
    }
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
            : _loadError != null
                ? ScreenErrorState(
                    title: 'Couldn’t load account',
                    message: _loadError!,
                    onRetry: () {
                      setState(() {
                        _isLoading = true;
                        _loadError = null;
                      });
                      _loadUserData();
                    },
                  )
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
                      if (_actionError != null) ...[
                        ScreenInlineErrorBanner(
                          message: _actionError!,
                          onDismiss: _clearActionError,
                        ),
                        const SizedBox(height: 16),
                      ],
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
        _userData?['displayName'] as String? ?? user?.displayName ?? 'User';
    final String username = _userData?['username'] as String? ?? 'username';
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
                  'Add another account to switch later',
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
                    color: c.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _isDeactivated ? Icons.visibility : Icons.visibility_off,
                    color: c.onSurface,
                    size: _isIos ? 18 : 20,
                  ),
                ),
                title: Text(
                  _isDeactivated ? 'Reactivate Account' : 'Deactivate Account',
                  style: TextStyle(
                    color: c.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: _listTitleSize,
                  ),
                ),
                subtitle: Text(
                  _isDeactivated
                      ? 'Make your profile and videos public again'
                      : 'Hide your profile and videos. You can reactivate anytime.',
                  style: TextStyle(
                    color: c.onSurfaceVariant,
                    fontSize: _listSubtitleSize,
                  ),
                ),
                onTap: _isAccountActionInFlight
                    ? null
                    : (_isDeactivated
                        ? _reactivateAccount
                        : _deactivateAccount),
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
