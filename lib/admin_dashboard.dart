// Fixed Admin Dashboard - Complete and error-free
import 'package:flutter/material.dart';
import 'admin_service.dart';
import 'admin_page.dart';
// import 'devotional_management_page.dart'; // Uncomment when you add the devotional page

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  AdminLevel? _adminLevel;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdminLevel();
  }

  Future<void> _loadAdminLevel() async {
    // You might want to store the admin level after login
    // For now, we'll assume master level access
    setState(() {
      _adminLevel = AdminLevel.master;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _adminLevel?.displayName ?? 'Admin',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
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
                      'Welcome Back!',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
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
            'Manage your Lagu Advent app with full administrative control. Access password management, devotional content, and system settings.',
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
      AdminFunction(
        title: 'Password Management',
        description: 'Update admin passwords and credentials',
        icon: Icons.security,
        color: Colors.red,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AdminPage()),
          );
        },
        enabled: _adminLevel?.canManagePasswords ?? false,
      ),
      AdminFunction(
        title: 'Devotional Content',
        description: 'Manage daily devotional content',
        icon: Icons.book,
        color: Colors.blue,
        onTap: () {
          // TODO: Uncomment when DevotionalManagementPage is added
          _showComingSoonDialog('Devotional Content Management');

          // Navigator.push(
          //   context,
          //   MaterialPageRoute(builder: (context) => const DevotionalManagementPage()),
          // );
        },
        enabled: _adminLevel?.canManageContent ?? false,
      ),
      AdminFunction(
        title: 'Song Collections',
        description: 'Manage song libraries and collections',
        icon: Icons.library_music,
        color: Colors.green,
        onTap: () {
          _showComingSoonDialog('Song Collection Management');
        },
        enabled: true,
      ),
      AdminFunction(
        title: 'User Analytics',
        description: 'View app usage and statistics',
        icon: Icons.analytics,
        color: Colors.purple,
        onTap: () {
          _showComingSoonDialog('User Analytics');
        },
        enabled: true,
      ),
      AdminFunction(
        title: 'System Settings',
        description: 'Configure app settings and preferences',
        icon: Icons.settings,
        color: Colors.orange,
        onTap: () {
          _showComingSoonDialog('System Settings');
        },
        enabled: _adminLevel == AdminLevel.master,
      ),
      AdminFunction(
        title: 'Backup & Export',
        description: 'Backup data and export content',
        icon: Icons.backup,
        color: Colors.teal,
        onTap: () {
          _showComingSoonDialog('Backup & Export');
        },
        enabled: _adminLevel == AdminLevel.master,
      ),
    ];

    return functions
        .map((function) => _AdminFunctionCard(function: function))
        .toList();
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
                    'Restricted',
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
