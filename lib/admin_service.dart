// Production Admin Service - Clean, optimized, and production-ready
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing admin credentials and Google Sheets integration
class AdminService {
  // Configuration
  static const String _scriptUrl =
      'https://script.google.com/macros/s/AKfycbzD4y9TW9ldAxJ-lhHOR4C1esrutbjjXEhI5KB6OyA8GA0AgtkALfetGRTlO5KW3vZx/exec';
  static const String _csvUrl =
      'https://docs.google.com/spreadsheets/d/1E6GVXX3dHpGsohUg5e7qC9jZwRhMvNdmelHQMQ8SWZ8/export?format=csv&gid=887869470';
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const Duration _cacheTimeout = Duration(minutes: 5);

  /// Test connection to Google Apps Script
  static Future<ServiceResult<Map<String, dynamic>>> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse(_scriptUrl),
        headers: {'User-Agent': 'LaguAdvent/1.0'},
      ).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ServiceResult.success(data);
      } else {
        return ServiceResult.error(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      return ServiceResult.error('Connection failed: $e');
    }
  }

  /// Get admin credentials from Google Sheets
  static Future<ServiceResult<Map<String, String>>>
      getAdminCredentials() async {
    try {
      // Try cache first
      final cached = await _getCachedCredentials();
      if (cached != null) {
        return ServiceResult.success(cached);
      }

      // Fetch from Google Sheets
      final response = await http.get(
        Uri.parse(_csvUrl),
        headers: {'User-Agent': 'LaguAdvent/1.0'},
      ).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final credentials = _parseCredentialsCSV(response.body);
        if (credentials.isNotEmpty) {
          await _cacheCredentials(credentials);
          return ServiceResult.success(credentials);
        } else {
          return ServiceResult.error('No credentials found in sheet');
        }
      } else {
        return ServiceResult.error(
            'Failed to fetch credentials: HTTP ${response.statusCode}');
      }
    } catch (e) {
      return ServiceResult.error('Error loading credentials: $e');
    }
  }

  /// Update admin password
  static Future<ServiceResult<bool>> updateAdminPassword({
    required String passwordType,
    required String newPassword,
    String updatedBy = 'Admin Panel',
  }) async {
    try {
      if (passwordType.isEmpty || newPassword.isEmpty) {
        return ServiceResult.error(
            'Password type and new password are required');
      }

      final uri = Uri.parse(_scriptUrl).replace(queryParameters: {
        'action': 'updatePassword',
        'passwordType': passwordType,
        'newPassword': newPassword,
        'updatedBy': updatedBy,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      });

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'LaguAdvent/1.0',
          'Accept': 'application/json',
        },
      ).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final result = json.decode(response.body);

        if (result['success'] == true) {
          // Wait for Google Sheets sync
          await Future.delayed(const Duration(seconds: 2));

          // Clear cache to force fresh data on next read
          await _clearCredentialsCache();

          // Verify the update
          final verified =
              await _verifyPasswordUpdate(passwordType, newPassword);
          return ServiceResult.success(verified);
        } else {
          return ServiceResult.error(result['error'] ?? 'Update failed');
        }
      } else {
        return ServiceResult.error('HTTP ${response.statusCode}');
      }
    } catch (e) {
      return ServiceResult.error('Password update failed: $e');
    }
  }

  /// Validate admin credentials
  static Future<ServiceResult<AdminLevel?>> validateCredentials({
    required String password,
  }) async {
    final credentialsResult = await getAdminCredentials();

    if (!credentialsResult.isSuccess) {
      return ServiceResult.error(credentialsResult.error!);
    }

    final credentials = credentialsResult.data!;

    if (credentials['admin_master'] == password) {
      return ServiceResult.success(AdminLevel.master);
    } else if (credentials['content_password'] == password) {
      return ServiceResult.success(AdminLevel.content);
    } else {
      return ServiceResult.success(null);
    }
  }

  /// Test password update functionality
  static Future<ServiceResult<bool>> testPasswordUpdate() async {
    try {
      final uri = Uri.parse(_scriptUrl).replace(queryParameters: {
        'action': 'testUpdate',
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      });

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'LaguAdvent/1.0',
          'Accept': 'application/json',
        },
      ).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return ServiceResult.success(result['success'] == true);
      }

      return ServiceResult.error('Test failed: HTTP ${response.statusCode}');
    } catch (e) {
      return ServiceResult.error('Test failed: $e');
    }
  }

  // Private helper methods
  static Future<bool> _verifyPasswordUpdate(
      String passwordType, String expectedPassword) async {
    final credentialsResult = await getAdminCredentials();
    if (!credentialsResult.isSuccess) return false;

    final credentials = credentialsResult.data!;
    return credentials[passwordType] == expectedPassword;
  }

  static Map<String, String> _parseCredentialsCSV(String csvContent) {
    final credentials = <String, String>{};

    try {
      final lines = csvContent
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();

      for (int i = 1; i < lines.length; i++) {
        // Skip header
        final parts = _parseCSVLine(lines[i]);
        if (parts.length >= 2) {
          final adminType = parts[0].replaceAll('"', '').trim();
          final password = parts[1].replaceAll('"', '').trim();

          if (adminType.isNotEmpty && password.isNotEmpty) {
            credentials[adminType] = password;
          }
        }
      }
    } catch (e) {
      // Return empty map on parsing error
    }

    return credentials;
  }

  static List<String> _parseCSVLine(String line) {
    final values = <String>[];
    bool inQuotes = false;
    String currentValue = '';

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        values.add(currentValue.trim());
        currentValue = '';
      } else {
        currentValue += char;
      }
    }

    if (currentValue.isNotEmpty) {
      values.add(currentValue.trim());
    }

    return values;
  }

  // Cache management
  static Future<void> _cacheCredentials(Map<String, String> credentials) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_credentials', json.encode(credentials));
      await prefs.setString(
          'admin_credentials_time', DateTime.now().toIso8601String());
    } catch (e) {
      // Silently fail cache operations
    }
  }

  static Future<Map<String, String>?> _getCachedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final credentialsJson = prefs.getString('admin_credentials');
      final cacheTime = prefs.getString('admin_credentials_time');

      if (credentialsJson != null && cacheTime != null) {
        final cached = DateTime.parse(cacheTime);
        final age = DateTime.now().difference(cached);

        if (age < _cacheTimeout) {
          return Map<String, String>.from(json.decode(credentialsJson));
        }
      }
    } catch (e) {
      // Return null on any cache error
    }

    return null;
  }

  static Future<void> _clearCredentialsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('admin_credentials');
      await prefs.remove('admin_credentials_time');
    } catch (e) {
      // Silently fail cache operations
    }
  }
}

/// Service result wrapper for better error handling
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

/// Admin access levels
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
  bool get canManageContent => true; // Both levels can manage content
}
