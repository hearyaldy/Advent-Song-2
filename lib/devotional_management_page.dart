// devotional_management_page.dart - Complete Working Version with Google Sheets Integration
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'theme_notifier.dart';
import 'google_drive_devotional_service.dart';

// DevotionalContent model class
class DevotionalContent {
  final String id;
  final String title;
  final String content;
  final String verse;
  final String reference;
  final String author;
  final String date;
  final String source;

  DevotionalContent({
    required this.id,
    required this.title,
    required this.content,
    required this.verse,
    required this.reference,
    required this.author,
    required this.date,
    required this.source,
  });

  factory DevotionalContent.fromMap(Map<String, dynamic> map) {
    return DevotionalContent(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      verse: map['verse']?.toString() ?? '',
      reference: map['reference']?.toString() ?? '',
      author: map['author']?.toString() ?? '',
      date: map['date']?.toString() ?? '',
      source: map['source']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'verse': verse,
      'reference': reference,
      'author': author,
      'date': date,
      'source': source,
    };
  }
}

class DevotionalManagementPage extends StatefulWidget {
  final ThemeNotifier themeNotifier;

  const DevotionalManagementPage({
    super.key,
    required this.themeNotifier,
  });

  @override
  State<DevotionalManagementPage> createState() => _DevotionalManagementPageState();
}

class _DevotionalManagementPageState extends State<DevotionalManagementPage> {
  List<DevotionalContent> _devotionals = [];
  bool _isLoading = false;
  String _error = '';
  
  // Form controllers
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _verseController = TextEditingController();
  final _referenceController = TextEditingController();
  final _authorController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  DevotionalContent? _editingDevotional;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadDevotionals();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _verseController.dispose();
    _referenceController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  Future<void> _loadDevotionals() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // Load devotionals from Google Sheets
      final devotionalsList = await _loadDevotionalsFromGoogleSheets();
      
      setState(() {
        _devotionals = devotionalsList;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load devotionals: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<DevotionalContent>> _loadDevotionalsFromGoogleSheets() async {
    try {
      print('📡 Loading devotionals from Google Sheets...');
      const String csvUrl = 'https://docs.google.com/spreadsheets/d/1E6GVXX3dHpGsohUg5e7qC9jZwRhMvNdmelHQMQ8SWZ8/export?format=csv&gid=0';

      final response = await http.get(
        Uri.parse(csvUrl),
        headers: {
          'User-Agent': 'LaguAdvent/1.0',
          'Accept-Charset': 'utf-8',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        String csvContent;
        try {
          csvContent = utf8.decode(response.bodyBytes, allowMalformed: true);
        } catch (e) {
          csvContent = latin1.decode(response.bodyBytes);
        }

        return _parseDevotionalsCSV(csvContent);
      } else {
        throw Exception('HTTP ${response.statusCode}: Failed to load data');
      }
    } catch (e) {
      print('❌ Error loading from Google Sheets: $e');
      // Return today's devotional as fallback
      final todaysDevotional = await GoogleDriveDevotionalService.getTodaysDevotional();
      return [DevotionalContent.fromMap(todaysDevotional)];
    }
  }

  List<DevotionalContent> _parseDevotionalsCSV(String csvContent) {
    final lines = csvContent.split('\n').where((line) => line.trim().isNotEmpty).toList();
    
    if (lines.length < 2) {
      throw Exception('Invalid CSV format');
    }

    final devotionals = <DevotionalContent>[];
    final dataLines = lines.skip(1).toList(); // Skip header

    for (int i = 0; i < dataLines.length; i++) {
      try {
        final line = dataLines[i];
        final values = _parseCSVLine(line);

        if (values.length >= 4) { // Minimum required columns
          final devotional = DevotionalContent(
            id: 'sheets_${i}_${DateTime.now().millisecondsSinceEpoch}',
            title: values.length > 2 ? _cleanText(values[2]) : 'Untitled',
            content: values.length > 3 ? _cleanText(values[3]) : '',
            verse: values.length > 4 ? _cleanText(values[4]) : '',
            reference: values.length > 5 ? _cleanText(values[5]) : '',
            author: values.length > 6 ? _cleanText(values[6]) : 'Unknown',
            date: values.length > 1 ? _parseDateFromCSV(values[1]) : DateFormat('yyyy-MM-dd').format(DateTime.now()),
            source: 'Google Sheets',
          );
          
          devotionals.add(devotional);
        }
      } catch (e) {
        print('⚠️ Error parsing line ${i + 1}: $e');
        continue;
      }
    }

    // Sort by date descending (newest first)
    devotionals.sort((a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)));
    
    return devotionals;
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

  String _cleanText(String text) {
    if (text.isEmpty) return text;

    return text
        .replaceAll('â€™', "'")
        .replaceAll('â€œ', '"')
        .replaceAll('â€', '"')
        .replaceAll('â€"', '—')
        .replaceAll('â€"', '–')
        .replaceAll('â€¦', '...')
        .replaceAll('"', '"')
        .replaceAll('"', '"')
        .replaceAll(''', "'")
        .replaceAll(''', "'")
        .replaceAll(RegExp(r'^"'), '')
        .replaceAll(RegExp(r'"

  Future<void> _submitDevotional() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final devotional = DevotionalContent(
        id: _editingDevotional?.id ?? 'new_${DateTime.now().millisecondsSinceEpoch}',
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        verse: _verseController.text.trim(),
        reference: _referenceController.text.trim(),
        author: _authorController.text.trim(),
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        source: 'Manual Entry',
      );

      // For demo purposes, just add to local list
      // In real implementation, this would submit to Google Sheets
      setState(() {
        if (_editingDevotional != null) {
          final index = _devotionals.indexWhere((d) => d.id == _editingDevotional!.id);
          if (index != -1) {
            _devotionals[index] = devotional;
          }
        } else {
          _devotionals.insert(0, devotional);
        }
      });

      _clearForm();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editingDevotional != null ? 'Devotional updated!' : 'Devotional created!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to submit devotional: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearForm() {
    _titleController.clear();
    _contentController.clear();
    _verseController.clear();
    _referenceController.clear();
    _authorController.clear();
    _editingDevotional = null;
    _selectedDate = DateTime.now();
  }

  void _editDevotional(DevotionalContent devotional) {
    setState(() {
      _editingDevotional = devotional;
      _titleController.text = devotional.title;
      _contentController.text = devotional.content;
      _verseController.text = devotional.verse;
      _referenceController.text = devotional.reference;
      _authorController.text = devotional.author;
      _selectedDate = DateTime.parse(devotional.date);
    });
  }

  Future<void> _deleteDevotional(DevotionalContent devotional) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Devotional'),
        content: Text('Are you sure you want to delete "${devotional.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _devotionals.removeWhere((d) => d.id == devotional.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Devotional deleted'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
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
          appBar: AppBar(
            title: const Text('Devotional Management'),
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadDevotionals,
                tooltip: 'Refresh',
              ),
              IconButton(
                icon: const Icon(Icons.clear_all),
                onPressed: _clearForm,
                tooltip: 'Clear Form',
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Form Section
                      _buildFormSection(theme, colorScheme),
                      
                      const SizedBox(height: 32),
                      
                      // Devotionals List Section
                      _buildDevotionalsList(theme, colorScheme),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildFormSection(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _editingDevotional != null ? Icons.edit : Icons.add,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _editingDevotional != null ? 'Edit Devotional' : 'Create New Devotional',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Date Selection
              InkWell(
                onTap: _selectDate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Date: ${DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate)}',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_drop_down, color: colorScheme.onSurface),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Field
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Content Field
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.article),
                  helperText: 'Main devotional content',
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter content';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Verse Field
              TextFormField(
                controller: _verseController,
                decoration: const InputDecoration(
                  labelText: 'Bible Verse',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.format_quote),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Reference Field
              TextFormField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'Scripture Reference',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.bookmark),
                  hintText: 'e.g., John 3:16',
                ),
              ),
              const SizedBox(height: 16),

              // Author Field
              TextFormField(
                controller: _authorController,
                decoration: const InputDecoration(
                  labelText: 'Author',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _submitDevotional,
                  icon: Icon(_editingDevotional != null ? Icons.save : Icons.add),
                  label: Text(_editingDevotional != null ? 'Update Devotional' : 'Create Devotional'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              
              if (_editingDevotional != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _clearForm,
                    icon: const Icon(Icons.clear),
                    label: const Text('Cancel Edit'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDevotionalsList(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Existing Devotionals',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
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
                    '${_devotionals.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_devotionals.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 48,
                      color: colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No devotionals found',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your first devotional using the form above',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _devotionals.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final devotional = _devotionals[index];
                  return _buildDevotionalItem(devotional, theme, colorScheme);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevotionalItem(DevotionalContent devotional, ThemeData theme, ColorScheme colorScheme) {
    return ExpansionTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
        ),
        child: Icon(
          Icons.article,
          color: colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        devotional.title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        DateFormat('EEEE, MMMM d, yyyy').format(DateTime.parse(devotional.date)),
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface.withOpacity(0.7),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editDevotional(devotional),
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteDevotional(devotional),
            tooltip: 'Delete',
          ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (devotional.content.isNotEmpty) ...[
                Text(
                  'Content:',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(devotional.content),
                const SizedBox(height: 12),
              ],
              
              if (devotional.verse.isNotEmpty) ...[
                Text(
                  'Verse:',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '"${devotional.verse}"',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (devotional.reference.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '— ${devotional.reference}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
              
              Row(
                children: [
                  if (devotional.author.isNotEmpty) ...[
                    Text(
                      'Author: ${devotional.author}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Text(
                    'Source: ${devotional.source}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _parseDateFromCSV(String dateStr) {
    try {
      // Try parsing DD/MM/YYYY format first
      if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          final date = DateTime(year, month, day);
          return DateFormat('yyyy-MM-dd').format(date);
        }
      }
      
      // Try parsing as is
      final parsed = DateTime.parse(dateStr);
      return DateFormat('yyyy-MM-dd').format(parsed);
    } catch (e) {
      // Return today's date as fallback
      return DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
  }

  Future<void> _submitDevotional() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final devotional = DevotionalContent(
        id: _editingDevotional?.id ?? 'new_${DateTime.now().millisecondsSinceEpoch}',
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        verse: _verseController.text.trim(),
        reference: _referenceController.text.trim(),
        author: _authorController.text.trim(),
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        source: 'Manual Entry',
      );

      // For demo purposes, just add to local list
      // In real implementation, this would submit to Google Sheets
      setState(() {
        if (_editingDevotional != null) {
          final index = _devotionals.indexWhere((d) => d.id == _editingDevotional!.id);
          if (index != -1) {
            _devotionals[index] = devotional;
          }
        } else {
          _devotionals.insert(0, devotional);
        }
      });

      _clearForm();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editingDevotional != null ? 'Devotional updated!' : 'Devotional created!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to submit devotional: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearForm() {
    _titleController.clear();
    _contentController.clear();
    _verseController.clear();
    _referenceController.clear();
    _authorController.clear();
    _editingDevotional = null;
    _selectedDate = DateTime.now();
  }

  void _editDevotional(DevotionalContent devotional) {
    setState(() {
      _editingDevotional = devotional;
      _titleController.text = devotional.title;
      _contentController.text = devotional.content;
      _verseController.text = devotional.verse;
      _referenceController.text = devotional.reference;
      _authorController.text = devotional.author;
      _selectedDate = DateTime.parse(devotional.date);
    });
  }

  Future<void> _deleteDevotional(DevotionalContent devotional) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Devotional'),
        content: Text('Are you sure you want to delete "${devotional.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _devotionals.removeWhere((d) => d.id == devotional.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Devotional deleted'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
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
          appBar: AppBar(
            title: const Text('Devotional Management'),
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadDevotionals,
                tooltip: 'Refresh',
              ),
              IconButton(
                icon: const Icon(Icons.clear_all),
                onPressed: _clearForm,
                tooltip: 'Clear Form',
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Form Section
                      _buildFormSection(theme, colorScheme),
                      
                      const SizedBox(height: 32),
                      
                      // Devotionals List Section
                      _buildDevotionalsList(theme, colorScheme),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildFormSection(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _editingDevotional != null ? Icons.edit : Icons.add,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _editingDevotional != null ? 'Edit Devotional' : 'Create New Devotional',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Date Selection
              InkWell(
                onTap: _selectDate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Date: ${DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate)}',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_drop_down, color: colorScheme.onSurface),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Field
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Content Field
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.article),
                  helperText: 'Main devotional content',
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter content';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Verse Field
              TextFormField(
                controller: _verseController,
                decoration: const InputDecoration(
                  labelText: 'Bible Verse',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.format_quote),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Reference Field
              TextFormField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'Scripture Reference',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.bookmark),
                  hintText: 'e.g., John 3:16',
                ),
              ),
              const SizedBox(height: 16),

              // Author Field
              TextFormField(
                controller: _authorController,
                decoration: const InputDecoration(
                  labelText: 'Author',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _submitDevotional,
                  icon: Icon(_editingDevotional != null ? Icons.save : Icons.add),
                  label: Text(_editingDevotional != null ? 'Update Devotional' : 'Create Devotional'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              
              if (_editingDevotional != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _clearForm,
                    icon: const Icon(Icons.clear),
                    label: const Text('Cancel Edit'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDevotionalsList(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Existing Devotionals',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
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
                    '${_devotionals.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_devotionals.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 48,
                      color: colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No devotionals found',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your first devotional using the form above',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _devotionals.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final devotional = _devotionals[index];
                  return _buildDevotionalItem(devotional, theme, colorScheme);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevotionalItem(DevotionalContent devotional, ThemeData theme, ColorScheme colorScheme) {
    return ExpansionTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
        ),
        child: Icon(
          Icons.article,
          color: colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        devotional.title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        DateFormat('EEEE, MMMM d, yyyy').format(DateTime.parse(devotional.date)),
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface.withOpacity(0.7),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editDevotional(devotional),
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteDevotional(devotional),
            tooltip: 'Delete',
          ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (devotional.content.isNotEmpty) ...[
                Text(
                  'Content:',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(devotional.content),
                const SizedBox(height: 12),
              ],
              
              if (devotional.verse.isNotEmpty) ...[
                Text(
                  'Verse:',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '"${devotional.verse}"',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (devotional.reference.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '— ${devotional.reference}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
              
              Row(
                children: [
                  if (devotional.author.isNotEmpty) ...[
                    Text(
                      'Author: ${devotional.author}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Text(
                    'Source: ${devotional.source}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}