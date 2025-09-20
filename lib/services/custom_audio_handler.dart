import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';
import '../models/playback_settings.dart';

/// Custom interface that includes AudioHandler methods plus additional ones
/// This interface defines all audio playback functionality for the music player
abstract class CustomAudioHandler {
  // Core AudioHandler methods
  ValueStream<MediaItem?> get mediaItem;
  ValueStream<PlaybackState> get playbackState;
  ValueStream<List<MediaItem>> get queue;
  
  // Basic playback controls
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> skipToNext();
  Future<void> skipToPrevious();
  
  // Queue management
  Future<void> addQueueItems(List<MediaItem> items);
  Future<void> addQueueItem(MediaItem mediaItem);
  Future<void> addQueueItemAt(MediaItem mediaItem, int index);
  Future<void> removeQueueItem(MediaItem mediaItem);
  Future<void> clearQueue();
  Future<void> setQueue(List<MediaItem> items);
  
  // Playback settings
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode);
  Future<void> setShuffleModeEnabled(bool enabled);
  Future<void> setPlaybackSpeed(double speed);
  Future<void> setVolume(double volume);
  
  // Advanced features
  Future<void> startSleepTimer(int minutes);
  Future<void> cancelSleepTimer();
  Future<void> setEqualizerSettings(Map<String, double> settings);
  Future<void> setCrossfadeDuration(int seconds);
  Future<void> setGaplessPlayback(bool enabled);
  
  // Audio enhancements
  Future<void> setBassBoost(double boost);
  Future<void> setTrebleBoost(double boost);
  Future<void> setSkipSilence(bool skip);
  
  // Utility methods
  Future<void> customAction(String name, [Map<String, dynamic>? extras]);
  Future<void> initialize();
  Future<void> dispose();
  
  // State queries
  bool get isInitialized;
  PlaybackSettings get currentSettings;
  Duration? get currentPosition;
  Duration? get currentDuration;
  
  // Dedicated position stream for smooth progress bars
  ValueStream<Duration>? get positionStream;
  
  // Error handling
  Stream<String> get errorStream;
  Future<void> recover();
}
