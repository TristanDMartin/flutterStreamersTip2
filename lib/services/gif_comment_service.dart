import 'package:giphy_picker/giphy_picker.dart';
import 'package:flutter/material.dart';

class GifCommentService {
  static const String _giphyApiKey = String.fromEnvironment(
    'GIPHY_API_KEY',
    defaultValue: '',
  );

  static Future<GiphyGif?> selectGif(BuildContext context) async {
    if (_giphyApiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GIF feature not configured'),
          backgroundColor: Colors.orange,
        ),
      );
      return null;
    }

    try {
      final gif = await GiphyPicker.pickGif(
        context: context,
        apiKey: _giphyApiKey,
        showPreviewPage: true,
        searchText: 'Trending',
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
    if (preview) {
      return gif.images?.downsizedMedium?.url ??
          gif.images?.downsized?.url ??
          gif.images?.original?.url ??
          '';
    }
    return gif.images?.original?.url ??
        gif.images?.downsized?.url ??
        '';
  }

  static String getGifPreviewUrl(GiphyGif gif) {
    return gif.images?.downsizedStill?.url ??
        gif.images?.fixedWidthStill?.url ??
        '';
  }

  static Map<String, dynamic> getGifMetadata(GiphyGif gif) {
    return {
      'title': gif.title ?? '',
      'username': gif.username ?? '',
      'source': gif.source ?? '',
      'rating': gif.rating ?? '',
      'width': gif.images?.original?.width ?? 0,
      'height': gif.images?.original?.height ?? 0,
      'size': gif.images?.original?.size ?? 0,
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
