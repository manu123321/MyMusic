import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:intl/intl.dart'; // for formatting
import '../main.dart'; // access audioHandler

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  @override
  void initState() {
    super.initState();
    // Optional: preload a local playlist on first run
    _loadDemoPlaylist();
  }

  Future<void> _loadDemoPlaylist() async {
    if (audioHandler.queue.value.isEmpty) {
      // Add three asset songs (example). Make sure these asset URIs match your assets
      final items = [
        MediaItem(
          id: 'asset:///assets/audio/song1.mp3',
          album: 'Album 1',
          title: 'Song 1',
          artist: 'Artist A',
          artUri: Uri.parse('asset:///assets/artwork/art1.jpg'),
        ),
        MediaItem(
          id: 'asset:///assets/audio/song2.mp3',
          album: 'Album 1',
          title: 'Song 2',
          artist: 'Artist A',
          artUri: Uri.parse('asset:///assets/artwork/art2.jpg'),
        ),
      ];
      await audioHandler.addQueueItems(items);
    }
  }

  String _format(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Album art & metadata
            StreamBuilder<MediaItem?>(
              stream: audioHandler.mediaItem,
              builder: (context, snapshot) {
                final mediaItem = snapshot.data;
                return Column(
                  children: [
                    SizedBox(
                      height: 320,
                      child: mediaItem?.artUri != null
                          ? Image(
                        image: mediaItem!.artUri!.scheme == 'asset'
                            ? AssetImage(mediaItem.artUri!.path.replaceFirst('/', '')) as ImageProvider
                            : NetworkImage(mediaItem.artUri.toString()) as ImageProvider,
                        fit: BoxFit.cover,
                      )
                          : const Icon(Icons.music_note, size: 160),
                    ),
                    const SizedBox(height: 12),
                    Text(mediaItem?.title ?? 'No song', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(mediaItem?.artist ?? '', style: const TextStyle(fontSize: 16)),
                  ],
                );
              },
            ),

            // Progress & controls
            StreamBuilder<PlaybackState>(
              stream: audioHandler.playbackState,
              builder: (context, snapshot) {
                final playbackState = snapshot.data;
                final position = playbackState?.position ?? Duration.zero;
                final bufferedPosition = playbackState?.bufferedPosition ?? Duration.zero;
                final total = audioHandler.mediaItem.value?.duration ?? Duration.zero;

                return Column(
                  children: [
                    Slider(
                      value: position.inMilliseconds.toDouble().clamp(0, total.inMilliseconds.toDouble() == 0 ? 1 : total.inMilliseconds.toDouble()),
                      max: total.inMilliseconds.toDouble() == 0 ? 1 : total.inMilliseconds.toDouble(),
                      onChanged: (v) {
                        audioHandler.seek(Duration(milliseconds: v.toInt()));
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_format(position)),
                          Text(_format(total)),
                        ],
                      ),
                    ),
                    // Controls row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(onPressed: () => audioHandler.skipToPrevious(), icon: const Icon(Icons.skip_previous)),
                        StreamBuilder<bool>(
                          stream: audioHandler.playbackState.map((s) => s.playing).distinct(),
                          builder: (context, snap) {
                            final playing = snap.data ?? false;
                            return IconButton(
                              iconSize: 64,
                              onPressed: () => playing ? audioHandler.pause() : audioHandler.play(),
                              icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
                            );
                          },
                        ),
                        IconButton(onPressed: () => audioHandler.skipToNext(), icon: const Icon(Icons.skip_next)),
                      ],
                    ),
                    // Shuffle / Repeat / Queue buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(onPressed: () async {
                          // Toggle shuffle
                          final enabled = (audioHandler.playbackState.value.shuffleMode == AudioServiceShuffleMode.none);
                          // just_audio shuffle API exposed in handler via a custom method; we used setShuffleModeEnabled
                          // call custom method via audioHandler.customAction if needed. Here for demo:
                          // (Assuming we implemented customAction in handler for toggling shuffle)
                          await audioHandler.customAction('toggleShuffle', {'enabled': enabled});
                        }, icon: const Icon(Icons.shuffle)),
                        IconButton(onPressed: () async {
                          // cycle repeat mode
                          final current = audioHandler.playbackState.value.repeatMode;
                          final next = current == AudioServiceRepeatMode.none ? AudioServiceRepeatMode.all : current == AudioServiceRepeatMode.all ? AudioServiceRepeatMode.one : AudioServiceRepeatMode.none;
                          await audioHandler.setRepeatMode(next);
                        }, icon: const Icon(Icons.repeat)),
                        IconButton(onPressed: () {
                          // open queue screen or show queue
                        }, icon: const Icon(Icons.queue_music)),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
