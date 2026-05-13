import 'package:flutter/material.dart';

/// Global keys for [ProductTourOverlay] coach marks (widgets attach these).
abstract final class ProductTourTargetKeys {
  static final GlobalKey homeFeed =
      GlobalKey(debugLabel: 'productTourHomeFeed');
  static final GlobalKey uploadButton =
      GlobalKey(debugLabel: 'productTourUpload');
  static final GlobalKey discover =
      GlobalKey(debugLabel: 'productTourDiscover');
  static final GlobalKey discoverActivity =
      GlobalKey(debugLabel: 'productTourDiscoverActivity');
  static final GlobalKey discoverCategories =
      GlobalKey(debugLabel: 'productTourDiscoverCategories');
  static final GlobalKey discoverTrending =
      GlobalKey(debugLabel: 'productTourDiscoverTrending');
  static final GlobalKey network = GlobalKey(debugLabel: 'productTourNetwork');
  static final GlobalKey inbox = GlobalKey(debugLabel: 'productTourInbox');
  static final GlobalKey profile = GlobalKey(debugLabel: 'productTourProfile');
  static final GlobalKey creatorCard =
      GlobalKey(debugLabel: 'productTourCreatorCard');
  static final GlobalKey tippyAi = GlobalKey(debugLabel: 'productTourTippy');

  /// Feed selector pill (For You / Progression / Threads dropdown).
  static final GlobalKey progression =
      GlobalKey(debugLabel: 'productTourProgressionPill');

  /// Progression tab body — level / streak hero (not the dropdown pill).
  static final GlobalKey progressionPanel =
      GlobalKey(debugLabel: 'productTourProgressionPanel');

  static GlobalKey? keyForStepId(String id) {
    switch (id) {
      case 'home_feed':
        return homeFeed;
      case 'upload_button':
        return uploadButton;
      case 'discover':
        return discover;
      case 'discover_activity':
        return discoverActivity;
      case 'discover_categories':
        return discoverCategories;
      case 'network':
        return network;
      case 'inbox':
        return inbox;
      case 'profile':
        return profile;
      case 'creator_card':
        return creatorCard;
      case 'tippy_ai':
        return tippyAi;
      case 'progression':
        return progressionPanel;
      case 'threads':
        return progression;
      default:
        return null;
    }
  }
}
