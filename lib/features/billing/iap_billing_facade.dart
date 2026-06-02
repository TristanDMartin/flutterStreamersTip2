import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'mobile_purchase_verification_client.dart';
import 'mobile_purchase_verification_payload.dart';
import 'store_product_ids.dart';

String billingStorePlatformForPayload() {
  if (kIsWeb) {
    return 'web';
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return 'ios';
    default:
      return 'android';
  }
}

/// Coordinates StoreKit / Play Billing, [purchaseStream], and server verification.
///
/// Subscribe to [purchaseStream] before calling [buySubscription]. Completes
/// purchases only after [MobilePurchaseVerificationClient.submitPurchase]
/// succeeds.
///
/// Prefer a single app-wide [purchaseStream] subscription via
/// [IapBillingCoordinator] so updates are not missed mid-purchase.
class IapBillingFacade {
  IapBillingFacade({
    InAppPurchase? store,
    MobilePurchaseVerificationClient? verificationClient,
    required this.onUiChanged,
    this.onRecoverableMessage,
    this.onVerified,
  })  : _store = store ?? InAppPurchase.instance,
        _verificationClient =
            verificationClient ?? const MobilePurchaseVerificationClient();

  final InAppPurchase _store;
  final MobilePurchaseVerificationClient _verificationClient;
  final void Function() onUiChanged;
  final void Function(String message)? onRecoverableMessage;
  final void Function()? onVerified;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  final Set<String> _verificationCompleteKeys = <String>{};
  bool storeAvailable = false;
  Map<String, ProductDetails> productsById = <String, ProductDetails>{};
  List<String> notFoundProductIds = <String>[];
  String? lastError;
  String? lastRecoverableHint;
  bool purchaseBusy = false;

  Future<void> initialize() async {
    if (_purchaseSub != null) {
      onUiChanged();
      return;
    }
    lastError = null;
    storeAvailable = await _store.isAvailable();
    if (!storeAvailable) {
      lastError = 'In-app purchases are not available on this device.';
      onUiChanged();
      return;
    }
    _purchaseSub = _store.purchaseStream.listen(
      _onPurchaseUpdateBatch,
      onError: (Object error, StackTrace stackTrace) {
        lastError = error.toString();
        purchaseBusy = false;
        onUiChanged();
      },
    );
    onUiChanged();
  }

  Future<void> loadProducts() async {
    if (!storeAvailable) {
      return;
    }
    lastError = null;
    final ProductDetailsResponse response =
        await _store.queryProductDetails(kStreamersTipSubscriptionProductIds);
    if (response.error != null) {
      lastError = response.error!.message;
      onUiChanged();
      return;
    }
    productsById = <String, ProductDetails>{
      for (final ProductDetails d in response.productDetails) d.id: d,
    };
    notFoundProductIds = response.notFoundIDs.toList(growable: false);
    onUiChanged();
  }

  Future<void> restorePurchases() async {
    if (!storeAvailable) {
      lastError = 'Billing is not available.';
      onUiChanged();
      return;
    }
    lastError = null;
    try {
      await _store.restorePurchases();
    } catch (err) {
      lastError = err.toString();
    }
    onUiChanged();
  }

  Future<void> buySubscription(ProductDetails product) async {
    if (!storeAvailable) {
      lastError = 'Billing is not available.';
      onUiChanged();
      return;
    }
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      lastError = 'Sign in to subscribe.';
      onUiChanged();
      return;
    }
    lastError = null;
    lastRecoverableHint = null;
    purchaseBusy = true;
    onUiChanged();
    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: product,
      applicationUserName: user.uid,
    );
    final bool sent = await _store.buyNonConsumable(
      purchaseParam: purchaseParam,
    );
    if (!sent) {
      purchaseBusy = false;
      lastError = 'Could not open the store purchase flow.';
      onUiChanged();
    }
  }

  Future<void> dispose() async {
    await _purchaseSub?.cancel();
    _purchaseSub = null;
  }

  String _dedupeKey(PurchaseDetails purchase) {
    final String pid = purchase.purchaseID ?? '';
    final String token = purchase.verificationData.serverVerificationData;
    return '${purchase.productID}|$pid|${token.hashCode}';
  }

  void _onPurchaseUpdateBatch(List<PurchaseDetails> purchases) {
    for (final PurchaseDetails purchase in purchases) {
      unawaited(_handleSinglePurchaseUpdate(purchase));
    }
  }

  Future<void> _handleSinglePurchaseUpdate(PurchaseDetails purchase) async {
    switch (purchase.status) {
      case PurchaseStatus.pending:
        lastRecoverableHint = 'Purchase pending…';
        onRecoverableMessage?.call(lastRecoverableHint!);
        onUiChanged();
        break;
      case PurchaseStatus.error:
        purchaseBusy = false;
        lastError = purchase.error?.message ?? 'Purchase error';
        onUiChanged();
        await _safeComplete(purchase);
        break;
      case PurchaseStatus.canceled:
        purchaseBusy = false;
        lastRecoverableHint = 'Purchase canceled.';
        onRecoverableMessage?.call(lastRecoverableHint!);
        onUiChanged();
        await _safeComplete(purchase);
        break;
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        await _verifyAndFinish(purchase);
        break;
    }
  }

  Future<void> _verifyAndFinish(PurchaseDetails purchase) async {
    final String key = _dedupeKey(purchase);
    if (_verificationCompleteKeys.contains(key)) {
      return;
    }
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      purchaseBusy = false;
      lastError = 'Signed out before purchase could finish.';
      onUiChanged();
      await _safeComplete(purchase);
      return;
    }
    final String token = purchase.verificationData.serverVerificationData;
    if (token.isEmpty) {
      purchaseBusy = false;
      lastError = 'Missing store verification payload.';
      onUiChanged();
      await _safeComplete(purchase);
      return;
    }
    final String transactionId = _readTransactionId(purchase);
    try {
      await _verificationClient.submitPurchase(
        payload: MobilePurchaseVerificationPayload(
          uid: user.uid,
          platform: billingStorePlatformForPayload(),
          productId: purchase.productID,
          purchaseToken: token,
          transactionId: transactionId,
        ),
      );
      await _store.completePurchase(purchase);
      _verificationCompleteKeys.add(key);
      purchaseBusy = false;
      lastError = null;
      lastRecoverableHint = 'Purchase verified.';
      onUiChanged();
      onVerified?.call();
    } on MobilePurchaseVerificationException catch (e) {
      purchaseBusy = false;
      lastError = e.message;
      onUiChanged();
    } catch (e) {
      purchaseBusy = false;
      lastError = e.toString();
      onUiChanged();
    }
  }

  String _readTransactionId(PurchaseDetails purchase) {
    final String? purchaseId = purchase.purchaseID;
    if (purchaseId != null && purchaseId.isNotEmpty) {
      return purchaseId;
    }
    final String? transactionDate = purchase.transactionDate;
    if (transactionDate != null && transactionDate.isNotEmpty) {
      return transactionDate;
    }
    return purchase.productID;
  }

  Future<void> _safeComplete(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) {
      return;
    }
    try {
      await _store.completePurchase(purchase);
    } catch (e) {
      lastError = '${lastError ?? ''} ${e.toString()}'.trim();
      onUiChanged();
    }
  }
}
