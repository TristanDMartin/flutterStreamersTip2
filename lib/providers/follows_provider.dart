import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/follows_service.dart';

export 'service_providers.dart'
    show eventTriggerServiceProvider, notificationServiceProvider;

/// Provider for FollowsService. Follow Activity notifications are server-only
/// — Cloud Function onFollowCreate owns that write (see firestore.rules).
final followsServiceProvider = Provider<FollowsService>((ref) {
  return FollowsService();
});
