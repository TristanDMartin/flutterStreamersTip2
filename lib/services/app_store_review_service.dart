import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the native review sheet or store listing for StreamersTip.
class AppStoreReviewService {
  AppStoreReviewService({InAppReview? review})
      : _review = review ?? InAppReview.instance;

  final InAppReview _review;

  static const String iosStoreUrl = 'https://apps.apple.com/app/streamerstip';
  static const String androidStoreUrl =
      'https://play.google.com/store/apps/details?id=com.streamerstip.streamersTipApp';

  /// Numeric Apple App Store ID when published (enables [InAppReview.openStoreListing] on iOS).
  static const String? iosAppStoreId = null;

  Future<bool> requestReviewOrOpenStore() async {
    try {
      if (await _review.isAvailable()) {
        await _review.requestReview();
        return true;
      }
    } catch (error, stackTrace) {
      debugPrint('AppStoreReviewService.requestReview failed: $error');
      debugPrint('$stackTrace');
    }
    return openStoreListing();
  }

  Future<bool> openStoreListing() async {
    try {
      if (!kIsWeb && Platform.isIOS && iosAppStoreId != null) {
        await _review.openStoreListing(appStoreId: iosAppStoreId);
        return true;
      }
      if (!kIsWeb && Platform.isAndroid) {
        await _review.openStoreListing();
        return true;
      }
    } catch (error, stackTrace) {
      debugPrint('AppStoreReviewService.openStoreListing failed: $error');
      debugPrint('$stackTrace');
    }
    return launchStoreUrl();
  }

  Future<bool> launchStoreUrl() async {
    final Uri uri = Uri.parse(_storeListingUrl);
    try {
      if (await canLaunchUrl(uri)) {
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (error, stackTrace) {
      debugPrint('AppStoreReviewService.launchStoreUrl failed: $error');
      debugPrint('$stackTrace');
    }
    return false;
  }

  String get _storeListingUrl {
    if (kIsWeb) {
      return iosStoreUrl;
    }
    if (Platform.isIOS) {
      return iosStoreUrl;
    }
    return androidStoreUrl;
  }

  String get storeButtonLabel {
    if (kIsWeb) {
      return 'Rate StreamersTip';
    }
    if (Platform.isIOS) {
      return 'Rate on App Store';
    }
    return 'Rate on Google Play';
  }
}

Future<bool> requestAppStoreReview() {
  return AppStoreReviewService().requestReviewOrOpenStore();
}
