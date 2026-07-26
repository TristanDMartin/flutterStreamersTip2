import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings/settings_subpage_widgets.dart';
import '../services/notification_settings_service.dart';
import '../utils/user_facing_error.dart';

class NotificationsView extends ConsumerStatefulWidget {
  const NotificationsView({super.key});

  @override
  ConsumerState<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends ConsumerState<NotificationsView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;
  String? _actionError;
  bool _pushNotifications = true;
  bool _emailEnabled = true;
  bool _digestWeekly = true;
  bool _smsNotifications = false;
  bool _followNotifications = true;
  bool _likeNotifications = true;
  bool _commentNotifications = true;
  bool _mentionNotifications = true;
  bool _tagNotifications = true;
  bool _messageNotifications = true;
  bool _liveNotifications = true;
  bool _progressionNotifications = true;
  bool _momentumReminders = true;
  bool _streakProtection = true;
  bool _missionUpdates = true;
  bool _levelUps = true;
  bool _weeklyRecap = true;

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
        _loadError = 'Please sign in to manage notification settings.';
      });
      return;
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notificationSettings')
          .doc('main')
          .get();
      if (mounted) {
        setState(() {
          if (doc.exists && doc.data() != null) {
            final Map<String, dynamic> data = doc.data()!;
            _pushNotifications = data['pushNotifications'] ?? true;
            _emailEnabled = data['emailEnabled'] as bool? ??
                data['emailNotifications'] as bool? ??
                true;
            _digestWeekly = data['digestWeekly'] as bool? ?? true;
            _smsNotifications = data['smsNotifications'] ?? false;
            _followNotifications = data['follows'] ?? true;
            _likeNotifications = data['likes'] ?? true;
            _commentNotifications = data['comments'] ?? true;
            _mentionNotifications = data['mentions'] ?? true;
            _tagNotifications = data['tags'] ?? true;
            _messageNotifications = data['messages'] ?? true;
            _liveNotifications = data['live'] ?? true;
            _progressionNotifications =
                data['progressionNotifications'] ?? true;
            _momentumReminders = data['momentumReminders'] ?? true;
            _streakProtection = data['streakProtection'] ?? true;
            _missionUpdates = data['missionUpdates'] ?? true;
            _levelUps = data['levelUps'] ?? true;
            _weeklyRecap = data['weeklyRecap'] ?? true;
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
      final Map<String, dynamic> updates = <String, dynamic>{
        key: value,
        'quietHoursStart': '22:00',
        'quietHoursEnd': '08:00',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (key == 'emailEnabled') {
        updates['emailNotifications'] = value;
      }
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notificationSettings')
          .doc('main')
          .set(updates, SetOptions(merge: true));
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

  Widget _toggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required String key,
  }) {
    return SettingsSubpageWidgets.switchRow(
      context: context,
      icon: icon,
      title: title,
      subtitle: subtitle,
      value: value,
      onChanged: (bool next) {
        setState(() {
          switch (key) {
            case 'pushNotifications':
              _pushNotifications = next;
            case 'emailEnabled':
              _emailEnabled = next;
            case 'digestWeekly':
              _digestWeekly = next;
            case 'smsNotifications':
              _smsNotifications = next;
            case 'follows':
              _followNotifications = next;
            case 'likes':
              _likeNotifications = next;
            case 'comments':
              _commentNotifications = next;
            case 'mentions':
              _mentionNotifications = next;
            case 'tags':
              _tagNotifications = next;
            case 'messages':
              _messageNotifications = next;
            case 'live':
              _liveNotifications = next;
            case 'progressionNotifications':
              _progressionNotifications = next;
            case 'momentumReminders':
              _momentumReminders = next;
            case 'streakProtection':
              _streakProtection = next;
            case 'missionUpdates':
              _missionUpdates = next;
            case 'levelUps':
              _levelUps = next;
            case 'weeklyRecap':
              _weeklyRecap = next;
          }
        });
        _updateSetting(key, next);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSubpageWidgets.shell(
      context: context,
      title: 'Notifications',
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
              title: 'General',
              subtitle: 'Basic notification settings',
              children: <Widget>[
                _toggle(
                  icon: Icons.notifications_active,
                  title: 'Push Notifications',
                  subtitle: 'Receive push notifications on your device',
                  value: _pushNotifications,
                  key: 'pushNotifications',
                ),
                _toggle(
                  icon: Icons.email_outlined,
                  title: 'Journey & onboarding emails',
                  subtitle:
                      'Tips to connect platforms, plan content, and stay consistent',
                  value: _emailEnabled,
                  key: 'emailEnabled',
                ),
                _toggle(
                  icon: Icons.insights_outlined,
                  title: 'Weekly growth snapshot',
                  subtitle:
                      'Monday email summary of consistency score and content progress',
                  value: _digestWeekly,
                  key: 'digestWeekly',
                ),
                _toggle(
                  icon: Icons.sms_outlined,
                  title: 'SMS Notifications',
                  subtitle: 'Receive notifications via SMS',
                  value: _smsNotifications,
                  key: 'smsNotifications',
                ),
              ],
            ),
            const SizedBox(height: 32),
            SettingsSubpageWidgets.section(
              context: context,
              title: 'Social Activity',
              subtitle: 'Notifications for social interactions',
              children: <Widget>[
                _toggle(
                  icon: Icons.person_add,
                  title: 'New Followers',
                  subtitle: 'Get notified when someone follows you',
                  value: _followNotifications,
                  key: 'follows',
                ),
                _toggle(
                  icon: Icons.favorite,
                  title: 'Likes',
                  subtitle: 'Get notified when someone likes your content',
                  value: _likeNotifications,
                  key: 'likes',
                ),
                _toggle(
                  icon: Icons.comment,
                  title: 'Comments',
                  subtitle: 'Get notified when someone comments',
                  value: _commentNotifications,
                  key: 'comments',
                ),
              ],
            ),
            const SizedBox(height: 32),
            SettingsSubpageWidgets.section(
              context: context,
              title: 'Mentions & Tags',
              subtitle: 'Notifications for mentions and tags',
              children: <Widget>[
                _toggle(
                  icon: Icons.alternate_email,
                  title: 'Mentions',
                  subtitle: 'Get notified when someone mentions you',
                  value: _mentionNotifications,
                  key: 'mentions',
                ),
                _toggle(
                  icon: Icons.label,
                  title: 'Tags',
                  subtitle: 'Get notified when someone tags you',
                  value: _tagNotifications,
                  key: 'tags',
                ),
              ],
            ),
            const SizedBox(height: 32),
            SettingsSubpageWidgets.section(
              context: context,
              title: 'Progression & Momentum',
              subtitle:
                  'Creator-focused reminders for streaks, missions, and rewards',
              children: <Widget>[
                _toggle(
                  icon: Icons.rocket_launch,
                  title: 'Progression Notifications',
                  subtitle: 'Enable creator momentum notifications',
                  value: _progressionNotifications,
                  key: 'progressionNotifications',
                ),
                _toggle(
                  icon: Icons.bolt,
                  title: 'Daily Momentum',
                  subtitle: 'Smart reminders near your usual active window',
                  value: _momentumReminders,
                  key: 'momentumReminders',
                ),
                _toggle(
                  icon: Icons.local_fire_department,
                  title: 'Streak Protection',
                  subtitle: 'Evening reminders when your streak needs action',
                  value: _streakProtection,
                  key: 'streakProtection',
                ),
                _toggle(
                  icon: Icons.flag,
                  title: 'Mission Updates',
                  subtitle: 'Reminders when you are close to mission rewards',
                  value: _missionUpdates,
                  key: 'missionUpdates',
                ),
                _toggle(
                  icon: Icons.workspace_premium,
                  title: 'Level Ups',
                  subtitle: 'Instant reward notifications when your rank grows',
                  value: _levelUps,
                  key: 'levelUps',
                ),
                _toggle(
                  icon: Icons.insights,
                  title: 'Weekly Recap',
                  subtitle: 'Weekly XP, streak, mission, and score summary',
                  value: _weeklyRecap,
                  key: 'weeklyRecap',
                ),
              ],
            ),
            const SizedBox(height: 32),
            SettingsSubpageWidgets.section(
              context: context,
              title: 'Messages',
              subtitle: 'Notification settings for messages',
              children: <Widget>[
                _toggle(
                  icon: Icons.chat_bubble,
                  title: 'Direct Messages',
                  subtitle: 'Get notified when you receive a message',
                  value: _messageNotifications,
                  key: 'messages',
                ),
              ],
            ),
            const SizedBox(height: 32),
            SettingsSubpageWidgets.section(
              context: context,
              title: 'Live & Events',
              subtitle: 'Notifications for live content and events',
              children: <Widget>[
                _toggle(
                  icon: Icons.videocam,
                  title: 'Live Streams',
                  subtitle: 'Get notified when someone goes live',
                  value: _liveNotifications,
                  key: 'live',
                ),
              ],
            ),
            const SizedBox(height: 32),
            SettingsSubpageWidgets.infoCard(
              context: context,
              title: 'About Notifications',
              body:
                  'Customize how and when you receive notifications. '
                  'You can control each type individually.',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
