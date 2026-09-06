import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/optimistic_video.dart';

/// Durable Instant Publish rows so Home/Profile survive app kill.
class OptimisticVideoPersistence {
  OptimisticVideoPersistence._internal();

  static final OptimisticVideoPersistence instance =
      OptimisticVideoPersistence._internal();

  static const String _directoryName = 'instant_publish_pending';
  Directory? _dir;

  Future<Directory> _ensureDir() async {
    final Directory? cached = _dir;
    if (cached != null) {
      return cached;
    }
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory next = Directory('${docs.path}/$_directoryName');
    if (!await next.exists()) {
      await next.create(recursive: true);
    }
    _dir = next;
    return next;
  }

  Future<void> save(OptimisticVideo video) async {
    try {
      final Directory dir = await _ensureDir();
      final File file = File('${dir.path}/${video.videoId}.json');
      await file.writeAsString(jsonEncode(video.toJson()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('OptimisticVideoPersistence.save failed: $e');
      }
    }
  }

  Future<void> remove(String videoId) async {
    try {
      final Directory dir = await _ensureDir();
      final File file = File('${dir.path}/$videoId.json');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('OptimisticVideoPersistence.remove failed: $e');
      }
    }
  }

  Future<void> clear() async {
    try {
      final Directory dir = await _ensureDir();
      if (await dir.exists()) {
        await for (final FileSystemEntity entity in dir.list()) {
          if (entity is File && entity.path.endsWith('.json')) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('OptimisticVideoPersistence.clear failed: $e');
      }
    }
  }

  Future<List<OptimisticVideo>> loadAll() async {
    try {
      final Directory dir = await _ensureDir();
      if (!await dir.exists()) {
        return const <OptimisticVideo>[];
      }
      final List<OptimisticVideo> loaded = <OptimisticVideo>[];
      await for (final FileSystemEntity entity in dir.list()) {
        if (entity is! File || !entity.path.endsWith('.json')) {
          continue;
        }
        try {
          final String raw = await entity.readAsString();
          final Map<String, dynamic> json =
              jsonDecode(raw) as Map<String, dynamic>;
          loaded.add(OptimisticVideo.fromJson(json));
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'OptimisticVideoPersistence: skip ${entity.path}: $e',
            );
          }
        }
      }
      return loaded;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('OptimisticVideoPersistence.loadAll failed: $e');
      }
      return const <OptimisticVideo>[];
    }
  }
}
