import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../providers/music_provider.dart';
import '../models/song.dart';

class QueuePanel extends ConsumerWidget {
  const QueuePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(queueProvider).value ?? [];
    final currentSong = ref.watch(currentSongProvider).value;
    final audioHandler = ref.read(audioHandlerProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Queue',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${queue.length} songs',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: queue.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.queue_music,
                          size: 48,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Queue is empty',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add songs to start playing',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: queue.length,
                    itemBuilder: (context, index) {
                      final song = queue[index];
                      final isCurrentSong = currentSong?.id == song.id;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isCurrentSong ? Colors.grey[800] : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: song.artUri != null
                                ? Image.file(
                                    File(song.artUri!.toFilePath()),
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 40,
                                        height: 40,
                                        color: Colors.grey[700],
                                        child: const Icon(
                                          Icons.music_note,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    width: 40,
                                    height: 40,
                                    color: Colors.grey[700],
                                    child: const Icon(
                                      Icons.music_note,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                          ),
                          title: Text(
                            song.title,
                            style: TextStyle(
                              color: isCurrentSong ? Colors.green : Colors.white,
                              fontSize: 14,
                              fontWeight: isCurrentSong ? FontWeight.bold : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            song.artist ?? '',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isCurrentSong)
                                Icon(
                                  Icons.equalizer,
                                  color: Colors.green,
                                  size: 16,
                                ),
                              IconButton(
                                onPressed: () {
                                  audioHandler.removeQueueItem(song);
                                },
                                icon: Icon(
                                  Icons.close,
                                  color: Colors.grey[400],
                                  size: 16,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          onTap: () {
                            // Jump to song in queue
                            // This would require implementing a method to jump to a specific index
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
