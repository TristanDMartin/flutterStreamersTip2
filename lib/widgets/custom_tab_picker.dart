import 'package:flutter/material.dart';

class CustomTabPicker extends StatefulWidget {
  final int selectedTab;
  final Function(int) onTabChanged;
  
  const CustomTabPicker({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
  });

  @override
  State<CustomTabPicker> createState() => _CustomTabPickerState();
}

class _CustomTabPickerState extends State<CustomTabPicker>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  // late Animation<double> _animation; // Unused field commented out
  
  final List<String> tabs = ["Photos", "Video", "Tagged"];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    // _animation = CurvedAnimation(
    //   parent: _animationController,
    //   curve: Curves.easeInOut,
    // );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTabTap(int index) {
    if (widget.selectedTab != index) {
      _animationController.forward().then((_) {
        _animationController.reverse();
      });
      widget.onTabChanged(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          tabs.length,
          (index) => Container(
            margin: EdgeInsets.only(right: index < tabs.length - 1 ? 30 : 0),
            child: GestureDetector(
              onTap: () => _onTabTap(index),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: widget.selectedTab == index 
                      ? FontWeight.w700 
                      : FontWeight.w500,
                  color: widget.selectedTab == index 
                      ? Colors.white 
                      : Colors.grey,
                ),
                child: Text(tabs[index]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
