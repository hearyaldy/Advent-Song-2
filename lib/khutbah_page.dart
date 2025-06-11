// khutbah_page.dart - UPDATED FOR GOOGLE DRIVE
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'theme_notifier.dart';
import 'google_drive_devotional_service.dart'; // UPDATED: Use Google Drive service

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
  Map<String, dynamic>? _currentDevotional;
  List<String> _bookmarkedDevotionals = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _error = '';
  String _connectionStatus = 'Checking...'; // NEW: Show connection status

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
    _loadDevotional();
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
        _connectionStatus = 'Connecting to Google Drive...';
      } else {
        _isLoading = true;
        _connectionStatus = 'Loading...';
      }
      _error = '';
    });

    try {
      // UPDATED: Use Google Drive service
      final devotional =
          await GoogleDriveDevotionalService.getTodaysDevotional();

      setState(() {
        _currentDevotional = devotional;
        _error = '';

        // Set connection status based on source
        final source = devotional['source'] ?? 'Unknown';
        if (source.contains('Google')) {
          _connectionStatus = 'Connected to $source';
        } else if (source.contains('Built-in') || source.contains('Offline')) {
          _connectionStatus = 'Offline content';
        } else {
          _connectionStatus = 'Content loaded';
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load devotional: ${e.toString()}';
        _connectionStatus = 'Connection failed';
      });
    } finally {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _shareDevotional() async {
    if (_currentDevotional == null) return;

    final text = '''${_currentDevotional!['title']}

${_currentDevotional!['content']}

${_currentDevotional!['verse']}
- ${_currentDevotional!['reference']}

Source: ${_currentDevotional!['source']}
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
        final isDarkMode = theme.brightness == Brightness.dark;

        if (_isLoading) {
          return Scaffold(
            backgroundColor: colorScheme.surface,
            appBar: AppBar(
              title: Text('Khutbah'),
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('Loading today\'s devotional...'),
                  const SizedBox(height: 8),
                  Text(
                    _connectionStatus,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
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
              // App Bar with connection status
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
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
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.3),
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
                            Row(
                              children: [
                                Icon(
                                  _getSourceIcon(),
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Khutbah',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Daily Devotional',
                              style: TextStyle(
                                fontSize: 24,
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
                              DateFormat('EEEE, MMMM d, yyyy')
                                  .format(DateTime.now()),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            // NEW: Connection status indicator
                            SizedBox(height: 4),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColor().withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      _getStatusColor().withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                _connectionStatus,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
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
                        _bookmarkedDevotionals
                                .contains(_currentDevotional!['id'])
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        color: Colors.white,
                      ),
                      onPressed: () =>
                          _toggleBookmark(_currentDevotional!['id']),
                    ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (value) {
                      switch (value) {
                        case 'refresh':
                          _loadDevotional(forceRefresh: true);
                          break;
                        case 'share':
                          _shareDevotional();
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
                      PopupMenuItem(
                        value: 'refresh',
                        child: ListTile(
                          leading: Icon(Icons.refresh),
                          title: Text('Refresh from Google Drive'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'share',
                        child: ListTile(
                          leading: Icon(Icons.share),
                          title: Text('Share'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'bookmarks',
                        child: ListTile(
                          leading: Icon(Icons.bookmarks),
                          title: Text('Bookmarks'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
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
              ),

              // Content
              SliverPadding(
                padding: const EdgeInsets.all(20.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (_error.isNotEmpty)
                      _buildErrorState()
                    else if (_currentDevotional != null)
                      _buildDevotionalContent()
                    else
                      _buildEmptyState(),
                  ]),
                ),
              ),
            ],
          ),
          floatingActionButton: _isRefreshing
              ? null
              : FloatingActionButton(
                  onPressed: () => _loadDevotional(forceRefresh: true),
                  tooltip: 'Refresh from Google Drive',
                  child: Icon(Icons.cloud_sync),
                ),
        );
      },
    );
  }

  // NEW: Get icon based on content source
  IconData _getSourceIcon() {
    final source = _currentDevotional?['source'] ?? '';
    if (source.contains('Google')) {
      return Icons.cloud;
    } else if (source.contains('Offline')) {
      return Icons.cloud_off;
    }
    return Icons.record_voice_over;
  }

  // NEW: Get status color
  Color _getStatusColor() {
    if (_connectionStatus.contains('Connected')) {
      return Colors.green;
    } else if (_connectionStatus.contains('Offline')) {
      return Colors.orange;
    } else if (_connectionStatus.contains('failed')) {
      return Colors.red;
    }
    return Colors.blue;
  }

  // NEW: Show source information
  void _showSourceInfo() {
    if (_currentDevotional == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Content Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Source: ${_currentDevotional!['source']}'),
            SizedBox(height: 8),
            Text('Author: ${_currentDevotional!['author']}'),
            SizedBox(height: 8),
            Text('Date: ${_currentDevotional!['date']}'),
            SizedBox(height: 8),
            Text('Status: $_connectionStatus'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off,
            size: 64,
            color: colorScheme.error,
          ),
          SizedBox(height: 16),
          Text(
            'Unable to load from Google Drive',
            style: theme.textTheme.titleLarge,
          ),
          SizedBox(height: 8),
          Text(
            _error,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.error,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _loadDevotional(forceRefresh: true),
            icon: Icon(Icons.cloud_sync),
            label: Text('Retry Google Drive'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_queue,
            size: 64,
            color: colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          SizedBox(height: 16),
          Text(
            'No devotional content available',
            style: theme.textTheme.titleLarge,
          ),
          SizedBox(height: 8),
          Text(
            'Check your Google Drive setup',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevotionalContent() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final devotional = _currentDevotional!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Card with source indicator
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary.withValues(alpha: 0.1),
                colorScheme.secondary.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      devotional['title'],
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getStatusColor().withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getSourceIcon(),
                          size: 12,
                          color: _getStatusColor(),
                        ),
                        SizedBox(width: 4),
                        Text(
                          devotional['source'] ?? 'Unknown',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _getStatusColor(),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (devotional['author'] != null &&
                  devotional['author'] != 'Unknown') ...[
                SizedBox(height: 8),
                Text(
                  'by ${devotional['author']}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),

        SizedBox(height: 24),

        // Scripture Verse
        if (devotional['verse'] != null &&
            devotional['verse'].toString().isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.secondary.withValues(alpha: 0.1),
                  colorScheme.secondary.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.secondary.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.format_quote,
                  color: colorScheme.secondary,
                  size: 32,
                ),
                SizedBox(height: 12),
                Text(
                  devotional['verse'],
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontStyle: FontStyle.italic,
                    height: 1.6,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (devotional['reference'] != null &&
                    devotional['reference'].toString().isNotEmpty) ...[
                  SizedBox(height: 12),
                  Text(
                    '- ${devotional['reference']}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.secondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 24),
        ],

        // Main Content
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: SelectableText(
            devotional['content'],
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.8,
              color: colorScheme.onSurface,
            ),
          ),
        ),

        SizedBox(height: 32),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _toggleBookmark(devotional['id']),
                icon: Icon(
                  _bookmarkedDevotionals.contains(devotional['id'])
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                ),
                label: Text(
                  _bookmarkedDevotionals.contains(devotional['id'])
                      ? 'Bookmarked'
                      : 'Bookmark',
                ),
              ),
            ),
            SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: _shareDevotional,
              child: Icon(Icons.share),
            ),
          ],
        ),
      ],
    );
  }

  void _showBookmarks() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bookmarked Devotionals',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 16),
            if (_bookmarkedDevotionals.isEmpty)
              Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No bookmarks yet. Tap the bookmark icon to save devotionals.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                ),
              )
            else
              ...(_bookmarkedDevotionals.map((id) => ListTile(
                    leading: Icon(Icons.bookmark,
                        color: Theme.of(context).colorScheme.primary),
                    title: Text('Devotional ${id.split('_').last}'),
                    subtitle: Text('Tap to remove from bookmarks'),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () {
                        _toggleBookmark(id);
                        Navigator.pop(context);
                      },
                    ),
                  ))),
          ],
        ),
      ),
    );
  }
}
