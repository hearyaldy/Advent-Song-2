// song_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import MethodChannel
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart'; // Import the logger package
import 'settings_popup.dart';

class SongDetailPage extends StatefulWidget {
  final Map<String, dynamic> song;

  const SongDetailPage({super.key, required this.song});

  @override
  SongDetailPageState createState() => SongDetailPageState();
}

class SongDetailPageState extends State<SongDetailPage> {
  double _fontSize = 16.0;
  String _fontFamily = 'Roboto';
  TextAlign _textAlign = TextAlign.left;
  bool _isFavorite = false;
  bool _isDarkMode = false;

  // Define a MethodChannel
  static const platform = MethodChannel('com.haweeinc.advent_song/share');

  // Create a logger instance
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
  }

  Future<void> _checkFavoriteStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteSongs = prefs.getStringList('favorites') ?? [];
    setState(() {
      _isFavorite = favoriteSongs.contains(widget.song['song_number']);
    });
  }

  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteSongs = prefs.getStringList('favorites') ?? [];

    if (_isFavorite) {
      favoriteSongs.remove(widget.song['song_number']);
    } else {
      favoriteSongs.add(widget.song['song_number']);
    }

    await prefs.setStringList('favorites', favoriteSongs);
    setState(() {
      _isFavorite = !_isFavorite;
    });
  }

  // Method to invoke native share functionality
  Future<void> _shareSong() async {
    try {
      await platform.invokeMethod('share', {
        'title': widget.song['song_title'],
        'lyrics': widget.song['verses']
            .map((verse) => "${verse['verse_number']}: ${verse['lyrics']}")
            .join('\n\n'),
      });
    } on PlatformException catch (e) {
      _logger.e('Failed to share: ${e.message}');
    }
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.pop(context); // Navigate back to the home page
        break;
      case 1:
        showDialog(
          context: context,
          builder: (context) => SettingsPopup(
            onSettingsChanged: (fontSize, fontFamily, textAlign) {
              setState(() {
                _fontSize = fontSize;
                _fontFamily = fontFamily;
                _textAlign = textAlign;
              });
            },
          ),
        );
        break;
      case 2:
        setState(() {
          _isDarkMode = !_isDarkMode;
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? Colors.black : Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              Image.asset(
                'assets/header_image.png',
                width: double.infinity,
                height: 170,
                fit: BoxFit.cover,
              ),
              Positioned(
                bottom: 10,
                left: 20,
                child: Text(
                  widget.song['song_title'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          // Align the share and favorite button to the right
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                ),
                onPressed: _toggleFavorite,
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: _shareSong,
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ListView.builder(
                itemCount: widget.song['verses'].length,
                itemBuilder: (context, index) {
                  final verse = widget.song['verses'][index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      "${verse['verse_number']}. ${verse['lyrics']}",
                      style: TextStyle(
                        fontSize: _fontSize,
                        fontFamily: _fontFamily,
                        color: _isDarkMode ? Colors.white : Colors.black,
                      ),
                      textAlign: _textAlign,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
          BottomNavigationBarItem(icon: Icon(Icons.toggle_on), label: 'Toggle Theme'),
        ],
        onTap: (index) => _onItemTapped(context, index),
      ),
    );
  }
}
