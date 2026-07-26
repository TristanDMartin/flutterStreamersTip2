import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:streamers_tip/models/upload_job.dart';
import 'package:streamers_tip/services/upload_job_storage_service.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.root);

  final Directory root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late UploadJobStorageService storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('upload_job_storage_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
    storage = UploadJobStorageService();
    await storage.initialize();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('failed publish checkpoint survives updateJobState', () async {
    final UploadJob job = UploadJob(
      localId: 'upload_screen_1',
      fileUri: '/tmp/video.mp4',
      title: 'Test caption',
      categories: const <String>['gaming'],
      createdAt: DateTime.now(),
      state: UploadJobState.uploading,
      videoId: 'vid_retry_1',
      progress: 0.0,
      metadata: const <String, dynamic>{
        'source': 'publish_screen',
        'privacy': 'Everyone',
        'allowComments': true,
      },
    );
    await storage.saveJob(job);
    await storage.updateJobState(
      'upload_screen_1',
      UploadJobState.uploading,
      progress: 0.42,
    );
    await storage.updateJobState(
      'upload_screen_1',
      UploadJobState.failed,
      errorMessage: 'Network dropped',
    );
    final UploadJob? stored = await storage.loadJob('upload_screen_1');
    expect(stored, isNotNull);
    expect(stored!.state, UploadJobState.failed);
    expect(stored.videoId, 'vid_retry_1');
    expect(stored.progress, closeTo(0.42, 0.001));
    expect(stored.errorMessage, 'Network dropped');
    expect(stored.metadata?['source'], 'publish_screen');
  });

  test('loadResumableJobs includes failed checkpoints', () async {
    final UploadJob job = UploadJob(
      localId: 'upload_failed_1',
      fileUri: '/tmp/a.mp4',
      title: 'caption',
      categories: const <String>['gaming'],
      createdAt: DateTime.now(),
      state: UploadJobState.failed,
      videoId: 'vid_2',
      errorMessage: 'timeout',
    );
    await storage.saveJob(job);
    final List<UploadJob> resumable = await storage.loadResumableJobs();
    expect(
      resumable.any((UploadJob j) => j.localId == 'upload_failed_1'),
      isTrue,
    );
    final List<UploadJob> activeOnly = await storage.loadActiveJobs();
    expect(
      activeOnly.any((UploadJob j) => j.localId == 'upload_failed_1'),
      isFalse,
    );
  });

  test('BackgroundUploadService-compatible states are startable', () {
    expect(UploadJobState.queued.isActive, isTrue);
    expect(UploadJobState.uploading.isActive, isTrue);
    expect(UploadJobState.failed.hasFailed, isTrue);
    expect(UploadJobState.failed.isActive, isFalse);
  });
}
