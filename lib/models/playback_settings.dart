import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';

part 'playback_settings.g.dart';

@HiveType(typeId: 3)
class PlaybackSettings extends HiveObject {
  @HiveField(0)
  bool shuffleEnabled;

  @HiveField(1)
  RepeatMode repeatMode;

  @HiveField(2)
  double playbackSpeed;

  @HiveField(3)
  int crossfadeDuration; // in seconds

  @HiveField(4)
  bool gaplessPlayback;

  @HiveField(5)
  double volume;

  @HiveField(6)
  bool sleepTimerEnabled;

  @HiveField(7)
  int sleepTimerDuration; // in minutes

  @HiveField(8)
  bool resumeAfterReboot;

  @HiveField(9)
  Map<String, double> equalizerSettings;
  
  @HiveField(10)
  bool skipSilence;
  
  @HiveField(11)
  double bassBoost; // 0.0 to 1.0
  
  @HiveField(12)
  double trebleBoost; // 0.0 to 1.0
  
  @HiveField(13)
  bool autoPlay; // auto-play next song
  
  @HiveField(14)
  bool showNotifications;
  
  @HiveField(15)
  String audioQuality; // 'low', 'medium', 'high', 'lossless'
  
  @HiveField(16)
  bool fadeInOut;
  
  @HiveField(17)
  int fadeInDuration; // in milliseconds
  
  @HiveField(18)
  int fadeOutDuration; // in milliseconds

  PlaybackSettings({
    this.shuffleEnabled = false,
    this.repeatMode = RepeatMode.none,
    this.playbackSpeed = 1.0,
    this.crossfadeDuration = 0,
    this.gaplessPlayback = true,
    this.volume = 1.0,
    this.sleepTimerEnabled = false,
    this.sleepTimerDuration = 30,
    this.resumeAfterReboot = true,
    this.equalizerSettings = const {},
    this.skipSilence = false,
    this.bassBoost = 0.0,
    this.trebleBoost = 0.0,
    this.autoPlay = true,
    this.showNotifications = true,
    this.audioQuality = 'high',
    this.fadeInOut = false,
    this.fadeInDuration = 1000,
    this.fadeOutDuration = 1000,
  }) : assert(playbackSpeed >= 0.25 && playbackSpeed <= 3.0, 'Playback speed must be between 0.25 and 3.0'),
       assert(crossfadeDuration >= 0 && crossfadeDuration <= 30, 'Crossfade duration must be between 0 and 30 seconds'),
       assert(volume >= 0.0 && volume <= 1.0, 'Volume must be between 0.0 and 1.0'),
       assert(sleepTimerDuration > 0, 'Sleep timer duration must be positive'),
       assert(bassBoost >= 0.0 && bassBoost <= 1.0, 'Bass boost must be between 0.0 and 1.0'),
       assert(trebleBoost >= 0.0 && trebleBoost <= 1.0, 'Treble boost must be between 0.0 and 1.0'),
       assert(['low', 'medium', 'high', 'lossless'].contains(audioQuality), 'Invalid audio quality'),
       assert(fadeInDuration >= 0 && fadeInDuration <= 10000, 'Fade in duration must be between 0 and 10000ms'),
       assert(fadeOutDuration >= 0 && fadeOutDuration <= 10000, 'Fade out duration must be between 0 and 10000ms');

  factory PlaybackSettings.fromMap(Map<String, dynamic> map) {
    try {
      // Validate and parse playback speed
      final playbackSpeed = _parseDoubleSafely(map['playbackSpeed'], 1.0);
      if (playbackSpeed < 0.25 || playbackSpeed > 3.0) {
        throw ArgumentError('Playback speed must be between 0.25 and 3.0');
      }
      
      // Validate and parse volume
      final volume = _parseDoubleSafely(map['volume'], 1.0);
      if (volume < 0.0 || volume > 1.0) {
        throw ArgumentError('Volume must be between 0.0 and 1.0');
      }
      
      // Validate repeat mode
      final repeatModeIndex = _parseIntSafely(map['repeatMode'], 0);
      if (repeatModeIndex < 0 || repeatModeIndex >= RepeatMode.values.length) {
        throw ArgumentError('Invalid repeat mode index');
      }
      
      // Validate crossfade duration
      final crossfadeDuration = _parseIntSafely(map['crossfadeDuration'], 0);
      if (crossfadeDuration < 0 || crossfadeDuration > 30) {
        throw ArgumentError('Crossfade duration must be between 0 and 30 seconds');
      }
      
      // Validate audio quality
      final audioQuality = map['audioQuality'] ?? 'high';
      if (!['low', 'medium', 'high', 'lossless'].contains(audioQuality)) {
        throw ArgumentError('Invalid audio quality: $audioQuality');
      }
      
      // Parse equalizer settings safely
      Map<String, double> equalizerSettings = {};
      if (map['equalizerSettings'] is Map) {
        final rawEq = map['equalizerSettings'] as Map;
        for (final entry in rawEq.entries) {
          if (entry.key is String && entry.value is num) {
            equalizerSettings[entry.key] = entry.value.toDouble();
          }
        }
      }
      
      return PlaybackSettings(
        shuffleEnabled: map['shuffleEnabled'] ?? false,
        repeatMode: RepeatMode.values[repeatModeIndex],
        playbackSpeed: playbackSpeed,
        crossfadeDuration: crossfadeDuration,
        gaplessPlayback: map['gaplessPlayback'] ?? true,
        volume: volume,
        sleepTimerEnabled: map['sleepTimerEnabled'] ?? false,
        sleepTimerDuration: _parseIntSafely(map['sleepTimerDuration'], 30),
        resumeAfterReboot: map['resumeAfterReboot'] ?? true,
        equalizerSettings: equalizerSettings,
        skipSilence: map['skipSilence'] ?? false,
        bassBoost: _parseDoubleSafely(map['bassBoost'], 0.0).clamp(0.0, 1.0),
        trebleBoost: _parseDoubleSafely(map['trebleBoost'], 0.0).clamp(0.0, 1.0),
        autoPlay: map['autoPlay'] ?? true,
        showNotifications: map['showNotifications'] ?? true,
        audioQuality: audioQuality,
        fadeInOut: map['fadeInOut'] ?? false,
        fadeInDuration: _parseIntSafely(map['fadeInDuration'], 1000).clamp(0, 10000),
        fadeOutDuration: _parseIntSafely(map['fadeOutDuration'], 1000).clamp(0, 10000),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing PlaybackSettings from map: $e');
      }
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'shuffleEnabled': shuffleEnabled,
      'repeatMode': repeatMode.index,
      'playbackSpeed': playbackSpeed,
      'crossfadeDuration': crossfadeDuration,
      'gaplessPlayback': gaplessPlayback,
      'volume': volume,
      'sleepTimerEnabled': sleepTimerEnabled,
      'sleepTimerDuration': sleepTimerDuration,
      'resumeAfterReboot': resumeAfterReboot,
      'equalizerSettings': equalizerSettings,
      'skipSilence': skipSilence,
      'bassBoost': bassBoost,
      'trebleBoost': trebleBoost,
      'autoPlay': autoPlay,
      'showNotifications': showNotifications,
      'audioQuality': audioQuality,
      'fadeInOut': fadeInOut,
      'fadeInDuration': fadeInDuration,
      'fadeOutDuration': fadeOutDuration,
    };
  }

  PlaybackSettings copyWith({
    bool? shuffleEnabled,
    RepeatMode? repeatMode,
    double? playbackSpeed,
    int? crossfadeDuration,
    bool? gaplessPlayback,
    double? volume,
    bool? sleepTimerEnabled,
    int? sleepTimerDuration,
    bool? resumeAfterReboot,
    Map<String, double>? equalizerSettings,
    bool? skipSilence,
    double? bassBoost,
    double? trebleBoost,
    bool? autoPlay,
    bool? showNotifications,
    String? audioQuality,
    bool? fadeInOut,
    int? fadeInDuration,
    int? fadeOutDuration,
  }) {
    return PlaybackSettings(
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      repeatMode: repeatMode ?? this.repeatMode,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      crossfadeDuration: crossfadeDuration ?? this.crossfadeDuration,
      gaplessPlayback: gaplessPlayback ?? this.gaplessPlayback,
      volume: volume ?? this.volume,
      sleepTimerEnabled: sleepTimerEnabled ?? this.sleepTimerEnabled,
      sleepTimerDuration: sleepTimerDuration ?? this.sleepTimerDuration,
      resumeAfterReboot: resumeAfterReboot ?? this.resumeAfterReboot,
      equalizerSettings: equalizerSettings ?? this.equalizerSettings,
      skipSilence: skipSilence ?? this.skipSilence,
      bassBoost: bassBoost ?? this.bassBoost,
      trebleBoost: trebleBoost ?? this.trebleBoost,
      autoPlay: autoPlay ?? this.autoPlay,
      showNotifications: showNotifications ?? this.showNotifications,
      audioQuality: audioQuality ?? this.audioQuality,
      fadeInOut: fadeInOut ?? this.fadeInOut,
      fadeInDuration: fadeInDuration ?? this.fadeInDuration,
      fadeOutDuration: fadeOutDuration ?? this.fadeOutDuration,
    );
  }

  /// Reset to default settings
  PlaybackSettings resetToDefaults() {
    return PlaybackSettings();
  }
  
  /// Get formatted playback speed string
  String get formattedPlaybackSpeed {
    if (playbackSpeed == 1.0) return 'Normal';
    return '${playbackSpeed.toStringAsFixed(1)}x';
  }
  
  /// Get formatted crossfade duration string
  String get formattedCrossfadeDuration {
    if (crossfadeDuration == 0) return 'Off';
    return '${crossfadeDuration}s';
  }
  
  /// Get formatted sleep timer duration string
  String get formattedSleepTimerDuration {
    if (sleepTimerDuration < 60) {
      return '${sleepTimerDuration}m';
    } else {
      final hours = sleepTimerDuration ~/ 60;
      final minutes = sleepTimerDuration % 60;
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
  }
  
  /// Get formatted volume percentage
  String get formattedVolume {
    return '${(volume * 100).round()}%';
  }
  
  /// Check if any equalizer bands are active
  bool get hasActiveEqualizer {
    return equalizerSettings.values.any((value) => value != 0.0);
  }
  
  /// Check if any audio enhancements are active
  bool get hasAudioEnhancements {
    return bassBoost > 0.0 || trebleBoost > 0.0 || hasActiveEqualizer;
  }
  
  /// Validate all settings
  bool get isValid {
    try {
      if (playbackSpeed < 0.25 || playbackSpeed > 3.0) return false;
      if (volume < 0.0 || volume > 1.0) return false;
      if (crossfadeDuration < 0 || crossfadeDuration > 30) return false;
      if (sleepTimerDuration <= 0) return false;
      if (bassBoost < 0.0 || bassBoost > 1.0) return false;
      if (trebleBoost < 0.0 || trebleBoost > 1.0) return false;
      if (!['low', 'medium', 'high', 'lossless'].contains(audioQuality)) return false;
      if (fadeInDuration < 0 || fadeInDuration > 10000) return false;
      if (fadeOutDuration < 0 || fadeOutDuration > 10000) return false;
      return true;
    } catch (e) {
      return false;
    }
  }
  
  @override
  String toString() {
    return 'PlaybackSettings(shuffle: $shuffleEnabled, repeat: $repeatMode, speed: $formattedPlaybackSpeed, volume: $formattedVolume)';
  }
  
  // Helper methods for parsing
  static int _parseIntSafely(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    if (value is double) return value.toInt();
    return defaultValue;
  }
  
  static double _parseDoubleSafely(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }
}

@HiveType(typeId: 4)
enum RepeatMode {
  @HiveField(0)
  none,
  @HiveField(1)
  one,
  @HiveField(2)
  all,
}
