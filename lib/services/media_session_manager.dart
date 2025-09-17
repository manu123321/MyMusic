import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';
import '../models/song.dart';
import 'logging_service.dart';

/// Manages media session metadata and lock screen integration
class MediaSessionManager {
  final LoggingService _loggingService = LoggingService();
  AudioHandler? _audioHandler;

  void initialize(AudioHandler audioHandler) {
    _audioHandler = audioHandler;
    _loggingService.logInfo('MediaSessionManager initialized');
  }

  /// Update media metadata for lock screen and notification display
  Future<void> updateMediaMetadata(Song song) async {
    if (_audioHandler == null) {
      _loggingService.logWarning('AudioHandler not initialized, cannot update metadata');
      return;
    }

    try {
      // Create rich media item with all available metadata
      final mediaItem = MediaItem(
        id: song.filePath,
        title: song.title,
        artist: song.artist.isNotEmpty ? song.artist : 'Unknown Artist',
        album: song.album.isNotEmpty ? song.album : 'Unknown Album',
        genre: song.genre,
        duration: Duration(milliseconds: song.duration),
        artUri: await _getArtworkUri(song),
        playable: true,
        extras: {
          'songId': song.id,
          'trackNumber': song.trackNumber,
          'year': song.year,
          'isFavorite': song.isFavorite,
          'rating': song.rating,
          'playCount': song.playCount,
          'dateAdded': song.dateAdded.toIso8601String(),
        },
      );

      // Update the media item in the audio handler
      if (_audioHandler!.mediaItem is BehaviorSubject) {
        (_audioHandler!.mediaItem as BehaviorSubject).add(mediaItem);
      }
      
      _loggingService.logInfo('Media metadata updated for: ${song.title}');
      
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to update media metadata', e, stackTrace);
    }
  }

  /// Update playback state for system integration
  Future<void> updatePlaybackState({
    required bool playing,
    required Duration position,
    required Duration? duration,
    required double speed,
    bool shuffleEnabled = false,
    AudioServiceRepeatMode repeatMode = AudioServiceRepeatMode.none,
    AudioProcessingState processingState = AudioProcessingState.ready,
  }) async {
    if (_audioHandler == null) {
      _loggingService.logWarning('AudioHandler not initialized, cannot update playback state');
      return;
    }

    try {
      // Create comprehensive playback state
      final playbackState = PlaybackState(
        controls: _buildMediaControls(playing),
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.setRating,
          MediaAction.setRepeatMode,
          MediaAction.setShuffleMode,
          MediaAction.playFromMediaId,
          MediaAction.playFromSearch,
        },
        androidCompactActionIndices: const [0, 1, 2], // Previous, Play/Pause, Next
        processingState: processingState,
        playing: playing,
        updatePosition: position,
        bufferedPosition: position, // For simplicity, assume buffered = position
        speed: speed,
        queueIndex: 0, // This should be updated based on actual queue position
        repeatMode: repeatMode,
        shuffleMode: shuffleEnabled 
            ? AudioServiceShuffleMode.all 
            : AudioServiceShuffleMode.none,
      );

      if (_audioHandler!.playbackState is BehaviorSubject) {
        (_audioHandler!.playbackState as BehaviorSubject).add(playbackState);
      }
      
      _loggingService.logDebug('Playback state updated: playing=$playing, position=${position.inSeconds}s');
      
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to update playback state', e, stackTrace);
    }
  }

  /// Build media controls based on current state
  List<MediaControl> _buildMediaControls(bool playing) {
    return [
      MediaControl.skipToPrevious,
      if (playing) MediaControl.pause else MediaControl.play,
      MediaControl.skipToNext,
      MediaControl.stop,
    ];
  }

  /// Get artwork URI for the song
  Future<Uri?> _getArtworkUri(Song song) async {
    try {
      if (song.albumArtPath != null && song.albumArtPath!.isNotEmpty) {
        final file = File(song.albumArtPath!);
        if (await file.exists()) {
          return Uri.file(song.albumArtPath!);
        }
      }
      
      // Could implement fallback artwork logic here
      // For example, generate artwork from song metadata or use default
      
      return null;
    } catch (e) {
      _loggingService.logError('Error getting artwork URI', e);
      return null;
    }
  }

  /// Update queue information for lock screen
  Future<void> updateQueue(List<Song> songs, int currentIndex) async {
    if (_audioHandler == null) {
      _loggingService.logWarning('AudioHandler not initialized, cannot update queue');
      return;
    }

    try {
      final mediaItems = await Future.wait(
        songs.map((song) async => MediaItem(
          id: song.filePath,
          title: song.title,
          artist: song.artist.isNotEmpty ? song.artist : 'Unknown Artist',
          album: song.album.isNotEmpty ? song.album : 'Unknown Album',
          duration: Duration(milliseconds: song.duration),
          artUri: await _getArtworkUri(song),
          playable: true,
        )),
      );

      if (_audioHandler!.queue is BehaviorSubject) {
        (_audioHandler!.queue as BehaviorSubject).add(mediaItems);
      }
      
      // Update current queue index
      if (currentIndex >= 0 && currentIndex < mediaItems.length) {
        final currentState = _audioHandler!.playbackState.value;
        if (_audioHandler!.playbackState is BehaviorSubject) {
          (_audioHandler!.playbackState as BehaviorSubject).add(
            currentState.copyWith(queueIndex: currentIndex),
          );
        }
      }
      
      _loggingService.logInfo('Queue updated with ${songs.length} songs, current index: $currentIndex');
      
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to update queue', e, stackTrace);
    }
  }

  /// Handle media button events from hardware controls
  Future<void> handleMediaButtonEvent(String action) async {
    _loggingService.logInfo('Media button event: $action');
    
    switch (action) {
      case 'PLAY':
        await _audioHandler?.play();
        break;
      case 'PAUSE':
        await _audioHandler?.pause();
        break;
      case 'PLAY_PAUSE':
        final playing = _audioHandler?.playbackState.value.playing ?? false;
        if (playing) {
          await _audioHandler?.pause();
        } else {
          await _audioHandler?.play();
        }
        break;
      case 'NEXT':
        await _audioHandler?.skipToNext();
        break;
      case 'PREVIOUS':
        await _audioHandler?.skipToPrevious();
        break;
      case 'STOP':
        await _audioHandler?.stop();
        break;
      default:
        _loggingService.logWarning('Unknown media button action: $action');
    }
  }

  /// Set rating for the current song (like/unlike)
  Future<void> setRating(bool isLiked) async {
    if (_audioHandler == null) return;

    try {
      final rating = Rating.newHeartRating(isLiked);
      // This would typically be handled by your custom audio handler
      await _audioHandler!.setRating(rating, null);
      
      _loggingService.logInfo('Rating set: ${isLiked ? 'liked' : 'unliked'}');
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to set rating', e, stackTrace);
    }
  }

  /// Dispose resources
  void dispose() {
    _loggingService.logInfo('MediaSessionManager disposed');
    _audioHandler = null;
  }
}
