/// Source comment model (for threads created from comments) - Regular class
class SourceComment {
  final String text;
  final String authorId;
  final String authorName;
  final String authorUsername;

  SourceComment({
    required this.text,
    required this.authorId,
    required this.authorName,
    required this.authorUsername,
  });

  factory SourceComment.fromMap(Map<String, dynamic> map) {
    return SourceComment(
      text: map['text'] as String,
      authorId: map['authorId'] as String,
      authorName: map['authorName'] as String,
      authorUsername: map['authorUsername'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'authorId': authorId,
      'authorName': authorName,
      'authorUsername': authorUsername,
    };
  }
}
