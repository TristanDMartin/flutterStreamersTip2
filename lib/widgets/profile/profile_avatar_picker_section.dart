import 'dart:io';

import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

class ProfileAvatarPickerSection extends StatelessWidget {
  const ProfileAvatarPickerSection({
    super.key,
    required this.avatarUrl,
    required this.selectedImage,
    required this.isUploading,
    required this.uploadError,
    required this.onTap,
  });

  final String? avatarUrl;
  final File? selectedImage;
  final bool isUploading;
  final String? uploadError;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color on = cs.onSurface;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: on.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.35),
        ),
      ),
      child: GestureDetector(
        onTap: isUploading ? null : onTap,
        child: Column(
          children: <Widget>[
            Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Container(
                  width: 124,
                  height: 124,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppColors.supportAccentGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(3),
                  child: _AvatarContent(
                    avatarUrl: avatarUrl,
                    selectedImage: selectedImage,
                    isUploading: isUploading,
                  ),
                ),
                if (!isUploading)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.supportAccent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: on.withValues(alpha: 0.28),
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.supportAccent
                                .withValues(alpha: 0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _AvatarStatusText(
              isUploading: isUploading,
              uploadError: uploadError,
            ),
            const SizedBox(height: 6),
            Text(
              isUploading
                  ? 'We are updating your profile image now.'
                  : 'Choose a photo or avatar that represents your profile.',
              style: TextStyle(
                color: on.withValues(alpha: 0.66),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
            if (uploadError != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Upload failed. Tap to try again.',
                style: TextStyle(
                  color: cs.error,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AvatarStatusText extends StatelessWidget {
  const _AvatarStatusText({
    required this.isUploading,
    required this.uploadError,
  });

  final bool isUploading;
  final String? uploadError;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color on = cs.onSurface;
    if (isUploading) {
      return Text(
        'Uploading...',
        style: TextStyle(
          color: on,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    if (uploadError != null) {
      return Text(
        'Upload failed',
        style: TextStyle(
          color: cs.error,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    return Text(
      'Edit photo or avatar',
      style: TextStyle(
        color: on,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _AvatarContent extends StatelessWidget {
  const _AvatarContent({
    required this.avatarUrl,
    required this.selectedImage,
    required this.isUploading,
  });

  final String? avatarUrl;
  final File? selectedImage;
  final bool isUploading;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color fill = cs.surfaceContainerHighest;
    if (isUploading) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: cs.primary,
            strokeWidth: 3,
          ),
        ),
      );
    }
    if (selectedImage != null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Image.file(
            selectedImage!,
            width: 120,
            height: 120,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Image.network(
            avatarUrl!,
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            errorBuilder: (
              BuildContext context,
              Object error,
              StackTrace? stackTrace,
            ) =>
                Icon(
              Icons.person,
              size: 40,
              color: cs.onSurface.withValues(alpha: 0.45),
            ),
            loadingBuilder: (
              BuildContext context,
              Widget? child,
              ImageChunkEvent? progress,
            ) {
              if (progress == null) {
                return child!;
              }
              return Center(
                child: CircularProgressIndicator(
                  color: cs.primary,
                  strokeWidth: 2,
                ),
              );
            },
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.person,
          size: 40,
          color: cs.onSurface.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}
