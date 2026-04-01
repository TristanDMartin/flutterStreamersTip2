import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ContentPreferencesView extends ConsumerStatefulWidget {
  const ContentPreferencesView({super.key});

  @override
  ConsumerState<ContentPreferencesView> createState() =>
      _ContentPreferencesViewState();
}

class _ContentPreferencesViewState
    extends ConsumerState<ContentPreferencesView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  bool _isSaving = false;

  // Content preferences state
  bool _autoPlay = true;
  bool _soundEnabled = true;
  bool _dataSaver = false;
  String _videoQuality = 'auto'; // auto | high | medium | low
  bool _downloadEnabled = true;
  bool _contentVisibility = true;
  bool _sensitiveContent = false;
  String _languagePreference = 'en';

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
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('contentSettings')
          .doc('main')
          .get();

      if (mounted) {
        setState(() {
          if (doc.exists) {
            final data = doc.data()!;
            _autoPlay = data['autoPlay'] ?? true;
            _soundEnabled = data['soundEnabled'] ?? true;
            _dataSaver = data['dataSaver'] ?? false;
            _videoQuality = data['videoQuality'] ?? 'auto';
            _downloadEnabled = data['downloadEnabled'] ?? true;
            _contentVisibility = data['contentVisibility'] ?? true;
            _sensitiveContent = data['sensitiveContent'] ?? false;
            _languagePreference = data['languagePreference'] ?? 'en';
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

  Future<void> _updateSetting(String key, dynamic value) async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('contentSettings')
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
            'Content Preferences',
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
          'Content Preferences',
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
              'Playback',
              'Control how content plays',
              [
                _buildSwitchSetting(
                  icon: Icons.play_circle_outline,
                  title: 'Auto-play',
                  subtitle: 'Automatically play videos when browsing',
                  value: _autoPlay,
                  onChanged: (value) {
                    setState(() => _autoPlay = value);
                    _updateSetting('autoPlay', value);
                  },
                ),
                _buildSwitchSetting(
                  icon: Icons.volume_up,
                  title: 'Sound',
                  subtitle: 'Enable sound by default',
                  value: _soundEnabled,
                  onChanged: (value) {
                    setState(() => _soundEnabled = value);
                    _updateSetting('soundEnabled', value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Quality & Data',
              'Control video quality and data usage',
              [
                _buildDropdownSetting(
                  icon: Icons.high_quality,
                  title: 'Video Quality',
                  subtitle: 'Choose preferred video quality',
                  value: _videoQuality,
                  options: const ['auto', 'high', 'medium', 'low'],
                  onChanged: (value) {
                    setState(() => _videoQuality = value!);
                    _updateSetting('videoQuality', value);
                  },
                ),
                _buildSwitchSetting(
                  icon: Icons.data_saver_on,
                  title: 'Data Saver',
                  subtitle: 'Reduce data usage by lowering quality',
                  value: _dataSaver,
                  onChanged: (value) {
                    setState(() => _dataSaver = value);
                    _updateSetting('dataSaver', value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Downloads',
              'Control downloaded content',
              [
                _buildSwitchSetting(
                  icon: Icons.download,
                  title: 'Allow Downloads',
                  subtitle: 'Enable downloading videos',
                  value: _downloadEnabled,
                  onChanged: (value) {
                    setState(() => _downloadEnabled = value);
                    _updateSetting('downloadEnabled', value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Content Visibility',
              'Control what content appears',
              [
                _buildSwitchSetting(
                  icon: Icons.visibility,
                  title: 'Show Sensitive Content',
                  subtitle: 'Show sensitive or explicit content',
                  value: _sensitiveContent,
                  onChanged: (value) {
                    setState(() => _sensitiveContent = value);
                    _updateSetting('sensitiveContent', value);
                  },
                ),
                _buildSwitchSetting(
                  icon: Icons.filter_list,
                  title: 'Content Filter',
                  subtitle: 'Filter mature or explicit content',
                  value: _contentVisibility,
                  onChanged: (value) {
                    setState(() => _contentVisibility = value);
                    _updateSetting('contentVisibility', value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Language',
              'Language preferences',
              [
                _buildDropdownSetting(
                  icon: Icons.language,
                  title: 'Preferred Language',
                  subtitle: 'Set your preferred language',
                  value: _languagePreference,
                  options: const [
                    'en',
                    'es',
                    'fr',
                    'de',
                    'it',
                    'pt',
                    'ja',
                    'zh'
                  ],
                  onChanged: (value) {
                    setState(() => _languagePreference = value!);
                    _updateSetting('languagePreference', value);
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
          const Icon(Icons.info_outline, color: Colors.blue, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'About Content Preferences',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Customize how you view and interact with content. Adjust quality, playback, and visibility settings to match your preferences.',
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
    final languageNames = {
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ja': 'Japanese',
      'zh': 'Chinese',
    };

    if (languageNames.containsKey(option)) {
      return languageNames[option]!;
    }

    // Format quality options
    return option[0].toUpperCase() + option.substring(1);
  }
}
