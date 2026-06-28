class TippyLaunchContext {
  const TippyLaunchContext({
    this.surface = 'tippy_chat',
    this.prefilledPrompt,
    this.videoId,
    this.planId,
    this.insightPrompt,
  });

  final String surface;
  final String? prefilledPrompt;
  final String? videoId;
  final String? planId;
  final String? insightPrompt;
}
