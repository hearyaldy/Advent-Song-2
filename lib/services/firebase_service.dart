// firebase_service.dart - COMPLETE UPDATED VERSION WITH updateAdminStatus
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/devotional_model.dart';
import '../models/song_model.dart';
import '../models/admin_model.dart';

/// Main Firebase service providing centralized access to all Firebase features
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

  /// Test Firebase connection
  static Future<ServiceResult<bool>> testConnection() async {
    try {
      // Simple database read to test connectivity
      await _settingsRef.child('app_version').once();
      return ServiceResult.success(true);
    } catch (e) {
      return ServiceResult.error('Connection failed: $e');
    }
  }

  // ==================== AUTHENTICATION ====================

  /// Sign in admin with email and password
  static Future<ServiceResult<AdminLevel>> signInAdmin({
    required String email,
    required String password,
  }) async {
    try {
      // Authenticate with Firebase Auth
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        return ServiceResult.error('Authentication failed');
      }

      // Get admin level from database
      final adminLevel = await _getAdminLevel(credential.user!.uid);
      if (adminLevel == null) {
        await _auth.signOut();
        return ServiceResult.error('Not authorized as admin');
      }

      // Log admin login
      await _logAdminActivity('login', {
        'user_id': credential.user!.uid,
        'email': credential.user!.email,
        'level': adminLevel.name,
      });

      return ServiceResult.success(adminLevel);
    } on FirebaseAuthException catch (e) {
      return ServiceResult.error(_getAuthErrorMessage(e.code));
    } catch (e) {
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
          'email': currentUserEmail,
        });
      }

      await _auth.signOut();
      return ServiceResult.success(true);
    } catch (e) {
      return ServiceResult.error('Logout failed: $e');
    }
  }

  /// Get current admin level
  static Future<AdminLevel?> getCurrentAdminLevel() async {
    if (!isAuthenticated) return null;
    return await _getAdminLevel(currentUserId);
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

  /// Get all devotionals stream (for admin management)
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

      devotionals.sort((a, b) => b.date.compareTo(a.date));
      return devotionals;
    });
  }

  /// Add new devotional (Admin only)
  static Future<ServiceResult<bool>> addDevotional(
    DevotionalModel devotional,
  ) async {
    if (!isAuthenticated) {
      return ServiceResult.error('Authentication required');
    }

    try {
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

      return ServiceResult.success(true);
    } catch (e) {
      return ServiceResult.error('Failed to add devotional: $e');
    }
  }

  /// Update devotional (Admin only)
  static Future<ServiceResult<bool>> updateDevotional(
    DevotionalModel devotional,
  ) async {
    if (!isAuthenticated) {
      return ServiceResult.error('Authentication required');
    }

    try {
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

      return ServiceResult.success(true);
    } catch (e) {
      return ServiceResult.error('Failed to update devotional: $e');
    }
  }

  /// Delete devotional (Master Admin only)
  static Future<ServiceResult<bool>> deleteDevotional(
    String devotionalId,
  ) async {
    final hasPermission = await FirebaseService.hasPermission(
      AdminPermission.deleteContent,
    );
    if (!hasPermission) {
      return ServiceResult.error('Master admin access required');
    }

    try {
      await _devotionalsRef.child(devotionalId).remove();

      // Log activity
      await _logAdminActivity('delete_devotional', {
        'devotional_id': devotionalId,
      });

      return ServiceResult.success(true);
    } catch (e) {
      return ServiceResult.error('Failed to delete devotional: $e');
    }
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
          final song = Song.fromJson(Map<String, dynamic>.from(value), id: key);
          songs.add(song);
        }
      });

      // Sort by song number
      songs.sort((a, b) => a.songNumber.compareTo(b.songNumber));
      return songs;
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
    });
  }

  /// Create new admin user (Master Admin only)
  static Future<ServiceResult<bool>> createAdminUser({
    required String email,
    required String password,
    required AdminLevel level,
    required String displayName,
  }) async {
    final hasPermission = await FirebaseService.hasPermission(
      AdminPermission.manageUsers,
    );
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

  /// Update admin status (active/inactive) - Master Admin only
  static Future<ServiceResult<bool>> updateAdminStatus(
    String adminUid,
    bool isActive,
  ) async {
    final hasPermission = await FirebaseService.hasPermission(
      AdminPermission.manageUsers,
    );
    if (!hasPermission) {
      return ServiceResult.error('Master admin access required');
    }

    try {
      await _adminsRef.child(adminUid).update({
        'is_active': isActive,
        'updated_at': ServerValue.timestamp,
        'updated_by': currentUserEmail,
      });

      // Log activity
      await _logAdminActivity('update_admin_status', {
        'target_admin_uid': adminUid,
        'is_active': isActive,
      });

      return ServiceResult.success(true);
    } catch (e) {
      return ServiceResult.error('Failed to update admin status: $e');
    }
  }

  // ==================== ANALYTICS ====================

  /// Log admin activity
  static Future<void> _logAdminActivity(
    String action,
    Map<String, dynamic> data,
  ) async {
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
    } catch (e) {
      debugPrint('Failed to log activity: $e');
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
            (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int),
          );
          return activities;
        });
  }

  // ==================== UTILITY METHODS ====================

  /// Get admin level for user
  static Future<AdminLevel?> _getAdminLevel(String uid) async {
    try {
      final snapshot = await _adminsRef.child(uid).once();
      if (!snapshot.snapshot.exists) return null;

      final data = snapshot.snapshot.value as Map;
      final levelString = data['level'] as String?;

      return AdminLevel.values.firstWhere(
        (level) => level.name == levelString,
        orElse: () => AdminLevel.content,
      );
    } catch (e) {
      debugPrint('Error getting admin level: $e');
      return null;
    }
  }

  /// Get user-friendly auth error messages
  static String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No admin account found with this email';
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
    Map<String, dynamic> settings,
  ) async {
    final hasPermission = await FirebaseService.hasPermission(
      AdminPermission.systemSettings,
    );
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

/// Service result wrapper for better error handling
class ServiceResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  ServiceResult.success(this.data) : error = null, isSuccess = true;

  ServiceResult.error(this.error) : data = null, isSuccess = false;
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
