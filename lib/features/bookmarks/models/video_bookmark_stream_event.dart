/// Stream events emitted when video bookmark (favorite) state changes.
enum VideoBookmarkStreamEventType {
  toggle,
  success,
  error,
}

class VideoBookmarkStreamEvent {
  final String videoId;
  final VideoBookmarkStreamEventType type;
  final bool? isBookmarked;
  final String? error;

  VideoBookmarkStreamEvent._(
    this.videoId,
    this.type, {
    this.isBookmarked,
    this.error,
  });

  factory VideoBookmarkStreamEvent.toggle(String videoId, bool isBookmarked) {
    return VideoBookmarkStreamEvent._(
      videoId,
      VideoBookmarkStreamEventType.toggle,
      isBookmarked: isBookmarked,
    );
  }

  factory VideoBookmarkStreamEvent.success(String videoId, bool isBookmarked) {
    return VideoBookmarkStreamEvent._(
      videoId,
      VideoBookmarkStreamEventType.success,
      isBookmarked: isBookmarked,
    );
  }

  factory VideoBookmarkStreamEvent.error(String error) {
    return VideoBookmarkStreamEvent._(
      '',
      VideoBookmarkStreamEventType.error,
      error: error,
    );
  }
}
