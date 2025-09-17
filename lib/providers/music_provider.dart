import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../services/custom_audio_handler.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../models/playback_settings.dart';
import '../services/storage_service.dart';
import '../services/metadata_service.dart';
import '../services/logging_service.dart';

// === SERVICES ===
final storageServiceProvider = Provider<StorageService>((ref) => StorageService());
final metadataServiceProvider = Provider<MetadataService>((ref) => MetadataService());
final loggingServiceProvider = Provider<LoggingService>((ref) => LoggingService());

// === AUDIO HANDLER ===
final audioHandlerProvider = Provider<CustomAudioHandler>((ref) {
  throw UnimplementedError('Audio handler must be initialized in main()');
});

// === LOADING STATES ===
final songsLoadingProvider = StateProvider<bool>((ref) => false);
final playlistsLoadingProvider = StateProvider<bool>((ref) => false);
final scanningDeviceProvider = StateProvider<bool>((ref) => false);

// === ERROR STATES ===
final lastErrorProvider = StateProvider<String?>((ref) => null);

// === SONGS PROVIDER ===
final songsProvider = StateNotifierProvider<SongsNotifier, List<Song>>((ref) {
  return SongsNotifier(
    ref.read(storageServiceProvider),
    ref.read(metadataServiceProvider),
    ref.read(loggingServiceProvider),
    ref,
  );
});

class SongsNotifier extends StateNotifier<List<Song>> {
  final StorageService _storageService;
  final MetadataService _metadataService;
  final LoggingService _loggingService;
  final Ref _ref;
  
  // Cache for performance
  final Map<String, Song> _songCache = {};
  bool _isInitialized = false;

  SongsNotifier(
    this._storageService,
    this._metadataService,
    this._loggingService,
    this._ref,
  ) : super([]) {
    _initializeSongs();
  }

  Future<void> _initializeSongs() async {
    if (_isInitialized) return;
    
    try {
      _ref.read(songsLoadingProvider.notifier).state = true;
      _ref.read(lastErrorProvider.notifier).state = null;
      
      await loadSongs();
      _isInitialized = true;
      
      _loggingService.logInfo('Songs provider initialized successfully');
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to initialize songs provider', e, stackTrace);
      _ref.read(lastErrorProvider.notifier).state = 'Failed to load songs: ${e.toString()}';
    } finally {
      _ref.read(songsLoadingProvider.notifier).state = false;
    }
  }

  Future<void> loadSongs() async {
    try {
      _ref.read(songsLoadingProvider.notifier).state = true;
      
      final songs = _storageService.getAllSongs();
      
      // Update cache
      _songCache.clear();
      for (final song in songs) {
        _songCache[song.id] = song;
      }
      
      state = songs;
      _loggingService.logInfo('Loaded ${songs.length} songs');
      
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to load songs', e, stackTrace);
      _ref.read(lastErrorProvider.notifier).state = 'Failed to load songs';
      rethrow;
    } finally {
      _ref.read(songsLoadingProvider.notifier).state = false;
    }
  }

  Future<void> scanDeviceForSongs() async {
    if (_ref.read(scanningDeviceProvider)) return; // Prevent concurrent scans
    
    try {
      _ref.read(scanningDeviceProvider.notifier).state = true;
      _ref.read(lastErrorProvider.notifier).state = null;
      
      _loggingService.logInfo('Starting device scan for audio files');
      
      final scannedSongs = await _metadataService.scanDeviceForAudioFiles();
      
      if (scannedSongs.isEmpty) {
        _loggingService.logInfo('No audio files found during scan');
        return;
      }
      
      // Filter out existing songs efficiently using cache
      final newSongs = <Song>[];
      for (final song in scannedSongs) {
        if (!_songCache.containsKey(song.id)) {
          newSongs.add(song);
        }
      }
      
      if (newSongs.isEmpty) {
        _loggingService.logInfo('No new songs found during scan');
        return;
      }
      
      // Save new songs in batches for better performance
      await _storageService.saveSongs(newSongs);
      
      // Update cache and state
      for (final song in newSongs) {
        _songCache[song.id] = song;
      }
      
      state = _storageService.getAllSongs();
      
      _loggingService.logInfo('Added ${newSongs.length} new songs from device scan');
      
    } catch (e, stackTrace) {
      _loggingService.logError('Device scan failed', e, stackTrace);
      _ref.read(lastErrorProvider.notifier).state = 'Failed to scan device: ${e.toString()}';
      rethrow;
    } finally {
      _ref.read(scanningDeviceProvider.notifier).state = false;
    }
  }

  Future<bool> addSong(Song song) async {
    try {
      if (song.title.trim().isEmpty) {
        throw ArgumentError('Song title cannot be empty');
      }
      
      // Check cache first for performance
      if (_songCache.containsKey(song.id)) {
        _loggingService.logWarning('Song already exists: ${song.title}');
        return false;
      }
      
      await _storageService.saveSong(song);
      
      // Update cache and state efficiently
      _songCache[song.id] = song;
      state = [...state, song];
      
      _loggingService.logInfo('Added song: ${song.title}');
      return true;
      
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to add song: ${song.title}', e, stackTrace);
      _ref.read(lastErrorProvider.notifier).state = 'Failed to add song: ${e.toString()}';
      return false;
    }
  }

  Future<bool> updateSong(Song song) async {
    try {
      if (song.title.trim().isEmpty) {
        throw ArgumentError('Song title cannot be empty');
      }
      
      await _storageService.saveSong(song); // FIXED: This was missing!
      
      // Update cache and state efficiently
      _songCache[song.id] = song;
      final updatedState = state.map((s) => s.id == song.id ? song : s).toList();
      state = updatedState;
      
      _loggingService.logInfo('Updated song: ${song.title}');
      return true;
      
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to update song: ${song.title}', e, stackTrace);
      _ref.read(lastErrorProvider.notifier).state = 'Failed to update song: ${e.toString()}';
      return false;
    }
  }

  Future<bool> deleteSong(String songId) async {
    try {
      if (songId.trim().isEmpty) {
        throw ArgumentError('Song ID cannot be empty');
      }
      
      final song = _songCache[songId];
      if (song == null) {
        _loggingService.logWarning('Attempted to delete non-existent song: $songId');
        return false;
      }
      
      await _storageService.deleteSong(songId);
      
      // Update cache and state efficiently
      _songCache.remove(songId);
      state = state.where((s) => s.id != songId).toList();
      
      _loggingService.logInfo('Deleted song: ${song.title}');
      return true;
      
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to delete song: $songId', e, stackTrace);
      _ref.read(lastErrorProvider.notifier).state = 'Failed to delete song: ${e.toString()}';
      return false;
    }
  }

  List<Song> searchSongs(String query) {
    try {
      if (query.trim().isEmpty) {
        return state;
      }
      
      final results = _storageService.searchSongs(query);
      _loggingService.logDebug('Song search for "$query" returned ${results.length} results');
      return results;
      
    } catch (e, stackTrace) {
      _loggingService.logError('Song search failed for query: $query', e, stackTrace);
      return [];
    }
  }

  List<Song> getRecentlyPlayed({int limit = 50}) {
    try {
      final recentlyPlayedPlaylist = _storageService.getPlaylist('recently_played');
      if (recentlyPlayedPlaylist != null) {
        final songIds = recentlyPlayedPlaylist.songIds.take(limit).toList();
        final songs = _storageService.getSongsByIds(songIds);
        _loggingService.logDebug('Retrieved ${songs.length} recently played songs');
        return songs;
      }
      return [];
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to get recently played songs', e, stackTrace);
      return [];
    }
  }

  List<Song> getMostPlayed({int limit = 50}) {
    try {
      final mostPlayedPlaylist = _storageService.getPlaylist('most_played');
      if (mostPlayedPlaylist != null) {
        final songIds = mostPlayedPlaylist.songIds.take(limit).toList();
        final songs = _storageService.getSongsByIds(songIds);
        _loggingService.logDebug('Retrieved ${songs.length} most played songs');
        return songs;
      }
      return [];
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to get most played songs', e, stackTrace);
      return [];
    }
  }

  List<Song> getFavorites() {
    try {
      final favorites = state.where((song) => song.isFavorite).toList();
      _loggingService.logDebug('Retrieved ${favorites.length} favorite songs');
      return favorites;
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to get favorite songs', e, stackTrace);
      return [];
    }
  }

  Song? getSongById(String songId) {
    try {
      return _songCache[songId];
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to get song by ID: $songId', e, stackTrace);
      return null;
    }
  }

  // Batch operations for better performance
  Future<int> addSongs(List<Song> songs) async {
    try {
      if (songs.isEmpty) return 0;
      
      final newSongs = <Song>[];
      for (final song in songs) {
        if (!_songCache.containsKey(song.id) && song.title.trim().isNotEmpty) {
          newSongs.add(song);
        }
      }
      
      if (newSongs.isEmpty) return 0;
      
      await _storageService.saveSongs(newSongs);
      
      // Update cache and state
      for (final song in newSongs) {
        _songCache[song.id] = song;
      }
      
      state = [...state, ...newSongs];
      
      _loggingService.logInfo('Added ${newSongs.length} songs in batch');
      return newSongs.length;
      
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to add songs in batch', e, stackTrace);
      _ref.read(lastErrorProvider.notifier).state = 'Failed to add songs: ${e.toString()}';
      return 0;
    }
  }

  Future<void> refreshSongs() async {
    try {
      _loggingService.logInfo('Refreshing songs from storage');
      await loadSongs();
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to refresh songs', e, stackTrace);
      rethrow;
    }
  }
}

// === PLAYLISTS PROVIDER ===
final playlistsProvider = StateNotifierProvider<PlaylistsNotifier, List<Playlist>>((ref) {
  return PlaylistsNotifier(
    ref.read(storageServiceProvider),
    ref.read(loggingServiceProvider),
    ref,
  );
});

class PlaylistsNotifier extends StateNotifier<List<Playlist>> {
  final StorageService _storageService;
  final LoggingService _loggingService;
  final Ref _ref;
  
  // Cache for performance
  final Map<String, Playlist> _playlistCache = {};
  bool _isInitialized = false;

  PlaylistsNotifier(
    this._storageService,
    this._loggingService,
    this._ref,
  ) : super([]) {
    _initializePlaylists();
  }

  Future<void> _initializePlaylists() async {
    if (_isInitialized) return;
    
    try {
      _ref.read(playlistsLoadingProvider.notifier).state = true;
      _ref.read(lastErrorProvider.notifier).state = null;
      
      await loadPlaylists();
      _isInitialized = true;
      
      _loggingService.logInfo('Playlists provider initialized successfully');
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to initialize playlists provider', e, stackTrace);
      _ref.read(lastErrorProvider.notifier).state = 'Failed to load playlists: ${e.toString()}';
    } finally {
      _ref.read(playlistsLoadingProvider.notifier).state = false;
    }
  }

  Future<void> loadPlaylists() async {
    try {
      _ref.read(playlistsLoadingProvider.notifier).state = true;
      
      final playlists = _storageService.getAllPlaylists();
      
      // Update cache
      _playlistCache.clear();
      for (final playlist in playlists) {
        _playlistCache[playlist.id] = playlist;
      }
      
      state = playlists;
      _loggingService.logInfo('Loaded ${playlists.length} playlists');
      
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to load playlists', e, stackTrace);
      _ref.read(lastErrorProvider.notifier).state = 'Failed to load playlists';
      rethrow;
    } finally {
      _ref.read(playlistsLoadingProvider.notifier).state = false;
    }
  }

  Future<String?> createPlaylist(
    String name, {
    String? description,
    String? coverArtPath,
    String? colorTheme,
    bool isPublic = false,
  }) async {
    try {
      if (name.trim().isEmpty) {
        throw ArgumentError('Playlist name cannot be empty');
      }
      
      // Check for duplicate names
      if (_playlistCache.values.any((p) => p.name.toLowerCase() == name.toLowerCase())) {
        throw ArgumentError('A playlist with this name already exists');
      }
      
      final playlist = Playlist.create(
        name: name,
        description: description,
        coverArtPath: coverArtPath,
        colorTheme: colorTheme,
        isPublic: isPublic,
      );
      
      await _storageService.savePlaylist(playlist);
      
      // Update cache and state
      _playlistCache[playlist.id] = playlist;
      state = [...state, playlist];
      
      _loggingService.logInfo('Created playlist: $name');
      return playlist.id;
      
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to create playlist: $name', e, stackTrace);
      _ref.read(lastErrorProvider.notifier).state = 'Failed to create playlist: ${e.toString()}';
      return null;
    }
  }

  Future<bool> updatePlaylist(Playlist playlist) async {
    try {
      if (playlist.name.trim().isEmpty) {
        throw ArgumentError('Playlist name cannot be empty');
      }
      
      await _storageService.savePlaylist(playlist);
      
      // Update cache and state
      _playlistCache[playlist.id] = playlist;
      final updatedState = state.map((p) => p.id == playlist.id ? playlist : p).toList();
      state = updatedState;
      
      _loggingService.logInfo('Updated playlist: ${playlist.name}');
      return true;
      
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to update playlist: ${playlist.name}', e, stackTrace);
      _ref.read(lastErrorProvider.notifier).state = 'Failed to update playlist: ${e.toString()}';
      return false;
    }
  }

  Future<bool> deletePlaylist(String playlistId) async {
    try {
      if (playlistId.trim().isEmpty) {
        throw ArgumentError('Playlist ID cannot be empty');
      }
      
      final playlist = _playlistCache[playlistId];
      if (playlist == null) {
        _loggingService.logWarning('Attempted to delete non-existent playlist: $playlistId');
        return false;
      }
      
       // Prevent deletion of system playlists
       if (playlist.isSystemPlaylist) {
         throw ArgumentError('Cannot delete system playlists');
       }
      
      await _storageService.deletePlaylist(playlistId);
      
      // Update cache and state
      _playlistCache.remove(playlistId);
      state = state.where((p) => p.id != playlistId).toList();
      
      _loggingService.logInfo('Deleted playlist: ${playlist.name}');
      return true;
      
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to delete playlist: $playlistId', e, stackTrace);
      _ref.read(lastErrorProvider.notifier).state = 'Failed to delete playlist: ${e.toString()}';
      return false;
    }
  }

  Future<bool> addSongToPlaylist(String playlistId, String songId) async {
    try {
      if (playlistId.trim().isEmpty || songId.trim().isEmpty) {
        throw ArgumentError('Playlist ID and Song ID cannot be empty');
      }
      
      final playlist = _playlistCache[playlistId];
      if (playlist == null) {
        throw ArgumentError('Playlist not found');
      }
      
      if (playlist.containsSong(songId)) {
        _loggingService.logWarning('Song already in playlist: ${playlist.name}');
        return false;
      }
      
      final success = playlist.addSong(songId);
      if (!success) {
        throw Exception('Failed to add song to playlist');
      }
      
      await _storageService.savePlaylist(playlist);
      
      // Update cache and state
      _playlistCache[playlistId] = playlist;
      final updatedState = state.map((p) => p.id == playlistId ? playlist : p).toList();
      state = updatedState;
      
      _loggingService.logInfo('Added song to playlist: ${playlist.name}');
      return true;
      
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to add song to playlist', e, stackTrace);
      _ref.read(lastErrorProvider.notifier).state = 'Failed to add song to playlist: ${e.toString()}';
      return false;
    }
  }

  Future<bool> removeSongFromPlaylist(String playlistId, String songId) async {
    try {
      if (playlistId.trim().isEmpty || songId.trim().isEmpty) {
        throw ArgumentError('Playlist ID and Song ID cannot be empty');
      }
      
      final playlist = _playlistCache[playlistId];
      if (playlist == null) {
        throw ArgumentError('Playlist not found');
      }
      
      if (!playlist.containsSong(songId)) {
        _loggingService.logWarning('Song not in playlist: ${playlist.name}');
        return false;
      }
      
      final success = playlist.removeSong(songId);
      if (!success) {
        throw Exception('Failed to remove song from playlist');
      }
      
      await _storageService.savePlaylist(playlist);
      
      // Update cache and state
      _playlistCache[playlistId] = playlist;
      final updatedState = state.map((p) => p.id == playlistId ? playlist : p).toList();
      state = updatedState;
      
      _loggingService.logInfo('Removed song from playlist: ${playlist.name}');
      return true;
      
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to remove song from playlist', e, stackTrace);
      _ref.read(lastErrorProvider.notifier).state = 'Failed to remove song from playlist: ${e.toString()}';
      return false;
    }
  }

  List<Playlist> getUserPlaylists() {
    try {
      final userPlaylists = _storageService.getUserPlaylists();
      _loggingService.logDebug('Retrieved ${userPlaylists.length} user playlists');
      return userPlaylists;
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to get user playlists', e, stackTrace);
      return [];
    }
  }

  List<Playlist> getSystemPlaylists() {
    try {
      final systemPlaylists = _storageService.getSystemPlaylists();
      _loggingService.logDebug('Retrieved ${systemPlaylists.length} system playlists');
      return systemPlaylists;
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to get system playlists', e, stackTrace);
      return [];
    }
  }

  List<Playlist> searchPlaylists(String query) {
    try {
      if (query.trim().isEmpty) {
        return state;
      }
      
      final results = _storageService.searchPlaylists(query);
      _loggingService.logDebug('Playlist search for "$query" returned ${results.length} results');
      return results;
      
    } catch (e, stackTrace) {
      _loggingService.logError('Playlist search failed for query: $query', e, stackTrace);
      return [];
    }
  }

  Playlist? getPlaylistById(String playlistId) {
    try {
      return _playlistCache[playlistId];
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to get playlist by ID: $playlistId', e, stackTrace);
      return null;
    }
  }

  Future<void> refreshPlaylists() async {
    try {
      _loggingService.logInfo('Refreshing playlists from storage');
      await loadPlaylists();
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to refresh playlists', e, stackTrace);
      rethrow;
    }
  }
}

// === PLAYBACK SETTINGS PROVIDER ===
final playbackSettingsProvider = StateNotifierProvider<PlaybackSettingsNotifier, PlaybackSettings>((ref) {
  return PlaybackSettingsNotifier(
    ref.read(storageServiceProvider),
    ref.read(loggingServiceProvider),
    ref,
  );
});

class PlaybackSettingsNotifier extends StateNotifier<PlaybackSettings> {
  final StorageService _storageService;
  final LoggingService _loggingService;
  final Ref _ref;
  
  bool _isInitialized = false;

  PlaybackSettingsNotifier(
    this._storageService,
    this._loggingService,
    this._ref,
  ) : super(PlaybackSettings()) {
    _initializeSettings();
  }

  Future<void> _initializeSettings() async {
    if (_isInitialized) return;
    
    try {
      await loadSettings();
      _isInitialized = true;
      
      _loggingService.logInfo('Playback settings provider initialized successfully');
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to initialize playback settings provider', e, stackTrace);
      _ref.read(lastErrorProvider.notifier).state = 'Failed to load settings: ${e.toString()}';
    }
  }

  Future<void> loadSettings() async {
    try {
      final settings = _storageService.getPlaybackSettings();
      state = settings;
      _loggingService.logDebug('Loaded playback settings');
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to load playback settings', e, stackTrace);
      _ref.read(lastErrorProvider.notifier).state = 'Failed to load settings';
      rethrow;
    }
  }

  Future<bool> updateSettings(PlaybackSettings settings) async {
    try {
      if (!settings.isValid) {
        throw ArgumentError('Invalid playback settings');
      }
      
      await _storageService.savePlaybackSettings(settings);
      state = settings;
      
      _loggingService.logInfo('Updated playback settings');
      return true;
      
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to update playback settings', e, stackTrace);
      _ref.read(lastErrorProvider.notifier).state = 'Failed to update settings: ${e.toString()}';
      return false;
    }
  }

  Future<bool> setShuffleEnabled(bool enabled) async {
    try {
      final newSettings = state.copyWith(shuffleEnabled: enabled);
      final success = await updateSettings(newSettings);
      if (success) {
        _loggingService.logInfo('Shuffle ${enabled ? 'enabled' : 'disabled'}');
      }
      return success;
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to set shuffle enabled', e, stackTrace);
      return false;
    }
  }

  Future<bool> setRepeatMode(RepeatMode mode) async {
    try {
      final newSettings = state.copyWith(repeatMode: mode);
      final success = await updateSettings(newSettings);
      if (success) {
        _loggingService.logInfo('Repeat mode set to: $mode');
      }
      return success;
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to set repeat mode', e, stackTrace);
      return false;
    }
  }

  Future<bool> setPlaybackSpeed(double speed) async {
    try {
      if (speed < 0.25 || speed > 3.0) {
        throw ArgumentError('Playback speed must be between 0.25 and 3.0');
      }
      
      final newSettings = state.copyWith(playbackSpeed: speed);
      final success = await updateSettings(newSettings);
      if (success) {
        _loggingService.logInfo('Playback speed set to: ${speed}x');
      }
      return success;
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to set playback speed', e, stackTrace);
      return false;
    }
  }

  Future<bool> setCrossfadeDuration(int seconds) async {
    try {
      if (seconds < 0 || seconds > 30) {
        throw ArgumentError('Crossfade duration must be between 0 and 30 seconds');
      }
      
      final newSettings = state.copyWith(crossfadeDuration: seconds);
      final success = await updateSettings(newSettings);
      if (success) {
        _loggingService.logInfo('Crossfade duration set to: ${seconds}s');
      }
      return success;
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to set crossfade duration', e, stackTrace);
      return false;
    }
  }

  Future<bool> setGaplessPlayback(bool enabled) async {
    try {
      final newSettings = state.copyWith(gaplessPlayback: enabled);
      final success = await updateSettings(newSettings);
      if (success) {
        _loggingService.logInfo('Gapless playback ${enabled ? 'enabled' : 'disabled'}');
      }
      return success;
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to set gapless playback', e, stackTrace);
      return false;
    }
  }

  Future<bool> setVolume(double volume) async {
    try {
      if (volume < 0.0 || volume > 1.0) {
        throw ArgumentError('Volume must be between 0.0 and 1.0');
      }
      
      final newSettings = state.copyWith(volume: volume);
      final success = await updateSettings(newSettings);
      if (success) {
        _loggingService.logDebug('Volume set to: ${(volume * 100).toInt()}%');
      }
      return success;
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to set volume', e, stackTrace);
      return false;
    }
  }

  Future<bool> setSleepTimerEnabled(bool enabled) async {
    try {
      final newSettings = state.copyWith(sleepTimerEnabled: enabled);
      final success = await updateSettings(newSettings);
      if (success) {
        _loggingService.logInfo('Sleep timer ${enabled ? 'enabled' : 'disabled'}');
      }
      return success;
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to set sleep timer enabled', e, stackTrace);
      return false;
    }
  }

  Future<bool> setSleepTimerDuration(int minutes) async {
    try {
      if (minutes < 1 || minutes > 999) {
        throw ArgumentError('Sleep timer duration must be between 1 and 999 minutes');
      }
      
      final newSettings = state.copyWith(sleepTimerDuration: minutes);
      final success = await updateSettings(newSettings);
      if (success) {
        _loggingService.logInfo('Sleep timer duration set to: ${minutes} minutes');
      }
      return success;
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to set sleep timer duration', e, stackTrace);
      return false;
    }
  }

  Future<bool> setResumeAfterReboot(bool enabled) async {
    try {
      final newSettings = state.copyWith(resumeAfterReboot: enabled);
      final success = await updateSettings(newSettings);
      if (success) {
        _loggingService.logInfo('Resume after reboot ${enabled ? 'enabled' : 'disabled'}');
      }
      return success;
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to set resume after reboot', e, stackTrace);
      return false;
    }
  }

  Future<bool> setEqualizerSettings(Map<String, double> settings) async {
    try {
      // Validate equalizer settings
      for (final entry in settings.entries) {
        if (entry.value < -12.0 || entry.value > 12.0) {
          throw ArgumentError('Equalizer gain must be between -12.0 and 12.0 dB');
        }
      }
      
      final newSettings = state.copyWith(equalizerSettings: settings);
      final success = await updateSettings(newSettings);
      if (success) {
        _loggingService.logInfo('Equalizer settings updated');
      }
      return success;
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to set equalizer settings', e, stackTrace);
      return false;
    }
  }

  Future<bool> resetToDefaults() async {
    try {
      final defaultSettings = PlaybackSettings();
      final success = await updateSettings(defaultSettings);
      if (success) {
        _loggingService.logInfo('Playback settings reset to defaults');
      }
      return success;
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to reset settings to defaults', e, stackTrace);
      return false;
    }
  }
}

// === STREAM PROVIDERS ===

// Current playing song
final currentSongProvider = StreamProvider<MediaItem?>((ref) {
  try {
    final audioHandler = ref.read(audioHandlerProvider);
    return audioHandler.mediaItem;
  } catch (e) {
    ref.read(loggingServiceProvider).logError('Failed to get current song stream', e);
    return Stream.value(null);
  }
});

// Playback state
final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  try {
    final audioHandler = ref.read(audioHandlerProvider);
    return audioHandler.playbackState;
  } catch (e) {
    ref.read(loggingServiceProvider).logError('Failed to get playback state stream', e);
    return Stream.value(PlaybackState());
  }
});

// Queue
final queueProvider = StreamProvider<List<MediaItem>>((ref) {
  try {
    final audioHandler = ref.read(audioHandlerProvider);
    return audioHandler.queue;
  } catch (e) {
    ref.read(loggingServiceProvider).logError('Failed to get queue stream', e);
    return Stream.value([]);
  }
});

// === SEARCH PROVIDERS ===

// Search query
final searchQueryProvider = StateProvider<String>((ref) => '');

// Search results with debouncing
final searchResultsProvider = Provider<List<Song>>((ref) {
  final query = ref.watch(searchQueryProvider);
  final songs = ref.watch(songsProvider);
  
  if (query.trim().isEmpty) return songs;
  
  try {
    final songsNotifier = ref.read(songsProvider.notifier);
    return songsNotifier.searchSongs(query);
  } catch (e) {
    ref.read(loggingServiceProvider).logError('Song search failed', e);
    return [];
  }
});

// Playlist search results
final playlistSearchResultsProvider = Provider<List<Playlist>>((ref) {
  final query = ref.watch(searchQueryProvider);
  final playlists = ref.watch(playlistsProvider);
  
  if (query.trim().isEmpty) return playlists;
  
  try {
    final playlistsNotifier = ref.read(playlistsProvider.notifier);
    return playlistsNotifier.searchPlaylists(query);
  } catch (e) {
    ref.read(loggingServiceProvider).logError('Playlist search failed', e);
    return [];
  }
});

// === COMPUTED PROVIDERS ===

// Recently played songs
final recentlyPlayedProvider = Provider<List<Song>>((ref) {
  try {
    final songsNotifier = ref.read(songsProvider.notifier);
    return songsNotifier.getRecentlyPlayed();
  } catch (e) {
    ref.read(loggingServiceProvider).logError('Failed to get recently played songs', e);
    return [];
  }
});

// Most played songs
final mostPlayedProvider = Provider<List<Song>>((ref) {
  try {
    final songsNotifier = ref.read(songsProvider.notifier);
    return songsNotifier.getMostPlayed();
  } catch (e) {
    ref.read(loggingServiceProvider).logError('Failed to get most played songs', e);
    return [];
  }
});

// Favorite songs
final favoriteSongsProvider = Provider<List<Song>>((ref) {
  try {
    final songsNotifier = ref.read(songsProvider.notifier);
    return songsNotifier.getFavorites();
  } catch (e) {
    ref.read(loggingServiceProvider).logError('Failed to get favorite songs', e);
    return [];
  }
});

// User playlists
final userPlaylistsProvider = Provider<List<Playlist>>((ref) {
  try {
    final playlistsNotifier = ref.read(playlistsProvider.notifier);
    return playlistsNotifier.getUserPlaylists();
  } catch (e) {
    ref.read(loggingServiceProvider).logError('Failed to get user playlists', e);
    return [];
  }
});

// System playlists
final systemPlaylistsProvider = Provider<List<Playlist>>((ref) {
  try {
    final playlistsNotifier = ref.read(playlistsProvider.notifier);
    return playlistsNotifier.getSystemPlaylists();
  } catch (e) {
    ref.read(loggingServiceProvider).logError('Failed to get system playlists', e);
    return [];
  }
});

// === STATISTICS PROVIDERS ===

// Total songs count
final totalSongsCountProvider = Provider<int>((ref) {
  final songs = ref.watch(songsProvider);
  return songs.length;
});

// Total playlists count
final totalPlaylistsCountProvider = Provider<int>((ref) {
  final playlists = ref.watch(playlistsProvider);
  return playlists.length;
});

// Total playtime
final totalPlaytimeProvider = Provider<Duration>((ref) {
  final songs = ref.watch(songsProvider);
  final totalMilliseconds = songs.fold<int>(0, (sum, song) => sum + song.duration);
  return Duration(milliseconds: totalMilliseconds);
});

// === UTILITY PROVIDERS ===

// App initialization status
final appInitializedProvider = Provider<bool>((ref) {
  final songsLoading = ref.watch(songsLoadingProvider);
  final playlistsLoading = ref.watch(playlistsLoadingProvider);
  
  return !songsLoading && !playlistsLoading;
});

// Has any error
final hasErrorProvider = Provider<bool>((ref) {
  final error = ref.watch(lastErrorProvider);
  return error != null;
});
