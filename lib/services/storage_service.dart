import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../models/queue_item.dart';
import '../models/playback_settings.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  late Box<Song> _songsBox;
  late Box<Playlist> _playlistsBox;
  late Box<QueueItem> _queueBox;
  late Box<PlaybackSettings> _settingsBox;
  late SharedPreferences _prefs;

  /// Initialize storage service
  Future<void> initialize() async {
    // Register Hive adapters
    Hive.registerAdapter(SongAdapter());
    Hive.registerAdapter(PlaylistAdapter());
    Hive.registerAdapter(QueueItemAdapter());
    Hive.registerAdapter(PlaybackSettingsAdapter());
    Hive.registerAdapter(RepeatModeAdapter());

    // Open Hive boxes
    _songsBox = await Hive.openBox<Song>('songs');
    _playlistsBox = await Hive.openBox<Playlist>('playlists');
    _queueBox = await Hive.openBox<QueueItem>('queue');
    _settingsBox = await Hive.openBox<PlaybackSettings>('settings');

    // Initialize SharedPreferences
    _prefs = await SharedPreferences.getInstance();

    // Create default playlists if they don't exist
    await _createDefaultPlaylists();
  }

  /// Create default system playlists
  Future<void> _createDefaultPlaylists() async {
    // Recently Played
    if (!_playlistsBox.containsKey('recently_played')) {
      final recentlyPlayed = Playlist.system(
        name: 'Recently Played',
        description: 'Your recently played songs',
      );
      await _playlistsBox.put('recently_played', recentlyPlayed);
    }


    // Most Played
    if (!_playlistsBox.containsKey('most_played')) {
      final mostPlayed = Playlist.system(
        name: 'Most Played',
        description: 'Your most played songs',
      );
      await _playlistsBox.put('most_played', mostPlayed);
    }
  }

  // Song operations
  Future<void> saveSong(Song song) async {
    await _songsBox.put(song.id, song);
  }

  Future<void> saveSongs(List<Song> songs) async {
    final Map<String, Song> songMap = {};
    for (final song in songs) {
      songMap[song.id] = song;
    }
    await _songsBox.putAll(songMap);
  }

  Song? getSong(String id) {
    return _songsBox.get(id);
  }

  List<Song> getAllSongs() {
    return _songsBox.values.toList();
  }

  List<Song> getSongsByIds(List<String> ids) {
    return ids.map((id) => _songsBox.get(id)).where((song) => song != null).cast<Song>().toList();
  }

  Future<void> deleteSong(String id) async {
    await _songsBox.delete(id);
    // Remove from all playlists
    for (final playlist in _playlistsBox.values) {
      if (playlist.songIds.contains(id)) {
        // Create a new list to avoid modifying the original
        final updatedSongIds = List<String>.from(playlist.songIds);
        updatedSongIds.remove(id);
        
        // Create a new playlist instance with updated song IDs
        final updatedPlaylist = Playlist(
          id: playlist.id,
          name: playlist.name,
          description: playlist.description,
          songIds: updatedSongIds,
          coverArtPath: playlist.coverArtPath,
          isSystemPlaylist: playlist.isSystemPlaylist,
          dateCreated: playlist.dateCreated,
          dateModified: DateTime.now(),
        );
        
        await savePlaylist(updatedPlaylist);
      }
    }
  }

  Future<void> updateSongPlayCount(String id) async {
    final song = _songsBox.get(id);
    if (song != null) {
      song.playCount++;
      song.lastPlayed = DateTime.now();
      await saveSong(song);
    }
  }


  // Playlist operations
  Future<void> savePlaylist(Playlist playlist) async {
    await _playlistsBox.put(playlist.id, playlist);
  }

  Playlist? getPlaylist(String id) {
    return _playlistsBox.get(id);
  }

  List<Playlist> getAllPlaylists() {
    return _playlistsBox.values.toList();
  }

  List<Playlist> getUserPlaylists() {
    return _playlistsBox.values.where((p) => !p.isSystemPlaylist).toList();
  }

  List<Playlist> getSystemPlaylists() {
    return _playlistsBox.values.where((p) => p.isSystemPlaylist).toList();
  }

  Future<void> deletePlaylist(String id) async {
    final playlist = _playlistsBox.get(id);
    if (playlist != null && !playlist.isSystemPlaylist) {
      await _playlistsBox.delete(id);
    }
  }

  // Queue operations
  Future<void> saveQueue(List<QueueItem> queue) async {
    await _queueBox.clear();
    for (int i = 0; i < queue.length; i++) {
      await _queueBox.put(i, queue[i]);
    }
  }

  List<QueueItem> getQueue() {
    return _queueBox.values.toList()..sort((a, b) => a.position.compareTo(b.position));
  }

  Future<void> clearQueue() async {
    await _queueBox.clear();
  }

  // Settings operations
  Future<void> savePlaybackSettings(PlaybackSettings settings) async {
    await _settingsBox.put('playback_settings', settings);
  }

  PlaybackSettings getPlaybackSettings() {
    return _settingsBox.get('playback_settings') ?? PlaybackSettings();
  }

  // Recently played songs
  Future<void> addToRecentlyPlayed(String songId) async {
    final recentlyPlayed = _playlistsBox.get('recently_played');
    if (recentlyPlayed != null) {
      // Create a new list to avoid modifying the original
      final updatedSongIds = List<String>.from(recentlyPlayed.songIds);
      
      // Remove if already exists
      updatedSongIds.remove(songId);
      // Add to beginning
      updatedSongIds.insert(0, songId);
      // Keep only last 100 songs
      if (updatedSongIds.length > 100) {
        updatedSongIds.removeRange(100, updatedSongIds.length);
      }
      
      // Create a new playlist instance with updated song IDs
      final updatedPlaylist = Playlist(
        id: recentlyPlayed.id,
        name: recentlyPlayed.name,
        description: recentlyPlayed.description,
        songIds: updatedSongIds,
        coverArtPath: recentlyPlayed.coverArtPath,
        isSystemPlaylist: recentlyPlayed.isSystemPlaylist,
        dateCreated: recentlyPlayed.dateCreated,
        dateModified: DateTime.now(),
      );
      
      await savePlaylist(updatedPlaylist);
    }
  }

  // Most played songs
  Future<void> updateMostPlayed() async {
    final mostPlayed = _playlistsBox.get('most_played');
    if (mostPlayed != null) {
      // Get all songs sorted by play count
      final allSongs = getAllSongs();
      allSongs.sort((a, b) => b.playCount.compareTo(a.playCount));
      
      // Create new song IDs list
      final newSongIds = allSongs.take(50).map((song) => song.id).toList();
      
      // Create a new playlist instance with updated song IDs
      final updatedPlaylist = Playlist(
        id: mostPlayed.id,
        name: mostPlayed.name,
        description: mostPlayed.description,
        songIds: newSongIds,
        coverArtPath: mostPlayed.coverArtPath,
        isSystemPlaylist: mostPlayed.isSystemPlaylist,
        dateCreated: mostPlayed.dateCreated,
        dateModified: DateTime.now(),
      );
      
      await savePlaylist(updatedPlaylist);
    }
  }

  // Search functionality
  List<Song> searchSongs(String query) {
    if (query.isEmpty) return getAllSongs();
    
    final lowercaseQuery = query.toLowerCase();
    return getAllSongs().where((song) {
      return song.title.toLowerCase().contains(lowercaseQuery) ||
             song.artist.toLowerCase().contains(lowercaseQuery) ||
             song.album.toLowerCase().contains(lowercaseQuery) ||
             (song.genre?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();
  }

  List<Playlist> searchPlaylists(String query) {
    if (query.isEmpty) return getUserPlaylists();
    
    final lowercaseQuery = query.toLowerCase();
    return getUserPlaylists().where((playlist) {
      return playlist.name.toLowerCase().contains(lowercaseQuery) ||
             (playlist.description?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();
  }

  // Export/Import functionality
  Future<String> exportData() async {
    final data = {
      'songs': getAllSongs().map((s) => s.toMap()).toList(),
      'playlists': getAllPlaylists().map((p) => p.toMap()).toList(),
      'settings': getPlaybackSettings().toMap(),
    };
    return jsonEncode(data);
  }

  Future<void> importData(String jsonData) async {
    try {
      final data = jsonDecode(jsonData) as Map<String, dynamic>;
      
      // Import songs
      if (data['songs'] != null) {
        final songs = (data['songs'] as List)
            .map((s) => Song.fromMap(s as Map<String, dynamic>))
            .toList();
        await saveSongs(songs);
      }
      
      // Import playlists
      if (data['playlists'] != null) {
        for (final playlistData in data['playlists'] as List) {
          final playlist = Playlist.fromMap(playlistData as Map<String, dynamic>);
          await savePlaylist(playlist);
        }
      }
      
      // Import settings
      if (data['settings'] != null) {
        final settings = PlaybackSettings.fromMap(data['settings'] as Map<String, dynamic>);
        await savePlaybackSettings(settings);
      }
    } catch (e) {
      throw Exception('Failed to import data: $e');
    }
  }

  // Clear all data
  Future<void> clearAllData() async {
    await _songsBox.clear();
    await _playlistsBox.clear();
    await _queueBox.clear();
    await _settingsBox.clear();
    await _prefs.clear();
    await _createDefaultPlaylists();
  }

  // Get storage statistics
  Map<String, dynamic> getStorageStats() {
    return {
      'totalSongs': _songsBox.length,
      'totalPlaylists': _playlistsBox.length,
      'queueLength': _queueBox.length,
      'storageUsed': _getStorageSize(),
    };
  }

  Future<int> _getStorageSize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      int totalSize = 0;
      
      await for (final entity in appDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  // Dispose
  Future<void> dispose() async {
    await _songsBox.close();
    await _playlistsBox.close();
    await _queueBox.close();
    await _settingsBox.close();
  }
}
