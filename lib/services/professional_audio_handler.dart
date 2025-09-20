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
class ProfessionalAudioHandler extends BaseAudioHandler 
    with QueueHandler, SeekHandler implements CustomAudioHandler {
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

  // Stream getters - Override BaseAudioHandler properties
  @override
  BehaviorSubject<MediaItem?> get mediaItem => _mediaItemSubject;

  @override
  BehaviorSubject<PlaybackState> get playbackState => _playbackStateSubject;

  @override
  BehaviorSubject<List<MediaItem>> get queue => _queueSubject;
  
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
      
      // Media session integration is handled by SystemMediaHandler
      
      // Update playback state
      _updatePlaybackState();
      
      // Update song statistics asynchronously
      _updateSongStatistics(_currentSong!.id);
    }
  }

  void _handleSongCompletion() {
    _loggingService.logInfo('Song completed: ${_currentSong?.title ?? "Unknown"}');
    
    // Check if we're at the last song with repeat off
    final isLastSong = _currentIndex == _queue.length - 1;
    final shouldStop = isLastSong && _settings.repeatMode == RepeatMode.none;
    
    if (shouldStop) {
      // Last song completed with repeat off - update UI to show stopped state
      _loggingService.logInfo('Last song completed with repeat off - updating UI to stopped state');
      
      // Update playback state to show play button (not pause)
      Future.microtask(() {
        if (!_isDisposed) {
          _playbackStateSubject.add(
            _playbackStateSubject.value.copyWith(
              playing: false, // Show play button
              processingState: AudioProcessingState.ready, // Ready to play again
              controls: [
                MediaControl.skipToPrevious,
                MediaControl.play, // Play button (not pause)
                MediaControl.skipToNext,
              ],
            ),
          );
          
          // Keep position timer running but in paused mode for UI updates
          _startPositionTimer(pausedMode: true);
        }
      });
    } else {
      // just_audio handles other cases automatically:
      // - LoopMode.all: Continues to first song after last
      // - LoopMode.one: Repeats current song
      _loggingService.logInfo('Automatic progression handled by just_audio LoopMode: ${_settings.repeatMode}');
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
      
      // Check if this is a single song (individual play) or multiple songs (playlist play)
      if (items.length == 1) {
        // SINGLE SONG: Load ALL songs in alphabetical order for circular navigation
        _loggingService.logInfo('Single song play - enabling circular navigation with all songs');
        await _buildCircularQueue(items.first);
      } else {
        // PLAYLIST: Use only the provided songs in the exact order they were provided
        _loggingService.logInfo('Playlist play - using only provided songs in exact order');
        await _buildPlaylistQueue(items);
      }
      
      // Create audio sources
      final sources = _queue.map((song) => 
          AudioSource.uri(Uri.file(song.filePath))).toList();
      await _playlist.addAll(sources);
      
      // Find the index of the selected song in the queue
      final selectedSong = _mediaItemToSong(items.first);
      final selectedIndex = _queue.indexWhere((s) => s.id == selectedSong.id);
      
      // Set audio source starting from selected song index
      await _player.setAudioSource(_playlist, initialIndex: selectedIndex >= 0 ? selectedIndex : 0);
      
      // Update state
      _currentIndex = selectedIndex >= 0 ? selectedIndex : 0;
      _currentSong = _queue[_currentIndex];
      
      // Update streams
      final mediaItems = _queue.map(_songToMediaItem).toList();
      _queueSubject.add(mediaItems);
      _mediaItemSubject.add(_songToMediaItem(_currentSong!));
      
      _updatePlaybackState();
      await _saveQueue();
      
      // CRITICAL FIX: Start position tracking immediately for first song
      _startPositionTimer(pausedMode: false);
      
      _loggingService.logInfo('Queue built with ${_queue.length} songs. Playing: ${_currentSong!.title} (index: $_currentIndex)');
      
    } catch (e, stackTrace) {
      _loggingService.logError('Error setting queue', e, stackTrace);
      rethrow;
    }
  }

  /// Builds a circular queue with ALL songs in the EXACT SAME ORDER as home screen
  Future<void> _buildCircularQueue(MediaItem selectedItem) async {
    try {
      // Get ALL songs from storage in the EXACT SAME ORDER as home screen
      final allSongs = _storageService.getAllSongs();
      
      if (allSongs.isEmpty) {
        _loggingService.logWarning('No songs available for circular queue');
        return;
      }
      
      // CRITICAL: Use the EXACT SAME ORDER as home screen (storage order)
      // NO SORTING - keep the natural order that users see on home screen
      final songsInDisplayOrder = List<Song>.from(allSongs);
      
      // Validate and add all songs in display order
      final validSongs = <Song>[];
      for (final song in songsInDisplayOrder) {
        if (await _validateSongFile(song)) {
          validSongs.add(song);
        }
      }
      
      _queue.addAll(validSongs);
      
      _loggingService.logInfo('Built circular queue with ${_queue.length} songs in HOME SCREEN ORDER (no sorting)');
      
    } catch (e, stackTrace) {
      _loggingService.logError('Error building circular queue', e, stackTrace);
      rethrow;
    }
  }

  /// Builds a playlist queue with only the provided songs in the exact order they were provided
  Future<void> _buildPlaylistQueue(List<MediaItem> items) async {
    try {
      _loggingService.logInfo('Building playlist queue with ${items.length} songs in provided order');
      
      // Convert MediaItems to Songs and validate files
      final validSongs = <Song>[];
      for (final item in items) {
        final song = _mediaItemToSong(item);
        if (await _validateSongFile(song)) {
          validSongs.add(song);
        } else {
          _loggingService.logWarning('Skipping invalid song file: ${song.title}');
        }
      }
      
      _queue.addAll(validSongs);
      
      _loggingService.logInfo('Built playlist queue with ${_queue.length} valid songs in EXACT PROVIDED ORDER');
      
    } catch (e, stackTrace) {
      _loggingService.logError('Error building playlist queue', e, stackTrace);
      rethrow;
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
      
      // Check if player is in stopped/completed state and needs to be restarted
      final processingState = _player.processingState;
      if (processingState == ProcessingState.completed || processingState == ProcessingState.idle) {
        _loggingService.logInfo('Player in completed/idle state, seeking to restart from beginning');
        // Seek to beginning of current song to restart properly
        await _player.seek(Duration.zero, index: _currentIndex);
        // Ensure position is reset to zero
        _positionSubject.add(Duration.zero);
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
      
      // Always start position timer when playing starts
      _startPositionTimer(pausedMode: false);
      
      // Force immediate position update after a short delay to ensure progress bar starts
      Future.delayed(const Duration(milliseconds: 50), () {
        if (!_isDisposed && _player.playing) {
          final currentPosition = _player.position;
          _positionSubject.add(currentPosition);
          _updatePlaybackState();
        }
      });
      
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
      
      // CRITICAL FIX: Don't stop position timer completely during pause
      // Keep updating position so progress bar shows correct paused position
      // Just reduce update frequency to save battery
      _startPositionTimer(pausedMode: true);
      
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
      
      // Keep current media item visible in UI (don't set to null)
      // This prevents "No song playing" message when stopped at end of playlist
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
      
      final currentIndex = _currentIndex;
      final isLastSong = currentIndex == _queue.length - 1;
      
      // Respect repeat mode for manual skip
      if (isLastSong && _settings.repeatMode == RepeatMode.none) {
        // At last song with no repeat - restart current song (consistent with backward behavior)
        _loggingService.logInfo('SKIP NEXT: At last song with no repeat - restarting current song');
        await _player.seek(Duration.zero);
        return;
      }
      
      // Calculate next index based on repeat mode
      int nextIndex;
      if (_settings.repeatMode == RepeatMode.one) {
        // Repeat one - stay on current song
        nextIndex = currentIndex;
        _loggingService.logInfo('SKIP NEXT: Repeat one - staying on current song');
      } else {
        // Repeat all or normal progression
        nextIndex = isLastSong ? 0 : currentIndex + 1;
        final behavior = _settings.repeatMode == RepeatMode.all ? 'REPEAT ALL' : 'NORMAL';
        _loggingService.logInfo('SKIP NEXT ($behavior): ${_queue[currentIndex].title} → ${_queue[nextIndex].title} ($currentIndex → $nextIndex)');
      }
      
      await _player.seek(Duration.zero, index: nextIndex);
      
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
      
      final currentIndex = _currentIndex;
      final isFirstSong = currentIndex == 0;
      
      // Respect repeat mode for manual skip
      if (isFirstSong && _settings.repeatMode == RepeatMode.none) {
        // At first song with no repeat - stay on first song or restart it
        _loggingService.logInfo('SKIP PREVIOUS: At first song with no repeat - restarting current song');
        await _player.seek(Duration.zero);
        return;
      }
      
      // Calculate previous index based on repeat mode
      int prevIndex;
      if (_settings.repeatMode == RepeatMode.one) {
        // Repeat one - stay on current song
        prevIndex = currentIndex;
        _loggingService.logInfo('SKIP PREVIOUS: Repeat one - staying on current song');
      } else {
        // Repeat all or normal progression
        prevIndex = isFirstSong ? _queue.length - 1 : currentIndex - 1;
        final behavior = _settings.repeatMode == RepeatMode.all ? 'REPEAT ALL' : 'NORMAL';
        _loggingService.logInfo('SKIP PREVIOUS ($behavior): ${_queue[currentIndex].title} → ${_queue[prevIndex].title} ($currentIndex → $prevIndex)');
      }
      
      await _player.seek(Duration.zero, index: prevIndex);
      
    } catch (e, stackTrace) {
      _loggingService.logError('Error skipping to previous', e, stackTrace);
      rethrow;
    }
  }

  // Position timer for smooth progress bars
  void _startPositionTimer({bool pausedMode = false}) {
    _stopPositionTimer();
    
    // Use different update frequencies for playing vs paused states
    final updateInterval = pausedMode 
        ? const Duration(milliseconds: 500)  // Slower updates when paused to save battery
        : const Duration(milliseconds: 100); // Fast updates when playing for smooth progress
    
    _positionTimer = Timer.periodic(updateInterval, (timer) {
      if (!_isDisposed && _currentSong != null) {
        final position = _player.position;
        final duration = _player.duration;
        
        // Always update position stream
        _positionSubject.add(position);
        
        // Always update playback state to keep UI in sync
        _updatePlaybackState();
        
        // Log position updates for debugging (only in playing mode to avoid spam)
        if (!pausedMode && _player.playing) {
          _loggingService.logDebug('Position update: ${position.inSeconds}s / ${duration?.inSeconds ?? 0}s');
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

      // Special case: if song completed and we're at last song with repeat off
      final isLastSong = _currentIndex == _queue.length - 1;
      final shouldShowStopped = processingState == ProcessingState.completed && 
                                isLastSong && 
                                _settings.repeatMode == RepeatMode.none;

      // Override playing state if song completed at end of playlist
      final effectivePlaying = shouldShowStopped ? false : playing;

      final controls = <MediaControl>[
        MediaControl.skipToPrevious,
        if (effectivePlaying) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ];

      final newState = PlaybackState(
        controls: controls,
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.setRating,
          MediaAction.setRepeatMode,
          MediaAction.setShuffleMode,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _mapProcessingState(processingState),
        playing: effectivePlaying,
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
      
      // Media session state is handled by SystemMediaHandler automatically
      
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
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    try {
      final songs = mediaItems.map(_mediaItemToSong).toList();
      _queue.addAll(songs);
      
      final sources = mediaItems.map((item) => 
          AudioSource.uri(Uri.file(item.id))).toList();
      await _playlist.addAll(sources);
      
      final queueMediaItems = _queue.map(_songToMediaItem).toList();
      _queueSubject.add(queueMediaItems);
      
      await _saveQueue();
    } catch (e, stackTrace) {
      _loggingService.logError('Error adding queue items', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) => addQueueItems([mediaItem]);

  @override
  Future<void> addQueueItemAt(MediaItem mediaItem, int index) async {
    try {
      final song = _mediaItemToSong(mediaItem);
      final source = AudioSource.uri(Uri.file(mediaItem.id));
      
      // Insert at the specified index
      _queue.insert(index, song);
      await _playlist.insert(index, source);
      
      final queueMediaItems = _queue.map(_songToMediaItem).toList();
      _queueSubject.add(queueMediaItems);
      
      _loggingService.logInfo('Added song to queue at index $index: ${song.title}');
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to add song to queue at index $index', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> reorderQueue(List<MediaItem> newOrder) async {
    try {
      _loggingService.logInfo('Reordering upcoming songs without interrupting current playback');
      
      // Store current playback state
      final currentPosition = _player.position;
      final isPlaying = _player.playing;
      final currentIndex = _player.currentIndex;
      
      // Convert MediaItems to Songs
      final newSongs = newOrder.map(_mediaItemToSong).toList();
      
      // Update internal queue
      _queue.clear();
      _queue.addAll(newSongs);
      
      // Update queue state
      final queueMediaItems = _queue.map(_songToMediaItem).toList();
      _queueSubject.add(queueMediaItems);
      
      // Since we only reorder upcoming songs (current song stays at index 0),
      // we need to rebuild the playlist to reflect the new order of upcoming songs
      await _playlist.clear();
      final sources = newSongs.map((song) => 
          AudioSource.uri(Uri.file(song.filePath))).toList();
      await _playlist.addAll(sources);
      
      // Restore playback to current song at index 0 with exact position
      if (currentIndex != null && currentIndex == 0) {
        // Current song is at index 0, restore exact position
        await _player.seek(currentPosition, index: 0);
        if (isPlaying) {
          // Small delay to ensure seek completes before playing
          await Future.delayed(const Duration(milliseconds: 100));
          await _player.play();
        }
      } else {
        // Fallback: seek to beginning of current song
        await _player.seek(Duration.zero, index: 0);
        if (isPlaying) {
          await Future.delayed(const Duration(milliseconds: 100));
          await _player.play();
        }
      }
      
      await _saveQueue();
      
      _loggingService.logInfo('Queue reordered successfully - current song preserved at index 0');
    } catch (e, stackTrace) {
      _loggingService.logError('Error reordering queue', e, stackTrace);
      rethrow;
    }
  }

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
    
    // Handle media button actions from hardware controls
    switch (name) {
      case 'MEDIA_BUTTON_PLAY':
        await play();
        break;
      case 'MEDIA_BUTTON_PAUSE':
        await pause();
        break;
      case 'MEDIA_BUTTON_PLAY_PAUSE':
        if (_player.playing) {
          await pause();
        } else {
          await play();
        }
        break;
      case 'MEDIA_BUTTON_NEXT':
        await skipToNext();
        break;
      case 'MEDIA_BUTTON_PREVIOUS':
        await skipToPrevious();
        break;
      case 'MEDIA_BUTTON_STOP':
        await stop();
        break;
      case 'SET_FAVORITE':
        if (_currentSong != null && extras != null) {
          final isFavorite = extras['isFavorite'] as bool? ?? false;
          await _toggleFavorite(_currentSong!.id, isFavorite);
        }
        break;
      default:
        _loggingService.logWarning('Unknown custom action: $name');
    }
  }
  
  Future<void> _toggleFavorite(String songId, bool isFavorite) async {
    try {
      // Note: toggleSongFavorite method needs to be implemented in StorageService
      // For now, we'll just log the action
      _loggingService.logInfo('Song favorite toggled: $songId = $isFavorite');
      
      // Update current song if it's the one being toggled
      if (_currentSong?.id == songId) {
        _currentSong = _currentSong!.copyWith(isFavorite: isFavorite);
        final mediaItem = _songToMediaItem(_currentSong!);
        _mediaItemSubject.add(mediaItem);
        // Media metadata is handled by SystemMediaHandler automatically
      }
    } catch (e, stackTrace) {
      _loggingService.logError('Error toggling favorite', e, stackTrace);
    }
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
