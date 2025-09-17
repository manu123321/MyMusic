import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../models/queue_item.dart';
import '../models/playback_settings.dart';
import 'logging_service.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  Box<Song>? _songsBox;
  Box<Playlist>? _playlistsBox;
  Box<QueueItem>? _queueBox;
  Box<PlaybackSettings>? _settingsBox;
  SharedPreferences? _prefs;
  
  final _loggingService = LoggingService();
  bool _isInitialized = false;
  
  // Cache for frequently accessed data
  final Map<String, Song> _songCache = {};
  final Map<String, Playlist> _playlistCache = {};
  
  // Batch operations queue
  final List<Function> _pendingOperations = [];
  bool _isProcessingBatch = false;

  /// Initialize storage service with comprehensive error handling
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _loggingService.logInfo('Initializing storage service');
      
      // Register Hive adapters with error handling
      await _registerHiveAdapters();
      
      // Open Hive boxes with retry mechanism
      await _openHiveBoxes();
      
      // Initialize SharedPreferences
      _prefs = await SharedPreferences.getInstance();
      
      // Create default playlists if they don't exist
      await _createDefaultPlaylists();
      
      // Initialize caches
      await _initializeCaches();
      
      _isInitialized = true;
      _loggingService.logInfo('Storage service initialized successfully');
      
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to initialize storage service', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _registerHiveAdapters() async {
    try {
      // Check if adapters are already registered
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(SongAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(PlaylistAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(QueueItemAdapter());
      }
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(PlaybackSettingsAdapter());
      }
      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(RepeatModeAdapter());
      }
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to register Hive adapters', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _openHiveBoxes() async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 1);
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        _songsBox = await Hive.openBox<Song>('songs');
        _playlistsBox = await Hive.openBox<Playlist>('playlists');
        _queueBox = await Hive.openBox<QueueItem>('queue');
        _settingsBox = await Hive.openBox<PlaybackSettings>('settings');
        return;
      } catch (e, stackTrace) {
        _loggingService.logWarning('Failed to open Hive boxes (attempt $attempt/$maxRetries)', e);
        
        if (attempt == maxRetries) {
          _loggingService.logError('All attempts to open Hive boxes failed', e, stackTrace);
          rethrow;
        }
        
        await Future.delayed(retryDelay * attempt);
      }
    }
  }

  Future<void> _initializeCaches() async {
    try {
      // Pre-load frequently accessed songs into cache
      final allSongs = _songsBox?.values ?? <Song>[];
      for (final song in allSongs) {
        _songCache[song.id] = song;
      }
      
      // Pre-load playlists into cache
      final allPlaylists = _playlistsBox?.values ?? <Playlist>[];
      for (final playlist in allPlaylists) {
        _playlistCache[playlist.id] = playlist;
      }
      
      _loggingService.logInfo('Initialized caches: ${_songCache.length} songs, ${_playlistCache.length} playlists');
    } catch (e, stackTrace) {
      _loggingService.logWarning('Failed to initialize caches', e);
    }
  }

  Future<void> _createDefaultPlaylists() async {
    try {
      if (_playlistsBox == null) return;
      
      // Recently Played
      if (!_playlistsBox!.containsKey('recently_played')) {
        final recentlyPlayed = Playlist.system(
          name: 'Recently Played',
          description: 'Your recently played songs',
        );
        await _playlistsBox!.put('recently_played', recentlyPlayed);
        _playlistCache['recently_played'] = recentlyPlayed;
      }

      // Most Played
      if (!_playlistsBox!.containsKey('most_played')) {
        final mostPlayed = Playlist.system(
          name: 'Most Played',
          description: 'Your most played songs',
        );
        await _playlistsBox!.put('most_played', mostPlayed);
        _playlistCache['most_played'] = mostPlayed;
      }
      
      // Favorites
      if (!_playlistsBox!.containsKey('favorites')) {
        final favorites = Playlist.system(
          name: 'Favorites',
          description: 'Your favorite songs',
        );
        await _playlistsBox!.put('favorites', favorites);
        _playlistCache['favorites'] = favorites;
      }
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to create default playlists', e, stackTrace);
    }
  }

  // Enhanced song operations with caching and error handling
  Future<void> saveSong(Song song) async {
    try {
      await _ensureInitialized();
      await _songsBox!.put(song.id, song);
      _songCache[song.id] = song;
      _loggingService.logDebug('Saved song: ${song.title}');
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to save song: ${song.title}', e, stackTrace);
      rethrow;
    }
  }

  Future<void> saveSongs(List<Song> songs) async {
    if (songs.isEmpty) return;
    
    try {
      await _ensureInitialized();
      
      // Use batch operation for better performance
      final Map<String, Song> songMap = {};
      for (final song in songs) {
        songMap[song.id] = song;
        _songCache[song.id] = song;
      }
      
      await _songsBox!.putAll(songMap);
      _loggingService.logInfo('Saved ${songs.length} songs');
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to save ${songs.length} songs', e, stackTrace);
      rethrow;
    }
  }

  Song? getSong(String id) {
    try {
      // Check cache first
      if (_songCache.containsKey(id)) {
        return _songCache[id];
      }
      
      // Fallback to database
      final song = _songsBox?.get(id);
      if (song != null) {
        _songCache[id] = song;
      }
      return song;
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to get song: $id', e, stackTrace);
      return null;
    }
  }

  List<Song> getAllSongs() {
    try {
      return _songsBox?.values.toList() ?? [];
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to get all songs', e, stackTrace);
      return [];
    }
  }

  List<Song> getSongsByIds(List<String> ids) {
    try {
      final songs = <Song>[];
      for (final id in ids) {
        final song = getSong(id);
        if (song != null) {
          songs.add(song);
        }
      }
      return songs;
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to get songs by IDs', e, stackTrace);
      return [];
    }
  }

  Future<void> deleteSong(String id) async {
    try {
      await _ensureInitialized();
      
      // Remove from cache
      _songCache.remove(id);
      
      // Remove from database
      await _songsBox!.delete(id);
      
      // Remove from all playlists
      await _removeSongFromAllPlaylists(id);
      
      _loggingService.logInfo('Deleted song: $id');
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to delete song: $id', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _removeSongFromAllPlaylists(String songId) async {
    try {
      final playlists = getAllPlaylists();
      for (final playlist in playlists) {
        if (playlist.songIds.contains(songId)) {
          final updatedSongIds = List<String>.from(playlist.songIds);
          updatedSongIds.remove(songId);
          
          final updatedPlaylist = playlist.copyWith(
            songIds: updatedSongIds,
            dateModified: DateTime.now(),
          );
          
          await savePlaylist(updatedPlaylist);
        }
      }
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to remove song from playlists: $songId', e, stackTrace);
    }
  }

  Future<void> updateSongPlayCount(String id) async {
    try {
      final song = getSong(id);
      if (song != null) {
        final updatedSong = song.copyWith(
          playCount: song.playCount + 1,
          lastPlayed: DateTime.now(),
        );
        await saveSong(updatedSong);
        
        // Update most played playlist asynchronously
        _scheduleOperation(() => updateMostPlayed());
      }
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to update play count for song: $id', e, stackTrace);
    }
  }

  // Enhanced playlist operations
  Future<void> savePlaylist(Playlist playlist) async {
    try {
      await _ensureInitialized();
      await _playlistsBox!.put(playlist.id, playlist);
      _playlistCache[playlist.id] = playlist;
      _loggingService.logDebug('Saved playlist: ${playlist.name}');
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to save playlist: ${playlist.name}', e, stackTrace);
      rethrow;
    }
  }

  Playlist? getPlaylist(String id) {
    try {
      // Check cache first
      if (_playlistCache.containsKey(id)) {
        return _playlistCache[id];
      }
      
      // Fallback to database
      final playlist = _playlistsBox?.get(id);
      if (playlist != null) {
        _playlistCache[id] = playlist;
      }
      return playlist;
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to get playlist: $id', e, stackTrace);
      return null;
    }
  }

  List<Playlist> getAllPlaylists() {
    try {
      return _playlistsBox?.values.toList() ?? [];
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to get all playlists', e, stackTrace);
      return [];
    }
  }

  List<Playlist> getUserPlaylists() {
    try {
      return getAllPlaylists().where((p) => !p.isSystemPlaylist).toList();
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to get user playlists', e, stackTrace);
      return [];
    }
  }

  List<Playlist> getSystemPlaylists() {
    try {
      return getAllPlaylists().where((p) => p.isSystemPlaylist).toList();
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to get system playlists', e, stackTrace);
      return [];
    }
  }

  Future<void> deletePlaylist(String id) async {
    try {
      await _ensureInitialized();
      
      final playlist = getPlaylist(id);
      if (playlist != null && !playlist.isSystemPlaylist) {
        _playlistCache.remove(id);
        await _playlistsBox!.delete(id);
        _loggingService.logInfo('Deleted playlist: ${playlist.name}');
      }
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to delete playlist: $id', e, stackTrace);
      rethrow;
    }
  }

  // Queue operations with error handling
  Future<void> saveQueue(List<QueueItem> queue) async {
    try {
      await _ensureInitialized();
      await _queueBox!.clear();
      for (int i = 0; i < queue.length; i++) {
        await _queueBox!.put(i, queue[i]);
      }
      _loggingService.logDebug('Saved queue with ${queue.length} items');
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to save queue', e, stackTrace);
      rethrow;
    }
  }

  List<QueueItem> getQueue() {
    try {
      final queue = _queueBox?.values.toList() ?? [];
      queue.sort((a, b) => a.position.compareTo(b.position));
      return queue;
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to get queue', e, stackTrace);
      return [];
    }
  }

  Future<void> clearQueue() async {
    try {
      await _ensureInitialized();
      await _queueBox!.clear();
      _loggingService.logDebug('Cleared queue');
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to clear queue', e, stackTrace);
    }
  }

  // Settings operations
  Future<void> savePlaybackSettings(PlaybackSettings settings) async {
    try {
      await _ensureInitialized();
      await _settingsBox!.put('playback_settings', settings);
      _loggingService.logDebug('Saved playback settings');
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to save playback settings', e, stackTrace);
      rethrow;
    }
  }

  PlaybackSettings getPlaybackSettings() {
    try {
      return _settingsBox?.get('playback_settings') ?? PlaybackSettings();
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to get playback settings', e, stackTrace);
      return PlaybackSettings();
    }
  }

  // Recently played songs with improved performance
  Future<void> addToRecentlyPlayed(String songId) async {
    try {
      final recentlyPlayed = getPlaylist('recently_played');
      if (recentlyPlayed != null) {
        final updatedSongIds = List<String>.from(recentlyPlayed.songIds);
        
        // Remove if already exists
        updatedSongIds.remove(songId);
        // Add to beginning
        updatedSongIds.insert(0, songId);
        // Keep only last 100 songs
        if (updatedSongIds.length > 100) {
          updatedSongIds.removeRange(100, updatedSongIds.length);
        }
        
        final updatedPlaylist = recentlyPlayed.copyWith(
          songIds: updatedSongIds,
          dateModified: DateTime.now(),
        );
        
        await savePlaylist(updatedPlaylist);
      }
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to add to recently played: $songId', e, stackTrace);
    }
  }

  // Most played songs with batch updates
  Future<void> updateMostPlayed() async {
    try {
      final mostPlayed = getPlaylist('most_played');
      if (mostPlayed != null) {
        // Get all songs sorted by play count
        final allSongs = getAllSongs();
        allSongs.sort((a, b) => b.playCount.compareTo(a.playCount));
        
        // Create new song IDs list
        final newSongIds = allSongs.take(50).map((song) => song.id).toList();
        
        final updatedPlaylist = mostPlayed.copyWith(
          songIds: newSongIds,
          dateModified: DateTime.now(),
        );
        
        await savePlaylist(updatedPlaylist);
      }
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to update most played', e, stackTrace);
    }
  }

  // Enhanced search functionality
  List<Song> searchSongs(String query) {
    if (query.isEmpty) return getAllSongs();
    
    try {
      final lowercaseQuery = query.toLowerCase();
      return getAllSongs().where((song) {
        return song.title.toLowerCase().contains(lowercaseQuery) ||
               song.artist.toLowerCase().contains(lowercaseQuery) ||
               song.album.toLowerCase().contains(lowercaseQuery) ||
               (song.genre?.toLowerCase().contains(lowercaseQuery) ?? false);
      }).toList();
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to search songs', e, stackTrace);
      return [];
    }
  }

  List<Playlist> searchPlaylists(String query) {
    if (query.isEmpty) return getUserPlaylists();
    
    try {
      final lowercaseQuery = query.toLowerCase();
      return getUserPlaylists().where((playlist) {
        return playlist.name.toLowerCase().contains(lowercaseQuery) ||
               (playlist.description?.toLowerCase().contains(lowercaseQuery) ?? false);
      }).toList();
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to search playlists', e, stackTrace);
      return [];
    }
  }

  // Batch operations for better performance
  void _scheduleOperation(Function operation) {
    _pendingOperations.add(operation);
    if (!_isProcessingBatch) {
      _processBatchOperations();
    }
  }

  Future<void> _processBatchOperations() async {
    if (_isProcessingBatch) return;
    
    _isProcessingBatch = true;
    
    while (_pendingOperations.isNotEmpty) {
      final operation = _pendingOperations.removeAt(0);
      try {
        await operation();
      } catch (e, stackTrace) {
        _loggingService.logError('Batch operation failed', e, stackTrace);
      }
    }
    
    _isProcessingBatch = false;
  }

  // Export/Import with enhanced error handling
  Future<String> exportData() async {
    try {
      await _ensureInitialized();
      
      final data = {
        'version': '1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'songs': getAllSongs().map((s) => s.toMap()).toList(),
        'playlists': getAllPlaylists().map((p) => p.toMap()).toList(),
        'settings': getPlaybackSettings().toMap(),
      };
      
      final jsonString = jsonEncode(data);
      _loggingService.logInfo('Exported data: ${jsonString.length} characters');
      return jsonString;
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to export data', e, stackTrace);
      rethrow;
    }
  }

  Future<void> importData(String jsonData) async {
    try {
      await _ensureInitialized();
      
      final data = jsonDecode(jsonData) as Map<String, dynamic>;
      
      // Validate data structure
      if (!data.containsKey('version')) {
        throw Exception('Invalid data format: missing version');
      }
      
      // Import songs
      if (data['songs'] != null) {
        final songs = (data['songs'] as List)
            .map((s) => Song.fromMap(s as Map<String, dynamic>))
            .toList();
        await saveSongs(songs);
        _loggingService.logInfo('Imported ${songs.length} songs');
      }
      
      // Import playlists
      if (data['playlists'] != null) {
        for (final playlistData in data['playlists'] as List) {
          final playlist = Playlist.fromMap(playlistData as Map<String, dynamic>);
          await savePlaylist(playlist);
        }
        _loggingService.logInfo('Imported playlists');
      }
      
      // Import settings
      if (data['settings'] != null) {
        final settings = PlaybackSettings.fromMap(data['settings'] as Map<String, dynamic>);
        await savePlaybackSettings(settings);
        _loggingService.logInfo('Imported settings');
      }
      
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to import data', e, stackTrace);
      rethrow;
    }
  }

  // Clear all data with confirmation
  Future<void> clearAllData() async {
    try {
      await _ensureInitialized();
      
      // Clear caches
      _songCache.clear();
      _playlistCache.clear();
      
      // Clear databases
      await _songsBox!.clear();
      await _playlistsBox!.clear();
      await _queueBox!.clear();
      await _settingsBox!.clear();
      await _prefs!.clear();
      
      // Recreate default playlists
      await _createDefaultPlaylists();
      
      _loggingService.logInfo('Cleared all data');
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to clear all data', e, stackTrace);
      rethrow;
    }
  }

  // Storage statistics
  Map<String, dynamic> getStorageStats() {
    try {
      return {
        'totalSongs': _songsBox?.length ?? 0,
        'totalPlaylists': _playlistsBox?.length ?? 0,
        'queueLength': _queueBox?.length ?? 0,
        'cacheSize': _songCache.length + _playlistCache.length,
        'isInitialized': _isInitialized,
      };
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to get storage stats', e, stackTrace);
      return {
        'error': 'Failed to get statistics',
        'isInitialized': _isInitialized,
      };
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  // Cleanup and dispose
  Future<void> dispose() async {
    try {
      // Process any pending operations
      await _processBatchOperations();
      
      // Clear caches
      _songCache.clear();
      _playlistCache.clear();
      
      // Close boxes
      await _songsBox?.close();
      await _playlistsBox?.close();
      await _queueBox?.close();
      await _settingsBox?.close();
      
      _isInitialized = false;
      _loggingService.logInfo('Storage service disposed');
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to dispose storage service', e, stackTrace);
    }
  }
}
