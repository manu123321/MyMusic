// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlaybackSettingsAdapter extends TypeAdapter<PlaybackSettings> {
  @override
  final int typeId = 3;

  @override
  PlaybackSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlaybackSettings(
      shuffleEnabled: fields[0] as bool,
      repeatMode: fields[1] as RepeatMode,
      playbackSpeed: fields[2] as double,
      crossfadeDuration: fields[3] as int,
      gaplessPlayback: fields[4] as bool,
      volume: fields[5] as double,
      sleepTimerEnabled: fields[6] as bool,
      sleepTimerDuration: fields[7] as int,
      resumeAfterReboot: fields[8] as bool,
      equalizerSettings: (fields[9] as Map).cast<String, double>(),
    );
  }

  @override
  void write(BinaryWriter writer, PlaybackSettings obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.shuffleEnabled)
      ..writeByte(1)
      ..write(obj.repeatMode)
      ..writeByte(2)
      ..write(obj.playbackSpeed)
      ..writeByte(3)
      ..write(obj.crossfadeDuration)
      ..writeByte(4)
      ..write(obj.gaplessPlayback)
      ..writeByte(5)
      ..write(obj.volume)
      ..writeByte(6)
      ..write(obj.sleepTimerEnabled)
      ..writeByte(7)
      ..write(obj.sleepTimerDuration)
      ..writeByte(8)
      ..write(obj.resumeAfterReboot)
      ..writeByte(9)
      ..write(obj.equalizerSettings);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaybackSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RepeatModeAdapter extends TypeAdapter<RepeatMode> {
  @override
  final int typeId = 4;

  @override
  RepeatMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RepeatMode.none;
      case 1:
        return RepeatMode.one;
      case 2:
        return RepeatMode.all;
      default:
        return RepeatMode.none;
    }
  }

  @override
  void write(BinaryWriter writer, RepeatMode obj) {
    switch (obj) {
      case RepeatMode.none:
        writer.writeByte(0);
        break;
      case RepeatMode.one:
        writer.writeByte(1);
        break;
      case RepeatMode.all:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepeatModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
