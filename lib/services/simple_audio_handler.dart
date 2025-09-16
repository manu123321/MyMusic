import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:rxdart/rxdart.dart';
import 'package:audio_service/audio_service.dart';
import '../models/song.dart';
import '../models/playback_settings.dart';
import '../models/queue_item.dart';
import 'storage_service.dart';
import 'custom_audio_handler.dart';

/// Simple audio handler that implements CustomAudioHandler interface
class SimpleAudioHandler implements CustomAudioHandler {
  final _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);
  late final StreamSubscription<PlayerState> _playerStateSub;
  late final StreamSubscription<PlaybackEvent> _playbackEventSub;
  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration?> _durationSub;

  final StorageService _storageService = StorageService();
  PlaybackSettings _settings = PlaybackSettings();
  Timer? _sleepTimer;
  bool _isInitialized = false;

  // BehaviorSubjects for UI compatibility
  final _currentSongSubject = BehaviorSubject<MediaItem?>();
  final _playbackStateSubject = BehaviorSubject<PlaybackState>();
  final _queueSubject = BehaviorSubject<List<MediaItem>>();

  List<Song> _currentSongs = [];
  int _currentIndex = 0;

  SimpleAudioHandler() {
    // Initialize with default values
    _currentSongSubject.add(null);
    _playbackStateSubject.add(PlaybackState(
      controls: [],
      systemActions: const {},
      androidCompactActionIndices: [],
      processingState: AudioProcessingState.idle,
      playing: false,
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
      speed: 1.0,
      queueIndex: null,
    ));
    _queueSubject.add([]);
    
    _init();
  }

  // Expose streams for UI compatibility
  ValueStream<MediaItem?> get mediaItem => _currentSongSubject.stream;

  ValueStream<PlaybackState> get playbackState => _playbackStateSubject.stream;

  ValueStream<List<MediaItem>> get queue => _queueSubject.stream;

  Future<void> _init() async {
    if (_isInitialized) return;

    // Load settings
    _settings = _storageService.getPlaybackSettings();

    // Setup audio focus and interrupts
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Listen to player events and keep playbackState updated
    _playbackEventSub = _player.playbackEventStream.listen((event) {
      _broadcastState();
    });

    _playerStateSub = _player.playerStateStream.listen((playerState) {
      _broadcastState();
    });

    _positionSub = _player.positionStream.listen((position) {
      _broadcastState();
    });

    _durationSub = _player.durationStream.listen((duration) {
      _broadcastState();
    });

    // When currentIndex changes, update current song
    _player.currentIndexStream.listen((index) {
      if (index != null && index < _currentSongs.length) {
        _currentIndex = index;
        final song = _currentSongs[index];
        _currentSongSubject.add(_songToMediaItem(song));

        // Update play count and recently played
        _storageService.updateSongPlayCount(song.id);
        _storageService.addToRecentlyPlayed(song.id);
      }
    });

    // Handle playback completion
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _handlePlaybackCompleted();
      }
    });

    // Apply settings
    await _applySettings();

    // Restore queue if available
    await _restoreQueue();

    _isInitialized = true;
  }

  Future<void> _applySettings() async {
    await _player.setShuffleModeEnabled(_settings.shuffleEnabled);
    await _player.setSpeed(_settings.playbackSpeed);

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
  }

  Future<void> _restoreQueue() async {
    final queueItems = _storageService.getQueue();
    if (queueItems.isNotEmpty) {
      final songs = _storageService.getSongsByIds(queueItems.map((q) => q.songId).toList());
      await addQueueItems(songs.map((song) => _songToMediaItem(song)).toList());
    }
  }

  void _handlePlaybackCompleted() {
    // Handle repeat modes
    switch (_settings.repeatMode) {
      case RepeatMode.none:
        if (_currentIndex == _currentSongs.length - 1) {
          pause();
        }
        break;
      case RepeatMode.one:
        // Just audio handles this automatically
        break;
      case RepeatMode.all:
        // Just audio handles this automatically
        break;
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

    if (_player.audioSource == null) {
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
    await clearQueue();
    if (items.isNotEmpty) {
      await addQueueItems(items);
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
  Future<void> play() async => _player.play();

  @override
  Future<void> pause() async => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    _currentSongSubject.add(null);
  }

  @override
  Future<void> seek(Duration position) async => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

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
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _settings = _settings.copyWith(sleepTimerEnabled: false);
    await _storageService.savePlaybackSettings(_settings);
  }

  // Custom action method for compatibility
  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    // Handle custom actions if needed
    print('Custom action: $name with extras: $extras');
  }

  void _broadcastState() {
    final playing = _player.playing;

    final controls = <MediaControl>[
      MediaControl.skipToPrevious,
      if (playing) MediaControl.pause else MediaControl.play,
      MediaControl.stop,
      MediaControl.skipToNext,
    ];

    final androidCompact = [0, 1, 3];

    _playbackStateSubject.add(
      PlaybackState(
        controls: controls,
        systemActions: const {},
        androidCompactActionIndices: androidCompact,
        processingState: {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _player.currentIndex,
        repeatMode: _settings.repeatMode == RepeatMode.one
            ? AudioServiceRepeatMode.one
            : _settings.repeatMode == RepeatMode.all
                ? AudioServiceRepeatMode.all
                : AudioServiceRepeatMode.none,
        shuffleMode: _settings.shuffleEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    _sleepTimer?.cancel();
    await _playbackEventSub.cancel();
    await _playerStateSub.cancel();
    await _positionSub.cancel();
    await _durationSub.cancel();
    await _player.dispose();
    await _saveQueue();
    await _currentSongSubject.close();
    await _playbackStateSubject.close();
    await _queueSubject.close();
  }
}