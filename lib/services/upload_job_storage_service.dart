import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/upload_job.dart';

class UploadJobStorageService {
  static final UploadJobStorageService _instance = UploadJobStorageService._internal();
  factory UploadJobStorageService() => _instance;
  UploadJobStorageService._internal();

  static const String _jobsDirectory = 'upload_jobs';
  late Directory _jobsDir;

  Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    _jobsDir = Directory('${appDir.path}/$_jobsDirectory');
    if (!await _jobsDir.exists()) {
      await _jobsDir.create(recursive: true);
    }
  }

  /// Save upload job to local storage
  Future<void> saveJob(UploadJob job) async {
    await initialize();
    final file = File('${_jobsDir.path}/${job.localId}.json');
    await file.writeAsString(jsonEncode(job.toJson()));
  }

  /// Load upload job from local storage
  Future<UploadJob?> loadJob(String localId) async {
    await initialize();
    final file = File('${_jobsDir.path}/$localId.json');
    if (!await file.exists()) return null;
    
    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return UploadJob.fromJson(json);
    } catch (e) {
    // print('❌ Error loading upload job $localId: $e');
      return null;
    }
  }

  /// Load all upload jobs
  Future<List<UploadJob>> loadAllJobs() async {
    await initialize();
    final files = _jobsDir.listSync();
    final jobs = <UploadJob>[];

    for (final file in files) {
      if (file is File && file.path.endsWith('.json')) {
        try {
          final content = await file.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          jobs.add(UploadJob.fromJson(json));
        } catch (e) {
    // print('❌ Error loading upload job from ${file.path}: $e');
        }
      }
    }

    return jobs;
  }

  /// Load active jobs (queued or uploading)
  Future<List<UploadJob>> loadActiveJobs() async {
    final allJobs = await loadAllJobs();
    return allJobs.where((job) => job.state.isActive).toList();
  }

  /// Update job state
  Future<void> updateJobState(String localId, UploadJobState state, {double? progress, String? errorMessage}) async {
    final job = await loadJob(localId);
    if (job == null) return;

    final updatedJob = job.copyWith(
      state: state,
      progress: progress,
      errorMessage: errorMessage,
    );

    await saveJob(updatedJob);
  }

  /// Delete completed job
  Future<void> deleteJob(String localId) async {
    await initialize();
    final file = File('${_jobsDir.path}/$localId.json');
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Clean up old completed jobs (older than 7 days)
  Future<void> cleanupOldJobs() async {
    final allJobs = await loadAllJobs();
    final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
    
    for (final job in allJobs) {
      if (job.state.isCompleted && job.createdAt.isBefore(cutoffDate)) {
        await deleteJob(job.localId);
      }
    }
  }

  /// Get job count by state
  Future<Map<UploadJobState, int>> getJobCounts() async {
    final allJobs = await loadAllJobs();
    final counts = <UploadJobState, int>{};
    
    for (final state in UploadJobState.values) {
      counts[state] = allJobs.where((job) => job.state == state).length;
    }
    
    return counts;
  }
}
