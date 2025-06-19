// devotional_service.dart - FULLY MIGRATED TO FIREBASE
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'services/firebase_service.dart';
import 'services/database_service.dart';
import 'models/devotional_model.dart';

/// Primary devotional service - now using Firebase instead of Google Sheets
class DevotionalService {
  // Cache management
  static const Duration _cacheTimeout = Duration(hours: 1);
  static DevotionalModel? _cachedTodaysDevotional;
  static DateTime? _cacheTime;

  /// Gets today's devotional - NOW FROM FIREBASE
  static Future<Map<String, dynamic>> getTodaysDevotional() async {
    try {
      debugPrint('📖 Loading today\'s devotional from Firebase...');

      // Check cache first
      if (_cachedTodaysDevotional != null && _isCacheValid()) {
        debugPrint('📖 Loading devotional from cache');
        return _cachedTodaysDevotional!.toDisplayMap();
      }

      // Load from Firebase
      final result = await FirebaseService.getTodaysDevotional();

      if (result.isSuccess) {
        _cachedTodaysDevotional = result.data!;
        _cacheTime = DateTime.now();
        debugPrint('✅ Loaded devotional from Firebase');
        return result.data!.toDisplayMap();
      } else {
        debugPrint('⚠️ Firebase failed, using fallback: ${result.error}');
        return _getEmergencyFallback();
      }
    } catch (e) {
      debugPrint('❌ Error loading devotional: $e');
      return _getEmergencyFallback();
    }
  }

  /// Stream today's devotional with real-time updates
  static Stream<Map<String, dynamic>> getTodaysDevotionalStream() {
    return FirebaseService.getTodaysDevotionalStream().map((devotional) {
      if (devotional != null) {
        _cachedTodaysDevotional = devotional;
        _cacheTime = DateTime.now();
        return devotional.toDisplayMap();
      } else {
        return _getEmergencyFallback();
      }
    });
  }

  /// Adds a new devotional to Firebase
  static Future<bool> addDevotional({
    required String date,
    required String title,
    required String content,
    String? verse,
    String? reference,
    String? author,
    String addedBy = 'Admin',
  }) async {
    try {
      debugPrint('📝 Adding devotional to Firebase...');

      // Parse date from DD/MM/YYYY to YYYY-MM-DD for Firebase key
      final dateFormat = DateFormat('dd/MM/yyyy');
      final parsedDate = dateFormat.parse(date);
      final dateKey = DateFormat('yyyy-MM-dd').format(parsedDate);

      // Create devotional model
      final devotional = DevotionalModel(
        id: dateKey,
        date: dateKey,
        title: title,
        content: content,
        verse: verse ?? '',
        reference: reference ?? '',
        author: author ?? 'Devotional Team',
        addedBy: addedBy,
        createdAt: DateTime.now(),
        source: 'Firebase',
      );

      // Save to Firebase
      final result = await FirebaseService.addDevotional(devotional);

      if (result.isSuccess) {
        debugPrint('✅ Devotional added successfully to Firebase');
        _clearCache(); // Clear cache to force refresh
        return true;
      } else {
        debugPrint('❌ Failed to add devotional: ${result.error}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error adding devotional: $e');
      return false;
    }
  }

  /// Updates an existing devotional in Firebase
  static Future<bool> updateDevotional({
    required String originalDate,
    required String date,
    required String title,
    required String content,
    String? verse,
    String? reference,
    String? author,
    String updatedBy = 'Admin',
  }) async {
    try {
      debugPrint('📝 Updating devotional in Firebase...');

      // Parse dates
      final dateFormat = DateFormat('dd/MM/yyyy');
      final parsedDate = dateFormat.parse(date);
      final dateKey = DateFormat('yyyy-MM-dd').format(parsedDate);

      // Create updated devotional model
      final devotional = DevotionalModel(
        id: dateKey,
        date: dateKey,
        title: title,
        content: content,
        verse: verse ?? '',
        reference: reference ?? '',
        author: author ?? 'Devotional Team',
        updatedBy: updatedBy,
        updatedAt: DateTime.now(),
        source: 'Firebase',
      );

      // Update in Firebase
      final result = await FirebaseService.updateDevotional(devotional);

      if (result.isSuccess) {
        debugPrint('✅ Devotional updated successfully in Firebase');
        _clearCache(); // Clear cache to force refresh
        return true;
      } else {
        debugPrint('❌ Failed to update devotional: ${result.error}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error updating devotional: $e');
      return false;
    }
  }

  /// Deletes a devotional from Firebase (Master Admin only)
  static Future<bool> deleteDevotional({
    required String date,
    String deletedBy = 'Admin',
  }) async {
    try {
      debugPrint('🗑️ Deleting devotional from Firebase...');

      // Parse date to Firebase key format
      final dateFormat = DateFormat('dd/MM/yyyy');
      final parsedDate = dateFormat.parse(date);
      final dateKey = DateFormat('yyyy-MM-dd').format(parsedDate);

      // Delete from Firebase
      final result = await FirebaseService.deleteDevotional(dateKey);

      if (result.isSuccess) {
        debugPrint('✅ Devotional deleted successfully from Firebase');
        _clearCache(); // Clear cache to force refresh
        return true;
      } else {
        debugPrint('❌ Failed to delete devotional: ${result.error}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error deleting devotional: $e');
      return false;
    }
  }

  /// Gets all devotionals from Firebase
  static Future<List<Map<String, dynamic>>> getAllDevotionals() async {
    try {
      debugPrint('📡 Loading all devotionals from Firebase...');

      // Get all devotionals stream and take first emission
      final streamResult =
          await FirebaseService.getAllDevotionalsStream().first;

      final devotionals = streamResult.map((devotional) {
        return {
          'id': devotional.id,
          'date': devotional.date,
          'title': devotional.title,
          'content': devotional.content,
          'verse': devotional.verse,
          'reference': devotional.reference,
          'author': devotional.author,
          'source': devotional.source,
          'parsedDate': DateTime.parse(devotional.date),
        };
      }).toList();

      debugPrint('✅ Loaded ${devotionals.length} devotionals from Firebase');
      return devotionals;
    } catch (e) {
      debugPrint('❌ Error loading all devotionals: $e');
      return [];
    }
  }

  /// Stream all devotionals with real-time updates
  static Stream<List<Map<String, dynamic>>> getAllDevotionalsStream() {
    return FirebaseService.getAllDevotionalsStream().map((devotionals) {
      return devotionals.map((devotional) {
        return {
          'id': devotional.id,
          'date': devotional.date,
          'title': devotional.title,
          'content': devotional.content,
          'verse': devotional.verse,
          'reference': devotional.reference,
          'author': devotional.author,
          'source': devotional.source,
          'parsedDate': DateTime.parse(devotional.date),
        };
      }).toList();
    });
  }

  /// Search devotionals in Firebase
  static Future<List<Map<String, dynamic>>> searchDevotionals(
      String query) async {
    try {
      debugPrint('🔍 Searching devotionals in Firebase for: $query');

      final result = await DatabaseService.searchDevotionals(query);

      if (result.isSuccess) {
        final devotionals = result.data!.map((devotional) {
          return {
            'id': devotional.id,
            'date': devotional.date,
            'title': devotional.title,
            'content': devotional.content,
            'verse': devotional.verse,
            'reference': devotional.reference,
            'author': devotional.author,
            'source': devotional.source,
            'parsedDate': DateTime.parse(devotional.date),
          };
        }).toList();

        debugPrint(
            '✅ Found ${devotionals.length} devotionals matching: $query');
        return devotionals;
      } else {
        debugPrint('❌ Search failed: ${result.error}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error searching devotionals: $e');
      return [];
    }
  }

  /// Test Firebase connection
  static Future<bool> testConnection() async {
    try {
      debugPrint('🧪 Testing Firebase connection...');

      final result = await FirebaseService.testConnection();

      if (result.isSuccess) {
        debugPrint('✅ Firebase connection successful!');
        return true;
      } else {
        debugPrint('❌ Firebase connection failed: ${result.error}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Firebase connection test error: $e');
      return false;
    }
  }

  /// Get devotional for specific date
  static Future<Map<String, dynamic>?> getDevotionalForDate(
      DateTime date) async {
    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      debugPrint('📖 Loading devotional for date: $dateKey');

      final result = await DatabaseService.getDevotional(date);

      if (result.isSuccess && result.data != null) {
        debugPrint('✅ Found devotional for $dateKey');
        return result.data!.toDisplayMap();
      } else {
        debugPrint('❌ No devotional found for $dateKey');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error loading devotional for date: $e');
      return null;
    }
  }

  /// Get devotionals for date range
  static Future<List<Map<String, dynamic>>> getDevotionalsInRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      debugPrint(
          '📡 Loading devotionals from ${DateFormat('yyyy-MM-dd').format(startDate)} to ${DateFormat('yyyy-MM-dd').format(endDate)}');

      final streamResult = await DatabaseService.getDevotionalsStream(
        startDate: startDate,
        endDate: endDate,
      ).first;

      final devotionals = streamResult.map((devotional) {
        return {
          'id': devotional.id,
          'date': devotional.date,
          'title': devotional.title,
          'content': devotional.content,
          'verse': devotional.verse,
          'reference': devotional.reference,
          'author': devotional.author,
          'source': devotional.source,
          'parsedDate': DateTime.parse(devotional.date),
        };
      }).toList();

      debugPrint('✅ Loaded ${devotionals.length} devotionals in date range');
      return devotionals;
    } catch (e) {
      debugPrint('❌ Error loading devotionals in range: $e');
      return [];
    }
  }

  // Private helper methods

  /// Check if cache is still valid
  static bool _isCacheValid() {
    if (_cacheTime == null) return false;
    final age = DateTime.now().difference(_cacheTime!);
    return age < _cacheTimeout;
  }

  /// Clear the cache
  static void _clearCache() {
    _cachedTodaysDevotional = null;
    _cacheTime = null;
    debugPrint('🧹 Cleared devotional cache');
  }

  /// Get emergency fallback devotional
  static Map<String, dynamic> _getEmergencyFallback() {
    return {
      'id': 'fallback_${DateTime.now().millisecondsSinceEpoch}',
      'title': 'God\'s Faithfulness',
      'content':
          'Even when technology fails, God\'s love remains constant. His faithfulness endures through every season. Take this moment to reflect on His goodness and find peace in His presence.',
      'verse':
          'Great is your faithfulness, O Lord; your mercies are new every morning.',
      'reference': 'Lamentations 3:22-23',
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'source': 'Emergency Fallback',
      'author': 'Lagu Advent',
      'loaded_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Force refresh cache (useful for debugging)
  static Future<Map<String, dynamic>> forceRefresh() async {
    debugPrint('🔄 Force refreshing devotional from Firebase...');
    _clearCache();
    return await getTodaysDevotional();
  }

  /// Get cache status (for debugging)
  static Map<String, dynamic> getCacheStatus() {
    return {
      'has_cached_devotional': _cachedTodaysDevotional != null,
      'cache_time': _cacheTime?.toIso8601String(),
      'is_cache_valid': _isCacheValid(),
      'cached_devotional_id': _cachedTodaysDevotional?.id,
      'cached_devotional_title': _cachedTodaysDevotional?.title,
    };
  }

  /// Preload devotionals for better performance
  static Future<void> preloadDevotionals() async {
    try {
      debugPrint('🚀 Preloading devotionals...');

      // Preload today's devotional
      await getTodaysDevotional();

      // Preload recent devotionals for offline access
      final recentDate = DateTime.now().subtract(const Duration(days: 7));
      await getDevotionalsInRange(
        startDate: recentDate,
        endDate: DateTime.now().add(const Duration(days: 1)),
      );

      debugPrint('✅ Preloading completed');
    } catch (e) {
      debugPrint('❌ Preloading failed: $e');
    }
  }
}
