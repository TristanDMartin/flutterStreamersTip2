import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings/settings_subpage_widgets.dart';
import '../services/content_settings_service.dart';
import '../utils/user_facing_error.dart';

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
  String? _loadError;
  String? _actionError;
  bool _autoPlay = true;
  bool _soundEnabled = true;
  bool _dataSaver = false;
  String _videoQuality = 'auto';
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
    final firebase_auth.User? user =
        firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _loadError = 'Please sign in to manage content preferences.';
      });
      return;
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('contentSettings')
          .doc('main')
          .get();
      if (mounted) {
        setState(() {
          if (doc.exists && doc.data() != null) {
            final Map<String, dynamic> data = doc.data()!;
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
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = UserFacingError.message(e);
        });
      }
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    final firebase_auth.User? user =
        firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    setState(() {
      _isSaving = true;
      _actionError = null;
    });
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('contentSettings')
          .doc('main')
          .set(<String, dynamic>{key: value}, SetOptions(merge: true));
      ContentSettingsService.instance.invalidate(user.uid);
      if (mounted) {
        SettingsSubpageWidgets.showUpdatedSnackBar(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _actionError = UserFacingError.message(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatLanguage(String code) {
    const Map<String, String> labels = <String, String>{
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ja': 'Japanese',
      'zh': 'Chinese',
    };
    return labels[code] ?? code.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSubpageWidgets.shell(
      context: context,
      title: 'Content Preferences',
      isLoading: _isLoading,
      isSaving: _isSaving,
      loadError: _loadError,
      onRetryLoad: () {
        setState(() {
          _isLoading = true;
          _loadError = null;
        });
        _loadSettings();
      },
      actionError: _actionError,
      onDismissActionError: () {
        if (mounted) {
          setState(() => _actionError = null);
        }
      },
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SettingsSubpageWidgets.section(
              context: context,
              title: 'Playback',
              subtitle: 'Control how content plays',
              children: <Widget>[
                SettingsSubpageWidgets.switchRow(
                  context: context,
                  icon: Icons.play_circle_outline,
                  title: 'Auto-play',
                  subtitle: 'Automatically play videos when browsing',
                  value: _autoPlay,
                  onChanged: (bool value) {
                    setState(() => _autoPlay = value);
                    _updateSetting('autoPlay', value);
                  },
                ),
                SettingsSubpageWidgets.switchRow(
                  context: context,
                  icon: Icons.volume_up,
                  title: 'Sound',
                  subtitle: 'Enable sound by default',
                  value: _soundEnabled,
                  onChanged: (bool value) {
                    setState(() => _soundEnabled = value);
                    _updateSetting('soundEnabled', value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            SettingsSubpageWidgets.section(
              context: context,
              title: 'Quality & Data',
              subtitle: 'Control video quality and data usage',
              children: <Widget>[
                SettingsSubpageWidgets.dropdownRow(
                  context: context,
                  icon: Icons.high_quality,
                  title: 'Video Quality',
                  subtitle: 'Choose preferred video quality',
                  value: _videoQuality,
                  options: const <String>['auto', 'high', 'medium', 'low'],
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _videoQuality = value);
                    _updateSetting('videoQuality', value);
                  },
                ),
                SettingsSubpageWidgets.switchRow(
                  context: context,
                  icon: Icons.data_saver_on,
                  title: 'Data Saver',
                  subtitle: 'Reduce data usage by lowering quality',
                  value: _dataSaver,
                  onChanged: (bool value) {
                    setState(() => _dataSaver = value);
                    _updateSetting('dataSaver', value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            SettingsSubpageWidgets.section(
              context: context,
              title: 'Downloads',
              subtitle: 'Control downloaded content',
              children: <Widget>[
                SettingsSubpageWidgets.switchRow(
                  context: context,
                  icon: Icons.download,
                  title: 'Allow Downloads',
                  subtitle: 'Enable downloading videos',
                  value: _downloadEnabled,
                  onChanged: (bool value) {
                    setState(() => _downloadEnabled = value);
                    _updateSetting('downloadEnabled', value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            SettingsSubpageWidgets.section(
              context: context,
              title: 'Content Visibility',
              subtitle: 'Control what content appears',
              children: <Widget>[
                SettingsSubpageWidgets.switchRow(
                  context: context,
                  icon: Icons.visibility,
                  title: 'Show Sensitive Content',
                  subtitle: 'Show sensitive or explicit content',
                  value: _sensitiveContent,
                  onChanged: (bool value) {
                    setState(() => _sensitiveContent = value);
                    _updateSetting('sensitiveContent', value);
                  },
                ),
                SettingsSubpageWidgets.switchRow(
                  context: context,
                  icon: Icons.filter_list,
                  title: 'Content Filter',
                  subtitle: 'Filter mature or explicit content',
                  value: _contentVisibility,
                  onChanged: (bool value) {
                    setState(() => _contentVisibility = value);
                    _updateSetting('contentVisibility', value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            SettingsSubpageWidgets.section(
              context: context,
              title: 'Language',
              subtitle: 'Language preferences',
              children: <Widget>[
                SettingsSubpageWidgets.dropdownRow(
                  context: context,
                  icon: Icons.language,
                  title: 'Preferred Language',
                  subtitle: 'Set your preferred language',
                  value: _languagePreference,
                  options: const <String>[
                    'en',
                    'es',
                    'fr',
                    'de',
                    'it',
                    'pt',
                    'ja',
                    'zh',
                  ],
                  labelForOption: _formatLanguage,
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _languagePreference = value);
                    _updateSetting('languagePreference', value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            SettingsSubpageWidgets.infoCard(
              context: context,
              title: 'About Content Preferences',
              body:
                  'Customize how you view and interact with content. '
                  'Adjust quality, playback, and visibility to match your '
                  'preferences.',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
