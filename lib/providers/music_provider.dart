import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../services/custom_audio_handler.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../models/playback_settings.dart';
import '../services/storage_service.dart';
import '../services/metadata_service.dart';

// Services
final storageServiceProvider = Provider<StorageService>((ref) => StorageService());
final metadataServiceProvider = Provider<MetadataService>((ref) => MetadataService());

// Audio handler
final audioHandlerProvider = Provider<CustomAudioHandler>((ref) {
  throw UnimplementedError('Audio handler must be initialized in main()');
});

// Songs
final songsProvider = StateNotifierProvider<SongsNotifier, List<Song>>((ref) {
  return SongsNotifier(ref.read(storageServiceProvider));
});

class SongsNotifier extends StateNotifier<List<Song>> {
  final StorageService _storageService;

  SongsNotifier(this._storageService) : super([]) {
    loadSongs();
  }

  Future<void> loadSongs() async {
    state = _storageService.getAllSongs();
  }

  Future<void> scanDeviceForSongs() async {
    final metadataService = MetadataService();
    final newSongs = await metadataService.scanDeviceForAudioFiles();
    await _storageService.saveSongs(newSongs);
    state = _storageService.getAllSongs();
  }

  Future<void> addSong(Song song) async {
    await _storageService.saveSong(song);
    state = _storageService.getAllSongs();
  }

  Future<void> updateSong(Song song) async {
    await _storageService.saveSong(song);
    state = _storageService.getAllSongs();
  }

  Future<void> deleteSong(String songId) async {
    await _storageService.deleteSong(songId);
    state = _storageService.getAllSongs();
  }

  Future<void> toggleLike(String songId) async {
    await _storageService.toggleSongLike(songId);
    state = _storageService.getAllSongs();
  }

  List<Song> searchSongs(String query) {
    return _storageService.searchSongs(query);
  }

  List<Song> getLikedSongs() {
    return state.where((song) => song.isLiked).toList();
  }

  List<Song> getRecentlyPlayed() {
    final recentlyPlayedPlaylist = _storageService.getPlaylist('recently_played');
    if (recentlyPlayedPlaylist != null) {
      return _storageService.getSongsByIds(recentlyPlayedPlaylist.songIds);
    }
    return [];
  }

  List<Song> getMostPlayed() {
    final mostPlayedPlaylist = _storageService.getPlaylist('most_played');
    if (mostPlayedPlaylist != null) {
      return _storageService.getSongsByIds(mostPlayedPlaylist.songIds);
    }
    return [];
  }
}

// Playlists
final playlistsProvider = StateNotifierProvider<PlaylistsNotifier, List<Playlist>>((ref) {
  return PlaylistsNotifier(ref.read(storageServiceProvider));
});

class PlaylistsNotifier extends StateNotifier<List<Playlist>> {
  final StorageService _storageService;

  PlaylistsNotifier(this._storageService) : super([]) {
    loadPlaylists();
  }

  Future<void> loadPlaylists() async {
    state = _storageService.getAllPlaylists();
  }

  Future<void> createPlaylist(String name, {String? description, String? coverArtPath}) async {
    final playlist = Playlist.create(
      name: name,
      description: description,
      coverArtPath: coverArtPath,
    );
    await _storageService.savePlaylist(playlist);
    state = _storageService.getAllPlaylists();
  }

  Future<void> updatePlaylist(Playlist playlist) async {
    await _storageService.savePlaylist(playlist);
    state = _storageService.getAllPlaylists();
  }

  Future<void> deletePlaylist(String playlistId) async {
    await _storageService.deletePlaylist(playlistId);
    state = _storageService.getAllPlaylists();
  }

  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    final playlist = _storageService.getPlaylist(playlistId);
    if (playlist != null) {
      playlist.addSong(songId);
      await _storageService.savePlaylist(playlist);
      state = _storageService.getAllPlaylists();
    }
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final playlist = _storageService.getPlaylist(playlistId);
    if (playlist != null) {
      playlist.removeSong(songId);
      await _storageService.savePlaylist(playlist);
      state = _storageService.getAllPlaylists();
    }
  }

  List<Playlist> getUserPlaylists() {
    return _storageService.getUserPlaylists();
  }

  List<Playlist> getSystemPlaylists() {
    return _storageService.getSystemPlaylists();
  }

  List<Playlist> searchPlaylists(String query) {
    return _storageService.searchPlaylists(query);
  }
}

// Playback settings
final playbackSettingsProvider = StateNotifierProvider<PlaybackSettingsNotifier, PlaybackSettings>((ref) {
  return PlaybackSettingsNotifier(ref.read(storageServiceProvider));
});

class PlaybackSettingsNotifier extends StateNotifier<PlaybackSettings> {
  final StorageService _storageService;

  PlaybackSettingsNotifier(this._storageService) : super(PlaybackSettings()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    state = _storageService.getPlaybackSettings();
  }

  Future<void> updateSettings(PlaybackSettings settings) async {
    await _storageService.savePlaybackSettings(settings);
    state = settings;
  }

  Future<void> setShuffleEnabled(bool enabled) async {
    final newSettings = state.copyWith(shuffleEnabled: enabled);
    await updateSettings(newSettings);
  }

  Future<void> setRepeatMode(RepeatMode mode) async {
    final newSettings = state.copyWith(repeatMode: mode);
    await updateSettings(newSettings);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    final newSettings = state.copyWith(playbackSpeed: speed);
    await updateSettings(newSettings);
  }

  Future<void> setCrossfadeDuration(int seconds) async {
    final newSettings = state.copyWith(crossfadeDuration: seconds);
    await updateSettings(newSettings);
  }

  Future<void> setGaplessPlayback(bool enabled) async {
    final newSettings = state.copyWith(gaplessPlayback: enabled);
    await updateSettings(newSettings);
  }

  Future<void> setVolume(double volume) async {
    final newSettings = state.copyWith(volume: volume);
    await updateSettings(newSettings);
  }

  Future<void> setSleepTimerEnabled(bool enabled) async {
    final newSettings = state.copyWith(sleepTimerEnabled: enabled);
    await updateSettings(newSettings);
  }

  Future<void> setSleepTimerDuration(int minutes) async {
    final newSettings = state.copyWith(sleepTimerDuration: minutes);
    await updateSettings(newSettings);
  }

  Future<void> setResumeAfterReboot(bool enabled) async {
    final newSettings = state.copyWith(resumeAfterReboot: enabled);
    await updateSettings(newSettings);
  }

  Future<void> setEqualizerSettings(Map<String, double> settings) async {
    final newSettings = state.copyWith(equalizerSettings: settings);
    await updateSettings(newSettings);
  }
}

// Current playing song
final currentSongProvider = StreamProvider<MediaItem?>((ref) {
  final audioHandler = ref.read(audioHandlerProvider);
  return audioHandler.mediaItem;
});

// Playback state
final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  final audioHandler = ref.read(audioHandlerProvider);
  return audioHandler.playbackState;
});

// Queue
final queueProvider = StreamProvider<List<MediaItem>>((ref) {
  final audioHandler = ref.read(audioHandlerProvider);
  return audioHandler.queue;
});

// Search query
final searchQueryProvider = StateProvider<String>((ref) => '');

// Search results
final searchResultsProvider = Provider<List<Song>>((ref) {
  final query = ref.watch(searchQueryProvider);
  final songs = ref.watch(songsProvider);
  
  if (query.isEmpty) return songs;
  
  final lowercaseQuery = query.toLowerCase();
  return songs.where((song) {
    return song.title.toLowerCase().contains(lowercaseQuery) ||
           song.artist.toLowerCase().contains(lowercaseQuery) ||
           song.album.toLowerCase().contains(lowercaseQuery) ||
           (song.genre?.toLowerCase().contains(lowercaseQuery) ?? false);
  }).toList();
});

// Playlist search results
final playlistSearchResultsProvider = Provider<List<Playlist>>((ref) {
  final query = ref.watch(searchQueryProvider);
  final playlists = ref.watch(playlistsProvider);
  
  if (query.isEmpty) return playlists;
  
  final lowercaseQuery = query.toLowerCase();
  return playlists.where((playlist) {
    return playlist.name.toLowerCase().contains(lowercaseQuery) ||
           (playlist.description?.toLowerCase().contains(lowercaseQuery) ?? false);
  }).toList();
});
