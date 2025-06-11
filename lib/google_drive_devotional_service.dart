// google_drive_devotional_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class GoogleDriveDevotionalService {
  // CORRECTED Google Sheets URL - using CSV export format
  static const String sheetId = '1E6GVXX3dHpGsohUg5e7qC9jZwRhMvNdmelHQMQBSWZ8'; // Fixed typo
  static const String csvUrl =
      'https://docs.google.com/spreadsheets/d/$sheetId/export?format=csv&gid=0';

  // For Google Docs
  static const String documentId = 'YOUR_GOOGLE_DOC_ID_HERE';
  static const String publishedDocUrl =
      'https://docs.google.com/document/d/$documentId/export?format=txt';

  static Future<Map<String, dynamic>> getTodaysDevotional() async {
    try {
      // Try Google Sheets approach first (most flexible)
      final sheetResult = await _loadFromGoogleSheets();
      if (sheetResult != null) {
        await _cacheDevotional(sheetResult);
        return sheetResult;
      }

      // Fallback to cached content
      final cached = await _getCachedDevotional();
      if (cached != null) {
        return cached;
      }

      // Ultimate fallback
      return _getOfflineFallback();
    } catch (e) {
      print('Error loading from Google Drive: $e');

      // Try cache as fallback
      final cached = await _getCachedDevotional();
      if (cached != null) {
        return cached;
      }

      return _getOfflineFallback();
    }
  }

  // FIXED: Load from Google Sheets (CSV format)
  static Future<Map<String, dynamic>?> _loadFromGoogleSheets() async {
    try {
      print('🔍 Loading from Google Sheets...');
      print('📍 URL: $csvUrl');

      final response = await http.get(
        Uri.parse(csvUrl),
        headers: {
          'User-Agent': 'LaguAdvent/1.0',
        },
      ).timeout(const Duration(seconds: 15));

      print('📊 Response status: ${response.statusCode}');
      print('📝 Response preview: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');

      if (response.statusCode == 200) {
        final csvContent = response.body;

        if (csvContent.isNotEmpty && !csvContent.contains('AppConfig')) {
          return _parseGoogleSheetsCSV(csvContent);
        } else {
          print('❌ Invalid CSV content received');
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Google Sheets loading failed: $e');
    }
    return null;
  }

  // FIXED: Parse Google Sheets CSV content based on your actual columns
  static Map<String, dynamic> _parseGoogleSheetsCSV(String csvContent) {
    final lines = csvContent.split('\n').where((line) => line.trim().isNotEmpty).toList();

    if (lines.length < 2) {
      throw Exception('Invalid CSV format - need at least header and one data row');
    }

    print('📋 CSV Lines found: ${lines.length}');
    print('📋 Header: ${lines[0]}');

    // Your actual columns from the screenshot: Title, Content, Verse, Reference
    final dataLines = lines.skip(1).toList(); // Skip header row

    if (dataLines.isEmpty) {
      throw Exception('No data found in CSV');
    }

    // Get a random devotional or cycle through them
    final today = DateTime.now();
    final dayOfYear = today.difference(DateTime(today.year, 1, 1)).inDays;
    final selectedIndex = dayOfYear % dataLines.length;
    
    final targetLine = dataLines[selectedIndex];
    print('📖 Selected line: $targetLine');

    final values = _parseCSVLine(targetLine);
    print('📊 Parsed values: $values');

    return {
      'id': 'gsheets_${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
      'title': values.isNotEmpty ? values[0].replaceAll('"', '') : 'Daily Devotional',
      'content': values.length > 1 ? values[1].replaceAll('"', '') : '',
      'verse': values.length > 2 ? values[2].replaceAll('"', '') : '',
      'reference': values.length > 3 ? values[3].replaceAll('"', '') : '',
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'source': 'Google Sheets',
      'author': 'Devotional',
    };
  }

  // Improved CSV line parser
  static List<String> _parseCSVLine(String line) {
    final values = <String>[];
    bool inQuotes = false;
    String currentValue = '';

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        values.add(currentValue.trim());
        currentValue = '';
      } else {
        currentValue += char;
      }
    }

    // Add the last value
    if (currentValue.isNotEmpty) {
      values.add(currentValue.trim());
    }

    return values;
  }

  static Future<Map<String, dynamic>?> _getCachedDevotional() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final cachedJson = prefs.getString('gdrive_devotional_$today');

    if (cachedJson != null) {
      try {
        return json.decode(cachedJson);
      } catch (e) {
        await prefs.remove('gdrive_devotional_$today');
      }
    }
    return null;
  }

  static Future<void> _cacheDevotional(Map<String, dynamic> devotional) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await prefs.setString('gdrive_devotional_$today', json.encode(devotional));

    // Clean old cache
    await _cleanOldCache(prefs);
  }

  static Future<void> _cleanOldCache(SharedPreferences prefs) async {
    final keys = prefs.getKeys().where((key) => key.startsWith('gdrive_devotional_'));
    final cutoffDate = DateTime.now().subtract(const Duration(days: 7));

    for (final key in keys) {
      try {
        final dateStr = key.replaceFirst('gdrive_devotional_', '');
        final date = DateTime.parse(dateStr);
        if (date.isBefore(cutoffDate)) {
          await prefs.remove(key);
        }
      } catch (e) {
        await prefs.remove(key);
      }
    }
  }

  static Map<String, dynamic> _getOfflineFallback() {
    return {
      'id': 'offline_${DateTime.now().millisecondsSinceEpoch}',
      'title': 'God\'s Unfailing Love',
      'content': 'Even when we cannot connect to online resources, God\'s love for us remains constant and unchanging. His word is written on our hearts, and His presence is always with us. Take this moment to reflect on His goodness and mercy in your life.',
      'verse': 'The Lord your God is with you, the Mighty Warrior who saves. He will take great delight in you; in his love he will no longer rebuke you, but will rejoice over you with singing.',
      'reference': 'Zephaniah 3:17',
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'source': 'Offline Fallback',
      'author': 'Lagu Advent',
    };
  }
}