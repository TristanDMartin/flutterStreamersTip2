import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'content_scheduler_models.dart';
import 'content_scheduler_repository.dart';

final Provider<ContentSchedulerRepository> contentSchedulerRepositoryProvider =
    Provider<ContentSchedulerRepository>((Ref ref) {
  return HttpContentSchedulerRepository();
});

final FutureProvider<List<SchedulerQueueItem>> contentSchedulerQueueProvider =
    FutureProvider<List<SchedulerQueueItem>>((Ref ref) async {
  final User? user = FirebaseAuth.instance.currentUser;
  final String? token = await user?.getIdToken(false);
  if (user == null || token == null || token.isEmpty) {
    throw const ContentSchedulerException('Authentication required.');
  }
  final ContentSchedulerRepository repository =
      ref.watch(contentSchedulerRepositoryProvider);
  return repository.loadQueue(idToken: token, limit: 25);
});
