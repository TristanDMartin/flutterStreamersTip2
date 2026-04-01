import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MentionsTagsView extends ConsumerStatefulWidget {
  const MentionsTagsView({super.key});

  @override
  ConsumerState<MentionsTagsView> createState() => _MentionsTagsViewState();
}

class _MentionsTagsViewState extends ConsumerState<MentionsTagsView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  bool _isSaving = false;

  // Mention & Tag settings state
  String _allowMentions = 'everyone'; // everyone | followers | nobody
  bool _allowTags = true;
  bool _allowMentionNotifications = true;
  bool _allowTagNotifications = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final privacyDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('privacySettings')
          .doc('main')
          .get();

      final notificationDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notificationSettings')
          .doc('main')
          .get();

      if (mounted) {
        setState(() {
          if (privacyDoc.exists) {
            final data = privacyDoc.data()!;
            _allowMentions = data['allowMentions'] ?? 'everyone';
            _allowTags = data['allowTags'] ?? true;
          }

          if (notificationDoc.exists) {
            final data = notificationDoc.data()!;
            _allowMentionNotifications = data['mentions'] ?? true;
            _allowTagNotifications = data['tags'] ?? true;
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updatePrivacySetting(String key, dynamic value) async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('privacySettings')
          .doc('main')
          .set({key: value}, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings updated'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _updateNotificationSetting(String key, bool value) async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notificationSettings')
          .doc('main')
          .set({key: value}, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings updated'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
            'Mentions & Tags',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

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
          'Mentions & Tags',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isSaving)
              const LinearProgressIndicator(
                backgroundColor: Colors.transparent,
              ),
            _buildSection(
              'Mentions',
              'Control who can mention you',
              [
                _buildDropdownSetting(
                  icon: Icons.alternate_email,
                  title: 'Who can mention you',
                  subtitle: 'Control mention permissions',
                  value: _allowMentions,
                  options: const ['everyone', 'followers', 'nobody'],
                  onChanged: (value) {
                    setState(() => _allowMentions = value!);
                    _updatePrivacySetting('allowMentions', value);
                  },
                ),
                _buildSwitchSetting(
                  icon: Icons.notifications_outlined,
                  title: 'Mention Notifications',
                  subtitle: 'Get notified when someone mentions you',
                  value: _allowMentionNotifications,
                  onChanged: (value) {
                    setState(() => _allowMentionNotifications = value);
                    _updateNotificationSetting('mentions', value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Tags',
              'Control who can tag you',
              [
                _buildSwitchSetting(
                  icon: Icons.label_outline,
                  title: 'Allow Tags',
                  subtitle: 'Let people tag you in their content',
                  value: _allowTags,
                  onChanged: (value) {
                    setState(() => _allowTags = value);
                    _updatePrivacySetting('allowTags', value);
                  },
                ),
                _buildSwitchSetting(
                  icon: Icons.notifications_outlined,
                  title: 'Tag Notifications',
                  subtitle: 'Get notified when someone tags you',
                  value: _allowTagNotifications,
                  onChanged: (value) {
                    setState(() => _allowTagNotifications = value);
                    _updateNotificationSetting('tags', value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildInfoCard(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String subtitle, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
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
            children: [...children],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownSetting({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            child: DropdownButton<String>(
              value: value,
              dropdownColor: const Color(0xFF1C135D),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              underline: const SizedBox(),
              items: options.map((option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(
                    _formatOption(option),
                    style: const TextStyle(color: Colors.white),
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

  Widget _buildSwitchSetting({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF9248D2),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'About Mentions & Tags',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mentions allow users to tag you in comments. Tags let users tag you in their content. You control who can do this.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatOption(String option) {
    return option[0].toUpperCase() + option.substring(1);
  }
}
