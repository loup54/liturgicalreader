import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../models/liturgical_reading.dart';
import '../models/liturgical_day.dart';

class OfflineStorageService {
  static final OfflineStorageService _instance =
      OfflineStorageService._internal();
  factory OfflineStorageService() => _instance;
  OfflineStorageService._internal();

  Database? _database;
  bool _isInitialized = false;

  // Initialize SQLite database
  Future<void> initialize() async {
    if (_isInitialized && _database != null) return;

    try {
      final databasePath = await getDatabasesPath();
      final path = join(databasePath, 'liturgical_cache.db');

      _database = await openDatabase(
        path,
        version: 1,
        onCreate: _createTables,
        onUpgrade: _upgradeDatabase,
      );

      _isInitialized = true;
      debugPrint('OfflineStorageService: Database initialized successfully');
    } catch (e) {
      debugPrint('OfflineStorageService: Failed to initialize database: $e');
      throw Exception('Failed to initialize offline storage: $e');
    }
  }

  // Create database tables
  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE liturgical_days_cache (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL UNIQUE,
        liturgical_season TEXT NOT NULL,
        liturgical_rank TEXT,
        feast_name TEXT,
        commemoration TEXT,
        liturgical_color TEXT NOT NULL,
        week_of_season INTEGER,
        day_of_week TEXT,
        is_sunday INTEGER DEFAULT 0,
        is_holy_day INTEGER DEFAULT 0,
        readings TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        cache_timestamp INTEGER NOT NULL,
        sync_status TEXT DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE liturgical_readings_cache (
        id TEXT PRIMARY KEY,
        liturgical_day_id TEXT NOT NULL,
        reading_type TEXT NOT NULL,
        citation TEXT NOT NULL,
        content TEXT NOT NULL,
        preview_text TEXT,
        audio_url TEXT,
        order_sequence INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        cache_timestamp INTEGER NOT NULL,
        sync_status TEXT DEFAULT 'pending',
        FOREIGN KEY (liturgical_day_id) REFERENCES liturgical_days_cache (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE cache_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        operation_type TEXT NOT NULL,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        data TEXT,
        created_at INTEGER NOT NULL,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT
      )
    ''');

    // Create indexes for performance
    await db.execute(
        'CREATE INDEX idx_liturgical_days_date ON liturgical_days_cache(date)');
    await db.execute(
        'CREATE INDEX idx_liturgical_days_cache_timestamp ON liturgical_days_cache(cache_timestamp)');
    await db.execute(
        'CREATE INDEX idx_readings_day_id ON liturgical_readings_cache(liturgical_day_id)');
    await db.execute(
        'CREATE INDEX idx_readings_cache_timestamp ON liturgical_readings_cache(cache_timestamp)');
    await db.execute(
        'CREATE INDEX idx_sync_queue_created ON sync_queue(created_at)');
  }

  // Handle database upgrades
  Future<void> _upgradeDatabase(
      Database db, int oldVersion, int newVersion) async {
    debugPrint(
        'OfflineStorageService: Upgrading database from $oldVersion to $newVersion');
    // Add migration logic here when needed
  }

  // Get database instance
  Future<Database> get database async {
    if (_database == null || !_isInitialized) {
      await initialize();
    }
    return _database!;
  }

  // Cache liturgical day with 90-day strategy
  Future<void> cacheLiturgicalDay(LiturgicalDay day) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert(
        'liturgical_days_cache',
        {
          'id': day.id,
          'date': day.date.toIso8601String().split('T')[0],
          'liturgical_season': day.liturgicalSeason,
          'liturgical_rank': day.liturgicalRank,
          'feast_name': day.feastName,
          'commemoration': day.commemoration,
          'liturgical_color': day.liturgicalColor,
          'week_of_season': day.weekOfSeason,
          'day_of_week': day.dayOfWeek,
          'is_sunday': day.isSunday ? 1 : 0,
          'is_holy_day': day.isHolyDay ? 1 : 0,
          'readings': jsonEncode(day.readings),
          'created_at': day.createdAt.toIso8601String(),
          'updated_at': day.updatedAt.toIso8601String(),
          'cache_timestamp': now,
          'sync_status': 'synced',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint(
          'OfflineStorageService: Cached liturgical day for ${day.date}');
    } catch (e) {
      debugPrint('OfflineStorageService: Failed to cache liturgical day: $e');
    }
  }

  // Cache liturgical readings
  Future<void> cacheLiturgicalReadings(List<LiturgicalReading> readings) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final batch = db.batch();
      for (final reading in readings) {
        batch.insert(
          'liturgical_readings_cache',
          {
            'id': reading.id,
            'liturgical_day_id': reading.liturgicalDayId,
            'reading_type': reading.readingType.name,
            'citation': reading.citation,
            'content': reading.content,
            'preview_text': reading.previewText,
            'audio_url': reading.audioUrl,
            'order_sequence': reading.orderSequence,
            'created_at': reading.createdAt.toIso8601String(),
            'updated_at': reading.updatedAt.toIso8601String(),
            'cache_timestamp': now,
            'sync_status': 'synced',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit();
      debugPrint('OfflineStorageService: Cached ${readings.length} readings');
    } catch (e) {
      debugPrint('OfflineStorageService: Failed to cache readings: $e');
    }
  }

  // Get cached liturgical day
  Future<LiturgicalDay?> getCachedLiturgicalDay(DateTime date) async {
    try {
      final db = await database;
      final dateStr = date.toIso8601String().split('T')[0];

      final result = await db.query(
        'liturgical_days_cache',
        where: 'date = ?',
        whereArgs: [dateStr],
        limit: 1,
      );

      if (result.isEmpty) return null;

      final data = result.first;
      return LiturgicalDay(
        id: data['id'] as String,
        date: DateTime.parse(data['date'] as String),
        liturgicalSeason: data['liturgical_season'] as String,
        liturgicalRank: (data['liturgical_rank'] as String?) ?? '',
        feastName: data['feast_name'] as String?,
        commemoration: data['commemoration'] as String?,
        liturgicalColor: data['liturgical_color'] as String,
        weekOfSeason: (data['week_of_season'] as int?) ?? 0,
        dayOfWeek: (data['day_of_week'] as String?) ?? '',
        isSunday: (data['is_sunday'] as int) == 1,
        isHolyDay: (data['is_holy_day'] as int) == 1,
        readings: jsonDecode(data['readings'] as String),
        createdAt: DateTime.parse(data['created_at'] as String),
        updatedAt: DateTime.parse(data['updated_at'] as String),
      );
    } catch (e) {
      debugPrint(
          'OfflineStorageService: Failed to get cached liturgical day: $e');
      return null;
    }
  }

  // Get cached readings for date
  Future<List<LiturgicalReading>> getCachedReadings(DateTime date) async {
    try {
      final db = await database;
      const query = '''
        SELECT r.* FROM liturgical_readings_cache r
        JOIN liturgical_days_cache d ON r.liturgical_day_id = d.id
        WHERE d.date = ?
        ORDER BY r.order_sequence
      ''';

      final dateStr = date.toIso8601String().split('T')[0];
      final result = await db.rawQuery(query, [dateStr]);

      return result.map((data) {
        return LiturgicalReading(
          id: data['id'] as String,
          liturgicalDayId: data['liturgical_day_id'] as String,
          readingType: ReadingType.values.firstWhere(
            (type) => type.name == data['reading_type'],
            orElse: () => ReadingType.firstReading,
          ),
          citation: data['citation'] as String,
          content: data['content'] as String,
          previewText: (data['preview_text'] as String?) ?? '',
          audioUrl: data['audio_url'] as String?,
          orderSequence: data['order_sequence'] as int,
          createdAt: DateTime.parse(data['created_at'] as String),
          updatedAt: DateTime.parse(data['updated_at'] as String),
        );
      }).toList();
    } catch (e) {
      debugPrint('OfflineStorageService: Failed to get cached readings: $e');
      return [];
    }
  }

  // Check if data exists in cache for date
  Future<bool> hasDataForDate(DateTime date) async {
    try {
      final db = await database;
      final dateStr = date.toIso8601String().split('T')[0];

      final result = await db.query(
        'liturgical_days_cache',
        where: 'date = ?',
        whereArgs: [dateStr],
        limit: 1,
      );

      return result.isNotEmpty;
    } catch (e) {
      debugPrint('OfflineStorageService: Failed to check cache for date: $e');
      return false;
    }
  }

  // Pre-load 90 days of data (30 past, 60 future)
  Future<List<DateTime>> getMissingDatesInRange() async {
    try {
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 30));
      final endDate = now.add(const Duration(days: 60));

      final missingDates = <DateTime>[];
      DateTime current = startDate;

      while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
        if (!await hasDataForDate(current)) {
          missingDates.add(current);
        }
        current = current.add(const Duration(days: 1));
      }

      debugPrint(
          'OfflineStorageService: Found ${missingDates.length} missing dates in 90-day range');
      return missingDates;
    } catch (e) {
      debugPrint('OfflineStorageService: Failed to get missing dates: $e');
      return [];
    }
  }

  // Clean old cache data beyond 90 days
  Future<void> cleanOldCacheData() async {
    try {
      final db = await database;
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      final cutoffDateStr = cutoffDate.toIso8601String().split('T')[0];

      // Delete old liturgical days and their readings
      await db.delete(
        'liturgical_readings_cache',
        where:
            'liturgical_day_id IN (SELECT id FROM liturgical_days_cache WHERE date < ?)',
        whereArgs: [cutoffDateStr],
      );

      final deletedDaysCount = await db.delete(
        'liturgical_days_cache',
        where: 'date < ?',
        whereArgs: [cutoffDateStr],
      );

      debugPrint(
          'OfflineStorageService: Cleaned $deletedDaysCount old cache entries');
    } catch (e) {
      debugPrint('OfflineStorageService: Failed to clean old cache data: $e');
    }
  }

  // Get cache statistics
  Future<Map<String, int>> getCacheStats() async {
    try {
      final db = await database;

      final daysResult = await db
          .rawQuery('SELECT COUNT(*) as count FROM liturgical_days_cache');
      final readingsResult = await db
          .rawQuery('SELECT COUNT(*) as count FROM liturgical_readings_cache');

      return {
        'cached_days': daysResult.first['count'] as int,
        'cached_readings': readingsResult.first['count'] as int,
      };
    } catch (e) {
      debugPrint('OfflineStorageService: Failed to get cache stats: $e');
      return {'cached_days': 0, 'cached_readings': 0};
    }
  }

  // Set cache metadata
  Future<void> setCacheMetadata(String key, String value) async {
    try {
      final db = await database;
      await db.insert(
        'cache_metadata',
        {
          'key': key,
          'value': value,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('OfflineStorageService: Failed to set cache metadata: $e');
    }
  }

  // Get cache metadata
  Future<String?> getCacheMetadata(String key) async {
    try {
      final db = await database;
      final result = await db.query(
        'cache_metadata',
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );

      if (result.isEmpty) return null;
      return result.first['value'] as String?;
    } catch (e) {
      debugPrint('OfflineStorageService: Failed to get cache metadata: $e');
      return null;
    }
  }

  // Close database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _isInitialized = false;
    }
  }

  // Check if service is initialized
  bool get isInitialized => _isInitialized;

  // Get cache size (rough estimate)
  Future<double> getCacheSizeInMB() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
          "SELECT page_count * page_size as size FROM pragma_page_count(), pragma_page_size()");
      if (result.isNotEmpty) {
        final sizeInBytes = result.first['size'] as int;
        return sizeInBytes / (1024 * 1024); // Convert to MB
      }
      return 0.0;
    } catch (e) {
      debugPrint('OfflineStorageService: Failed to get cache size: $e');
      return 0.0;
    }
  }
}
