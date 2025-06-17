// devotional_service.dart - COMPLETE GOOGLE SHEETS INTEGRATION
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DevotionalService {
  // Google Sheets Configuration
  static const String SHEET_ID = '1E6GVXX3dHpGsohUg5e7qC9jZwRhMvNdmelHQMQ8SWZ8';
  static const String DEVOTIONAL_CSV_URL =
      'https://docs.google.com/spreadsheets/d/$SHEET_ID/export?format=csv&gid=0';
  static const String APPS_SCRIPT_URL =
      'https://script.google.com/macros/s/AKfycbzD4y9TW9ldAxJ-lhHOR4C1esrutbjjXEhI5KB6OyA8GA0AgtkALfetGRTlO5KW3vZx/exec';

  static const String _cachePrefix = 'devotional_';
  static const Duration _cacheTimeout = Duration(hours: 6);

  /// Gets today's devotional - NOW ALWAYS FROM GOOGLE SHEETS
  static Future<Map<String, dynamic>> getTodaysDevotional() async {
    final today = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(today);

    try {
      // 1. Try cache first
      final cached = await _getCachedDevotional(todayKey);
      if (cached != null) {
        debugPrint('📖 Loading devotional from cache');
        return cached;
      }

      // 2. Load from Google Sheets (primary source)
      final googleSheetsResult = await _loadFromGoogleSheets();
      if (googleSheetsResult != null) {
        await _cacheDevotional(todayKey, googleSheetsResult);
        debugPrint('✅ Loaded devotional from Google Sheets');
        return googleSheetsResult;
      }

      // 3. Emergency fallback only if Google Sheets fails
      debugPrint('⚠️ Google Sheets unavailable, using fallback');
      return _getEmergencyFallback();
    } catch (e) {
      debugPrint('❌ Error loading devotional: $e');
      return _getEmergencyFallback();
    }
  }

  /// Loads devotional from Google Sheets
  static Future<Map<String, dynamic>?> _loadFromGoogleSheets() async {
    try {
      debugPrint('📡 Loading devotionals from Google Sheets...');

      final response = await http.get(
        Uri.parse(DEVOTIONAL_CSV_URL),
        headers: {
          'User-Agent': 'LaguAdvent/1.0',
          'Accept-Charset': 'utf-8',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        String csvContent;
        try {
          csvContent = utf8.decode(response.bodyBytes, allowMalformed: true);
        } catch (e) {
          csvContent = latin1.decode(response.bodyBytes);
        }

        return _parseDevotionalCSV(csvContent);
      } else {
        debugPrint('❌ HTTP Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error loading from Google Sheets: $e');
      return null;
    }
  }

  /// Parses CSV to find today's devotional
  static Map<String, dynamic> _parseDevotionalCSV(String csvContent) {
    final lines =
        csvContent.split('\n').where((line) => line.trim().isNotEmpty).toList();

    if (lines.length < 2) {
      throw Exception('Invalid CSV format');
    }

    final today = DateTime.now();
    final todayFormatted = DateFormat('dd/MM/yyyy').format(today);
    final dataLines = lines.skip(1).toList(); // Skip header

    debugPrint('🗓️ Looking for today\'s date: $todayFormatted');

    // First, try to find today's exact date
    for (int i = 0; i < dataLines.length; i++) {
      final line = dataLines[i];
      final values = _parseCSVLine(line);

      if (values.length > 1) {
        final dateValue = _cleanText(values[1]).trim();

        if (dateValue == todayFormatted) {
          debugPrint('✅ Found today\'s devotional!');
          return {
            'id': 'gsheets_${DateFormat('yyyy-MM-dd').format(today)}',
            'title':
                values.length > 2 ? _cleanText(values[2]) : 'Daily Devotional',
            'content': values.length > 3 ? _cleanText(values[3]) : '',
            'verse': values.length > 4 ? _cleanText(values[4]) : '',
            'reference': values.length > 5 ? _cleanText(values[5]) : '',
            'author':
                values.length > 6 ? _cleanText(values[6]) : 'Devotional Team',
            'date': DateFormat('yyyy-MM-dd').format(today),
            'source': 'Google Sheets',
            'loaded_at': DateTime.now().millisecondsSinceEpoch,
          };
        }
      }
    }

    // If no exact date match, find the most recent past devotional
    debugPrint('⚠️ No exact date match, looking for most recent devotional...');

    DateTime? closestDate;
    List<String>? closestValues;

    for (final line in dataLines) {
      final values = _parseCSVLine(line);
      if (values.length > 1) {
        final dateValue = _cleanText(values[1]).trim();
        try {
          final devotionalDate = DateFormat('dd/MM/yyyy').parse(dateValue);
          if (devotionalDate.isBefore(today.add(Duration(days: 1))) &&
              (closestDate == null || devotionalDate.isAfter(closestDate))) {
            closestDate = devotionalDate;
            closestValues = values;
          }
        } catch (e) {
          debugPrint('⚠️ Could not parse date: $dateValue');
        }
      }
    }

    if (closestValues != null) {
      final daysAgo = today.difference(closestDate!).inDays;
      debugPrint('📅 Using closest devotional from $daysAgo days ago');

      return {
        'id': 'gsheets_${DateFormat('yyyy-MM-dd').format(today)}',
        'title': closestValues.length > 2
            ? _cleanText(closestValues[2])
            : 'Daily Devotional',
        'content': closestValues.length > 3 ? _cleanText(closestValues[3]) : '',
        'verse': closestValues.length > 4 ? _cleanText(closestValues[4]) : '',
        'reference':
            closestValues.length > 5 ? _cleanText(closestValues[5]) : '',
        'author': closestValues.length > 6
            ? _cleanText(closestValues[6])
            : 'Devotional Team',
        'date': DateFormat('yyyy-MM-dd').format(today),
        'source': 'Google Sheets ($daysAgo days ago)',
        'loaded_at': DateTime.now().millisecondsSinceEpoch,
      };
    }

    // Last resort - use first available devotional
    debugPrint('❌ No suitable devotional found, using first available');
    final firstLine = dataLines[0];
    final values = _parseCSVLine(firstLine);

    return {
      'id': 'gsheets_${DateFormat('yyyy-MM-dd').format(today)}',
      'title': values.length > 2 ? _cleanText(values[2]) : 'Daily Devotional',
      'content': values.length > 3 ? _cleanText(values[3]) : '',
      'verse': values.length > 4 ? _cleanText(values[4]) : '',
      'reference': values.length > 5 ? _cleanText(values[5]) : '',
      'author': values.length > 6 ? _cleanText(values[6]) : 'Devotional Team',
      'date': DateFormat('yyyy-MM-dd').format(today),
      'source': 'Google Sheets (Fallback)',
      'loaded_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Adds a new devotional to Google Sheets
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
      debugPrint('📝 Adding devotional to Google Sheets...');

      final uri = Uri.parse(APPS_SCRIPT_URL).replace(queryParameters: {
        'action': 'addDevotional',
        'date': date,
        'title': title,
        'content': content,
        'verse': verse ?? '',
        'reference': reference ?? '',
        'author': author ?? 'Devotional Team',
        'addedBy': addedBy,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      });

      final response = await http.get(uri, headers: {
        'User-Agent': 'LaguAdvent/1.0',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          debugPrint('✅ Devotional added successfully');

          // Clear cache to force fresh data
          await _clearCache();
          return true;
        } else {
          debugPrint('❌ Add failed: ${result['error']}');
          return false;
        }
      } else {
        debugPrint('❌ HTTP Error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error adding devotional: $e');
      return false;
    }
  }

  /// Updates an existing devotional in Google Sheets
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
      debugPrint('📝 Updating devotional in Google Sheets...');

      final uri = Uri.parse(APPS_SCRIPT_URL).replace(queryParameters: {
        'action': 'updateDevotional',
        'originalDate': originalDate,
        'date': date,
        'title': title,
        'content': content,
        'verse': verse ?? '',
        'reference': reference ?? '',
        'author': author ?? 'Devotional Team',
        'updatedBy': updatedBy,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      });

      final response = await http.get(uri, headers: {
        'User-Agent': 'LaguAdvent/1.0',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          debugPrint('✅ Devotional updated successfully');

          // Clear cache to force fresh data
          await _clearCache();
          return true;
        } else {
          debugPrint('❌ Update failed: ${result['error']}');
          return false;
        }
      } else {
        debugPrint('❌ HTTP Error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error updating devotional: $e');
      return false;
    }
  }

  /// Deletes a devotional from Google Sheets
  static Future<bool> deleteDevotional({
    required String date,
    String deletedBy = 'Admin',
  }) async {
    try {
      debugPrint('🗑️ Deleting devotional from Google Sheets...');

      final uri = Uri.parse(APPS_SCRIPT_URL).replace(queryParameters: {
        'action': 'deleteDevotional',
        'date': date,
        'deletedBy': deletedBy,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      });

      final response = await http.get(uri, headers: {
        'User-Agent': 'LaguAdvent/1.0',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          debugPrint('✅ Devotional deleted successfully');

          // Clear cache to force fresh data
          await _clearCache();
          return true;
        } else {
          debugPrint('❌ Delete failed: ${result['error']}');
          return false;
        }
      } else {
        debugPrint('❌ HTTP Error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error deleting devotional: $e');
      return false;
    }
  }

  /// Gets all devotionals from Google Sheets
  static Future<List<Map<String, dynamic>>> getAllDevotionals() async {
    try {
      debugPrint('📡 Loading all devotionals from Google Sheets...');

      final response = await http.get(
        Uri.parse(DEVOTIONAL_CSV_URL),
        headers: {
          'User-Agent': 'LaguAdvent/1.0',
          'Accept-Charset': 'utf-8',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        String csvContent;
        try {
          csvContent = utf8.decode(response.bodyBytes, allowMalformed: true);
        } catch (e) {
          csvContent = latin1.decode(response.bodyBytes);
        }

        return _parseAllDevotionals(csvContent);
      } else {
        debugPrint('❌ HTTP Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error loading all devotionals: $e');
      return [];
    }
  }

  /// Parses CSV to get all devotionals
  static List<Map<String, dynamic>> _parseAllDevotionals(String csvContent) {
    final lines =
        csvContent.split('\n').where((line) => line.trim().isNotEmpty).toList();

    if (lines.length < 2) {
      return [];
    }

    final devotionals = <Map<String, dynamic>>[];
    final dataLines = lines.skip(1).toList(); // Skip header

    for (int i = 0; i < dataLines.length; i++) {
      try {
        final line = dataLines[i];
        final values = _parseCSVLine(line);

        if (values.length >= 3) {
          // Minimum required columns
          final devotional = {
            'id': 'gsheets_$i',
            'title': values.length > 2 ? _cleanText(values[2]) : 'Untitled',
            'content': values.length > 3 ? _cleanText(values[3]) : '',
            'verse': values.length > 4 ? _cleanText(values[4]) : '',
            'reference': values.length > 5 ? _cleanText(values[5]) : '',
            'author': values.length > 6 ? _cleanText(values[6]) : 'Unknown',
            'date': values.length > 1
                ? _parseDateFromCSV(values[1])
                : DateFormat('yyyy-MM-dd').format(DateTime.now()),
            'source': 'Google Sheets',
          };

          devotionals.add(devotional);
        }
      } catch (e) {
        debugPrint('⚠️ Error parsing line ${i + 1}: $e');
        continue;
      }
    }

    // Sort by date descending (newest first)
    devotionals.sort((a, b) =>
        DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));

    return devotionals;
  }

  // Helper methods
  static List<String> _parseCSVLine(String line) {
    final values = <String>[];
    bool inQuotes = false;
    String currentValue = '';

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (i + 1 < line.length && line[i + 1] == '"' && inQuotes) {
          currentValue += '"';
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        values.add(currentValue.trim());
        currentValue = '';
      } else {
        currentValue += char;
      }
    }
    values.add(currentValue.trim());
    return values;
  }

  static String _cleanText(String text) {
    if (text.isEmpty) return text;

    return text
        .replaceAll('â€™', "'")
        .replaceAll('â€œ', '"')
        .replaceAll('â€', '"')
        .replaceAll('â€"', '—')
        .replaceAll('â€"', '–')
        .replaceAll('â€¦', '...')
        .replaceAll('"', '"')
        .replaceAll('"', '"')
        .replaceAll(''', "'")
        .replaceAll(''', "'")
        .replaceAll(RegExp(r'^"'), '')
        .replaceAll(RegExp(r'"$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _parseDateFromCSV(String dateStr) {
    try {
      if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          final date = DateTime(year, month, day);
          return DateFormat('yyyy-MM-dd').format(date);
        }
      }
      final parsed = DateTime.parse(dateStr);
      return DateFormat('yyyy-MM-dd').format(parsed);
    } catch (e) {
      return DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
  }

  // Cache management
  static Future<Map<String, dynamic>?> _getCachedDevotional(
      String dateKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('$_cachePrefix$dateKey');

      if (cachedJson != null) {
        final cached = json.decode(cachedJson) as Map<String, dynamic>;
        final cachedAt = cached['cached_at'] as int?;
        if (cachedAt != null) {
          final cacheAge = DateTime.now().millisecondsSinceEpoch - cachedAt;
          if (cacheAge < _cacheTimeout.inMilliseconds) {
            return cached;
          } else {
            await prefs.remove('$_cachePrefix$dateKey');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error reading cache: $e');
    }
    return null;
  }

  static Future<void> _cacheDevotional(
      String dateKey, Map<String, dynamic> devotional) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final devotionalWithTimestamp = {
        ...devotional,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(
          '$_cachePrefix$dateKey', json.encode(devotionalWithTimestamp));
    } catch (e) {
      debugPrint('⚠️ Error caching devotional: $e');
    }
  }

  static Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys =
          prefs.getKeys().where((key) => key.startsWith(_cachePrefix)).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
      debugPrint('🧹 Cleared devotional cache');
    } catch (e) {
      debugPrint('⚠️ Error clearing cache: $e');
    }
  }

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

  /// Test connection to Google Sheets
  static Future<bool> testConnection() async {
    try {
      final result = await _loadFromGoogleSheets();
      return result != null;
    } catch (e) {
      return false;
    }
  }
}
