import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

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
  bool isLiked;

  @HiveField(14)
  String? lyricsPath;

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
    this.isLiked = false,
    this.lyricsPath,
  });

  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: map['id'] ?? const Uuid().v4(),
      title: map['title'] ?? 'Unknown Title',
      artist: map['artist'] ?? 'Unknown Artist',
      album: map['album'] ?? 'Unknown Album',
      filePath: map['filePath'] ?? '',
      duration: map['duration'] ?? 0,
      albumArtPath: map['albumArtPath'],
      trackNumber: map['trackNumber'],
      year: map['year'],
      genre: map['genre'],
      dateAdded: DateTime.tryParse(map['dateAdded'] ?? '') ?? DateTime.now(),
      lastPlayed: map['lastPlayed'] != null ? DateTime.tryParse(map['lastPlayed']) : null,
      playCount: map['playCount'] ?? 0,
      isLiked: map['isLiked'] ?? false,
      lyricsPath: map['lyricsPath'],
    );
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
      'isLiked': isLiked,
      'lyricsPath': lyricsPath,
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
    bool? isLiked,
    String? lyricsPath,
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
      isLiked: isLiked ?? this.isLiked,
      lyricsPath: lyricsPath ?? this.lyricsPath,
    );
  }

  @override
  String toString() {
    return 'Song(id: $id, title: $title, artist: $artist, album: $album)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Song && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
