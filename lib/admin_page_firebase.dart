// admin_page.dart - COMPLETE UPDATED VERSION WITH GOOGLE SHEETS INTEGRATION
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'devotional_service.dart'; // Use unified service
import 'devotional_management_page.dart';
import 'theme_notifier.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  // Authentication state
  bool _isAuthenticated = false;
  bool _isLoading = false;
  bool _isCheckingPassword = false;
  String _adminLevel = ''; // 'master' or 'content'
  String _currentUser = '';
  final _passwordController = TextEditingController();

  // Password management (Master Admin only)
  final _newMasterPasswordController = TextEditingController();
  final _confirmMasterPasswordController = TextEditingController();
  final _newContentPasswordController = TextEditingController();
  final _confirmContentPasswordController = TextEditingController();

  // Devotional form (All admins)
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _verseController = TextEditingController();
  final _referenceController = TextEditingController();
  final _authorController = TextEditingController();
  final _dateController = TextEditingController();
  final _devotionalFormKey = GlobalKey<FormState>();

  // Google Sheets configuration
  static const String SHEET_ID = '1E6GVXX3dHpGsohUg5e7qC9jZwRhMvNdmelHQMQ8SWZ8';
  static const String ADMIN_CSV_URL =
      'https://docs.google.com/spreadsheets/d/$SHEET_ID/export?format=csv&gid=887869470';
  static const String APPS_SCRIPT_URL =
      'https://script.google.com/macros/s/AKfycbzD4y9TW9ldAxJ-lhHOR4C1esrutbjjXEhI5KB6OyA8GA0AgtkALfetGRTlO5KW3vZx/exec';

  // Admin levels
  static const String MASTER_ADMIN = 'master';
  static const String CONTENT_ADMIN = 'content';

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _newMasterPasswordController.dispose();
    _confirmMasterPasswordController.dispose();
    _newContentPasswordController.dispose();
    _confirmContentPasswordController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _verseController.dispose();
    _referenceController.dispose();
    _authorController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  // 🔐 AUTHENTICATION & ACCESS CONTROL

  Future<Map<String, String>> _getAdminCredentials() async {
    try {
      print('🔍 Loading admin credentials from AdminCredentials sheet...');

      final response = await http.get(
        Uri.parse(ADMIN_CSV_URL),
        headers: {
          'User-Agent': 'LaguAdvent/1.0',
          'Accept-Charset': 'utf-8',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        String csvContent;
        try {
          csvContent = utf8.decode(response.bodyBytes, allowMalformed: true);
        } catch (e) {
          csvContent = latin1.decode(response.bodyBytes);
        }

        print(
            '📄 CSV Content Preview: ${csvContent.substring(0, csvContent.length > 200 ? 200 : csvContent.length)}');

        final parsedCredentials = _parseAdminCredentials(csvContent);
        if (parsedCredentials.isNotEmpty) {
          print('✅ Loaded credentials: ${parsedCredentials.keys}');
          return parsedCredentials;
        }
      }
    } catch (e) {
      print('❌ Error loading credentials: $e');
    }

    // Fallback credentials if AdminCredentials sheet unavailable
    print('🔄 Using fallback credentials');
    return {
      'admin_master': 'masterAdmin2025',
      'content_password': 'contentTeam2025',
    };
  }

  Map<String, String> _parseAdminCredentials(String csvContent) {
    try {
      final lines = csvContent
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();

      final credentials = <String, String>{};

      // Skip header and process data lines
      for (int i = 1; i < lines.length; i++) {
        final values = _parseCSVLine(lines[i]);
        if (values.length >= 2) {
          final adminType = values[0].replaceAll('"', '').trim();
          final password = values[1].replaceAll('"', '').trim();

          if (adminType.isNotEmpty && password.isNotEmpty) {
            credentials[adminType] = password;
            print(
                '📋 Found credential: $adminType -> ${password.substring(0, 3)}...');
          }
        }
      }

      return credentials;
    } catch (e) {
      print('❌ Error parsing credentials: $e');
      return {
        'admin_master': 'masterAdmin2025',
        'content_password': 'contentTeam2025',
      };
    }
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

    values.add(currentValue.trim());
    return values;
  }

  Future<void> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isAuth = prefs.getBool('admin_authenticated') ?? false;
    final authTime = prefs.getInt('admin_auth_time') ?? 0;
    final adminLevel = prefs.getString('admin_level') ?? '';
    final currentUser = prefs.getString('current_user') ?? '';
    final now = DateTime.now().millisecondsSinceEpoch;

    // Session expires after 2 hours
    if (isAuth && (now - authTime) < (2 * 60 * 60 * 1000)) {
      setState(() {
        _isAuthenticated = true;
        _adminLevel = adminLevel;
        _currentUser = currentUser;
      });
    } else if (isAuth) {
      await _logout();
      _showSessionExpiredDialog();
    }
  }

  Future<void> _authenticate() async {
    setState(() {
      _isCheckingPassword = true;
    });

    try {
      final credentials = await _getAdminCredentials();
      final enteredPassword = _passwordController.text.trim();

      String? level;
      String? userName;

      print('🔐 Checking password: ${enteredPassword.substring(0, 3)}...');
      print('🔑 Available credentials: ${credentials.keys}');

      // Check against admin_master password
      final masterPassword = credentials['admin_master'];
      final contentPassword = credentials['content_password'];

      if (masterPassword != null && enteredPassword == masterPassword) {
        level = MASTER_ADMIN;
        userName = 'Master Admin';
        print('✅ Master admin authenticated');
      }
      // Check against content_password
      else if (contentPassword != null && enteredPassword == contentPassword) {
        level = CONTENT_ADMIN;
        userName = 'Content Contributor';
        print('✅ Content admin authenticated');
      }

      if (level != null && userName != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('admin_authenticated', true);
        await prefs.setInt(
            'admin_auth_time', DateTime.now().millisecondsSinceEpoch);
        await prefs.setString('admin_level', level);
        await prefs.setString('current_user', userName);

        setState(() {
          _isAuthenticated = true;
          _adminLevel = level!;
          _currentUser = userName!;
        });

        _passwordController.clear();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('✅ Welcome $userName (${_getAccessLevelDisplay()})'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        print('❌ Authentication failed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Invalid admin password'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Authentication error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Authentication error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingPassword = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_authenticated');
    await prefs.remove('admin_auth_time');
    await prefs.remove('admin_level');
    await prefs.remove('current_user');

    setState(() {
      _isAuthenticated = false;
      _adminLevel = '';
      _currentUser = '';
    });
  }

  String _getAccessLevelDisplay() {
    switch (_adminLevel) {
      case MASTER_ADMIN:
        return 'Master Admin';
      case CONTENT_ADMIN:
        return 'Content Contributor';
      default:
        return 'Unknown';
    }
  }

  bool get _isMasterAdmin => _adminLevel == MASTER_ADMIN;

  // 📝 DEVOTIONAL MANAGEMENT - USING UNIFIED SERVICE

  Future<void> _addDevotional() async {
    if (!_devotionalFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print('📡 Adding devotional using unified service...');

      final success = await DevotionalService.addDevotional(
        date: _dateController.text,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        verse: _verseController.text.trim(),
        reference: _referenceController.text.trim(),
        author: _authorController.text.trim(),
        addedBy: '$_currentUser ($_adminLevel)',
      );

      if (success) {
        _clearDevotionalForm();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('✅ Devotional saved to Google Sheets!'),
                  Text('👤 Added by: $_currentUser'),
                  Text('🔐 Admin Level: ${_getAccessLevelDisplay()}'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        throw Exception('Failed to save devotional to Google Sheets');
      }
    } catch (e) {
      print('❌ Error: $e');
      _showError('Failed to save: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testDevotionalConnection() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('🧪 Testing devotional service connection...');

      final isConnected = await DevotionalService.testConnection();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isConnected
                ? '✅ Google Sheets connection successful!'
                : '❌ Google Sheets connection failed'),
            backgroundColor: isConnected ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Connection test failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Connection test failed: ${e.toString()}'),
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

  void _clearDevotionalForm() {
    _titleController.clear();
    _contentController.clear();
    _verseController.clear();
    _referenceController.clear();
    _authorController.clear();
    _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
  }

  bool _validateDevotionalForm() {
    if (_titleController.text.trim().isEmpty) {
      _showError('Please enter a title');
      return false;
    }
    if (_contentController.text.trim().isEmpty) {
      _showError('Please enter content');
      return false;
    }
    if (_dateController.text.trim().isEmpty) {
      _showError('Please select a date');
      return false;
    }
    return true;
  }

  // 🔑 PASSWORD MANAGEMENT (Master Admin Only)

  Future<void> _updateMasterPassword() async {
    if (!_isMasterAdmin) {
      _showError('Only Master Admin can change passwords');
      return;
    }

    if (_newMasterPasswordController.text.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    if (_newMasterPasswordController.text !=
        _confirmMasterPasswordController.text) {
      _showError('Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _updatePasswordInCloud(
          'admin_master', _newMasterPasswordController.text);

      if (success) {
        _newMasterPasswordController.clear();
        _confirmMasterPasswordController.clear();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔒 Master Admin password updated globally!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        _showError('Failed to update password');
      }
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateContentPassword() async {
    if (!_isMasterAdmin) {
      _showError('Only Master Admin can manage content passwords');
      return;
    }

    if (_newContentPasswordController.text.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    if (_newContentPasswordController.text !=
        _confirmContentPasswordController.text) {
      _showError('Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _updatePasswordInCloud(
          'content_password', _newContentPasswordController.text);

      if (success) {
        _newContentPasswordController.clear();
        _confirmContentPasswordController.clear();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '👥 Content password updated! Share new password with contributors.'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } else {
        _showError('Failed to update content password');
      }
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _updatePasswordInCloud(
      String passwordType, String newPassword) async {
    try {
      print('🔐 Updating password: $passwordType');

      final uri = Uri.parse(APPS_SCRIPT_URL).replace(queryParameters: {
        'action': 'updatePassword',
        'passwordType': passwordType,
        'newPassword': newPassword,
        'updatedBy': _currentUser,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      });

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'LaguAdvent/1.0',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      print('📊 Password update response: ${response.statusCode}');
      print('📝 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return result['success'] == true;
      }
    } catch (e) {
      print('❌ Error updating password: $e');
    }
    return false;
  }

  // 🛠️ UTILITY METHODS

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ $message'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showSessionExpiredDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.schedule, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Session Expired'),
          ],
        ),
        content:
            const Text('Your admin session has expired. Please log in again.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feature),
        content: Text(
          'This feature is coming soon!\n\n'
          'We\'re working on bringing you $feature functionality. '
          'Stay tuned for updates in the next version.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  // 📱 UI BUILDING

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        actions: _isAuthenticated
            ? [
                // User indicator
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isMasterAdmin
                        ? Colors.red.withValues(alpha: 0.2)
                        : Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _isMasterAdmin ? '👑 Master' : '✏️ Content',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Test connection
                IconButton(
                  icon: const Icon(Icons.wifi_find),
                  onPressed: _testDevotionalConnection,
                  tooltip: 'Test Google Sheets Connection',
                ),

                // Password management (Master only)
                if (_isMasterAdmin)
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: _showPasswordManagementDialog,
                    tooltip: 'Password Management',
                  ),

                // Logout
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: _logout,
                  tooltip: 'Logout',
                ),
              ]
            : null,
      ),
      body: _isAuthenticated ? _buildAdminInterface() : _buildLoginInterface(),
    );
  }

  Widget _buildLoginInterface() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  size: 64,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Admin Authentication',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your admin password',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Access level info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info,
                              color: colorScheme.primary, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Access Levels',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '👑 Master Admin: Full control + password management\n'
                        '✏️ Content Admin: Add devotionals only',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Admin Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  onSubmitted: (_) => _authenticate(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isCheckingPassword ? null : _authenticate,
                    icon: _isCheckingPassword
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(
                        _isCheckingPassword ? 'Authenticating...' : 'Login'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminInterface() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome card
          _buildWelcomeCard(),
          const SizedBox(height: 24),

          // Devotional form
          _buildDevotionalForm(),

          // Master admin features
          if (_isMasterAdmin) ...[
            const SizedBox(height: 32),
            _buildMasterAdminSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: _isMasterAdmin
          ? colorScheme.errorContainer.withValues(alpha: 0.1)
          : colorScheme.primaryContainer.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              _isMasterAdmin ? Icons.admin_panel_settings : Icons.edit,
              color: _isMasterAdmin ? Colors.red : colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, $_currentUser',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _isMasterAdmin
                        ? 'Master Admin - Full control'
                        : 'Content Admin - Add devotionals',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: _isMasterAdmin ? Colors.red : colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _isMasterAdmin ? 'MASTER' : 'CONTENT',
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
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Connection status indicator
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_done, color: Colors.green, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Google Sheets',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green[700],
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
                'Devotionals are automatically saved to Google Sheets and synced across all devices.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
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
                      onPressed: _testDevotionalConnection,
                      icon: const Icon(Icons.wifi_find),
                      label: const Text('Test'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _addDevotional,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload),
                      label: Text(_isLoading
                          ? 'Saving to Sheets...'
                          : 'Save to Sheets'),
                    ),
                  ),
                ],
              ),
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
      color: colorScheme.errorContainer.withValues(alpha: 0.1),
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
              leading:
                  Icon(Icons.admin_panel_settings, color: colorScheme.primary),
              title: const Text('Password Management'),
              subtitle: const Text('Change master and content passwords'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showPasswordManagementDialog,
            ),
            ListTile(
              leading: Icon(Icons.library_books, color: Colors.blue),
              title: const Text('Advanced Devotional Management'),
              subtitle: const Text('Full CRUD operations for devotionals'),
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
              leading: Icon(Icons.wifi_find, color: Colors.orange),
              title: const Text('Test Devotional Connection'),
              subtitle: const Text('Test Google Sheets integration'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _testDevotionalConnection,
            ),
            ListTile(
              leading: Icon(Icons.analytics, color: Colors.purple),
              title: const Text('Usage Analytics'),
              subtitle: const Text('View app usage and statistics'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _showComingSoonDialog('Usage Analytics');
              },
            ),
            ListTile(
              leading: Icon(Icons.backup, color: Colors.teal),
              title: const Text('Backup & Export'),
              subtitle: const Text('Backup devotional data'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _showComingSoonDialog('Backup & Export');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPasswordManagementDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.red),
            const SizedBox(width: 8),
            const Expanded(child: Text('Password Management')),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 500),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Master password section
                ExpansionTile(
                  leading: Icon(Icons.admin_panel_settings, color: Colors.red),
                  title: const Text('Master Admin Password'),
                  subtitle: const Text('Your full-control password'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextField(
                            controller: _newMasterPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'New Master Password',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _confirmMasterPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Confirm Password',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _updateMasterPassword,
                              style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red),
                              child: const Text('Update Master Password'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Content password section
                ExpansionTile(
                  leading: Icon(Icons.edit, color: Colors.blue),
                  title: const Text('Content Team Password'),
                  subtitle: const Text('For content contributors only'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextField(
                            controller: _newContentPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'New Content Password',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _confirmContentPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Confirm Password',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _updateContentPassword,
                              style: FilledButton.styleFrom(
                                  backgroundColor: Colors.blue),
                              child: const Text('Update Content Password'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
