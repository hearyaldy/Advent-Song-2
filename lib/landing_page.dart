// landing_page.dart - COMPLETE UPDATED VERSION WITH KHUTBAH INTEGRATION
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'song_list_page.dart';
import 'song_detail_page.dart';
import 'settings_page.dart';
import 'theme_notifier.dart';
import 'khutbah_page.dart'; // NEW: Import for Khutbah page

class LandingPage extends StatefulWidget {
  final ThemeNotifier themeNotifier;

  const LandingPage({
    super.key,
    required this.themeNotifier,
  });

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  Map<String, dynamic>? _verseOfTheDay;
  List<Map<String, dynamic>> _recentFavorites = [];
  final Map<String, int> _collectionCounts = {};
  bool _isLoading = true;
  String _currentDate = '';
  String _greeting = '';

  final Map<String, String> _collectionFiles = {
    'Lagu Pujian Masa Ini': 'lpmi.json',
    'Syair Rindu Dendam': 'srd.json',
    'Lagu Iban': 'iban.json',
    'Lagu Pandak': 'pandak.json',
    'Khutbah': 'khutbah.json', // NEW: Future expansion
    'Media': 'media.json', // NEW: Future expansion
  };

  final Map<String, IconData> _collectionIcons = {
    'Lagu Pujian Masa Ini': Icons.church,
    'Syair Rindu Dendam': Icons.favorite,
    'Lagu Iban': Icons.language,
    'Lagu Pandak': Icons.music_note,
    'Khutbah': Icons.record_voice_over, // NEW: Sermon/speech icon
    'Media': Icons.video_library, // NEW: Media library icon
  };

  final Map<String, Color> _collectionColors = {
    'Lagu Pujian Masa Ini': Color(0xFF6366F1),
    'Syair Rindu Dendam': Color(0xFFDC2626),
    'Lagu Iban': Color(0xFF059669),
    'Lagu Pandak': Color(0xFFD97706),
    'Khutbah': Color(0xFF7C2D12), // NEW: Brown/sermon color
    'Media': Color(0xFF4338CA), // NEW: Indigo/media color
  };

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    await Future.wait([
      _loadCollectionCounts(),
      _loadRecentFavorites(),
      _loadVerseOfTheDay(),
    ]);
    _setGreetingAndDate();
    setState(() {
      _isLoading = false;
    });
  }

  void _setGreetingAndDate() {
    final now = DateTime.now();
    final hour = now.hour;

    if (hour < 12) {
      _greeting = 'Selamat Pagi';
    } else if (hour < 17) {
      _greeting = 'Selamat Tengah Hari';
    } else {
      _greeting = 'Selamat Petang';
    }

    _currentDate = DateFormat('EEEE, MMMM d, yyyy').format(now);
  }

  Future<void> _loadCollectionCounts() async {
    for (final entry in _collectionFiles.entries) {
      try {
        final String data =
            await rootBundle.loadString('assets/${entry.value}');
        final List<dynamic> songs = json.decode(data);
        _collectionCounts[entry.key] = songs.length;
      } catch (e) {
        _collectionCounts[entry.key] = 0;
      }
    }
  }

  Future<void> _loadRecentFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteSongs = prefs.getStringList('favorites') ?? [];

    if (favoriteSongs.isEmpty) return;

    List<Map<String, dynamic>> allSongs = [];

    // Load all songs from all collections
    for (final entry in _collectionFiles.entries) {
      try {
        final String data =
            await rootBundle.loadString('assets/${entry.value}');
        final List<dynamic> songs = json.decode(data);
        for (var song in songs) {
          if (song is Map<String, dynamic>) {
            song['collection'] = entry.key;
            allSongs.add(song);
          }
        }
      } catch (e) {
        // Handle error silently
      }
    }

    // Get recent favorites (last 5)
    final recentFavoriteNumbers = favoriteSongs.take(5).toList();
    _recentFavorites = allSongs
        .where((song) =>
            recentFavoriteNumbers.contains(song['song_number']?.toString()))
        .toList();
  }

  Future<void> _loadVerseOfTheDay() async {
    try {
      // Load a random verse from all collections
      final allVerses = <Map<String, dynamic>>[];

      for (final entry in _collectionFiles.entries) {
        try {
          final String data =
              await rootBundle.loadString('assets/${entry.value}');
          final List<dynamic> songs = json.decode(data);

          for (var songData in songs) {
            if (songData is Map<String, dynamic>) {
              final song = Map<String, dynamic>.from(songData);
              if (song['verses'] != null &&
                  song['verses'] is List &&
                  (song['verses'] as List).isNotEmpty) {
                final verses = song['verses'] as List;
                final randomVerse = verses[Random().nextInt(verses.length)];
                if (randomVerse is Map<String, dynamic>) {
                  allVerses.add({
                    'song_title': song['song_title'] ?? 'Unknown Song',
                    'song_number': song['song_number'] ?? '0',
                    'collection': entry.key,
                    'verse_number': randomVerse['verse_number'] ?? 'Verse 1',
                    'lyrics': randomVerse['lyrics'] ?? '',
                    'full_song': song,
                  });
                }
              }
            }
          }
        } catch (e) {
          // Skip files that don't exist (like khutbah.json, media.json)
          continue;
        }
      }

      if (allVerses.isNotEmpty) {
        // Use date as seed for consistent daily verse
        final today = DateTime.now();
        final seed = today.year * 10000 + today.month * 100 + today.day;
        final random = Random(seed);
        _verseOfTheDay = allVerses[random.nextInt(allVerses.length)];
      }
    } catch (e) {
      // Handle error silently
    }
  }

  // NEW: Helper method to get collection descriptions
  String _getCollectionDescription(String collection, int count) {
    switch (collection) {
      case 'Khutbah':
        return 'Daily devotionals';
      case 'Media':
        return 'Coming soon';
      default:
        return '$count songs';
    }
  }

  // NEW: Method to show coming soon dialog
  void _showComingSoon(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Coming Soon'),
        content: Text(
            '$feature feature is under development and will be available in a future update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.themeNotifier,
      builder: (context, child) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final isDarkMode = theme.brightness == Brightness.dark;

        if (_isLoading) {
          return Scaffold(
            backgroundColor: colorScheme.surface,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Loading songs...',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: colorScheme.surface,
          body: CustomScrollView(
            slivers: [
              // App Bar with custom title positioning
              SliverAppBar(
                expandedHeight: 120,
                floating: true,
                pinned: true,
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background gradient
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
                      ),
                      // Optional background image
                      Image.asset(
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
                      // Overlay for better text contrast
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.2),
                            ],
                          ),
                        ),
                      ),
                      // CUSTOM POSITIONED TITLE AND DATE
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 80, // Leave space for settings icon
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Lagu Advent',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    offset: Offset(0, 1),
                                    blurRadius: 3,
                                    color: Colors.black.withValues(alpha: 0.7),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              _currentDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    offset: Offset(0, 1),
                                    blurRadius: 3,
                                    color: Colors.black.withValues(alpha: 0.7),
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
                  IconButton(
                    icon: Icon(
                      Icons.settings,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SettingsPage(
                            themeNotifier: widget.themeNotifier,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),

              // Content
              SliverPadding(
                padding: const EdgeInsets.all(20.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Greeting
                    _buildGreetingCard(),
                    const SizedBox(height: 24),

                    // Verse of the Day
                    if (_verseOfTheDay != null) ...[
                      _buildVerseOfTheDayCard(),
                      const SizedBox(height: 24),
                    ],

                    // Quick Stats
                    _buildStatsCard(),
                    const SizedBox(height: 32),

                    // Collections
                    _buildSectionHeader('Collections'),
                    const SizedBox(height: 16),
                    _buildCollectionsGrid(),
                    const SizedBox(height: 32),

                    // Recent Favorites - NOW AS LIST
                    if (_recentFavorites.isNotEmpty) ...[
                      _buildSectionHeader('Recent Favorites'),
                      const SizedBox(height: 16),
                      _buildRecentFavoritesList(), // Changed to list style
                      const SizedBox(height: 32),
                    ],

                    // Quick Actions
                    _buildSectionHeader('Quick Actions'),
                    const SizedBox(height: 16),
                    _buildQuickActions(),

                    const SizedBox(height: 40), // Bottom padding
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGreetingCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        // ENHANCED: Gradient background - FIXED withOpacity deprecation
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  colorScheme.surfaceContainerHighest,
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
                ]
              : [
                  colorScheme.surface,
                  colorScheme.primary.withValues(alpha: 0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withValues(alpha: 0.3)
                : colorScheme.primary.withValues(alpha: 0.15),
            blurRadius: isDarkMode ? 15 : 25,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 28, // INCREASED: More prominent greeting
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Selamat Kembali ke Aplikasi Lagu Advent',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary.withValues(alpha: 0.2),
                  colorScheme.secondary.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(
              _getGreetingIcon(),
              color: colorScheme.primary,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerseOfTheDayCard() {
    if (_verseOfTheDay == null) return const SizedBox();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      decoration: BoxDecoration(
        // ENHANCED: Gradient background - FIXED withOpacity deprecation
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  colorScheme.surfaceContainerHighest,
                  colorScheme.surface,
                ]
              : [
                  colorScheme.surface,
                  colorScheme.secondary.withValues(alpha: 0.08),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withValues(alpha: 0.4)
                : colorScheme.secondary.withValues(alpha: 0.2),
            blurRadius: isDarkMode ? 20 : 30,
            offset: const Offset(0, 12),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with theme colors
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.secondary.withValues(alpha: 0.2),
                        colorScheme.primary.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colorScheme.secondary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: colorScheme.secondary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Lagu Hari Ini',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.secondary.withValues(alpha: 0.15),
                        colorScheme.primary.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.secondary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    DateFormat('MMM d').format(DateTime.now()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Verse content with better contrast
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDarkMode
                      ? [
                          colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.2),
                        ]
                      : [
                          colorScheme.secondary.withValues(alpha: 0.08),
                          colorScheme.primary.withValues(alpha: 0.05),
                        ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.secondary.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                _verseOfTheDay!['lyrics']?.toString() ?? 'No lyrics available',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                  color: colorScheme.onSurface,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 16),

            // Attribution and action
            Row(
              children: [
                Expanded(
                  child: Text(
                    _verseOfTheDay!['song_title']?.toString() ?? 'Unknown',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.secondary.withValues(alpha: 0.15),
                        colorScheme.primary.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextButton(
                    onPressed: () {
                      final fullSong = _verseOfTheDay!['full_song'];
                      final collection = _verseOfTheDay!['collection'];
                      if (fullSong != null && collection != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SongDetailPage(
                              song: fullSong,
                              collectionName: collection.toString(),
                              onFavoriteChanged: () {},
                            ),
                          ),
                        );
                      }
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.secondary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Read More'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    final totalSongs =
        _collectionCounts.values.fold<int>(0, (sum, count) => sum + count);
    final favoritesCount = _recentFavorites.length;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        // ENHANCED: Gradient background - FIXED withOpacity deprecation
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  colorScheme.surfaceContainerHighest,
                  colorScheme.surface,
                ]
              : [
                  colorScheme.surface,
                  colorScheme.primary.withValues(alpha: 0.03),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withValues(alpha: 0.3)
                : colorScheme.primary.withValues(alpha: 0.15),
            blurRadius: isDarkMode ? 15 : 25,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text(
                  totalSongs.toString(),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Songs',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              children: [
                Text(
                  _collectionCounts.length.toString(),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Collections',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              children: [
                Text(
                  favoritesCount.toString(),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Favorites',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
      ),
    );
  }

  // UPDATED: Collections Grid with Khutbah navigation
  Widget _buildCollectionsGrid() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: _collectionFiles.length,
      itemBuilder: (context, index) {
        final collection = _collectionFiles.keys.elementAt(index);
        final count = _collectionCounts[collection] ?? 0;
        final icon = _collectionIcons[collection] ?? Icons.music_note;
        final color = _collectionColors[collection] ?? colorScheme.primary;

        return Container(
          decoration: BoxDecoration(
            // ENHANCED: Gradient background for collection cards - FIXED withOpacity deprecation
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDarkMode
                  ? [
                      colorScheme.surfaceContainerHighest,
                      colorScheme.surface,
                    ]
                  : [
                      colorScheme.surface,
                      color.withValues(alpha: 0.05),
                    ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withValues(alpha: 0.3)
                    : color.withValues(alpha: 0.2),
                blurRadius: isDarkMode ? 10 : 15,
                offset: const Offset(0, 6),
                spreadRadius: 0,
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              // UPDATED: Handle different collection types
              if (collection == 'Khutbah') {
                // Navigate to Khutbah (Devotional) page
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => KhutbahPage(
                      themeNotifier: widget.themeNotifier,
                    ),
                  ),
                );
              } else if (collection == 'Media') {
                // Future: Navigate to Media page
                _showComingSoon('Media Library');
              } else {
                // Navigate to regular song list
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SongListPage(
                      themeNotifier: widget.themeNotifier,
                      initialCollection: collection,
                    ),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  8.0, 16.0, 8.0, 8.0), // INCREASED: More top padding
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withValues(alpha: 0.2),
                          color.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: color.withValues(alpha: 0.4), width: 1),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          collection,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.visible,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getCollectionDescription(collection, count),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // UPDATED: Recent Favorites as List Style - FIXED withOpacity deprecation
  Widget _buildRecentFavoritesList() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        // ENHANCED: Gradient background for favorites list - FIXED withOpacity deprecation
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDarkMode
              ? [
                  colorScheme.surfaceContainerHighest,
                  colorScheme.surface,
                ]
              : [
                  colorScheme.surface,
                  Colors.red.withValues(alpha: 0.02),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.red.withValues(alpha: 0.1),
            blurRadius: isDarkMode ? 10 : 20,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header for favorites list
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.withValues(alpha: 0.1),
                  Colors.red.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.favorite,
                  color: Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Your Recent Favorites',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '${_recentFavorites.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // List of favorites
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentFavorites.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: colorScheme.outline.withValues(alpha: 0.1),
            ),
            itemBuilder: (context, index) {
              final song = _recentFavorites[index];
              return ListTile(
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  child: Text(
                    song['song_number']?.toString() ?? '0',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                title: Text(
                  song['song_title']?.toString() ?? 'Unknown Song',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  song['collection']?.toString() ?? 'Unknown Collection',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Icon(
                  Icons.favorite,
                  color: Colors.red,
                  size: 18,
                ),
                onTap: () {
                  final collection = song['collection'];
                  if (collection != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SongDetailPage(
                          song: song,
                          collectionName: collection.toString(),
                        ),
                      ),
                    );
                  }
                },
              );
            },
          ),
          // View all favorites button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.withValues(alpha: 0.05),
                  Colors.red.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SongListPage(
                      themeNotifier: widget.themeNotifier,
                      showFavoritesOnly: true,
                    ),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: Text('View All Favorites'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              // ENHANCED: Gradient background for quick actions - FIXED withOpacity deprecation
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDarkMode
                    ? [
                        colorScheme.surfaceContainerHighest,
                        colorScheme.surface,
                      ]
                    : [
                        colorScheme.surface,
                        Colors.red.withValues(alpha: 0.03),
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withValues(alpha: 0.2)
                      : Colors.red.withValues(alpha: 0.1),
                  blurRadius: isDarkMode ? 8 : 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SongListPage(
                      themeNotifier: widget.themeNotifier,
                      showFavoritesOnly: true,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 28,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Favorites',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              // ENHANCED: Gradient background for quick actions - FIXED withOpacity deprecation
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDarkMode
                    ? [
                        colorScheme.surfaceContainerHighest,
                        colorScheme.surface,
                      ]
                    : [
                        colorScheme.surface,
                        colorScheme.primary.withValues(alpha: 0.03),
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withValues(alpha: 0.2)
                      : colorScheme.primary.withValues(alpha: 0.1),
                  blurRadius: isDarkMode ? 8 : 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SongListPage(
                      themeNotifier: widget.themeNotifier,
                      openSearch: true,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.search,
                      color: colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Search',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) return Icons.wb_sunny;
    if (hour < 17) return Icons.wb_sunny_outlined;
    return Icons.nights_stay;
  }
}
