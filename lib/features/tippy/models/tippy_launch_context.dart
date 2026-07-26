class TippyLaunchContext {
  const TippyLaunchContext({
    this.surface = 'tippy_chat',
    this.prefilledPrompt,
    this.videoId,
    this.planId,
    this.insightPrompt,
    this.academyGuideId,
    this.academyLessonId,
    this.academyGuideTitle,
    this.academyLessonTitle,
    this.academyCategory,
    this.academySection,
  });

  final String surface;
  final String? prefilledPrompt;
  final String? videoId;
  final String? planId;
  final String? insightPrompt;
  final String? academyGuideId;
  final String? academyLessonId;
  final String? academyGuideTitle;
  final String? academyLessonTitle;
  final String? academyCategory;
  final String? academySection;

  bool get hasAcademyContext =>
      surface.startsWith('academy') ||
      (academyLessonId != null && academyLessonId!.isNotEmpty) ||
      (academyGuideId != null && academyGuideId!.isNotEmpty);

  Map<String, dynamic> toChatPayloadExtras() {
    return <String, dynamic>{
      'surface': surface,
      if (academyGuideId != null && academyGuideId!.isNotEmpty)
        'academyGuideId': academyGuideId,
      if (academyLessonId != null && academyLessonId!.isNotEmpty)
        'academyLessonId': academyLessonId,
      if (academyGuideTitle != null && academyGuideTitle!.isNotEmpty)
        'academyGuideTitle': academyGuideTitle,
      if (academyLessonTitle != null && academyLessonTitle!.isNotEmpty)
        'academyLessonTitle': academyLessonTitle,
      if (academyCategory != null && academyCategory!.isNotEmpty)
        'academyCategory': academyCategory,
      if (academySection != null && academySection!.isNotEmpty)
        'academySection': academySection,
    };
  }
}
