// services/firebase_service.dart - COMPLETE VERSION WITH ALL METHODS
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/devotional_model.dart';
import '../models/song_model.dart';
import '../models/admin_model.dart';

/// Complete Firebase service with all required methods
class FirebaseService {
  // Firebase instances
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Database references
  static DatabaseReference get _devotionalsRef => _database.ref('devotionals');
  static DatabaseReference get _songsRef => _database.ref('songs');
  static DatabaseReference get _adminsRef => _database.ref('admins');
  static DatabaseReference get _settingsRef => _database.ref('settings');
  static DatabaseReference get _analyticsRef => _database.ref('analytics');

  // Current user info
  static User? get currentUser => _auth.currentUser;
  static bool get isAuthenticated => currentUser != null;
  static String get currentUserId => currentUser?.uid ?? '';
  static String get currentUserEmail => currentUser?.email ?? '';

  /// Initialize Firebase service (call in main.dart)
  static Future<void> initialize() async {
    try {
      // Enable offline persistence for better performance
      _database.setPersistenceEnabled(true);
      _database.setPersistenceCacheSizeBytes(10000000); // 10MB cache

      // Enable logging in debug mode
      if (kDebugMode) {
        _database.setLoggingEnabled(true);
      }

      debugPrint('🔥 Firebase service initialized successfully');
    } catch (e) {
      debugPrint('❌ Firebase initialization error: $e');
    }
  }

  /// Test Firebase connection with detailed diagnostics
  static Future<ServiceResult<Map<String, dynamic>>> testConnection() async {
    final diagnostics = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'auth_status': 'unknown',
      'database_status': 'unknown',
      'admin_status': 'unknown',
      'user_id': currentUserId,
      'user_email': currentUserEmail,
      'errors': <String>[],
    };

    try {
      // Test 1: Authentication status
      if (isAuthenticated) {
        diagnostics['auth_status'] = 'authenticated';
        debugPrint('✅ Firebase Auth: User authenticated');
      } else {
        diagnostics['auth_status'] = 'not_authenticated';
        diagnostics['errors'].add('User not authenticated');
        debugPrint('❌ Firebase Auth: User not authenticated');
      }

      // Test 2: Database connectivity
      try {
        await _database.ref('.info/connected').once();
        diagnostics['database_status'] = 'connected';
        debugPrint('✅ Firebase Database: Connected');
      } catch (e) {
        diagnostics['database_status'] = 'connection_failed';
        diagnostics['errors'].add('Database connection failed: $e');
        debugPrint('❌ Firebase Database: Connection failed - $e');
      }

      // Test 3: Admin permissions (only if authenticated)
      if (isAuthenticated) {
        try {
          final adminLevel = await _getAdminLevelWithDiagnostics();
          if (adminLevel != null) {
            diagnostics['admin_status'] = 'admin_verified';
            diagnostics['admin_level'] = adminLevel.name;
            debugPrint('✅ Admin Access: Verified as ${adminLevel.name}');
          } else {
            diagnostics['admin_status'] = 'not_admin';
            diagnostics['errors'].add('User is not an admin');
            debugPrint('❌ Admin Access: User is not an admin');
          }
        } catch (e) {
          diagnostics['admin_status'] = 'permission_denied';
          diagnostics['errors'].add('Admin check failed: $e');
          debugPrint('❌ Admin Access: Permission denied - $e');

          // Provide specific guidance for permission errors
          if (e.toString().contains('permission-denied')) {
            diagnostics['errors'].add(
                'Setup required: Add user to /admins in Firebase Database');
            diagnostics['setup_instructions'] = {
              'step1': 'Go to Firebase Console → Realtime Database',
              'step2': 'Add user to /admins/$currentUserId',
              'step3': 'Set level to "master" or "content"',
              'step4': 'Update security rules if needed'
            };
          }
        }
      }

      final hasErrors = (diagnostics['errors'] as List).isNotEmpty;
      return hasErrors
          ? ServiceResult.error('Connection issues found', data: diagnostics)
          : ServiceResult.success(diagnostics);
    } catch (e) {
      diagnostics['errors'].add('Connection test failed: $e');
      return ServiceResult.error('Connection test failed: $e',
          data: diagnostics);
    }
  }

  // ==================== AUTHENTICATION ====================

  /// Sign in admin with enhanced error handling
  static Future<ServiceResult<AdminLevel>> signInAdmin({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔐 Attempting admin login for: $email');

      // Authenticate with Firebase Auth
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        return ServiceResult.error('Authentication failed');
      }

      debugPrint('✅ Firebase Auth successful for: ${credential.user!.email}');

      // Check admin level with enhanced error handling
      final adminLevel = await _getAdminLevelWithDiagnostics();
      if (adminLevel == null) {
        await _auth.signOut();

        // Provide specific guidance
        final setupMessage = '''
Admin setup required for ${credential.user!.email}:

1. Go to Firebase Console → Realtime Database
2. Add this path: /admins/${credential.user!.uid}
3. Add data: {"email": "${credential.user!.email}", "level": "master", "name": "Admin User", "is_active": true}
4. Update security rules if needed
5. Try logging in again

User ID: ${credential.user!.uid}
        ''';

        return ServiceResult.error(setupMessage);
      }

      debugPrint('✅ Admin access verified: ${adminLevel.name}');

      // Log admin login
      await _logAdminActivity('login', {
        'user_id': credential.user!.uid,
        'email': credential.user!.email,
        'level': adminLevel.name,
      });

      return ServiceResult.success(adminLevel);
    } on FirebaseAuthException catch (e) {
      final errorMessage = _getAuthErrorMessage(e.code);
      debugPrint('❌ Firebase Auth error: $errorMessage');
      return ServiceResult.error(errorMessage);
    } catch (e) {
      debugPrint('❌ Login error: $e');
      return ServiceResult.error('Login failed: $e');
    }
  }

  /// Sign out current admin
  static Future<ServiceResult<bool>> signOut() async {
    try {
      // Log admin logout
      if (isAuthenticated) {
        await _logAdminActivity('logout', {
          'user_id': currentUserId,
          'user_email': currentUserEmail,
        });
      }

      await _auth.signOut();
      debugPrint('✅ User signed out successfully');
      return ServiceResult.success(true);
    } catch (e) {
      debugPrint('❌ Sign out error: $e');
      return ServiceResult.error('Logout failed: $e');
    }
  }

  /// Get admin level with detailed diagnostics
  static Future<AdminLevel?> _getAdminLevelWithDiagnostics() async {
    if (!isAuthenticated) {
      debugPrint('❌ Admin check: User not authenticated');
      return null;
    }

    try {
      debugPrint('🔍 Checking admin level for user: $currentUserId');
      debugPrint('🔍 Checking path: /admins/$currentUserId');

      final snapshot = await _adminsRef.child(currentUserId).once();

      if (!snapshot.snapshot.exists) {
        debugPrint('❌ Admin data not found at: /admins/$currentUserId');
        debugPrint('💡 Setup instructions:');
        debugPrint('   1. Go to Firebase Console → Realtime Database');
        debugPrint('   2. Create path: /admins/$currentUserId');
        debugPrint(
            '   3. Add: {"email": "$currentUserEmail", "level": "master", "name": "Admin User"}');
        return null;
      }

      final data = snapshot.snapshot.value as Map;
      final levelString = data['level'] as String?;

      debugPrint('✅ Admin data found: $data');
      debugPrint('✅ Admin level: $levelString');

      return AdminLevel.values.firstWhere(
        (level) => level.name == levelString,
        orElse: () => AdminLevel.content,
      );
    } on FirebaseDatabaseException catch (e) {
      debugPrint('❌ Database error: ${e.message}');
      if (e.code == 'permission-denied') {
        debugPrint('💡 Permission denied - check Firebase security rules');
        debugPrint(
            '💡 Make sure rules allow: auth.uid == \$uid for /admins/\$uid');
      }
      throw e;
    } catch (e) {
      debugPrint('❌ Unexpected error getting admin level: $e');
      throw e;
    }
  }

  /// Get current admin level (public method)
  static Future<AdminLevel?> getCurrentAdminLevel() async {
    try {
      return await _getAdminLevelWithDiagnostics();
    } catch (e) {
      debugPrint('Error getting current admin level: $e');
      return null;
    }
  }

  /// Check if user has specific permission
  static Future<bool> hasPermission(AdminPermission permission) async {
    final adminLevel = await getCurrentAdminLevel();
    if (adminLevel == null) return false;

    switch (permission) {
      case AdminPermission.managePasswords:
      case AdminPermission.manageUsers:
      case AdminPermission.viewAnalytics:
      case AdminPermission.systemSettings:
        return adminLevel == AdminLevel.master;
      case AdminPermission.manageContent:
        return true; // Both levels can manage content
      case AdminPermission.deleteContent:
        return adminLevel == AdminLevel.master;
    }
  }

  // ==================== DEVOTIONALS ====================

  /// Get today's devotional as a stream (real-time updates)
  static Stream<DevotionalModel?> getTodaysDevotionalStream() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return _devotionalsRef.child(today).onValue.map((event) {
      if (!event.snapshot.exists) return null;
      return DevotionalModel.fromFirebase(
        event.snapshot.key!,
        Map<String, dynamic>.from(event.snapshot.value as Map),
      );
    }).handleError((error) {
      debugPrint('❌ Error in devotional stream: $error');
      return null;
    });
  }

  /// Get today's devotional (one-time fetch)
  static Future<ServiceResult<DevotionalModel>> getTodaysDevotional() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      final snapshot = await _devotionalsRef.child(today).once();

      if (snapshot.snapshot.exists) {
        final devotional = DevotionalModel.fromFirebase(
          snapshot.snapshot.key!,
          Map<String, dynamic>.from(snapshot.snapshot.value as Map),
        );
        return ServiceResult.success(devotional);
      }

      // Try to get most recent devotional
      final recentSnapshot =
          await _devotionalsRef.orderByKey().limitToLast(5).once();

      if (recentSnapshot.snapshot.exists) {
        final recentData = recentSnapshot.snapshot.value as Map;
        final latestKey = recentData.keys.last;
        final latestSnapshot = await _devotionalsRef.child(latestKey).once();

        if (latestSnapshot.snapshot.exists) {
          final devotional = DevotionalModel.fromFirebase(
            latestSnapshot.snapshot.key!,
            Map<String, dynamic>.from(latestSnapshot.snapshot.value as Map),
          );
          final updatedDevotional = devotional.copyWith(
            id: today,
            date: today,
            source: 'Recent Devotional',
          );
          return ServiceResult.success(updatedDevotional);
        }
      }

      // Return fallback devotional
      final fallback = _createFallbackDevotional();
      return ServiceResult.success(fallback);
    } catch (e) {
      debugPrint('❌ Error loading devotional: $e');
      return ServiceResult.success(_createFallbackDevotional());
    }
  }

  /// Add new devotional (Admin only) - FIXED: This was missing!
  static Future<ServiceResult<bool>> addDevotional(
      DevotionalModel devotional) async {
    if (!isAuthenticated) {
      return ServiceResult.error('Authentication required');
    }

    try {
      debugPrint('📝 Adding devotional: ${devotional.title}');

      final data = devotional.toFirebaseMap();
      data['added_by'] = currentUserEmail;
      data['added_by_uid'] = currentUserId;
      data['created_at'] = ServerValue.timestamp;
      data['updated_at'] = ServerValue.timestamp;

      await _devotionalsRef.child(devotional.id).set(data);

      // Log activity
      await _logAdminActivity('add_devotional', {
        'devotional_id': devotional.id,
        'title': devotional.title,
      });

      debugPrint('✅ Devotional added successfully: ${devotional.id}');
      return ServiceResult.success(true);
    } catch (e) {
      debugPrint('❌ Error adding devotional: $e');
      return ServiceResult.error('Failed to add devotional: $e');
    }
  }

  /// Update devotional (Admin only) - FIXED: This was missing!
  static Future<ServiceResult<bool>> updateDevotional(
      DevotionalModel devotional) async {
    if (!isAuthenticated) {
      return ServiceResult.error('Authentication required');
    }

    try {
      debugPrint('📝 Updating devotional: ${devotional.title}');

      final data = devotional.toFirebaseMap();
      data['updated_by'] = currentUserEmail;
      data['updated_by_uid'] = currentUserId;
      data['updated_at'] = ServerValue.timestamp;

      await _devotionalsRef.child(devotional.id).update(data);

      // Log activity
      await _logAdminActivity('update_devotional', {
        'devotional_id': devotional.id,
        'title': devotional.title,
      });

      debugPrint('✅ Devotional updated successfully: ${devotional.id}');
      return ServiceResult.success(true);
    } catch (e) {
      debugPrint('❌ Error updating devotional: $e');
      return ServiceResult.error('Failed to update devotional: $e');
    }
  }

  /// Delete devotional (Master Admin only) - FIXED: This was missing!
  static Future<ServiceResult<bool>> deleteDevotional(
      String devotionalId) async {
    final hasPermission =
        await FirebaseService.hasPermission(AdminPermission.deleteContent);
    if (!hasPermission) {
      return ServiceResult.error('Master admin access required');
    }

    try {
      debugPrint('🗑️ Deleting devotional: $devotionalId');

      await _devotionalsRef.child(devotionalId).remove();

      // Log activity
      await _logAdminActivity('delete_devotional', {
        'devotional_id': devotionalId,
      });

      debugPrint('✅ Devotional deleted successfully: $devotionalId');
      return ServiceResult.success(true);
    } catch (e) {
      debugPrint('❌ Error deleting devotional: $e');
      return ServiceResult.error('Failed to delete devotional: $e');
    }
  }

  /// Get all devotionals stream (for admin management) - FIXED: This was missing!
  static Stream<List<DevotionalModel>> getAllDevotionalsStream() {
    return _devotionalsRef.orderByKey().onValue.map((event) {
      if (!event.snapshot.exists) return <DevotionalModel>[];

      final data = event.snapshot.value as Map;
      final devotionals = <DevotionalModel>[];

      data.forEach((key, value) {
        if (value is Map) {
          final devotional = DevotionalModel.fromFirebase(
            key,
            Map<String, dynamic>.from(value),
          );
          devotionals.add(devotional);
        }
      });

      // Sort by date descending
      devotionals.sort((a, b) => b.date.compareTo(a.date));
      return devotionals;
    }).handleError((error) {
      debugPrint('❌ Error in devotionals stream: $error');
      return <DevotionalModel>[];
    });
  }

  // ==================== SONGS ====================

  /// Get songs by collection as stream
  static Stream<List<Song>> getSongsStream(String collectionId) {
    return _songsRef.child(collectionId).onValue.map((event) {
      if (!event.snapshot.exists) return <Song>[];

      final data = event.snapshot.value as Map;
      final songs = <Song>[];

      data.forEach((key, value) {
        if (value is Map) {
          final song = Song.fromJson(
            Map<String, dynamic>.from(value),
            id: key,
          );
          songs.add(song);
        }
      });

      // Sort by song number
      songs.sort((a, b) => a.songNumber.compareTo(b.songNumber));
      return songs;
    }).handleError((error) {
      debugPrint('❌ Error in songs stream: $error');
      return <Song>[];
    });
  }

  /// Search songs across all collections
  static Future<ServiceResult<List<Song>>> searchSongs(String query) async {
    try {
      final allSongs = <Song>[];
      final collections = ['lpmi', 'srd', 'iban', 'pandak'];

      for (final collectionId in collections) {
        final snapshot = await _songsRef.child(collectionId).once();
        if (snapshot.snapshot.exists) {
          final data = snapshot.snapshot.value as Map;

          data.forEach((key, value) {
            if (value is Map) {
              final song = Song.fromJson(
                Map<String, dynamic>.from(value),
                id: key,
              );
              if (song.matchesSearch(query)) {
                allSongs.add(song);
              }
            }
          });
        }
      }

      return ServiceResult.success(allSongs);
    } catch (e) {
      return ServiceResult.error('Search failed: $e');
    }
  }

  /// Add song (Admin only)
  static Future<ServiceResult<bool>> addSong(Song song) async {
    if (!isAuthenticated) {
      return ServiceResult.error('Authentication required');
    }

    try {
      final data = song.toJson();
      data['added_by'] = currentUserEmail;
      data['added_by_uid'] = currentUserId;

      await _songsRef.child(song.collection).child(song.id).set(data);

      // Log activity
      await _logAdminActivity('add_song', {
        'song_id': song.id,
        'title': song.title,
        'collection': song.collection,
      });

      return ServiceResult.success(true);
    } catch (e) {
      return ServiceResult.error('Failed to add song: $e');
    }
  }

  // ==================== ADMIN MANAGEMENT ====================

  /// Get all admins (Master Admin only)
  static Stream<List<AdminModel>> getAdminsStream() {
    return _adminsRef.onValue.map((event) {
      if (!event.snapshot.exists) return <AdminModel>[];

      final data = event.snapshot.value as Map;
      final admins = <AdminModel>[];

      data.forEach((key, value) {
        if (value is Map) {
          final admin = AdminModel.fromFirebase(
            key,
            Map<String, dynamic>.from(value),
          );
          admins.add(admin);
        }
      });

      return admins;
    }).handleError((error) {
      debugPrint('❌ Error in admins stream: $error');
      return <AdminModel>[];
    });
  }

  /// Create new admin user (Master Admin only)
  static Future<ServiceResult<bool>> createAdminUser({
    required String email,
    required String password,
    required AdminLevel level,
    required String displayName,
  }) async {
    final hasPermission =
        await FirebaseService.hasPermission(AdminPermission.manageUsers);
    if (!hasPermission) {
      return ServiceResult.error('Master admin access required');
    }

    try {
      // Create user in Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        return ServiceResult.error('Failed to create user');
      }

      // Add to admins database
      await _adminsRef.child(credential.user!.uid).set({
        'email': email,
        'name': displayName,
        'level': level.name,
        'created_at': ServerValue.timestamp,
        'created_by': currentUserEmail,
        'is_active': true,
      });

      // Log activity
      await _logAdminActivity('create_admin', {
        'new_admin_uid': credential.user!.uid,
        'new_admin_email': email,
        'level': level.name,
      });

      return ServiceResult.success(true);
    } catch (e) {
      return ServiceResult.error('Failed to create admin: $e');
    }
  }

  // ==================== ANALYTICS ====================

  /// Log admin activity with error handling
  static Future<void> _logAdminActivity(
      String action, Map<String, dynamic> data) async {
    if (!isAuthenticated) return;

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _analyticsRef.child('admin_activities').push().set({
        'action': action,
        'user_id': currentUserId,
        'user_email': currentUserEmail,
        'timestamp': timestamp,
        'data': data,
      });
      debugPrint('📊 Activity logged: $action');
    } catch (e) {
      debugPrint('❌ Failed to log activity: $e');
      // Don't throw - logging is not critical
    }
  }

  /// Get admin activity logs (Master Admin only)
  static Stream<List<Map<String, dynamic>>> getAdminActivityStream() {
    return _analyticsRef
        .child('admin_activities')
        .orderByChild('timestamp')
        .limitToLast(100)
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return <Map<String, dynamic>>[];

      final data = event.snapshot.value as Map;
      final activities = <Map<String, dynamic>>[];

      data.forEach((key, value) {
        if (value is Map) {
          activities.add(Map<String, dynamic>.from(value));
        }
      });

      // Sort by timestamp descending
      activities.sort(
          (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
      return activities;
    }).handleError((error) {
      debugPrint('❌ Error in activity stream: $error');
      return <Map<String, dynamic>>[];
    });
  }

  // ==================== UTILITY METHODS ====================

  /// Get user-friendly auth error messages
  static String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No admin account found with this email address';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This admin account has been disabled';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      default:
        return 'Authentication failed: $code';
    }
  }

  /// Get app settings
  static Future<Map<String, dynamic>> getAppSettings() async {
    try {
      final snapshot = await _settingsRef.once();
      if (snapshot.snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.snapshot.value as Map);
      }
      return {};
    } catch (e) {
      debugPrint('Error loading app settings: $e');
      return {};
    }
  }

  /// Update app settings (Master Admin only)
  static Future<ServiceResult<bool>> updateAppSettings(
      Map<String, dynamic> settings) async {
    final hasPermission =
        await FirebaseService.hasPermission(AdminPermission.systemSettings);
    if (!hasPermission) {
      return ServiceResult.error('Master admin access required');
    }

    try {
      await _settingsRef.update(settings);
      return ServiceResult.success(true);
    } catch (e) {
      return ServiceResult.error('Failed to update settings: $e');
    }
  }

  /// Create fallback devotional
  static DevotionalModel _createFallbackDevotional() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return DevotionalModel(
      id: 'fallback_${DateTime.now().millisecondsSinceEpoch}',
      date: today,
      title: 'God\'s Faithfulness',
      content:
          'Even when technology fails, God\'s love remains constant. His faithfulness endures through every season. Take this moment to reflect on His goodness and find peace in His presence.',
      verse:
          'Great is your faithfulness, O Lord; your mercies are new every morning.',
      reference: 'Lamentations 3:22-23',
      author: 'Lagu Advent',
      source: 'Emergency Fallback',
    );
  }
}

/// Enhanced service result wrapper
class ServiceResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;
  final Map<String, dynamic>? diagnostics;

  ServiceResult.success(this.data, {this.diagnostics})
      : error = null,
        isSuccess = true;

  ServiceResult.error(this.error, {this.data, this.diagnostics})
      : isSuccess = false;
}

/// Admin permissions enum
enum AdminPermission {
  managePasswords,
  manageContent,
  deleteContent,
  manageUsers,
  viewAnalytics,
  systemSettings,
}
