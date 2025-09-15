import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../providers/music_provider.dart';
import '../services/custom_audio_handler.dart';
import '../widgets/lyrics_panel.dart';
import '../widgets/queue_panel.dart';
import '../widgets/equalizer_panel.dart';
import '../widgets/sleep_timer_dialog.dart';
import '../models/playback_settings.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen>
    with TickerProviderStateMixin {
  late AnimationController _albumArtController;
  late AnimationController _progressController;
  bool _showLyrics = false;
  bool _showQueue = false;
  bool _showEqualizer = false;

  @override
  void initState() {
    super.initState();
    _albumArtController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _albumArtController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSong = ref.watch(currentSongProvider).value;
    final playbackState = ref.watch(playbackStateProvider).value;
    final audioHandler = ref.read(audioHandlerProvider);

    if (currentSong == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          ),
        ),
        body: const Center(
          child: Text(
            'No song playing',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                  ),
                  const Text(
                    'Now playing',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // Show more options
                    },
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Album art
            Expanded(
              flex: 3,
              child: Center(
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: StreamBuilder<bool>(
                    stream: audioHandler.playbackState.map((state) => state.playing),
                    builder: (context, snapshot) {
                      final isPlaying = snapshot.data ?? false;
                      
                      if (isPlaying) {
                        _albumArtController.repeat();
                      } else {
                        _albumArtController.stop();
                      }

                      return AnimatedBuilder(
                        animation: _albumArtController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _albumArtController.value * 2 * 3.14159,
                            child: ClipOval(
                              child: currentSong.artUri != null
                                  ? Image.file(
                                      File(currentSong.artUri!.toFilePath()),
                                      width: 300,
                                      height: 300,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: 300,
                                          height: 300,
                                          color: Colors.grey[800],
                                          child: const Icon(
                                            Icons.music_note,
                                            color: Colors.white,
                                            size: 120,
                                          ),
                                        );
                                      },
                                    )
                                  : Container(
                                      width: 300,
                                      height: 300,
                                      color: Colors.grey[800],
                                      child: const Icon(
                                        Icons.music_note,
                                        color: Colors.white,
                                        size: 120,
                                      ),
                                    ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),

            // Song info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      currentSong.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentSong.artist ?? '',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),

            // Progress bar
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    StreamBuilder<Duration>(
                      stream: audioHandler.playbackState.map((state) => state.position),
                      builder: (context, snapshot) {
                        final position = snapshot.data ?? Duration.zero;
                        final duration = currentSong.duration ?? Duration.zero;
                        
                        return Column(
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
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
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(position),
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  _formatDuration(duration),
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Controls
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Secondary controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          onPressed: () {
                            // Toggle shuffle
                            final currentShuffle = playbackState?.shuffleMode == AudioServiceShuffleMode.all;
                            (audioHandler as CustomAudioHandler).setShuffleModeEnabled(!currentShuffle);
                          },
                          icon: Icon(
                            Icons.shuffle,
                            color: playbackState?.shuffleMode == AudioServiceShuffleMode.all
                                ? Colors.green
                                : Colors.grey[400],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            // Toggle repeat
                            final currentRepeat = playbackState?.repeatMode ?? AudioServiceRepeatMode.none;
                            AudioServiceRepeatMode nextRepeat;
                            switch (currentRepeat) {
                              case AudioServiceRepeatMode.none:
                                nextRepeat = AudioServiceRepeatMode.all;
                                break;
                              case AudioServiceRepeatMode.all:
                                nextRepeat = AudioServiceRepeatMode.one;
                                break;
                              case AudioServiceRepeatMode.one:
                                nextRepeat = AudioServiceRepeatMode.none;
                                break;
                              case AudioServiceRepeatMode.group:
                                nextRepeat = AudioServiceRepeatMode.none;
                                break;
                            }
                            audioHandler.setRepeatMode(nextRepeat);
                          },
                          icon: Icon(
                            _getRepeatIcon(playbackState?.repeatMode ?? AudioServiceRepeatMode.none),
                            color: playbackState?.repeatMode != AudioServiceRepeatMode.none
                                ? Colors.green
                                : Colors.grey[400],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _showQueue = !_showQueue;
                            });
                          },
                          icon: Icon(
                            Icons.queue_music,
                            color: _showQueue ? Colors.green : Colors.grey[400],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _showLyrics = !_showLyrics;
                              if (_showLyrics) {
                                _showEqualizer = false;
                              }
                            });
                          },
                          icon: Icon(
                            Icons.lyrics,
                            color: _showLyrics ? Colors.green : Colors.grey[400],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _showEqualizer = !_showEqualizer;
                              if (_showEqualizer) {
                                _showLyrics = false;
                              }
                            });
                          },
                          icon: Icon(
                            Icons.equalizer,
                            color: _showEqualizer ? Colors.green : Colors.grey[400],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => const SleepTimerDialog(),
                            );
                          },
                          icon: Icon(
                            Icons.timer,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Main controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          onPressed: () => audioHandler.skipToPrevious(),
                          icon: const Icon(Icons.skip_previous, color: Colors.white),
                          iconSize: 40,
                        ),
                        StreamBuilder<bool>(
                          stream: audioHandler.playbackState.map((state) => state.playing),
                          builder: (context, snapshot) {
                            final isPlaying = snapshot.data ?? false;
                            return Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: IconButton(
                                onPressed: () {
                                  if (isPlaying) {
                                    audioHandler.pause();
                                  } else {
                                    audioHandler.play();
                                  }
                                },
                                icon: Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.black,
                                ),
                                iconSize: 48,
                              ),
                            );
                          },
                        ),
                        IconButton(
                          onPressed: () => audioHandler.skipToNext(),
                          icon: const Icon(Icons.skip_next, color: Colors.white),
                          iconSize: 40,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Lyrics, Queue, or Equalizer panel
            if (_showLyrics || _showQueue || _showEqualizer)
              Expanded(
                flex: 2,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _showLyrics
                      ? const LyricsPanel()
                      : _showQueue
                          ? const QueuePanel()
                          : const EqualizerPanel(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  IconData _getRepeatIcon(AudioServiceRepeatMode mode) {
    switch (mode) {
      case AudioServiceRepeatMode.one:
        return Icons.repeat_one;
      case AudioServiceRepeatMode.all:
        return Icons.repeat;
      case AudioServiceRepeatMode.none:
        return Icons.repeat;
      case AudioServiceRepeatMode.group:
        return Icons.repeat;
    }
  }
}
