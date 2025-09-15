import 'package:hive/hive.dart';

part 'queue_item.g.dart';

@HiveType(typeId: 2)
class QueueItem extends HiveObject {
  @HiveField(0)
  String songId;

  @HiveField(1)
  int position;

  @HiveField(2)
  DateTime addedAt;

  QueueItem({
    required this.songId,
    required this.position,
    required this.addedAt,
  });

  factory QueueItem.fromMap(Map<String, dynamic> map) {
    return QueueItem(
      songId: map['songId'] ?? '',
      position: map['position'] ?? 0,
      addedAt: DateTime.tryParse(map['addedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'songId': songId,
      'position': position,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  QueueItem copyWith({
    String? songId,
    int? position,
    DateTime? addedAt,
  }) {
    return QueueItem(
      songId: songId ?? this.songId,
      position: position ?? this.position,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  String toString() {
    return 'QueueItem(songId: $songId, position: $position)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QueueItem && other.songId == songId && other.position == position;
  }

  @override
  int get hashCode => Object.hash(songId, position);
}
