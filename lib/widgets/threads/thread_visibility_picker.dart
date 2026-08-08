import 'package:flutter/material.dart';

import '../../features/threads/thread_visibility.dart';

/// Public / Followers / Invite picker matching website CommentsView.
class ThreadVisibilityPicker extends StatelessWidget {
  const ThreadVisibilityPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final String selected = normalizeThreadVisibility(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Visibility',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kThreadVisibilityValues.map((String option) {
            final bool isSelected = selected == option;
            return ChoiceChip(
              label: Text(threadVisibilityIconLabel(option)),
              selected: isSelected,
              onSelected: enabled
                  ? (bool selectedNow) {
                      if (selectedNow) {
                        onChanged(option);
                      }
                    }
                  : null,
              selectedColor: const Color(0xFF9248D2),
              backgroundColor: Colors.grey[900],
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF9248D2)
                    : Colors.white24,
              ),
            );
          }).toList(growable: false),
        ),
      ],
    );
  }
}
