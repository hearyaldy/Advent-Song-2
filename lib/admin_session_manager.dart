// admin_session_manager.dart - NEW FILE FOR CENTRALIZED SESSION MANAGEMENT
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_service.dart';

class AdminSessionManager {
  static const String _authKey = 'admin_authenticated';
  static const String _timeKey = 'admin_auth_time';
  static const String _levelKey = 'admin_level';
  static const String _userKey = 'current_user';
  static const Duration _sessionTimeout = Duration(hours: 2);

  /// Check if current session is valid
  static Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    final isAuth = prefs.getBool(_authKey) ?? false;
    final authTime = prefs.getInt(_timeKey) ?? 0;

    if (!isAuth) return false;

    final sessionAge = DateTime.now().millisecondsSinceEpoch - authTime;
    return sessionAge < _sessionTimeout.inMilliseconds;
  }

  /// Get current admin level
  static Future<AdminLevel?> getCurrentAdminLevel() async {
    if (!await isSessionValid()) return null;

    final prefs = await SharedPreferences.getInstance();
    final levelString = prefs.getString(_levelKey);

    switch (levelString) {
      case 'master':
        return AdminLevel.master;
      case 'content':
        return AdminLevel.content;
      default:
        return null;
    }
  }

  /// Get current user name
  static Future<String?> getCurrentUser() async {
    if (!await isSessionValid()) return null;

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userKey);
  }

  /// Create new admin session
  static Future<bool> createSession({
    required AdminLevel adminLevel,
    required String userName,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_authKey, true);
    await prefs.setInt(_timeKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.setString(
        _levelKey, adminLevel == AdminLevel.master ? 'master' : 'content');
    await prefs.setString(_userKey, userName);

    return true;
  }

  /// Clear current session
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_authKey);
    await prefs.remove(_timeKey);
    await prefs.remove(_levelKey);
    await prefs.remove(_userKey);
  }

  /// Extend current session (reset timeout)
  static Future<void> extendSession() async {
    if (!await isSessionValid()) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_timeKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Get session info
  static Future<AdminSessionInfo?> getSessionInfo() async {
    if (!await isSessionValid()) return null;

    final prefs = await SharedPreferences.getInstance();
    final authTime = prefs.getInt(_timeKey) ?? 0;
    final levelString = prefs.getString(_levelKey) ?? '';
    final userName = prefs.getString(_userKey) ?? '';

    AdminLevel? level;
    switch (levelString) {
      case 'master':
        level = AdminLevel.master;
        break;
      case 'content':
        level = AdminLevel.content;
        break;
      default:
        return null;
    }

    final sessionAge = DateTime.now().millisecondsSinceEpoch - authTime;
    final timeRemaining = _sessionTimeout.inMilliseconds - sessionAge;

    return AdminSessionInfo(
      adminLevel: level,
      userName: userName,
      sessionStart: DateTime.fromMillisecondsSinceEpoch(authTime),
      timeRemaining: Duration(milliseconds: timeRemaining),
    );
  }

  /// Check if user has specific permission
  static Future<bool> hasPermission(AdminPermission permission) async {
    final level = await getCurrentAdminLevel();
    if (level == null) return false;

    switch (permission) {
      case AdminPermission.managePasswords:
        return level == AdminLevel.master;
      case AdminPermission.manageContent:
        return true; // Both levels can manage content
      case AdminPermission.deleteContent:
        return level == AdminLevel.master;
      case AdminPermission.viewAnalytics:
        return level == AdminLevel.master;
      case AdminPermission.systemSettings:
        return level == AdminLevel.master;
    }
  }
}

/// Admin session information
class AdminSessionInfo {
  final AdminLevel adminLevel;
  final String userName;
  final DateTime sessionStart;
  final Duration timeRemaining;

  AdminSessionInfo({
    required this.adminLevel,
    required this.userName,
    required this.sessionStart,
    required this.timeRemaining,
  });

  bool get isValid => timeRemaining.inMilliseconds > 0;
  bool get isExpiringSoon => timeRemaining.inMinutes < 15;

  String get displayName {
    switch (adminLevel) {
      case AdminLevel.master:
        return 'Master Admin';
      case AdminLevel.content:
        return 'Content Admin';
    }
  }
}

/// Admin permissions enum
enum AdminPermission {
  managePasswords,
  manageContent,
  deleteContent,
  viewAnalytics,
  systemSettings,
}
