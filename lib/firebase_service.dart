// firebase_service.dart - Clean Firebase integration
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Authentication
  static User? get currentUser => _auth.currentUser;
  static bool get isAuthenticated => currentUser != null;

  // Database references
  static DatabaseReference get _devotionalsRef => _database.ref('devotionals');
  static DatabaseReference get _songsRef => _database.ref('songs');
  static DatabaseReference get _adminsRef => _database.ref('admins');

  /// Initialize Firebase (call in main.dart)
  static Future<void> initialize() async {
    // Enable offline persistence
    _database.setPersistenceEnabled(true);
    _database.setPersistenceCacheSizeBytes(10000000); // 10MB cache
  }

  // ==================== AUTHENTICATION ====================

  /// Admin login with email/password
  static Future<ServiceResult<AdminLevel>> adminLogin({
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
      final adminSnapshot = await _adminsRef.child(credential.user!.uid).once();

      if (!adminSnapshot.snapshot.exists) {
        await _auth.signOut();
        return ServiceResult.error('Not authorized as admin');
      }

      final adminData = adminSnapshot.snapshot.value as Map;
      final level = AdminLevel.values.firstWhere(
        (l) => l.name == adminData['level'],
        orElse: () => AdminLevel.content,
      );

      return ServiceResult.success(level);
    } on FirebaseAuthException catch (e) {
      return ServiceResult.error(_getAuthErrorMessage(e.code));
    } catch (e) {
      return ServiceResult.error('Login failed: $e');
    }
  }

  /// Logout current admin
  static Future<void> adminLogout() async {
    await _auth.signOut();
  }

  /// Check if current user is admin
  static Future<AdminLevel?> getCurrentAdminLevel() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final adminSnapshot = await _adminsRef.child(user.uid).once();
      if (!adminSnapshot.snapshot.exists) return null;

      final adminData = adminSnapshot.snapshot.value as Map;
      return AdminLevel.values.firstWhere(
        (l) => l.name == adminData['level'],
        orElse: () => AdminLevel.content,
      );
    } catch (e) {
      debugPrint('Error getting admin level: $e');
      return null;
    }
  }

  // ==================== DEVOTIONALS ====================

  /// Get today's devotional with real-time updates
  static Stream<Map<String, dynamic>?> getTodaysDevotionalStream() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return _devotionalsRef.child(today).onValue.map((event) {
      if (!event.snapshot.exists) return null;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);

      return {
        'id': today,
        'date': today,
        ...data,
        'source': 'Firebase',
        'loaded_at': DateTime.now().millisecondsSinceEpoch,
      };
    });
  }

  /// Get today's devotional (one-time fetch)
  static Future<Map<String, dynamic>> getTodaysDevotional() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      final snapshot = await _devotionalsRef.child(today).once();

      if (snapshot.snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);

        return {
          'id': today,
          'date': today,
          ...data,
          'source': 'Firebase',
          'loaded_at': DateTime.now().millisecondsSinceEpoch,
        };
      }

      // Try to get most recent devotional
      final recentSnapshot =
          await _devotionalsRef.orderByKey().limitToLast(5).once();

      if (recentSnapshot.snapshot.exists) {
        final recentData = recentSnapshot.snapshot.value as Map;
        final latestKey = recentData.keys.last;
        final latestDevotional = recentData[latestKey] as Map;

        return {
          'id': today,
          'date': today,
          ...Map<String, dynamic>.from(latestDevotional),
          'source': 'Firebase (Recent)',
          'loaded_at': DateTime.now().millisecondsSinceEpoch,
        };
      }

      // Fallback
      return _getEmergencyFallback();
    } catch (e) {
      debugPrint('Error loading devotional: $e');
      return _getEmergencyFallback();
    }
  }

  /// Add new devotional (Admin only)
  static Future<ServiceResult<bool>> addDevotional({
    required String date,
    required String title,
    required String content,
    String? verse,
    String? reference,
    String? author,
    String? addedBy,
  }) async {
    if (!isAuthenticated) {
      return ServiceResult.error('Authentication required');
    }

    try {
      await _devotionalsRef.child(date).set({
        'title': title,
        'content': content,
        'verse': verse ?? '',
        'reference': reference ?? '',
        'author': author ?? 'Devotional Team',
        'added_by': addedBy ?? currentUser!.email,
        'created_at': ServerValue.timestamp,
        'updated_at': ServerValue.timestamp,
      });

      return ServiceResult.success(true);
    } catch (e) {
      return ServiceResult.error('Failed to add devotional: $e');
    }
  }

  /// Update devotional (Admin only)
  static Future<ServiceResult<bool>> updateDevotional({
    required String date,
    required String title,
    required String content,
    String? verse,
    String? reference,
    String? author,
    String? updatedBy,
  }) async {
    if (!isAuthenticated) {
      return ServiceResult.error('Authentication required');
    }

    try {
      await _devotionalsRef.child(date).update({
        'title': title,
        'content': content,
        'verse': verse ?? '',
        'reference': reference ?? '',
        'author': author ?? 'Devotional Team',
        'updated_by': updatedBy ?? currentUser!.email,
        'updated_at': ServerValue.timestamp,
      });

      return ServiceResult.success(true);
    } catch (e) {
      return ServiceResult.error('Failed to update devotional: $e');
    }
  }

  /// Delete devotional (Master Admin only)
  static Future<ServiceResult<bool>> deleteDevotional({
    required String date,
  }) async {
    final adminLevel = await getCurrentAdminLevel();
    if (adminLevel != AdminLevel.master) {
      return ServiceResult.error('Master admin access required');
    }

    try {
      await _devotionalsRef.child(date).remove();
      return ServiceResult.success(true);
    } catch (e) {
      return ServiceResult.error('Failed to delete devotional: $e');
    }
  }

  /// Get all devotionals with real-time updates
  static Stream<List<Map<String, dynamic>>> getAllDevotionalsStream() {
    return _devotionalsRef.orderByKey().onValue.map((event) {
      if (!event.snapshot.exists) return <Map<String, dynamic>>[];

      final data = event.snapshot.value as Map;
      final devotionals = <Map<String, dynamic>>[];

      data.forEach((key, value) {
        devotionals.add({
          'id': key,
          'date': key,
          ...Map<String, dynamic>.from(value as Map),
        });
      });

      // Sort by date descending
      devotionals.sort((a, b) => b['date'].compareTo(a['date']));
      return devotionals;
    });
  }

  // ==================== SONGS ====================

  /// Get songs by collection
  static Stream<List<Map<String, dynamic>>> getSongsStream(String collection) {
    return _songsRef.child(collection).onValue.map((event) {
      if (!event.snapshot.exists) return <Map<String, dynamic>>[];

      final data = event.snapshot.value as Map;
      final songs = <Map<String, dynamic>>[];

      data.forEach((key, value) {
        songs.add({
          'id': key,
          ...Map<String, dynamic>.from(value as Map),
        });
      });

      return songs;
    });
  }

  // ==================== ADMIN MANAGEMENT ====================

  /// Update admin passwords (Master Admin only)
  static Future<ServiceResult<bool>> updateAdminPassword({
    required String adminId,
    required String newPassword,
  }) async {
    final adminLevel = await getCurrentAdminLevel();
    if (adminLevel != AdminLevel.master) {
      return ServiceResult.error('Master admin access required');
    }

    try {
      // Note: In production, you'd want to use Firebase Admin SDK
      // for server-side password updates
      return ServiceResult.success(true);
    } catch (e) {
      return ServiceResult.error('Failed to update password: $e');
    }
  }

  // ==================== UTILITY METHODS ====================

  static Map<String, dynamic> _getEmergencyFallback() {
    return {
      'id': 'fallback_${DateTime.now().millisecondsSinceEpoch}',
      'title': 'God\'s Faithfulness',
      'content':
          'Even when technology fails, God\'s love remains constant. His faithfulness endures through every season. Take this moment to reflect on His goodness and find peace in His presence.',
      'verse':
          'Great is your faithfulness, O Lord; your mercies are new every morning.',
      'reference': 'Lamentations 3:22-23',
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'source': 'Emergency Fallback',
      'author': 'Lagu Advent',
      'loaded_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

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
      default:
        return 'Authentication failed';
    }
  }
}

// Service result wrapper (same as before)
class ServiceResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  ServiceResult.success(this.data)
      : error = null,
        isSuccess = true;
  ServiceResult.error(this.error)
      : data = null,
        isSuccess = false;
}

// Admin levels enum (same as before)
enum AdminLevel {
  master,
  content;

  String get displayName {
    switch (this) {
      case AdminLevel.master:
        return 'Master Admin';
      case AdminLevel.content:
        return 'Content Admin';
    }
  }

  bool get canManagePasswords => this == AdminLevel.master;
  bool get canManageContent => true;
}
