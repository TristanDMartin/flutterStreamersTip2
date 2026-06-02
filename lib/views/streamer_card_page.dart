import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import '../models/user.dart';
import '../constants/app_colors.dart';

class StreamerCardPage extends StatelessWidget {
  final User user;
  const StreamerCardPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.supportSurfaceGradient,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _Header(onBack: () => Navigator.pop(context)),
                const SizedBox(height: 16),
                _Avatar(user: user),
                const SizedBox(height: 16),
                Text(
                  user.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  '@${user.username}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _GlassButton(
                        title: 'Follow', onTap: () => _followUser(context)),
                    const SizedBox(width: 12),
                    _FilledButton(title: 'Share', onTap: () {}),
                  ],
                ),
                const SizedBox(height: 24),
                _SegmentedTabs(),
                const SizedBox(height: 24),
                const _EmptyState(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _followUser(BuildContext context) async {
    final uid = fa.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid == user.id) return;

    try {
      // Check if already following
      final existing = await FirebaseFirestore.instance
          .collection('relationships')
          .where('followerId', isEqualTo: uid)
          .where('followingId', isEqualTo: user.id)
          .get();

      if (existing.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('relationships').add({
          'followerId': uid,
          'followingId': user.id,
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Now following ${user.displayName}!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Already following ${user.displayName}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error following user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onBack,
          borderRadius: BorderRadius.circular(20),
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.chevron_left, color: Colors.white),
          ),
        ),
        const Spacer(),
        const SizedBox(width: 44),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final User user;
  const _Avatar({required this.user});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.1),
      ),
      child: const Icon(Icons.person, color: Colors.white70, size: 40),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipOval(
          child: user.avatarURL != null
              ? Image.network(
                  user.avatarURL!,
                  width: 112,
                  height: 112,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => fallback,
                )
              : fallback,
        ),
        Positioned(
          top: -2,
          right: -2,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getStatusColor(user.onlineStatus),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color:
                      _getStatusColor(user.onlineStatus).withValues(alpha: 0.5),
                  blurRadius: 6,
                )
              ],
            ),
          ),
        )
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'online':
        return Colors.green;
      case 'offline':
        return Colors.grey;
      case 'busy':
        return Colors.orange;
      case 'dnd':
        return Colors.red;
      case 'streaming':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

class _GlassButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  const _GlassButton({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(24),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
        ),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _FilledButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  const _FilledButton({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          title,
          style: const TextStyle(
            color: AppColors.supportAccent,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SegmentedTabs extends StatefulWidget {
  @override
  State<_SegmentedTabs> createState() => _SegmentedTabsState();
}

class _SegmentedTabsState extends State<_SegmentedTabs> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.15), width: 1),
          ),
          child: Row(
            children: [
              _seg('Video', 0),
              _seg('Favorites', 1),
              _seg('Tagged', 2),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_index == 0)
          const _EmptyState()
        else if (_index == 1)
          const _EmptyState(label: 'No favorites yet.')
        else
          const _EmptyState(label: 'No tagged posts.'),
      ],
    );
  }

  Widget _seg(String label, int i) {
    final bool sel = _index == i;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _index = i),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: sel
              ? BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25), width: 1),
                )
              : null,
          child: Text(
            label,
            style: TextStyle(
              color: sel ? Colors.white : Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String label;
  const _EmptyState({this.label = 'No content yet.'});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.video_library_outlined,
          size: 48,
          color: Colors.white.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 16),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
