import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'custom_audio_handler.dart';
import 'logging_service.dart';

/// System-integrated media handler that provides notification panel,
/// lock screen, and control center integration
class SystemMediaHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final CustomAudioHandler _internalHandler;
  final LoggingService _loggingService = LoggingService();
  late final StreamSubscription _mediaItemSub;
  late final StreamSubscription _playbackStateSub;
  late final StreamSubscription _queueSub;

  SystemMediaHandler(this._internalHandler) {
    _loggingService.logInfo('Initializing SystemMediaHandler');
    _init();
  }

  void _init() {
    // Listen to internal handler changes and propagate to system
    _mediaItemSub = _internalHandler.mediaItem.listen((mediaItem) {
      if (mediaItem != null) {
        this.mediaItem.add(mediaItem);
        _loggingService.logDebug('System media item updated: ${mediaItem.title}');
      }
    });

    _playbackStateSub = _internalHandler.playbackState.listen((state) {
      // Enhance the state with system-specific controls
      final enhancedState = state.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (state.playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.setRating,
          MediaAction.setRepeatMode,
          MediaAction.setShuffleMode,
        },
        androidCompactActionIndices: const [0, 1, 2], // Previous, Play/Pause, Next
      );
      
      playbackState.add(enhancedState);
      _loggingService.logDebug('System playback state updated: playing=${state.playing}');
    });

    _queueSub = _internalHandler.queue.listen((queueItems) {
      queue.add(queueItems);
      _loggingService.logDebug('System queue updated: ${queueItems.length} items');
    });
  }

  // Forward all control actions to internal handler
  @override
  Future<void> play() async {
    _loggingService.logInfo('System play command');
    await _internalHandler.play();
  }

  @override
  Future<void> pause() async {
    _loggingService.logInfo('System pause command');
    await _internalHandler.pause();
  }

  @override
  Future<void> stop() async {
    _loggingService.logInfo('System stop command');
    await _internalHandler.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    _loggingService.logDebug('System seek command: ${position.inSeconds}s');
    await _internalHandler.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    _loggingService.logInfo('System skip next command');
    await _internalHandler.skipToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    _loggingService.logInfo('System skip previous command');
    await _internalHandler.skipToPrevious();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _loggingService.logInfo('System repeat mode command: $repeatMode');
    await _internalHandler.setRepeatMode(repeatMode);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _loggingService.logInfo('System shuffle mode command: $shuffleMode');
    final enabled = shuffleMode == AudioServiceShuffleMode.all;
    await _internalHandler.setShuffleModeEnabled(enabled);
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    _loggingService.logInfo('System add queue item: ${mediaItem.title}');
    await _internalHandler.addQueueItem(mediaItem);
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    _loggingService.logInfo('System add queue items: ${mediaItems.length}');
    await _internalHandler.addQueueItems(mediaItems);
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    _loggingService.logInfo('System remove queue item: ${mediaItem.title}');
    await _internalHandler.removeQueueItem(mediaItem);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    _loggingService.logInfo('System skip to queue item: $index');
    // This would need to be implemented in the internal handler
    final queueItems = queue.value;
    if (index >= 0 && index < queueItems.length) {
      final targetItem = queueItems[index];
      await _internalHandler.setQueue([targetItem]);
      await _internalHandler.play();
    }
  }

  // Handle media button events (from headphones, Bluetooth devices, etc.)
  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    _loggingService.logInfo('System play media item: ${mediaItem.title}');
    await _internalHandler.setQueue([mediaItem]);
    await _internalHandler.play();
  }

  // Handle system volume and other controls
  Future<void> setVolume(double volume) async {
    _loggingService.logDebug('System volume command: $volume');
    await _internalHandler.setVolume(volume);
  }

  @override
  Future<void> setSpeed(double speed) async {
    _loggingService.logDebug('System speed command: $speed');
    await _internalHandler.setPlaybackSpeed(speed);
  }

  // Handle rating (like/unlike)
  @override
  Future<void> setRating(Rating rating, [Map<String, dynamic>? extras]) async {
    _loggingService.logInfo('System rating command received');
    // This could be used to implement like/unlike functionality
    // You could extend your internal handler to support this
  }

  // Custom actions for advanced features
  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    _loggingService.logInfo('System custom action: $name');
    await _internalHandler.customAction(name, extras);
  }

  Future<void> dispose() async {
    _loggingService.logInfo('Disposing SystemMediaHandler');
    await _mediaItemSub.cancel();
    await _playbackStateSub.cancel();
    await _queueSub.cancel();
  }
}

/// Initialize the system media handler
Future<AudioHandler> initSystemMediaHandler(CustomAudioHandler internalHandler) async {
  return await AudioService.init(
    builder: () => SystemMediaHandler(internalHandler),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.music_player.channel.audio',
      androidNotificationChannelName: 'Music Player',
      androidNotificationChannelDescription: 'Media playback controls for Music Player',
      androidNotificationOngoing: false,
      androidShowNotificationBadge: true,
      androidNotificationIcon: 'drawable/ic_notification',
      androidNotificationClickStartsActivity: true,
      androidStopForegroundOnPause: false,
      preloadArtwork: true,
      artDownscaleWidth: 512,
      artDownscaleHeight: 512,
      fastForwardInterval: Duration(seconds: 10),
      rewindInterval: Duration(seconds: 10),
    ),
  );
}
