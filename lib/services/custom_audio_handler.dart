import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';

/// Custom interface that includes AudioHandler methods plus additional ones
abstract class CustomAudioHandler {
  // AudioHandler methods
  ValueStream<MediaItem?> get mediaItem;
  ValueStream<PlaybackState> get playbackState;
  ValueStream<List<MediaItem>> get queue;
  
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> skipToNext();
  Future<void> skipToPrevious();
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode);
  Future<void> addQueueItems(List<MediaItem> items);
  Future<void> addQueueItem(MediaItem mediaItem);
  Future<void> removeQueueItem(MediaItem mediaItem);
  Future<void> customAction(String name, [Map<String, dynamic>? extras]);
  
  // Additional custom methods
  Future<void> startSleepTimer(int minutes);
  Future<void> cancelSleepTimer();
  Future<void> setPlaybackSpeed(double speed);
  Future<void> setShuffleModeEnabled(bool enabled);
}
