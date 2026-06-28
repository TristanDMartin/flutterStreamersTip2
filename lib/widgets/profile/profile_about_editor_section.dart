import 'package:flutter/material.dart';

import 'editable_profile_field.dart';

class ProfileAboutEditorSection extends StatelessWidget {
  const ProfileAboutEditorSection({
    super.key,
    required this.user,
    required this.onEditField,
    this.canChangeName = true,
    this.showNameRow = true,
    this.showUsernameRow = true,
    this.showPlatformsRow = false,
    this.onNameLockedTap,
    this.onEditPlatforms,
  });

  final Map<String, dynamic> user;
  final ValueChanged<EditableProfileField> onEditField;
  final bool canChangeName;
  final bool showNameRow;
  final bool showUsernameRow;
  final bool showPlatformsRow;
  final VoidCallback? onNameLockedTap;
  final VoidCallback? onEditPlatforms;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color on = cs.onSurface;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            child: Text(
              'About',
              style: TextStyle(
                color: on,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: on.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: cs.outline.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              children: <Widget>[
                if (showNameRow) ...<Widget>[
                  _ProfileFieldRow(
                    label: EditableProfileField.name.title,
                    value: (user['displayName'] as String?) ?? '',
                    isLocked: !canChangeName,
                    onTap: canChangeName
                        ? () => onEditField(EditableProfileField.name)
                        : onNameLockedTap,
                  ),
                  _ProfileSectionDivider(),
                ],
                if (showUsernameRow) ...<Widget>[
                  _UsernameRow(
                    username: (user['username'] as String?) ?? '',
                  ),
                  _ProfileSectionDivider(),
                ],
                _ProfileFieldRow(
                  label: EditableProfileField.bio.title,
                  value: (user['bio'] as String?) ?? '',
                  onTap: () => onEditField(EditableProfileField.bio),
                ),
                if (showPlatformsRow) ...<Widget>[
                  _ProfileSectionDivider(),
                  _PlatformsRow(
                    platformCount: _linkedPlatformCount(user),
                    onTap: onEditPlatforms,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static int _linkedPlatformCount(Map<String, dynamic> user) {
    final Object? raw = user['platforms'];
    if (raw is! List) {
      return 0;
    }
    return raw.where((Object? item) {
      if (item is! Map) {
        return false;
      }
      final String username = (item['username'] as String?)?.trim() ?? '';
      final String url = (item['url'] as String?)?.trim() ?? '';
      return username.isNotEmpty || url.isNotEmpty;
    }).length;
  }
}

class _PlatformsRow extends StatelessWidget {
  const _PlatformsRow({
    required this.platformCount,
    required this.onTap,
  });

  final int platformCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color on = cs.onSurface;
    final Color muted = on.withValues(alpha: 0.45);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: on.withValues(alpha: 0.03),
        ),
        child: Row(
          children: <Widget>[
            Text(
              'Platforms',
              style: TextStyle(
                color: on,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (platformCount > 0)
              Text(
                '$platformCount platform${platformCount == 1 ? '' : 's'}',
                style: TextStyle(
                  color: on.withValues(alpha: 0.72),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: muted, size: 16),
          ],
        ),
      ),
    );
  }
}

class _ProfileFieldRow extends StatelessWidget {
  const _ProfileFieldRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.isLocked = false,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color on = cs.onSurface;
    final Color muted = on.withValues(alpha: 0.45);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isLocked
              ? on.withValues(alpha: 0.06)
              : on.withValues(alpha: 0.03),
        ),
        child: Row(
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                color: isLocked ? muted : on,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (value.isNotEmpty)
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: isLocked ? muted : on.withValues(alpha: 0.72),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (isLocked) ...<Widget>[
              Icon(Icons.lock, color: muted, size: 16),
              const SizedBox(width: 8),
            ],
            Icon(
              isLocked ? Icons.info_outline : Icons.chevron_right,
              color: muted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _UsernameRow extends StatelessWidget {
  const _UsernameRow({required this.username});

  final String username;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color on = cs.onSurface;
    final Color muted = on.withValues(alpha: 0.45);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: on.withValues(alpha: 0.03),
      ),
      child: Row(
        children: <Widget>[
          Text(
            'Username',
            style: TextStyle(
              color: on,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            username.isEmpty ? '@' : '@$username',
            style: TextStyle(
              color: on.withValues(alpha: 0.72),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.lock, color: muted, size: 16),
        ],
      ),
    );
  }
}

class _ProfileSectionDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Color on = Theme.of(context).colorScheme.onSurface;
    return Container(
      margin: const EdgeInsets.only(left: 18),
      height: 1,
      color: on.withValues(alpha: 0.1),
    );
  }
}
