import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pending_post.dart';
import 'publish_flow_tokens.dart';

class PreviewCropSheet extends StatelessWidget {
  const PreviewCropSheet({
    super.key,
    required this.selected,
    required this.isLandscape,
  });

  final PreviewCropMode selected;
  final bool isLandscape;

  static Future<PreviewCropMode?> show({
    required BuildContext context,
    required PreviewCropMode selected,
    required bool isLandscape,
  }) {
    return showModalBottomSheet<PreviewCropMode>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => PreviewCropSheet(
        selected: selected,
        isLandscape: isLandscape,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      decoration: PublishFlowTokens.glassPanel(radius: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Crop & aspect',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (isLandscape) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
              ),
              child: const Text(
                'Landscape clip — Fit shows the full frame. '
                '9:16 performs best in the feed.',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          _CropOption(
            label: 'Fit',
            subtitle: 'Show full video in frame',
            mode: PreviewCropMode.fit,
            selected: selected,
          ),
          _CropOption(
            label: 'Fill',
            subtitle: 'Crop to fill the frame',
            mode: PreviewCropMode.fill,
            selected: selected,
          ),
          _CropOption(
            label: '9:16',
            subtitle: 'Vertical feed frame',
            mode: PreviewCropMode.nineSixteen,
            selected: selected,
          ),
          _CropOption(
            label: '1:1',
            subtitle: 'Square frame',
            mode: PreviewCropMode.oneOne,
            selected: selected,
          ),
          _CropOption(
            label: 'Original',
            subtitle: 'Native aspect ratio',
            mode: PreviewCropMode.original,
            selected: selected,
          ),
        ],
      ),
    );
  }
}

class _CropOption extends StatelessWidget {
  const _CropOption({
    required this.label,
    required this.subtitle,
    required this.mode,
    required this.selected,
  });

  final String label;
  final String subtitle;
  final PreviewCropMode mode;
  final PreviewCropMode selected;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = mode == selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected
            ? PublishFlowTokens.primaryStart.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pop(mode);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
