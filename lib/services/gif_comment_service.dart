import 'package:flutter/material.dart';
import 'package:giphy_picker/giphy_picker.dart';
import 'package:streamers_tip/config/giphy_config.dart';

class GifCommentService {
  static Future<GiphyGif?> selectGif(BuildContext context) async {
    final String apiKey = GiphyConfig.bestApiKey;
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GIF feature not configured'),
          backgroundColor: Colors.orange,
        ),
      );
      return null;
    }

    try {
      final GiphyGif? gif = await GiphyPicker.pickGif(
        context: context,
        apiKey: apiKey,
        showPreviewPage: true,
        fullScreenDialog: false,
      );

      return gif;
    } catch (e) {
      debugPrint('Error selecting GIF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load GIF picker'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  static String getGifUrl(GiphyGif gif, {bool preview = false}) {
    final GiphyImages images = gif.images;
    if (preview) {
      return images.fixedWidth?.url ??
          images.downsized?.url ??
          images.original?.url ??
          '';
    }
    return images.original?.url ?? images.downsized?.url ?? '';
  }

  static String getGifPreviewUrl(GiphyGif gif) {
    final GiphyImages images = gif.images;
    return images.downsizedStill?.url ?? images.fixedWidthStill?.url ?? '';
  }

  static Map<String, dynamic> getGifMetadata(GiphyGif gif) {
    final GiphyOriginalImage? original = gif.images.original;
    return {
      'title': gif.title ?? '',
      'username': gif.username ?? '',
      'source': gif.source ?? '',
      'rating': gif.rating ?? '',
      'width': int.tryParse(original?.width ?? '') ?? 0,
      'height': int.tryParse(original?.height ?? '') ?? 0,
      'size': int.tryParse(original?.size ?? '') ?? 0,
    };
  }

  static String getGifAttribution(GiphyGif gif) {
    final username = gif.username;
    if (username != null && username.isNotEmpty) {
      return 'via GIPHY · @$username';
    }
    return 'via GIPHY';
  }
}
