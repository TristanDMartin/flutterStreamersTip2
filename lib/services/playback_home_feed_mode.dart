/// Home feed playback pool sizing (TikTok-style prev + current + next).
abstract final class PlaybackHomeFeedConfig {
  static const int maxPoolSize = 4;

  static const int maxPinnedControllers = 3;
}
