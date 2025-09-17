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

/// Simple audio handler that implements CustomAudioHandler interface
class SimpleAudioHandler implements CustomAudioHandler {
  final _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);
  late final StreamSubscription<PlayerState> _playerStateSub;
  late final StreamSubscription<PlaybackEvent> _playbackEventSub;
  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration?> _durationSub;
  late final StreamSubscription<int?> _currentIndexSub;

  final StorageService _storageService = StorageService();
  final LoggingService _loggingService = LoggingService();
  PlaybackSettings _settings = PlaybackSettings();
  Timer? _sleepTimer;
  bool _isInitialized = false;
  bool _isDisposed = false;
  
  // Error tracking
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 5;

  // BehaviorSubjects for UI compatibility
  final _currentSongSubject = BehaviorSubject<MediaItem?>.seeded(null);
  final _playbackStateSubject = BehaviorSubject<PlaybackState>();
  final _queueSubject = BehaviorSubject<List<MediaItem>>.seeded([]);
  final _errorSubject = BehaviorSubject<String>();
  
  // Dedicated position stream for real-time progress updates
  final _positionSubject = BehaviorSubject<Duration>.seeded(Duration.zero);
  Timer? _positionTimer;

  final List<Song> _currentSongs = [];
  int _currentIndex = 0;

  SimpleAudioHandler() {
    _loggingService.logInfo('Initializing SimpleAudioHandler');
    
    // Initialize with default values
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
    
    // Don't auto-initialize in constructor
    // Let main.dart call initialize() explicitly
  }

  // Expose streams for UI compatibility
  @override
  ValueStream<MediaItem?> get mediaItem => _currentSongSubject.shareValueSeeded(null);

  @override
  ValueStream<PlaybackState> get playbackState => _playbackStateSubject.shareValueSeeded(
    PlaybackState(
      controls: [MediaControl.play],
      processingState: AudioProcessingState.idle,
      playing: false,
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
      speed: 1.0,
    ),
  );

  @override
  ValueStream<List<MediaItem>> get queue => _queueSubject.shareValueSeeded([]);
  
  @override
  Stream<String> get errorStream => _errorSubject.stream;
  
  @override
  bool get isInitialized => _isInitialized;
  
  @override
  PlaybackSettings get currentSettings => _settings;
  
  @override
  Duration? get currentPosition => _player.position;
  
  @override
  Duration? get currentDuration => _player.duration;

  /// Public initialize method called from main.dart
  @override
  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) return;
    
    try {
      _loggingService.logInfo('Starting audio handler initialization');
      await _init();
      _loggingService.logInfo('Audio handler initialized successfully');
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to initialize audio handler', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _init() async {
    if (_isInitialized || _isDisposed) return;

    try {
      // Load settings
      _settings = _storageService.getPlaybackSettings();
      _loggingService.logDebug('Loaded playback settings');

      // Setup audio focus and interrupts
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _loggingService.logDebug('Configured audio session');

      // Setup error handling for player
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) { // Fixed: error is not a valid ProcessingState
          _handlePlayerError();
        }
      });

      // Listen to player events and keep playbackState updated
      _playbackEventSub = _player.playbackEventStream.listen(
        (event) {
          try {
            _broadcastState();
            _consecutiveErrors = 0; // Reset error count on success
          } catch (e, stackTrace) {
            _handleStreamError('playback event', e, stackTrace);
          }
        },
        onError: (e, stackTrace) {
          _handleStreamError('playback event stream', e, stackTrace);
        },
      );

      _playerStateSub = _player.playerStateStream.listen(
        (playerState) {
          try {
            _broadcastState();
            if (playerState.processingState == ProcessingState.completed) {
              _handlePlaybackCompleted();
            }
          } catch (e, stackTrace) {
            _handleStreamError('player state', e, stackTrace);
          }
        },
        onError: (e, stackTrace) {
          _handleStreamError('player state stream', e, stackTrace);
        },
      );

      // CRITICAL FIX: Position stream with higher frequency updates
      _positionSub = _player.positionStream.listen(
        (position) {
          try {
            // Update dedicated position subject for smooth progress
            _positionSubject.add(position);
            // Update position immediately for smooth progress bar
            _broadcastState();
          } catch (e, stackTrace) {
            _handleStreamError('position', e, stackTrace);
          }
        },
        onError: (e, stackTrace) {
          _handleStreamError('position stream', e, stackTrace);
        },
      );
      
      // Start high-frequency position timer for ultra-smooth progress
      _startPositionTimer();

      _durationSub = _player.durationStream.listen(
        (duration) {
          try {
            _broadcastState();
          } catch (e, stackTrace) {
            _handleStreamError('duration', e, stackTrace);
          }
        },
        onError: (e, stackTrace) {
          _handleStreamError('duration stream', e, stackTrace);
        },
      );

      // CRITICAL FIX: When currentIndex changes, update current song
      _currentIndexSub = _player.currentIndexStream.listen(
        (index) {
          try {
            _loggingService.logDebug('Current index changed to: $index');
            
            if (index != null && index < _currentSongs.length && index != _currentIndex) {
              // Only update if index actually changed
              final previousIndex = _currentIndex;
              _currentIndex = index;
              final song = _currentSongs[index];
              final mediaItem = _songToMediaItem(song);
              
              _loggingService.logInfo('Track changed from index $previousIndex to $index: ${song.title}');
              
              // Update current song
              _currentSongSubject.add(mediaItem);
              
              // Update queue to reflect current position
              final queueItems = _currentSongs.map((s) => _songToMediaItem(s)).toList();
              _queueSubject.add(queueItems);
              
              // Broadcast updated state
              _broadcastState();

              // Update play count and recently played asynchronously
              _updateSongStatistics(song.id);
            } else if (index == null) {
              _loggingService.logDebug('Current index is null, clearing current song');
              _currentSongSubject.add(null);
              _broadcastState();
            } else if (index == _currentIndex) {
              _loggingService.logDebug('Index unchanged: $index');
            } else {
              _loggingService.logWarning('Invalid index: $index (queue length: ${_currentSongs.length})');
            }
          } catch (e, stackTrace) {
            _handleStreamError('current index', e, stackTrace);
          }
        },
        onError: (e, stackTrace) {
          _handleStreamError('current index stream', e, stackTrace);
        },
      );

      // Apply settings
      await _applySettings();

      // Restore queue if available
      await _restoreQueue();

      _isInitialized = true;
      _loggingService.logInfo('Audio handler initialization completed');
      
    } catch (e, stackTrace) {
      _loggingService.logError('Error during audio handler initialization', e, stackTrace);
      rethrow;
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
      
      _loggingService.logDebug('Applied settings: shuffle=${_settings.shuffleEnabled}, speed=${_settings.playbackSpeed}, repeat=${_settings.repeatMode}');
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to apply settings', e, stackTrace);
      // Don't rethrow - continue with default settings
    }
  }

  Future<void> _restoreQueue() async {
    try {
      final queueItems = _storageService.getQueue();
      if (queueItems.isNotEmpty) {
        _loggingService.logInfo('Restoring queue with ${queueItems.length} items');
        
        final songIds = queueItems.map((q) => q.songId).toList();
        final songs = _storageService.getSongsByIds(songIds);
        
        // Validate that songs still exist on disk
        final validSongs = <Song>[];
        for (final song in songs) {
          if (await _validateSongFile(song)) {
            validSongs.add(song);
          } else {
            _loggingService.logWarning('Song file not found, removing from queue: ${song.filePath}');
          }
        }
        
        if (validSongs.isNotEmpty) {
          await setQueue(validSongs.map((song) => _songToMediaItem(song)).toList());
          _loggingService.logInfo('Restored ${validSongs.length} valid songs to queue');
        } else {
          _loggingService.logWarning('No valid songs found in saved queue');
          await _storageService.clearQueue();
        }
      }
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to restore queue', e, stackTrace);
      // Clear invalid queue
      await _storageService.clearQueue();
    }
  }

  void _handlePlaybackCompleted() {
    try {
      _loggingService.logDebug('Playback completed, current index: $_currentIndex, queue length: ${_currentSongs.length}, repeat mode: ${_settings.repeatMode}');
      
      // Handle repeat modes
      switch (_settings.repeatMode) {
        case RepeatMode.none:
          // For RepeatMode.none, just_audio will automatically advance to next song
          // We only need to handle the case when we reach the end of the queue
          if (_currentIndex >= _currentSongs.length - 1) {
            _loggingService.logInfo('Reached end of queue, trying to add more songs');
            _addMoreSongsToQueue();
          } else {
            _loggingService.logInfo('Song completed, just_audio will handle advancement');
          }
          break;
        case RepeatMode.one:
          // Just audio handles this automatically with LoopMode.one
          _loggingService.logDebug('Repeating current song (handled by just_audio)');
          break;
        case RepeatMode.all:
          // Just audio handles this automatically with LoopMode.all
          _loggingService.logDebug('Repeating all songs (handled by just_audio)');
          break;
      }
    } catch (e, stackTrace) {
      _loggingService.logError('Error handling playback completion', e, stackTrace);
    }
  }

  Future<void> _addMoreSongsToQueue() async {
    try {
      _loggingService.logDebug('Adding more songs to queue');
      
      // Get all songs from storage
      final allSongs = _storageService.getAllSongs();
      
      // If we have more songs available, add them to the queue
      if (allSongs.length > _currentSongs.length) {
        // Get songs that are not already in the current queue
        final currentSongIds = _currentSongs.map((s) => s.id).toSet();
        final remainingSongs = allSongs.where((s) => !currentSongIds.contains(s.id)).toList();
        
        if (remainingSongs.isNotEmpty) {
          // Add up to 10 more songs to the queue
          final songsToAdd = remainingSongs.take(10).toList();
          
          // Validate songs before adding
          final validSongs = <Song>[];
          for (final song in songsToAdd) {
            if (await _validateSongFile(song)) {
              validSongs.add(song);
            }
          }
          
          if (validSongs.isNotEmpty) {
            // Add songs to internal list
            _currentSongs.addAll(validSongs);
            
            // Create additional audio sources
            final additionalSources = validSongs.map((song) => 
                AudioSource.uri(Uri.file(song.filePath))).toList();
            await _playlist.addAll(additionalSources);
            
            // Update queue subject
            final currentMediaItems = _currentSongs.map((song) => _songToMediaItem(song)).toList();
            _queueSubject.add(currentMediaItems);
            
            // Save queue to storage
            await _saveQueue();
            
            _loggingService.logInfo('Added ${validSongs.length} more songs to queue');
          } else {
            _loggingService.logWarning('No valid songs to add to queue');
            await pause();
          }
        } else {
          _loggingService.logInfo('No more songs available, pausing');
          await pause();
        }
      } else {
        _loggingService.logInfo('All songs already in queue, pausing');
        await pause();
      }
    } catch (e, stackTrace) {
      _loggingService.logError('Error adding more songs to queue', e, stackTrace);
      await pause();
    }
  }

  Future<void> _addMoreSongsToQueueForSingleSong() async {
    try {
      _loggingService.logInfo('Adding more songs to queue for continuous playback');
      
      // Get all songs from storage
      final allSongs = _storageService.getAllSongs();
      
      if (allSongs.isEmpty) {
        _loggingService.logWarning('No songs available to add to queue');
        return;
      }
      
      // Get songs that are not already in the current queue
      final currentSongIds = _currentSongs.map((s) => s.id).toSet();
      final remainingSongs = allSongs.where((s) => !currentSongIds.contains(s.id)).toList();
      
      if (remainingSongs.isNotEmpty) {
        // Add up to 20 more songs to the queue for continuous playback
        final songsToAdd = remainingSongs.take(20).toList();
        
        // Validate songs before adding
        final validSongs = <Song>[];
        for (final song in songsToAdd) {
          if (await _validateSongFile(song)) {
            validSongs.add(song);
          }
        }
        
        if (validSongs.isNotEmpty) {
          // Add songs to internal list
          _currentSongs.addAll(validSongs);
          
          // Create additional audio sources
          final additionalSources = validSongs.map((song) => 
              AudioSource.uri(Uri.file(song.filePath))).toList();
          await _playlist.addAll(additionalSources);
          
          // Update queue subject
          final currentMediaItems = _currentSongs.map((song) => _songToMediaItem(song)).toList();
          _queueSubject.add(currentMediaItems);
          
          _loggingService.logInfo('Added ${validSongs.length} more songs to queue for continuous playback');
        } else {
          _loggingService.logWarning('No valid songs found to add to queue');
        }
      } else {
        _loggingService.logInfo('No more songs available to add to queue');
      }
    } catch (e, stackTrace) {
      _loggingService.logError('Error adding more songs to queue for single song', e, stackTrace);
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
      },
    );
  }

  @override
  Future<void> addQueueItems(List<MediaItem> items) async {
    final current = queue.value;
    final newQueue = [...current, ...items];
    _queueSubject.add(newQueue);

    // Convert MediaItems to Songs and add to internal list
    final songs = items.map((item) => _mediaItemToSong(item)).toList();
    _currentSongs.addAll(songs);

    final sources = items.map((m) => AudioSource.uri(Uri.parse(m.id))).toList();
    await _playlist.addAll(sources);

    if (_player.audioSource == null || _currentSongs.isEmpty) {
      await _player.setAudioSource(_playlist, initialIndex: 0);
    }

    // Save queue to storage
    await _saveQueue();
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) => addQueueItems([mediaItem]);

  @override
  Future<void> clearQueue() async {
    await _player.stop();
    await _playlist.clear();
    await _player.setAudioSource(_playlist);
    _currentSongs.clear();
    _currentIndex = 0;
    _queueSubject.add([]);
    _currentSongSubject.add(null);
    await _saveQueue();
  }

  @override
  Future<void> setQueue(List<MediaItem> items) async {
    try {
      _loggingService.logInfo('Setting queue with ${items.length} items');
      
      // Clear current state
      await _player.stop();
      await _playlist.clear();
      _currentSongs.clear();
      _currentIndex = 0;
      
      if (items.isEmpty) {
        _currentSongSubject.add(null);
        _queueSubject.add([]);
        _broadcastState();
        return;
      }

      // Convert MediaItems to Songs and add to internal list
      final songs = items.map((item) => _mediaItemToSong(item)).toList();
      final selectedSong = songs.first; // Remember the selected song
      _currentSongs.addAll(songs);
      
      // CRITICAL FIX: Add more songs but keep selected song at index 0
      if (items.length == 1) {
        await _addMoreSongsToQueueForSingleSong();
        // Move selected song to front of queue after adding more songs
        _currentSongs.removeWhere((s) => s.id == selectedSong.id);
        _currentSongs.insert(0, selectedSong);
      }
      
      // Create audio sources for all songs in the queue
      final sources = _currentSongs.map((song) => 
          AudioSource.uri(Uri.file(song.filePath))).toList();
      await _playlist.addAll(sources);
      
      // Set the audio source and start from index 0 (which is now the selected song)
      await _player.setAudioSource(_playlist, initialIndex: 0);
      _currentIndex = 0; // This will now play the selected song
      
      // Update queue and current song
      final currentMediaItems = _currentSongs.map((song) => _songToMediaItem(song)).toList();
      _queueSubject.add(currentMediaItems);
      
      if (_currentSongs.isNotEmpty) {
        final firstSong = _currentSongs.first;
        _currentSongSubject.add(_songToMediaItem(firstSong));
        _loggingService.logInfo('Queue set with ${_currentSongs.length} songs, first song: ${firstSong.title}');
      }
      
      // Broadcast initial state
      _broadcastState();
      
      // Save queue to storage
      await _saveQueue();
      
    } catch (e, stackTrace) {
      _loggingService.logError('Error setting queue', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    final idx = queue.value.indexWhere((m) => m.id == mediaItem.id);
    if (idx != -1) {
      final q = [...queue.value];
      q.removeAt(idx);
      _queueSubject.add(q);
      _currentSongs.removeAt(idx);
      await _playlist.removeAt(idx);
      await _saveQueue();
    }
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
    );
  }

  Future<void> _saveQueue() async {
    final queueItems = _currentSongs.asMap().entries.map((entry) {
      return QueueItem(
        songId: entry.value.id,
        position: entry.key,
        addedAt: DateTime.now(),
      );
    }).toList();
    await _storageService.saveQueue(queueItems);
  }

  @override
  Future<void> play() async {
    try {
      _loggingService.logInfo('Play command received');
      
      // Force immediate state update before actual play
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
      
      // Start position timer for smooth progress
      _startPositionTimer();
      
      // Broadcast state again after play
      _broadcastState();
      
      _loggingService.logInfo('Play command completed');
    } catch (e, stackTrace) {
      _loggingService.logError('Error during play', e, stackTrace);
      
      // Revert state on error
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
      
      rethrow;
    }
  }

  @override
  Future<void> pause() async {
    try {
      _loggingService.logInfo('Pause command received');
      
      // Force immediate state update before actual pause
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
      
      // Stop position timer when paused
      _stopPositionTimer();
      
      // Broadcast state again after pause
      _broadcastState();
      
      _loggingService.logInfo('Pause command completed');
    } catch (e, stackTrace) {
      _loggingService.logError('Error during pause', e, stackTrace);
      
      // Revert state on error
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
      
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    try {
      _loggingService.logInfo('Stop command received');
      await _player.stop();
      
      // Stop position timer
      _stopPositionTimer();
      
      _currentSongSubject.add(null);
      _positionSubject.add(Duration.zero);
      _broadcastState();
    } catch (e, stackTrace) {
      _loggingService.logError('Error during stop', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      _loggingService.logDebug('Seek to position: ${position.inSeconds}s');
      await _player.seek(position);
      _broadcastState();
    } catch (e, stackTrace) {
      _loggingService.logError('Error during seek', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> skipToNext() async {
    try {
      _loggingService.logInfo('Skip to next command received');
      
      if (_currentSongs.isEmpty) {
        _loggingService.logWarning('No songs in queue for skip next');
        return;
      }
      
      // Check if we have more songs in the queue
      if (_currentIndex < _currentSongs.length - 1) {
        final nextIndex = _currentIndex + 1;
        _loggingService.logInfo('Skipping to next song at index: $nextIndex');
        await _player.seek(Duration.zero, index: nextIndex);
        _currentIndex = nextIndex;
        
        // Update current song immediately
        final nextSong = _currentSongs[nextIndex];
        _currentSongSubject.add(_songToMediaItem(nextSong));
        _broadcastState();
        
        _loggingService.logInfo('Now playing: ${nextSong.title}');
      } else {
        _loggingService.logInfo('Reached end of queue, trying to add more songs');
        await _addMoreSongsToQueue();
        
        // Try again if we now have more songs
        if (_currentIndex < _currentSongs.length - 1) {
          final nextIndex = _currentIndex + 1;
          await _player.seek(Duration.zero, index: nextIndex);
          _currentIndex = nextIndex;
          
          final nextSong = _currentSongs[nextIndex];
          _currentSongSubject.add(_songToMediaItem(nextSong));
          _broadcastState();
        } else {
          _loggingService.logInfo('No more songs available');
        }
      }
    } catch (e, stackTrace) {
      _loggingService.logError('Error during skip to next', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> skipToPrevious() async {
    try {
      _loggingService.logInfo('Skip to previous command received');
      
      if (_currentSongs.isEmpty) {
        _loggingService.logWarning('No songs in queue for skip previous');
        return;
      }
      
      // Check if we can go to previous song
      if (_currentIndex > 0) {
        final prevIndex = _currentIndex - 1;
        _loggingService.logInfo('Skipping to previous song at index: $prevIndex');
        await _player.seek(Duration.zero, index: prevIndex);
        _currentIndex = prevIndex;
        
        // Update current song immediately
        final prevSong = _currentSongs[prevIndex];
        _currentSongSubject.add(_songToMediaItem(prevSong));
        _broadcastState();
        
        _loggingService.logInfo('Now playing: ${prevSong.title}');
      } else {
        _loggingService.logInfo('Already at first song, restarting current song');
        await _player.seek(Duration.zero);
      }
    } catch (e, stackTrace) {
      _loggingService.logError('Error during skip to previous', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    RepeatMode newRepeatMode;
    switch (repeatMode) {
      case AudioServiceRepeatMode.one:
        newRepeatMode = RepeatMode.one;
        await _player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.all:
        newRepeatMode = RepeatMode.all;
        await _player.setLoopMode(LoopMode.all);
        break;
      case AudioServiceRepeatMode.none:
      default:
        newRepeatMode = RepeatMode.none;
        await _player.setLoopMode(LoopMode.off);
        break;
    }
    _settings = _settings.copyWith(repeatMode: newRepeatMode);
    await _storageService.savePlaybackSettings(_settings);
    _playbackStateSubject.add(_playbackStateSubject.value.copyWith(repeatMode: repeatMode));
  }

  @override
  Future<void> setShuffleModeEnabled(bool enabled) async {
    await _player.setShuffleModeEnabled(enabled);
    _settings = _settings.copyWith(shuffleEnabled: enabled);
    await _storageService.savePlaybackSettings(_settings);
    _playbackStateSubject.add(
      _playbackStateSubject.value.copyWith(
        shuffleMode: enabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
      ),
    );
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    await _player.setSpeed(speed);
    _settings = _settings.copyWith(playbackSpeed: speed);
    await _storageService.savePlaybackSettings(_settings);
  }

  // Public methods for sleep timer
  @override
  Future<void> startSleepTimer(int minutes) async {
    _sleepTimer?.cancel();
    _sleepTimer = Timer(Duration(minutes: minutes), () {
      pause();
    });
    _settings = _settings.copyWith(
      sleepTimerEnabled: true,
      sleepTimerDuration: minutes,
    );
    await _storageService.savePlaybackSettings(_settings);
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
  
  // Additional interface methods implementation
  @override
  Future<void> setVolume(double volume) async {
    try {
      final clampedVolume = volume.clamp(0.0, 1.0);
      await _player.setVolume(clampedVolume);
      _settings = _settings.copyWith(volume: clampedVolume);
      await _storageService.savePlaybackSettings(_settings);
      _loggingService.logDebug('Volume set to: $clampedVolume');
    } catch (e, stackTrace) {
      _loggingService.logError('Error setting volume', e, stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<void> setEqualizerSettings(Map<String, double> settings) async {
    try {
      _settings = _settings.copyWith(equalizerSettings: settings);
      await _storageService.savePlaybackSettings(_settings);
      _loggingService.logDebug('Equalizer settings updated');
      // Note: Actual equalizer implementation would need platform-specific code
    } catch (e, stackTrace) {
      _loggingService.logError('Error setting equalizer', e, stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<void> setCrossfadeDuration(int seconds) async {
    try {
      final clampedSeconds = seconds.clamp(0, 30);
      _settings = _settings.copyWith(crossfadeDuration: clampedSeconds);
      await _storageService.savePlaybackSettings(_settings);
      _loggingService.logDebug('Crossfade duration set to: ${clampedSeconds}s');
    } catch (e, stackTrace) {
      _loggingService.logError('Error setting crossfade duration', e, stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<void> setGaplessPlayback(bool enabled) async {
    try {
      _settings = _settings.copyWith(gaplessPlayback: enabled);
      await _storageService.savePlaybackSettings(_settings);
      _loggingService.logDebug('Gapless playback set to: $enabled');
    } catch (e, stackTrace) {
      _loggingService.logError('Error setting gapless playback', e, stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<void> setBassBoost(double boost) async {
    try {
      final clampedBoost = boost.clamp(0.0, 1.0);
      _settings = _settings.copyWith(bassBoost: clampedBoost);
      await _storageService.savePlaybackSettings(_settings);
      _loggingService.logDebug('Bass boost set to: $clampedBoost');
    } catch (e, stackTrace) {
      _loggingService.logError('Error setting bass boost', e, stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<void> setTrebleBoost(double boost) async {
    try {
      final clampedBoost = boost.clamp(0.0, 1.0);
      _settings = _settings.copyWith(trebleBoost: clampedBoost);
      await _storageService.savePlaybackSettings(_settings);
      _loggingService.logDebug('Treble boost set to: $clampedBoost');
    } catch (e, stackTrace) {
      _loggingService.logError('Error setting treble boost', e, stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<void> setSkipSilence(bool skip) async {
    try {
      _settings = _settings.copyWith(skipSilence: skip);
      await _storageService.savePlaybackSettings(_settings);
      _loggingService.logDebug('Skip silence set to: $skip');
    } catch (e, stackTrace) {
      _loggingService.logError('Error setting skip silence', e, stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<void> recover() async {
    try {
      _loggingService.logInfo('Attempting to recover audio handler');
      
      // Reset error count
      _consecutiveErrors = 0;
      
      // Try to reinitialize if needed
      if (!_isInitialized) {
        await initialize();
      }
      
      _loggingService.logInfo('Audio handler recovery completed');
    } catch (e, stackTrace) {
      _loggingService.logError('Error during audio handler recovery', e, stackTrace);
      rethrow;
    }
  }

  // Custom action method for compatibility
  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    // Handle custom actions if needed
    _loggingService.logDebug('Custom action: $name with extras: $extras');
  }

  // High-frequency position timer for ultra-smooth progress bars
  void _startPositionTimer() {
    _stopPositionTimer(); // Stop any existing timer
    
    _positionTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_player.playing && !_isDisposed) {
        final position = _player.position;
        _positionSubject.add(position);
        
        // Also update the playback state for complete synchronization
        _broadcastState();
      }
    });
    
    _loggingService.logDebug('Started high-frequency position timer');
  }
  
  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
    _loggingService.logDebug('Stopped position timer');
  }
  
  // Expose dedicated position stream for progress bars
  @override
  ValueStream<Duration> get positionStream => _positionSubject.shareValueSeeded(Duration.zero);

  void _broadcastState() {
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
        processingState: {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[processingState] ?? AudioProcessingState.idle,
        playing: playing,
        updatePosition: position,
        bufferedPosition: bufferedPosition,
        speed: speed,
        queueIndex: currentIndex,
        repeatMode: _settings.repeatMode == RepeatMode.one
            ? AudioServiceRepeatMode.one
            : _settings.repeatMode == RepeatMode.all
                ? AudioServiceRepeatMode.all
                : AudioServiceRepeatMode.none,
        shuffleMode: _settings.shuffleEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
      );

      _playbackStateSubject.add(newState);
      
      _loggingService.logDebug('State broadcast: playing=$playing, position=${position.inSeconds}s, index=$currentIndex');
      
    } catch (e, stackTrace) {
      _loggingService.logError('Error broadcasting state', e, stackTrace);
    }
  }

  /// Error handling methods
  void _handlePlayerError() {
    _consecutiveErrors++;
    _loggingService.logError('Player error occurred ($_consecutiveErrors/$_maxConsecutiveErrors)', null);
    
    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      _loggingService.logFatal('Too many consecutive errors, stopping playback', null);
      stop();
    }
  }
  
  void _handleStreamError(String streamName, Object error, StackTrace stackTrace) {
    _consecutiveErrors++;
    _loggingService.logError('Stream error in $streamName ($_consecutiveErrors/$_maxConsecutiveErrors)', error, stackTrace);
    
    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      _loggingService.logFatal('Too many stream errors, reinitializing', error);
      _reinitialize();
    }
  }
  
  Future<void> _reinitialize() async {
    try {
      _loggingService.logInfo('Reinitializing audio handler due to errors');
      
      // Cancel existing subscriptions
      await _playbackEventSub.cancel();
      await _playerStateSub.cancel();
      await _positionSub.cancel();
      await _durationSub.cancel();
      await _currentIndexSub.cancel();
      
      // Reset state
      _isInitialized = false;
      _consecutiveErrors = 0;
      
      // Reinitialize
      await _init();
    } catch (e, stackTrace) {
      _loggingService.logFatal('Failed to reinitialize audio handler', e, stackTrace);
    }
  }
  
  Future<bool> _validateSongFile(Song song) async {
    try {
      final file = File(song.filePath);
      final exists = await file.exists();
      if (!exists) {
        _loggingService.logWarning('Song file does not exist: ${song.filePath}');
        return false;
      }
      
      final size = await file.length();
      if (size == 0) {
        _loggingService.logWarning('Song file is empty: ${song.filePath}');
        return false;
      }
      
      return true;
    } catch (e, stackTrace) {
      _loggingService.logError('Error validating song file: ${song.filePath}', e, stackTrace);
      return false;
    }
  }
  
  Future<void> _updateSongStatistics(String songId) async {
    try {
      await _storageService.updateSongPlayCount(songId);
      await _storageService.addToRecentlyPlayed(songId);
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to update song statistics: $songId', e, stackTrace);
      // Don't rethrow - this is not critical
    }
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    try {
      _loggingService.logInfo('Disposing audio handler');
      _isDisposed = true;
      
      // Cancel sleep timer and position timer
      _sleepTimer?.cancel();
      _stopPositionTimer();
      
      // Cancel stream subscriptions
      await _playbackEventSub.cancel();
      await _playerStateSub.cancel();
      await _positionSub.cancel();
      await _durationSub.cancel();
      await _currentIndexSub.cancel();
      
      // Save current queue
      await _saveQueue();
      
      // Dispose player
      await _player.dispose();
      
      // Close subjects
      await _currentSongSubject.close();
      await _playbackStateSubject.close();
      await _queueSubject.close();
      await _positionSubject.close();
      
      _loggingService.logInfo('Audio handler disposed successfully');
    } catch (e, stackTrace) {
      _loggingService.logError('Error disposing audio handler', e, stackTrace);
    }
  }
}