import 'package:flutter_riverpod/flutter_riverpod.dart';

class UploadManagerState {
  final bool isUploading;
  final double progress; // 0.0 - 1.0
  final String tipText;
  final String currentTitle;

  const UploadManagerState({
    required this.isUploading,
    required this.progress,
    required this.tipText,
    required this.currentTitle,
  });

  factory UploadManagerState.initial() => const UploadManagerState(
        isUploading: false,
        progress: 0.0,
        tipText: 'Add a title to get more likes 👍',
        currentTitle: '',
      );

  UploadManagerState copyWith({
    bool? isUploading,
    double? progress,
    String? tipText,
    String? currentTitle,
  }) {
    return UploadManagerState(
      isUploading: isUploading ?? this.isUploading,
      progress: progress ?? this.progress,
      tipText: tipText ?? this.tipText,
      currentTitle: currentTitle ?? this.currentTitle,
    );
  }
}

class UploadManager extends StateNotifier<UploadManagerState> {
  UploadManager() : super(UploadManagerState.initial());

  void startUpload(String title) {
    state = state.copyWith(
      isUploading: true,
      progress: 0.0,
      currentTitle: title,
    );
  }

  void updateProgress(double value) {
    final clamped = value.clamp(0.0, 1.0);
    state = state.copyWith(progress: clamped);
  }

  void finishUpload() {
    state = state.copyWith(
      isUploading: false,
      progress: 1.0,
      tipText: 'Hurray! Make sure to share with your Friends',
    );
    // Soft reset after UX delay
    Future<void>.delayed(const Duration(seconds: 2), () {
      state = state.copyWith(
        tipText: 'Add a title to get more likes 👍',
        progress: 0.0,
        currentTitle: '',
      );
    });
  }

  void failUpload() {
    state = state.copyWith(isUploading: false);
  }
}

final uploadManagerProvider =
    StateNotifierProvider<UploadManager, UploadManagerState>((ref) {
  return UploadManager();
});
