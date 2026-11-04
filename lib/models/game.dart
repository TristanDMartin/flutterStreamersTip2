import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'game.freezed.dart';
part 'game.g.dart';

@freezed
class Game with _$Game {
  const factory Game({
    required String id,
    required String title,
    required String artworkUrl,
    required String provider,
    required String providerGameId,
    required String slug,
    @Default(0) int clipCount,
    @Default(0) int followerCount,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) = _Game;

  factory Game.fromJson(Map<String, dynamic> json) => _$GameFromJson(json);

  factory Game.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw Exception('Game document ${doc.id} has no data');
    }
    
    return Game(
      id: doc.id,
      title: data['title'] as String? ?? 'Unknown Game',
      artworkUrl: data['artworkUrl'] as String? ?? '',
      provider: data['provider'] as String? ?? 'unknown',
      providerGameId: data['providerGameId'] as String? ?? '',
      slug: data['slug'] as String? ?? '',
      clipCount: data['clipCount'] as int? ?? 0,
      followerCount: data['followerCount'] as int? ?? 0,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  static Map<String, dynamic> toFirestore(Game game) {
    return {
      'title': game.title,
      'artworkUrl': game.artworkUrl,
      'provider': game.provider,
      'providerGameId': game.providerGameId,
      'slug': game.slug,
      'clipCount': game.clipCount,
      'followerCount': game.followerCount,
      'updatedAt': FieldValue.serverTimestamp(),
      if (game.metadata != null) 'metadata': game.metadata,
    };
  }
}

extension GameExtension on Game {
  static List<Game> get samples => [
    const Game(
      id: 'fortnite',
      title: 'Fortnite',
      artworkUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co2ekt.jpg',
      provider: 'igdb',
      providerGameId: '1905',
      slug: 'fortnite',
      clipCount: 150,
      followerCount: 1200,
    ),
    const Game(
      id: 'minecraft',
      title: 'Minecraft',
      artworkUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co49x5.jpg',
      provider: 'igdb',
      providerGameId: '121',
      slug: 'minecraft',
      clipCount: 280,
      followerCount: 2100,
    ),
    const Game(
      id: 'valorant',
      title: 'VALORANT',
      artworkUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co2mvt.jpg',
      provider: 'igdb',
      providerGameId: '119171',
      slug: 'valorant',
      clipCount: 95,
      followerCount: 850,
    ),
    const Game(
      id: 'league-of-legends',
      title: 'League of Legends',
      artworkUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co49wj.jpg',
      provider: 'igdb',
      providerGameId: '115',
      slug: 'league-of-legends',
      clipCount: 210,
      followerCount: 1500,
    ),
    const Game(
      id: 'call-of-duty-warzone',
      title: 'Call of Duty: Warzone',
      artworkUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co2eus.jpg',
      provider: 'igdb',
      providerGameId: '136521',
      slug: 'call-of-duty-warzone',
      clipCount: 120,
      followerCount: 950,
    ),
  ];
}
