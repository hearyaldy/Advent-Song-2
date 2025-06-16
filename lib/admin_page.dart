// Production Admin Page - Clean, user-friendly interface
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'admin_service.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _masterPasswordController = TextEditingController();
  final _contentPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  Map<String, String>? _currentCredentials;
  String? _connectionStatus;

  @override
  void initState() {
    super.initState();
    _initializeAdmin();
  }

  @override
  void dispose() {
    _masterPasswordController.dispose();
    _contentPasswordController.dispose();
    super.dispose();
  }

  Future<void> _initializeAdmin() async {
    await _loadCredentials();
    await _checkConnection();
  }

  Future<void> _loadCredentials() async {
    setState(() => _isLoading = true);

    final result = await AdminService.getAdminCredentials();

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _currentCredentials = result.data;
        _masterPasswordController.text = result.data!['admin_master'] ?? '';
        _contentPasswordController.text =
            result.data!['content_password'] ?? '';
      } else {
        _showErrorSnackBar('Failed to load credentials: ${result.error}');
      }
    });
  }

  Future<void> _checkConnection() async {
    final result = await AdminService.testConnection();
    setState(() {
      _connectionStatus = result.isSuccess ? 'Connected' : 'Connection Error';
    });
  }

  Future<void> _updateMasterPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final newPassword = _masterPasswordController.text.trim();
    await _updatePassword('admin_master', newPassword, 'Master Password');
  }

  Future<void> _updateContentPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final newPassword = _contentPasswordController.text.trim();
    await _updatePassword('content_password', newPassword, 'Content Password');
  }

  Future<void> _updatePassword(
      String type, String password, String displayName) async {
    setState(() => _isLoading = true);

    try {
      final result = await AdminService.updateAdminPassword(
        passwordType: type,
        newPassword: password,
      );

      if (result.isSuccess && result.data == true) {
        _showSuccessSnackBar('$displayName updated successfully!');
        await _loadCredentials(); // Refresh to verify
      } else {
        _showErrorSnackBar('Failed to update $displayName: ${result.error}');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testPasswordSystem() async {
    setState(() => _isLoading = true);

    final result = await AdminService.testPasswordUpdate();

    setState(() => _isLoading = false);

    if (result.isSuccess && result.data == true) {
      _showSuccessSnackBar('Password system test passed!');
      await _loadCredentials(); // Refresh after test
    } else {
      _showErrorSnackBar('Password system test failed: ${result.error}');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _copyCurrentCredentials() {
    if (_currentCredentials != null) {
      final text = '''Admin Credentials:
Master: ${_currentCredentials!['admin_master'] ?? 'Not loaded'}
Content: ${_currentCredentials!['content_password'] ?? 'Not loaded'}

Generated: ${DateTime.now().toString()}''';

      Clipboard.setData(ClipboardData(text: text));
      _showSuccessSnackBar('Credentials copied to clipboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        actions: [
          if (_connectionStatus != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _connectionStatus == 'Connected'
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _connectionStatus == 'Connected'
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  child: Text(
                    _connectionStatus!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _initializeAdmin,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildCurrentCredentialsCard(),
                    const SizedBox(height: 24),
                    _buildPasswordUpdateCard(),
                    const SizedBox(height: 24),
                    _buildSystemTestCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCurrentCredentialsCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Current Credentials',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: _copyCurrentCredentials,
                  tooltip: 'Copy credentials',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_currentCredentials != null) ...[
              _buildCredentialDisplay(
                'Master Admin',
                _currentCredentials!['admin_master'],
                Icons.admin_panel_settings,
                Colors.red,
              ),
              const SizedBox(height: 12),
              _buildCredentialDisplay(
                'Content Admin',
                _currentCredentials!['content_password'],
                Icons.edit,
                Colors.orange,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_done, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Synced with Google Sheets',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Unable to load credentials from Google Sheets',
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialDisplay(
      String label, String? password, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  password ?? 'Not loaded',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: password != null ? Colors.black87 : Colors.grey,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordUpdateCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit, color: colorScheme.secondary),
                const SizedBox(width: 12),
                Text(
                  'Update Passwords',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _masterPasswordController,
              decoration: const InputDecoration(
                labelText: 'Master Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.admin_panel_settings),
                helperText: 'Full administrative access',
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Password cannot be empty';
                }
                if (value.trim().length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _updateMasterPassword,
                icon: const Icon(Icons.security),
                label: const Text('Update Master Password'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _contentPasswordController,
              decoration: const InputDecoration(
                labelText: 'Content Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit),
                helperText: 'Content management access',
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Password cannot be empty';
                }
                if (value.trim().length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _updateContentPassword,
                icon: const Icon(Icons.edit_note),
                label: const Text('Update Content Password'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemTestCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bug_report, color: colorScheme.tertiary),
                const SizedBox(width: 12),
                Text(
                  'System Testing',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Test the password update system to ensure Google Sheets integration is working properly.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _testPasswordSystem,
                    icon: const Icon(Icons.science),
                    label: const Text('Test Password System'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.tertiary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _checkConnection,
                  icon: const Icon(Icons.wifi_find),
                  label: const Text('Test Connection'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
