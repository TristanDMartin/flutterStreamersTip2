import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings/settings_subpage_widgets.dart';
import '../services/privacy_settings_service.dart';
import '../services/notification_settings_service.dart';
import '../utils/user_facing_error.dart';

class MentionsTagsView extends ConsumerStatefulWidget {
  const MentionsTagsView({super.key});

  @override
  ConsumerState<MentionsTagsView> createState() => _MentionsTagsViewState();
}

class _MentionsTagsViewState extends ConsumerState<MentionsTagsView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;
  String? _actionError;
  String _allowMentions = 'everyone';
  bool _allowTags = true;
  bool _allowMentionNotifications = true;
  bool _allowTagNotifications = true;

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
        _loadError = 'Please sign in to manage mentions and tags.';
      });
      return;
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> privacyDoc =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('privacySettings')
              .doc('main')
              .get();
      final DocumentSnapshot<Map<String, dynamic>> notificationDoc =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('notificationSettings')
              .doc('main')
              .get();
      if (mounted) {
        setState(() {
          if (privacyDoc.exists && privacyDoc.data() != null) {
            final Map<String, dynamic> data = privacyDoc.data()!;
            _allowMentions = data['allowMentions'] ?? 'everyone';
            _allowTags = data['allowTags'] ?? true;
          }
          if (notificationDoc.exists && notificationDoc.data() != null) {
            final Map<String, dynamic> data = notificationDoc.data()!;
            _allowMentionNotifications = data['mentions'] ?? true;
            _allowTagNotifications = data['tags'] ?? true;
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

  Future<void> _updatePrivacySetting(String key, dynamic value) async {
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
          .collection('privacySettings')
          .doc('main')
          .set(<String, dynamic>{key: value}, SetOptions(merge: true));
      PrivacySettingsService.instance.invalidate(user.uid);
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

  Future<void> _updateNotificationSetting(String key, bool value) async {
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
          .collection('notificationSettings')
          .doc('main')
          .set(<String, dynamic>{key: value}, SetOptions(merge: true));
      NotificationSettingsService.instance.invalidate(user.uid);
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

  @override
  Widget build(BuildContext context) {
    return SettingsSubpageWidgets.shell(
      context: context,
      title: 'Mentions & Tags',
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
              title: 'Mentions',
              subtitle: 'Control who can mention you',
              children: <Widget>[
                SettingsSubpageWidgets.dropdownRow(
                  context: context,
                  icon: Icons.alternate_email,
                  title: 'Who can mention you',
                  subtitle: 'Control mention permissions',
                  value: _allowMentions,
                  options: const <String>['everyone', 'followers', 'nobody'],
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _allowMentions = value);
                    _updatePrivacySetting('allowMentions', value);
                  },
                ),
                SettingsSubpageWidgets.switchRow(
                  context: context,
                  icon: Icons.notifications_outlined,
                  title: 'Mention Notifications',
                  subtitle: 'Get notified when someone mentions you',
                  value: _allowMentionNotifications,
                  onChanged: (bool value) {
                    setState(() => _allowMentionNotifications = value);
                    _updateNotificationSetting('mentions', value);
                  },
                  showDivider: false,
                ),
              ],
            ),
            const SizedBox(height: 32),
            SettingsSubpageWidgets.section(
              context: context,
              title: 'Tags',
              subtitle: 'Control who can tag you',
              children: <Widget>[
                SettingsSubpageWidgets.switchRow(
                  context: context,
                  icon: Icons.local_offer_outlined,
                  title: 'Allow Tags',
                  subtitle: 'Let people tag you in videos and posts',
                  value: _allowTags,
                  onChanged: (bool value) {
                    setState(() => _allowTags = value);
                    _updatePrivacySetting('allowTags', value);
                  },
                ),
                SettingsSubpageWidgets.switchRow(
                  context: context,
                  icon: Icons.notifications_outlined,
                  title: 'Tag Notifications',
                  subtitle: 'Get notified when someone tags you',
                  value: _allowTagNotifications,
                  onChanged: (bool value) {
                    setState(() => _allowTagNotifications = value);
                    _updateNotificationSetting('tags', value);
                  },
                  showDivider: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
