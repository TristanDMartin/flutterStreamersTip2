import 'package:flutter/material.dart';
import '../utils/constants.dart';

class PageTemplate extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const PageTemplate({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.showBackButton = true,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: showBackButton
            ? IconButton(
                icon: const Icon(
                  Icons.chevron_left,
                  color: AppColors.primary,
                  size: 32,
                ),
                onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          title,
          style: AppTextStyles.h2,
        ),
        centerTitle: true,
        actions: actions,
      ),
      body: body,
    );
  }
}
