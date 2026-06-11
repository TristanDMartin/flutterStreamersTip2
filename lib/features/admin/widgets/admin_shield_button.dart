import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Premium shield entry (gradient #9248D2 → #4897D2 on #1e293b).
class AdminShieldButton extends StatefulWidget {
  const AdminShieldButton({
    super.key,
    required this.onPressed,
    this.showTicketBadge = false,
  });

  final Future<void> Function() onPressed;
  final bool showTicketBadge;

  @override
  State<AdminShieldButton> createState() => _AdminShieldButtonState();
}

class _AdminShieldButtonState extends State<AdminShieldButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _scale;

  static const Color _c1 = Color(0xFF9248D2);
  static const Color _c2 = Color(0xFF4897D2);
  static const Color _bg = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _scale = Tween<double>(begin: 1, end: 0.92).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    await _c.forward();
    await _c.reverse();
    HapticFeedback.lightImpact();
    await widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _tap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x559248D2),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [_c1, _c2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: const Icon(Icons.shield_rounded, size: 22),
                  ),
                  const SizedBox(width: 6),
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [_c1, _c2],
                    ).createShader(bounds),
                    child: Text(
                      'Admin',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                    ),
                  ),
                  if (widget.showTicketBadge) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
