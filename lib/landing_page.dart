// landing_page.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'song_list_page.dart';
import 'song_detail_page.dart';
import 'settings_page.dart';

class LandingPage extends StatefulWidget {
  final Function(bool)? onThemeChanged;

  const LandingPage({super.key, this.onThemeChanged});

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
  };

  final Map<String, IconData> _collectionIcons = {
    'Lagu Pujian Masa Ini': Icons.church,
    'Syair Rindu Dendam': Icons.favorite,
    'Lagu Iban': Icons.language,
    'Lagu Pandak': Icons.music_note,
  };

  final Map<String, Color> _collectionColors = {
    'Lagu Pujian Masa Ini': Color(0xFF6366F1),
    'Syair Rindu Dendam': Color(0xFFDC2626),
    'Lagu Iban': Color(0xFF059669),
    'Lagu Pandak': Color(0xFFD97706),
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
      _greeting = 'Good Morning';
    } else if (hour < 17) {
      _greeting = 'Good Afternoon';
    } else {
      _greeting = 'Good Evening';
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
        debugPrint('Error loading ${entry.key}: $e');
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
        debugPrint('Error loading ${entry.key}: $e');
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
      debugPrint('Error loading verse of the day: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Loading songs...',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
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
          // App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                ),
                child: Image.asset(
                  'assets/header_image.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                      ),
                    );
                  },
                ),
              ),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lagu Advent',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                  Text(
                    _currentDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onPrimary.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsPage(
                        onThemeChanged: widget.onThemeChanged,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Greeting
                _buildGreetingCard(),
                const SizedBox(height: 20),

                // Verse of the Day
                if (_verseOfTheDay != null) ...[
                  _buildVerseOfTheDayCard(),
                  const SizedBox(height: 20),
                ],

                // Quick Stats
                _buildStatsCard(),
                const SizedBox(height: 20),

                // Collections
                _buildSectionHeader('Song Collections', Icons.library_music),
                const SizedBox(height: 12),
                _buildCollectionsGrid(),
                const SizedBox(height: 20),

                // Recent Favorites
                if (_recentFavorites.isNotEmpty) ...[
                  _buildSectionHeader('Recent Favorites', Icons.favorite),
                  const SizedBox(height: 12),
                  _buildRecentFavorites(),
                  const SizedBox(height: 20),
                ],

                // Quick Actions
                _buildSectionHeader('Quick Actions', Icons.flash_on),
                const SizedBox(height: 12),
                _buildQuickActions(),

                const SizedBox(height: 40), // Bottom padding
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGreetingCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                _getGreetingIcon(),
                size: 30,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Welcome to your song collection',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerseOfTheDayCard() {
    if (_verseOfTheDay == null) return const SizedBox();

    return Card(
      elevation: 3,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Verse of the Day',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _verseOfTheDay!['lyrics']?.toString() ?? 'No lyrics available',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                      height: 1.6,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _buildVerseAttribution(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                  TextButton(
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
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Read Full Song'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    final totalSongs =
        _collectionCounts.values.fold<int>(0, (sum, count) => sum + count);
    final favoritesCount = _recentFavorites.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            _buildStatItem(
              icon: Icons.library_music,
              label: 'Total Songs',
              value: totalSongs.toString(),
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 20),
            _buildStatItem(
              icon: Icons.collections,
              label: 'Collections',
              value: _collectionCounts.length.toString(),
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(width: 20),
            _buildStatItem(
              icon: Icons.favorite,
              label: 'Favorites',
              value: favoritesCount.toString(),
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildCollectionsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio:
            1.4, // Increased from 1.2 to give more width, less height
      ),
      itemCount: _collectionFiles.length,
      itemBuilder: (context, index) {
        final collection = _collectionFiles.keys.elementAt(index);
        final count = _collectionCounts[collection] ?? 0;
        final icon = _collectionIcons[collection] ?? Icons.music_note;
        final color = _collectionColors[collection] ??
            Theme.of(context).colorScheme.primary;

        return Card(
          elevation: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SongListPage(
                    onThemeChanged: widget.onThemeChanged,
                    initialCollection: collection,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(12.0), // Reduced from 16.0
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min, // Added to prevent overflow
                children: [
                  Container(
                    width: 48, // Reduced from 56
                    height: 48, // Reduced from 56
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24), // Adjusted
                    ),
                    child:
                        Icon(icon, color: color, size: 24), // Reduced from 28
                  ),
                  const SizedBox(height: 8), // Reduced from 12
                  Flexible(
                    // Added Flexible to prevent overflow
                    child: Text(
                      collection,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 12, // Reduced font size
                          ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 2), // Reduced from 4
                  Text(
                    '$count songs',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                          fontSize: 10, // Reduced font size
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

  Widget _buildRecentFavorites() {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _recentFavorites.length,
        itemBuilder: (context, index) {
          final song = _recentFavorites[index];
          return Container(
            width: 200,
            margin: EdgeInsets.only(
                right: index < _recentFavorites.length - 1 ? 12 : 0),
            child: Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
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
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.favorite,
                            color: Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '#${song['song_number']?.toString() ?? '0'}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          song['song_title'],
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        song['collection'],
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SongListPage(
                      onThemeChanged: widget.onThemeChanged,
                      showFavoritesOnly: true,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'View All\nFavorites',
                      style: Theme.of(context).textTheme.titleSmall,
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
          child: Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SongListPage(
                      onThemeChanged: widget.onThemeChanged,
                      openSearch: true,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.primary,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Search\nSongs',
                      style: Theme.of(context).textTheme.titleSmall,
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

  String _buildVerseAttribution() {
    if (_verseOfTheDay == null) return 'Unknown';

    final songTitleRaw = _verseOfTheDay!['song_title'];
    final verseNumberRaw = _verseOfTheDay!['verse_number'];

    final songTitle = songTitleRaw?.toString() ?? 'Unknown';
    final verseNumber = verseNumberRaw?.toString() ?? 'Unknown';

    return '$songTitle - $verseNumber';
  }

  IconData _getGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) return Icons.wb_sunny;
    if (hour < 17) return Icons.wb_sunny_outlined;
    return Icons.nights_stay;
  }
}
