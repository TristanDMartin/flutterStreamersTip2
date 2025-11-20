import 'streamer_card.dart';

class StreamerCardSamples {
  static StreamerCard get gamingPro => const StreamerCard(
        id: '1',
        username: 'gamingpro',
        displayName: 'Gaming Pro',
        bio: 'Professional gamer and streamer. I play competitive games and share my gaming journey with viewers. Specializing in FPS and strategy games.',
        avatarURL: null,
        coverImageURL: null,
        platforms: [
          Platform(
            id: 'p1',
            type: PlatformType.youtube,
            username: 'GamingProOfficial',
            followers: 200000,
            url: 'https://youtube.com/c/GamingProOfficial',
          ),
          Platform(
            id: 'p2',
            type: PlatformType.tiktok,
            username: 'gamingpro',
            followers: 150000,
            url: 'https://tiktok.com/@gamingpro',
          ),
          Platform(
            id: 'p3',
            type: PlatformType.twitch,
            username: 'gamingpro',
            followers: 50000,
            url: 'https://twitch.tv/gamingpro',
          ),
        ],
        hashtags: ['gaming', 'esports', 'fps', 'strategy', 'competitive'],
        socialLinks: [],
        isConnected: true,
        onlineStatus: 'online',
        calendarEvents: [],
        isFollowing: false,
        isFollowingYou: true,
      );

  static StreamerCard get techReviewer => const StreamerCard(
        id: '2',
        username: 'techreviewer',
        displayName: 'Tech Reviewer',
        bio: 'Tech enthusiast and reviewer. I review the latest gadgets, smartphones, and tech innovations. Follow for honest reviews and tech insights!',
        avatarURL: null,
        coverImageURL: null,
        platforms: [
          Platform(
            id: 'p4',
            type: PlatformType.youtube,
            username: 'TechReviewerChannel',
            followers: 500000,
            url: 'https://youtube.com/c/TechReviewerChannel',
          ),
          Platform(
            id: 'p5',
            type: PlatformType.instagram,
            username: 'techreviewer',
            followers: 100000,
            url: 'https://instagram.com/techreviewer',
          ),
        ],
        hashtags: ['tech', 'reviews', 'gadgets', 'smartphones', 'innovation'],
        socialLinks: [],
        isConnected: false,
        onlineStatus: 'idle',
        calendarEvents: [],
        isFollowing: true,
        isFollowingYou: false,
      );

  static StreamerCard get fitnessInfluencer => const StreamerCard(
        id: '3',
        username: 'fitnessguru',
        displayName: 'Fitness Guru',
        bio: 'Certified personal trainer and fitness influencer. Helping you achieve your fitness goals with workout routines, nutrition tips, and motivation!',
        avatarURL: null,
        coverImageURL: null,
        platforms: [
          Platform(
            id: 'p6',
            type: PlatformType.instagram,
            username: 'fitnessguru',
            followers: 300000,
            url: 'https://instagram.com/fitnessguru',
          ),
          Platform(
            id: 'p7',
            type: PlatformType.tiktok,
            username: 'fitnessguru',
            followers: 250000,
            url: 'https://tiktok.com/@fitnessguru',
          ),
          Platform(
            id: 'p8',
            type: PlatformType.youtube,
            username: 'FitnessGuruOfficial',
            followers: 100000,
            url: 'https://youtube.com/c/FitnessGuruOfficial',
          ),
        ],
        hashtags: ['fitness', 'workout', 'nutrition', 'health', 'motivation'],
        socialLinks: [],
        isConnected: true,
        onlineStatus: 'dnd',
        calendarEvents: [],
        isFollowing: false,
        isFollowingYou: false,
      );

  static List<StreamerCard> get all => [
        gamingPro,
        techReviewer,
        fitnessInfluencer,
      ];
}
