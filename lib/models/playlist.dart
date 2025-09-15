import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

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

  Playlist({
    required this.id,
    required this.name,
    this.description,
    this.songIds = const [],
    required this.dateCreated,
    required this.dateModified,
    this.coverArtPath,
    this.isSystemPlaylist = false,
  });

  factory Playlist.create({
    required String name,
    String? description,
    String? coverArtPath,
  }) {
    final now = DateTime.now();
    return Playlist(
      id: const Uuid().v4(),
      name: name,
      description: description,
      dateCreated: now,
      dateModified: now,
      coverArtPath: coverArtPath,
    );
  }

  factory Playlist.system({
    required String name,
    String? description,
    String? coverArtPath,
  }) {
    final now = DateTime.now();
    return Playlist(
      id: const Uuid().v4(),
      name: name,
      description: description,
      dateCreated: now,
      dateModified: now,
      coverArtPath: coverArtPath,
      isSystemPlaylist: true,
    );
  }

  factory Playlist.fromMap(Map<String, dynamic> map) {
    return Playlist(
      id: map['id'] ?? const Uuid().v4(),
      name: map['name'] ?? 'Untitled Playlist',
      description: map['description'],
      songIds: List<String>.from(map['songIds'] ?? []),
      dateCreated: DateTime.tryParse(map['dateCreated'] ?? '') ?? DateTime.now(),
      dateModified: DateTime.tryParse(map['dateModified'] ?? '') ?? DateTime.now(),
      coverArtPath: map['coverArtPath'],
      isSystemPlaylist: map['isSystemPlaylist'] ?? false,
    );
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
    );
  }

  void addSong(String songId) {
    if (!songIds.contains(songId)) {
      songIds.add(songId);
      dateModified = DateTime.now();
      save();
    }
  }

  void removeSong(String songId) {
    songIds.remove(songId);
    dateModified = DateTime.now();
    save();
  }

  void reorderSongs(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final songId = songIds.removeAt(oldIndex);
    songIds.insert(newIndex, songId);
    dateModified = DateTime.now();
    save();
  }

  void clearSongs() {
    songIds.clear();
    dateModified = DateTime.now();
    save();
  }

  @override
  String toString() {
    return 'Playlist(id: $id, name: $name, songCount: ${songIds.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Playlist && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
