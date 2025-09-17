import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';

part 'queue_item.g.dart';

@HiveType(typeId: 2)
class QueueItem extends HiveObject {
  @HiveField(0)
  String songId;

  @HiveField(1)
  int position;

  @HiveField(2)
  DateTime addedAt;
  
  @HiveField(3)
  bool isCurrentlyPlaying;
  
  @HiveField(4)
  String? source; // 'playlist', 'album', 'search', etc.
  
  @HiveField(5)
  Map<String, dynamic>? metadata; // additional context data

  QueueItem({
    required this.songId,
    required this.position,
    required this.addedAt,
    this.isCurrentlyPlaying = false,
    this.source,
    this.metadata,
  }) : assert(songId.trim().isNotEmpty, 'Song ID cannot be empty'),
       assert(position >= 0, 'Position must be non-negative');

  factory QueueItem.fromMap(Map<String, dynamic> map) {
    try {
      final songId = (map['songId'] as String?)?.trim();
      if (songId == null || songId.isEmpty) {
        throw ArgumentError('Song ID cannot be null or empty');
      }
      
      final position = _parseIntSafely(map['position'], 0);
      if (position < 0) {
        throw ArgumentError('Position must be non-negative');
      }
      
      return QueueItem(
        songId: songId,
        position: position,
        addedAt: _parseDateTimeSafely(map['addedAt']) ?? DateTime.now(),
        isCurrentlyPlaying: map['isCurrentlyPlaying'] ?? false,
        source: map['source'],
        metadata: map['metadata'] != null 
            ? Map<String, dynamic>.from(map['metadata'])
            : null,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing QueueItem from map: $e');
      }
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'songId': songId,
      'position': position,
      'addedAt': addedAt.toIso8601String(),
      'isCurrentlyPlaying': isCurrentlyPlaying,
      'source': source,
      'metadata': metadata,
    };
  }

  QueueItem copyWith({
    String? songId,
    int? position,
    DateTime? addedAt,
    bool? isCurrentlyPlaying,
    String? source,
    Map<String, dynamic>? metadata,
  }) {
    return QueueItem(
      songId: songId ?? this.songId,
      position: position ?? this.position,
      addedAt: addedAt ?? this.addedAt,
      isCurrentlyPlaying: isCurrentlyPlaying ?? this.isCurrentlyPlaying,
      source: source ?? this.source,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Create a queue item with current playing status
  QueueItem asCurrentlyPlaying() {
    return copyWith(isCurrentlyPlaying: true);
  }
  
  /// Create a queue item without current playing status
  QueueItem asNotCurrentlyPlaying() {
    return copyWith(isCurrentlyPlaying: false);
  }
  
  /// Update position
  QueueItem updatePosition(int newPosition) {
    if (newPosition < 0) {
      throw ArgumentError('Position must be non-negative');
    }
    return copyWith(position: newPosition);
  }
  
  /// Add metadata
  QueueItem addMetadata(String key, dynamic value) {
    final newMetadata = Map<String, dynamic>.from(metadata ?? {});
    newMetadata[key] = value;
    return copyWith(metadata: newMetadata);
  }
  
  /// Remove metadata
  QueueItem removeMetadata(String key) {
    if (metadata == null || !metadata!.containsKey(key)) {
      return this;
    }
    final newMetadata = Map<String, dynamic>.from(metadata!);
    newMetadata.remove(key);
    return copyWith(metadata: newMetadata.isEmpty ? null : newMetadata);
  }
  
  /// Get queue item age in minutes
  int get ageInMinutes {
    return DateTime.now().difference(addedAt).inMinutes;
  }
  
  /// Check if queue item was added recently (within 5 minutes)
  bool get isRecentlyAdded {
    return ageInMinutes < 5;
  }
  
  @override
  String toString() {
    return 'QueueItem(songId: $songId, position: $position, playing: $isCurrentlyPlaying, source: $source)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QueueItem && 
           other.songId == songId && 
           other.position == position;
  }

  @override
  int get hashCode => Object.hash(songId, position);
  
  // Helper methods for parsing
  static int _parseIntSafely(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    if (value is double) return value.toInt();
    return defaultValue;
  }
  
  static DateTime? _parseDateTimeSafely(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
