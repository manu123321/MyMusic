// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'queue_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class QueueItemAdapter extends TypeAdapter<QueueItem> {
  @override
  final int typeId = 2;

  @override
  QueueItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QueueItem(
      songId: fields[0] as String,
      position: fields[1] as int,
      addedAt: fields[2] as DateTime,
      isCurrentlyPlaying: fields[3] as bool,
      source: fields[4] as String?,
      metadata: (fields[5] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, QueueItem obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.songId)
      ..writeByte(1)
      ..write(obj.position)
      ..writeByte(2)
      ..write(obj.addedAt)
      ..writeByte(3)
      ..write(obj.isCurrentlyPlaying)
      ..writeByte(4)
      ..write(obj.source)
      ..writeByte(5)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueueItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
