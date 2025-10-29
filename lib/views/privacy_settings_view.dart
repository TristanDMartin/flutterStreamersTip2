import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  // Privacy settings state
  String _profileVisibility = 'public'; // public | followers | private
  String _videoPrivacy = 'public';
  String _allowMentions = 'everyone'; // everyone | followers | nobody
  bool _allowTags = true;
  bool _allowFollowers = true;
  String _allowMessagesFrom = 'everyone'; // everyone | followers | nobody
  bool _showOnlineStatus = true;
  bool _readReceipts = true;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
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
        final data = doc.data()!;
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
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
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
            'Privacy Settings',
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
          'Privacy Settings',
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
              'Profile',
              [
                _buildDropdownSetting(
                  icon: Icons.visibility,
                  title: 'Profile Visibility',
                  subtitle: 'Who can see your profile',
                  value: _profileVisibility,
                  options: const ['public', 'followers', 'private'],
                  onChanged: (value) {
                    setState(() => _profileVisibility = value!);
                    _updateSetting('profileVisibility', value);
                  },
                ),
                _buildSwitchSetting(
                  icon: Icons.people_outline,
                  title: 'Allow Followers',
                  subtitle: 'Let people follow your account',
                  value: _allowFollowers,
                  onChanged: (value) {
                    setState(() => _allowFollowers = value);
                    _updateSetting('allowFollowers', value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Content',
              [
                _buildDropdownSetting(
                  icon: Icons.video_library,
                  title: 'Video Privacy',
                  subtitle: 'Default privacy for new videos',
                  value: _videoPrivacy,
                  options: const ['public', 'followers', 'private'],
                  onChanged: (value) {
                    setState(() => _videoPrivacy = value!);
                    _updateSetting('videoPrivacy', value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Social',
              [
                _buildDropdownSetting(
                  icon: Icons.alternate_email,
                  title: 'Mentions',
                  subtitle: 'Who can mention you',
                  value: _allowMentions,
                  options: const ['everyone', 'followers', 'nobody'],
                  onChanged: (value) {
                    setState(() => _allowMentions = value!);
                    _updateSetting('allowMentions', value);
                  },
                ),
                _buildSwitchSetting(
                  icon: Icons.label_outline,
                  title: 'Allow Tags',
                  subtitle: 'Let people tag you',
                  value: _allowTags,
                  onChanged: (value) {
                    setState(() => _allowTags = value);
                    _updateSetting('allowTags', value);
                  },
                ),
                _buildDropdownSetting(
                  icon: Icons.message_outlined,
                  title: 'Messages',
                  subtitle: 'Who can send you messages',
                  value: _allowMessagesFrom,
                  options: const ['everyone', 'followers', 'nobody'],
                  onChanged: (value) {
                    setState(() => _allowMessagesFrom = value!);
                    _updateSetting('allowMessagesFrom', value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Activity',
              [
                _buildSwitchSetting(
                  icon: Icons.circle,
                  title: 'Show Online Status',
                  subtitle: 'Let others see when you\'re online',
                  value: _showOnlineStatus,
                  onChanged: (value) {
                    setState(() => _showOnlineStatus = value);
                    _updateSetting('showOnlineStatus', value);
                  },
                ),
                _buildSwitchSetting(
                  icon: Icons.done_all,
                  title: 'Read Receipts',
                  subtitle: 'Let others know when you\'ve read their messages',
                  value: _readReceipts,
                  onChanged: (value) {
                    setState(() => _readReceipts = value);
                    _updateSetting('readReceipts', value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
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
              ...children,
            ],
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
            activeColor: const Color(0xFF9248D2),
          ),
        ],
      ),
    );
  }

  String _formatOption(String option) {
    return option[0].toUpperCase() + option.substring(1);
  }
}
