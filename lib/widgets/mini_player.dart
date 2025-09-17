import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../providers/music_provider.dart';
import '../screens/now_playing_screen.dart';
import '../models/playback_settings.dart';
import '../services/logging_service.dart';

class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({super.key});
  
  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _progressController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _progressAnimation;
  
  final LoggingService _loggingService = LoggingService();
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void dispose() {
    _slideController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSong = ref.watch(currentSongProvider).value;
    final playbackState = ref.watch(playbackStateProvider).value;
    final audioHandler = ref.read(audioHandlerProvider);

    if (currentSong == null) {
      // Animate out if no song
      _slideController.reverse();
      return const SizedBox.shrink();
    }
    
    // Animate in when song is playing
    _slideController.forward();

    return Semantics(
      label: 'Mini player',
      hint: 'Currently playing ${currentSong.title}. Tap to open full player, long press for quick controls',
      child: SlideTransition(
        position: _slideAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _isExpanded ? 140 : 80,
          decoration: BoxDecoration(
            color: Colors.grey[900],
            border: Border(
              top: BorderSide(color: Colors.grey[800]!, width: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _loggingService.logInfo('Mini player tapped - opening now playing');
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const NowPlayingScreen(),
                        fullscreenDialog: true,
                      ),
                    );
                  },
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  child: Column(
                    children: [
                      // Enhanced progress bar at the top
                      StreamBuilder<Duration>(
                        stream: audioHandler.positionStream,
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          final duration = currentSong.duration ?? Duration.zero;
                          
                          if (duration.inMilliseconds <= 0) {
                            return Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(1.5),
                                ),
                              ),
                            );
                          }
                          
                          final progress = duration.inMilliseconds > 0 
                              ? position.inMilliseconds / duration.inMilliseconds
                              : 0.0;
                          
                          return Container(
                            height: 3,
                            child: LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              backgroundColor: Colors.grey[800],
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
                              minHeight: 3,
                            ),
                          );
                        },
                      ),
                      
                      // Main content
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              // Album art with enhanced styling
                              _buildAlbumArt(currentSong),
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
                                        fontWeight: FontWeight.w600,
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
                              
                              // Enhanced control buttons
                              _buildControlButtons(audioHandler),
                            ],
                          ),
                        ),
                      ),
                      
                      // Expanded content (volume, additional controls)
                      if (_isExpanded)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: _buildExpandedControls(audioHandler),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildAlbumArt(MediaItem currentSong) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: currentSong.artUri != null
          ? Image.file(
              File(currentSong.artUri!.toFilePath()),
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              cacheWidth: 56,
              cacheHeight: 56,
              errorBuilder: (context, error, stackTrace) {
                return _buildDefaultAlbumArt();
              },
            )
          : _buildDefaultAlbumArt(),
    );
  }
  
  Widget _buildDefaultAlbumArt() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[800]!,
            Colors.grey[900]!,
          ],
        ),
      ),
      child: const Icon(
        Icons.music_note_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }
  
  Widget _buildControlButtons(audioHandler) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Previous button (only show if expanded)
        if (_isExpanded)
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              audioHandler.skipToPrevious();
            },
            icon: const Icon(
              Icons.skip_previous,
              color: Colors.white,
            ),
            iconSize: 24,
            tooltip: 'Previous song',
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),
        
        // Play/Pause button
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: StreamBuilder<PlaybackState>(
            stream: audioHandler.playbackState,
            builder: (context, snapshot) {
              final playbackState = snapshot.data;
              final isPlaying = playbackState?.playing ?? false;
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                  border: Border.all(
                    color: const Color(0xFF00E676).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
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
                  iconSize: 28,
                  tooltip: isPlaying ? 'Pause' : 'Play',
                ),
              );
            },
          ),
        ),
        
        // Next button (only show if expanded)
        if (_isExpanded)
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              audioHandler.skipToNext();
            },
            icon: const Icon(
              Icons.skip_next,
              color: Colors.white,
            ),
            iconSize: 24,
            tooltip: 'Next song',
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),
      ],
    );
  }
  
  Widget _buildExpandedControls(audioHandler) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Volume control
          Icon(
            Icons.volume_up,
            color: Colors.grey[400],
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StreamBuilder<PlaybackState>(
              stream: audioHandler.playbackState,
              builder: (context, snapshot) {
                // Note: PlaybackState doesn't have volume, this is a placeholder
                const volume = 1.0;
                
                return SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: const Color(0xFF00E676),
                    inactiveTrackColor: Colors.grey[700],
                    thumbColor: const Color(0xFF00E676),
                  ),
                  child: Slider(
                    value: volume,
                    onChanged: (value) {
                      // TODO: Implement volume control when available
                    },
                    min: 0.0,
                    max: 1.0,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          
          // Shuffle button
          StreamBuilder<PlaybackState>(
            stream: audioHandler.playbackState,
            builder: (context, snapshot) {
              final shuffleEnabled = snapshot.data?.shuffleMode == AudioServiceShuffleMode.all;
              return IconButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  // TODO: Implement shuffle toggle when available
                },
                icon: Icon(
                  Icons.shuffle,
                  color: shuffleEnabled ? const Color(0xFF00E676) : Colors.grey[400],
                  size: 16,
                ),
                tooltip: shuffleEnabled ? 'Disable shuffle' : 'Enable shuffle',
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              );
            },
          ),
          
          // Repeat button
          StreamBuilder<PlaybackState>(
            stream: audioHandler.playbackState,
            builder: (context, snapshot) {
              final repeatMode = snapshot.data?.repeatMode ?? AudioServiceRepeatMode.none;
              return IconButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _cycleRepeatMode(audioHandler, repeatMode);
                },
                icon: Icon(
                  _getRepeatIcon(repeatMode),
                  color: repeatMode != AudioServiceRepeatMode.none 
                      ? const Color(0xFF00E676) 
                      : Colors.grey[400],
                  size: 16,
                ),
                tooltip: _getRepeatTooltip(repeatMode),
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  void _cycleRepeatMode(audioHandler, AudioServiceRepeatMode currentMode) {
    AudioServiceRepeatMode nextMode;
    switch (currentMode) {
      case AudioServiceRepeatMode.none:
        nextMode = AudioServiceRepeatMode.all;
        break;
      case AudioServiceRepeatMode.all:
        nextMode = AudioServiceRepeatMode.one;
        break;
      case AudioServiceRepeatMode.one:
        nextMode = AudioServiceRepeatMode.none;
        break;
      default:
        nextMode = AudioServiceRepeatMode.none;
    }
    audioHandler.setRepeatMode(nextMode);
  }
  
  IconData _getRepeatIcon(AudioServiceRepeatMode mode) {
    switch (mode) {
      case AudioServiceRepeatMode.one:
        return Icons.repeat_one;
      case AudioServiceRepeatMode.all:
        return Icons.repeat;
      default:
        return Icons.repeat;
    }
  }
  
  String _getRepeatTooltip(AudioServiceRepeatMode mode) {
    switch (mode) {
      case AudioServiceRepeatMode.none:
        return 'Enable repeat all';
      case AudioServiceRepeatMode.all:
        return 'Enable repeat one';
      case AudioServiceRepeatMode.one:
        return 'Disable repeat';
      default:
        return 'Toggle repeat';
    }
  }
}
