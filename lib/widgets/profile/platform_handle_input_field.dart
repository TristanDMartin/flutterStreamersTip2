import 'package:flutter/material.dart';

import '../../utils/platform_rules.dart';

class PlatformHandleInputField extends StatelessWidget {
  const PlatformHandleInputField({
    super.key,
    required this.platformType,
    required this.controller,
    required this.onChanged,
    this.onClear,
  });

  final String platformType;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final String prefix = PlatformRules.displayUrlPrefix(platformType);
    final String? preview = PlatformRules.previewPlatformUrl(
      platformType,
      controller.text,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Flexible(
                flex: 0,
                child: Text(
                  prefix,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: (_) => onChanged(),
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.none,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: PlatformRules.handleHintForType(platformType),
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: controller,
                builder: (BuildContext context, Widget? child) {
                  if (controller.text.isEmpty || onClear == null) {
                    return const SizedBox.shrink();
                  }
                  return GestureDetector(
                    onTap: onClear,
                    child: const Icon(
                      Icons.clear,
                      color: Colors.grey,
                      size: 20,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        if (preview != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            'Preview: $preview',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
