import '../features/billing/models/subscription_snapshot.dart';
import '../features/billing/subscription_repository.dart';

export '../features/billing/subscription_repository.dart'
    show SubscriptionRepository, SubscriptionRepositoryException;

typedef MeEntitlementsTokenProvider = SubscriptionTokenProvider;

/// @deprecated Use [SubscriptionRepository] directly.
class MeEntitlementsException implements Exception {
  const MeEntitlementsException(this.message);

  final String message;

  factory MeEntitlementsException.fromRepo(SubscriptionRepositoryException e) {
    return MeEntitlementsException(e.message);
  }

  @override
  String toString() => message;
}

/// @deprecated Use [SubscriptionRepository].
class MeEntitlementsService {
  MeEntitlementsService({
    String? apiBase,
    SubscriptionRepository? repository,
  }) : _repository = repository ??
            SubscriptionRepository(
              siteApiBase: apiBase,
              legacyCloudFunctionBase: apiBase,
            );

  final SubscriptionRepository _repository;

  bool get hasApiBase => _repository.hasSiteApiBase || _repository.hasLegacyApiBase;

  Future<SubscriptionSnapshot> fetchCurrentUserEntitlements({
    bool forceRefresh = false,
  }) async {
    try {
      return await _repository.fetchEntitlements(forceRefresh: forceRefresh);
    } on SubscriptionRepositoryException catch (e) {
      throw MeEntitlementsException.fromRepo(e);
    }
  }

  void dispose() {
    _repository.dispose();
  }
}
