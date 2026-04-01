import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'user.dart';
import 'json_converters.dart';

part 'comment.freezed.dart';
part 'comment.g.dart';

@freezed
sealed class Comment with _$Comment {
  const factory Comment({
    required String id,
    @UserConverter() required User user,
    required String text,
    @TimestampConverter() required DateTime timestamp,
    @Default(0) int likeCount,
    @Default(false) bool isLiked,
    List<Comment>? replies,
  }) = _Comment;

  factory Comment.fromJson(Map<String, dynamic> json) => _$CommentFromJson(json);
}

// Extension for relative timestamp and mock data
extension CommentExtension on Comment {
  String get relativeTimestamp {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return '1d ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return '${weeks}w ago';
      } else {
        final months = (difference.inDays / 30).floor();
        return '${months}mo ago';
      }
    } else if (difference.inHours > 0) {
      if (difference.inHours == 1) {
        return '1h ago';
      } else {
        return '${difference.inHours}h ago';
      }
    } else if (difference.inMinutes > 0) {
      if (difference.inMinutes == 1) {
        return '1m ago';
      } else {
        return '${difference.inMinutes}m ago';
      }
    } else {
      return 'Just now';
    }
  }
}

// Extension for mock data
extension CommentMockData on Comment {
  static List<Comment> mockData() {
    final users = UserSamples.samples;
    if (users.length < 3) return [];
    
    return [
      Comment(
        id: 'mock-comment-1',
        user: users[1],
        text: "It's always the dhurty wine for me😂",
        timestamp: DateTime.now().subtract(const Duration(days: 21)), // 3 weeks ago
        likeCount: 6618,
        isLiked: false,
        replies: [],
      ),
      Comment(
        id: 'mock-comment-2',
        user: users[2],
        text: "There he go swiveling that box again! 😂😂😂",
        timestamp: DateTime.now().subtract(const Duration(days: 21)), // 3 weeks ago
        likeCount: 1958,
        isLiked: false,
        replies: [],
      ),
      Comment(
        id: 'mock-comment-3',
        user: users[0],
        text: "Roblox Trey a menace 😂😂😂😂",
        timestamp: DateTime.now().subtract(const Duration(days: 21)), // 3 weeks ago
        likeCount: 4008,
        isLiked: false,
        replies: [],
      ),
    ];
  }
}

enum CommentError implements Exception {
  userNotAuthenticated,
  userNotFound,
  videoNotFound,
  commentNotFound,
  unauthorized;

  String get errorDescription {
    switch (this) {
      case CommentError.userNotAuthenticated:
        return "User not authenticated";
      case CommentError.userNotFound:
        return "User not found";
      case CommentError.videoNotFound:
        return "Video not found";
      case CommentError.commentNotFound:
        return "Comment not found";
      case CommentError.unauthorized:
        return "You are not authorized to perform this action";
    }
  }
}
