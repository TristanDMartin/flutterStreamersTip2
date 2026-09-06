import 'dart:async';

import 'package:streamers_tip/utils/secure_log.dart';

import '../features/publish/video_draft.dart';
import 'video_draft_store.dart';
import 'video_render_service.dart';

/// Single-flight FFmpeg bake. Call only when no VideoPlayer holds the decoder.
class VideoRenderWarmup {
  VideoRenderWarmup._internal();

  static final VideoRenderWarmup instance = VideoRenderWarmup._internal();

  final Map<String, Future<VideoDraft>> _inflight =
      <String, Future<VideoDraft>>{};

  /// Fire-and-forget bake. Prefer [ensureRendered] after releasing players.
  void schedule(VideoDraft draft) {
    unawaited(ensureRendered(draft));
  }

  /// Returns a draft with a baked file. Coalesces concurrent callers.
  Future<VideoDraft> ensureRendered(VideoDraft draft) async {
    if (!draft.requiresRender) {
      return draft;
    }
    final VideoDraft? memory = VideoDraftStore.instance.peek(draft.draftId);
    if (memory != null &&
        memory.renderStatus == VideoDraftRenderStatus.ready &&
        memory.hasRenderableOutput &&
        _isSameEditFingerprint(memory, draft)) {
      return memory;
    }
    if (draft.renderStatus == VideoDraftRenderStatus.ready &&
        draft.hasRenderableOutput) {
      return draft;
    }
    final Future<VideoDraft>? existing = _inflight[draft.draftId];
    if (existing != null) {
      final VideoDraft warmed = await existing;
      if (warmed.renderStatus == VideoDraftRenderStatus.ready &&
          warmed.hasRenderableOutput &&
          _isSameEditFingerprint(warmed, draft)) {
        return warmed;
      }
      // Prior job finished with a different/failed result — bake this draft.
    }
    final Future<VideoDraft> future = _run(draft);
    _inflight[draft.draftId] = future;
    try {
      return await future;
    } finally {
      if (identical(_inflight[draft.draftId], future)) {
        _inflight.remove(draft.draftId);
      }
    }
  }

  bool _isSameEditFingerprint(VideoDraft a, VideoDraft b) {
    return a.trimStart == b.trimStart &&
        a.trimEnd == b.trimEnd &&
        a.manualCaptionText == b.manualCaptionText &&
        a.captionsEnabled == b.captionsEnabled &&
        a.textLayers.length == b.textLayers.length;
  }

  Future<VideoDraft> _run(VideoDraft draft) async {
    secureLog('VideoRenderWarmup: start ${draft.draftId}');
    try {
      final VideoRenderResult result =
          await VideoRenderService.instance.renderDraft(draft);
      if (!result.success || result.outputFile == null) {
        final VideoDraft failed = draft.copyWith(
          renderStatus: VideoDraftRenderStatus.failed,
          renderError: result.errorMessage,
          clearRenderedFile: true,
          updatedAt: DateTime.now(),
        );
        await VideoDraftStore.instance.saveNow(failed);
        return failed;
      }
      final VideoDraft ready = draft.copyWith(
        renderStatus: VideoDraftRenderStatus.ready,
        renderedFilePath: result.outputFile!.path,
        clearRenderError: true,
        updatedAt: DateTime.now(),
      );
      await VideoDraftStore.instance.saveNow(ready);
      secureLog('VideoRenderWarmup: ready ${draft.draftId}');
      return ready;
    } catch (e, st) {
      secureLog('VideoRenderWarmup failed: $e\n$st');
      final VideoDraft failed = draft.copyWith(
        renderStatus: VideoDraftRenderStatus.failed,
        renderError: '$e',
        clearRenderedFile: true,
        updatedAt: DateTime.now(),
      );
      await VideoDraftStore.instance.saveNow(failed);
      return failed;
    }
  }
}
