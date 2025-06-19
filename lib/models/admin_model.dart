// lib/models/admin_model.dart
class AdminModel {
  final String uid;
  final String email;
  final String name;
  final AdminLevel level;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final bool isActive;

  AdminModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.level,
    required this.createdAt,
    this.lastLoginAt,
    this.isActive = true,
  });

  /// Create AdminModel from Firebase data
  factory AdminModel.fromFirebase(String uid, Map<String, dynamic> data) {
    return AdminModel(
      uid: uid,
      email: data['email']?.toString() ?? '',
      name: data['name']?.toString() ?? 'Admin User',
      level: data['level']?.toString() == 'master'
          ? AdminLevel.master
          : AdminLevel.content,
      createdAt: data['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['created_at'] as int)
          : DateTime.now(),
      lastLoginAt: data['last_login_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['last_login_at'] as int)
          : null,
      isActive: data['is_active'] as bool? ?? true,
    );
  }

  /// Convert to Firebase-compatible Map
  Map<String, dynamic> toFirebaseMap() {
    return {
      'email': email,
      'name': name,
      'level': level.name,
      'created_at': createdAt.millisecondsSinceEpoch,
      'last_login_at': lastLoginAt?.millisecondsSinceEpoch,
      'is_active': isActive,
    };
  }

  /// Create a copy with updated fields
  AdminModel copyWith({
    String? uid,
    String? email,
    String? name,
    AdminLevel? level,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isActive,
  }) {
    return AdminModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      level: level ?? this.level,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Update last login time
  AdminModel withLastLogin(DateTime loginTime) {
    return copyWith(lastLoginAt: loginTime);
  }

  /// Get display name for UI
  String get displayName => name.isNotEmpty ? name : email.split('@').first;

  /// Get level display text
  String get levelDisplayName => level.displayName;

  /// Check if admin can perform specific actions
  bool canManagePasswords() => level.canManagePasswords;
  bool canDeleteContent() => level.canDeleteContent;
  bool canManageContent() => level.canManageContent;
  bool canViewAnalytics() => level.canViewAnalytics;

  @override
  String toString() {
    return 'AdminModel(uid: $uid, email: $email, level: ${level.name}, active: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AdminModel &&
        other.uid == uid &&
        other.email == email &&
        other.level == level;
  }

  @override
  int get hashCode => uid.hashCode ^ email.hashCode ^ level.hashCode;
}

/// Admin access levels (moved from firebase_service.dart for better organization)
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

  String get description {
    switch (this) {
      case AdminLevel.master:
        return 'Full access to all features including user management';
      case AdminLevel.content:
        return 'Can manage devotional content and songs';
    }
  }

  bool get canManagePasswords => this == AdminLevel.master;
  bool get canDeleteContent => this == AdminLevel.master;
  bool get canManageContent => true; // Both levels can manage content
  bool get canViewAnalytics => this == AdminLevel.master;
  bool get canManageUsers => this == AdminLevel.master;
}
