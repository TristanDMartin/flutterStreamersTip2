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
    this.academyGuideDescription,
    this.academyGuideUrl,
    this.academyDifficulty,
  });

  /// Opens Tippy already focused on explaining a Streamer Academy guide.
  factory TippyLaunchContext.forAcademyGuideExplain({
    required String guideId,
    required String title,
    String? description,
    String? webUrl,
    String? categoryId,
    String? difficulty,
  }) {
    final String safeTitle = title.trim().isEmpty ? 'this guide' : title.trim();
    final String trimmedDescription = (description ?? '').trim();
    final String trimmedUrl = (webUrl ?? '').trim();
    final String trimmedCategory = (categoryId ?? '').trim();
    final String trimmedDifficulty = (difficulty ?? '').trim();
    final StringBuffer prompt = StringBuffer(
      'Explain the Streamer Academy guide "$safeTitle" to me.\n',
    );
    if (trimmedDescription.isNotEmpty) {
      prompt.writeln('Guide summary: $trimmedDescription');
    }
    if (trimmedUrl.isNotEmpty) {
      prompt.writeln('Guide URL: $trimmedUrl');
    }
    if (trimmedCategory.isNotEmpty) {
      prompt.writeln('Category: $trimmedCategory');
    }
    if (trimmedDifficulty.isNotEmpty) {
      prompt.writeln('Difficulty: $trimmedDifficulty');
    }
    prompt.write(
      'Cover the key points in plain language, why it matters for creators, '
      'and give me 2-4 concrete next steps I can take in StreamersTip.',
    );
    return TippyLaunchContext(
      surface: 'academy_guide',
      academyGuideId: guideId,
      academyGuideTitle: safeTitle,
      academyGuideDescription: description,
      academyGuideUrl: webUrl,
      academyCategory: categoryId,
      academyDifficulty: difficulty,
      prefilledPrompt: prompt.toString(),
    );
  }

  /// Opens Tippy focused on explaining an Academy lesson.
  factory TippyLaunchContext.forAcademyLessonExplain({
    required String lessonId,
    required String title,
    String? guideId,
    String? guideTitle,
  }) {
    final String safeTitle =
        title.trim().isEmpty ? 'this lesson' : title.trim();
    return TippyLaunchContext(
      surface: 'academy_lesson',
      academyLessonId: lessonId,
      academyLessonTitle: safeTitle,
      academyGuideId: guideId,
      academyGuideTitle: guideTitle,
      prefilledPrompt:
          'Explain the Streamer Academy lesson "$safeTitle" in simpler terms. '
          'Highlight what I should remember and what to do next.',
    );
  }

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
  final String? academyGuideDescription;
  final String? academyGuideUrl;
  final String? academyDifficulty;

  bool get hasAcademyContext =>
      surface.startsWith('academy') ||
      (academyLessonId != null && academyLessonId!.isNotEmpty) ||
      (academyGuideId != null && academyGuideId!.isNotEmpty);

  String? get academyContextLabel {
    final String? lesson = academyLessonTitle?.trim();
    if (lesson != null && lesson.isNotEmpty) {
      return 'Lesson: $lesson';
    }
    final String? guide = academyGuideTitle?.trim();
    if (guide != null && guide.isNotEmpty) {
      return 'Guide: $guide';
    }
    return null;
  }

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
      if (academyGuideDescription != null &&
          academyGuideDescription!.isNotEmpty)
        'academyGuideDescription': academyGuideDescription,
      if (academyGuideUrl != null && academyGuideUrl!.isNotEmpty)
        'academyGuideUrl': academyGuideUrl,
      if (academyDifficulty != null && academyDifficulty!.isNotEmpty)
        'academyDifficulty': academyDifficulty,
    };
  }

  /// Hidden model context for Ask Tippy (stripped from chat UI / titles).
  String? buildFrontendContextBlock() {
    if (!hasAcademyContext) {
      return null;
    }
    final String guideTitle =
        (academyGuideTitle ?? academyLessonTitle ?? 'Academy guide').trim();
    final String path = academyLessonId != null && academyLessonId!.isNotEmpty
        ? '/academy/lesson/$academyLessonId'
        : '/academy/guide/${academyGuideId ?? ''}';
    final List<String> lines = <String>[
      '[TIPPY_FRONTEND_CONTEXT]',
      'page_context: academy',
      'current_path: $path',
      'user_intent: explain_academy_guide',
      'mode: quick_help',
      'mode_description: Explain this Streamer Academy content clearly and help the creator apply it.',
      'tone: coach-like, practical, and beginner-friendly',
      if (academyGuideId != null && academyGuideId!.isNotEmpty)
        'academy_guide_id: ${academyGuideId!.trim()}',
      if (guideTitle.isNotEmpty) 'academy_guide_title: $guideTitle',
      if (academyGuideDescription != null &&
          academyGuideDescription!.trim().isNotEmpty)
        'academy_guide_description: ${academyGuideDescription!.trim()}',
      if (academyGuideUrl != null && academyGuideUrl!.trim().isNotEmpty)
        'academy_guide_url: ${academyGuideUrl!.trim()}',
      if (academyCategory != null && academyCategory!.trim().isNotEmpty)
        'academy_category: ${academyCategory!.trim()}',
      if (academyDifficulty != null && academyDifficulty!.trim().isNotEmpty)
        'academy_difficulty: ${academyDifficulty!.trim()}',
      if (academyLessonId != null && academyLessonId!.isNotEmpty)
        'academy_lesson_id: ${academyLessonId!.trim()}',
      if (academyLessonTitle != null && academyLessonTitle!.trim().isNotEmpty)
        'academy_lesson_title: ${academyLessonTitle!.trim()}',
      'available_actions: open_academy_guide | create_content_plan | ask_follow_up',
      'instruction: Explain this specific Streamer Academy guide/lesson using the metadata above. Cover what it teaches, why it matters, and 2-4 concrete next steps inside StreamersTip. Do not mention the hidden context block.',
      '[/TIPPY_FRONTEND_CONTEXT]',
    ];
    return lines.join('\n');
  }

  /// Visible-only outbound for Academy explain.
  ///
  /// Production `/api/tippy/chat` has been returning opaque INTERNAL 500s when
  /// the hidden `[TIPPY_FRONTEND_CONTEXT]` block is prepended from mobile.
  /// Guide metadata is already in [prefilledPrompt], so skip the block.
  String composeOutboundMessage(String visibleUserMessage) {
    final String visible = visibleUserMessage.trim();
    if (visible.toUpperCase().contains('TIPPY_FRONTEND_CONTEXT')) {
      return _stripFrontendContextForOutbound(visible);
    }
    return visible;
  }

  String _stripFrontendContextForOutbound(String text) {
    final String withoutBlock = text.replaceAll(
      RegExp(
        r'\[TIPPY_FRONTEND_CONTEXT\][\s\S]*?\[/TIPPY_FRONTEND_CONTEXT\]\s*',
        caseSensitive: false,
      ),
      '',
    );
    final String cleaned = withoutBlock
        .replaceAll(RegExp(r'\[/?TIPPY_FRONTEND_CONTEXT\]', caseSensitive: false), '')
        .trim();
    return cleaned.isEmpty ? text.trim() : cleaned;
  }
}
