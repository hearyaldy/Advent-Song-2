// lib/models/devotional_model.dart
class DevotionalModel {
  final String id;
  final String date;
  final String title;
  final String content;
  final String verse;
  final String reference;
  final String author;
  final String addedBy;
  final String? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String source;

  DevotionalModel({
    required this.id,
    required this.date,
    required this.title,
    required this.content,
    this.verse = '',
    this.reference = '',
    this.author = 'Devotional Team',
    this.addedBy = '',
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    this.source = 'Firebase',
  });

  /// Create DevotionalModel from Firebase data
  factory DevotionalModel.fromFirebase(String id, Map<String, dynamic> data) {
    return DevotionalModel(
      id: id,
      date: id, // Date is used as ID in Firebase
      title: data['title']?.toString() ?? 'Untitled',
      content: data['content']?.toString() ?? '',
      verse: data['verse']?.toString() ?? '',
      reference: data['reference']?.toString() ?? '',
      author: data['author']?.toString() ?? 'Devotional Team',
      addedBy: data['added_by']?.toString() ?? '',
      updatedBy: data['updated_by']?.toString(),
      createdAt: data['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['created_at'] as int)
          : null,
      updatedAt: data['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['updated_at'] as int)
          : null,
      source: data['source']?.toString() ?? 'Firebase',
    );
  }

  /// Create DevotionalModel from legacy Google Sheets data
  factory DevotionalModel.fromLegacyData(Map<String, dynamic> data) {
    return DevotionalModel(
      id: data['id']?.toString() ?? '',
      date: data['date']?.toString() ?? '',
      title: data['title']?.toString() ?? 'Untitled',
      content: data['content']?.toString() ?? '',
      verse: data['verse']?.toString() ?? '',
      reference: data['reference']?.toString() ?? '',
      author: data['author']?.toString() ?? 'Devotional Team',
      addedBy:
          data['addedBy']?.toString() ?? data['added_by']?.toString() ?? '',
      source: data['source']?.toString() ?? 'Legacy',
    );
  }

  /// Convert to Firebase-compatible Map
  Map<String, dynamic> toFirebaseMap() {
    return {
      'title': title,
      'content': content,
      'verse': verse,
      'reference': reference,
      'author': author,
      'added_by': addedBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      'created_at': createdAt?.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
    };
  }

  /// Convert to display-friendly Map (for UI)
  Map<String, dynamic> toDisplayMap() {
    return {
      'id': id,
      'date': date,
      'title': title,
      'content': content,
      'verse': verse,
      'reference': reference,
      'author': author,
      'source': source,
      'loaded_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Create a copy with updated fields
  DevotionalModel copyWith({
    String? id,
    String? date,
    String? title,
    String? content,
    String? verse,
    String? reference,
    String? author,
    String? addedBy,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? source,
  }) {
    return DevotionalModel(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      content: content ?? this.content,
      verse: verse ?? this.verse,
      reference: reference ?? this.reference,
      author: author ?? this.author,
      addedBy: addedBy ?? this.addedBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      source: source ?? this.source,
    );
  }

  /// Check if devotional has verse content
  bool get hasVerse => verse.isNotEmpty;

  /// Check if devotional has reference
  bool get hasReference => reference.isNotEmpty;

  /// Get formatted date for display
  String get formattedDate {
    try {
      final dateTime = DateTime.parse(date);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return date;
    }
  }

  /// Get word count for content
  int get wordCount =>
      content.split(' ').where((word) => word.isNotEmpty).length;

  /// Get reading time estimate (words per minute)
  int get estimatedReadingMinutes => (wordCount / 200).ceil();

  @override
  String toString() {
    return 'DevotionalModel(id: $id, title: $title, author: $author, source: $source)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DevotionalModel &&
        other.id == id &&
        other.title == title &&
        other.content == content;
  }

  @override
  int get hashCode => id.hashCode ^ title.hashCode ^ content.hashCode;
}
