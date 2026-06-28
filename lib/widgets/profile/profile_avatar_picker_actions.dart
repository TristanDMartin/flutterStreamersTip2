import 'dart:io';

import 'package:flutter/material.dart';

import '../../routing/navigation_context.dart';
import '../image_picker_widget.dart';

abstract final class ProfileAvatarPickerActions {
  static void showImagePicker(
    BuildContext context, {
    required void Function(File imageFile) onImageSelected,
    VoidCallback? onRemovePhoto,
    bool hasExistingPhoto = false,
  }) {
    if (!NavigationContext.canNavigate(context)) {
      return;
    }
    final BuildContext navigatorContext =
        NavigationContext.requireForNavigation(context);
    showModalBottomSheet<void>(
      context: navigatorContext,
      isScrollControlled: true,
      useRootNavigator: NavigationContext.shouldUseRootNavigator(context),
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return ImagePickerWidget(
          hasExistingPhoto: hasExistingPhoto,
          onRemovePhoto: onRemovePhoto,
          onImageSelected: (File imageFile) {
            Navigator.of(sheetContext).pop();
            onImageSelected(imageFile);
          },
          onCancel: () => Navigator.of(sheetContext).pop(),
        );
      },
    );
  }
}
