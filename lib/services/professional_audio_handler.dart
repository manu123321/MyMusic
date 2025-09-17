import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:rxdart/rxdart.dart';
import 'package:audio_service/audio_service.dart';
import '../models/song.dart';
import '../models/playback_settings.dart';
import '../models/queue_item.dart';
import 'storage_service.dart';
import 'custom_audio_handler.dart';
import 'logging_service.dart';

/// Professional audio handler with reliable song selection and playback
class ProfessionalAudioHandler implements CustomAudioHandler {
  // Core audio components
  final _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);
  
  // Services
  final StorageService _storageService = StorageService();
  final LoggingService _loggingService = LoggingService();
  
  // State management
  PlaybackSettings _settings = PlaybackSettings();
  Timer? _sleepTimer;
  Timer? _positionTimer;
  bool _isInitialized = false;
  bool _isDisposed = false;
  
  // Queue management
  final List<Song> _queue = [];
  int _currentIndex = 0;
  Song? _currentSong;
  
  // Stream controllers with initial values
  final _mediaItemSubject = BehaviorSubject<MediaItem?>.seeded(null);
  final _playbackStateSubject = BehaviorSubject<PlaybackState>();
  final _queueSubject = BehaviorSubject<List<MediaItem>>.seeded([]);
  final _positionSubject = BehaviorSubject<Duration>.seeded(Duration.zero);
  
  // Stream subscriptions
  late final StreamSubscription<PlayerState> _playerStateSub;
  late final StreamSubscription<PlaybackEvent> _playbackEventSub;
  late final StreamSubscription<Duration?> _durationSub;
  late final StreamSubscription<int?> _currentIndexSub;

  ProfessionalAudioHandler() {
    _loggingService.logInfo('Initializing ProfessionalAudioHandler');
    _initializeDefaultState();
  }

  void _initializeDefaultState() {
    _playbackStateSubject.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: AudioProcessingState.idle,
      playing: false,
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
      speed: 1.0,
      queueIndex: null,
    ));
  }

  // Stream getters
  @override
  ValueStream<MediaItem?> get mediaItem => _mediaItemSubject.shareValueSeeded(null);

  @override
  ValueStream<PlaybackState> get playbackState => _playbackStateSubject.shareValue();

  @override
  ValueStream<List<MediaItem>> get queue => _queueSubject.shareValueSeeded([]);
  
  @override
  ValueStream<Duration> get positionStream => _positionSubject.shareValueSeeded(Duration.zero);
  
  @override
  Stream<String> get errorStream => Stream.empty();
  
  @override
  bool get isInitialized => _isInitialized;
  
  @override
  PlaybackSettings get currentSettings => _settings;
  
  @override
  Duration? get currentPosition => _player.position;
  
  @override
  Duration? get currentDuration => _player.duration;

  @override
  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) return;
    
    try {
      _loggingService.logInfo('Starting professional audio handler initialization');
      await _setupAudioSession();
      await _setupPlayerListeners();
      await _loadSettings();
      await _restoreQueue();
      
      _isInitialized = true;
      _loggingService.logInfo('Professional audio handler initialized successfully');
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to initialize professional audio handler', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _setupAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _loggingService.logDebug('Audio session configured');
  }

  Future<void> _setupPlayerListeners() async {
    // Player state listener
    _playerStateSub = _player.playerStateStream.listen(
      (playerState) {
        _updatePlaybackState();
        
        if (playerState.processingState == ProcessingState.completed) {
          _handleSongCompletion();
        }
      },
      onError: (e, stackTrace) {
        _loggingService.logError('Player state stream error', e, stackTrace);
      },
    );

    // Playback event listener
    _playbackEventSub = _player.playbackEventStream.listen(
      (event) {
        _updatePlaybackState();
      },
      onError: (e, stackTrace) {
        _loggingService.logError('Playback event stream error', e, stackTrace);
      },
    );

    // Duration listener
    _durationSub = _player.durationStream.listen(
      (duration) {
        _updatePlaybackState();
      },
      onError: (e, stackTrace) {
        _loggingService.logError('Duration stream error', e, stackTrace);
      },
    );

    // Current index listener - CRITICAL for proper song tracking
    _currentIndexSub = _player.currentIndexStream.listen(
      (index) {
        _handleIndexChange(index);
      },
      onError: (e, stackTrace) {
        _loggingService.logError('Current index stream error', e, stackTrace);
      },
    );

    _loggingService.logDebug('Player listeners setup complete');
  }

  void _handleIndexChange(int? index) {
    if (index == null) {
      _loggingService.logDebug('Index is null, no current song');
      _currentSong = null;
      _currentIndex = 0;
      _mediaItemSubject.add(null);
      _updatePlaybackState();
      return;
    }

    if (index < 0 || index >= _queue.length) {
      _loggingService.logWarning('Invalid index: $index (queue length: ${_queue.length})');
      return;
    }

    // Only update if index actually changed
    if (_currentIndex != index) {
      final previousSong = _currentSong?.title ?? 'None';
      _currentIndex = index;
      _currentSong = _queue[index];
      
      _loggingService.logInfo('Song changed from "$previousSong" to "${_currentSong!.title}" (index: $index)');
      
      // Update media item
      final mediaItem = _songToMediaItem(_currentSong!);
      _mediaItemSubject.add(mediaItem);
      
      // Update playback state
      _updatePlaybackState();
      
      // Update song statistics asynchronously
      _updateSongStatistics(_currentSong!.id);
    }
  }

  void _handleSongCompletion() {
    _loggingService.logInfo('Song completed: ${_currentSong?.title ?? "Unknown"}');
    
    // Let just_audio handle the advancement automatically
    // We only intervene if we need to add more songs to the queue
    if (_currentIndex >= _queue.length - 2) { // Near end of queue
      _loggingService.logInfo('Near end of queue, adding more songs');
      _addMoreSongsToQueue();
    }
  }

  Future<void> _loadSettings() async {
    try {
      _settings = _storageService.getPlaybackSettings();
      await _applySettings();
      _loggingService.logDebug('Settings loaded and applied');
    } catch (e, stackTrace) {
      _loggingService.logError('Error loading settings', e, stackTrace);
      // Continue with defaults
    }
  }

  Future<void> _applySettings() async {
    try {
      await _player.setShuffleModeEnabled(_settings.shuffleEnabled);
      await _player.setSpeed(_settings.playbackSpeed.clamp(0.25, 3.0));
      await _player.setVolume(_settings.volume.clamp(0.0, 1.0));

      // Apply repeat mode
      switch (_settings.repeatMode) {
        case RepeatMode.none:
          await _player.setLoopMode(LoopMode.off);
          break;
        case RepeatMode.one:
          await _player.setLoopMode(LoopMode.one);
          break;
        case RepeatMode.all:
          await _player.setLoopMode(LoopMode.all);
          break;
      }
      
      _loggingService.logDebug('Settings applied successfully');
    } catch (e, stackTrace) {
      _loggingService.logError('Error applying settings', e, stackTrace);
    }
  }

  // CORE PLAYBACK METHODS

  @override
  Future<void> setQueue(List<MediaItem> items) async {
    try {
      if (items.isEmpty) {
        await clearQueue();
        return;
      }

      _loggingService.logInfo('Setting queue with ${items.length} items');
      
      // Stop current playback
      await _player.stop();
      
      // Clear existing queue
      await _playlist.clear();
      _queue.clear();
      
      // Convert MediaItems to Songs
      final songs = items.map(_mediaItemToSong).toList();
      
      // CRITICAL: Add selected song first, then additional songs
      _queue.add(songs.first); // Selected song at index 0
      
      // Add more songs for continuous playback (but not if we already have multiple)
      if (items.length == 1) {
        final additionalSongs = await _getAdditionalSongs(songs.first);
        _queue.addAll(additionalSongs);
      } else {
        _queue.addAll(songs.skip(1)); // Add remaining selected songs
      }
      
      // Create audio sources
      final sources = _queue.map((song) => 
          AudioSource.uri(Uri.file(song.filePath))).toList();
      await _playlist.addAll(sources);
      
      // Set audio source starting from index 0 (selected song)
      await _player.setAudioSource(_playlist, initialIndex: 0);
      
      // Update state
      _currentIndex = 0;
      _currentSong = _queue.first;
      
      // Update streams
      final mediaItems = _queue.map(_songToMediaItem).toList();
      _queueSubject.add(mediaItems);
      _mediaItemSubject.add(_songToMediaItem(_currentSong!));
      
      _updatePlaybackState();
      await _saveQueue();
      
      // CRITICAL FIX: Start position tracking immediately for first song
      _startPositionTimer();
      
      _loggingService.logInfo('Queue set successfully. Playing: ${_currentSong!.title}');
      
    } catch (e, stackTrace) {
      _loggingService.logError('Error setting queue', e, stackTrace);
      rethrow;
    }
  }

  Future<List<Song>> _getAdditionalSongs(Song selectedSong) async {
    try {
      final allSongs = _storageService.getAllSongs();
      
      // Get songs excluding the selected one
      final otherSongs = allSongs.where((s) => s.id != selectedSong.id).toList();
      
      if (otherSongs.isEmpty) return [];
      
      // PROFESSIONAL APPROACH: Predictable order for better UX
      // Sort by artist, then album, then track number for logical progression
      otherSongs.sort((a, b) {
        // First, try to group by same artist as selected song
        if (a.artist == selectedSong.artist && b.artist != selectedSong.artist) return -1;
        if (b.artist == selectedSong.artist && a.artist != selectedSong.artist) return 1;
        
        // Then by artist name
        final artistCompare = a.artist.compareTo(b.artist);
        if (artistCompare != 0) return artistCompare;
        
        // Then by album
        final albumCompare = a.album.compareTo(b.album);
        if (albumCompare != 0) return albumCompare;
        
        // Finally by track number
        return (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0);
      });
      
      final additionalSongs = otherSongs.take(20).toList();
      
      // Validate songs
      final validSongs = <Song>[];
      for (final song in additionalSongs) {
        if (await _validateSongFile(song)) {
          validSongs.add(song);
        }
      }
      
      _loggingService.logInfo('Added ${validSongs.length} additional songs for continuous playback');
      return validSongs;
      
    } catch (e, stackTrace) {
      _loggingService.logError('Error getting additional songs', e, stackTrace);
      return [];
    }
  }

  Future<bool> _validateSongFile(Song song) async {
    try {
      final file = File(song.filePath);
      final exists = await file.exists();
      if (!exists) return false;
      
      final size = await file.length();
      return size > 0;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> play() async {
    try {
      _loggingService.logInfo('Play command - Current song: ${_currentSong?.title ?? "None"}');
      
      if (_currentSong == null) {
        _loggingService.logWarning('No current song to play');
        return;
      }
      
      // Update state immediately for responsive UI
      _playbackStateSubject.add(
        _playbackStateSubject.value.copyWith(
          playing: true,
          controls: [
            MediaControl.skipToPrevious,
            MediaControl.pause,
            MediaControl.skipToNext,
          ],
        ),
      );
      
      await _player.play();
      _startPositionTimer();
      
      _loggingService.logInfo('Playback started: ${_currentSong!.title}');
      
    } catch (e, stackTrace) {
      _loggingService.logError('Error during play', e, stackTrace);
      // Revert state on error
      _playbackStateSubject.add(
        _playbackStateSubject.value.copyWith(playing: false),
      );
      rethrow;
    }
  }

  @override
  Future<void> pause() async {
    try {
      _loggingService.logInfo('Pause command');
      
      // Update state immediately for responsive UI
      _playbackStateSubject.add(
        _playbackStateSubject.value.copyWith(
          playing: false,
          controls: [
            MediaControl.skipToPrevious,
            MediaControl.play,
            MediaControl.skipToNext,
          ],
        ),
      );
      
      await _player.pause();
      _stopPositionTimer();
      
      _loggingService.logInfo('Playback paused');
      
    } catch (e, stackTrace) {
      _loggingService.logError('Error during pause', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    try {
      _loggingService.logInfo('Stop command');
      
      await _player.stop();
      _stopPositionTimer();
      
      _mediaItemSubject.add(null);
      _positionSubject.add(Duration.zero);
      _updatePlaybackState();
      
      _loggingService.logInfo('Playback stopped');
      
    } catch (e, stackTrace) {
      _loggingService.logError('Error during stop', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      _loggingService.logDebug('Seek to: ${position.inSeconds}s');
      
      await _player.seek(position);
      _positionSubject.add(position);
      _updatePlaybackState();
      
    } catch (e, stackTrace) {
      _loggingService.logError('Error during seek', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> skipToNext() async {
    try {
      if (_queue.isEmpty) {
        _loggingService.logWarning('No songs in queue for skip next');
        return;
      }
      
      final nextIndex = _currentIndex + 1;
      
      if (nextIndex < _queue.length) {
        _loggingService.logInfo('Skipping to next: ${_queue[nextIndex].title}');
        await _player.seek(Duration.zero, index: nextIndex);
      } else {
        _loggingService.logInfo('At end of queue, adding more songs');
        await _addMoreSongsToQueue();
        
        if (_currentIndex + 1 < _queue.length) {
          await _player.seek(Duration.zero, index: _currentIndex + 1);
        }
      }
      
    } catch (e, stackTrace) {
      _loggingService.logError('Error skipping to next', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> skipToPrevious() async {
    try {
      if (_queue.isEmpty) {
        _loggingService.logWarning('No songs in queue for skip previous');
        return;
      }
      
      if (_currentIndex > 0) {
        final prevIndex = _currentIndex - 1;
        _loggingService.logInfo('Skipping to previous: ${_queue[prevIndex].title}');
        await _player.seek(Duration.zero, index: prevIndex);
      } else {
        _loggingService.logInfo('At beginning, restarting current song');
        await _player.seek(Duration.zero);
      }
      
    } catch (e, stackTrace) {
      _loggingService.logError('Error skipping to previous', e, stackTrace);
      rethrow;
    }
  }

  // Position timer for smooth progress bars
  void _startPositionTimer() {
    _stopPositionTimer();
    
    _positionTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isDisposed) {
        final position = _player.position;
        _positionSubject.add(position);
        
        // CRITICAL FIX: Always update position, even when not playing
        // This ensures progress bar works immediately on first song
        if (_player.playing || _currentSong != null) {
          _updatePlaybackState();
        }
      }
    });
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  void _updatePlaybackState() {
    try {
      final playing = _player.playing;
      final processingState = _player.processingState;
      final position = _player.position;
      final bufferedPosition = _player.bufferedPosition;
      final speed = _player.speed;
      final currentIndex = _player.currentIndex;

      final controls = <MediaControl>[
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ];

      final newState = PlaybackState(
        controls: controls,
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _mapProcessingState(processingState),
        playing: playing,
        updatePosition: position,
        bufferedPosition: bufferedPosition,
        speed: speed,
        queueIndex: currentIndex,
        repeatMode: _mapRepeatMode(_settings.repeatMode),
        shuffleMode: _settings.shuffleEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
      );

      _playbackStateSubject.add(newState);
      
    } catch (e, stackTrace) {
      _loggingService.logError('Error updating playback state', e, stackTrace);
    }
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  AudioServiceRepeatMode _mapRepeatMode(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.none:
        return AudioServiceRepeatMode.none;
      case RepeatMode.one:
        return AudioServiceRepeatMode.one;
      case RepeatMode.all:
        return AudioServiceRepeatMode.all;
    }
  }

  MediaItem _songToMediaItem(Song song) {
    return MediaItem(
      id: song.filePath,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: Duration(milliseconds: song.duration),
      artUri: song.albumArtPath != null ? Uri.file(song.albumArtPath!) : null,
      extras: {
        'songId': song.id,
        'trackNumber': song.trackNumber,
        'year': song.year,
        'genre': song.genre,
        'isFavorite': song.isFavorite,
        'rating': song.rating,
      },
    );
  }

  Song _mediaItemToSong(MediaItem item) {
    return Song(
      id: item.extras?['songId'] ?? item.id,
      title: item.title,
      artist: item.artist ?? 'Unknown Artist',
      album: item.album ?? 'Unknown Album',
      filePath: item.id,
      duration: item.duration?.inMilliseconds ?? 0,
      albumArtPath: item.artUri?.toFilePath(),
      trackNumber: item.extras?['trackNumber'],
      year: item.extras?['year'],
      genre: item.extras?['genre'],
      dateAdded: DateTime.now(),
      playCount: 0,
      isFavorite: item.extras?['isFavorite'] ?? false,
      rating: item.extras?['rating'],
    );
  }

  Future<void> _addMoreSongsToQueue() async {
    try {
      final allSongs = _storageService.getAllSongs();
      final currentSongIds = _queue.map((s) => s.id).toSet();
      final remainingSongs = allSongs.where((s) => !currentSongIds.contains(s.id)).toList();
      
      if (remainingSongs.isEmpty) {
        _loggingService.logInfo('No more songs to add to queue');
        return;
      }
      
      // PROFESSIONAL APPROACH: Predictable continuation
      // Sort remaining songs in the same logical order as _getAdditionalSongs
      remainingSongs.sort((a, b) {
        final artistCompare = a.artist.compareTo(b.artist);
        if (artistCompare != 0) return artistCompare;
        
        final albumCompare = a.album.compareTo(b.album);
        if (albumCompare != 0) return albumCompare;
        
        return (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0);
      });
      
      final songsToAdd = remainingSongs.take(10).toList();
      
      // Validate and add songs
      final validSongs = <Song>[];
      for (final song in songsToAdd) {
        if (await _validateSongFile(song)) {
          validSongs.add(song);
        }
      }
      
      if (validSongs.isNotEmpty) {
        _queue.addAll(validSongs);
        
        final additionalSources = validSongs.map((song) => 
            AudioSource.uri(Uri.file(song.filePath))).toList();
        await _playlist.addAll(additionalSources);
        
        // Update queue stream
        final mediaItems = _queue.map(_songToMediaItem).toList();
        _queueSubject.add(mediaItems);
        
        await _saveQueue();
        
        _loggingService.logInfo('Added ${validSongs.length} more songs to queue');
      }
      
    } catch (e, stackTrace) {
      _loggingService.logError('Error adding more songs to queue', e, stackTrace);
    }
  }

  Future<void> _saveQueue() async {
    try {
      final queueItems = _queue.asMap().entries.map((entry) {
        return QueueItem(
          songId: entry.value.id,
          position: entry.key,
          addedAt: DateTime.now(),
        );
      }).toList();
      await _storageService.saveQueue(queueItems);
    } catch (e, stackTrace) {
      _loggingService.logError('Error saving queue', e, stackTrace);
    }
  }

  Future<void> _restoreQueue() async {
    try {
      final queueItems = _storageService.getQueue();
      if (queueItems.isNotEmpty) {
        _loggingService.logInfo('Restoring queue with ${queueItems.length} items');
        
        final songIds = queueItems.map((q) => q.songId).toList();
        final songs = _storageService.getSongsByIds(songIds);
        
        if (songs.isNotEmpty) {
          final mediaItems = songs.map(_songToMediaItem).toList();
          await setQueue(mediaItems);
        }
      }
    } catch (e, stackTrace) {
      _loggingService.logError('Error restoring queue', e, stackTrace);
    }
  }

  Future<void> _updateSongStatistics(String songId) async {
    try {
      await _storageService.updateSongPlayCount(songId);
      await _storageService.addToRecentlyPlayed(songId);
    } catch (e, stackTrace) {
      _loggingService.logError('Error updating song statistics', e, stackTrace);
    }
  }

  // Implement remaining interface methods...
  @override
  Future<void> addQueueItems(List<MediaItem> items) async {
    try {
      final songs = items.map(_mediaItemToSong).toList();
      _queue.addAll(songs);
      
      final sources = items.map((item) => 
          AudioSource.uri(Uri.file(item.id))).toList();
      await _playlist.addAll(sources);
      
      final mediaItems = _queue.map(_songToMediaItem).toList();
      _queueSubject.add(mediaItems);
      
      await _saveQueue();
    } catch (e, stackTrace) {
      _loggingService.logError('Error adding queue items', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) => addQueueItems([mediaItem]);

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    try {
      final index = _queue.indexWhere((s) => s.filePath == mediaItem.id);
      if (index != -1) {
        _queue.removeAt(index);
        await _playlist.removeAt(index);
        
        final mediaItems = _queue.map(_songToMediaItem).toList();
        _queueSubject.add(mediaItems);
        
        await _saveQueue();
      }
    } catch (e, stackTrace) {
      _loggingService.logError('Error removing queue item', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> clearQueue() async {
    try {
      await _player.stop();
      await _playlist.clear();
      _queue.clear();
      _currentIndex = 0;
      _currentSong = null;
      
      _mediaItemSubject.add(null);
      _queueSubject.add([]);
      _positionSubject.add(Duration.zero);
      _updatePlaybackState();
      
      await _saveQueue();
    } catch (e, stackTrace) {
      _loggingService.logError('Error clearing queue', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    try {
      RepeatMode newMode;
      switch (repeatMode) {
        case AudioServiceRepeatMode.none:
          newMode = RepeatMode.none;
          await _player.setLoopMode(LoopMode.off);
          break;
        case AudioServiceRepeatMode.one:
          newMode = RepeatMode.one;
          await _player.setLoopMode(LoopMode.one);
          break;
        case AudioServiceRepeatMode.all:
          newMode = RepeatMode.all;
          await _player.setLoopMode(LoopMode.all);
          break;
        case AudioServiceRepeatMode.group:
          newMode = RepeatMode.none;
          await _player.setLoopMode(LoopMode.off);
          break;
      }
      
      _settings = _settings.copyWith(repeatMode: newMode);
      await _storageService.savePlaybackSettings(_settings);
      _updatePlaybackState();
      
    } catch (e, stackTrace) {
      _loggingService.logError('Error setting repeat mode', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> setShuffleModeEnabled(bool enabled) async {
    try {
      await _player.setShuffleModeEnabled(enabled);
      _settings = _settings.copyWith(shuffleEnabled: enabled);
      await _storageService.savePlaybackSettings(_settings);
      _updatePlaybackState();
    } catch (e, stackTrace) {
      _loggingService.logError('Error setting shuffle mode', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    try {
      final clampedSpeed = speed.clamp(0.25, 3.0);
      await _player.setSpeed(clampedSpeed);
      _settings = _settings.copyWith(playbackSpeed: clampedSpeed);
      await _storageService.savePlaybackSettings(_settings);
      _updatePlaybackState();
    } catch (e, stackTrace) {
      _loggingService.logError('Error setting playback speed', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    try {
      final clampedVolume = volume.clamp(0.0, 1.0);
      await _player.setVolume(clampedVolume);
      _settings = _settings.copyWith(volume: clampedVolume);
      await _storageService.savePlaybackSettings(_settings);
    } catch (e, stackTrace) {
      _loggingService.logError('Error setting volume', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> startSleepTimer(int minutes) async {
    try {
      _sleepTimer?.cancel();
      _sleepTimer = Timer(Duration(minutes: minutes), () {
        pause();
        _loggingService.logInfo('Sleep timer triggered - pausing playback');
      });
      
      _settings = _settings.copyWith(
        sleepTimerEnabled: true,
        sleepTimerDuration: minutes,
      );
      await _storageService.savePlaybackSettings(_settings);
      
      _loggingService.logInfo('Sleep timer started: $minutes minutes');
    } catch (e, stackTrace) {
      _loggingService.logError('Error starting sleep timer', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> cancelSleepTimer() async {
    try {
      _sleepTimer?.cancel();
      _sleepTimer = null;
      _settings = _settings.copyWith(sleepTimerEnabled: false);
      await _storageService.savePlaybackSettings(_settings);
      _loggingService.logInfo('Sleep timer cancelled');
    } catch (e, stackTrace) {
      _loggingService.logError('Error cancelling sleep timer', e, stackTrace);
      rethrow;
    }
  }

  // Implement remaining interface methods with no-op or basic implementations
  @override
  Future<void> setEqualizerSettings(Map<String, double> settings) async {
    _settings = _settings.copyWith(equalizerSettings: settings);
    await _storageService.savePlaybackSettings(_settings);
  }

  @override
  Future<void> setCrossfadeDuration(int seconds) async {
    _settings = _settings.copyWith(crossfadeDuration: seconds);
    await _storageService.savePlaybackSettings(_settings);
  }

  @override
  Future<void> setGaplessPlayback(bool enabled) async {
    _settings = _settings.copyWith(gaplessPlayback: enabled);
    await _storageService.savePlaybackSettings(_settings);
  }

  @override
  Future<void> setBassBoost(double boost) async {
    _settings = _settings.copyWith(bassBoost: boost);
    await _storageService.savePlaybackSettings(_settings);
  }

  @override
  Future<void> setTrebleBoost(double boost) async {
    _settings = _settings.copyWith(trebleBoost: boost);
    await _storageService.savePlaybackSettings(_settings);
  }

  @override
  Future<void> setSkipSilence(bool skip) async {
    _settings = _settings.copyWith(skipSilence: skip);
    await _storageService.savePlaybackSettings(_settings);
  }

  @override
  Future<void> recover() async {
    try {
      _loggingService.logInfo('Recovering audio handler');
      if (!_isInitialized) {
        await initialize();
      }
    } catch (e, stackTrace) {
      _loggingService.logError('Error during recovery', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    _loggingService.logDebug('Custom action: $name');
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    try {
      _loggingService.logInfo('Disposing professional audio handler');
      _isDisposed = true;
      
      _sleepTimer?.cancel();
      _stopPositionTimer();
      
      await _playerStateSub.cancel();
      await _playbackEventSub.cancel();
      await _durationSub.cancel();
      await _currentIndexSub.cancel();
      
      await _saveQueue();
      await _player.dispose();
      
      await _mediaItemSubject.close();
      await _playbackStateSubject.close();
      await _queueSubject.close();
      await _positionSubject.close();
      
      _loggingService.logInfo('Professional audio handler disposed');
    } catch (e, stackTrace) {
      _loggingService.logError('Error disposing audio handler', e, stackTrace);
    }
  }
}
