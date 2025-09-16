// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'song.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SongAdapter extends TypeAdapter<Song> {
  @override
  final int typeId = 0;

  @override
  Song read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Song(
      id: fields[0] as String,
      title: fields[1] as String,
      artist: fields[2] as String,
      album: fields[3] as String,
      filePath: fields[4] as String,
      duration: fields[5] as int,
      albumArtPath: fields[6] as String?,
      trackNumber: fields[7] as int?,
      year: fields[8] as int?,
      genre: fields[9] as String?,
      dateAdded: fields[10] as DateTime,
      lastPlayed: fields[11] as DateTime?,
      playCount: fields[12] as int,
      lyricsPath: fields[14] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Song obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.artist)
      ..writeByte(3)
      ..write(obj.album)
      ..writeByte(4)
      ..write(obj.filePath)
      ..writeByte(5)
      ..write(obj.duration)
      ..writeByte(6)
      ..write(obj.albumArtPath)
      ..writeByte(7)
      ..write(obj.trackNumber)
      ..writeByte(8)
      ..write(obj.year)
      ..writeByte(9)
      ..write(obj.genre)
      ..writeByte(10)
      ..write(obj.dateAdded)
      ..writeByte(11)
      ..write(obj.lastPlayed)
      ..writeByte(12)
      ..write(obj.playCount)
      ..writeByte(14)
      ..write(obj.lyricsPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SongAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
