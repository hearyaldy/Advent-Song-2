// auth_service.dart - FIXED VERSION
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/admin_model.dart'; // ✅ FIXED: Import AdminModel
import 'firebase_service.dart';

/// Authentication service providing clean interface for auth operations
class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream for auth state changes
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static Stream<User?> get userChanges => _auth.userChanges();

  // Current user info
  static User? get currentUser => _auth.currentUser;
  static bool get isSignedIn => currentUser != null;
  static String get currentUserId => currentUser?.uid ?? '';
  static String get currentUserEmail => currentUser?.email ?? '';
  static String get currentUserDisplayName => currentUser?.displayName ?? '';

  /// Initialize auth service
  static Future<void> initialize() async {
    try {
      // Set up auth state persistence
      await _auth.setPersistence(Persistence.LOCAL);

      // Listen for auth state changes
      _auth.authStateChanges().listen((User? user) {
        if (user != null) {
          debugPrint('🔐 User signed in: ${user.email}');
        } else {
          debugPrint('🔐 User signed out');
        }
      });

      debugPrint('🔐 Auth service initialized');
    } catch (e) {
      debugPrint('❌ Auth service initialization error: $e');
    }
  }

  // ==================== ADMIN AUTHENTICATION ====================

  /// Sign in admin with email and password
  static Future<AuthResult> signInAdmin({
    required String email,
    required String password,
  }) async {
    try {
      // Validate input
      if (email.isEmpty || password.isEmpty) {
        return AuthResult.error('Email and password are required');
      }

      if (!_isValidEmail(email)) {
        return AuthResult.error('Please enter a valid email address');
      }

      // Sign in with Firebase Auth
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user == null) {
        return AuthResult.error('Authentication failed');
      }

      // Verify admin status
      final adminLevel = await FirebaseService.getCurrentAdminLevel();
      if (adminLevel == null) {
        await signOut();
        return AuthResult.error('Access denied: Not an admin user');
      }

      // ✅ FIXED: Create AdminModel instead of AdminUser
      final adminModel = AdminModel(
        uid: credential.user!.uid,
        email: credential.user!.email ?? '',
        name: credential.user!.displayName ?? email.split('@').first,
        level: adminLevel,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
        isActive: true,
      );

      return AuthResult.success(adminModel);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Login failed: $e');
    }
  }

  /// Sign out current user
  static Future<AuthResult> signOut() async {
    try {
      await _auth.signOut();
      return AuthResult.success(null);
    } catch (e) {
      return AuthResult.error('Sign out failed: $e');
    }
  }

  /// Check if user is admin
  static Future<bool> isAdmin() async {
    if (!isSignedIn) return false;
    final adminLevel = await FirebaseService.getCurrentAdminLevel();
    return adminLevel != null;
  }

  /// Get current admin info
  static Future<AdminModel?> getCurrentAdmin() async {
    if (!isSignedIn) return null;

    try {
      final adminLevel = await FirebaseService.getCurrentAdminLevel();
      if (adminLevel == null) return null;

      // ✅ FIXED: Return AdminModel instead of AdminUser
      return AdminModel(
        uid: currentUserId,
        email: currentUserEmail,
        name: currentUserDisplayName.isNotEmpty
            ? currentUserDisplayName
            : currentUserEmail.split('@').first,
        level: adminLevel,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
        isActive: true,
      );
    } catch (e) {
      debugPrint('Error getting admin info: $e');
      return null;
    }
  }

  // ==================== PASSWORD MANAGEMENT ====================

  /// Send password reset email
  static Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      if (!_isValidEmail(email)) {
        return AuthResult.error('Please enter a valid email address');
      }

      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Failed to send reset email: $e');
    }
  }

  /// Update password for current user
  static Future<AuthResult> updatePassword(String newPassword) async {
    try {
      if (!isSignedIn) {
        return AuthResult.error('User not signed in');
      }

      if (newPassword.length < 6) {
        return AuthResult.error('Password must be at least 6 characters');
      }

      await currentUser!.updatePassword(newPassword);
      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Failed to update password: $e');
    }
  }

  /// Reauthenticate user (required before sensitive operations)
  static Future<AuthResult> reauthenticate(String password) async {
    try {
      if (!isSignedIn) {
        return AuthResult.error('User not signed in');
      }

      final credential = EmailAuthProvider.credential(
        email: currentUserEmail,
        password: password,
      );

      await currentUser!.reauthenticateWithCredential(credential);
      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Reauthentication failed: $e');
    }
  }

  // ==================== USER MANAGEMENT (Master Admin Only) ====================

  /// Create new admin user (requires master admin)
  static Future<AuthResult> createAdminUser({
    required String email,
    required String password,
    required String displayName,
    required AdminLevel level,
  }) async {
    try {
      // Check permissions - using FirebaseService method
      final currentAdminLevel = await getCurrentAdmin();
      if (currentAdminLevel?.level != AdminLevel.master) {
        return AuthResult.error('Master admin access required');
      }

      // Validate input
      if (!_isValidEmail(email)) {
        return AuthResult.error('Please enter a valid email address');
      }

      if (password.length < 6) {
        return AuthResult.error('Password must be at least 6 characters');
      }

      if (displayName.trim().isEmpty) {
        return AuthResult.error('Display name is required');
      }

      // Use Firebase service to create user
      final result = await FirebaseService.createAdminUser(
        email: email.trim(),
        password: password,
        level: level,
        displayName: displayName.trim(),
      );

      if (result.isSuccess) {
        return AuthResult.success(null);
      } else {
        return AuthResult.error(result.error ?? 'Failed to create user');
      }
    } catch (e) {
      return AuthResult.error('User creation failed: $e');
    }
  }

  // ==================== ACCOUNT MANAGEMENT ====================

  /// Update user profile
  static Future<AuthResult> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      if (!isSignedIn) {
        return AuthResult.error('User not signed in');
      }

      await currentUser!.updateDisplayName(displayName);
      if (photoURL != null) {
        await currentUser!.updatePhotoURL(photoURL);
      }

      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Profile update failed: $e');
    }
  }

  /// Update email address
  /// ✅ FIXED: Use verifyBeforeUpdateEmail instead of deprecated updateEmail
  static Future<AuthResult> updateEmail(String newEmail) async {
    try {
      if (!isSignedIn) {
        return AuthResult.error('User not signed in');
      }

      if (!_isValidEmail(newEmail)) {
        return AuthResult.error('Please enter a valid email address');
      }

      // ✅ FIXED: Use the new non-deprecated method
      await currentUser!.verifyBeforeUpdateEmail(newEmail.trim());
      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Email update failed: $e');
    }
  }

  /// Delete current user account
  static Future<AuthResult> deleteAccount() async {
    try {
      if (!isSignedIn) {
        return AuthResult.error('User not signed in');
      }

      await currentUser!.delete();
      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getAuthErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Account deletion failed: $e');
    }
  }

  // ==================== VALIDATION & UTILITIES ====================

  /// Validate email format
  static bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  /// Get user-friendly error messages
  static String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email address';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection';
      case 'email-already-in-use':
        return 'An account already exists with this email address';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password';
      case 'operation-not-allowed':
        return 'This operation is not allowed';
      case 'invalid-credential':
        return 'The provided credentials are invalid';
      case 'credential-already-in-use':
        return 'This credential is already associated with another account';
      case 'requires-recent-login':
        return 'Please sign in again to continue';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method';
      default:
        return 'Authentication error: ${e.message ?? e.code}';
    }
  }

  // ==================== SESSION MANAGEMENT ====================

  /// Check if session is still valid
  static Future<bool> isSessionValid() async {
    if (!isSignedIn) return false;

    try {
      // Refresh the current user token to check if it's still valid
      await currentUser!.getIdToken(true);
      return true;
    } catch (e) {
      debugPrint('Session validation failed: $e');
      return false;
    }
  }

  /// Get session info
  static AuthSessionInfo? getSessionInfo() {
    if (!isSignedIn) return null;

    final user = currentUser!;
    return AuthSessionInfo(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? '',
      photoURL: user.photoURL,
      emailVerified: user.emailVerified,
      creationTime: user.metadata.creationTime,
      lastSignInTime: user.metadata.lastSignInTime,
      isAnonymous: user.isAnonymous,
    );
  }

  /// Force token refresh
  static Future<String?> refreshToken() async {
    if (!isSignedIn) return null;

    try {
      return await currentUser!.getIdToken(true);
    } catch (e) {
      debugPrint('Token refresh failed: $e');
      return null;
    }
  }

  // ==================== DEBUGGING & MONITORING ====================

  /// Get detailed auth state for debugging
  static Map<String, dynamic> getDebugInfo() {
    return {
      'is_signed_in': isSignedIn,
      'current_user_id': currentUserId,
      'current_user_email': currentUserEmail,
      'current_user_display_name': currentUserDisplayName,
      'auth_state': currentUser?.toString() ?? 'null',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}

/// Authentication result wrapper
/// ✅ FIXED: Use AdminModel instead of AdminUser
class AuthResult {
  final AdminModel? adminUser;
  final String? error;
  final bool isSuccess;

  AuthResult.success(this.adminUser)
      : error = null,
        isSuccess = true;

  AuthResult.error(this.error)
      : adminUser = null,
        isSuccess = false;
}

/// Session information
class AuthSessionInfo {
  final String uid;
  final String email;
  final String displayName;
  final String? photoURL;
  final bool emailVerified;
  final DateTime? creationTime;
  final DateTime? lastSignInTime;
  final bool isAnonymous;

  AuthSessionInfo({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoURL,
    required this.emailVerified,
    this.creationTime,
    this.lastSignInTime,
    required this.isAnonymous,
  });

  @override
  String toString() => 'AuthSessionInfo(uid: $uid, email: $email)';
}
