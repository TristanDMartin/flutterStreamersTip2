import 'package:cloud_firestore/cloud_firestore.dart';

enum AcademyDifficulty { beginner, intermediate, advanced, expert }

enum AcademyProgressStatus { notStarted, inProgress, completed }

enum AcademyContentBlockType {
  heading,
  paragraph,
  image,
  list,
  video,
  callout,
  tip,
  warning,
  checklist,
  quiz,
  link,
}

class AcademyCategory {
  const AcademyCategory({
    required this.id,
    required this.name,
    required this.description,
    this.iconKey,
    this.iconUrl,
    this.sortOrder = 0,
    this.isPublished = true,
    this.guideCount = 0,
    this.slug,
    this.keywords = const <String>[],
    this.unlockLevel = 0,
  });

  final String id;
  final String name;
  final String description;
  final String? iconKey;
  final String? iconUrl;
  final int sortOrder;
  final bool isPublished;
  final int guideCount;
  final String? slug;
  final List<String> keywords;
  final int unlockLevel;

  factory AcademyCategory.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return AcademyCategory(
      id: doc.id,
      name: _readString(data['name']) ?? 'Category',
      description: _readString(data['description']) ?? '',
      iconKey: _readString(data['iconKey']),
      iconUrl: _readString(data['iconUrl']),
      sortOrder: _readInt(data['sortOrder']),
      isPublished: data['isPublished'] != false && data['status'] != 'draft',
      guideCount: _readInt(data['guideCount']),
      slug: _readString(data['slug']),
      keywords: _readStringList(data['keywords']),
      unlockLevel: _readInt(data['unlockLevel']),
    );
  }
}

class AcademyGuideSummary {
  const AcademyGuideSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.categoryId,
    this.difficulty = AcademyDifficulty.beginner,
    this.estimatedMinutes = 0,
    this.author,
    this.coverImageUrl,
    this.thumbnailUrl,
    this.sortOrder = 0,
    this.isPublished = true,
    this.tags = const <String>[],
    this.platforms = const <String>[],
    this.keywords = const <String>[],
    this.lessonCount = 0,
    this.slug,
    this.webUrl,
    this.sitePath,
    this.contentMode = 'native',
    this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final String categoryId;
  final AcademyDifficulty difficulty;
  final int estimatedMinutes;
  final String? author;
  final String? coverImageUrl;
  final String? thumbnailUrl;
  final int sortOrder;
  final bool isPublished;
  final List<String> tags;
  final List<String> platforms;
  final List<String> keywords;
  final int lessonCount;
  final String? slug;
  final String? webUrl;
  final String? sitePath;
  final String contentMode;
  final DateTime? updatedAt;

  String get imageUrl => thumbnailUrl ?? coverImageUrl ?? '';

  bool get isWebsiteBacked =>
      contentMode == 'website' ||
      (webUrl != null && webUrl!.trim().isNotEmpty && lessonCount <= 0);

  String get shareUrl {
    final String? site = webUrl?.trim();
    if (site != null && site.isNotEmpty) {
      return site;
    }
    final String pathSlug = (slug ?? id).trim();
    if (pathSlug.isEmpty) {
      return 'https://streamerstip.com/streamer-academy';
    }
    return 'https://streamerstip.com/$pathSlug';
  }

  factory AcademyGuideSummary.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return AcademyGuideSummary.fromMap(doc.id, data);
  }

  factory AcademyGuideSummary.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    final String? resolvedWebUrl = _readString(data['webUrl']) ??
        _readString(data['url']) ??
        _webUrlFromSitePath(_readString(data['sitePath']));
    return AcademyGuideSummary(
      id: id,
      title: _readString(data['title']) ?? 'Guide',
      description: _readString(data['description']) ?? '',
      categoryId: _readString(data['categoryId']) ?? '',
      difficulty: _parseDifficulty(data['difficulty']),
      estimatedMinutes: _readInt(data['estimatedMinutes']),
      author: _readString(data['author']),
      coverImageUrl: _readString(data['coverImageUrl']),
      thumbnailUrl: _readString(data['thumbnailUrl']),
      sortOrder: _readInt(data['sortOrder']),
      isPublished: data['isPublished'] != false && data['status'] != 'draft',
      tags: _readStringList(data['tags']),
      platforms: _readStringList(data['platforms']),
      keywords: _readStringList(data['keywords']),
      lessonCount: _readInt(data['lessonCount']),
      slug: _readString(data['slug']),
      webUrl: resolvedWebUrl,
      sitePath: _readString(data['sitePath']),
      contentMode: _readString(data['contentMode']) ??
          (resolvedWebUrl != null ? 'website' : 'native'),
      updatedAt: _readTimestamp(data['updatedAt']),
    );
  }
}

class AcademyLessonSummary {
  const AcademyLessonSummary({
    required this.id,
    required this.guideId,
    required this.title,
    this.sortOrder = 0,
    this.estimatedMinutes = 0,
    this.isPublished = true,
    this.slug,
    this.hasQuiz = false,
    this.hasApplyAction = false,
  });

  final String id;
  final String guideId;
  final String title;
  final int sortOrder;
  final int estimatedMinutes;
  final bool isPublished;
  final String? slug;
  final bool hasQuiz;
  final bool hasApplyAction;

  factory AcademyLessonSummary.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return AcademyLessonSummary(
      id: doc.id,
      guideId: _readString(data['guideId']) ?? '',
      title: _readString(data['title']) ?? 'Lesson',
      sortOrder: _readInt(data['sortOrder']),
      estimatedMinutes: _readInt(data['estimatedMinutes']),
      isPublished: data['isPublished'] != false && data['status'] != 'draft',
      slug: _readString(data['slug']),
      hasQuiz: data['quiz'] != null,
      hasApplyAction: data['applyAction'] != null,
    );
  }
}

class AcademyContentBlock {
  const AcademyContentBlock({
    required this.type,
    required this.content,
    this.level = 2,
    this.items = const <String>[],
    this.url,
    this.caption,
    this.variant,
    this.options = const <String>[],
    this.correctIndex,
  });

  final AcademyContentBlockType type;
  final String content;
  final int level;
  final List<String> items;
  final String? url;
  final String? caption;
  final String? variant;
  final List<String> options;
  final int? correctIndex;

  factory AcademyContentBlock.fromJson(Map<String, dynamic> json) {
    return AcademyContentBlock(
      type: _parseBlockType(_readString(json['type'])),
      content: _readString(json['content'] ?? json['text']) ?? '',
      level: _readInt(json['level'], fallback: 2),
      items: _readStringList(json['items']),
      url: _readString(json['url'] ?? json['src']),
      caption: _readString(json['caption']),
      variant: _readString(json['variant']),
      options: _readStringList(json['options']),
      correctIndex: json['correctIndex'] is int ? json['correctIndex'] as int : null,
    );
  }
}

class AcademyApplyAction {
  const AcademyApplyAction({
    required this.title,
    required this.plannerItemTitle,
    this.plannerItemDescription,
    this.plannerItemType = 'task',
    this.tags = const <String>[],
  });

  final String title;
  final String plannerItemTitle;
  final String? plannerItemDescription;
  final String plannerItemType;
  final List<String> tags;

  factory AcademyApplyAction.fromJson(dynamic raw) {
    if (raw is! Map) {
      return const AcademyApplyAction(
        title: 'Apply This',
        plannerItemTitle: 'Academy action',
      );
    }
    final Map<String, dynamic> m = Map<String, dynamic>.from(raw);
    return AcademyApplyAction(
      title: _readString(m['title']) ?? 'Apply This',
      plannerItemTitle:
          _readString(m['plannerItemTitle']) ?? 'Academy action',
      plannerItemDescription: _readString(m['plannerItemDescription']),
      plannerItemType: _readString(m['plannerItemType']) ?? 'task',
      tags: _readStringList(m['tags']),
    );
  }
}

class AcademyLesson {
  const AcademyLesson({
    required this.summary,
    this.contentBlocks = const <AcademyContentBlock>[],
    this.videoUrl,
    this.videoCompletionThreshold = 0.9,
    this.applyAction,
    this.relatedGuideIds = const <String>[],
  });

  final AcademyLessonSummary summary;
  final List<AcademyContentBlock> contentBlocks;
  final String? videoUrl;
  final double videoCompletionThreshold;
  final AcademyApplyAction? applyAction;
  final List<String> relatedGuideIds;

  factory AcademyLesson.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    final AcademyLessonSummary summary =
        AcademyLessonSummary.fromFirestore(doc);
    final List<AcademyContentBlock> blocks = <AcademyContentBlock>[];
    final Object? rawBlocks = data['contentBlocks'] ?? data['content'];
    if (rawBlocks is List) {
      for (final Object? block in rawBlocks) {
        if (block is Map<String, dynamic>) {
          blocks.add(AcademyContentBlock.fromJson(block));
        } else if (block is Map) {
          blocks.add(
            AcademyContentBlock.fromJson(Map<String, dynamic>.from(block)),
          );
        }
      }
    }
    return AcademyLesson(
      summary: summary,
      contentBlocks: blocks,
      videoUrl: _readString(data['videoUrl']),
      videoCompletionThreshold:
          (data['videoCompletionThreshold'] is num)
              ? (data['videoCompletionThreshold'] as num).toDouble()
              : 0.9,
      applyAction: data['applyAction'] != null
          ? AcademyApplyAction.fromJson(data['applyAction'])
          : null,
      relatedGuideIds: _readStringList(data['relatedGuideIds']),
    );
  }
}

class AcademyPath {
  const AcademyPath({
    required this.id,
    required this.title,
    required this.description,
    this.lessonIds = const <String>[],
    this.sortOrder = 0,
    this.isPublished = true,
    this.unlockLevel = 0,
    this.iconKey,
  });

  final String id;
  final String title;
  final String description;
  final List<String> lessonIds;
  final int sortOrder;
  final bool isPublished;
  final int unlockLevel;
  final String? iconKey;

  factory AcademyPath.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return AcademyPath(
      id: doc.id,
      title: _readString(data['title']) ?? 'Learning Path',
      description: _readString(data['description']) ?? '',
      lessonIds: _readStringList(data['lessonIds']),
      sortOrder: _readInt(data['sortOrder']),
      isPublished: data['isPublished'] != false && data['status'] != 'draft',
      unlockLevel: _readInt(data['unlockLevel']),
      iconKey: _readString(data['iconKey']),
    );
  }
}

class AcademyUserProgress {
  const AcademyUserProgress({
    required this.userId,
    required this.guideId,
    required this.lessonId,
    this.pathId,
    this.status = AcademyProgressStatus.notStarted,
    this.progressPercent = 0,
    this.completedAt,
    this.lastOpenedAt,
    this.quizScore,
    this.xpAwarded = false,
    this.completionEventId,
    this.platform = 'app',
    this.readingPosition = 0,
    this.isSaved = false,
    this.savedAt,
  });

  final String userId;
  final String guideId;
  final String lessonId;
  final String? pathId;
  final AcademyProgressStatus status;
  final int progressPercent;
  final DateTime? completedAt;
  final DateTime? lastOpenedAt;
  final int? quizScore;
  final bool xpAwarded;
  final String? completionEventId;
  final String platform;
  final double readingPosition;
  final bool isSaved;
  final DateTime? savedAt;

  bool get isCompleted => status == AcademyProgressStatus.completed;

  String get documentId => '${userId}_$lessonId';

  factory AcademyUserProgress.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return AcademyUserProgress(
      userId: _readString(data['userId']) ?? '',
      guideId: _readString(data['guideId']) ?? '',
      lessonId: _readString(data['lessonId']) ?? '',
      pathId: _readString(data['pathId']),
      status: _parseProgressStatus(data['status']),
      progressPercent: _readInt(data['progressPercent']),
      completedAt: _readTimestamp(data['completedAt']),
      lastOpenedAt: _readTimestamp(data['lastOpenedAt']),
      quizScore: data['quizScore'] is int ? data['quizScore'] as int : null,
      xpAwarded: data['xpAwarded'] == true,
      completionEventId: _readString(data['completionEventId']),
      platform: _readString(data['platform']) ?? 'app',
      readingPosition: (data['readingPosition'] is num)
          ? (data['readingPosition'] as num).toDouble()
          : 0,
      isSaved: data['isSaved'] == true,
      savedAt: _readTimestamp(data['savedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'userId': userId,
      'guideId': guideId,
      'lessonId': lessonId,
      if (pathId != null) 'pathId': pathId,
      'status': status.name,
      'progressPercent': progressPercent,
      if (completedAt != null)
        'completedAt': Timestamp.fromDate(completedAt!),
      if (lastOpenedAt != null)
        'lastOpenedAt': Timestamp.fromDate(lastOpenedAt!),
      if (quizScore != null) 'quizScore': quizScore,
      'xpAwarded': xpAwarded,
      if (completionEventId != null) 'completionEventId': completionEventId,
      'platform': platform,
      'readingPosition': readingPosition,
      'isSaved': isSaved,
      if (savedAt != null) 'savedAt': Timestamp.fromDate(savedAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  AcademyUserProgress copyWith({
    AcademyProgressStatus? status,
    int? progressPercent,
    DateTime? completedAt,
    DateTime? lastOpenedAt,
    int? quizScore,
    bool? xpAwarded,
    String? completionEventId,
    double? readingPosition,
    bool? isSaved,
    DateTime? savedAt,
  }) {
    return AcademyUserProgress(
      userId: userId,
      guideId: guideId,
      lessonId: lessonId,
      pathId: pathId,
      status: status ?? this.status,
      progressPercent: progressPercent ?? this.progressPercent,
      completedAt: completedAt ?? this.completedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      quizScore: quizScore ?? this.quizScore,
      xpAwarded: xpAwarded ?? this.xpAwarded,
      completionEventId: completionEventId ?? this.completionEventId,
      platform: platform,
      readingPosition: readingPosition ?? this.readingPosition,
      isSaved: isSaved ?? this.isSaved,
      savedAt: savedAt ?? this.savedAt,
    );
  }
}

class AcademyXpRewards {
  const AcademyXpRewards({
    this.openFirstGuideOfDay = 5,
    this.completeLesson = 15,
    this.completeQuiz = 20,
    this.completeCategory = 75,
    this.finishLearningPath = 150,
    this.sevenDayStreak = 100,
    this.applyToContentPlanner = 25,
  });

  final int openFirstGuideOfDay;
  final int completeLesson;
  final int completeQuiz;
  final int completeCategory;
  final int finishLearningPath;
  final int sevenDayStreak;
  final int applyToContentPlanner;

  factory AcademyXpRewards.defaults() => const AcademyXpRewards();

  factory AcademyXpRewards.fromFirestore(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return AcademyXpRewards.defaults();
    }
    return AcademyXpRewards(
      openFirstGuideOfDay:
          _readInt(data['openFirstGuideOfDay'], fallback: 5),
      completeLesson: _readInt(data['completeLesson'], fallback: 15),
      completeQuiz: _readInt(data['completeQuiz'], fallback: 20),
      completeCategory: _readInt(data['completeCategory'], fallback: 75),
      finishLearningPath:
          _readInt(data['finishLearningPath'], fallback: 150),
      sevenDayStreak: _readInt(data['sevenDayStreak'], fallback: 100),
      applyToContentPlanner:
          _readInt(data['applyToContentPlanner'], fallback: 25),
    );
  }
}

class AcademySearchResult {
  const AcademySearchResult({
    required this.guide,
    this.categoryName,
    this.matchedFields = const <String>[],
  });

  final AcademyGuideSummary guide;
  final String? categoryName;
  final List<String> matchedFields;
}

String? _readString(dynamic value) {
  if (value == null) {
    return null;
  }
  final String s = value.toString().trim();
  return s.isEmpty ? null : s;
}

String? _webUrlFromSitePath(String? sitePath) {
  if (sitePath == null || sitePath.isEmpty) {
    return null;
  }
  if (sitePath.startsWith('http://') || sitePath.startsWith('https://')) {
    return sitePath;
  }
  final String normalized =
      sitePath.startsWith('/') ? sitePath : '/$sitePath';
  return 'https://streamerstip.com$normalized';
}

int _readInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return fallback;
}

List<String> _readStringList(dynamic value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((dynamic e) => e?.toString().trim() ?? '')
      .where((String s) => s.isNotEmpty)
      .toList(growable: false);
}

DateTime? _readTimestamp(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  return null;
}

AcademyDifficulty _parseDifficulty(dynamic value) {
  final String raw = value?.toString().toLowerCase() ?? '';
  switch (raw) {
    case 'intermediate':
      return AcademyDifficulty.intermediate;
    case 'advanced':
      return AcademyDifficulty.advanced;
    case 'expert':
      return AcademyDifficulty.expert;
    default:
      return AcademyDifficulty.beginner;
  }
}

AcademyProgressStatus _parseProgressStatus(dynamic value) {
  final String raw = value?.toString().toLowerCase() ?? '';
  switch (raw) {
    case 'in_progress':
    case 'inprogress':
      return AcademyProgressStatus.inProgress;
    case 'completed':
      return AcademyProgressStatus.completed;
    default:
      return AcademyProgressStatus.notStarted;
  }
}

AcademyContentBlockType _parseBlockType(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'heading':
      return AcademyContentBlockType.heading;
    case 'image':
      return AcademyContentBlockType.image;
    case 'list':
      return AcademyContentBlockType.list;
    case 'video':
      return AcademyContentBlockType.video;
    case 'callout':
      return AcademyContentBlockType.callout;
    case 'tip':
      return AcademyContentBlockType.tip;
    case 'warning':
      return AcademyContentBlockType.warning;
    case 'checklist':
      return AcademyContentBlockType.checklist;
    case 'quiz':
      return AcademyContentBlockType.quiz;
    case 'link':
      return AcademyContentBlockType.link;
    default:
      return AcademyContentBlockType.paragraph;
  }
}

String difficultyLabel(AcademyDifficulty difficulty) {
  switch (difficulty) {
    case AcademyDifficulty.beginner:
      return 'Beginner';
    case AcademyDifficulty.intermediate:
      return 'Intermediate';
    case AcademyDifficulty.advanced:
      return 'Advanced';
    case AcademyDifficulty.expert:
      return 'Expert';
  }
}
