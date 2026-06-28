import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/support_shell_style.dart';
import '../features/tippy/tippy_legal_service.dart';
import '../providers/status_provider.dart';
import '../services/privacy_settings_service.dart';

class PrivacySettingsView extends ConsumerStatefulWidget {
  const PrivacySettingsView({super.key});

  @override
  ConsumerState<PrivacySettingsView> createState() =>
      _PrivacySettingsViewState();
}

class _PrivacySettingsViewState extends ConsumerState<PrivacySettingsView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  bool _isSaving = false;

  bool get _isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

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

  String _profileVisibility = 'public';
  String _videoPrivacy = 'public';
  String _allowMentions = 'everyone';
  bool _allowTags = true;
  bool _allowFollowers = true;
  String _allowMessagesFrom = 'everyone';
  bool _showOnlineStatus = true;
  bool _readReceipts = true;
  bool _deletingTippyHistory = false;

  final TippyLegalService _tippyLegalService = TippyLegalService();

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    final firebase_auth.User? user =
        firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('privacySettings')
          .doc('main')
          .get();

      if (doc.exists && mounted) {
        final Map<String, dynamic> data = doc.data()!;
        setState(() {
          _profileVisibility = data['profileVisibility'] ?? 'public';
          _videoPrivacy = data['videoPrivacy'] ?? 'public';
          _allowMentions = data['allowMentions'] ?? 'everyone';
          _allowTags = data['allowTags'] ?? true;
          _allowFollowers = data['allowFollowers'] ?? true;
          _allowMessagesFrom = data['allowMessagesFrom'] ?? 'everyone';
          _showOnlineStatus = data['showOnlineStatus'] ?? true;
          _readReceipts = data['readReceipts'] ?? true;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    final firebase_auth.User? user =
        firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('privacySettings')
          .doc('main')
          .set({key: value}, SetOptions(merge: true));

      PrivacySettingsService.instance.invalidate(user.uid);
      if (key == 'showOnlineStatus' && value == false) {
        await ref.read(statusNotifierProvider.notifier).setOffline();
      }

      if (mounted) {
        final ColorScheme cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Settings updated',
              style: TextStyle(color: cs.onInverseSurface),
            ),
            backgroundColor: cs.inverseSurface,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final ColorScheme cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Error updating settings: $e',
              style: TextStyle(color: cs.onErrorContainer),
            ),
            backgroundColor: cs.errorContainer,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: shell.onChrome),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'Privacy Settings',
        style: TextStyle(
          color: shell.onChrome,
          fontWeight: FontWeight.w800,
          fontSize: _isIos ? 17 : 22,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    if (_isLoading) {
      return _wrapIosTextScale(
        context,
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: StSupportShellStyle.of(context).pageGradient,
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: _buildAppBar(context),
            body: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      );
    }

    return _wrapIosTextScale(
      context,
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: StSupportShellStyle.of(context).pageGradient,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _buildAppBar(context),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(_isIos ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isSaving)
                  LinearProgressIndicator(
                    backgroundColor: cs.surfaceContainerLow,
                    color: cs.primary,
                  ),
                _buildSection(
                  context,
                  'Profile',
                  [
                    _buildDropdownSetting(
                      context,
                      icon: Icons.visibility,
                      title: 'Profile Visibility',
                      subtitle: 'Who can see your profile',
                      value: _profileVisibility,
                      options: const ['public', 'followers', 'private'],
                      onChanged: (String? value) {
                        setState(() => _profileVisibility = value!);
                        _updateSetting('profileVisibility', value);
                      },
                    ),
                    _buildSwitchSetting(
                      context,
                      icon: Icons.people_outline,
                      title: 'Allow Followers',
                      subtitle: 'Let people follow your account',
                      value: _allowFollowers,
                      onChanged: (bool value) {
                        setState(() => _allowFollowers = value);
                        _updateSetting('allowFollowers', value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildSection(
                  context,
                  'Content',
                  [
                    _buildDropdownSetting(
                      context,
                      icon: Icons.video_library,
                      title: 'Video Privacy',
                      subtitle: 'Default privacy for new videos',
                      value: _videoPrivacy,
                      options: const ['public', 'followers', 'private'],
                      onChanged: (String? value) {
                        setState(() => _videoPrivacy = value!);
                        _updateSetting('videoPrivacy', value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildSection(
                  context,
                  'Social',
                  [
                    _buildDropdownSetting(
                      context,
                      icon: Icons.alternate_email,
                      title: 'Mentions',
                      subtitle: 'Who can mention you',
                      value: _allowMentions,
                      options: const ['everyone', 'followers', 'nobody'],
                      onChanged: (String? value) {
                        setState(() => _allowMentions = value!);
                        _updateSetting('allowMentions', value);
                      },
                    ),
                    _buildSwitchSetting(
                      context,
                      icon: Icons.label_outline,
                      title: 'Allow Tags',
                      subtitle: 'Let people tag you',
                      value: _allowTags,
                      onChanged: (bool value) {
                        setState(() => _allowTags = value);
                        _updateSetting('allowTags', value);
                      },
                    ),
                    _buildDropdownSetting(
                      context,
                      icon: Icons.message_outlined,
                      title: 'Messages',
                      subtitle: 'Who can send you messages',
                      value: _allowMessagesFrom,
                      options: const ['everyone', 'followers', 'nobody'],
                      onChanged: (String? value) {
                        setState(() => _allowMessagesFrom = value!);
                        _updateSetting('allowMessagesFrom', value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildSection(
                  context,
                  'Activity',
                  [
                    _buildSwitchSetting(
                      context,
                      icon: Icons.circle,
                      title: 'Show Online Status',
                      subtitle: 'Let others see when you\'re online',
                      value: _showOnlineStatus,
                      onChanged: (bool value) {
                        setState(() => _showOnlineStatus = value);
                        _updateSetting('showOnlineStatus', value);
                      },
                    ),
                    _buildSwitchSetting(
                      context,
                      icon: Icons.done_all,
                      title: 'Read Receipts',
                      subtitle:
                          'Let others know when you\'ve read their messages',
                      value: _readReceipts,
                      onChanged: (bool value) {
                        setState(() => _readReceipts = value);
                        _updateSetting('readReceipts', value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildSection(
                  context,
                  'Tippy AI',
                  [
                    _buildDeleteTippyHistoryTile(context),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            color: shell.onChrome,
            fontSize: _isIos ? 17 : 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: shell.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: shell.surfaceCardBorder),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: shell.shadowSoft,
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownSetting(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Container(
      padding: EdgeInsets.all(_isIos ? 14 : 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: shell.chipUnselectedBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: shell.chipUnselectedBorder),
            ),
            child: Icon(icon, color: shell.onChrome, size: _isIos ? 18 : 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    color: shell.onChrome,
                    fontSize: _isIos ? 14 : 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: shell.muted,
                    fontSize: _isIos ? 11 : 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: shell.chipUnselectedBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: shell.chipUnselectedBorder,
              ),
            ),
            child: DropdownButton<String>(
              value: value,
              dropdownColor: cs.surfaceContainerHigh,
              style: TextStyle(
                color: shell.onChrome,
                fontSize: _isIos ? 13 : 14,
              ),
              underline: const SizedBox(),
              items: options.map((String option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(
                    _formatOption(option),
                    style: TextStyle(color: shell.onChrome),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchSetting(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Container(
      padding: EdgeInsets.all(_isIos ? 14 : 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: shell.chipUnselectedBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: shell.chipUnselectedBorder),
            ),
            child: Icon(icon, color: shell.onChrome, size: _isIos ? 18 : 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    color: shell.onChrome,
                    fontSize: _isIos ? 14 : 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: shell.muted,
                    fontSize: _isIos ? 11 : 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: cs.primary,
            activeTrackColor: cs.primary.withValues(alpha: 0.45),
            inactiveTrackColor: shell.muted.withValues(alpha: 0.22),
            inactiveThumbColor: shell.iconDim,
          ),
        ],
      ),
    );
  }

  String _formatOption(String option) {
    return option[0].toUpperCase() + option.substring(1);
  }

  Widget _buildDeleteTippyHistoryTile(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Container(
      padding: EdgeInsets.all(_isIos ? 14 : 20),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: shell.chipUnselectedBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: shell.chipUnselectedBorder),
            ),
            child: Icon(
              Icons.delete_forever_outlined,
              color: shell.onChrome,
              size: _isIos ? 18 : 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Delete Tippy chat history',
                  style: TextStyle(
                    color: shell.onChrome,
                    fontSize: _isIos ? 14 : 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Permanently remove saved Tippy conversations and prompts.',
                  style: TextStyle(
                    color: shell.muted,
                    fontSize: _isIos ? 11 : 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: _deletingTippyHistory ? null : _confirmDeleteTippyHistory,
            child: _deletingTippyHistory
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteTippyHistory() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Tippy history?'),
          content: const Text(
            'This permanently deletes your saved Tippy conversations. '
            'This cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _deletingTippyHistory = true);
    try {
      await _tippyLegalService.deleteAllPromptHistory();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Tippy chat history deleted'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Could not delete history: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _deletingTippyHistory = false);
      }
    }
  }
}
