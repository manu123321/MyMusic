import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../providers/music_provider.dart';
import '../screens/now_playing_screen.dart';
import '../models/playback_settings.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(currentSongProvider).value;
    final playbackState = ref.watch(playbackStateProvider).value;
    final audioHandler = ref.read(audioHandlerProvider);

    if (currentSong == null) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          top: BorderSide(color: Colors.grey[800]!, width: 0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const NowPlayingScreen(),
                fullscreenDialog: true,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Album art
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: currentSong.artUri != null
                      ? Image.file(
                          File(currentSong.artUri!.toFilePath()),
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 56,
                              height: 56,
                              color: Colors.grey[800],
                              child: const Icon(
                                Icons.music_note,
                                color: Colors.white,
                                size: 24,
                              ),
                            );
                          },
                        )
                      : Container(
                          width: 56,
                          height: 56,
                          color: Colors.grey[800],
                          child: const Icon(
                            Icons.music_note,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                
                // Song info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        currentSong.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentSong.artist ?? '',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // Progress bar
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      StreamBuilder<Duration>(
                        stream: audioHandler.playbackState.map((state) => state.position),
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          final duration = currentSong.duration ?? Duration.zero;
                          
                          if (duration.inMilliseconds == 0) {
                            return const SizedBox.shrink();
                          }
                          
                          return SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.grey[600],
                              thumbColor: Colors.white,
                            ),
                            child: Slider(
                              value: position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble()),
                              max: duration.inMilliseconds.toDouble(),
                              onChanged: (value) {
                                audioHandler.seek(Duration(milliseconds: value.toInt()));
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                
                // Controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => audioHandler.skipToPrevious(),
                      icon: const Icon(Icons.skip_previous, color: Colors.white),
                      iconSize: 28,
                    ),
                    StreamBuilder<bool>(
                      stream: audioHandler.playbackState.map((state) => state.playing),
                      builder: (context, snapshot) {
                        final isPlaying = snapshot.data ?? false;
                        return IconButton(
                          onPressed: () {
                            if (isPlaying) {
                              audioHandler.pause();
                            } else {
                              audioHandler.play();
                            }
                          },
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                          ),
                          iconSize: 32,
                        );
                      },
                    ),
                    IconButton(
                      onPressed: () => audioHandler.skipToNext(),
                      icon: const Icon(Icons.skip_next, color: Colors.white),
                      iconSize: 28,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
