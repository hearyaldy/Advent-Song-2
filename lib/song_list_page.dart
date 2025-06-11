// song_list_page.dart - UPDATED TO USE THEME NOTIFIER
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'song_detail_page.dart';
import 'settings_page.dart';
import 'landing_page.dart';
import 'theme_notifier.dart'; // Import theme notifier
import 'package:flutter/services.dart' show rootBundle;

class SongListPage extends StatefulWidget {
  final ThemeNotifier themeNotifier; // Use theme notifier instead of callbacks
  final String? initialCollection;
  final bool showFavoritesOnly;
  final bool openSearch;

  const SongListPage({
    super.key,
    required this.themeNotifier,
    this.initialCollection,
    this.showFavoritesOnly = false,
    this.openSearch = false,
  });

  @override
  SongListPageState createState() => SongListPageState();
}

class SongListPageState extends State<SongListPage>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _songs = [];
  List<Map<String, dynamic>> _filteredSongs = [];
  List<Map<String, dynamic>> _favorites = [];
  String _selectedFilter = 'All';
  String _selectedCollectionName = 'Lagu Pujian Masa Ini';
  String _searchQuery = '';

  // Collections
  final Map<String, List<Map<String, dynamic>>> _collections = {};
  final List<String> _collectionNames = [
    'Lagu Pujian Masa Ini',
    'Syair Rindu Dendam',
    'Lagu Iban',
    'Lagu Pandak'
  ];
  final Map<String, String> _collectionFiles = {
    'Lagu Pujian Masa Ini': 'lpmi.json',
    'Syair Rindu Dendam': 'srd.json',
    'Lagu Iban': 'iban.json',
    'Lagu Pandak': 'pandak.json',
  };

  String _currentDate = '';
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await _loadCollections();
    await _loadFavorites();
    _getCurrentDate();
    setState(() {
      _isLoading = false;
    });
  }

  void _getCurrentDate() {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE | MMMM d, yyyy').format(now);
    setState(() {
      _currentDate = formattedDate;
    });
  }

  Future<void> _loadCollections() async {
    try {
      // SAFETY CHECK: Re-apply initial collection if it was passed
      if (widget.initialCollection != null &&
          widget.initialCollection!.isNotEmpty) {
        _selectedCollectionName = widget.initialCollection!;
      }

      for (final entry in _collectionFiles.entries) {
        try {
          final String data =
              await rootBundle.loadString('assets/${entry.value}');
          final List<dynamic> jsonData = json.decode(data);
          _collections[entry.key] = List<Map<String, dynamic>>.from(jsonData);
        } catch (fileError) {
          _collections[entry.key] = [];
        }
      }

      // Set songs based on selected collection (after collections are loaded)
      if (_collections.containsKey(_selectedCollectionName)) {
        _songs = _collections[_selectedCollectionName] ?? [];
      } else {
        // Fallback to first available collection if selected one doesn't exist
        if (_collections.isNotEmpty) {
          final fallbackCollection = _collections.keys.first;
          _selectedCollectionName = fallbackCollection;
          _songs = _collections[fallbackCollection] ?? [];
        } else {
          _songs = [];
        }
      }

      _filteredSongs = _songs;
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteSongs = prefs.getStringList('favorites') ?? [];

    // Load favorites from all collections
    List<Map<String, dynamic>> allFavorites = [];
    for (final collection in _collections.values) {
      allFavorites.addAll(collection
          .where((song) => favoriteSongs.contains(song['song_number'])));
    }

    setState(() {
      _favorites = allFavorites;
    });
  }

  Future<void> _toggleFavorite(Map<String, dynamic> song) async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteSongs = prefs.getStringList('favorites') ?? [];

    if (favoriteSongs.contains(song['song_number'])) {
      favoriteSongs.remove(song['song_number']);
    } else {
      favoriteSongs.add(song['song_number']);
    }

    await prefs.setStringList('favorites', favoriteSongs);
    await _loadFavorites();

    // Show feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(favoriteSongs.contains(song['song_number'])
              ? 'Added to favorites'
              : 'Removed from favorites'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _filterSongs(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _applyCurrentFilter();
      } else {
        _filteredSongs = _songs
            .where((song) =>
                song['song_title']
                    .toLowerCase()
                    .contains(query.toLowerCase()) ||
                song['song_number'].toString().contains(query))
            .toList();
      }
    });
  }

  void _onCollectionChanged(String collection) {
    setState(() {
      _selectedCollectionName = collection;
      _songs = _collections[collection] ?? [];
      _searchController.clear();
      _searchQuery = '';
      _selectedFilter = 'All';
      _filteredSongs = _songs;
    });
  }

  void _applyCurrentFilter() {
    setState(() {
      switch (_selectedFilter) {
        case 'All':
          _filteredSongs = _songs;
          break;
        case 'Favorites':
          _filteredSongs = _songs
              .where((song) => _favorites
                  .any((fav) => fav['song_number'] == song['song_number']))
              .toList();
          break;
        case 'Alphabet':
          _filteredSongs = List.from(_songs)
            ..sort((a, b) => a['song_title']
                .toLowerCase()
                .compareTo(b['song_title'].toLowerCase()));
          break;
        case 'Number':
          _filteredSongs = List.from(_songs)
            ..sort((a, b) => a['song_number']
                .toString()
                .compareTo(b['song_number'].toString()));
          break;
      }
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _applyCurrentFilter();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        // Navigate back to dashboard/landing page
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => LandingPage(
              themeNotifier: widget.themeNotifier, // Pass theme notifier
            ),
          ),
          (route) => false, // Remove all previous routes
        );
        break;
      case 1:
        // Navigate to dedicated settings page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SettingsPage(
              themeNotifier: widget.themeNotifier, // Pass theme notifier
            ),
          ),
        );
        break;
      case 2:
        // Additional features (could be about, help, etc.)
        _showAboutDialog();
        break;
    }
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Lagu Advent',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.music_note, size: 48),
      children: [
        const Text('A collection of Advent songs for worship and praise.'),
        const SizedBox(height: 16),
        const Text('Features:'),
        const Text('• Multiple song collections'),
        const Text('• Search and favorites'),
        const Text('• Customizable text display'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          // Header with image
          Stack(
            children: [
              Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colorScheme.primary, colorScheme.secondary],
                  ),
                ),
                child: Image.asset(
                  'assets/header_image.png',
                  width: double.infinity,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [colorScheme.primary, colorScheme.secondary],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                bottom: 10,
                left: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lagu Advent',
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
                      _currentDate,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 3,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Collection name
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Icon(Icons.library_music, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedCollectionName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_songs.length} songs',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search bar with sort options
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                // Search field
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterSongs,
                    decoration: InputDecoration(
                      hintText: 'Search by title or number...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _filterSongs('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Sort button
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Icon(
                      Icons.sort,
                      color: colorScheme.primary,
                    ),
                  ),
                  tooltip: 'Sort options',
                  onSelected: (value) {
                    _onFilterChanged(value);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'All',
                      child: Row(
                        children: [
                          Icon(
                            Icons.list,
                            color: _selectedFilter == 'All'
                                ? colorScheme.primary
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'All Songs',
                            style: TextStyle(
                              fontWeight: _selectedFilter == 'All'
                                  ? FontWeight.bold
                                  : null,
                              color: _selectedFilter == 'All'
                                  ? colorScheme.primary
                                  : null,
                            ),
                          ),
                          if (_selectedFilter == 'All') ...[
                            const Spacer(),
                            Icon(Icons.check, color: colorScheme.primary),
                          ],
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'Favorites',
                      child: Row(
                        children: [
                          Icon(
                            Icons.favorite,
                            color: _selectedFilter == 'Favorites'
                                ? colorScheme.primary
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Favorites',
                            style: TextStyle(
                              fontWeight: _selectedFilter == 'Favorites'
                                  ? FontWeight.bold
                                  : null,
                              color: _selectedFilter == 'Favorites'
                                  ? colorScheme.primary
                                  : null,
                            ),
                          ),
                          if (_selectedFilter == 'Favorites') ...[
                            const Spacer(),
                            Icon(Icons.check, color: colorScheme.primary),
                          ],
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'Alphabet',
                      child: Row(
                        children: [
                          Icon(
                            Icons.sort_by_alpha,
                            color: _selectedFilter == 'Alphabet'
                                ? colorScheme.primary
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Sort A-Z',
                            style: TextStyle(
                              fontWeight: _selectedFilter == 'Alphabet'
                                  ? FontWeight.bold
                                  : null,
                              color: _selectedFilter == 'Alphabet'
                                  ? colorScheme.primary
                                  : null,
                            ),
                          ),
                          if (_selectedFilter == 'Alphabet') ...[
                            const Spacer(),
                            Icon(Icons.check, color: colorScheme.primary),
                          ],
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'Number',
                      child: Row(
                        children: [
                          Icon(
                            Icons.format_list_numbered,
                            color: _selectedFilter == 'Number'
                                ? colorScheme.primary
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Sort by Number',
                            style: TextStyle(
                              fontWeight: _selectedFilter == 'Number'
                                  ? FontWeight.bold
                                  : null,
                              color: _selectedFilter == 'Number'
                                  ? colorScheme.primary
                                  : null,
                            ),
                          ),
                          if (_selectedFilter == 'Number') ...[
                            const Spacer(),
                            Icon(Icons.check, color: colorScheme.primary),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Song list
          Expanded(
            child: _filteredSongs.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: _filteredSongs.length,
                    itemBuilder: (context, index) {
                      final song = _filteredSongs[index];
                      final isFavorite = _favorites.any(
                          (fav) => fav['song_number'] == song['song_number']);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colorScheme.primary,
                            child: Text(
                              song['song_number'].toString(),
                              style: TextStyle(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            song['song_title'],
                            style: theme.textTheme.titleMedium,
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isFavorite ? Colors.red : null,
                            ),
                            onPressed: () => _toggleFavorite(song),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SongDetailPage(
                                  song: song,
                                  collectionName: _selectedCollectionName,
                                  onFavoriteChanged: () {
                                    _loadFavorites(); // Refresh favorites when changed
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCollectionMenu,
        tooltip: 'Switch Collection',
        icon: const Icon(Icons.library_music),
        label: Text(_getShortCollectionName()),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info_outline),
            label: 'About',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _selectedFilter == 'Favorites'
                ? Icons.favorite_border
                : Icons.search_off,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == 'Favorites'
                ? 'No favorite songs yet'
                : _searchQuery.isNotEmpty
                    ? 'No songs found for "$_searchQuery"'
                    : 'No songs available',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
          ),
          if (_selectedFilter == 'Favorites') ...[
            const SizedBox(height: 8),
            Text(
              'Tap the heart icon on songs to add them to favorites',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  String _getShortCollectionName() {
    switch (_selectedCollectionName) {
      case 'Lagu Pujian Masa Ini':
        return 'LPMI';
      case 'Syair Rindu Dendam':
        return 'SRD';
      case 'Lagu Iban':
        return 'Iban';
      case 'Lagu Pandak':
        return 'Pandak';
      default:
        return 'Songs';
    }
  }

  void _showCollectionMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Icon(
                    Icons.library_music,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Select Collection',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Choose from available song collections',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
              ),
              const SizedBox(height: 16),

              // Collection options in scrollable list
              Flexible(
                child: ListView.builder(
                  controller: scrollController,
                  shrinkWrap: true,
                  itemCount: _collectionNames.length,
                  itemBuilder: (context, index) {
                    final collection = _collectionNames[index];
                    final isSelected = collection == _selectedCollectionName;
                    final songCount = _collections[collection]?.length ?? 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1)
                            : null,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.3))
                            : null,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.music_note,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                        ),
                        title: Text(
                          collection,
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                        ),
                        subtitle: Text(
                          '$songCount songs',
                          style: TextStyle(
                            color: isSelected
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.7)
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.6),
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.pop(context);
                          if (!isSelected) {
                            _onCollectionChanged(collection);
                          }
                        },
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
