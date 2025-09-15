import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';
import '../models/playback_settings.dart';
import '../models/queue_item.dart';
import 'storage_service.dart';

/// Initialize this from main() before runApp
Future<AudioHandler> initAudioHandler() async {
  return await AudioService.init(
    builder: () => MusicPlayerAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.music_player.channel.audio',
      androidNotificationChannelName: 'Music Playback',
      androidNotificationOngoing: true,
      androidShowNotificationBadge: true,
      androidNotificationIcon: 'drawable/ic_notification',
      preloadArtwork: true,
      artDownscaleWidth: 512,
      artDownscaleHeight: 512,
    ),
  );
}

class MusicPlayerAudioHandler extends BaseAudioHandler 
    with QueueHandler, SeekHandler {
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

  MusicPlayerAudioHandler() {
    _init();
  }

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

    // When currentIndex changes, update mediaItem
    _player.currentIndexStream.listen((index) {
      if (index != null && index < queue.value.length) {
        final currentSong = queue.value[index];
        mediaItem.add(currentSong);
        
        // Update play count and recently played
        _storageService.updateSongPlayCount(currentSong.id);
        _storageService.addToRecentlyPlayed(currentSong.id);
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
    
    // Apply crossfade if supported
    if (_settings.crossfadeDuration > 0) {
      try {
        // Note: Crossfade is not directly supported in just_audio
        // This would need to be implemented at a higher level
        print('Crossfade setting: ${_settings.crossfadeDuration}s (not implemented)');
      } catch (e) {
        print('Crossfade not supported: $e');
      }
    }
  }

  Future<void> _restoreQueue() async {
    final queueItems = _storageService.getQueue();
    if (queueItems.isNotEmpty) {
      final songs = _storageService.getSongsByIds(queueItems.map((q) => q.songId).toList());
      final mediaItems = songs.map((song) => _songToMediaItem(song)).toList();
      await addQueueItems(mediaItems);
    }
  }

  void _handlePlaybackCompleted() {
    // Handle repeat modes
    switch (_settings.repeatMode) {
      case RepeatMode.none:
        if (_player.currentIndex == queue.value.length - 1) {
          stop();
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
    queue.add(newQueue);

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
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    final idx = queue.value.indexWhere((m) => m.id == mediaItem.id);
    if (idx != -1) {
      final q = [...queue.value];
      q.removeAt(idx);
      queue.add(q);
      await _playlist.removeAt(idx);
      await _saveQueue();
    }
  }

  Future<void> _saveQueue() async {
    final queueItems = queue.value.asMap().entries.map((entry) {
      return QueueItem(
        songId: entry.value.extras?['songId'] ?? '',
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
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
        _settings = _settings.copyWith(repeatMode: RepeatMode.one);
        break;
      case AudioServiceRepeatMode.all:
        await _player.setLoopMode(LoopMode.all);
        _settings = _settings.copyWith(repeatMode: RepeatMode.all);
        break;
      case AudioServiceRepeatMode.none:
      default:
        await _player.setLoopMode(LoopMode.off);
        _settings = _settings.copyWith(repeatMode: RepeatMode.none);
        break;
    }
    await _storageService.savePlaybackSettings(_settings);
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  Future<void> setShuffleModeEnabled(bool enabled) async {
    await _player.setShuffleModeEnabled(enabled);
    _settings = _settings.copyWith(shuffleEnabled: enabled);
    await _storageService.savePlaybackSettings(_settings);
    playbackState.add(
      playbackState.value.copyWith(
        shuffleMode: enabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
      ),
    );
  }

  Future<void> setPlaybackSpeed(double speed) async {
    await _player.setSpeed(speed);
    _settings = _settings.copyWith(playbackSpeed: speed);
    await _storageService.savePlaybackSettings(_settings);
  }

  Future<void> setCrossfadeDuration(int seconds) async {
    try {
      // Note: Crossfade is not directly supported in just_audio
      // This would need to be implemented at a higher level
      _settings = _settings.copyWith(crossfadeDuration: seconds);
      await _storageService.savePlaybackSettings(_settings);
      print('Crossfade setting updated: ${seconds}s (not implemented)');
    } catch (e) {
      print('Crossfade not supported: $e');
    }
  }

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

  Future<void> cancelSleepTimer() async {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _settings = _settings.copyWith(sleepTimerEnabled: false);
    await _storageService.savePlaybackSettings(_settings);
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

    playbackState.add(
      playbackState.value.copyWith(
        controls: controls,
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
  }
}
