// khutbah_page.dart - COMPLETE WORKING VERSION
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'theme_notifier.dart';
import 'google_drive_devotional_service.dart';

class KhutbahPage extends StatefulWidget {
  final ThemeNotifier themeNotifier;

  const KhutbahPage({
    super.key,
    required this.themeNotifier,
  });

  @override
  State<KhutbahPage> createState() => _KhutbahPageState();
}

class _KhutbahPageState extends State<KhutbahPage> {
  // ALL ESSENTIAL VARIABLES
  Map<String, dynamic>? _currentDevotional;
  List<String> _bookmarkedDevotionals = [];
  List<Map<String, dynamic>> _previousDevotionals = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _error = '';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
    _loadDevotional();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bookmarkedDevotionals =
          prefs.getStringList('bookmarked_devotionals') ?? [];
    });
  }

  Future<void> _toggleBookmark(String devotionalId) async {
    final prefs = await SharedPreferences.getInstance();

    if (_bookmarkedDevotionals.contains(devotionalId)) {
      _bookmarkedDevotionals.remove(devotionalId);
    } else {
      _bookmarkedDevotionals.add(devotionalId);
    }

    await prefs.setStringList('bookmarked_devotionals', _bookmarkedDevotionals);
    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_bookmarkedDevotionals.contains(devotionalId)
              ? 'Added to bookmarks'
              : 'Removed from bookmarks'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _loadDevotional({bool forceRefresh = false}) async {
    setState(() {
      if (forceRefresh) {
        _isRefreshing = true;
      } else {
        _isLoading = true;
      }
      _error = '';
    });

    try {
      print('🔄 Loading current devotional...');
      final devotional =
          await GoogleDriveDevotionalService.getTodaysDevotional();

      print('🔄 Loading previous devotionals...');
      final previousDevotionals = await _loadPreviousDevotionals();
      print('📊 Loaded ${previousDevotionals.length} previous devotionals');

      setState(() {
        _currentDevotional = devotional;
        _previousDevotionals = previousDevotionals;
        _error = '';
      });
    } catch (e) {
      print('❌ Error loading devotional: $e');
      setState(() {
        _error = 'Failed to load devotional: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  // IMPROVED TEXT CLEANING METHOD
  String _cleanText(String text) {
    if (text.isEmpty) return text;

    String cleaned = text
        // Handle UTF-8 encoding artifacts (common when data comes from CSV/web)
        .replaceAll('â€™', "'") // Right single quotation mark encoded
        .replaceAll('â€œ', '"') // Left double quotation mark encoded
        .replaceAll('â€', '"') // Right double quotation mark encoded
        .replaceAll('â€"', '—') // Em dash encoded
        .replaceAll('â€"', '–') // En dash encoded
        .replaceAll('â€¦', '...') // Horizontal ellipsis encoded

        // Handle various quote characters
        .replaceAll('"', '"') // Left double quotation mark (U+201C)
        .replaceAll('"', '"') // Right double quotation mark (U+201D)
        .replaceAll(''', "'") // Left single quotation mark (U+2018)
        .replaceAll(''', "'") // Right single quotation mark (U+2019)
        .replaceAll('‚', "'") // Single low-9 quotation mark
        .replaceAll('„', '"') // Double low-9 quotation mark
        .replaceAll('‹', "'") // Single left-pointing angle quotation mark
        .replaceAll('›', "'") // Right-pointing angle quotation mark
        .replaceAll('«', '"') // Left-pointing double angle quotation mark
        .replaceAll('»', '"') // Right-pointing double angle quotation mark

        // Handle dash characters
        .replaceAll('—', '—') // Em dash (U+2014) - keep as is
        .replaceAll('–', '–') // En dash (U+2013) - keep as is
        .replaceAll('−', '-') // Minus sign (U+2212) -> hyphen

        // Handle apostrophe variants
        .replaceAll('`', "'") // Grave accent
        .replaceAll('´', "'") // Acute accent
        .replaceAll('ʻ', "'") // Modifier letter turned comma
        .replaceAll('ʼ', "'") // Modifier letter apostrophe

        // Handle ellipsis
        .replaceAll('…', '...') // Horizontal ellipsis

        // Handle non-breaking spaces and other whitespace
        .replaceAll('\u00A0', ' ') // Non-breaking space
        .replaceAll('\u2000', ' ') // En quad
        .replaceAll('\u2001', ' ') // Em quad
        .replaceAll('\u2002', ' ') // En space
        .replaceAll('\u2003', ' ') // Em space
        .replaceAll('\u2009', ' ') // Thin space
        .replaceAll('\u202F', ' ') // Narrow no-break space

        // Remove CSV parsing artifacts
        .replaceAll(RegExp(r'^"'), '') // Remove leading quote
        .replaceAll(RegExp(r'"$'), '') // Remove trailing quote

        // Clean up whitespace (multiple spaces, tabs, newlines)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return cleaned;
  }

  // DEBUG METHOD (removed unused warning by making it used)
  void _debugTextIssues(String label, String text) {
    if (text.contains('â€')) {
      // Only debug problematic text
      print('=== $label ===');
      print('Original: "$text"');
      print('Cleaned: "${_cleanText(text)}"');
      print(
          'Runes: ${text.runes.map((r) => 'U+${r.toRadixString(16).toUpperCase().padLeft(4, '0')}').join(' ')}');
      print('===================');
    }
  }

  Future<List<Map<String, dynamic>>> _loadPreviousDevotionals() async {
    try {
      print('📡 Fetching previous devotionals from Google Sheets...');
      const String csvUrl =
          'https://docs.google.com/spreadsheets/d/1E6GVXX3dHpGsohUg5e7qC9jZwRhMvNdmelHQMQ8SWZ8/export?format=csv&gid=0';

      final response = await http.get(
        Uri.parse(csvUrl),
        headers: {
          'User-Agent': 'LaguAdvent/1.0',
          'Accept-Charset': 'utf-8',
        },
      ).timeout(const Duration(seconds: 10));

      print('📊 Previous devotionals response: ${response.statusCode}');

      if (response.statusCode == 200) {
        String csvContent;
        try {
          csvContent = utf8.decode(response.bodyBytes, allowMalformed: true);
        } catch (e) {
          csvContent = latin1.decode(response.bodyBytes);
        }

        final result = _parsePreviousDevotionals(csvContent);
        print('✅ Successfully parsed ${result.length} previous devotionals');
        return result;
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading previous devotionals: $e');
    }

    print('🔄 Returning mock previous devotionals for testing');
    return _getMockPreviousDevotionals();
  }

  List<Map<String, dynamic>> _getMockPreviousDevotionals() {
    final today = DateTime.now();
    return List.generate(5, (index) {
      final date = today.subtract(Duration(days: index + 1));
      return {
        'date': DateFormat('dd/MM/yyyy').format(date),
        'title': 'Devotional from ${DateFormat('MMM d').format(date)}',
        'content':
            'This is sample content for the devotional from ${DateFormat('EEEE, MMM d').format(date)}. This helps test the previous devotionals section.',
        'verse': 'For I know the plans I have for you, declares the Lord...',
        'reference': 'Jeremiah 29:11',
        'author': 'Devotional Team',
        'id': 'mock_${DateFormat('yyyy-MM-dd').format(date)}',
        'source': 'Mock Data',
        'parsedDate': date,
      };
    });
  }

  List<Map<String, dynamic>> _parsePreviousDevotionals(String csvContent) {
    try {
      print('📋 Parsing CSV for previous devotionals...');
      final lines = csvContent
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();

      if (lines.length < 3) {
        print('❌ Not enough lines in CSV: ${lines.length}');
        return [];
      }

      final dataLines = lines.skip(1).toList();
      final today = DateTime.now();
      final previousDevotionals = <Map<String, dynamic>>[];

      for (int i = 1; i <= 5; i++) {
        final targetDate = today.subtract(Duration(days: i));
        final targetFormatted = DateFormat('dd/MM/yyyy').format(targetDate);

        for (int lineIndex = 0; lineIndex < dataLines.length; lineIndex++) {
          final line = dataLines[lineIndex];
          final values = _parseCSVLine(line);

          if (values.length > 1) {
            final dateValue = _cleanText(values[1]).trim();

            if (dateValue == targetFormatted && values.length > 2) {
              final devotional = {
                'date': targetFormatted,
                'title': values.length > 2 ? _cleanText(values[2]) : 'Untitled',
                'content': values.length > 3 ? _cleanText(values[3]) : '',
                'verse': values.length > 4 ? _cleanText(values[4]) : '',
                'reference': values.length > 5 ? _cleanText(values[5]) : '',
                'author': values.length > 6 ? _cleanText(values[6]) : '',
                'id': 'previous_${DateFormat('yyyy-MM-dd').format(targetDate)}',
                'source': 'Google Sheets',
                'parsedDate': targetDate,
              };

              previousDevotionals.add(devotional);
              break;
            }
          }
        }
      }

      previousDevotionals.sort((a, b) =>
          (b['parsedDate'] as DateTime).compareTo(a['parsedDate'] as DateTime));

      return previousDevotionals;
    } catch (e) {
      print('❌ Error parsing previous devotionals: $e');
      return [];
    }
  }

  List<String> _parseCSVLine(String line) {
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

  Future<void> _shareDevotional() async {
    if (_currentDevotional == null) return;

    final cleanTitle =
        _cleanText(_currentDevotional!['title'] ?? 'Daily Devotional');
    final cleanContent = _cleanText(_currentDevotional!['content'] ?? '');
    final cleanVerse = _cleanText(_currentDevotional!['verse'] ?? '');
    final cleanReference = _cleanText(_currentDevotional!['reference'] ?? '');

    final text = '''$cleanTitle

$cleanContent

"$cleanVerse"
— $cleanReference

Shared from Lagu Advent App''';

    await Clipboard.setData(ClipboardData(text: text));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Devotional copied to clipboard - ready to share!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.themeNotifier,
      builder: (context, child) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Scaffold(
          backgroundColor: colorScheme.surface,
          body: _buildBody(theme, colorScheme),
          floatingActionButton: _buildFloatingActionButton(colorScheme),
        );
      },
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme colorScheme) {
    if (_isLoading) {
      return _buildLoadingState(theme, colorScheme);
    }

    if (_error.isNotEmpty) {
      return _buildErrorState(theme, colorScheme);
    }

    if (_currentDevotional == null) {
      return _buildEmptyState(theme, colorScheme);
    }

    return RefreshIndicator(
      onRefresh: () => _loadDevotional(forceRefresh: true),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildHeaderSliver(theme, colorScheme),
          SliverPadding(
            padding: const EdgeInsets.all(20.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildTitleSection(theme, colorScheme),
                const SizedBox(height: 24),
                _buildVerseSection(theme, colorScheme),
                const SizedBox(height: 24),
                _buildContentSection(theme, colorScheme),
                const SizedBox(height: 32),
                _buildActionButtons(theme, colorScheme),
                const SizedBox(height: 32),
                _buildPreviousDevotionalsSection(theme, colorScheme),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSliver(ThemeData theme, ColorScheme colorScheme) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary,
                    colorScheme.secondary,
                  ],
                ),
              ),
              child: Image.asset(
                'assets/header_image.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary,
                          colorScheme.secondary,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.4),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getSourceIcon(),
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _currentDevotional != null
                              ? (_currentDevotional!['source'] ?? 'Unknown')
                              : 'Loading...',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Khutbah',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 3,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 2,
                          color: Colors.black45,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_currentDevotional != null)
          IconButton(
            icon: Icon(
              _bookmarkedDevotionals.contains(_currentDevotional!['id'])
                  ? Icons.bookmark
                  : Icons.bookmark_border,
            ),
            onPressed: () => _toggleBookmark(_currentDevotional!['id']),
            tooltip: 'Bookmark',
          ),
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: _shareDevotional,
          tooltip: 'Share',
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'refresh':
                _loadDevotional(forceRefresh: true);
                break;
              case 'debug':
                _showDebugInfo();
                break;
              case 'bookmarks':
                _showBookmarks();
                break;
              case 'source':
                _showSourceInfo();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'refresh',
              child: ListTile(
                leading: Icon(Icons.refresh),
                title: Text('Refresh'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'debug',
              child: ListTile(
                leading: Icon(Icons.bug_report),
                title: Text('Debug Info'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'bookmarks',
              child: ListTile(
                leading: Icon(Icons.bookmarks),
                title: Text('Bookmarks'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'source',
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Source Info'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingState(ThemeData theme, ColorScheme colorScheme) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          title: const Text('Khutbah'),
        ),
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Loading today\'s devotional...',
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(ThemeData theme, ColorScheme colorScheme) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          title: const Text('Khutbah'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _loadDevotional(forceRefresh: true),
            ),
          ],
        ),
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: 64,
                    color: colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Unable to Load Content',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _loadDevotional(forceRefresh: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          title: const Text('Khutbah'),
        ),
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.book_outlined,
                    size: 64,
                    color: colorScheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Content Available',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check your Google Drive setup or try refreshing',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getSourceIcon() {
    final source = _currentDevotional?['source'] ?? '';
    if (source.contains('Google')) {
      return Icons.cloud;
    } else if (source.contains('Offline')) {
      return Icons.cloud_off;
    }
    return Icons.record_voice_over;
  }

  Widget _buildTitleSection(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withOpacity(0.1),
            colorScheme.secondary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _cleanText(_currentDevotional!['title'] ?? 'Daily Devotional'),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          if (_currentDevotional!['author'] != null &&
              _currentDevotional!['author'] != 'Unknown' &&
              _currentDevotional!['author'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'by ${_cleanText(_currentDevotional!['author'])}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVerseSection(ThemeData theme, ColorScheme colorScheme) {
    if (_currentDevotional!['verse'] == null ||
        _currentDevotional!['verse'].toString().isEmpty) {
      return const SizedBox.shrink();
    }

    final rawVerse = _currentDevotional!['verse'].toString();
    final rawReference = _currentDevotional!['reference']?.toString() ?? '';

    // Debug problematic text
    _debugTextIssues('Verse', rawVerse);
    if (rawReference.isNotEmpty) _debugTextIssues('Reference', rawReference);

    String displayVerse = _cleanText(rawVerse);
    String displayReference = _cleanText(rawReference);

    // Handle cases where verse and reference might be combined
    if (displayVerse.contains('—') ||
        displayVerse.contains(' - ') ||
        displayVerse.contains('–')) {
      final parts = displayVerse.split(RegExp(r'\s*[—–-]\s*'));
      if (parts.length >= 2) {
        displayVerse = parts[0].trim();
        displayReference = parts.sublist(1).join(' — ').trim();
      }
    }

    // Ensure proper quote formatting for verses
    if (!displayVerse.startsWith('"') && !displayVerse.startsWith('"')) {
      displayVerse = '"$displayVerse"';
    }

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: colorScheme.secondary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.secondary.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.format_quote,
            color: colorScheme.secondary,
            size: 32,
          ),
          const SizedBox(height: 16),
          SelectableText(
            displayVerse,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontStyle: FontStyle.italic,
              height: 1.6,
              color: colorScheme.onSurface,
              fontSize: 18,
              fontFamily: 'serif',
            ),
            textAlign: TextAlign.center,
          ),
          if (displayReference.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              displayReference.startsWith('—')
                  ? displayReference
                  : '— $displayReference',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.secondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContentSection(ThemeData theme, ColorScheme colorScheme) {
    final content =
        _currentDevotional!['content']?.toString() ?? 'No content available';

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SelectableText(
        _cleanText(content),
        style: theme.textTheme.bodyLarge?.copyWith(
          height: 1.8,
          color: colorScheme.onSurface,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme, ColorScheme colorScheme) {
    final isBookmarked =
        _bookmarkedDevotionals.contains(_currentDevotional!['id']);

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _toggleBookmark(_currentDevotional!['id']),
            icon: Icon(
              isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            ),
            label: Text(
              isBookmarked ? 'Bookmarked' : 'Bookmark',
            ),
            style: FilledButton.styleFrom(
              backgroundColor:
                  isBookmarked ? colorScheme.secondary : colorScheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _shareDevotional,
            icon: const Icon(Icons.share),
            label: const Text('Share'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviousDevotionalsSection(
      ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.history,
              color: colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Previous Devotionals',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_previousDevotionals.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _previousDevotionals.isEmpty
              ? _buildEmptyPreviousState(theme, colorScheme)
              : _buildPreviousDevotionalsList(theme, colorScheme),
        ),
      ],
    );
  }

  Widget _buildEmptyPreviousState(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Icon(
            Icons.schedule,
            size: 48,
            color: colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading Previous Devotionals...',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Previous devotionals will appear here once loaded',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _loadDevotional(forceRefresh: true),
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousDevotionalsList(
      ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        for (int i = 0; i < _previousDevotionals.length; i++) ...[
          _buildPreviousDevotionalItem(
            _previousDevotionals[i],
            theme,
            colorScheme,
            i + 1,
          ),
          if (i < _previousDevotionals.length - 1)
            Divider(
              height: 1,
              color: colorScheme.outline.withOpacity(0.2),
            ),
        ],
      ],
    );
  }

  Widget _buildPreviousDevotionalItem(
    Map<String, dynamic> devotional,
    ThemeData theme,
    ColorScheme colorScheme,
    int daysAgo,
  ) {
    return InkWell(
      onTap: () => _viewPreviousDevotional(devotional),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Center(
                child: Text(
                  '-$daysAgo',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _cleanText(devotional['title'] ?? 'Untitled'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatRelativeDate(devotional['parsedDate'] as DateTime),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 1) {
      return 'Yesterday';
    } else if (difference <= 7) {
      return '$difference days ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  void _viewPreviousDevotional(Map<String, dynamic> devotional) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _cleanText(devotional['title'] ?? 'Untitled'),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          _formatRelativeDate(
                              devotional['parsedDate'] as DateTime),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.7),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (devotional['verse'] != null &&
                          devotional['verse'].toString().isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20.0),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondary
                                .withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.format_quote,
                                color: Theme.of(context).colorScheme.secondary,
                                size: 24,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '"${_cleanText(devotional['verse'])}"',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      fontStyle: FontStyle.italic,
                                      height: 1.5,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              if (devotional['reference'] != null &&
                                  devotional['reference']
                                      .toString()
                                      .isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  '— ${_cleanText(devotional['reference'])}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.2),
                          ),
                        ),
                        child: SelectableText(
                          _cleanText(
                              devotional['content'] ?? 'No content available'),
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    height: 1.7,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildFloatingActionButton(ColorScheme colorScheme) {
    if (_isRefreshing) return null;

    return FloatingActionButton(
      onPressed: () => _loadDevotional(forceRefresh: true),
      tooltip: 'Refresh',
      child: const Icon(Icons.refresh),
    );
  }

  void _showDebugInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Information'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Current Devotional: ${_currentDevotional != null ? "✅ Loaded" : "❌ Not Loaded"}'),
              const SizedBox(height: 8),
              Text(
                  'Previous Devotionals: ${_previousDevotionals.length} items'),
              const SizedBox(height: 8),
              Text('Loading: $_isLoading'),
              const SizedBox(height: 8),
              Text('Refreshing: $_isRefreshing'),
              const SizedBox(height: 8),
              Text('Error: ${_error.isEmpty ? "None" : _error}'),
              const SizedBox(height: 16),
              if (_currentDevotional != null) ...[
                const Text('Current Devotional Details:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Title: ${_currentDevotional!['title']}'),
                Text('Source: ${_currentDevotional!['source']}'),
                Text('ID: ${_currentDevotional!['id']}'),
                const SizedBox(height: 16),
              ],
              const Text('Previous Devotionals:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              if (_previousDevotionals.isEmpty)
                const Text('No previous devotionals loaded')
              else
                ..._previousDevotionals
                    .map((dev) => Text('• ${dev['title']} (${dev['date']})')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadDevotional(forceRefresh: true);
            },
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  void _showSourceInfo() {
    if (_currentDevotional == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Content Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Source: ${_currentDevotional!['source']}'),
            const SizedBox(height: 8),
            Text('Author: ${_currentDevotional!['author']}'),
            const SizedBox(height: 8),
            Text('Date: ${_currentDevotional!['date']}'),
            const SizedBox(height: 8),
            Text('ID: ${_currentDevotional!['id']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showBookmarks() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Bookmarked Devotionals',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              if (_bookmarkedDevotionals.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bookmark_border,
                          size: 48,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No bookmarks yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the bookmark icon to save devotionals for later reading.',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.7),
                                  ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _bookmarkedDevotionals.length,
                    itemBuilder: (context, index) {
                      final id = _bookmarkedDevotionals[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            Icons.bookmark,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text('Devotional ${id.split('_').last}'),
                          subtitle: Text('Tap to remove from bookmarks'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              _toggleBookmark(id);
                              if (_bookmarkedDevotionals.isEmpty) {
                                Navigator.pop(context);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
