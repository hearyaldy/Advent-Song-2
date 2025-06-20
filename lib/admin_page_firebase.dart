// admin_page_firebase.dart - FULLY MIGRATED TO FIREBASE
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/auth_service.dart';
import 'services/firebase_service.dart';
import 'models/devotional_model.dart';
import 'models/admin_model.dart';
import 'devotional_management_page.dart';
import 'admin_password_management_page.dart';
import 'theme_notifier.dart';

class AdminPageFirebase extends StatefulWidget {
  const AdminPageFirebase({super.key});

  @override
  State<AdminPageFirebase> createState() => _AdminPageFirebaseState();
}

class _AdminPageFirebaseState extends State<AdminPageFirebase> {
  // Authentication state
  AdminModel? _currentAdmin;
  bool _isLoading = false;
  bool _isConnected = false;
  String _error = '';

  // Devotional form
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _verseController = TextEditingController();
  final _referenceController = TextEditingController();
  final _authorController = TextEditingController();
  final _dateController = TextEditingController();
  final _devotionalFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _initializePage();
    _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _verseController.dispose();
    _referenceController.dispose();
    _authorController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _initializePage() async {
    await _loadCurrentAdmin();
    await _testFirebaseConnection();
  }

  /// Load current admin information
  Future<void> _loadCurrentAdmin() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final admin = await AuthService.getCurrentAdmin();
      setState(() {
        _currentAdmin = admin;
        _isLoading = false;
      });

      if (admin == null) {
        _showError('Not authenticated as admin');
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load admin info: $e';
        _isLoading = false;
      });
    }
  }

  /// Test Firebase connection
  Future<void> _testFirebaseConnection() async {
    try {
      final result = await FirebaseService.testConnection();
      setState(() {
        _isConnected = result.isSuccess;
      });

      if (!result.isSuccess) {
        _showError('Firebase connection failed: ${result.error}');
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
      });
      _showError('Firebase connection error: $e');
    }
  }

  /// Add devotional using Firebase
  Future<void> _addDevotional() async {
    if (!_devotionalFormKey.currentState!.validate()) return;
    if (!_isConnected) {
      _showError('Firebase connection required');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // Parse date from DD/MM/YYYY to YYYY-MM-DD
      final dateFormat = DateFormat('dd/MM/yyyy');
      final parsedDate = dateFormat.parse(_dateController.text);
      final dateKey = DateFormat('yyyy-MM-dd').format(parsedDate);

      // Create devotional model
      final devotional = DevotionalModel(
        id: dateKey,
        date: dateKey,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        verse: _verseController.text.trim(),
        reference: _referenceController.text.trim(),
        author: _authorController.text.trim().isEmpty
            ? 'Devotional Team'
            : _authorController.text.trim(),
        addedBy: _currentAdmin?.email ?? 'Admin',
        createdAt: DateTime.now(),
        source: 'Firebase Admin',
      );

      // Add to Firebase
      final result = await FirebaseService.addDevotional(devotional);

      if (result.isSuccess) {
        _clearDevotionalForm();
        _showSuccess(
            '✅ Devotional saved to Firebase!\nAdded by: ${_currentAdmin?.displayName}');
      } else {
        _showError('Failed to save devotional: ${result.error}');
      }
    } catch (e) {
      _showError('Error saving devotional: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Clear devotional form
  void _clearDevotionalForm() {
    _titleController.clear();
    _contentController.clear();
    _verseController.clear();
    _referenceController.clear();
    _authorController.clear();
    _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
  }

  /// Sign out admin
  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await AuthService.signOut();
      if (result.isSuccess && mounted) {
        Navigator.of(context).pushReplacementNamed('/admin-login');
      }
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ $message'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading && _currentAdmin == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 16),
              Text('Loading Firebase admin...',
                  style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      );
    }

    if (_currentAdmin == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Firebase Admin'),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: colorScheme.error),
              const SizedBox(height: 16),
              Text('Not authenticated', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(_error.isNotEmpty ? _error : 'Please log in as admin'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pushReplacementNamed('/admin-login'),
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Admin Panel'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        actions: [
          // Firebase connection indicator
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isConnected
                  ? Colors.green.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: _isConnected ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'Firebase',
                  style: TextStyle(
                    fontSize: 10,
                    color: _isConnected ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Admin level indicator
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _currentAdmin!.level == AdminLevel.master
                  ? Colors.red.withOpacity(0.2)
                  : Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _currentAdmin!.level == AdminLevel.master
                  ? '👑 Master'
                  : '✏️ Content',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Test connection
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _testFirebaseConnection,
            tooltip: 'Test Firebase Connection',
          ),

          // Sign out
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome section
            _buildWelcomeCard(),
            const SizedBox(height: 24),

            // Error display
            if (_error.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_error,
                            style: TextStyle(color: Colors.red[700]))),
                    TextButton(
                      onPressed: () => setState(() => _error = ''),
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Devotional form
            _buildDevotionalForm(),
            const SizedBox(height: 32),

            // Master admin features
            if (_currentAdmin!.level == AdminLevel.master) ...[
              _buildMasterAdminSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMaster = _currentAdmin!.level == AdminLevel.master;

    return Card(
      color: isMaster
          ? colorScheme.errorContainer.withOpacity(0.1)
          : colorScheme.primaryContainer.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              isMaster ? Icons.admin_panel_settings : Icons.edit,
              color: isMaster ? Colors.red : colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${_currentAdmin!.displayName}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${_currentAdmin!.levelDisplayName} • Firebase Auth',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: isMaster ? Colors.red : colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isMaster ? 'MASTER' : 'CONTENT',
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevotionalForm() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _devotionalFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.add_circle, color: colorScheme.primary, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Add New Devotional',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Firebase status indicator
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isConnected
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isConnected
                            ? Colors.green.withOpacity(0.3)
                            : Colors.red.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isConnected ? Icons.cloud_done : Icons.cloud_off,
                          color: _isConnected ? Colors.green : Colors.red,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Firebase',
                          style: TextStyle(
                            fontSize: 10,
                            color: _isConnected
                                ? Colors.green[700]
                                : Colors.red[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Devotionals are saved to Firebase Realtime Database with real-time sync.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24),

              // Date field
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Date (DD/MM/YYYY)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please select a date' : null,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    _dateController.text =
                        DateFormat('dd/MM/yyyy').format(date);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Title field
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                maxLength: 100,
                validator: (value) => value?.trim().isEmpty ?? true
                    ? 'Please enter a title'
                    : null,
              ),
              const SizedBox(height: 16),

              // Content field
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Content *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.article),
                  alignLabelWithHint: true,
                ),
                maxLines: 6,
                maxLength: 1000,
                validator: (value) => value?.trim().isEmpty ?? true
                    ? 'Please enter content'
                    : null,
              ),
              const SizedBox(height: 16),

              // Verse field
              TextFormField(
                controller: _verseController,
                decoration: const InputDecoration(
                  labelText: 'Bible Verse',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.format_quote),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                maxLength: 500,
              ),
              const SizedBox(height: 16),

              // Reference field
              TextFormField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'Bible Reference',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.menu_book),
                  hintText: 'e.g., John 3:16',
                ),
                maxLength: 50,
              ),
              const SizedBox(height: 16),

              // Author field
              TextFormField(
                controller: _authorController,
                decoration: const InputDecoration(
                  labelText: 'Author',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                  hintText: 'e.g., Pastor John',
                ),
                maxLength: 50,
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearDevotionalForm,
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _testFirebaseConnection,
                      icon: const Icon(Icons.cloud),
                      label: const Text('Test'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed:
                          (_isLoading || !_isConnected) ? null : _addDevotional,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload),
                      label: Text(_isLoading
                          ? 'Saving to Firebase...'
                          : 'Save to Firebase'),
                    ),
                  ),
                ],
              ),

              if (!_isConnected) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '⚠️ Firebase connection required to save devotionals',
                    style: TextStyle(color: Colors.orange[700], fontSize: 12),
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

  Widget _buildMasterAdminSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: colorScheme.errorContainer.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Master Admin Controls',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.library_books, color: Colors.blue),
              title: const Text('Advanced Devotional Management'),
              subtitle: const Text('Full CRUD operations with Firebase'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DevotionalManagementPage(
                      themeNotifier: ThemeNotifier(),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.admin_panel_settings, color: colorScheme.primary),
              title: const Text('Firebase Password Management'),
              subtitle: const Text('Manage admin access and permissions'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminPasswordManagementPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.cloud, color: Colors.orange),
              title: const Text('Test Firebase Connection'),
              subtitle: const Text('Verify Firebase integration'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _testFirebaseConnection,
            ),
            ListTile(
              leading: Icon(Icons.analytics, color: Colors.purple),
              title: const Text('Firebase Analytics'),
              subtitle: const Text('Real-time usage and admin activity'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _showComingSoonDialog('Firebase Analytics');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feature),
        content: Text(
            '$feature is being developed with Firebase integration and will be available in the next update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
