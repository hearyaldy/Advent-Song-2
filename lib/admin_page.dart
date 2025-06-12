// admin_page.dart - Two-Tier Security System
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
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

  // Google Sheets configuration
  static const String SHEET_ID = '1E6GVXX3dHpGsohUg5e7qC9jZwRhMvNdmelHQMQ8SWZ8';
  static const String CSV_URL =
      'https://docs.google.com/spreadsheets/d/$SHEET_ID/export?format=csv&gid=0';
  static const String ADMIN_CSV_URL =
      'https://docs.google.com/spreadsheets/d/$SHEET_ID/gviz/tq?tqx=out:csv&sheet=AdminCredentials';
  static const String APPS_SCRIPT_URL =
      'https://script.google.com/macros/s/AKfycbwHs6o914KFEj1sl1-pY7q2Zp38m-HSBofQ31Mn0Uyi5lQWdlN3gbpBfUML_Iwxl2LvVQ/exec';

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

        final parsedCredentials = _parseAdminCredentials(csvContent);
        if (parsedCredentials.isNotEmpty) {
          return parsedCredentials;
        }
      }
    } catch (e) {
      print('❌ Error loading credentials: $e');
    }

    // Fallback credentials if AdminCredentials sheet unavailable
    print('🔄 Using fallback credentials');
    return {
      'master_password': 'masterAdmin2025',
      'content_password': 'contentTeam2025',
    };
  }

  Map<String, String> _parseAdminCredentials(String csvContent) {
    try {
      final lines = csvContent.split('\n');

      // Initialize with fallback values
      String masterPassword = 'masterAdmin2025';
      String contentPassword = 'contentTeam2025';

      // Look for admin credentials in the last rows
      // Expected format: admin_password_master, actual_password
      //                  admin_password_content, actual_password
      for (final line in lines) {
        final values = _parseCSVLine(line);
        if (values.length >= 2) {
          final key = values[0].toLowerCase().trim();
          final password = values[1].trim();

          if ((key.contains('admin_password_master') ||
                  key == 'master_password') &&
              password.isNotEmpty) {
            masterPassword = password;
          } else if ((key.contains('admin_password_content') ||
                  key == 'content_password') &&
              password.isNotEmpty) {
            contentPassword = password;
          }
        }
      }

      return {
        'master_password': masterPassword,
        'content_password': contentPassword,
      };
    } catch (e) {
      print('❌ Error parsing credentials: $e');
      // Return fallback on any parsing error
      return {
        'master_password': 'masterAdmin2025',
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

      // Check against master password
      final masterPassword = credentials['master_password'];
      final contentPassword = credentials['content_password'];

      if (masterPassword != null && enteredPassword == masterPassword) {
        level = MASTER_ADMIN;
        userName = 'Master Admin';
      }
      // Check against content password
      else if (contentPassword != null && enteredPassword == contentPassword) {
        level = CONTENT_ADMIN;
        userName = 'Content Contributor';
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
          'master', _newMasterPasswordController.text);

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
          'content', _newContentPasswordController.text);

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
      final response = await http.post(
        Uri.parse(APPS_SCRIPT_URL),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'updateAdminPassword',
          'passwordType': passwordType,
          'password': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return result['success'] == true;
      }
    } catch (e) {
      print('❌ Error updating password: $e');
    }
    return false;
  }

  // 📝 DEVOTIONAL MANAGEMENT - Test Version (bypasses Apps Script)

  Future<void> _addDevotional() async {
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // BYPASS APPS SCRIPT FOR NOW - just test the form
      print('📝 Devotional Details:');
      print('📅 Date: ${_dateController.text}');
      print('📖 Title: ${_titleController.text}');
      print('📄 Content: ${_contentController.text}');
      print('✝️ Verse: ${_verseController.text}');
      print('📚 Reference: ${_referenceController.text}');
      print('👤 Author: ${_authorController.text}');
      print('🔐 Added by: $_currentUser ($_adminLevel)');

      // Simulate processing time
      await Future.delayed(Duration(seconds: 2));

      _clearForm();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ Devotional form validated successfully!'),
                Text('👤 Added by: $_currentUser'),
                Text('📝 Check console for details'),
                SizedBox(height: 4),
                Text('🔧 Next: Set up Google Apps Script for real saving',
                    style:
                        TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      _showError('Test completed: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _validateForm() {
    if (_titleController.text.isEmpty) {
      _showError('Please enter a title');
      return false;
    }
    if (_contentController.text.isEmpty) {
      _showError('Please enter content');
      return false;
    }
    return true;
  }

  void _clearForm() {
    _titleController.clear();
    _contentController.clear();
    _verseController.clear();
    _referenceController.clear();
    _authorController.clear();
    _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
  }

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
            SizedBox(width: 8),
            Text('Session Expired'),
          ],
        ),
        content: Text('Your admin session has expired. Please log in again.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
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
        title: Text(
          'Admin Panel',
          style: TextStyle(fontSize: 16),
        ),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        actions: _isAuthenticated
            ? [
                // User indicator - Ultra compact
                Container(
                  margin: EdgeInsets.only(right: 2),
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: _isMasterAdmin
                        ? Colors.red.withOpacity(0.2)
                        : Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _isMasterAdmin ? '👑' : '✏️',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),

                // Password management (Master only) - Compact
                if (_isMasterAdmin)
                  IconButton(
                    icon: const Icon(Icons.settings, size: 18),
                    onPressed: _showPasswordManagementDialog,
                    tooltip: 'Passwords',
                    padding: EdgeInsets.all(4),
                    constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                  ),

                // Logout - Compact
                IconButton(
                  icon: const Icon(Icons.logout, size: 18),
                  onPressed: _logout,
                  tooltip: 'Logout',
                  padding: EdgeInsets.all(4),
                  constraints: BoxConstraints(minWidth: 32, minHeight: 32),
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
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Access level info
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info,
                              color: colorScheme.primary, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Access Levels',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
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
                        ? SizedBox(
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
          ? colorScheme.errorContainer.withOpacity(0.1)
          : colorScheme.primaryContainer.withOpacity(0.1),
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
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: _isMasterAdmin ? Colors.red : colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _isMasterAdmin ? 'MASTER' : 'CONTENT',
                style: TextStyle(
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
              ],
            ),
            const SizedBox(height: 24),

            // Date field
            TextFormField(
              controller: _dateController,
              decoration: InputDecoration(
                labelText: 'Date (DD/MM/YYYY)',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  _dateController.text = DateFormat('dd/MM/yyyy').format(date);
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

            // Action buttons - Responsive layout
            LayoutBuilder(
              builder: (context, constraints) {
                // If width is too narrow, stack buttons vertically
                if (constraints.maxWidth < 280) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _clearForm,
                        icon: const Icon(Icons.clear, size: 18),
                        label: const Text('Clear Form'),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _isLoading ? null : _addDevotional,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add, size: 18),
                        label:
                            Text(_isLoading ? 'Adding...' : 'Add Devotional'),
                      ),
                    ],
                  );
                } else {
                  // Regular horizontal layout for wider screens
                  return Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _clearForm,
                          icon: const Icon(Icons.clear, size: 18),
                          label: const Text('Clear'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _addDevotional,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.add, size: 18),
                          label: Text(
                            _isLoading ? 'Adding...' : 'Add',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ],
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
              leading:
                  Icon(Icons.admin_panel_settings, color: colorScheme.primary),
              title: Text('Password Management'),
              subtitle: Text('Change master and content passwords'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showPasswordManagementDialog,
            ),
            ListTile(
              leading: Icon(Icons.people, color: Colors.blue),
              title: Text('Content Contributors'),
              subtitle: Text('Manage who can add devotionals'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showContentManagementDialog,
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
            SizedBox(width: 8),
            Expanded(child: Text('Password Management')),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(maxHeight: 500),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Master password section
                ExpansionTile(
                  leading: Icon(Icons.admin_panel_settings, color: Colors.red),
                  title: Text('Master Admin Password'),
                  subtitle: Text('Your full-control password'),
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextField(
                            controller: _newMasterPasswordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'New Master Password',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          SizedBox(height: 12),
                          TextField(
                            controller: _confirmMasterPasswordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _updateMasterPassword,
                              style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red),
                              child: Text('Update Master Password'),
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
                  title: Text('Content Team Password'),
                  subtitle: Text('For content contributors only'),
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextField(
                            controller: _newContentPasswordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'New Content Password',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          SizedBox(height: 12),
                          TextField(
                            controller: _confirmContentPasswordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _updateContentPassword,
                              style: FilledButton.styleFrom(
                                  backgroundColor: Colors.blue),
                              child: Text('Update Content Password'),
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
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showContentManagementDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.people, color: Colors.blue),
            SizedBox(width: 8),
            Text('Content Contributors'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Content contributors can:'),
            SizedBox(height: 8),
            Text('✅ Add new devotionals'),
            Text('✅ Fill in all devotional fields'),
            Text('❌ Change any passwords'),
            Text('❌ Access master admin features'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Share the Content Team password with trusted contributors. '
                'You can change this password anytime from the Password Management section.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it'),
          ),
        ],
      ),
    );
  }
}
