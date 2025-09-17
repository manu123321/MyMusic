import 'dart:io';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

part 'song.g.dart';

@HiveType(typeId: 0)
class Song extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String artist;

  @HiveField(3)
  String album;

  @HiveField(4)
  String filePath;

  @HiveField(5)
  int duration; // in milliseconds

  @HiveField(6)
  String? albumArtPath;

  @HiveField(7)
  int? trackNumber;

  @HiveField(8)
  int? year;

  @HiveField(9)
  String? genre;

  @HiveField(10)
  DateTime dateAdded;

  @HiveField(11)
  DateTime? lastPlayed;

  @HiveField(12)
  int playCount;

  @HiveField(13)
  double? rating; // 0.0 to 5.0

  @HiveField(14)
  String? lyricsPath;

  @HiveField(15)
  bool isFavorite;

  @HiveField(16)
  int fileSize; // in bytes

  @HiveField(17)
  String? albumArtist;

  @HiveField(18)
  String? composer;

  @HiveField(19)
  int? discNumber;

  @HiveField(20)
  int bitrate; // in kbps

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.filePath,
    required this.duration,
    this.albumArtPath,
    this.trackNumber,
    this.year,
    this.genre,
    required this.dateAdded,
    this.lastPlayed,
    this.playCount = 0,
    this.rating,
    this.lyricsPath,
    this.isFavorite = false,
    this.fileSize = 0,
    this.albumArtist,
    this.composer,
    this.discNumber,
    this.bitrate = 0,
  }) : assert(title.isNotEmpty, 'Title cannot be empty'),
       assert(artist.isNotEmpty, 'Artist cannot be empty'),
       assert(filePath.isNotEmpty, 'File path cannot be empty'),
       assert(duration >= 0, 'Duration must be non-negative'),
       assert(playCount >= 0, 'Play count must be non-negative'),
       assert(rating == null || (rating >= 0.0 && rating <= 5.0), 'Rating must be between 0.0 and 5.0'),
       assert(fileSize >= 0, 'File size must be non-negative'),
       assert(bitrate >= 0, 'Bitrate must be non-negative');

  factory Song.fromMap(Map<String, dynamic> map) {
    try {
      // Validate required fields
      final title = (map['title'] as String?)?.trim();
      final artist = (map['artist'] as String?)?.trim();
      final album = (map['album'] as String?)?.trim();
      final filePath = (map['filePath'] as String?)?.trim();
      
      if (title == null || title.isEmpty) {
        throw ArgumentError('Song title cannot be null or empty');
      }
      if (artist == null || artist.isEmpty) {
        throw ArgumentError('Song artist cannot be null or empty');
      }
      if (filePath == null || filePath.isEmpty) {
        throw ArgumentError('Song file path cannot be null or empty');
      }
      
      // Validate numeric fields
      final duration = _parseIntSafely(map['duration'], 0);
      final playCount = _parseIntSafely(map['playCount'], 0);
      final fileSize = _parseIntSafely(map['fileSize'], 0);
      final bitrate = _parseIntSafely(map['bitrate'], 0);
      
      if (duration < 0) throw ArgumentError('Duration must be non-negative');
      if (playCount < 0) throw ArgumentError('Play count must be non-negative');
      
      // Validate rating
      double? rating;
      if (map['rating'] != null) {
        rating = _parseDoubleSafely(map['rating']);
        if (rating != null && (rating < 0.0 || rating > 5.0)) {
          throw ArgumentError('Rating must be between 0.0 and 5.0');
        }
      }
      
      return Song(
        id: map['id'] ?? const Uuid().v4(),
        title: title,
        artist: artist,
        album: album.isEmpty ? 'Unknown Album' : album,
        filePath: filePath,
        duration: duration,
        albumArtPath: map['albumArtPath'],
        trackNumber: _parseIntSafely(map['trackNumber']),
        year: _parseIntSafely(map['year']),
        genre: map['genre'],
        dateAdded: _parseDateTimeSafely(map['dateAdded']) ?? DateTime.now(),
        lastPlayed: _parseDateTimeSafely(map['lastPlayed']),
        playCount: playCount,
        rating: rating,
        lyricsPath: map['lyricsPath'],
        isFavorite: map['isFavorite'] ?? false,
        fileSize: fileSize,
        albumArtist: map['albumArtist'],
        composer: map['composer'],
        discNumber: _parseIntSafely(map['discNumber']),
        bitrate: bitrate,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing Song from map: $e');
      }
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'filePath': filePath,
      'duration': duration,
      'albumArtPath': albumArtPath,
      'trackNumber': trackNumber,
      'year': year,
      'genre': genre,
      'dateAdded': dateAdded.toIso8601String(),
      'lastPlayed': lastPlayed?.toIso8601String(),
      'playCount': playCount,
      'rating': rating,
      'lyricsPath': lyricsPath,
      'isFavorite': isFavorite,
      'fileSize': fileSize,
      'albumArtist': albumArtist,
      'composer': composer,
      'discNumber': discNumber,
      'bitrate': bitrate,
    };
  }

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? filePath,
    int? duration,
    String? albumArtPath,
    int? trackNumber,
    int? year,
    String? genre,
    DateTime? dateAdded,
    DateTime? lastPlayed,
    int? playCount,
    double? rating,
    String? lyricsPath,
    bool? isFavorite,
    int? fileSize,
    String? albumArtist,
    String? composer,
    int? discNumber,
    int? bitrate,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      filePath: filePath ?? this.filePath,
      duration: duration ?? this.duration,
      albumArtPath: albumArtPath ?? this.albumArtPath,
      trackNumber: trackNumber ?? this.trackNumber,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      dateAdded: dateAdded ?? this.dateAdded,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      playCount: playCount ?? this.playCount,
      rating: rating ?? this.rating,
      lyricsPath: lyricsPath ?? this.lyricsPath,
      isFavorite: isFavorite ?? this.isFavorite,
      fileSize: fileSize ?? this.fileSize,
      albumArtist: albumArtist ?? this.albumArtist,
      composer: composer ?? this.composer,
      discNumber: discNumber ?? this.discNumber,
      bitrate: bitrate ?? this.bitrate,
    );
  }

  /// Check if the song file exists on disk
  bool get fileExists {
    try {
      return File(filePath).existsSync();
    } catch (e) {
      return false;
    }
  }
  
  /// Get formatted duration string (MM:SS or HH:MM:SS)
  String get formattedDuration {
    final Duration dur = Duration(milliseconds: duration);
    final hours = dur.inHours;
    final minutes = dur.inMinutes.remainder(60);
    final seconds = dur.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }
  
  /// Get formatted file size string
  String get formattedFileSize {
    if (fileSize == 0) return 'Unknown';
    
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    int index = 0;
    double size = fileSize.toDouble();
    
    while (size >= 1024 && index < suffixes.length - 1) {
      size /= 1024;
      index++;
    }
    
    return '${size.toStringAsFixed(size < 10 ? 1 : 0)} ${suffixes[index]}';
  }
  
  /// Update play statistics
  Song incrementPlayCount() {
    return copyWith(
      playCount: playCount + 1,
      lastPlayed: DateTime.now(),
    );
  }
  
  /// Toggle favorite status
  Song toggleFavorite() {
    return copyWith(isFavorite: !isFavorite);
  }
  
  /// Set rating (0.0 to 5.0)
  Song setRating(double newRating) {
    if (newRating < 0.0 || newRating > 5.0) {
      throw ArgumentError('Rating must be between 0.0 and 5.0');
    }
    return copyWith(rating: newRating);
  }
  
  /// Check if song has complete metadata
  bool get hasCompleteMetadata {
    return title.isNotEmpty &&
           artist.isNotEmpty &&
           album.isNotEmpty &&
           duration > 0 &&
           fileSize > 0;
  }
  
  /// Get search keywords for this song
  List<String> get searchKeywords {
    final keywords = <String>[];
    keywords.addAll(title.toLowerCase().split(' '));
    keywords.addAll(artist.toLowerCase().split(' '));
    keywords.addAll(album.toLowerCase().split(' '));
    if (genre != null) keywords.addAll(genre!.toLowerCase().split(' '));
    if (albumArtist != null) keywords.addAll(albumArtist!.toLowerCase().split(' '));
    if (composer != null) keywords.addAll(composer!.toLowerCase().split(' '));
    return keywords.where((k) => k.isNotEmpty).toSet().toList();
  }
  
  @override
  String toString() {
    return 'Song(id: $id, title: $title, artist: $artist, album: $album, duration: ${formattedDuration})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Song && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
  
  // Helper methods for parsing
  static int? _parseIntSafely(dynamic value, [int? defaultValue]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? defaultValue;
    }
    if (value is double) return value.toInt();
    return defaultValue;
  }
  
  static double? _parseDoubleSafely(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
  
  static DateTime? _parseDateTimeSafely(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
