import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scheduled_post.dart';
import '../models/trending_creator.dart';
import 'logging_service.dart';

class OfflineStorageService {
  static final OfflineStorageService _instance =
      OfflineStorageService._internal();
  factory OfflineStorageService() => _instance;
  OfflineStorageService._internal();

  Database? _database;
  SharedPreferences? _prefs;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<Database> _initDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'streamers_tip_offline.db');

      return await openDatabase(
        path,
        version: 1,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to initialize offline database',
        tag: 'OfflineStorageService',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    try {
      // Scheduled Posts table
      await db.execute('''
        CREATE TABLE scheduled_posts (
          id TEXT PRIMARY KEY,
          author_id TEXT NOT NULL,
          caption TEXT,
          tags TEXT,
          visibility TEXT NOT NULL,
          media_data TEXT NOT NULL,
          platforms_data TEXT NOT NULL,
          schedule_data TEXT,
          status TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          sync_status TEXT DEFAULT 'pending'
        )
      ''');

      // Trending Creators table
      await db.execute('''
        CREATE TABLE trending_creators (
          id TEXT PRIMARY KEY,
          username TEXT NOT NULL,
          display_name TEXT,
          avatar_url TEXT,
          follower_count INTEGER DEFAULT 0,
          is_active BOOLEAN DEFAULT 1,
          last_updated INTEGER NOT NULL,
          sync_status TEXT DEFAULT 'pending'
        )
      ''');

      // Categories table
      await db.execute('''
        CREATE TABLE categories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          icon TEXT,
          color TEXT,
          is_active BOOLEAN DEFAULT 1,
          last_updated INTEGER NOT NULL,
          sync_status TEXT DEFAULT 'pending'
        )
      ''');

      // Sync Queue table
      await db.execute('''
        CREATE TABLE sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          table_name TEXT NOT NULL,
          record_id TEXT NOT NULL,
          operation TEXT NOT NULL,
          data TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          retry_count INTEGER DEFAULT 0,
          last_retry INTEGER,
          status TEXT DEFAULT 'pending'
        )
      ''');

      // Create indexes for better performance
      await db.execute(
          'CREATE INDEX idx_scheduled_posts_status ON scheduled_posts(status)');
      await db.execute(
          'CREATE INDEX idx_scheduled_posts_sync ON scheduled_posts(sync_status)');
      await db.execute(
          'CREATE INDEX idx_trending_creators_active ON trending_creators(is_active)');
      await db
          .execute('CREATE INDEX idx_sync_queue_status ON sync_queue(status)');

      LoggingService.instance.info('Offline database created successfully',
          tag: 'OfflineStorageService');
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to create database tables',
        tag: 'OfflineStorageService',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
    LoggingService.instance.info(
        'Database upgraded from $oldVersion to $newVersion',
        tag: 'OfflineStorageService');
  }

  // Scheduled Posts CRUD
  Future<void> saveScheduledPost(ScheduledPost post) async {
    try {
      final db = await database;
      await db.insert(
        'scheduled_posts',
        {
          'id': post.id,
          'author_id': post.authorId,
          'caption': post.caption,
          'tags': jsonEncode(post.tags),
          'visibility': post.visibility.name,
          'media_data': jsonEncode(post.media.map((m) => m.toJson()).toList()),
          'platforms_data':
              jsonEncode(post.platforms.map((p) => p.toJson()).toList()),
          'schedule_data': post.schedule != null
              ? jsonEncode(post.schedule!.toJson())
              : null,
          'status': post.status.name,
          'created_at': post.createdAt.millisecondsSinceEpoch,
          'updated_at': post.updatedAt.millisecondsSinceEpoch,
          'sync_status': 'pending',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Add to sync queue
      await _addToSyncQueue(
          'scheduled_posts', post.id, 'upsert', jsonEncode(post.toJson()));

      LoggingService.instance.debug('Scheduled post saved offline: ${post.id}',
          tag: 'OfflineStorageService');
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to save scheduled post offline',
        tag: 'OfflineStorageService',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<List<ScheduledPost>> getScheduledPosts({String? status}) async {
    try {
      final db = await database;
      String whereClause = '';
      List<dynamic> whereArgs = [];

      if (status != null) {
        whereClause = 'WHERE status = ?';
        whereArgs.add(status);
      }

      final List<Map<String, dynamic>> maps = await db.rawQuery(
        'SELECT * FROM scheduled_posts $whereClause ORDER BY created_at DESC',
        whereArgs,
      );

      return maps.map((map) => _mapToScheduledPost(map)).toList();
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to get scheduled posts from offline storage',
        tag: 'OfflineStorageService',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  Future<void> deleteScheduledPost(String id) async {
    try {
      final db = await database;
      await db.delete('scheduled_posts', where: 'id = ?', whereArgs: [id]);

      // Add to sync queue
      await _addToSyncQueue('scheduled_posts', id, 'delete', '{}');

      LoggingService.instance.debug('Scheduled post deleted offline: $id',
          tag: 'OfflineStorageService');
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to delete scheduled post from offline storage',
        tag: 'OfflineStorageService',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // Trending Creators CRUD
  Future<void> saveTrendingCreators(List<TrendingCreator> creators) async {
    try {
      final db = await database;
      final batch = db.batch();

      for (final creator in creators) {
        batch.insert(
          'trending_creators',
          {
            'id': creator.id,
            'username': creator.username,
            'display_name': creator.displayName,
            'avatar_url': creator.avatarURL,
            'follower_count': creator.followerCount,
            'is_active': creator.isActive ? 1 : 0,
            'last_updated': DateTime.now().millisecondsSinceEpoch,
            'sync_status': 'synced',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit();
      LoggingService.instance.debug(
          'Trending creators saved offline: ${creators.length}',
          tag: 'OfflineStorageService');
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to save trending creators offline',
        tag: 'OfflineStorageService',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<List<TrendingCreator>> getTrendingCreators() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'trending_creators',
        where: 'is_active = ?',
        whereArgs: [1],
        orderBy: 'follower_count DESC',
      );

      return maps.map((map) => _mapToTrendingCreator(map)).toList();
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to get trending creators from offline storage',
        tag: 'OfflineStorageService',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  // Sync Queue Management
  Future<void> _addToSyncQueue(
      String tableName, String recordId, String operation, String data) async {
    try {
      final db = await database;
      await db.insert('sync_queue', {
        'table_name': tableName,
        'record_id': recordId,
        'operation': operation,
        'data': data,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'retry_count': 0,
        'status': 'pending',
      });
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to add item to sync queue',
        tag: 'OfflineStorageService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    try {
      final db = await database;
      return await db.query(
        'sync_queue',
        where: 'status = ?',
        whereArgs: ['pending'],
        orderBy: 'created_at ASC',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to get pending sync items',
        tag: 'OfflineStorageService',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  Future<void> markSyncItemCompleted(int syncId) async {
    try {
      final db = await database;
      await db.update(
        'sync_queue',
        {'status': 'completed'},
        where: 'id = ?',
        whereArgs: [syncId],
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to mark sync item as completed',
        tag: 'OfflineStorageService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> markSyncItemFailed(int syncId, String error) async {
    try {
      final db = await database;
      await db.update(
        'sync_queue',
        {
          'status': 'failed',
          'retry_count': 'retry_count + 1',
          'last_retry': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [syncId],
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to mark sync item as failed',
        tag: 'OfflineStorageService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // Offline Status Management
  Future<bool> isOfflineMode() async {
    try {
      final prefs = await this.prefs;
      return prefs.getBool('offline_mode') ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> setOfflineMode(bool isOffline) async {
    try {
      final prefs = await this.prefs;
      await prefs.setBool('offline_mode', isOffline);
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to set offline mode',
        tag: 'OfflineStorageService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await this.prefs;
      final timestamp = prefs.getInt('last_sync_time');
      return timestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : null;
    } catch (e) {
      return null;
    }
  }

  Future<void> setLastSyncTime(DateTime time) async {
    try {
      final prefs = await this.prefs;
      await prefs.setInt('last_sync_time', time.millisecondsSinceEpoch);
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to set last sync time',
        tag: 'OfflineStorageService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // Helper methods
  ScheduledPost _mapToScheduledPost(Map<String, dynamic> map) {
    return ScheduledPost(
      id: map['id'],
      authorId: map['author_id'],
      caption: map['caption'],
      tags: List<String>.from(jsonDecode(map['tags'] ?? '[]')),
      visibility: PostVisibility.values.firstWhere(
        (v) => v.name == map['visibility'],
        orElse: () => PostVisibility.public,
      ),
      media: (jsonDecode(map['media_data']) as List)
          .map((m) => PostMedia.fromJson(m))
          .toList(),
      platforms: (jsonDecode(map['platforms_data']) as List)
          .map((p) => PlatformConfig.fromJson(p))
          .toList(),
      schedule: map['schedule_data'] != null
          ? PostSchedule.fromJson(jsonDecode(map['schedule_data']))
          : null,
      status: PostStatus.values.firstWhere(
        (v) => v.name == map['status'],
        orElse: () => PostStatus.draft,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }

  TrendingCreator _mapToTrendingCreator(Map<String, dynamic> map) {
    return TrendingCreator(
      id: map['id'],
      username: map['username'],
      displayName: map['display_name'],
      avatarURL: map['avatar_url'],
      followerCount: map['follower_count'] ?? 0,
      isActive: map['is_active'] == 1,
      creatorLevel: map['creator_level'] as int? ?? 0,
      tierStatusLabel: map['tier_status_label'] as String?,
      isFollowing: map['is_following'] == 1,
    );
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
