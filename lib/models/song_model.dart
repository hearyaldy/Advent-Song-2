// song_model.dart - Song data models for Firebase integration
import 'package:firebase_database/firebase_database.dart';

/// Represents a single verse in a song
class SongVerse {
  final String verseNumber;
  final String lyrics;
  final bool isChorus;
  final int? order;

  const SongVerse({
    required this.verseNumber,
    required this.lyrics,
    this.isChorus = false,
    this.order,
  });

  /// Create SongVerse from JSON/Map (Firebase data)
  factory SongVerse.fromJson(Map<String, dynamic> json) {
    return SongVerse(
      verseNumber: json['verse_number']?.toString() ?? '',
      lyrics: json['lyrics']?.toString() ?? '',
      isChorus: _isChorusVerse(json['verse_number']?.toString() ?? ''),
      order: json['order'] as int?,
    );
  }

  /// Convert SongVerse to JSON/Map (for Firebase)
  Map<String, dynamic> toJson() {
    return {
      'verse_number': verseNumber,
      'lyrics': lyrics,
      'is_chorus': isChorus,
      if (order != null) 'order': order,
    };
  }

  /// Check if verse is a chorus/korus
  static bool _isChorusVerse(String verseNumber) {
    final lowerVerse = verseNumber.toLowerCase();
    return lowerVerse.contains('korus') ||
        lowerVerse.contains('chorus') ||
        lowerVerse.contains('refrain');
  }

  /// Get cleaned lyrics without extra whitespace
  String get cleanedLyrics {
    return lyrics
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n');
  }

  /// Get verse type for display
  String get verseType {
    if (isChorus) return 'Chorus';
    if (verseNumber.toLowerCase().contains('bridge')) return 'Bridge';
    if (verseNumber.toLowerCase().contains('outro')) return 'Outro';
    if (verseNumber.toLowerCase().contains('intro')) return 'Intro';
    return 'Verse';
  }

  @override
  String toString() =>
      'SongVerse(verseNumber: $verseNumber, isChorus: $isChorus)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SongVerse &&
          runtimeType == other.runtimeType &&
          verseNumber == other.verseNumber &&
          lyrics == other.lyrics;

  @override
  int get hashCode => verseNumber.hashCode ^ lyrics.hashCode;

  /// Copy with new values
  SongVerse copyWith({
    String? verseNumber,
    String? lyrics,
    bool? isChorus,
    int? order,
  }) {
    return SongVerse(
      verseNumber: verseNumber ?? this.verseNumber,
      lyrics: lyrics ?? this.lyrics,
      isChorus: isChorus ?? this.isChorus,
      order: order ?? this.order,
    );
  }
}

/// Represents a complete song with metadata and verses
class Song {
  final String id;
  final String songNumber;
  final String title;
  final List<SongVerse> verses;
  final String collection;
  final String? author;
  final String? composer;
  final String? copyright;
  final List<String> tags;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? addedBy;
  final Map<String, dynamic>? metadata;

  const Song({
    required this.id,
    required this.songNumber,
    required this.title,
    required this.verses,
    required this.collection,
    this.author,
    this.composer,
    this.copyright,
    this.tags = const [],
    this.createdAt,
    this.updatedAt,
    this.addedBy,
    this.metadata,
  });

  /// Create Song from JSON/Map (Firebase data)
  factory Song.fromJson(Map<String, dynamic> json, {String? id}) {
    // Handle verses - can be List or Map
    List<SongVerse> verses = [];
    final versesData = json['verses'];

    if (versesData is List) {
      verses = versesData
          .whereType<Map<String, dynamic>>()
          .map((verse) => SongVerse.fromJson(verse as Map<String, dynamic>))
          .toList();
    } else if (versesData is Map) {
      verses = versesData.values
          .whereType<Map<String, dynamic>>()
          .map((verse) => SongVerse.fromJson(verse as Map<String, dynamic>))
          .toList();
    }

    // Sort verses by order if available, otherwise by verse number
    verses.sort((a, b) {
      if (a.order != null && b.order != null) {
        return a.order!.compareTo(b.order!);
      }
      return a.verseNumber.compareTo(b.verseNumber);
    });

    return Song(
      id: id ?? json['id']?.toString() ?? '',
      songNumber: json['song_number']?.toString() ?? '',
      title: json['song_title']?.toString() ?? json['title']?.toString() ?? '',
      verses: verses,
      collection: json['collection']?.toString() ?? '',
      author: json['author']?.toString(),
      composer: json['composer']?.toString(),
      copyright: json['copyright']?.toString(),
      tags: _parseTags(json['tags']),
      createdAt: _parseTimestamp(json['created_at']),
      updatedAt: _parseTimestamp(json['updated_at']),
      addedBy: json['added_by']?.toString(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Create Song from Firebase DataSnapshot
  factory Song.fromSnapshot(DataSnapshot snapshot) {
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return Song.fromJson(data, id: snapshot.key);
  }

  /// Convert Song to JSON/Map (for Firebase)
  Map<String, dynamic> toJson() {
    return {
      'song_number': songNumber,
      'song_title': title,
      'title': title, // Backward compatibility
      'verses': verses
          .asMap()
          .map((index, verse) => MapEntry(index.toString(), verse.toJson())),
      'collection': collection,
      if (author != null) 'author': author,
      if (composer != null) 'composer': composer,
      if (copyright != null) 'copyright': copyright,
      if (tags.isNotEmpty) 'tags': tags,
      'created_at': createdAt?.millisecondsSinceEpoch ?? ServerValue.timestamp,
      'updated_at': updatedAt?.millisecondsSinceEpoch ?? ServerValue.timestamp,
      if (addedBy != null) 'added_by': addedBy,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Parse tags from various formats
  static List<String> _parseTags(dynamic tags) {
    if (tags == null) return [];
    if (tags is List) return tags.map((tag) => tag.toString()).toList();
    if (tags is String) {
      return tags.split(',').map((tag) => tag.trim()).toList();
    }
    return [];
  }

  /// Parse timestamp from Firebase
  static DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is int) return DateTime.fromMillisecondsSinceEpoch(timestamp);
    if (timestamp is Map && timestamp.containsKey('.sv')) return DateTime.now();
    return null;
  }

  /// Get all lyrics as a single string
  String get fullLyrics {
    return verses
        .map((verse) => '${verse.verseNumber}\n${verse.cleanedLyrics}')
        .join('\n\n');
  }

  /// Get verses grouped by type (Verse, Chorus, etc.)
  Map<String, List<SongVerse>> get versesByType {
    final grouped = <String, List<SongVerse>>{};
    for (final verse in verses) {
      final type = verse.verseType;
      grouped.putIfAbsent(type, () => []).add(verse);
    }
    return grouped;
  }

  /// Get all chorus verses
  List<SongVerse> get chorusVerses =>
      verses.where((verse) => verse.isChorus).toList();

  /// Get all non-chorus verses
  List<SongVerse> get regularVerses =>
      verses.where((verse) => !verse.isChorus).toList();

  /// Search within song content
  bool matchesSearch(String query) {
    final lowerQuery = query.toLowerCase();

    // Search in title
    if (title.toLowerCase().contains(lowerQuery)) return true;

    // Search in song number
    if (songNumber.contains(query)) return true;

    // Search in author
    if (author?.toLowerCase().contains(lowerQuery) == true) return true;

    // Search in lyrics
    for (final verse in verses) {
      if (verse.lyrics.toLowerCase().contains(lowerQuery)) return true;
    }

    // Search in tags
    for (final tag in tags) {
      if (tag.toLowerCase().contains(lowerQuery)) return true;
    }

    return false;
  }

  /// Get formatted song for sharing
  String getShareableText() {
    final buffer = StringBuffer();

    // Header
    buffer.writeln(title);
    buffer.writeln('Song #$songNumber | $collection');
    if (author != null) buffer.writeln('by $author');
    buffer.writeln('');

    // Verses
    for (final verse in verses) {
      buffer.writeln(verse.verseNumber);
      buffer.writeln(verse.cleanedLyrics);
      buffer.writeln('');
    }

    // Footer
    buffer.writeln('Shared from Lagu Advent App');

    return buffer.toString();
  }

  /// Get song for clipboard copy
  String getCopyableText() {
    return getShareableText();
  }

  /// Validate song data
  bool get isValid {
    return id.isNotEmpty &&
        songNumber.isNotEmpty &&
        title.isNotEmpty &&
        verses.isNotEmpty &&
        collection.isNotEmpty;
  }

  /// Get song statistics
  Map<String, int> get statistics {
    return {
      'verse_count': verses.length,
      'chorus_count': chorusVerses.length,
      'regular_verse_count': regularVerses.length,
      'total_lines':
          verses.fold(0, (sum, verse) => sum + verse.lyrics.split('\n').length),
      'total_characters':
          verses.fold(0, (sum, verse) => sum + verse.lyrics.length),
    };
  }

  @override
  String toString() => 'Song(id: $id, title: $title, songNumber: $songNumber)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          songNumber == other.songNumber &&
          title == other.title;

  @override
  int get hashCode => id.hashCode ^ songNumber.hashCode ^ title.hashCode;

  /// Copy with new values
  Song copyWith({
    String? id,
    String? songNumber,
    String? title,
    List<SongVerse>? verses,
    String? collection,
    String? author,
    String? composer,
    String? copyright,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? addedBy,
    Map<String, dynamic>? metadata,
  }) {
    return Song(
      id: id ?? this.id,
      songNumber: songNumber ?? this.songNumber,
      title: title ?? this.title,
      verses: verses ?? this.verses,
      collection: collection ?? this.collection,
      author: author ?? this.author,
      composer: composer ?? this.composer,
      copyright: copyright ?? this.copyright,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      addedBy: addedBy ?? this.addedBy,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Song collection metadata
class SongCollection {
  final String id;
  final String name;
  final String description;
  final String abbreviation;
  final int songCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

  const SongCollection({
    required this.id,
    required this.name,
    required this.description,
    required this.abbreviation,
    this.songCount = 0,
    this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  /// Create from JSON/Map
  factory SongCollection.fromJson(Map<String, dynamic> json, {String? id}) {
    return SongCollection(
      id: id ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      abbreviation: json['abbreviation']?.toString() ?? '',
      songCount: json['song_count'] as int? ?? 0,
      createdAt: Song._parseTimestamp(json['created_at']),
      updatedAt: Song._parseTimestamp(json['updated_at']),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON/Map
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'abbreviation': abbreviation,
      'song_count': songCount,
      'created_at': createdAt?.millisecondsSinceEpoch ?? ServerValue.timestamp,
      'updated_at': updatedAt?.millisecondsSinceEpoch ?? ServerValue.timestamp,
      if (metadata != null) 'metadata': metadata,
    };
  }

  @override
  String toString() =>
      'SongCollection(id: $id, name: $name, songCount: $songCount)';
}

/// Predefined song collections
class SongCollections {
  static const laguPujianMasaIni = SongCollection(
    id: 'lpmi',
    name: 'Lagu Pujian Masa Ini',
    description: 'Contemporary Christian worship songs',
    abbreviation: 'LPMI',
  );

  static const syairRinduDendam = SongCollection(
    id: 'srd',
    name: 'Syair Rindu Dendam',
    description: 'Traditional hymns and spiritual songs',
    abbreviation: 'SRD',
  );

  static const laguIban = SongCollection(
    id: 'iban',
    name: 'Lagu Iban',
    description: 'Songs in Iban language',
    abbreviation: 'Iban',
  );

  static const laguPandak = SongCollection(
    id: 'pandak',
    name: 'Lagu Pandak',
    description: 'Short songs and choruses',
    abbreviation: 'Pandak',
  );

  static const all = [
    laguPujianMasaIni,
    syairRinduDendam,
    laguIban,
    laguPandak,
  ];

  static SongCollection? getById(String id) {
    try {
      return all.firstWhere((collection) => collection.id == id);
    } catch (e) {
      return null;
    }
  }
}
