// google_drive_devotional_service.dart - FIXED DATE MATCHING
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class GoogleDriveDevotionalService {
  static const String sheetId = '1E6GVXX3dHpGsohUg5e7qC9jZwRhMvNdmelHQMQ8SWZ8';
  static const String csvUrl =
      'https://docs.google.com/spreadsheets/d/$sheetId/export?format=csv&gid=0';

  static Future<Map<String, dynamic>> getTodaysDevotional() async {
    try {
      final sheetResult = await _loadFromGoogleSheets();
      if (sheetResult != null) {
        await _cacheDevotional(sheetResult);
        return sheetResult;
      }

      final cached = await _getCachedDevotional();
      if (cached != null) {
        return cached;
      }

      return _getOfflineFallback();
    } catch (e) {
      print('Error loading from Google Drive: $e');

      final cached = await _getCachedDevotional();
      if (cached != null) {
        return cached;
      }

      return _getOfflineFallback();
    }
  }

  static Future<Map<String, dynamic>?> _loadFromGoogleSheets() async {
    try {
      print('🔍 Loading from Google Sheets...');
      print('📍 URL: $csvUrl');

      final response = await http.get(
        Uri.parse(csvUrl),
        headers: {
          'User-Agent': 'LaguAdvent/1.0',
          'Accept': 'text/csv,text/plain,*/*',
          'Accept-Charset': 'utf-8',
        },
      ).timeout(const Duration(seconds: 15));

      print('📊 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        String csvContent;
        try {
          csvContent = utf8.decode(response.bodyBytes, allowMalformed: true);
        } catch (e) {
          print('UTF-8 decode failed, trying latin1: $e');
          csvContent = latin1.decode(response.bodyBytes);
        }

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

  // FIXED: Parse CSV to find today's actual date
  static Map<String, dynamic> _parseGoogleSheetsCSV(String csvContent) {
    final lines =
        csvContent.split('\n').where((line) => line.trim().isNotEmpty).toList();

    if (lines.length < 2) {
      throw Exception(
          'Invalid CSV format - need at least header and one data row');
    }

    print('📋 CSV Lines found: ${lines.length}');

    final dataLines = lines.skip(1).toList(); // Skip header row

    if (dataLines.isEmpty) {
      throw Exception('No data found in CSV');
    }

    // Get today's date in the same format as the CSV (DD/MM/YYYY)
    final today = DateTime.now();
    final todayFormatted = DateFormat('dd/MM/yyyy').format(today);

    print('🗓️ Looking for today\'s date: $todayFormatted');

    // First, try to find today's exact date
    for (int i = 0; i < dataLines.length; i++) {
      final line = dataLines[i];
      final values = _parseCSVLine(line);

      print('📋 Checking line ${i + 1}: $line');

      if (values.length > 1) {
        final dateValue = _cleanText(values[1]).trim();
        print('📅 Date in line: "$dateValue" vs today: "$todayFormatted"');

        if (dateValue == todayFormatted) {
          print('✅ Found today\'s devotional!');

          return {
            'id': 'gsheets_${DateFormat('yyyy-MM-dd').format(today)}',
            'title':
                values.length > 2 ? _cleanText(values[2]) : 'Daily Devotional',
            'content': values.length > 3 ? _cleanText(values[3]) : '',
            'verse': values.length > 4 ? _cleanText(values[4]) : '',
            'reference': values.length > 5 ? _cleanText(values[5]) : '',
            'date': DateFormat('yyyy-MM-dd').format(today),
            'source': 'Google Sheets',
            'author': values.length > 6 ? _cleanText(values[6]) : 'Devotional',
          };
        }
      }
    }

    // If no exact date match found, try to find the most recent past devotional
    print(
        '⚠️ No exact date match found. Looking for most recent devotional...');

    DateTime? closestDate;
    List<String>? closestValues;

    for (final line in dataLines) {
      final values = _parseCSVLine(line);

      if (values.length > 1) {
        final dateValue = _cleanText(values[1]).trim();

        try {
          final devotionalDate = DateFormat('dd/MM/yyyy').parse(dateValue);

          // Only consider dates that are today or in the past
          if (devotionalDate.isBefore(today.add(Duration(days: 1))) &&
              (closestDate == null || devotionalDate.isAfter(closestDate))) {
            closestDate = devotionalDate;
            closestValues = values;
          }
        } catch (e) {
          print('⚠️ Could not parse date: $dateValue');
        }
      }
    }

    if (closestValues != null) {
      final daysAgo = today.difference(closestDate!).inDays;
      print(
          '📅 Using closest devotional from ${DateFormat('dd/MM/yyyy').format(closestDate)} ($daysAgo days ago)');

      return {
        'id': 'gsheets_${DateFormat('yyyy-MM-dd').format(today)}',
        'title': closestValues.length > 2
            ? _cleanText(closestValues[2])
            : 'Daily Devotional',
        'content': closestValues.length > 3 ? _cleanText(closestValues[3]) : '',
        'verse': closestValues.length > 4 ? _cleanText(closestValues[4]) : '',
        'reference':
            closestValues.length > 5 ? _cleanText(closestValues[5]) : '',
        'date': DateFormat('yyyy-MM-dd').format(today),
        'source': 'Google Sheets ($daysAgo days ago)',
        'author': closestValues.length > 6
            ? _cleanText(closestValues[6])
            : 'Devotional',
      };
    }

    // Final fallback - use the first available devotional
    print('❌ No suitable devotional found, using first available');
    final firstLine = dataLines[0];
    final values = _parseCSVLine(firstLine);

    return {
      'id': 'gsheets_${DateFormat('yyyy-MM-dd').format(today)}',
      'title': values.length > 2 ? _cleanText(values[2]) : 'Daily Devotional',
      'content': values.length > 3 ? _cleanText(values[3]) : '',
      'verse': values.length > 4 ? _cleanText(values[4]) : '',
      'reference': values.length > 5 ? _cleanText(values[5]) : '',
      'date': DateFormat('yyyy-MM-dd').format(today),
      'source': 'Google Sheets (Fallback)',
      'author': values.length > 6 ? _cleanText(values[6]) : 'Devotional',
    };
  }

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

    if (currentValue.isNotEmpty || values.isNotEmpty) {
      values.add(currentValue.trim());
    }

    return values;
  }

  static String _cleanText(String text) {
    if (text.isEmpty) return text;

    String cleaned = text
        // Handle UTF-8 encoding artifacts
        .replaceAll('â€™', "'") // Right single quotation mark encoded
        .replaceAll('â€œ', '"') // Left double quotation mark encoded
        .replaceAll('â€', '"') // Right double quotation mark encoded
        .replaceAll('â€"', '—') // Em dash encoded
        .replaceAll('â€"', '–') // En dash encoded
        .replaceAll('â€¦', '...') // Horizontal ellipsis encoded

        // Handle various quote characters
        .replaceAll('"', '"') // Left double quotation mark
        .replaceAll('"', '"') // Right double quotation mark
        .replaceAll(''', "'") // Left single quotation mark
        .replaceAll(''', "'") // Right single quotation mark
        .replaceAll('‚', "'") // Single low-9 quotation mark
        .replaceAll('„', '"') // Double low-9 quotation mark

        // Handle dash characters
        .replaceAll('—', '—') // Em dash - keep as is
        .replaceAll('–', '–') // En dash - keep as is
        .replaceAll('−', '-') // Minus sign -> hyphen

        // Handle apostrophe variants
        .replaceAll('`', "'") // Grave accent
        .replaceAll('´', "'") // Acute accent
        .replaceAll('ʻ', "'") // Modifier letter turned comma
        .replaceAll('ʼ', "'") // Modifier letter apostrophe

        // Handle ellipsis
        .replaceAll('…', '...') // Horizontal ellipsis

        // Handle non-breaking spaces
        .replaceAll('\u00A0', ' ') // Non-breaking space
        .replaceAll('\u2009', ' ') // Thin space
        .replaceAll('\u202F', ' ') // Narrow no-break space

        // Remove CSV parsing quotes
        .replaceAll(RegExp(r'^"'), '') // Remove leading quote
        .replaceAll(RegExp(r'"$'), '') // Remove trailing quote

        // Clean up whitespace
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return cleaned;
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
