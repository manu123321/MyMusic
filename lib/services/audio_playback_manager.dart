import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../models/song.dart';
import 'custom_audio_handler.dart';
import 'logging_service.dart';

/// Manages audio playback state and ensures UI synchronization
class AudioPlaybackManager {
  static final AudioPlaybackManager _instance = AudioPlaybackManager._internal();
  factory AudioPlaybackManager() => _instance;
  AudioPlaybackManager._internal();

  final LoggingService _loggingService = LoggingService();
  CustomAudioHandler? _audioHandler;
  
  // State tracking
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  MediaItem? _currentMediaItem;
  
  // Stream controllers for reliable state updates
  final _playingController = StreamController<bool>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _mediaItemController = StreamController<MediaItem?>.broadcast();
  
  // Getters for streams
  Stream<bool> get isPlayingStream => _playingController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<MediaItem?> get mediaItemStream => _mediaItemController.stream;
  
  // Current state getters
  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _currentPosition;
  Duration get currentDuration => _currentDuration;
  MediaItem? get currentMediaItem => _currentMediaItem;

  void initialize(CustomAudioHandler audioHandler) {
    _audioHandler = audioHandler;
    _setupListeners();
    _loggingService.logInfo('AudioPlaybackManager initialized');
  }

  void _setupListeners() {
    if (_audioHandler == null) return;

    // Listen to playback state changes
    _audioHandler!.playbackState.listen((state) {
      final newIsPlaying = state.playing;
      final newPosition = state.updatePosition;
      
      if (_isPlaying != newIsPlaying) {
        _isPlaying = newIsPlaying;
        _playingController.add(_isPlaying);
        _loggingService.logDebug('Playing state changed: $_isPlaying');
      }
      
      if (_currentPosition != newPosition) {
        _currentPosition = newPosition;
        _positionController.add(_currentPosition);
      }
    });

    // Listen to media item changes
    _audioHandler!.mediaItem.listen((mediaItem) {
      if (_currentMediaItem?.id != mediaItem?.id) {
        _currentMediaItem = mediaItem;
        _mediaItemController.add(_currentMediaItem);
        
        if (mediaItem != null) {
          _currentDuration = mediaItem.duration ?? Duration.zero;
          _loggingService.logInfo('Media item changed: ${mediaItem.title}');
        }
      }
    });
  }

  Future<void> playSong(Song song) async {
    try {
      if (_audioHandler == null) {
        throw Exception('Audio handler not initialized');
      }

      _loggingService.logInfo('Starting playback for: ${song.title}');

      // Create MediaItem
      final mediaItem = MediaItem(
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

      // Set queue and start playback
      await _audioHandler!.setQueue([mediaItem]);
      
      // Wait a moment for queue to be set
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Seek to beginning and start playing
      await _audioHandler!.seek(Duration.zero);
      await _audioHandler!.play();
      
      // Force state update
      _currentMediaItem = mediaItem;
      _currentDuration = Duration(milliseconds: song.duration);
      _mediaItemController.add(_currentMediaItem);
      
      _loggingService.logInfo('Playback started successfully for: ${song.title}');
      
    } catch (e, stackTrace) {
      _loggingService.logError('Error starting playback for: ${song.title}', e, stackTrace);
      rethrow;
    }
  }

  Future<void> togglePlayPause() async {
    try {
      if (_audioHandler == null) return;

      if (_isPlaying) {
        await _audioHandler!.pause();
        _loggingService.logInfo('Playback paused');
      } else {
        await _audioHandler!.play();
        _loggingService.logInfo('Playback resumed');
      }
    } catch (e, stackTrace) {
      _loggingService.logError('Error toggling play/pause', e, stackTrace);
      rethrow;
    }
  }

  Future<void> skipToNext() async {
    try {
      if (_audioHandler == null) return;
      
      await _audioHandler!.skipToNext();
      _loggingService.logInfo('Skipped to next track');
    } catch (e, stackTrace) {
      _loggingService.logError('Error skipping to next', e, stackTrace);
      rethrow;
    }
  }

  Future<void> skipToPrevious() async {
    try {
      if (_audioHandler == null) return;
      
      await _audioHandler!.skipToPrevious();
      _loggingService.logInfo('Skipped to previous track');
    } catch (e, stackTrace) {
      _loggingService.logError('Error skipping to previous', e, stackTrace);
      rethrow;
    }
  }

  Future<void> seekTo(Duration position) async {
    try {
      if (_audioHandler == null) return;
      
      await _audioHandler!.seek(position);
      _currentPosition = position;
      _positionController.add(_currentPosition);
      _loggingService.logDebug('Seeked to: ${position.inSeconds}s');
    } catch (e, stackTrace) {
      _loggingService.logError('Error seeking', e, stackTrace);
      rethrow;
    }
  }

  void dispose() {
    _playingController.close();
    _positionController.close();
    _mediaItemController.close();
    _loggingService.logInfo('AudioPlaybackManager disposed');
  }
}

// Provider for the playback manager
final audioPlaybackManagerProvider = Provider<AudioPlaybackManager>((ref) {
  return AudioPlaybackManager();
});
