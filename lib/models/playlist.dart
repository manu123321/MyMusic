import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

part 'playlist.g.dart';

@HiveType(typeId: 1)
class Playlist extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? description;

  @HiveField(3)
  List<String> songIds;

  @HiveField(4)
  DateTime dateCreated;

  @HiveField(5)
  DateTime dateModified;

  @HiveField(6)
  String? coverArtPath;

  @HiveField(7)
  bool isSystemPlaylist; // for "Recently Played", "Liked Songs", etc.
  
  @HiveField(8)
  int sortOrder; // for custom playlist ordering
  
  @HiveField(9)
  bool isPublic; // for sharing functionality
  
  @HiveField(10)
  String? colorTheme; // hex color for playlist theming

  Playlist({
    required this.id,
    required this.name,
    this.description,
    this.songIds = const [],
    required this.dateCreated,
    required this.dateModified,
    this.coverArtPath,
    this.isSystemPlaylist = false,
    this.sortOrder = 0,
    this.isPublic = false,
    this.colorTheme,
  }) : assert(name.trim().isNotEmpty, 'Playlist name cannot be empty'),
       assert(songIds.length <= 10000, 'Playlist cannot exceed 10,000 songs'),
       assert(sortOrder >= 0, 'Sort order must be non-negative');

  factory Playlist.create({
    required String name,
    String? description,
    String? coverArtPath,
    bool isPublic = false,
    String? colorTheme,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Playlist name cannot be empty');
    }
    
    final now = DateTime.now();
    return Playlist(
      id: const Uuid().v4(),
      name: name.trim(),
      description: description?.trim(),
      dateCreated: now,
      dateModified: now,
      coverArtPath: coverArtPath,
      isPublic: isPublic,
      colorTheme: colorTheme,
    );
  }

  factory Playlist.system({
    required String name,
    String? description,
    String? coverArtPath,
    String? colorTheme,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError('System playlist name cannot be empty');
    }
    
    final now = DateTime.now();
    return Playlist(
      id: const Uuid().v4(),
      name: name.trim(),
      description: description?.trim(),
      dateCreated: now,
      dateModified: now,
      coverArtPath: coverArtPath,
      isSystemPlaylist: true,
      colorTheme: colorTheme,
    );
  }

  factory Playlist.fromMap(Map<String, dynamic> map) {
    try {
      // Validate required fields
      final name = (map['name'] as String?)?.trim();
      if (name == null || name.isEmpty) {
        throw ArgumentError('Playlist name cannot be null or empty');
      }
      
      // Validate song IDs list
      final songIdsRaw = map['songIds'];
      List<String> songIds = [];
      if (songIdsRaw is List) {
        songIds = songIdsRaw
            .where((id) => id is String && id.trim().isNotEmpty)
            .cast<String>()
            .toList();
      }
      
      if (songIds.length > 10000) {
        throw ArgumentError('Playlist cannot exceed 10,000 songs');
      }
      
      return Playlist(
        id: map['id'] ?? const Uuid().v4(),
        name: name,
        description: (map['description'] as String?)?.trim(),
        songIds: songIds,
        dateCreated: _parseDateTimeSafely(map['dateCreated']) ?? DateTime.now(),
        dateModified: _parseDateTimeSafely(map['dateModified']) ?? DateTime.now(),
        coverArtPath: map['coverArtPath'],
        isSystemPlaylist: map['isSystemPlaylist'] ?? false,
        sortOrder: _parseIntSafely(map['sortOrder'], 0),
        isPublic: map['isPublic'] ?? false,
        colorTheme: map['colorTheme'],
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing Playlist from map: $e');
      }
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'songIds': songIds,
      'dateCreated': dateCreated.toIso8601String(),
      'dateModified': dateModified.toIso8601String(),
      'coverArtPath': coverArtPath,
      'isSystemPlaylist': isSystemPlaylist,
      'sortOrder': sortOrder,
      'isPublic': isPublic,
      'colorTheme': colorTheme,
    };
  }

  Playlist copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? songIds,
    DateTime? dateCreated,
    DateTime? dateModified,
    String? coverArtPath,
    bool? isSystemPlaylist,
    int? sortOrder,
    bool? isPublic,
    String? colorTheme,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      songIds: songIds ?? this.songIds,
      dateCreated: dateCreated ?? this.dateCreated,
      dateModified: dateModified ?? this.dateModified,
      coverArtPath: coverArtPath ?? this.coverArtPath,
      isSystemPlaylist: isSystemPlaylist ?? this.isSystemPlaylist,
      sortOrder: sortOrder ?? this.sortOrder,
      isPublic: isPublic ?? this.isPublic,
      colorTheme: colorTheme ?? this.colorTheme,
    );
  }

  /// Add a song to the playlist
  bool addSong(String songId) {
    if (songId.trim().isEmpty) {
      throw ArgumentError('Song ID cannot be empty');
    }
    
    if (isSystemPlaylist && !_canModifySystemPlaylist()) {
      return false;
    }
    
    if (songIds.length >= 10000) {
      throw StateError('Playlist cannot exceed 10,000 songs');
    }
    
    if (!songIds.contains(songId)) {
      songIds.add(songId);
      dateModified = DateTime.now();
      try {
        save();
        return true;
      } catch (e) {
        // Rollback on save failure
        songIds.remove(songId);
        rethrow;
      }
    }
    return false;
  }

  /// Remove a song from the playlist
  bool removeSong(String songId) {
    if (songId.trim().isEmpty) return false;
    
    if (isSystemPlaylist && !_canModifySystemPlaylist()) {
      return false;
    }
    
    final removed = songIds.remove(songId);
    if (removed) {
      dateModified = DateTime.now();
      try {
        save();
        return true;
      } catch (e) {
        // Rollback on save failure
        songIds.add(songId);
        rethrow;
      }
    }
    return false;
  }

  /// Add multiple songs to the playlist
  int addSongs(List<String> songIdsToAdd) {
    if (isSystemPlaylist && !_canModifySystemPlaylist()) {
      return 0;
    }
    
    final validIds = songIdsToAdd
        .where((id) => id.trim().isNotEmpty && !songIds.contains(id))
        .toList();
    
    if (songIds.length + validIds.length > 10000) {
      throw StateError('Adding ${validIds.length} songs would exceed 10,000 song limit');
    }
    
    if (validIds.isNotEmpty) {
      songIds.addAll(validIds);
      dateModified = DateTime.now();
      try {
        save();
        return validIds.length;
      } catch (e) {
        // Rollback on save failure
        for (final id in validIds) {
          songIds.remove(id);
        }
        rethrow;
      }
    }
    return 0;
  }

  /// Reorder songs in the playlist
  bool reorderSongs(int oldIndex, int newIndex) {
    if (isSystemPlaylist && !_canModifySystemPlaylist()) {
      return false;
    }
    
    if (oldIndex < 0 || oldIndex >= songIds.length ||
        newIndex < 0 || newIndex >= songIds.length) {
      throw RangeError('Invalid indices for reordering');
    }
    
    if (oldIndex == newIndex) return false;
    
    final originalList = List<String>.from(songIds);
    
    try {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final songId = songIds.removeAt(oldIndex);
      songIds.insert(newIndex, songId);
      dateModified = DateTime.now();
      save();
      return true;
    } catch (e) {
      // Rollback on failure
      songIds.clear();
      songIds.addAll(originalList);
      rethrow;
    }
  }

  /// Clear all songs from the playlist
  bool clearSongs() {
    if (isSystemPlaylist && !_canModifySystemPlaylist()) {
      return false;
    }
    
    final originalList = List<String>.from(songIds);
    
    try {
      songIds.clear();
      dateModified = DateTime.now();
      save();
      return true;
    } catch (e) {
      // Rollback on failure
      songIds.addAll(originalList);
      rethrow;
    }
  }
  
  /// Shuffle the playlist
  bool shuffle() {
    if (isSystemPlaylist && !_canModifySystemPlaylist()) {
      return false;
    }
    
    if (songIds.length <= 1) return false;
    
    final originalList = List<String>.from(songIds);
    
    try {
      songIds.shuffle(math.Random());
      dateModified = DateTime.now();
      save();
      return true;
    } catch (e) {
      // Rollback on failure
      songIds.clear();
      songIds.addAll(originalList);
      rethrow;
    }
  }
  
  /// Check if system playlist can be modified
  bool _canModifySystemPlaylist() {
    // Some system playlists like "Recently Played" can be modified
    return name == 'Recently Played' || name == 'Most Played' || name == 'Favorites';
  }

  /// Get playlist duration in milliseconds
  int get totalDuration {
    // This would need to be calculated by looking up actual songs
    // For now, return 0 as placeholder
    return 0;
  }
  
  /// Get formatted duration string
  String get formattedDuration {
    final Duration dur = Duration(milliseconds: totalDuration);
    final hours = dur.inHours;
    final minutes = dur.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
  
  /// Check if playlist is empty
  bool get isEmpty => songIds.isEmpty;
  
  /// Check if playlist is not empty
  bool get isNotEmpty => songIds.isNotEmpty;
  
  /// Get song count
  int get songCount => songIds.length;
  
  /// Check if playlist contains a specific song
  bool containsSong(String songId) => songIds.contains(songId);
  
  /// Get index of a song in the playlist
  int indexOf(String songId) => songIds.indexOf(songId);
  
  /// Check if playlist can be modified
  bool get canModify {
    return !isSystemPlaylist || _canModifySystemPlaylist();
  }
  
  /// Get playlist age in days
  int get ageInDays {
    return DateTime.now().difference(dateCreated).inDays;
  }
  
  /// Check if playlist was modified recently (within 24 hours)
  bool get isRecentlyModified {
    return DateTime.now().difference(dateModified).inHours < 24;
  }
  
  /// Get search keywords for this playlist
  List<String> get searchKeywords {
    final keywords = <String>[];
    keywords.addAll(name.toLowerCase().split(' '));
    if (description != null) {
      keywords.addAll(description!.toLowerCase().split(' '));
    }
    return keywords.where((k) => k.isNotEmpty).toSet().toList();
  }
  
  @override
  String toString() {
    return 'Playlist(id: $id, name: $name, songCount: ${songIds.length}, system: $isSystemPlaylist)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Playlist && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
  
  // Helper methods for parsing
  static int _parseIntSafely(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    if (value is double) return value.toInt();
    return defaultValue;
  }
  
  static DateTime? _parseDateTimeSafely(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
