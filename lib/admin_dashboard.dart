// admin_dashboard.dart - UPDATED WITH PROPER SESSION MANAGEMENT AND NAVIGATION
import 'package:flutter/material.dart';
import 'admin_service.dart';
import 'admin_password_management_page.dart'; // NEW: Dedicated password management page
import 'devotional_management_page.dart';
import 'theme_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  AdminLevel? _adminLevel;
  String _currentUser = '';
  bool _isLoading = true;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _loadAdminSession();
    _testConnection();
  }

  // UPDATED: Load admin session from SharedPreferences
  Future<void> _loadAdminSession() async {
    final prefs = await SharedPreferences.getInstance();
    final adminLevelString = prefs.getString('admin_level');
    final currentUser = prefs.getString('current_user') ?? 'Admin';
    final isAuth = prefs.getBool('admin_authenticated') ?? false;
    final authTime = prefs.getInt('admin_auth_time') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Check if session is still valid (2 hours)
    if (!isAuth || (now - authTime) >= (2 * 60 * 60 * 1000)) {
      // Session expired, redirect to login
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/admin-login');
      }
      return;
    }

    setState(() {
      if (adminLevelString == 'master') {
        _adminLevel = AdminLevel.master;
      } else if (adminLevelString == 'content') {
        _adminLevel = AdminLevel.content;
      }
      _currentUser = currentUser;
      _isLoading = false;
    });
  }

  // ADDED: Test connection to Google Sheets
  Future<void> _testConnection() async {
    try {
      final result = await AdminService.testConnection();
      setState(() {
        _isConnected = result.isSuccess;
      });
    } catch (e) {
      setState(() {
        _isConnected = false;
      });
    }
  }

  // ADDED: Logout functionality
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('admin_authenticated');
      await prefs.remove('admin_auth_time');
      await prefs.remove('admin_level');
      await prefs.remove('current_user');

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/settings');
      }
    }
  }

  // ADDED: Refresh connection status
  Future<void> _refreshConnection() async {
    setState(() {
      _isLoading = true;
    });

    await _testConnection();

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isConnected
              ? '✅ Connection successful!'
              : '❌ Connection failed'),
          backgroundColor: _isConnected ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Loading admin dashboard...',
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        automaticallyImplyLeading: false, // Remove back button
        actions: [
          // Connection status indicator
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
                  _isConnected ? 'Connected' : 'Offline',
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
              color: _adminLevel == AdminLevel.master
                  ? Colors.red.withOpacity(0.2)
                  : Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _adminLevel == AdminLevel.master ? '👑 Master' : '✏️ Content',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Refresh connection
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshConnection,
            tooltip: 'Refresh Connection',
          ),

          // Logout
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withOpacity(0.1),
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome section
                _buildWelcomeSection(),
                const SizedBox(height: 32),

                // Admin functions grid
                Text(
                  'Admin Functions',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                    children: _buildAdminFunctions(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.admin_panel_settings,
                  color: colorScheme.onPrimary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, $_currentUser!',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_adminLevel?.displayName} Access',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onPrimary.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _adminLevel == AdminLevel.master
                ? 'You have full administrative control over the Lagu Advent app. Manage passwords, content, and system settings.'
                : 'You can contribute devotional content to the Lagu Advent app. Your contributions will be available to all users.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimary.withOpacity(0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAdminFunctions() {
    final functions = <AdminFunction>[
      // Password Management (Master Admin Only)
      if (_adminLevel == AdminLevel.master)
        AdminFunction(
          title: 'Password Management',
          description: 'Update admin passwords globally',
          icon: Icons.security,
          color: Colors.red,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminPasswordManagementPage(),
              ),
            );
          },
          enabled: true,
        ),

      // Devotional Content Management (All Admins)
      AdminFunction(
        title: 'Devotional Content',
        description: 'Manage daily devotional content',
        icon: Icons.book,
        color: Colors.blue,
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
        enabled: _isConnected,
      ),

      // Quick Add Devotional (All Admins)
      AdminFunction(
        title: 'Quick Add Devotional',
        description: 'Add today\'s devotional quickly',
        icon: Icons.add_circle,
        color: Colors.green,
        onTap: () {
          _showQuickAddDevotionalDialog();
        },
        enabled: _isConnected,
      ),

      // Song Collections (Future Feature)
      AdminFunction(
        title: 'Song Collections',
        description: 'Manage song libraries',
        icon: Icons.library_music,
        color: Colors.purple,
        onTap: () {
          _showComingSoonDialog('Song Collection Management');
        },
        enabled: false,
      ),

      // User Analytics (Master Admin Only)
      if (_adminLevel == AdminLevel.master)
        AdminFunction(
          title: 'User Analytics',
          description: 'View app usage statistics',
          icon: Icons.analytics,
          color: Colors.orange,
          onTap: () {
            _showComingSoonDialog('User Analytics');
          },
          enabled: false,
        ),

      // System Settings (Master Admin Only)
      if (_adminLevel == AdminLevel.master)
        AdminFunction(
          title: 'System Settings',
          description: 'Configure app settings',
          icon: Icons.settings,
          color: Colors.indigo,
          onTap: () {
            _showComingSoonDialog('System Settings');
          },
          enabled: false,
        ),

      // Backup & Export (Master Admin Only)
      if (_adminLevel == AdminLevel.master)
        AdminFunction(
          title: 'Backup & Export',
          description: 'Backup and export data',
          icon: Icons.backup,
          color: Colors.teal,
          onTap: () {
            _showComingSoonDialog('Backup & Export');
          },
          enabled: false,
        ),

      // Connection Test (All Admins)
      AdminFunction(
        title: 'Test Connection',
        description: 'Test Google Sheets connection',
        icon: Icons.wifi_find,
        color: Colors.cyan,
        onTap: () {
          _refreshConnection();
        },
        enabled: true,
      ),
    ];

    return functions
        .map((function) => _AdminFunctionCard(function: function))
        .toList();
  }

  void _showQuickAddDevotionalDialog() {
    // Implement quick add devotional dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quick Add Devotional'),
        content: const Text(
            'This will open a simplified form to quickly add today\'s devotional. Would you like to continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DevotionalManagementPage(
                    themeNotifier: ThemeNotifier(),
                  ),
                ),
              );
            },
            child: const Text('Continue'),
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
}

class AdminFunction {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  AdminFunction({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });
}

class _AdminFunctionCard extends StatelessWidget {
  final AdminFunction function;

  const _AdminFunctionCard({required this.function});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: function.enabled ? 4 : 1,
      shadowColor: function.enabled
          ? function.color.withOpacity(0.3)
          : Colors.grey.withOpacity(0.1),
      child: InkWell(
        onTap: function.enabled ? function.onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: function.enabled
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      function.color.withOpacity(0.1),
                      function.color.withOpacity(0.05),
                    ],
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: function.enabled
                      ? function.color.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  function.icon,
                  color: function.enabled ? function.color : Colors.grey,
                  size: 28,
                ),
              ),

              const SizedBox(height: 16),

              // Title
              Text(
                function.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: function.enabled
                      ? colorScheme.onSurface
                      : colorScheme.onSurface.withOpacity(0.5),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8),

              // Description
              Expanded(
                child: Text(
                  function.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: function.enabled
                        ? colorScheme.onSurface.withOpacity(0.7)
                        : colorScheme.onSurface.withOpacity(0.4),
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Status indicator
              if (!function.enabled)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Coming Soon',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Icon(
                      Icons.arrow_forward,
                      color: function.color,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Access',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: function.color,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
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
}
