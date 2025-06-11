// google_drive_devotional_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class GoogleDriveDevotionalService {
  // OPTION 1: Published Google Docs URLs
  // Make your Google Doc public and get the document ID
  static const String documentId = 'YOUR_GOOGLE_DOC_ID_HERE';
  static const String publishedDocUrl =
      'https://docs.google.com/document/d/$documentId/export?format=txt';

  // OPTION 2: Google Sheets CSV URLs
  // More structured approach with multiple devotionals
  static const String sheetId = '1E6GVXX3dHpGsohUg5e7qC9jZwRhMvNdmelHQMQ8SWZ8';
  static const String csvUrl =
      'https://docs.google.com/spreadsheets/d/1E6GVXX3dHpGsohUg5e7qC9jZwRhMvNdmelHQMQ8SWZ8/edit?gid=0#gid=0';

  // OPTION 3: Multiple Google Docs (different docs for different days/themes)
  static const Map<String, String> dailyDocs = {
    'monday': 'MONDAY_DOC_ID',
    'tuesday': 'TUESDAY_DOC_ID',
    'wednesday': 'WEDNESDAY_DOC_ID',
    'thursday': 'THURSDAY_DOC_ID',
    'friday': 'FRIDAY_DOC_ID',
    'saturday': 'SATURDAY_DOC_ID',
    'sunday': 'SUNDAY_DOC_ID',
  };

  static Future<Map<String, dynamic>> getTodaysDevotional() async {
    try {
      // Try different methods in order of preference

      // 1. Try Google Sheets approach (most flexible)
      final sheetResult = await _loadFromGoogleSheets();
      if (sheetResult != null) {
        await _cacheDevotional(sheetResult);
        return sheetResult;
      }

      // 2. Try single Google Doc approach
      final docResult = await _loadFromGoogleDoc();
      if (docResult != null) {
        await _cacheDevotional(docResult);
        return docResult;
      }

      // 3. Try daily docs approach
      final dailyResult = await _loadDailyGoogleDoc();
      if (dailyResult != null) {
        await _cacheDevotional(dailyResult);
        return dailyResult;
      }

      // 4. Fallback to cached content
      final cached = await _getCachedDevotional();
      if (cached != null) {
        return cached;
      }

      // 5. Ultimate fallback
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

  // OPTION 1: Load from single published Google Doc
  static Future<Map<String, dynamic>?> _loadFromGoogleDoc() async {
    try {
      print('🔍 Loading from Google Doc...');

      final response = await http.get(
        Uri.parse(publishedDocUrl),
        headers: {
          'User-Agent': 'LaguAdvent/1.0',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final content = response.body;

        if (content.isNotEmpty && content.length > 50) {
          return _parseGoogleDocContent(content);
        }
      }
    } catch (e) {
      print('Google Doc loading failed: $e');
    }
    return null;
  }

  // OPTION 2: Load from Google Sheets (CSV format)
  static Future<Map<String, dynamic>?> _loadFromGoogleSheets() async {
    try {
      print('🔍 Loading from Google Sheets...');

      final response = await http.get(
        Uri.parse(csvUrl),
        headers: {
          'User-Agent': 'LaguAdvent/1.0',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final csvContent = response.body;

        if (csvContent.isNotEmpty) {
          return _parseGoogleSheetsCSV(csvContent);
        }
      }
    } catch (e) {
      print('Google Sheets loading failed: $e');
    }
    return null;
  }

  // OPTION 3: Load daily-specific Google Doc
  static Future<Map<String, dynamic>?> _loadDailyGoogleDoc() async {
    try {
      final today = DateTime.now();
      final dayName = DateFormat('EEEE').format(today).toLowerCase();

      final docId = dailyDocs[dayName];
      if (docId == null) return null;

      print('🔍 Loading daily doc for $dayName...');

      final dailyUrl =
          'https://docs.google.com/document/d/$docId/export?format=txt';

      final response = await http.get(
        Uri.parse(dailyUrl),
        headers: {
          'User-Agent': 'LaguAdvent/1.0',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final content = response.body;

        if (content.isNotEmpty && content.length > 50) {
          return _parseGoogleDocContent(content, dayName);
        }
      }
    } catch (e) {
      print('Daily Google Doc loading failed: $e');
    }
    return null;
  }

  // Parse Google Doc plain text content
  static Map<String, dynamic> _parseGoogleDocContent(String content,
      [String? source]) {
    final lines =
        content.split('\n').where((line) => line.trim().isNotEmpty).toList();

    String title = 'Daily Devotional';
    String mainContent = '';
    String verse = '';
    String reference = '';

    // Try to parse structured content
    // Expected format:
    // Title: Your Title Here
    // Content: Your devotional content...
    // Verse: "Your Bible verse here"
    // Reference: John 3:16

    String currentSection = '';

    for (final line in lines) {
      final trimmedLine = line.trim();

      if (trimmedLine.toLowerCase().startsWith('title:')) {
        title = trimmedLine.substring(6).trim();
        currentSection = 'title';
      } else if (trimmedLine.toLowerCase().startsWith('content:')) {
        mainContent = trimmedLine.substring(8).trim();
        currentSection = 'content';
      } else if (trimmedLine.toLowerCase().startsWith('verse:')) {
        verse = trimmedLine.substring(6).trim().replaceAll('"', '');
        currentSection = 'verse';
      } else if (trimmedLine.toLowerCase().startsWith('reference:')) {
        reference = trimmedLine.substring(10).trim();
        currentSection = 'reference';
      } else {
        // Continue adding to current section
        switch (currentSection) {
          case 'content':
            mainContent += ' $trimmedLine';
            break;
          case 'verse':
            verse += ' $trimmedLine';
            break;
          default:
            // If no structure, treat as content
            if (mainContent.isEmpty) {
              mainContent = trimmedLine;
            } else {
              mainContent += ' $trimmedLine';
            }
        }
      }
    }

    // If no structured format found, use the entire content
    if (title == 'Daily Devotional' &&
        mainContent.isEmpty &&
        lines.isNotEmpty) {
      title = lines.isNotEmpty ? lines.first : 'Daily Devotional';
      mainContent = lines.skip(1).join(' ');
    }

    return {
      'id': 'gdrive_${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
      'title': title,
      'content': mainContent.trim(),
      'verse': verse.trim(),
      'reference': reference.trim(),
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'source': source ?? 'Google Drive',
      'author': 'Google Drive Document',
    };
  }

  // Parse Google Sheets CSV content
  static Map<String, dynamic> _parseGoogleSheetsCSV(String csvContent) {
    final lines = csvContent.split('\n');

    if (lines.length < 2) {
      throw Exception('Invalid CSV format');
    }

    // Expected CSV format:
    // Date,Title,Content,Verse,Reference,Author
    // 2024-01-01,"Daily Title","Content here","Verse text","John 3:16","Author Name"

    final headers =
        lines[0].split(',').map((h) => h.trim().replaceAll('"', '')).toList();
    final dataLines =
        lines.skip(1).where((line) => line.trim().isNotEmpty).toList();

    if (dataLines.isEmpty) {
      throw Exception('No data found in CSV');
    }

    // Get today's devotional or latest one
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Try to find today's devotional first
    String? todaysLine;
    for (final line in dataLines) {
      if (line.contains(today)) {
        todaysLine = line;
        break;
      }
    }

    // If no devotional for today, get the latest one
    final targetLine = todaysLine ?? dataLines.last;

    final values = _parseCSVLine(targetLine);

    return {
      'id': 'gsheets_${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
      'title': values.length > 1 ? values[1] : 'Daily Devotional',
      'content': values.length > 2 ? values[2] : '',
      'verse': values.length > 3 ? values[3] : '',
      'reference': values.length > 4 ? values[4] : '',
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'source': 'Google Sheets',
      'author': values.length > 5 ? values[5] : 'Google Sheets',
    };
  }

  // Simple CSV line parser (handles basic quoted values)
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

    values.add(currentValue.trim());
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
    final keys =
        prefs.getKeys().where((key) => key.startsWith('gdrive_devotional_'));
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
      'content':
          'Even when we cannot connect to online resources, God\'s love for us remains constant and unchanging. His word is written on our hearts, and His presence is always with us. Take this moment to reflect on His goodness and mercy in your life.',
      'verse':
          'The Lord your God is with you, the Mighty Warrior who saves. He will take great delight in you; in his love he will no longer rebuke you, but will rejoice over you with singing.',
      'reference': 'Zephaniah 3:17',
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'source': 'Offline Fallback',
      'author': 'Lagu Advent',
    };
  }
}
