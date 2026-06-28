import 'package:flutter/material.dart';

import 'profile_username_availability_controller.dart';
import 'profile_username_rules.dart';

class ProfileCreatorIdentityFields extends StatefulWidget {
  const ProfileCreatorIdentityFields({
    super.key,
    required this.displayName,
    required this.username,
    required this.onDisplayNameChanged,
    required this.onUsernameChanged,
    required this.usernameStatus,
    this.usernameStatusMessage,
  });

  final String displayName;
  final String username;
  final ValueChanged<String> onDisplayNameChanged;
  final ValueChanged<String> onUsernameChanged;
  final UsernameAvailabilityStatus usernameStatus;
  final String? usernameStatusMessage;

  @override
  State<ProfileCreatorIdentityFields> createState() =>
      _ProfileCreatorIdentityFieldsState();
}

class _ProfileCreatorIdentityFieldsState
    extends State<ProfileCreatorIdentityFields> {
  late TextEditingController _displayNameController;
  late TextEditingController _usernameController;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(text: widget.displayName);
    _usernameController = TextEditingController(text: widget.username);
  }

  @override
  void didUpdateWidget(ProfileCreatorIdentityFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.displayName != oldWidget.displayName &&
        widget.displayName != _displayNameController.text) {
      _displayNameController.text = widget.displayName;
    }
    if (widget.username != oldWidget.username &&
        widget.username != _usernameController.text) {
      _usernameController.text = widget.username;
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color on = cs.onSurface;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: on.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Identity',
            style: TextStyle(
              color: on,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _IdentityField(
            label: 'Display Name',
            controller: _displayNameController,
            hintText: 'Your creator name',
            onChanged: widget.onDisplayNameChanged,
          ),
          const SizedBox(height: 16),
          _IdentityField(
            label: 'Username',
            controller: _usernameController,
            hintText: 'username',
            prefixText: '@',
            onChanged: widget.onUsernameChanged,
          ),
          const SizedBox(height: 6),
          Text(
            ProfileUsernameRules.helperLine,
            style: TextStyle(
              color: on.withValues(alpha: 0.62),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            ProfileUsernameRules.formatLine,
            style: TextStyle(
              color: on.withValues(alpha: 0.52),
              fontSize: 12,
            ),
          ),
          if (widget.usernameStatusMessage != null &&
              widget.usernameStatus != UsernameAvailabilityStatus.idle) ...<Widget>[
            const SizedBox(height: 8),
            _UsernameStatusLine(
              status: widget.usernameStatus,
              message: widget.usernameStatusMessage!,
            ),
          ],
        ],
      ),
    );
  }
}

class _IdentityField extends StatelessWidget {
  const _IdentityField({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.prefixText,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final String? prefixText;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color on = cs.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: on.withValues(alpha: 0.82),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: TextStyle(
              color: on,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              prefixText: prefixText,
              filled: true,
              fillColor: on.withValues(alpha: 0.05),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: cs.outline.withValues(alpha: 0.35),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: cs.outline.withValues(alpha: 0.35),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: cs.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UsernameStatusLine extends StatelessWidget {
  const _UsernameStatusLine({
    required this.status,
    required this.message,
  });

  final UsernameAvailabilityStatus status;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    Color color = cs.onSurface.withValues(alpha: 0.62);
    if (status == UsernameAvailabilityStatus.available) {
      color = Colors.greenAccent.shade400;
    } else if (status == UsernameAvailabilityStatus.checking) {
      color = cs.primary;
    } else if (status == UsernameAvailabilityStatus.taken ||
        status == UsernameAvailabilityStatus.invalid ||
        status == UsernameAvailabilityStatus.tooShort ||
        status == UsernameAvailabilityStatus.error) {
      color = cs.error;
    }
    return Row(
      children: <Widget>[
        if (status == UsernameAvailabilityStatus.checking)
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: color,
            ),
          ),
        if (status == UsernameAvailabilityStatus.checking)
          const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
