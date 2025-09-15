import 'package:hive/hive.dart';

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
  });

  factory PlaybackSettings.fromMap(Map<String, dynamic> map) {
    return PlaybackSettings(
      shuffleEnabled: map['shuffleEnabled'] ?? false,
      repeatMode: RepeatMode.values[map['repeatMode'] ?? 0],
      playbackSpeed: (map['playbackSpeed'] ?? 1.0).toDouble(),
      crossfadeDuration: map['crossfadeDuration'] ?? 0,
      gaplessPlayback: map['gaplessPlayback'] ?? true,
      volume: (map['volume'] ?? 1.0).toDouble(),
      sleepTimerEnabled: map['sleepTimerEnabled'] ?? false,
      sleepTimerDuration: map['sleepTimerDuration'] ?? 30,
      resumeAfterReboot: map['resumeAfterReboot'] ?? true,
      equalizerSettings: Map<String, double>.from(map['equalizerSettings'] ?? {}),
    );
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
    );
  }

  @override
  String toString() {
    return 'PlaybackSettings(shuffle: $shuffleEnabled, repeat: $repeatMode, speed: $playbackSpeed)';
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
