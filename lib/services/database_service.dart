// database_service.dart - FIXED VERSION
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/devotional_model.dart'; // ✅ FIXED: Import DevotionalModel
import '../models/song_model.dart';
import 'auth_service.dart';

/// Database service providing clean interface for all database operations
class DatabaseService {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Database references
  static DatabaseReference get _devotionalsRef => _database.ref('devotionals');
  static DatabaseReference get _songsRef => _database.ref('songs');
  static DatabaseReference get _settingsRef => _database.ref('settings');
  static DatabaseReference get _analyticsRef => _database.ref('analytics');
  static DatabaseReference get _favoritesRef => _database.ref('favorites');
  static DatabaseReference get _collectionsRef => _database.ref('collections');

  /// Initialize database service
  static Future<void> initialize() async {
    try {
      // Configure database settings
      _database.setPersistenceEnabled(true);
      _database.setPersistenceCacheSizeBytes(10000000); // 10MB cache

      if (kDebugMode) {
        _database.setLoggingEnabled(true);
      }

      // Test connection
      await _testConnection();

      debugPrint('📊 Database service initialized');
    } catch (e) {
      debugPrint('❌ Database service initialization error: $e');
    }
  }

  /// Test database connectivity
  static Future<bool> _testConnection() async {
    try {
      final snapshot = await _settingsRef.child('app_version').once();
      return true;
    } catch (e) {
      debugPrint('Database connection test failed: $e');
      return false;
    }
  }

  // ==================== DEVOTIONALS ====================

  /// Get devotional by date
  /// ✅ FIXED: Use DevotionalModel instead of Devotional
  static Future<DatabaseResult<DevotionalModel?>> getDevotional(
      DateTime date) async {
    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final snapshot = await _devotionalsRef.child(dateKey).once();

      if (snapshot.snapshot.exists) {
        // ✅ FIXED: Use DevotionalModel.fromSnapshot
        final devotional = DevotionalModel.fromFirebase(
          snapshot.snapshot.key!,
          Map<String, dynamic>.from(snapshot.snapshot.value as Map),
        );
        return DatabaseResult.success(devotional);
      }

      return DatabaseResult.success(null);
    } catch (e) {
      return DatabaseResult.error('Failed to load devotional: $e');
    }
  }

  /// Get devotionals stream for real-time updates
  /// ✅ FIXED: Use DevotionalModel instead of Devotional
  static Stream<List<DevotionalModel>> getDevotionalsStream({
    int? limit,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query query = _devotionalsRef.orderByKey();

    if (startDate != null) {
      final startKey = DateFormat('yyyy-MM-dd').format(startDate);
      query = query.startAt(startKey);
    }

    if (endDate != null) {
      final endKey = DateFormat('yyyy-MM-dd').format(endDate);
      query = query.endAt(endKey);
    }

    if (limit != null) {
      query = query.limitToLast(limit);
    }

    return query.onValue.map((event) {
      if (!event.snapshot.exists) return <DevotionalModel>[];

      final data = event.snapshot.value as Map;
      final devotionals = <DevotionalModel>[];

      data.forEach((key, value) {
        if (value is Map) {
          // ✅ FIXED: Use DevotionalModel.fromFirebase
          final devotional = DevotionalModel.fromFirebase(
            key,
            Map<String, dynamic>.from(value),
          );
          devotionals.add(devotional);
        }
      });

      // ✅ FIXED: Sort by date properly with null safety
      devotionals.sort((a, b) => b.date.compareTo(a.date));
      return devotionals;
    });
  }

  /// Add or update devotional
  /// ✅ FIXED: Use DevotionalModel instead of Devotional
  static Future<DatabaseResult<bool>> saveDevotional(
      DevotionalModel devotional) async {
    try {
      if (!AuthService.isSignedIn) {
        return DatabaseResult.error('Authentication required');
      }

      final data = devotional.toFirebaseMap();

      // Add metadata
      data['updated_by'] = AuthService.currentUserEmail;
      data['updated_by_uid'] = AuthService.currentUserId;
      data['updated_at'] = ServerValue.timestamp;

      // If it's a new devotional, add creation metadata
      final exists = await _devotionalsRef.child(devotional.id).once();
      if (!exists.snapshot.exists) {
        data['created_by'] = AuthService.currentUserEmail;
        data['created_by_uid'] = AuthService.currentUserId;
        data['created_at'] = ServerValue.timestamp;
      }

      await _devotionalsRef.child(devotional.id).set(data);

      // Log activity
      await _logActivity('save_devotional', {
        'devotional_id': devotional.id,
        'title': devotional.title,
        'action': exists.snapshot.exists ? 'update' : 'create',
      });

      return DatabaseResult.success(true);
    } catch (e) {
      return DatabaseResult.error('Failed to save devotional: $e');
    }
  }

  /// Delete devotional
  static Future<DatabaseResult<bool>> deleteDevotional(
      String devotionalId) async {
    try {
      if (!AuthService.isSignedIn) {
        return DatabaseResult.error('Authentication required');
      }

      await _devotionalsRef.child(devotionalId).remove();

      // Log activity
      await _logActivity('delete_devotional', {
        'devotional_id': devotionalId,
      });

      return DatabaseResult.success(true);
    } catch (e) {
      return DatabaseResult.error('Failed to delete devotional: $e');
    }
  }

  /// Search devotionals
  /// ✅ FIXED: Use DevotionalModel instead of Devotional
  static Future<DatabaseResult<List<DevotionalModel>>> searchDevotionals(
      String query) async {
    try {
      final snapshot = await _devotionalsRef.once();
      if (!snapshot.snapshot.exists) {
        return DatabaseResult.success(<DevotionalModel>[]);
      }

      final data = snapshot.snapshot.value as Map;
      final results = <DevotionalModel>[];
      final lowerQuery = query.toLowerCase();

      data.forEach((key, value) {
        if (value is Map) {
          // ✅ FIXED: Use DevotionalModel.fromFirebase
          final devotional = DevotionalModel.fromFirebase(
            key,
            Map<String, dynamic>.from(value),
          );

          if (devotional.matchesSearch(lowerQuery)) {
            results.add(devotional);
          }
        }
      });

      // ✅ FIXED: Sort by relevance with null safety
      results.sort((a, b) {
        final aTitle = a.title.toLowerCase().contains(lowerQuery);
        final bTitle = b.title.toLowerCase().contains(lowerQuery);

        if (aTitle && !bTitle) return -1;
        if (!aTitle && bTitle) return 1;

        return b.date.compareTo(a.date); // Then by date
      });

      return DatabaseResult.success(results);
    } catch (e) {
      return DatabaseResult.error('Search failed: $e');
    }
  }

  // ==================== SONGS ====================

  /// Get songs by collection
  static Stream<List<Song>> getSongsStream(String collectionId) {
    return _songsRef.child(collectionId).onValue.map((event) {
      if (!event.snapshot.exists) return <Song>[];

      final data = event.snapshot.value as Map;
      final songs = <Song>[];

      data.forEach((key, value) {
        if (value is Map) {
          final song = Song.fromJson(
            Map<String, dynamic>.from(value),
            id: key,
          );
          songs.add(song);
        }
      });

      // Sort by song number (numeric sort)
      songs.sort((a, b) {
        final numA = int.tryParse(a.songNumber) ?? 0;
        final numB = int.tryParse(b.songNumber) ?? 0;
        return numA.compareTo(numB);
      });

      return songs;
    });
  }

  /// Get single song
  static Future<DatabaseResult<Song?>> getSong(
      String collectionId, String songId) async {
    try {
      final snapshot = await _songsRef.child(collectionId).child(songId).once();

      if (snapshot.snapshot.exists) {
        final song = Song.fromSnapshot(snapshot.snapshot);
        return DatabaseResult.success(song);
      }

      return DatabaseResult.success(null);
    } catch (e) {
      return DatabaseResult.error('Failed to load song: $e');
    }
  }

  /// Save song
  static Future<DatabaseResult<bool>> saveSong(Song song) async {
    try {
      if (!AuthService.isSignedIn) {
        return DatabaseResult.error('Authentication required');
      }

      final data = song.toJson();

      // Add metadata
      data['updated_by'] = AuthService.currentUserEmail;
      data['updated_by_uid'] = AuthService.currentUserId;
      data['updated_at'] = ServerValue.timestamp;

      // Check if new song
      final exists =
          await _songsRef.child(song.collection).child(song.id).once();
      if (!exists.snapshot.exists) {
        data['created_by'] = AuthService.currentUserEmail;
        data['created_by_uid'] = AuthService.currentUserId;
        data['created_at'] = ServerValue.timestamp;
      }

      await _songsRef.child(song.collection).child(song.id).set(data);

      // Update collection song count
      await _updateCollectionCount(song.collection);

      // Log activity
      await _logActivity('save_song', {
        'song_id': song.id,
        'title': song.title,
        'collection': song.collection,
        'action': exists.snapshot.exists ? 'update' : 'create',
      });

      return DatabaseResult.success(true);
    } catch (e) {
      return DatabaseResult.error('Failed to save song: $e');
    }
  }

  /// Delete song
  static Future<DatabaseResult<bool>> deleteSong(
      String collectionId, String songId) async {
    try {
      if (!AuthService.isSignedIn) {
        return DatabaseResult.error('Authentication required');
      }

      await _songsRef.child(collectionId).child(songId).remove();

      // Update collection song count
      await _updateCollectionCount(collectionId);

      // Log activity
      await _logActivity('delete_song', {
        'song_id': songId,
        'collection': collectionId,
      });

      return DatabaseResult.success(true);
    } catch (e) {
      return DatabaseResult.error('Failed to delete song: $e');
    }
  }

  /// Search songs across all collections
  static Future<DatabaseResult<List<Song>>> searchSongs(String query) async {
    try {
      final allSongs = <Song>[];
      final collections = ['lpmi', 'srd', 'iban', 'pandak'];

      for (final collectionId in collections) {
        final snapshot = await _songsRef.child(collectionId).once();
        if (snapshot.snapshot.exists) {
          final data = snapshot.snapshot.value as Map;

          data.forEach((key, value) {
            if (value is Map) {
              final song = Song.fromJson(
                Map<String, dynamic>.from(value),
                id: key,
              );
              if (song.matchesSearch(query)) {
                allSongs.add(song);
              }
            }
          });
        }
      }

      // Sort by relevance
      final lowerQuery = query.toLowerCase();
      allSongs.sort((a, b) {
        // Exact song number match first
        if (a.songNumber == query) return -1;
        if (b.songNumber == query) return 1;

        // Title matches
        final aTitle = a.title.toLowerCase().contains(lowerQuery);
        final bTitle = b.title.toLowerCase().contains(lowerQuery);

        if (aTitle && !bTitle) return -1;
        if (!aTitle && bTitle) return 1;

        // Then by song number
        final numA = int.tryParse(a.songNumber) ?? 0;
        final numB = int.tryParse(b.songNumber) ?? 0;
        return numA.compareTo(numB);
      });

      return DatabaseResult.success(allSongs);
    } catch (e) {
      return DatabaseResult.error('Search failed: $e');
    }
  }

  // ==================== COLLECTIONS ====================

  /// Get all collections with metadata
  static Stream<List<SongCollection>> getCollectionsStream() {
    return _collectionsRef.onValue.map((event) {
      if (!event.snapshot.exists) return <SongCollection>[];

      final data = event.snapshot.value as Map;
      final collections = <SongCollection>[];

      data.forEach((key, value) {
        if (value is Map) {
          final collection = SongCollection.fromJson(
            Map<String, dynamic>.from(value),
            id: key,
          );
          collections.add(collection);
        }
      });

      return collections;
    });
  }

  /// Update collection song count
  static Future<void> _updateCollectionCount(String collectionId) async {
    try {
      final snapshot = await _songsRef.child(collectionId).once();
      final count = snapshot.snapshot.exists
          ? (snapshot.snapshot.value as Map).length
          : 0;

      await _collectionsRef.child(collectionId).update({
        'song_count': count,
        'updated_at': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('Failed to update collection count: $e');
    }
  }

  // ==================== FAVORITES ====================

  /// Get user favorites stream
  static Stream<List<String>> getFavoritesStream(String userId) {
    return _favoritesRef.child(userId).onValue.map((event) {
      if (!event.snapshot.exists) return <String>[];

      final data = event.snapshot.value;
      if (data is List) {
        return data.cast<String>();
      } else if (data is Map) {
        return data.keys.cast<String>().toList();
      }

      return <String>[];
    });
  }

  /// Add song to favorites
  static Future<DatabaseResult<bool>> addToFavorites(
      String userId, String songId) async {
    try {
      await _favoritesRef.child(userId).child(songId).set(true);

      // Log activity
      await _logActivity('add_favorite', {'song_id': songId});

      return DatabaseResult.success(true);
    } catch (e) {
      return DatabaseResult.error('Failed to add favorite: $e');
    }
  }

  /// Remove song from favorites
  static Future<DatabaseResult<bool>> removeFromFavorites(
      String userId, String songId) async {
    try {
      await _favoritesRef.child(userId).child(songId).remove();

      // Log activity
      await _logActivity('remove_favorite', {'song_id': songId});

      return DatabaseResult.success(true);
    } catch (e) {
      return DatabaseResult.error('Failed to remove favorite: $e');
    }
  }

  /// Check if song is favorited
  static Future<bool> isFavorite(String userId, String songId) async {
    try {
      final snapshot = await _favoritesRef.child(userId).child(songId).once();
      return snapshot.snapshot.exists;
    } catch (e) {
      return false;
    }
  }

  // ==================== SETTINGS ====================

  /// Get app settings
  static Future<DatabaseResult<Map<String, dynamic>>> getSettings() async {
    try {
      final snapshot = await _settingsRef.once();
      if (snapshot.snapshot.exists) {
        return DatabaseResult.success(
          Map<String, dynamic>.from(snapshot.snapshot.value as Map),
        );
      }
      return DatabaseResult.success(<String, dynamic>{});
    } catch (e) {
      return DatabaseResult.error('Failed to load settings: $e');
    }
  }

  /// Update app settings
  static Future<DatabaseResult<bool>> updateSettings(
      Map<String, dynamic> settings) async {
    try {
      if (!AuthService.isSignedIn) {
        return DatabaseResult.error('Authentication required');
      }

      await _settingsRef.update({
        ...settings,
        'updated_by': AuthService.currentUserEmail,
        'updated_at': ServerValue.timestamp,
      });

      return DatabaseResult.success(true);
    } catch (e) {
      return DatabaseResult.error('Failed to update settings: $e');
    }
  }

  // ==================== ANALYTICS ====================

  /// Log user activity
  static Future<void> _logActivity(
      String action, Map<String, dynamic> data) async {
    if (!AuthService.isSignedIn) return;

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _analyticsRef.child('activities').push().set({
        'action': action,
        'user_id': AuthService.currentUserId,
        'user_email': AuthService.currentUserEmail,
        'timestamp': timestamp,
        'data': data,
      });
    } catch (e) {
      debugPrint('Failed to log activity: $e');
    }
  }

  /// Get activity logs stream
  static Stream<List<Map<String, dynamic>>> getActivityLogsStream(
      {int limit = 100}) {
    return _analyticsRef
        .child('activities')
        .orderByChild('timestamp')
        .limitToLast(limit)
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return <Map<String, dynamic>>[];

      final data = event.snapshot.value as Map;
      final activities = <Map<String, dynamic>>[];

      data.forEach((key, value) {
        if (value is Map) {
          final activity = Map<String, dynamic>.from(value);
          activity['id'] = key;
          activities.add(activity);
        }
      });

      // Sort by timestamp descending
      activities.sort(
          (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

      return activities;
    });
  }

  /// Get usage statistics
  static Future<DatabaseResult<Map<String, dynamic>>> getUsageStats() async {
    try {
      final snapshot = await _analyticsRef.child('stats').once();
      if (snapshot.snapshot.exists) {
        return DatabaseResult.success(
          Map<String, dynamic>.from(snapshot.snapshot.value as Map),
        );
      }
      return DatabaseResult.success(<String, dynamic>{});
    } catch (e) {
      return DatabaseResult.error('Failed to load stats: $e');
    }
  }

  // ==================== BATCH OPERATIONS ====================

  /// Batch write multiple operations
  static Future<DatabaseResult<bool>> batchWrite(
      List<DatabaseOperation> operations) async {
    try {
      final updates = <String, dynamic>{};

      for (final operation in operations) {
        switch (operation.type) {
          case DatabaseOperationType.set:
            updates[operation.path] = operation.data;
            break;
          case DatabaseOperationType.update:
            updates[operation.path] = operation.data;
            break;
          case DatabaseOperationType.delete:
            updates[operation.path] = null;
            break;
        }
      }

      await _database.ref().update(updates);

      // Log batch operation
      await _logActivity('batch_write', {
        'operation_count': operations.length,
        'operations': operations
            .map((op) => {
                  'type': op.type.name,
                  'path': op.path,
                })
            .toList(),
      });

      return DatabaseResult.success(true);
    } catch (e) {
      return DatabaseResult.error('Batch operation failed: $e');
    }
  }

  // ==================== MIGRATION HELPERS ====================

  /// Import data from JSON (for migration)
  static Future<DatabaseResult<bool>> importData({
    required String path,
    required Map<String, dynamic> data,
    bool overwrite = false,
  }) async {
    try {
      if (!AuthService.isSignedIn) {
        return DatabaseResult.error('Authentication required');
      }

      if (!overwrite) {
        final exists = await _database.ref(path).once();
        if (exists.snapshot.exists) {
          return DatabaseResult.error('Data already exists at path: $path');
        }
      }

      await _database.ref(path).set(data);

      // Log import
      await _logActivity('import_data', {
        'path': path,
        'record_count': data.length,
        'overwrite': overwrite,
      });

      return DatabaseResult.success(true);
    } catch (e) {
      return DatabaseResult.error('Import failed: $e');
    }
  }

  /// Export data to JSON
  static Future<DatabaseResult<Map<String, dynamic>>> exportData(
      String path) async {
    try {
      final snapshot = await _database.ref(path).once();
      if (snapshot.snapshot.exists) {
        return DatabaseResult.success(
          Map<String, dynamic>.from(snapshot.snapshot.value as Map),
        );
      }
      return DatabaseResult.success(<String, dynamic>{});
    } catch (e) {
      return DatabaseResult.error('Export failed: $e');
    }
  }
}

/// Database operation result wrapper
class DatabaseResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  DatabaseResult.success(this.data)
      : error = null,
        isSuccess = true;

  DatabaseResult.error(this.error)
      : data = null,
        isSuccess = false;
}

/// Database operation for batch writes
class DatabaseOperation {
  final DatabaseOperationType type;
  final String path;
  final dynamic data;

  DatabaseOperation({
    required this.type,
    required this.path,
    this.data,
  });

  DatabaseOperation.set(String path, dynamic data)
      : this(type: DatabaseOperationType.set, path: path, data: data);

  DatabaseOperation.update(String path, Map<String, dynamic> data)
      : this(type: DatabaseOperationType.update, path: path, data: data);

  DatabaseOperation.delete(String path)
      : this(type: DatabaseOperationType.delete, path: path);
}

/// Database operation types
enum DatabaseOperationType {
  set,
  update,
  delete,
}

/// ✅ ADDED: Extension method for DevotionalModel to support search
extension DevotionalSearch on DevotionalModel {
  bool matchesSearch(String query) {
    final lowerQuery = query.toLowerCase();
    return title.toLowerCase().contains(lowerQuery) ||
        content.toLowerCase().contains(lowerQuery) ||
        verse.toLowerCase().contains(lowerQuery) ||
        reference.toLowerCase().contains(lowerQuery) ||
        author.toLowerCase().contains(lowerQuery);
  }
}
