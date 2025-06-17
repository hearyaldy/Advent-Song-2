// devotional_management_page.dart - COMPLETE UPDATED VERSION WITH ALL FIXES
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'theme_notifier.dart';
import 'devotional_service.dart'; // Use the unified service

class DevotionalManagementPage extends StatefulWidget {
  final ThemeNotifier themeNotifier;

  const DevotionalManagementPage({
    super.key,
    required this.themeNotifier,
  });

  @override
  State<DevotionalManagementPage> createState() =>
      _DevotionalManagementPageState();
}

class _DevotionalManagementPageState extends State<DevotionalManagementPage> {
  List<Map<String, dynamic>> _devotionals = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String _error = '';
  bool _isConnected = false;

  // Form controllers
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _verseController = TextEditingController();
  final _referenceController = TextEditingController();
  final _authorController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Map<String, dynamic>? _editingDevotional;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initializePage();
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

  Future<void> _initializePage() async {
    await _testConnection();
    await _loadDevotionals();
  }

  Future<void> _testConnection() async {
    try {
      final isConnected = await DevotionalService.testConnection();
      setState(() {
        _isConnected = isConnected;
      });
    } catch (e) {
      setState(() {
        _isConnected = false;
      });
    }
  }

  Future<void> _loadDevotionals() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      print('📡 Loading all devotionals from Google Sheets...');
      final devotionalsList = await DevotionalService.getAllDevotionals();

      setState(() {
        _devotionals = devotionalsList;
      });

      print('✅ Loaded ${devotionalsList.length} devotionals');
    } catch (e) {
      print('❌ Error loading devotionals: $e');
      setState(() {
        _error = 'Failed to load devotionals: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitDevotional() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = '';
    });

    try {
      final dateFormatted = DateFormat('dd/MM/yyyy').format(_selectedDate);

      bool success;
      if (_editingDevotional != null) {
        // Update existing devotional - FIXED: Use bracket notation
        final originalDateFormatted = DateFormat('dd/MM/yyyy')
            .format(DateTime.parse(_editingDevotional!['date']));

        print('📝 Updating devotional: ${_titleController.text}');
        success = await DevotionalService.updateDevotional(
          originalDate: originalDateFormatted,
          date: dateFormatted,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          verse: _verseController.text.trim(),
          reference: _referenceController.text.trim(),
          author: _authorController.text.trim(),
          updatedBy: 'Devotional Management',
        );
      } else {
        // Add new devotional
        print('📝 Adding new devotional: ${_titleController.text}');
        success = await DevotionalService.addDevotional(
          date: dateFormatted,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          verse: _verseController.text.trim(),
          reference: _referenceController.text.trim(),
          author: _authorController.text.trim(),
          addedBy: 'Devotional Management',
        );
      }

      if (success) {
        _clearForm();
        await _loadDevotionals(); // Reload the list

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_editingDevotional != null
                  ? '✅ Devotional updated successfully!'
                  : '✅ Devotional created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _error = _editingDevotional != null
              ? 'Failed to update devotional'
              : 'Failed to create devotional';
        });
      }
    } catch (e) {
      print('❌ Error submitting devotional: $e');
      setState(() {
        _error = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isSaving = false;
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

  void _editDevotional(Map<String, dynamic> devotional) {
    setState(() {
      _editingDevotional = devotional;
      // FIXED: Use bracket notation for all Map access
      _titleController.text = devotional['title'] ?? '';
      _contentController.text = devotional['content'] ?? '';
      _verseController.text = devotional['verse'] ?? '';
      _referenceController.text = devotional['reference'] ?? '';
      _authorController.text = devotional['author'] ?? '';
      _selectedDate = DateTime.parse(devotional['date']);
    });

    // Scroll to top to show the form
    if (_formKey.currentContext != null) {
      Scrollable.ensureVisible(
        _formKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _deleteDevotional(Map<String, dynamic> devotional) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Devotional'),
        content: Text(
            'Are you sure you want to delete "${devotional['title']}"?\n\nThis action cannot be undone.'),
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
        _isSaving = true;
      });

      try {
        // FIXED: Use bracket notation for Map access
        final dateFormatted =
            DateFormat('dd/MM/yyyy').format(DateTime.parse(devotional['date']));

        print('🗑️ Deleting devotional: ${devotional['title']}');
        final success = await DevotionalService.deleteDevotional(
          date: dateFormatted,
          deletedBy: 'Devotional Management',
        );

        if (success) {
          await _loadDevotionals(); // Reload the list

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Devotional deleted successfully'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          setState(() {
            _error = 'Failed to delete devotional';
          });
        }
      } catch (e) {
        print('❌ Error deleting devotional: $e');
        setState(() {
          _error = 'Error deleting devotional: $e';
        });
      } finally {
        setState(() {
          _isSaving = false;
        });
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

  Future<void> _refreshConnection() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final isConnected = await DevotionalService.testConnection();
      setState(() {
        _isConnected = isConnected;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isConnected
                ? '✅ Google Sheets connection successful!'
                : '❌ Google Sheets connection failed'),
            backgroundColor: isConnected ? Colors.green : Colors.red,
          ),
        );
      }

      if (isConnected) {
        await _loadDevotionals();
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Connection test failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
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
                icon: Icon(
                  _isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: _isConnected ? Colors.white : Colors.orange,
                ),
                onPressed: _refreshConnection,
                tooltip: _isConnected
                    ? 'Connected to Google Sheets'
                    : 'Test Connection',
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadDevotionals,
                tooltip: 'Refresh',
              ),
              if (_editingDevotional != null)
                IconButton(
                  icon: const Icon(Icons.clear),
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
                      // Connection status
                      _buildConnectionStatus(theme, colorScheme),

                      if (_error.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildErrorCard(theme),
                      ],

                      const SizedBox(height: 16),

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

  Widget _buildConnectionStatus(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isConnected
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isConnected
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isConnected ? Icons.cloud_done : Icons.cloud_off,
            color: _isConnected ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isConnected
                  ? 'Connected to Google Sheets'
                  : 'Google Sheets connection issues',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _isConnected ? Colors.green[700] : Colors.orange[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (_isConnected) ...[
            Text(
              '${_devotionals.length} devotionals',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.green[600],
              ),
            ),
          ] else ...[
            TextButton(
              onPressed: _refreshConnection,
              child: Text(
                'Retry',
                style: TextStyle(color: Colors.orange[700]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
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
          TextButton(
            onPressed: () => setState(() => _error = ''),
            child: const Text('Dismiss'),
          ),
        ],
      ),
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
                  Expanded(
                    child: Text(
                      _editingDevotional != null
                          ? 'Edit Devotional'
                          : 'Create New Devotional',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_editingDevotional != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'EDITING',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
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
                  labelText: 'Title *',
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
                  labelText: 'Content *',
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
                  onPressed:
                      (_isSaving || !_isConnected) ? null : _submitDevotional,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _editingDevotional != null ? Icons.save : Icons.add),
                  label: Text(_isSaving
                      ? (_editingDevotional != null
                          ? 'Updating...'
                          : 'Creating...')
                      : (_editingDevotional != null
                          ? 'Update Devotional'
                          : 'Create Devotional')),
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

              if (!_isConnected) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '⚠️ Google Sheets connection required to save devotionals',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
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
                Icon(Icons.cloud, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Google Sheets Devotionals',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
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
                      _isConnected ? Icons.article_outlined : Icons.cloud_off,
                      size: 48,
                      color: colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isConnected
                          ? 'No devotionals found'
                          : 'Cannot load devotionals',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isConnected
                          ? 'Create your first devotional using the form above'
                          : 'Please check your Google Sheets connection',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
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

  Widget _buildDevotionalItem(Map<String, dynamic> devotional, ThemeData theme,
      ColorScheme colorScheme) {
    // FIXED: Use bracket notation for Map access
    final isEditing = _editingDevotional != null &&
        _editingDevotional!['id'] == devotional['id'];

    return Container(
      decoration: BoxDecoration(
        color: isEditing ? colorScheme.primary.withValues(alpha: 0.1) : null,
        borderRadius: BorderRadius.circular(8),
        border: isEditing
            ? Border.all(color: colorScheme.primary.withValues(alpha: 0.3))
            : null,
      ),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isEditing
                ? colorScheme.primary.withValues(alpha: 0.2)
                : colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
          ),
          child: Icon(
            Icons.article,
            color: colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          devotional['title'] ?? 'Untitled',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: isEditing ? colorScheme.primary : null,
          ),
        ),
        subtitle: Text(
          DateFormat('EEEE, MMMM d, yyyy')
              .format(DateTime.parse(devotional['date'])),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isEditing)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'EDITING',
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
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
                if ((devotional['content'] ?? '').isNotEmpty) ...[
                  Text(
                    'Content:',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(devotional['content'] ?? ''),
                  const SizedBox(height: 12),
                ],
                if ((devotional['verse'] ?? '').isNotEmpty) ...[
                  Text(
                    'Verse:',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"${devotional['verse']}"',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if ((devotional['reference'] ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '— ${devotional['reference']}',
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
                    if ((devotional['author'] ?? '').isNotEmpty) ...[
                      Text(
                        'Author: ${devotional['author']}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Text(
                      'Source: ${devotional['source'] ?? 'Unknown'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
