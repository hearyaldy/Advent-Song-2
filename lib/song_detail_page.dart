// song_detail_page.dart - UPDATED (minimal changes, no theme callbacks needed)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'settings_page.dart';
import 'theme_notifier.dart'; // Import for potential future use

class SongDetailPage extends StatefulWidget {
  final Map<String, dynamic> song;
  final String collectionName;
  final VoidCallback? onFavoriteChanged;
  final ThemeNotifier? themeNotifier; // Optional for consistency

  const SongDetailPage({
    super.key,
    required this.song,
    required this.collectionName,
    this.onFavoriteChanged,
    this.themeNotifier, // Optional since this page doesn't change themes
  });

  @override
  SongDetailPageState createState() => SongDetailPageState();
}

class SongDetailPageState extends State<SongDetailPage> {
  double _fontSize = 16.0;
  String _fontFamily = 'Roboto';
  TextAlign _textAlign = TextAlign.left;
  bool _isFavorite = false;
  bool _isLoading = true;

  static const platform = MethodChannel('com.haweeinc.advent_song/share');
  final Logger _logger = Logger();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteSongs = prefs.getStringList('favorites') ?? [];

    setState(() {
      _fontSize = prefs.getDouble('fontSize') ?? 16.0;
      _fontFamily = prefs.getString('fontFamily') ?? 'Roboto';
      _textAlign = TextAlign.values[prefs.getInt('textAlign') ?? 0];
      _isFavorite = favoriteSongs.contains(widget.song['song_number']);
      _isLoading = false;
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

    // Notify parent to refresh favorites list
    widget.onFavoriteChanged?.call();

    // Show feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFavorite ? 'Added to favorites' : 'Removed from favorites',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _shareSong() async {
    try {
      final songText = '''${widget.song['song_title']}
From: ${widget.collectionName}
Song #${widget.song['song_number']}

${widget.song['verses'].map((verse) => "${verse['verse_number']}\n${verse['lyrics']}").join('\n\n')}

Shared from Lagu Advent App''';

      await platform.invokeMethod('share', {
        'title': widget.song['song_title'],
        'lyrics': songText,
      });
    } on PlatformException catch (e) {
      _logger.e('Failed to share: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: ${e.message}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _copyToClipboard() async {
    final songText = '''${widget.song['song_title']}
From: ${widget.collectionName}
Song #${widget.song['song_number']}

${widget.song['verses'].map((verse) => "${verse['verse_number']}\n${verse['lyrics']}").join('\n\n')}''';

    await Clipboard.setData(ClipboardData(text: songText));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Song copied to clipboard'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // App bar with header image
          SliverAppBar(
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
                        colors: [colorScheme.primary, colorScheme.secondary],
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
                          Colors.black.withOpacity(0.7),
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
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${widget.song['song_number']} | ${widget.collectionName}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.song['song_title'],
                          style: const TextStyle(
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                ),
                onPressed: _toggleFavorite,
                tooltip:
                    _isFavorite ? 'Remove from favorites' : 'Add to favorites',
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'share':
                      _shareSong();
                      break;
                    case 'copy':
                      _copyToClipboard();
                      break;
                    case 'settings':
                      // Navigate to settings with theme notifier if available
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => widget.themeNotifier != null
                              ? SettingsPage(
                                  themeNotifier: widget.themeNotifier!,
                                )
                              : SettingsPage(
                                  themeNotifier: ThemeNotifier()..initialize(),
                                ),
                        ),
                      ).then(
                        (_) => _loadSettings(),
                      ); // Reload settings when returning
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'share',
                    child: ListTile(
                      leading: Icon(Icons.share),
                      title: Text('Share'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copy',
                    child: ListTile(
                      leading: Icon(Icons.copy),
                      title: Text('Copy'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: ListTile(
                      leading: Icon(Icons.settings),
                      title: Text('Settings'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Song verses
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: 32.0,
              vertical: 16.0,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final verse = widget.song['verses'][index];
                final isKorus = verse['verse_number'].toLowerCase() == 'korus';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Verse number/title
                      Text(
                        verse['verse_number'],
                        style: TextStyle(
                          fontSize: _fontSize + 6,
                          fontFamily: _fontFamily,
                          fontStyle:
                              isKorus ? FontStyle.italic : FontStyle.normal,
                          fontWeight: FontWeight.bold,
                          color: isKorus
                              ? colorScheme.secondary
                              : colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Verse lyrics
                      SelectableText(
                        verse['lyrics'],
                        style: TextStyle(
                          fontSize: _fontSize,
                          fontFamily: _fontFamily,
                          fontStyle:
                              isKorus ? FontStyle.italic : FontStyle.normal,
                          color: colorScheme.onSurface,
                          height: 1.8,
                          letterSpacing: 0.3,
                        ),
                        textAlign: _textAlign,
                      ),
                    ],
                  ),
                );
              }, childCount: widget.song['verses'].length),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scrollToTop,
        tooltip: 'Scroll to top',
        mini: true,
        child: const Icon(Icons.keyboard_arrow_up),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _toggleFavorite,
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                  ),
                  label: Text(_isFavorite ? 'Favorited' : 'Add to Favorites'),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        _isFavorite ? colorScheme.error : colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(
                onPressed: _shareSong,
                child: const Icon(Icons.share),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: _copyToClipboard,
                child: const Icon(Icons.copy),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
