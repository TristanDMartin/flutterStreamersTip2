import 'package:cloud_firestore/cloud_firestore.dart';

/// Forum category model - Regular class
class ForumCategory {
  final String id;
  final String name;
  final String? description;
  final String? parentCategoryId;
  final int postCount;
  final DateTime createdAt;

  ForumCategory({
    required this.id,
    required this.name,
    this.description,
    this.parentCategoryId,
    required this.postCount,
    required this.createdAt,
  });

  factory ForumCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ForumCategory(
      id: doc.id,
      name: data['name'] as String,
      description: data['description'] as String?,
      parentCategoryId: data['parentCategoryId'] as String?,
      postCount: data['postCount'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}
