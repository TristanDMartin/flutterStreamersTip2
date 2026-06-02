import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationsView extends ConsumerStatefulWidget {
  const NotificationsView({super.key});

  @override
  ConsumerState<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends ConsumerState<NotificationsView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  bool _isSaving = false;

  // Notification settings state
  bool _pushNotifications = true;
  bool _emailNotifications = false;
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
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notificationSettings')
          .doc('main')
          .get();

      if (mounted) {
        setState(() {
          if (doc.exists) {
            final data = doc.data()!;
            _pushNotifications = data['pushNotifications'] ?? true;
            _emailNotifications = data['emailNotifications'] ?? false;
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
          .collection('notificationSettings')
          .doc('main')
          .set({
        key: value,
        'quietHoursStart': '22:00',
        'quietHoursEnd': '08:00',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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
            'Notifications',
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
          'Notifications',
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
              'General',
              'Basic notification settings',
              [
                _buildSwitchSetting(
                  icon: Icons.notifications_active,
                  title: 'Push Notifications',
                  subtitle: 'Receive push notifications on your device',
                  value: _pushNotifications,
                  onChanged: (value) {
                    setState(() => _pushNotifications = value);
                    _updateSetting('pushNotifications', value);
                  },
                ),
                _buildSwitchSetting(
                  icon: Icons.email_outlined,
                  title: 'Email Notifications',
                  subtitle: 'Receive notifications via email',
                  value: _emailNotifications,
                  onChanged: (value) {
                    setState(() => _emailNotifications = value);
                    _updateSetting('emailNotifications', value);
                  },
                ),
                _buildSwitchSetting(
                  icon: Icons.sms_outlined,
                  title: 'SMS Notifications',
                  subtitle: 'Receive notifications via SMS',
                  value: _smsNotifications,
                  onChanged: (value) {
                    setState(() => _smsNotifications = value);
                    _updateSetting('smsNotifications', value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Social Activity',
              'Notifications for social interactions',
              [
                _buildSwitchSetting(
                  icon: Icons.person_add,
                  title: 'New Followers',
                  subtitle: 'Get notified when someone follows you',
                  value: _followNotifications,
                  onChanged: (value) {
                    setState(() => _followNotifications = value);
                    _updateSetting('follows', value);
                  },
                ),
                _buildSwitchSetting(
                  icon: Icons.favorite,
                  title: 'Likes',
                  subtitle: 'Get notified when someone likes your content',
                  value: _likeNotifications,
                  onChanged: (value) {
                    setState(() => _likeNotifications = value);
                    _updateSetting('likes', value);
                  },
                ),
                _buildSwitchSetting(
                  icon: Icons.comment,
                  title: 'Comments',
                  subtitle: 'Get notified when someone comments',
                  value: _commentNotifications,
                  onChanged: (value) {
                    setState(() => _commentNotifications = value);
                    _updateSetting('comments', value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Mentions & Tags',
              'Notifications for mentions and tags',
              [
                _buildSwitchSetting(
                  icon: Icons.alternate_email,
                  title: 'Mentions',
                  subtitle: 'Get notified when someone mentions you',
                  value: _mentionNotifications,
                  onChanged: (value) {
                    setState(() => _mentionNotifications = value);
                    _updateSetting('mentions', value);
                  },
                ),
                _buildSwitchSetting(
                  icon: Icons.label,
                  title: 'Tags',
                  subtitle: 'Get notified when someone tags you',
                  value: _tagNotifications,
                  onChanged: (value) {
                    setState(() => _tagNotifications = value);
                    _updateSetting('tags', value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Progression & Momentum',
              'Creator-focused reminders for streaks, missions, and rewards',
              [
                _buildSwitchSetting(
                  icon: Icons.rocket_launch,
                  title: 'Progression Notifications',
                  subtitle: 'Enable creator momentum notifications',
                  value: _progressionNotifications,
                  onChanged: (value) {
                    setState(() => _progressionNotifications = value);
                    _updateSetting('progressionNotifications', value);
                  },
                ),
                _buildSwitchSetting(
                  icon: Icons.bolt,
                  title: 'Daily Momentum',
                  subtitle: 'Smart reminders near your usual active window',
                  value: _momentumReminders,
                  onChanged: (value) {
                    setState(() => _momentumReminders = value);
                    _updateSetting('momentumReminders', value);
                  },
                ),
                _buildSwitchSetting(
                  icon: Icons.local_fire_department,
                  title: 'Streak Protection',
                  subtitle: 'Evening reminders when your streak needs action',
                  value: _streakProtection,
                  onChanged: (value) {
                    setState(() => _streakProtection = value);
                    _updateSetting('streakProtection', value);
                  },
                ),
                _buildSwitchSetting(
                  icon: Icons.flag,
                  title: 'Mission Updates',
                  subtitle: 'Reminders when you are close to mission rewards',
                  value: _missionUpdates,
                  onChanged: (value) {
                    setState(() => _missionUpdates = value);
                    _updateSetting('missionUpdates', value);
                  },
                ),
                _buildSwitchSetting(
                  icon: Icons.workspace_premium,
                  title: 'Level Ups',
                  subtitle: 'Instant reward notifications when your rank grows',
                  value: _levelUps,
                  onChanged: (value) {
                    setState(() => _levelUps = value);
                    _updateSetting('levelUps', value);
                  },
                ),
                _buildSwitchSetting(
                  icon: Icons.insights,
                  title: 'Weekly Recap',
                  subtitle: 'Weekly XP, streak, mission, and score summary',
                  value: _weeklyRecap,
                  onChanged: (value) {
                    setState(() => _weeklyRecap = value);
                    _updateSetting('weeklyRecap', value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Messages',
              'Notification settings for messages',
              [
                _buildSwitchSetting(
                  icon: Icons.chat_bubble,
                  title: 'Direct Messages',
                  subtitle: 'Get notified when you receive a message',
                  value: _messageNotifications,
                  onChanged: (value) {
                    setState(() => _messageNotifications = value);
                    _updateSetting('messages', value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Live & Events',
              'Notifications for live content and events',
              [
                _buildSwitchSetting(
                  icon: Icons.videocam,
                  title: 'Live Streams',
                  subtitle: 'Get notified when someone goes live',
                  value: _liveNotifications,
                  onChanged: (value) {
                    setState(() => _liveNotifications = value);
                    _updateSetting('live', value);
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
                  'About Notifications',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Customize how and when you receive notifications. You can control each type of notification individually.',
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
}
