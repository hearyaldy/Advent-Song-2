// song_list_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'song_detail_page.dart';
import 'settings_popup.dart';
import 'package:flutter/services.dart' show rootBundle;

class SongListPage extends StatefulWidget {
  const SongListPage({super.key});

  @override
  SongListPageState createState() => SongListPageState();
}

class SongListPageState extends State<SongListPage> {
  int _selectedIndex = 0;
  bool _isDarkMode = false;
  List<Map<String, dynamic>> _songs = [];
  List<Map<String, dynamic>> _filteredSongs = [];
  List<Map<String, dynamic>> _favorites = [];
  String _selectedFilter = 'All';

  List<Map<String, dynamic>> _lpmi = [];
  List<Map<String, dynamic>> _srd = [];
  List<Map<String, dynamic>> _iban = [];
  List<Map<String, dynamic>> _pandak = [];

  @override
  void initState() {
    super.initState();
    _loadSongs();
    _loadFavorites();
  }

  Future<void> _loadSongs() async {
    final String lpmiData = await rootBundle.loadString('assets/lpmi.json');
    final String srdData = await rootBundle.loadString('assets/srd.json');
    final String ibanData = await rootBundle.loadString('assets/iban.json');
    final String pandakData = await rootBundle.loadString('assets/pandak.json');

    _lpmi = List<Map<String, dynamic>>.from(json.decode(lpmiData));
    _srd = List<Map<String, dynamic>>.from(json.decode(srdData));
    _iban = List<Map<String, dynamic>>.from(json.decode(ibanData));
    _pandak = List<Map<String, dynamic>>.from(json.decode(pandakData));

    setState(() {
      _songs = _lpmi;
      _filteredSongs = _songs;
    });
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteSongs = prefs.getStringList('favorites') ?? [];
    setState(() {
      _favorites = _songs
          .where((song) => favoriteSongs.contains(song['song_number']))
          .toList();
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
    _loadFavorites();
  }

  void _filterSongs(String query) {
    setState(() {
      _filteredSongs = _songs
          .where((song) =>
              song['song_title'].toLowerCase().contains(query.toLowerCase()) ||
              song['song_number'].contains(query))
          .toList();
    });
  }

  void _onCollectionChanged(String collection) {
    setState(() {
      switch (collection) {
        case 'LPMI':
          _songs = _lpmi;
          break;
        case 'SRD':
          _songs = _srd;
          break;
        case 'IBAN':
          _songs = _iban;
          break;
        case 'PANDAK':
          _songs = _pandak;
          break;
      }
      _filteredSongs = _songs;
      _filterSongs('');
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
      if (filter == 'All') {
        _filteredSongs = _songs;
      } else if (filter == 'Favorites') {
        _filteredSongs = _favorites;
      } else if (filter == 'Alphabet') {
        _filteredSongs = [..._songs]
          ..sort((a, b) => a['song_title'].toLowerCase().compareTo(b['song_title'].toLowerCase()));
      } else if (filter == 'Number') {
        _filteredSongs = [..._songs]..sort((a, b) => a['song_number'].compareTo(b['song_number']));
      }
      _filterSongs('');
    });
  }

  void _onItemTapped(int index) {
    if (index == 1) {
      showDialog(
        context: context,
        builder: (context) => SettingsPopup(
          onSettingsChanged: (fontSize, fontFamily, textAlign) {
            // Settings changes
          },
        ),
      );
    } else {
      setState(() {
        _selectedIndex = index;
        if (index == 2) {
          _toggleTheme();
        }
      });
    }
  }

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? Colors.black : Colors.white,
      body: Column(
        children: [
          Stack(
            children: [
              Image.asset(
                'assets/header_image.png',
                width: double.infinity,
                height: 170,
                fit: BoxFit.cover,
              ),
              const Positioned(
                bottom: 10,
                left: 20,
                child: Text(
                  'Lagu Advent',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: _filterSongs,
              decoration: InputDecoration(
                hintText: 'Search by title or number...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
          Container(
            height: 40, // Smaller height for the menu
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Favorites', 'Alphabet', 'Number']
                    .map((filter) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: _selectedFilter == filter,
                            onSelected: (selected) {
                              _onFilterChanged(filter);
                            },
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _filteredSongs.length,
              separatorBuilder: (context, index) => Divider(
                color: Colors.grey[400], // Divider for modern look
                thickness: 1,
              ),
              itemBuilder: (context, index) {
                final song = _filteredSongs[index];
                return ListTile(
                  title: Text(
                    '${song['song_number']}. ${song['song_title']}',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      _favorites.contains(song) ? Icons.favorite : Icons.favorite_border,
                    ),
                    onPressed: () => _toggleFavorite(song),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SongDetailPage(song: song),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCollectionMenu,
        backgroundColor: Colors.blueAccent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.library_music),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat, // Move FAB to the right
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
          BottomNavigationBarItem(icon: Icon(Icons.toggle_on), label: 'Toggle Theme'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  // Method to show the song collection menu
  void _showCollectionMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: ['LPMI', 'SRD', 'IBAN', 'PANDAK']
            .map((collection) => ListTile(
                  title: Text(collection),
                  onTap: () {
                    Navigator.pop(context);
                    _onCollectionChanged(collection);
                  },
                ))
            .toList(),
      ),
    );
  }
}
