// song_list_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import for formatting the date
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

  String _currentDate = '';

  @override
  void initState() {
    super.initState();
    _loadSongs();
    _loadFavorites();
    _getCurrentDate();
  }

  void _getCurrentDate() {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE | MMMM d, yyyy').format(now);
    setState(() {
      _currentDate = formattedDate;
    });
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
        case 'Lagu Pujian Masa Ini':
          _songs = _lpmi;
          break;
        case 'Syair Rindu Dendam':
          _songs = _srd;
          break;
        case 'Lagu Iban':
          _songs = _iban;
          break;
        case 'Lagu Pandak':
          _songs = _pandak;
          break;
      }
      _filteredSongs = _songs;
      _filterSongs('');
    });
  }

  void _onSortChanged(String sort) {
    setState(() {
      if (sort == 'Alphabet') {
        _filteredSongs.sort(
            (a, b) => a['song_title'].toLowerCase().compareTo(b['song_title'].toLowerCase()));
      } else if (sort == 'Number') {
        _filteredSongs.sort((a, b) => a['song_number'].compareTo(b['song_number']));
      }
    });
  }

  void _onItemTapped(int index) {
    if (index == 1) {
      showDialog(
        context: context,
        builder: (context) => SettingsPopup(
          onSettingsChanged: (fontSize, fontFamily, textAlign) {
            // Handle settings changes
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
                height: 120, // Adjusted header image size to 120px
                fit: BoxFit.cover,
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
                      ),
                    ),
                    Text(
                      _currentDate,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: _filterSongs,
              decoration: InputDecoration(
                hintText: 'Carian lagu melalui Tajuk atau Perkataan...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['All', 'Favorites', 'Alphabet', 'Number']
                  .map((filter) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: _selectedFilter == filter,
                          onSelected: (selected) {
                            setState(() {
                              _selectedFilter = filter;
                              if (filter == 'All') {
                                _filteredSongs = _songs;
                              } else if (filter == 'Favorites') {
                                _filteredSongs = _favorites;
                              } else {
                                _onSortChanged(filter);
                              }
                            });
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredSongs.length,
              itemBuilder: (context, index) {
                final song = _filteredSongs[index];
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
                  decoration: BoxDecoration(
                    color: _isDarkMode ? Colors.grey[900] : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ListTile(
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
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        onPressed: _showCollectionMenu,
        child: const Icon(Icons.library_music),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
        children: ['Lagu Pujian Masa Ini', 'Syair Rindu Dendam', 'Lagu Iban', 'Lagu Pandak']
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
