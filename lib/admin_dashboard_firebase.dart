// admin_dashboard.dart - Firebase Real-time Version
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/auth_service.dart';
import 'services/firebase_service.dart';
import 'services/database_service.dart';
import 'models/admin_model.dart';
import 'devotional_management_page.dart';
import 'theme_notifier.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  AdminLevel? _adminLevel;
  String _currentUserEmail = '';
  String _currentUserName = '';
  bool _isLoading = true;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
    _testConnection();
  }

  /// Load current admin information
  Future<void> _loadAdminInfo() async {
    final admin = await AuthService.getCurrentAdmin();

    setState(() {
      _adminLevel = admin?.level;
      _currentUserEmail = admin?.email ?? '';
      _currentUserName = admin?.displayName ?? '';
      _isLoading = false;
    });
  }

  /// Test Firebase connection
  Future<void> _testConnection() async {
    final result = await FirebaseService.testConnection();
    setState(() {
      _isConnected = result.isSuccess;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isConnected
              ? '✅ Firebase connection successful!'
              : '❌ Firebase connection failed'),
          backgroundColor: _isConnected ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Sign out current admin
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
        Navigator.of(context).pushReplacementNamed('/settings');
      }
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

    return StreamBuilder<User?>(
      // 🔥 REAL-TIME AUTH STATE MONITORING
      stream: AuthService.authStateChanges,
      builder: (context, authSnapshot) {
        // If user signs out, redirect immediately
        if (!authSnapshot.hasData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed('/admin-login');
          });
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Admin Dashboard'),
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            elevation: 0,
            automaticallyImplyLeading: false,
            actions: [
              // Real-time connection status
              StreamBuilder<bool>(
                stream: Stream.periodic(const Duration(seconds: 30)).asyncMap(
                    (_) async =>
                        (await FirebaseService.testConnection()).isSuccess),
                initialData: _isConnected,
                builder: (context, connectionSnapshot) {
                  final connected = connectionSnapshot.data ?? false;
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: connected
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          connected ? Icons.cloud_done : Icons.cloud_off,
                          color: connected ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          connected ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 10,
                            color: connected ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
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
                onPressed: _testConnection,
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
                    // Welcome section with real-time data
                    _buildWelcomeSection(),
                    const SizedBox(height: 32),

                    // Real-time statistics
                    _buildRealTimeStats(),
                    const SizedBox(height: 32),

                    // Admin functions
                    Text(
                      'Firebase Admin Functions',
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
      },
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
                child: Stack(
                  children: [
                    Icon(
                      Icons.admin_panel_settings,
                      color: colorScheme.onPrimary,
                      size: 32,
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${_currentUserName.isNotEmpty ? _currentUserName : _currentUserEmail.split('@').first}!',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_adminLevel?.displayName} • Firebase Auth',
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
                ? 'Firebase provides enterprise-grade security, real-time synchronization, and automatic scaling. You have full administrative control over the Lagu Advent app with instant data updates.'
                : 'Contribute devotional content with Firebase\'s real-time database. Your changes are instantly synchronized across all app instances worldwide.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimary.withOpacity(0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealTimeStats() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      // 🔥 REAL-TIME ACTIVITY MONITORING
      stream: DatabaseService.getActivityLogsStream(limit: 10),
      builder: (context, activitySnapshot) {
        final recentActivities = activitySnapshot.data ?? [];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.analytics,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Real-time Statistics',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Live',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Recent Activities',
                        recentActivities.length.toString(),
                        Icons.history,
                        Colors.blue,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Online Users',
                        '1', // Current user
                        Icons.people,
                        Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Firebase Status',
                        _isConnected ? 'Online' : 'Offline',
                        _isConnected ? Icons.cloud_done : Icons.cloud_off,
                        _isConnected ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  List<Widget> _buildAdminFunctions() {
    final functions = <AdminFunction>[
      // Real-time Devotional Management
      AdminFunction(
        title: 'Devotional Content',
        description: 'Real-time devotional management',
        icon: Icons.book,
        color: Colors.blue,
        onTap: () => _openDevotionalManagement(),
        enabled: true,
      ),

      // Firebase User Management (Master Admin only)
      if (_adminLevel == AdminLevel.master)
        AdminFunction(
          title: 'User Management',
          description: 'Firebase Auth users',
          icon: Icons.people,
          color: Colors.red,
          onTap: () => _openUserManagement(),
          enabled: true,
        ),

      // Real-time Analytics
      AdminFunction(
        title: 'Live Analytics',
        description: 'Real-time usage data',
        icon: Icons.analytics,
        color: Colors.orange,
        onTap: () => _openAnalytics(),
        enabled: true,
      ),

      // Firebase Console Access
      if (_adminLevel == AdminLevel.master)
        AdminFunction(
          title: 'Firebase Console',
          description: 'Direct database access',
          icon: Icons.storage,
          color: Colors.purple,
          onTap: () => _openFirebaseConsole(),
          enabled: true,
        ),

      // Security Rules (Master Admin only)
      if (_adminLevel == AdminLevel.master)
        AdminFunction(
          title: 'Security Rules',
          description: 'Firebase security config',
          icon: Icons.security,
          color: Colors.indigo,
          onTap: () => _openSecurityRules(),
          enabled: true,
        ),

      // Offline Management
      AdminFunction(
        title: 'Offline Support',
        description: 'Automatic Firebase caching',
        icon: Icons.offline_bolt,
        color: Colors.teal,
        onTap: () => _showOfflineInfo(),
        enabled: true,
      ),

      // Real-time Monitoring
      AdminFunction(
        title: 'Live Monitoring',
        description: 'Real-time system health',
        icon: Icons.monitor_heart,
        color: Colors.pink,
        onTap: () => _openMonitoring(),
        enabled: true,
      ),

      // Backup & Sync
      AdminFunction(
        title: 'Cloud Backup',
        description: 'Automatic Firebase backup',
        icon: Icons.cloud_sync,
        color: Colors.cyan,
        onTap: () => _showBackupInfo(),
        enabled: true,
      ),
    ];

    return functions
        .map((function) => _AdminFunctionCard(function: function))
        .toList();
  }

  void _openDevotionalManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DevotionalManagementPage(
          themeNotifier: ThemeNotifier(),
        ),
      ),
    );
  }

  void _openUserManagement() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Firebase User Management'),
        content: const Text(
          'Firebase Authentication provides:\n\n'
          '🔐 Industry-standard security\n'
          '👥 User management console\n'
          '🔄 Automatic session handling\n'
          '📧 Password reset emails\n'
          '📊 Login analytics\n\n'
          'Access via Firebase Console → Authentication',
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

  void _openAnalytics() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _AnalyticsPage(),
      ),
    );
  }

  void _openFirebaseConsole() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Firebase Console'),
        content: const Text(
          'Firebase Console provides:\n\n'
          '📊 Real-time database viewer\n'
          '🔍 Data query tools\n'
          '📈 Performance monitoring\n'
          '🔐 Security rule testing\n'
          '📱 App analytics\n\n'
          'Access at: console.firebase.google.com',
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

  void _openSecurityRules() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Firebase Security Rules'),
        content: const Text(
          'Firebase Security Rules ensure:\n\n'
          '🛡️ Authentication-based access\n'
          '👮 Role-based permissions\n'
          '✅ Data validation\n'
          '🧪 Real-time rule testing\n'
          '📝 Version control\n\n'
          'Configure via Firebase Console → Database → Rules',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Open Console'),
          ),
        ],
      ),
    );
  }

  void _openMonitoring() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Live Monitoring'),
        content: const Text(
          'Firebase provides real-time monitoring:\n\n'
          '⚡ Live connection status\n'
          '📊 Real-time user activity\n'
          '🚨 Automatic error reporting\n'
          '📈 Performance metrics\n'
          '🔔 Alert notifications\n\n'
          'Everything updates automatically!',
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

  void _showOfflineInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Automatic Offline Support'),
        content: const Text(
          'Firebase automatically handles:\n\n'
          '💾 Intelligent data caching\n'
          '📝 Offline write queuing\n'
          '🔄 Auto-sync on reconnect\n'
          '⚡ No manual cache management\n'
          '📱 Works across all devices\n\n'
          'Users can access content even without internet!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Amazing!'),
          ),
        ],
      ),
    );
  }

  void _showBackupInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cloud Backup'),
        content: const Text(
          'Firebase provides automatic backup:\n\n'
          '☁️ Real-time data replication\n'
          '🌍 Global data distribution\n'
          '🔄 Automatic disaster recovery\n'
          '📊 Export capabilities\n'
          '⏰ Point-in-time recovery\n\n'
          'Your data is always safe!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Excellent!'),
          ),
        ],
      ),
    );
  }
}

// Analytics page with real-time data
class _AnalyticsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Analytics'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: DatabaseService.getActivityLogsStream(limit: 50),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final activities = snapshot.data ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final activity = activities[index];
              final timestamp = DateTime.fromMillisecondsSinceEpoch(
                activity['timestamp'] as int,
              );

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getActivityColor(activity['action']),
                    child: Icon(
                      _getActivityIcon(activity['action']),
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  title: Text(activity['action'] ?? 'Unknown'),
                  subtitle: Text(
                    '${activity['user_email'] ?? 'Unknown'} • '
                    '${_formatTime(timestamp)}',
                  ),
                  trailing: Text(
                    _formatTimestamp(timestamp),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getActivityColor(String? action) {
    switch (action) {
      case 'login':
        return Colors.green;
      case 'logout':
        return Colors.orange;
      case 'add_devotional':
        return Colors.blue;
      case 'update_devotional':
        return Colors.purple;
      case 'delete_devotional':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getActivityIcon(String? action) {
    switch (action) {
      case 'login':
        return Icons.login;
      case 'logout':
        return Icons.logout;
      case 'add_devotional':
        return Icons.add;
      case 'update_devotional':
        return Icons.edit;
      case 'delete_devotional':
        return Icons.delete;
      default:
        return Icons.activity;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatTimestamp(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }
}

// Reuse AdminFunction and _AdminFunctionCard from existing code
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
