import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'event_trigger_service.dart';

/// Service for parsing and processing tags and mentions in video captions
class TagMentionService {
  static final TagMentionService _instance = TagMentionService._internal();
  factory TagMentionService() => _instance;
  TagMentionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  EventTriggerService? _eventTriggerService;

  /// Set the EventTriggerService instance (should be called from provider)
  void setEventTriggerService(EventTriggerService eventTriggerService) {
    _eventTriggerService = eventTriggerService;
  }

  /// Parse and process tags and mentions from video caption
  /// This should be called after a video is successfully uploaded
  Future<void> processVideoTagsAndMentions({
    required String videoId,
    required String videoOwnerId,
    required String caption,
    String? postThumbnailUrl,
  }) async {
    try {
      debugPrint(
          '🏷️ TagMentionService: Processing tags and mentions for video: $videoId');

      // Parse tags and mentions from caption
      final parsedData = _parseTagsAndMentions(caption);

      if (parsedData.tags.isEmpty && parsedData.mentions.isEmpty) {
        debugPrint(
            '🏷️ TagMentionService: No tags or mentions found in caption');
        return;
      }

      debugPrint(
          '🏷️ TagMentionService: Found ${parsedData.tags.length} tags and ${parsedData.mentions.length} mentions');

      // Process tags (users tagged in the video)
      if (parsedData.tags.isNotEmpty) {
        await _processTags(
          videoId: videoId,
          videoOwnerId: videoOwnerId,
          taggedUsernames: parsedData.tags,
          postThumbnailUrl: postThumbnailUrl,
        );
      }

      // Process mentions (users mentioned with @ in caption)
      if (parsedData.mentions.isNotEmpty) {
        await _processMentions(
          videoId: videoId,
          videoOwnerId: videoOwnerId,
          mentionedUsernames: parsedData.mentions,
          postThumbnailUrl: postThumbnailUrl,
        );
      }

      debugPrint(
          '✅ TagMentionService: Successfully processed tags and mentions');
    } catch (e) {
      debugPrint('❌ TagMentionService: Error processing tags and mentions: $e');
    }
  }

  /// Parse tags and mentions from caption text
  ParsedContent _parseTagsAndMentions(String caption) {
    final tags = <String>[];
    final mentions = <String>[];

    if (caption.isEmpty) {
      return ParsedContent(tags: tags, mentions: mentions);
    }

    // Parse tags - look for patterns like "tagged: @username" or "tagged @username"
    final tagRegex = RegExp(r'tagged\s*:?\s*@(\w+)', caseSensitive: false);
    final tagMatches = tagRegex.allMatches(caption);
    for (final match in tagMatches) {
      final username = match.group(1);
      if (username != null && !tags.contains(username)) {
        tags.add(username);
      }
    }

    // Parse mentions - look for @username patterns (but not in tag context)
    final mentionRegex =
        RegExp(r'(?<!tagged\s*:?\s*)@(\w+)', caseSensitive: false);
    final mentionMatches = mentionRegex.allMatches(caption);
    for (final match in mentionMatches) {
      final username = match.group(1);
      if (username != null &&
          !mentions.contains(username) &&
          !tags.contains(username)) {
        mentions.add(username);
      }
    }

    return ParsedContent(tags: tags, mentions: mentions);
  }

  /// Process tags (users tagged in the video)
  Future<void> _processTags({
    required String videoId,
    required String videoOwnerId,
    required List<String> taggedUsernames,
    String? postThumbnailUrl,
  }) async {
    try {
      debugPrint(
          '🏷️ TagMentionService: Processing ${taggedUsernames.length} tags');

      for (final username in taggedUsernames) {
        // Find user by username
        final userDoc = await _findUserByUsername(username);
        if (userDoc != null) {
          final taggedUserId = userDoc.id;

          debugPrint(
              '🏷️ TagMentionService: Found tagged user: $username ($taggedUserId)');

          // Trigger tag event notification
          if (_eventTriggerService != null) {
            await _eventTriggerService!.triggerTagEvent(
              taggerId: videoOwnerId,
              taggedUserId: taggedUserId,
              videoId: videoId,
              postThumbnailUrl: postThumbnailUrl,
            );
          } else {
            debugPrint(
                '⚠️ TagMentionService: EventTriggerService not set - no tag notification will be created');
          }

          // Store tag relationship in Firestore
          await _storeTagRelationship(
            taggerId: videoOwnerId,
            taggedUserId: taggedUserId,
            videoId: videoId,
          );
        } else {
          debugPrint('⚠️ TagMentionService: Tagged user not found: $username');
        }
      }
    } catch (e) {
      debugPrint('❌ TagMentionService: Error processing tags: $e');
    }
  }

  /// Process mentions (users mentioned with @ in caption)
  Future<void> _processMentions({
    required String videoId,
    required String videoOwnerId,
    required List<String> mentionedUsernames,
    String? postThumbnailUrl,
  }) async {
    try {
      debugPrint(
          '💬 TagMentionService: Processing ${mentionedUsernames.length} mentions');

      for (final username in mentionedUsernames) {
        // Find user by username
        final userDoc = await _findUserByUsername(username);
        if (userDoc != null) {
          final mentionedUserId = userDoc.id;

          debugPrint(
              '💬 TagMentionService: Found mentioned user: $username ($mentionedUserId)');

          // Create mention notification
          if (_eventTriggerService != null) {
            await _eventTriggerService!.triggerMentionEvent(
              mentionerId: videoOwnerId,
              mentionedUserId: mentionedUserId,
              videoId: videoId,
              postThumbnailUrl: postThumbnailUrl,
            );
          } else {
            debugPrint(
                '⚠️ TagMentionService: EventTriggerService not set - no mention notification will be created');
          }

          // Store mention relationship in Firestore
          await _storeMentionRelationship(
            mentionerId: videoOwnerId,
            mentionedUserId: mentionedUserId,
            videoId: videoId,
          );
        } else {
          debugPrint(
              '⚠️ TagMentionService: Mentioned user not found: $username');
        }
      }
    } catch (e) {
      debugPrint('❌ TagMentionService: Error processing mentions: $e');
    }
  }

  /// Find user by username
  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _findUserByUsername(
      String username) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return query.docs.first;
      }
      return null;
    } catch (e) {
      debugPrint('❌ TagMentionService: Error finding user by username: $e');
      return null;
    }
  }

  /// Store tag relationship in Firestore
  Future<void> _storeTagRelationship({
    required String taggerId,
    required String taggedUserId,
    required String videoId,
  }) async {
    try {
      await _firestore.collection('tags').add({
        'taggerId': taggerId,
        'taggedUserId': taggedUserId,
        'videoId': videoId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ TagMentionService: Stored tag relationship');
    } catch (e) {
      debugPrint('❌ TagMentionService: Error storing tag relationship: $e');
    }
  }

  /// Store mention relationship in Firestore
  Future<void> _storeMentionRelationship({
    required String mentionerId,
    required String mentionedUserId,
    required String videoId,
  }) async {
    try {
      await _firestore.collection('mentions').add({
        'mentionerId': mentionerId,
        'mentionedUserId': mentionedUserId,
        'videoId': videoId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ TagMentionService: Stored mention relationship');
    } catch (e) {
      debugPrint('❌ TagMentionService: Error storing mention relationship: $e');
    }
  }
}

/// Data class for parsed content
class ParsedContent {
  final List<String> tags;
  final List<String> mentions;

  ParsedContent({
    required this.tags,
    required this.mentions,
  });
}
