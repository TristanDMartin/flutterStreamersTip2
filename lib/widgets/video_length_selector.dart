import 'package:flutter/material.dart';

enum VideoLength {
  short15s(Duration(seconds: 15), '15s'),
  medium60s(Duration(seconds: 60), '60s'),
  long3m(Duration(minutes: 3), '3m');

  const VideoLength(this.duration, this.label);
  final Duration duration;
  final String label;
}

class VideoLengthSelector extends StatelessWidget {
  final VideoLength? selectedLength;
  final Function(VideoLength) onLengthSelected;

  const VideoLengthSelector({
    super.key,
    required this.selectedLength,
    required this.onLengthSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: VideoLength.values.map((length) {
        final isSelected = selectedLength == length;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => onLengthSelected(length),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    length.label,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
