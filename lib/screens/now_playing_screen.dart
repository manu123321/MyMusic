import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../providers/music_provider.dart';
import '../services/logging_service.dart';
import '../widgets/sleep_timer_dialog.dart';
import '../widgets/queue_panel.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _albumArtController;
  late AnimationController _progressController;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  
  final LoggingService _loggingService = LoggingService();
  
  bool _showLyrics = false;
  bool _showEqualizer = false;
  bool _isDraggingSlider = false;
  bool _isSwipeInProgress = false;
  double _swipeProgress = 0.0;
  double _swipeDirection = 0.0; // -1 for left (next), 1 for right (previous)
  MediaItem? _nextSong;
  MediaItem? _previousSong;
  Duration _sliderPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _albumArtController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    // Start entrance animation with delay to prevent glitches
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        _slideController.forward();
      }
    });
    
    _loggingService.logInfo('Now playing screen opened');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _albumArtController.dispose();
    _progressController.dispose();
    _slideController.dispose();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      _albumArtController.stop();
    } else if (state == AppLifecycleState.resumed) {
      // Add small delay to prevent glitches during resume
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          final playbackState = ref.read(playbackStateProvider).value;
          if (playbackState?.playing == true) {
            _albumArtController.repeat();
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSong = ref.watch(currentSongProvider).value;
    final audioHandler = ref.read(audioHandlerProvider);
    
    // CRITICAL FIX: Don't watch playbackStateProvider here as it causes entire screen rebuild
    // Individual widgets will watch it only when needed

    if (currentSong == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
            tooltip: 'Go back',
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.music_off,
                size: 80,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 16),
              Text(
                'No song playing',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Go back and select a song to play',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      key: const ValueKey('now_playing_screen'),
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: GestureDetector(
         onHorizontalDragStart: (details) {
           _isSwipeInProgress = true;
           _swipeProgress = 0.0;
           _swipeDirection = 0.0;
           
           // Pre-load adjacent songs for smooth experience
           _nextSong = _getNextSong();
           _previousSong = _getPreviousSong();
         },
         onHorizontalDragUpdate: (details) {
           if (_isSwipeInProgress) {
             final screenWidth = MediaQuery.of(context).size.width;
             final albumArtSize = 300.0; // Album art size
             final centerX = screenWidth / 2;
             final currentX = details.localPosition.dx;
             final dragDistance = currentX - centerX;
             
             // Calculate progress based on album art width (more intuitive)
             final maxDragDistance = albumArtSize * 0.8; // 80% of album art width for full transition
             final progress = (dragDistance.abs() / maxDragDistance).clamp(0.0, 1.0);
             
             // Determine direction: negative = left (next), positive = right (previous)
             final direction = dragDistance < 0 ? -1.0 : 1.0;
             
             // Only proceed if we have an adjacent song in that direction
             final hasAdjacentSong = direction < 0 ? _nextSong != null : _previousSong != null;
             
             if (hasAdjacentSong && dragDistance.abs() > 10) {
               _swipeProgress = progress;
               _swipeDirection = direction;
               
               // Store swipe state for rendering
             } else {
               // Reset if no adjacent song or minimal drag
               _swipeProgress = 0.0;
               _swipeDirection = 0.0;
             }
             
             if (mounted) {
               setState(() {});
             }
           }
         },
        onHorizontalDragEnd: (details) {
          if (_isSwipeInProgress) {
            _handleSwipeEnd(details, ref.read(audioHandlerProvider));
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: _buildBackgroundGradient(currentSong),
          child: SafeArea(
            child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                // Header with blur effect
                ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                            tooltip: 'Close',
                          ),
                          const Text(
                            'Now Playing',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              _showMoreOptions();
                            },
                            icon: const Icon(Icons.more_vert, color: Colors.white),
                            tooltip: 'More options',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                 // Swipeable Album Art Section
                 Expanded(
                   flex: 3,
                   child: _buildSwipeableAlbumSection(currentSong),
                 ),

            // Swipeable Song Info Section
            Expanded(
              flex: 2,
              child: _buildSwipeableSongInfo(currentSong),
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
                      stream: audioHandler.positionStream,
                      builder: (context, snapshot) {
                        final streamPosition = snapshot.data ?? Duration.zero;
                        final position = _isDraggingSlider ? _sliderPosition : streamPosition;
                        final duration = currentSong.duration ?? Duration.zero;
                        
                        return Column(
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                                activeTrackColor: Colors.white,
                                inactiveTrackColor: Colors.grey[600],
                                thumbColor: Colors.white,
                                overlayColor: Colors.white.withValues(alpha: 0.2),
                              ),
                              child: Slider(
                                value: position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble()),
                                max: duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                                onChangeStart: (value) {
                                  setState(() {
                                    _isDraggingSlider = true;
                                    _sliderPosition = Duration(milliseconds: value.toInt());
                                  });
                                  HapticFeedback.selectionClick();
                                },
                                onChanged: (value) {
                                  setState(() {
                                    _sliderPosition = Duration(milliseconds: value.toInt());
                                  });
                                },
                                onChangeEnd: (value) {
                                  final seekPosition = Duration(milliseconds: value.toInt());
                                  audioHandler.seek(seekPosition);
                                  setState(() {
                                    _isDraggingSlider = false;
                                    _sliderPosition = Duration.zero;
                                  });
                                  HapticFeedback.lightImpact();
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
                        Consumer(
                          builder: (context, ref, child) {
                            final playbackState = ref.watch(playbackStateProvider).value;
                            return IconButton(
                              onPressed: () {
                                // Toggle shuffle
                                final currentShuffle = playbackState?.shuffleMode == AudioServiceShuffleMode.all;
                                audioHandler.setShuffleModeEnabled(!currentShuffle);
                              },
                              icon: Icon(
                                Icons.shuffle,
                                color: playbackState?.shuffleMode == AudioServiceShuffleMode.all
                                    ? Colors.green
                                    : Colors.grey[400],
                              ),
                            );
                          },
                        ),
                        Consumer(
                          builder: (context, ref, child) {
                            final playbackState = ref.watch(playbackStateProvider).value;
                            final currentRepeat = playbackState?.repeatMode ?? AudioServiceRepeatMode.none;
                            
                            return IconButton(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                // Cycle through repeat modes: Off -> All -> One -> Off
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
                              icon: Stack(
                                children: [
                                  Icon(
                                    _getRepeatIcon(currentRepeat),
                                    color: _getRepeatIconColor(currentRepeat),
                                    size: 24,
                                  ),
                                  // Show "1" indicator for repeat one mode
                                  if (currentRepeat == AudioServiceRepeatMode.one)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.black, width: 1),
                                        ),
                                        child: const Center(
                                          child: Text(
                                            '1',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              tooltip: _getRepeatTooltip(currentRepeat),
                            );
                          },
                        ),
                        IconButton(
                          onPressed: () {
                            _showQueueModal();
                          },
                          icon: Icon(
                            Icons.queue_music,
                            color: Colors.grey[400],
                          ),
                          tooltip: 'Queue',
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
                        Consumer(
                          builder: (context, ref, child) {
                            final playbackSettings = ref.watch(playbackSettingsProvider);
                            final isTimerActive = playbackSettings.sleepTimerEnabled;
                            
                            return IconButton(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.transparent,
                                  isScrollControlled: true,
                                  builder: (context) => const SleepTimerBottomSheet(),
                                );
                              },
                              icon: Icon(
                                Icons.timer,
                                color: isTimerActive ? Colors.green : Colors.grey[400],
                              ),
                            );
                          },
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
                        StreamBuilder<PlaybackState>(
                          stream: audioHandler.playbackState,
                          builder: (context, snapshot) {
                            final playbackState = snapshot.data;
                            final isPlaying = playbackState?.playing ?? false;
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(40),
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  if (isPlaying) {
                                    audioHandler.pause();
                                  } else {
                                    audioHandler.play();
                                  }
                                },
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                     boxShadow: [
                                       BoxShadow(
                                         color: Colors.black.withValues(alpha: 0.3),
                                         blurRadius: 20,
                                         spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: Colors.black,
                                    size: 40,
                                  ),
                                ),
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

              // Lyrics or Equalizer panel
            if (_showLyrics || _showEqualizer)
              Expanded(
                flex: 2,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _showLyrics 
                          ? 'Lyrics coming soon' 
                          : 'Equalizer coming soon',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
               ],
             ),
            ),
          ),
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
        return Icons.repeat; // Use regular repeat icon, "1" indicator will be shown separately
      case AudioServiceRepeatMode.all:
        return Icons.repeat;
      case AudioServiceRepeatMode.none:
        return Icons.repeat;
      case AudioServiceRepeatMode.group:
        return Icons.repeat;
    }
  }

  Color _getRepeatIconColor(AudioServiceRepeatMode mode) {
    switch (mode) {
      case AudioServiceRepeatMode.one:
        return Colors.green; // Active - repeating current song
      case AudioServiceRepeatMode.all:
        return Colors.green; // Active - repeating all songs
      case AudioServiceRepeatMode.none:
        return Colors.grey[400]!; // Inactive - no repeat
      case AudioServiceRepeatMode.group:
        return Colors.grey[400]!; // Inactive - treat as no repeat
    }
  }

  String _getRepeatTooltip(AudioServiceRepeatMode mode) {
    switch (mode) {
      case AudioServiceRepeatMode.one:
        return 'Repeat current song';
      case AudioServiceRepeatMode.all:
        return 'Repeat all songs';
      case AudioServiceRepeatMode.none:
        return 'No repeat';
      case AudioServiceRepeatMode.group:
        return 'No repeat';
    }
  }

  
  BoxDecoration _buildBackgroundGradient(MediaItem? currentSong) {
    // Create dynamic background based on song or use default
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF1A1A1A),
          Color(0xFF0A0A0A),
          Colors.black,
        ],
      ),
    );
  }
  
  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            
            // Options
            _buildOptionTile(
              icon: Icons.favorite_border,
              title: 'Add to Favorites',
              onTap: () {
                Navigator.pop(context);
                _addToFavorites();
              },
            ),
            _buildOptionTile(
              icon: Icons.playlist_add,
              title: 'Add to Playlist',
              onTap: () {
                Navigator.pop(context);
                _showAddToPlaylistDialog();
              },
            ),
            _buildOptionTile(
              icon: Icons.share,
              title: 'Share',
              onTap: () {
                Navigator.pop(context);
                _shareSong();
              },
            ),
            _buildOptionTile(
              icon: Icons.info_outline,
              title: 'Song Info',
              onTap: () {
                Navigator.pop(context);
                _showSongInfo();
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
  
  void _addToFavorites() {
    _showSnackBar('Added to favorites', Colors.green);
  }
  
  void _showAddToPlaylistDialog() {
    _showSnackBar('Add to playlist feature coming soon', Colors.orange);
  }
  
  void _shareSong() {
    _showSnackBar('Share feature coming soon', Colors.orange);
  }
  
  void _showSongInfo() {
    _showSnackBar('Song info feature coming soon', Colors.orange);
  }
  
  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }
  
  void _showQueueModal() {
    HapticFeedback.lightImpact();
    _loggingService.logInfo('Opening queue modal');
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Queue content
              const Expanded(
                child: QueuePanel(),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
   void _handleSwipeEnd(DragEndDetails details, audioHandler) {
     final velocity = details.primaryVelocity ?? 0;
     const velocityThreshold = 300.0; // Velocity threshold for quick swipes
     const progressThreshold = 0.5; // 50% progress threshold
     
     bool shouldChangeSong = false;
     bool isNext = false;
     
     // Determine if we should change song based on progress or velocity
     if (_swipeProgress >= progressThreshold) {
       // 50% threshold reached - change song regardless of velocity
       shouldChangeSong = true;
       isNext = _swipeDirection < 0; // Left swipe = next song
       HapticFeedback.mediumImpact(); // Stronger haptic for threshold crossing
     } else if (velocity.abs() > velocityThreshold) {
       // Fast swipe with sufficient velocity
       shouldChangeSong = true;
       isNext = velocity < 0; // Left swipe = next song
       HapticFeedback.lightImpact(); // Light haptic for velocity-based change
     }
     
     // Reset all swipe state
     _isSwipeInProgress = false;
     _swipeProgress = 0.0;
     _swipeDirection = 0.0;
     _nextSong = null;
     _previousSong = null;
     
     if (mounted) {
       setState(() {});
     }
     
     // Execute song change if conditions are met
     if (shouldChangeSong) {
       try {
         if (isNext) {
           audioHandler.skipToNext();
           _loggingService.logInfo('Changed to next song via swipe');
         } else {
           audioHandler.skipToPrevious();
           _loggingService.logInfo('Changed to previous song via swipe');
         }
       } catch (e, stackTrace) {
         _loggingService.logError('Error changing song via swipe', e, stackTrace);
       }
     }
   }
   
   // Helper methods for peek functionality
   MediaItem? _getNextSong() {
     try {
       final queue = ref.read(queueProvider).value ?? [];
       final currentSong = ref.read(currentSongProvider).value;
       
       if (queue.isEmpty || currentSong == null) return null;
       
       final currentIndex = queue.indexWhere((item) => item.id == currentSong.id);
       if (currentIndex == -1 || currentIndex >= queue.length - 1) return null;
       
       return queue[currentIndex + 1];
     } catch (e) {
       _loggingService.logError('Error getting next song for peek', e);
       return null;
     }
   }
   
   MediaItem? _getPreviousSong() {
     try {
       final queue = ref.read(queueProvider).value ?? [];
       final currentSong = ref.read(currentSongProvider).value;
       
       if (queue.isEmpty || currentSong == null) return null;
       
       final currentIndex = queue.indexWhere((item) => item.id == currentSong.id);
       if (currentIndex <= 0) return null;
       
       return queue[currentIndex - 1];
     } catch (e) {
       _loggingService.logError('Error getting previous song for peek', e);
       return null;
     }
   }
   
   Widget _buildAlbumArtWidget(MediaItem song, {required bool isCurrentSong}) {
     return Container(
       width: 300,
       height: 300,
       decoration: BoxDecoration(
         shape: BoxShape.circle,
         boxShadow: [
           BoxShadow(
             color: Colors.black.withValues(alpha: 0.3),
             blurRadius: 20,
             spreadRadius: 5,
           ),
         ],
       ),
       child: StreamBuilder<PlaybackState>(
         stream: ref.read(audioHandlerProvider).playbackState,
         builder: (context, snapshot) {
           final playbackState = snapshot.data;
           final isPlaying = playbackState?.playing ?? false;
           
           // Only animate rotation for current song when playing
           if (isCurrentSong && isPlaying && !_albumArtController.isAnimating) {
             _albumArtController.repeat();
           } else if ((!isCurrentSong || !isPlaying) && _albumArtController.isAnimating) {
             _albumArtController.stop();
           }

           Widget albumArt = ClipOval(
             child: song.artUri != null
                 ? Image.file(
                     File(song.artUri!.toFilePath()),
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
           );
           
           // Only rotate current song when playing
           if (isCurrentSong) {
             return AnimatedBuilder(
               animation: _albumArtController,
               builder: (context, child) {
                 return Transform.rotate(
                   angle: _albumArtController.value * 2 * 3.14159,
                   child: child,
                 );
               },
               child: albumArt,
             );
           }
           
           return albumArt;
         },
       ),
     );
   }
   
   Widget _buildSwipeableAlbumSection(MediaItem currentSong) {
     return Center(
       child: SizedBox(
         width: 300,
         height: 300,
         child: Stack(
           alignment: Alignment.center,
           children: [
             // Current album art (moves with swipe)
             Transform.translate(
               offset: Offset(_swipeDirection * _swipeProgress * 300, 0),
               child: Opacity(
                 opacity: 1.0 - (_swipeProgress * 0.4), // Fade out as adjacent song appears
                 child: _buildAlbumArtWidget(currentSong, isCurrentSong: true),
               ),
             ),
             
             // Next song album art (slides in from right when swiping left)
             if (_swipeProgress > 0 && _swipeDirection < 0 && _nextSong != null)
               Transform.translate(
                 offset: Offset(300 * (1.0 - _swipeProgress), 0),
                 child: Opacity(
                   opacity: _swipeProgress * 0.9,
                   child: _buildAlbumArtWidget(_nextSong!, isCurrentSong: false),
                 ),
               ),
             
             // Previous song album art (slides in from left when swiping right)
             if (_swipeProgress > 0 && _swipeDirection > 0 && _previousSong != null)
               Transform.translate(
                 offset: Offset(-300 * (1.0 - _swipeProgress), 0),
                 child: Opacity(
                   opacity: _swipeProgress * 0.9,
                   child: _buildAlbumArtWidget(_previousSong!, isCurrentSong: false),
                 ),
               ),
           ],
         ),
       ),
     );
   }
   
   Widget _buildSwipeableSongInfo(MediaItem currentSong) {
     return Padding(
       padding: const EdgeInsets.symmetric(horizontal: 32),
       child: SizedBox(
         height: 100,
         child: Stack(
           alignment: Alignment.center,
           children: [
             // Current song info (moves with swipe)
             Transform.translate(
               offset: Offset(_swipeDirection * _swipeProgress * 300, 0),
               child: Opacity(
                 opacity: 1.0 - (_swipeProgress * 0.4),
                 child: _buildSongInfoWidget(currentSong),
               ),
             ),
             
             // Next song info (slides in from right when swiping left)
             if (_swipeProgress > 0 && _swipeDirection < 0 && _nextSong != null)
               Transform.translate(
                 offset: Offset(300 * (1.0 - _swipeProgress), 0),
                 child: Opacity(
                   opacity: _swipeProgress * 0.9,
                   child: _buildSongInfoWidget(_nextSong!),
                 ),
               ),
             
             // Previous song info (slides in from left when swiping right)
             if (_swipeProgress > 0 && _swipeDirection > 0 && _previousSong != null)
               Transform.translate(
                 offset: Offset(-300 * (1.0 - _swipeProgress), 0),
                 child: Opacity(
                   opacity: _swipeProgress * 0.9,
                   child: _buildSongInfoWidget(_previousSong!),
                 ),
               ),
           ],
         ),
       ),
     );
   }
   
   Widget _buildSongInfoWidget(MediaItem song) {
     return Column(
       mainAxisAlignment: MainAxisAlignment.center,
       children: [
         Text(
           song.title,
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
           song.artist ?? '',
           style: TextStyle(
             color: Colors.grey[400],
             fontSize: 18,
           ),
           textAlign: TextAlign.center,
           maxLines: 1,
           overflow: TextOverflow.ellipsis,
         ),
       ],
     );
   }
 }

