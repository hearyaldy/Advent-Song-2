// admin_password_management_page.dart - NEW DEDICATED PASSWORD MANAGEMENT PAGE
import 'package:flutter/material.dart';
import 'admin_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminPasswordManagementPage extends StatefulWidget {
  const AdminPasswordManagementPage({super.key});

  @override
  State<AdminPasswordManagementPage> createState() =>
      _AdminPasswordManagementPageState();
}

class _AdminPasswordManagementPageState
    extends State<AdminPasswordManagementPage> {
  final _newMasterPasswordController = TextEditingController();
  final _confirmMasterPasswordController = TextEditingController();
  final _newContentPasswordController = TextEditingController();
  final _confirmContentPasswordController = TextEditingController();
  final _masterFormKey = GlobalKey<FormState>();
  final _contentFormKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isMasterLoading = false;
  bool _isContentLoading = false;
  bool _obscureMasterNew = true;
  bool _obscureMasterConfirm = true;
  bool _obscureContentNew = true;
  bool _obscureContentConfirm = true;
  String _currentUser = '';
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _testConnection();
  }

  @override
  void dispose() {
    _newMasterPasswordController.dispose();
    _confirmMasterPasswordController.dispose();
    _newContentPasswordController.dispose();
    _confirmContentPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUser = prefs.getString('current_user') ?? 'Master Admin';
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AdminService.testConnection();
      setState(() {
        _isConnected = result.isSuccess;
      });
    } catch (e) {
      setState(() {
        _isConnected = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateMasterPassword() async {
    if (!_masterFormKey.currentState!.validate()) return;

    setState(() {
      _isMasterLoading = true;
    });

    try {
      final result = await AdminService.updateAdminPassword(
        passwordType: 'admin_master',
        newPassword: _newMasterPasswordController.text.trim(),
        updatedBy: _currentUser,
      );

      if (result.isSuccess && result.data == true) {
        _newMasterPasswordController.clear();
        _confirmMasterPasswordController.clear();
        _showSuccess(
            '🔒 Master Admin password updated globally!\n\nAll app instances will use the new password immediately.');
      } else {
        _showError(result.error ?? 'Failed to update master password');
      }
    } catch (e) {
      _showError('Error updating master password: $e');
    } finally {
      setState(() {
        _isMasterLoading = false;
      });
    }
  }

  Future<void> _updateContentPassword() async {
    if (!_contentFormKey.currentState!.validate()) return;

    setState(() {
      _isContentLoading = true;
    });

    try {
      final result = await AdminService.updateAdminPassword(
        passwordType: 'content_password',
        newPassword: _newContentPasswordController.text.trim(),
        updatedBy: _currentUser,
      );

      if (result.isSuccess && result.data == true) {
        _newContentPasswordController.clear();
        _confirmContentPasswordController.clear();
        _showSuccess(
            '👥 Content Team password updated globally!\n\nPlease share the new password with content contributors.');
      } else {
        _showError(result.error ?? 'Failed to update content password');
      }
    } catch (e) {
      _showError('Error updating content password: $e');
    } finally {
      setState(() {
        _isContentLoading = false;
      });
    }
  }

  Future<void> _testPasswordUpdate() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AdminService.testPasswordUpdate();

      if (result.isSuccess && result.data == true) {
        _showSuccess('✅ Password update system is working correctly!');
      } else {
        _showError('❌ Password update system test failed');
      }
    } catch (e) {
      _showError('Test failed: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⚠️ $message'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String? _validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    if (value.length > 50) {
      return 'Password must be less than 50 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value, String originalPassword) {
    if (value == null || value.trim().isEmpty) {
      return 'Please confirm your password';
    }
    if (value != originalPassword) {
      return 'Passwords do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Password Management'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        actions: [
          // Connection indicator
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
                  _isConnected ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 10,
                    color: _isConnected ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _testConnection,
            tooltip: 'Test Connection',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'test':
                  _testPasswordUpdate();
                  break;
                case 'info':
                  _showInfoDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'test',
                child: ListTile(
                  leading: Icon(Icons.bug_report),
                  title: Text('Test System'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'info',
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('About'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Info
                  _buildHeaderInfo(),
                  const SizedBox(height: 24),

                  // Master Password Section
                  _buildMasterPasswordSection(),
                  const SizedBox(height: 24),

                  // Content Password Section
                  _buildContentPasswordSection(),
                  const SizedBox(height: 24),

                  // Security Notice
                  _buildSecurityNotice(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderInfo() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withOpacity(0.1),
            colorScheme.secondary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.security,
                color: colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Global Password Management',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Manage admin passwords that are synchronized across all app instances through Google Sheets. Changes take effect immediately for all users.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Current User: $_currentUser',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterPasswordSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _masterFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.admin_panel_settings,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Master Admin Password',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        Text(
                          'Full administrative access',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  '⚠️ Master password provides full control including password management, system settings, and all administrative functions.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.red[700],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newMasterPasswordController,
                obscureText: _obscureMasterNew,
                decoration: InputDecoration(
                  labelText: 'New Master Password *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureMasterNew
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureMasterNew = !_obscureMasterNew;
                      });
                    },
                  ),
                ),
                validator: _validatePassword,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmMasterPasswordController,
                obscureText: _obscureMasterConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm Master Password *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureMasterConfirm
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureMasterConfirm = !_obscureMasterConfirm;
                      });
                    },
                  ),
                ),
                validator: (value) => _validateConfirmPassword(
                    value, _newMasterPasswordController.text),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_isMasterLoading || !_isConnected)
                      ? null
                      : _updateMasterPassword,
                  icon: _isMasterLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.security),
                  label: Text(_isMasterLoading
                      ? 'Updating Master Password...'
                      : 'Update Master Password'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentPasswordSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _contentFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.edit,
                      color: Colors.blue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Content Team Password',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        Text(
                          'For content contributors only',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  'ℹ️ Content password allows adding and managing devotional content only. Share this password responsibly with trusted contributors.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.blue[700],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newContentPasswordController,
                obscureText: _obscureContentNew,
                decoration: InputDecoration(
                  labelText: 'New Content Password *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureContentNew
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureContentNew = !_obscureContentNew;
                      });
                    },
                  ),
                ),
                validator: _validatePassword,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmContentPasswordController,
                obscureText: _obscureContentConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm Content Password *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureContentConfirm
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureContentConfirm = !_obscureContentConfirm;
                      });
                    },
                  ),
                ),
                validator: (value) => _validateConfirmPassword(
                    value, _newContentPasswordController.text),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_isContentLoading || !_isConnected)
                      ? null
                      : _updateContentPassword,
                  icon: _isContentLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.group),
                  label: Text(_isContentLoading
                      ? 'Updating Content Password...'
                      : 'Update Content Password'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityNotice() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Security Guidelines',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• Use strong, unique passwords (minimum 6 characters)\n'
            '• Changes are synchronized globally via Google Sheets\n'
            '• Master password provides full administrative control\n'
            '• Content password is for devotional contributors only\n'
            '• Keep passwords confidential and share responsibly\n'
            '• Sessions expire after 2 hours for security',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Password Management System'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'This system manages admin passwords through Google Sheets:'),
              SizedBox(height: 12),
              Text('🔄 Real-time Synchronization'),
              Text('Changes are immediately available to all app instances'),
              SizedBox(height: 8),
              Text('🔐 Two-Level Access'),
              Text('Master Admin: Full control including password management'),
              Text('Content Admin: Devotional content management only'),
              SizedBox(height: 8),
              Text('📊 AdminCredentials Sheet'),
              Text('Passwords are stored securely in Google Sheets'),
              SizedBox(height: 8),
              Text('⏱️ Session Management'),
              Text('Admin sessions expire after 2 hours for security'),
            ],
          ),
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
}
