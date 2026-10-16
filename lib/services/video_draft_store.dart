import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamers_tip/utils/secure_log.dart';

import '../features/publish/video_draft.dart';

/// Debounced local persistence for [VideoDraft] edit sessions.
class VideoDraftStore {
  VideoDraftStore._internal();

  static final VideoDraftStore instance = VideoDraftStore._internal();

  static const String _prefsKey = 'video_drafts_v1';
  static const Duration _debounce = Duration(milliseconds: 450);
  static const int _maxSaveRetries = 3;

  final Map<String, Timer> _debounceTimers = <String, Timer>{};
  final Map<String, VideoDraft> _memory = <String, VideoDraft>{};
  final Map<String, bool> _saveStatus = <String, bool>{}; // Track save success
  final Map<String, int> _saveRetryCount = <String, int>{}; // Track retry attempts

  String generateDraftId() {
    final int ts = DateTime.now().millisecondsSinceEpoch;
    final int rand = Random().nextInt(1 << 20);
    return 'vd_${ts}_$rand';
  }

  Future<Directory> draftsDirectory() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory dir = Directory(p.join(docs.path, 'VideoDrafts'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<VideoDraft> createFromSource({
    required File sourceFile,
    required Duration duration,
    required VideoDraftSourceType sourceType,
    int width = 0,
    int height = 0,
    double? aspectRatio,
  }) async {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final Directory dir = await draftsDirectory();
    final String draftId = generateDraftId();
    final String ext = p.extension(sourceFile.path).isEmpty
        ? '.mp4'
        : p.extension(sourceFile.path);
    final String destPath = p.join(dir.path, '${draftId}_source$ext');
    final String tempPath = p.join(dir.path, '${draftId}_source.tmp$ext');
    final int sourceBytes =
        await sourceFile.exists() ? await sourceFile.length() : 0;
    debugPrint(
      'CAMERA_FILE_AUDIT stage=draft_copy_before '
      'source=${sourceFile.path} sourceBytes=$sourceBytes '
      'destination=$destPath',
    );
    if (sourceFile.path != destPath) {
      // Gallery picks are often already a cache copy — try a same-volume
      // rename first so selection does not re-copy multi‑hundred‑MB clips.
      bool placed = false;
      if (sourceType == VideoDraftSourceType.gallery) {
        try {
          await sourceFile.rename(destPath);
          placed = true;
        } catch (_) {
          placed = false;
        }
      }
      if (!placed) {
        final File tempFile = await sourceFile.copy(tempPath);
        final int tempBytes = await tempFile.length();
        if (tempBytes <= 0 || tempBytes != sourceBytes) {
          try {
            await tempFile.delete();
          } catch (_) {}
          throw StateError(
            'Draft copy incomplete: source=$sourceBytes dest=$tempBytes',
          );
        }
        final File finalFile = File(destPath);
        if (await finalFile.exists()) {
          await finalFile.delete();
        }
        try {
          await tempFile.rename(destPath);
        } catch (_) {
          await tempFile.copy(destPath);
          try {
            await tempFile.delete();
          } catch (_) {}
        }
      }
    }
    final int destBytes =
        await File(destPath).exists() ? await File(destPath).length() : 0;
    debugPrint(
      'CAMERA_FILE_AUDIT stage=draft_copy_after '
      'destination=$destPath destinationBytes=$destBytes',
    );
    if (destBytes <= 0 || (sourceBytes > 0 && destBytes != sourceBytes)) {
      throw StateError(
        'Draft source invalid after copy: '
        'source=$sourceBytes dest=$destBytes',
      );
    }
    final VideoDraft draft = VideoDraft(
      draftId: draftId,
      ownerUid: uid,
      sourceFilePath: destPath,
      sourceType: sourceType,
      duration: duration,
      width: width,
      height: height,
      aspectRatio: aspectRatio,
      trimEnd: duration,
    );
    await saveNow(draft);
    return draft;
  }

  VideoDraft? peek(String draftId) => _memory[draftId];

  Future<void> saveDebounced(VideoDraft draft) async {
    _memory[draft.draftId] = draft;
    _debounceTimers[draft.draftId]?.cancel();
    _debounceTimers[draft.draftId] = Timer(_debounce, () async {
      await saveNow(draft);
    });
  }
  
  /// Flush all pending debounced saves immediately
  Future<void> flushPendingSaves() async {
    final pendingDrafts = <VideoDraft>[];
    
    // Cancel all timers and collect drafts
    for (final entry in _debounceTimers.entries) {
      entry.value.cancel();
      final draft = _memory[entry.key];
      if (draft != null) {
        pendingDrafts.add(draft);
      }
    }
    _debounceTimers.clear();
    
    // Save all pending drafts
    for (final draft in pendingDrafts) {
      await saveNow(draft);
    }
    
    debugPrint('💾 Flushed ${pendingDrafts.length} pending draft saves');
  }

  Future<bool> saveNow(VideoDraft draft, {int retryAttempt = 0}) async {
    _memory[draft.draftId] = draft;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> all = await _loadRaw(prefs);
      all[draft.draftId] = draft.toJson();
      await prefs.setString(_prefsKey, jsonEncode(all));
      
      // Mark save as successful
      _saveStatus[draft.draftId] = true;
      _saveRetryCount[draft.draftId] = 0;
      
      debugPrint('✅ Draft saved successfully: ${draft.draftId}');
      return true;
    } catch (e) {
      secureLog('VideoDraftStore: save failed (attempt ${retryAttempt + 1}): $e');
      _saveStatus[draft.draftId] = false;
      
      // Retry logic with exponential backoff
      if (retryAttempt < _maxSaveRetries) {
        _saveRetryCount[draft.draftId] = retryAttempt + 1;
        final delayMs = 100 * (1 << retryAttempt); // 100ms, 200ms, 400ms
        
        debugPrint('⏳ Retrying draft save in ${delayMs}ms...');
        await Future.delayed(Duration(milliseconds: delayMs));
        return saveNow(draft, retryAttempt: retryAttempt + 1);
      }
      
      // All retries exhausted
      debugPrint('❌ Draft save failed after $_maxSaveRetries attempts: ${draft.draftId}');
      return false;
    }
  }
  
  /// Get save status for a draft
  bool getSaveStatus(String draftId) {
    return _saveStatus[draftId] ?? false;
  }
  
  /// Check if a draft is currently being retried
  bool isRetrying(String draftId) {
    final retryCount = _saveRetryCount[draftId] ?? 0;
    return retryCount > 0 && retryCount < _maxSaveRetries;
  }

  Future<VideoDraft?> load(String draftId) async {
    if (_memory.containsKey(draftId)) {
      return _memory[draftId];
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> all = await _loadRaw(prefs);
    final Object? raw = all[draftId];
    if (raw is! Map) {
      return null;
    }
    final VideoDraft draft =
        VideoDraft.fromJson(Map<String, dynamic>.from(raw));
    if (!await File(draft.sourceFilePath).exists()) {
      return null;
    }
    _memory[draftId] = draft;
    return draft;
  }

  Future<List<VideoDraft>> listResumable({String? ownerUid}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> all = await _loadRaw(prefs);
    final List<VideoDraft> drafts = <VideoDraft>[];
    for (final Object? raw in all.values) {
      if (raw is! Map) {
        continue;
      }
      final VideoDraft draft =
          VideoDraft.fromJson(Map<String, dynamic>.from(raw));
      if (ownerUid != null &&
          ownerUid.isNotEmpty &&
          draft.ownerUid.isNotEmpty &&
          draft.ownerUid != ownerUid) {
        continue;
      }
      if (!await File(draft.sourceFilePath).exists()) {
        continue;
      }
      drafts.add(draft);
    }
    drafts.sort(
      (VideoDraft a, VideoDraft b) => b.updatedAt.compareTo(a.updatedAt),
    );
    return drafts;
  }

  Future<VideoDraft?> latestResumable({String? ownerUid}) async {
    final List<VideoDraft> drafts = await listResumable(ownerUid: ownerUid);
    if (drafts.isEmpty) {
      return null;
    }
    return drafts.first;
  }

  Future<void> delete(String draftId) async {
    _debounceTimers.remove(draftId)?.cancel();
    final VideoDraft? existing = _memory.remove(draftId) ?? await load(draftId);
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> all = await _loadRaw(prefs);
      all.remove(draftId);
      await prefs.setString(_prefsKey, jsonEncode(all));
    } catch (e) {
      secureLog('VideoDraftStore: delete meta failed: $e');
    }
    if (existing == null) {
      return;
    }
    await _safeDelete(existing.sourceFilePath);
    await _safeDelete(existing.renderedFilePath);
  }

  Future<Map<String, dynamic>> _loadRaw(SharedPreferences prefs) async {
    final String? encoded = prefs.getString(_prefsKey);
    if (encoded == null || encoded.isEmpty) {
      return <String, dynamic>{};
    }
    try {
      final Object? decoded = jsonDecode(encoded);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      secureLog('VideoDraftStore: corrupt prefs: $e');
    }
    return <String, dynamic>{};
  }

  Future<void> _safeDelete(String? path) async {
    if (path == null || path.isEmpty) {
      return;
    }
    try {
      final File file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
