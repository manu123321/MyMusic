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
import '../widgets/add_to_playlist_sheet.dart';
import '../models/song.dart';

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
           // Prevent system back gesture conflict by checking start position
           final screenWidth = MediaQuery.of(context).size.width;
           final startX = details.globalPosition.dx;
           const edgeThreshold = 40.0; // Reduced edge threshold for better usability
           
           // Only start swipe if not near screen edges
           if (startX > edgeThreshold && startX < (screenWidth - edgeThreshold)) {
             _isSwipeInProgress = true;
             _swipeProgress = 0.0;
             _swipeDirection = 0.0;
             
             // Pre-load adjacent songs for smooth experience
             _nextSong = _getNextSong();
             _previousSong = _getPreviousSong();
           }
         },
         onHorizontalDragUpdate: (details) {
           if (_isSwipeInProgress) {
             // Use delta for smoother tracking and prevent stuttering
             final deltaX = details.delta.dx;
             const albumArtSize = 300.0;
             
             // Accumulate drag distance for smooth movement
             _swipeDirection += deltaX;
             
             // Much more responsive thresholds
             final maxDragDistance = albumArtSize * 0.6; // Reduced from 0.8 to 0.6 for easier triggering
             final progress = (_swipeDirection.abs() / maxDragDistance).clamp(0.0, 1.0);
             
             // Determine direction: negative = left (next), positive = right (previous)
             final direction = _swipeDirection < 0 ? -1.0 : 1.0;
             
             // Only proceed if we have an adjacent song in that direction
             final hasAdjacentSong = direction < 0 ? _nextSong != null : _previousSong != null;
             
             // Much lower threshold for better responsiveness
             if (hasAdjacentSong && _swipeDirection.abs() > 3) { // Reduced from 10 to 3
               _swipeProgress = progress;
               
               // Direct setState for immediate response
               if (mounted) {
                 setState(() {});
               }
             } else if (_swipeDirection.abs() <= 3) {
               // Reset if minimal drag
               _swipeProgress = 0.0;
               _swipeDirection = 0.0;
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
              mainAxisAlignment: MainAxisAlignment.start,
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

            // Progress bar and Controls (combined section)
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 20),
                    // Progress bar
                    Flexible(
                      child: StreamBuilder<Duration>(
                        stream: audioHandler.positionStream,
                        builder: (context, snapshot) {
                        final streamPosition = snapshot.data ?? Duration.zero;
                        final position = _isDraggingSlider ? _sliderPosition : streamPosition;
                        final duration = currentSong.duration ?? Duration.zero;
                        
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3, // Reduced by 30% from 4 (4 * 0.7 = 2.8 ≈ 3)
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
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(position),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  _formatDuration(duration),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Main controls (moved closer to progress bar)
                    Flexible(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                        IconButton(
                          onPressed: () => audioHandler.skipToPrevious(),
                          icon: const Icon(Icons.skip_previous, color: Colors.white),
                          iconSize: 50, // Increased by 15% from 44 (44 * 1.15 = 50.6 ≈ 50)
                        ),
                        StreamBuilder<PlaybackState>(
                          stream: audioHandler.playbackState,
                          builder: (context, snapshot) {
                            final playbackState = snapshot.data;
                            final isPlaying = playbackState?.playing ?? false;
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(32), // Adjusted for new size (56 * 1.15 = 64.4, radius = 32)
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  if (isPlaying) {
                                    audioHandler.pause();
                                  } else {
                                    audioHandler.play();
                                  }
                                },
                                child: Container(
                                  width: 64, // Increased by 15% from 56 (56 * 1.15 = 64.4 ≈ 64)
                                  height: 64, // Increased by 15% from 56 (56 * 1.15 = 64.4 ≈ 64)
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
                                    size: 32, // Increased by 15% from 28 (28 * 1.15 = 32.2 ≈ 32)
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          onPressed: () => audioHandler.skipToNext(),
                          icon: const Icon(Icons.skip_next, color: Colors.white),
                          iconSize: 50, // Increased by 15% from 44 (44 * 1.15 = 50.6 ≈ 50)
                        ),
                      ],
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Secondary controls (moved closer to main controls)
                    Flexible(
                      child: Row(
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
                            _showSnackBar('Equalizer coming soon', Colors.orange);
                          },
                          icon: Icon(
                            Icons.equalizer,
                            color: Colors.grey[400],
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
                                Icons.timer_outlined,
                                color: isTimerActive ? Colors.green : Colors.grey[400],
                              ),
                            );
                          },
                        ),
                      ],
                      ),
                    ),
                      const SizedBox(height: 24),
                    ],
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
    final currentSong = ref.read(currentSongProvider).value;
    if (currentSong == null) return;
    
    final song = _mediaItemToSong(currentSong);
    if (song == null) return;

    HapticFeedback.selectionClick();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 16),

            // Song info
            _buildSongHeader(song),
            const SizedBox(height: 24),

            // Options
            Consumer(
              builder: (context, ref, child) {
                final favorites = ref.watch(favoritesProvider);
                final isFavorite = favorites.contains(song.id);
                
                return _buildOptionTile(
                  icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                  title: isFavorite ? 'Remove from liked songs' : 'Add to liked songs',
                  onTap: () {
                    Navigator.pop(context);
                    _toggleFavorite(song);
                  },
                );
              },
            ),
            _buildOptionTile(
              icon: Icons.queue_music,
              title: 'Add to queue',
              onTap: () {
                Navigator.pop(context);
                _addToQueue(song);
              },
            ),
            _buildOptionTile(
              icon: Icons.playlist_add,
              title: 'Add to playlist',
              onTap: () {
                Navigator.pop(context);
                _showAddToPlaylistDialog(song);
              },
            ),
            _buildOptionTile(
              icon: Icons.info_outline,
              title: 'Song info',
              onTap: () {
                Navigator.pop(context);
                _showSongInfoDialog(song);
              },
            ),
            _buildOptionTile(
              icon: Icons.remove_circle_outline,
              title: 'Remove from library',
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(song);
              },
              isDestructive: true,
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
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : Colors.white,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : Colors.white,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  /// Helper method to convert MediaItem back to Song object
  Song? _mediaItemToSong(MediaItem mediaItem) {
    try {
      final extras = mediaItem.extras ?? {};
      
      return Song(
        id: extras['songId'] ?? mediaItem.id,
        title: mediaItem.title,
        artist: mediaItem.artist ?? 'Unknown Artist',
        album: mediaItem.album ?? 'Unknown Album',
        filePath: mediaItem.id,
        duration: mediaItem.duration?.inMilliseconds ?? 0,
        albumArtPath: mediaItem.artUri?.toFilePath(),
        trackNumber: extras['trackNumber'],
        year: extras['year'],
        genre: extras['genre'],
        dateAdded: DateTime.now(), // We don't have this in MediaItem
        isFavorite: extras['isFavorite'] ?? false,
      );
    } catch (e, stackTrace) {
      _loggingService.logError('Error converting MediaItem to Song', e, stackTrace);
      return null;
    }
  }

  Widget _buildSongHeader(Song song) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: song.albumArtPath != null
              ? Image.file(
            File(song.albumArtPath!),
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildDefaultAlbumArt(64);
            },
          )
              : _buildDefaultAlbumArt(64),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                song.artist,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (song.album.isNotEmpty)
                Text(
                  song.album,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultAlbumArt([double size = 56]) {
    return Container(
      width: size,
      height: size,
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
      child: Icon(
        Icons.music_note_rounded,
        color: Colors.white,
        size: size * 0.4,
      ),
    );
  }

  void _toggleFavorite(Song song) {
    try {
      HapticFeedback.lightImpact();

      final favorites = ref.read(favoritesProvider);
      final isCurrentlyFavorite = favorites.contains(song.id);

      // Use the centralized favorites management
      ref.read(favoritesProvider.notifier).toggleFavorite(song.id);

      _loggingService.logInfo('Toggled favorite for: ${song.title}');

      _showSuccessSnackBar(
          !isCurrentlyFavorite
              ? 'Added to liked songs'
              : 'Removed from liked songs'
      );
    } catch (e, stackTrace) {
      _loggingService.logError('Error toggling favorite', e, stackTrace);
      _showErrorSnackBar('Failed to update liked songs');
    }
  }

  void _addToQueue(Song song) {
    try {
      HapticFeedback.lightImpact();
      
      final audioHandler = ref.read(audioHandlerProvider);
      final queue = ref.read(queueProvider).value ?? [];
      final currentSong = ref.read(currentSongProvider).value;
      
      // Convert song to MediaItem
      final mediaItem = MediaItem(
        id: song.filePath,
        title: song.title,
        artist: song.artist,
        album: song.album,
        duration: Duration(milliseconds: song.duration),
        artUri: song.albumArtPath != null ? Uri.file(song.albumArtPath!) : null,
        extras: {
          'songId': song.id,
          'trackNumber': song.trackNumber,
          'year': song.year,
          'genre': song.genre,
          'isFavorite': song.isFavorite,
        },
      );
      
      // Add to queue next to current playing song
      if (currentSong != null && queue.isNotEmpty) {
        final currentIndex = queue.indexWhere((item) => item.id == currentSong.id);
        if (currentIndex != -1) {
          // Add after current song (next position)
          audioHandler.addQueueItemAt(mediaItem, currentIndex + 1);
        } else {
          // Fallback to end of queue
          audioHandler.addQueueItem(mediaItem);
        }
      } else {
        // No current song or empty queue, add to end
        audioHandler.addQueueItem(mediaItem);
      }
      
      _loggingService.logInfo('Added song to queue: ${song.title}');
      
      // No snackbar message - clean UX like Spotify
    } catch (e, stackTrace) {
      _loggingService.logError('Error adding song to queue', e, stackTrace);
      _showErrorSnackBar('Failed to add song to queue');
    }
  }

  void _showAddToPlaylistDialog(Song song) {
    HapticFeedback.selectionClick();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AddToPlaylistSheet(song: song),
    );
  }
  
  void _showSongInfoDialog(Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 16),

            // Song info with album art
            _buildSongInfoHeader(song),
            const SizedBox(height: 24),

            // Song details
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Title', song.title),
                    _buildInfoRow('Artist', song.artist),
                    _buildInfoRow('Album', song.album),
                    if (song.genre != null)
                      _buildInfoRow('Genre', song.genre!),
                    if (song.year != null)
                      _buildInfoRow('Year', song.year.toString()),
                    if (song.trackNumber != null)
                      _buildInfoRow('Track', song.trackNumber.toString()),
                    _buildInfoRow('Duration', song.formattedDuration),
                    _buildInfoRow('File size', song.formattedFileSize),
                    _buildInfoRow('Bitrate', '${song.bitrate} kbps'),
                    _buildInfoRow('Date added', song.dateAdded.toString().split(' ')[0]),
                    if (song.lastPlayed != null)
                      _buildInfoRow('Last played', song.lastPlayed.toString().split(' ')[0]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongInfoHeader(Song song) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: song.albumArtPath != null
              ? Image.file(
            File(song.albumArtPath!),
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildDefaultAlbumArt(80);
            },
          )
              : _buildDefaultAlbumArt(80),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Song Information',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                song.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                song.artist,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (song.album.isNotEmpty)
                Text(
                  song.album,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Song song) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text(
              'Remove from library',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "${song.title}" from your library?\n\nThis will remove it from all playlists but won\'t delete the actual file.',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              try {
                await ref.read(songsProvider.notifier).deleteSong(song.id);

                if (mounted) {
                  navigator.pop();
                  _showSuccessSnackBar('Song removed from library');
                }
              } catch (e, stackTrace) {
                _loggingService.logError('Error deleting song', e, stackTrace);
                if (mounted) {
                  navigator.pop();
                  _showErrorSnackBar('Failed to remove song');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.black),
              const SizedBox(width: 8),
              Expanded(child: Text(message, style: const TextStyle(color: Colors.black))),
            ],
          ),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.black),
              const SizedBox(width: 8),
              Expanded(child: Text(message, style: const TextStyle(color: Colors.black))),
            ],
          ),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }
  
  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
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
     const progressThreshold = 0.3; // Reduced from 0.5 to 0.3 for easier triggering
     const velocityThreshold = 200.0; // Much lower velocity threshold
     final velocity = details.primaryVelocity ?? 0;
     
     bool shouldChangeSong = false;
     bool isNext = false;
     
     // Much more responsive conditions for song change
     if (_swipeProgress >= progressThreshold) {
       // 30% threshold reached - change song regardless of velocity
       shouldChangeSong = true;
       isNext = _swipeDirection < 0; // Left swipe = next song
       HapticFeedback.mediumImpact();
       _loggingService.logInfo('Song change triggered by 30% threshold');
     } else if (velocity.abs() > velocityThreshold && _swipeDirection.abs() > 20) {
       // Fast swipe with much lower requirements
       shouldChangeSong = true;
       isNext = velocity < 0; // Left swipe = next song
       HapticFeedback.lightImpact();
       _loggingService.logInfo('Song change triggered by velocity');
     } else if (_swipeDirection.abs() > 80) {
       // Even slow swipes trigger if user drags far enough
       shouldChangeSong = true;
       isNext = _swipeDirection < 0;
       HapticFeedback.lightImpact();
       _loggingService.logInfo('Song change triggered by distance');
     }
     
     // Execute song change immediately for better responsiveness
     if (shouldChangeSong) {
       try {
         if (isNext && _nextSong != null) {
           audioHandler.skipToNext();
           _loggingService.logInfo('Changed to next song via swipe');
         } else if (!isNext && _previousSong != null) {
           audioHandler.skipToPrevious();
           _loggingService.logInfo('Changed to previous song via swipe');
         }
       } catch (e, stackTrace) {
         _loggingService.logError('Error changing song via swipe', e, stackTrace);
       }
     }
     
     // Reset state after song change for cleaner experience
     if (mounted) {
       setState(() {
         _isSwipeInProgress = false;
         _swipeProgress = 0.0;
         _swipeDirection = 0.0;
         _nextSong = null;
         _previousSong = null;
       });
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
     return RepaintBoundary(
       child: Container(
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
         child: isCurrentSong 
             ? StreamBuilder<PlaybackState>(
                 stream: ref.read(audioHandlerProvider).playbackState,
                 builder: (context, snapshot) {
                   final playbackState = snapshot.data;
                   final isPlaying = playbackState?.playing ?? false;
                   
                   // Only animate rotation for current song when playing
                   if (isPlaying && !_albumArtController.isAnimating) {
                     _albumArtController.repeat();
                   } else if (!isPlaying && _albumArtController.isAnimating) {
                     _albumArtController.stop();
                   }

                   final albumArt = _buildAlbumArtImage(song);
                   
                   // Only rotate current song when playing
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
                 },
               )
             : _buildAlbumArtImage(song), // Static image for adjacent songs
       ),
     );
   }
   
   Widget _buildAlbumArtImage(MediaItem song) {
     return ClipOval(
       child: song.artUri != null
           ? Image.file(
               File(song.artUri!.toFilePath()),
               width: 300,
               height: 300,
               fit: BoxFit.cover,
               cacheWidth: 300,
               cacheHeight: 300,
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
   }
   
   Widget _buildSwipeableAlbumSection(MediaItem currentSong) {
     return RepaintBoundary(
       child: Center(
         child: SizedBox(
           width: 300,
           height: 300,
           child: Stack(
             alignment: Alignment.center,
             children: [
               // Current album art (moves with swipe)
               RepaintBoundary(
                 child: Transform.translate(
                   offset: Offset(
                     _swipeDirection.sign * _swipeProgress * 300, 
                     0
                   ),
                   child: Opacity(
                     opacity: (1.0 - (_swipeProgress * 0.4)).clamp(0.0, 1.0),
                     child: _buildAlbumArtWidget(currentSong, isCurrentSong: true),
                   ),
                 ),
               ),
               
               // Next song album art (slides in from right when swiping left)
               if (_swipeProgress > 0.02 && _swipeDirection < 0 && _nextSong != null)
                 RepaintBoundary(
                   child: Transform.translate(
                     offset: Offset(300 * (1.0 - _swipeProgress), 0),
                     child: Opacity(
                       opacity: (_swipeProgress * 1.1).clamp(0.0, 1.0), // Increased opacity for better visibility
                       child: Container(
                         decoration: _swipeProgress >= 0.3 
                             ? BoxDecoration(
                                 shape: BoxShape.circle,
                                 border: Border.all(
                                   color: const Color(0xFF00E676),
                                   width: 3,
                                 ),
                               )
                             : null,
                         child: _buildAlbumArtWidget(_nextSong!, isCurrentSong: false),
                       ),
                     ),
                   ),
                 ),
               
               // Previous song album art (slides in from left when swiping right)
               if (_swipeProgress > 0.02 && _swipeDirection > 0 && _previousSong != null)
                 RepaintBoundary(
                   child: Transform.translate(
                     offset: Offset(-300 * (1.0 - _swipeProgress), 0),
                     child: Opacity(
                       opacity: (_swipeProgress * 1.1).clamp(0.0, 1.0), // Increased opacity for better visibility
                       child: Container(
                         decoration: _swipeProgress >= 0.3 
                             ? BoxDecoration(
                                 shape: BoxShape.circle,
                                 border: Border.all(
                                   color: const Color(0xFF00E676),
                                   width: 3,
                                 ),
                               )
                             : null,
                         child: _buildAlbumArtWidget(_previousSong!, isCurrentSong: false),
                       ),
                     ),
                   ),
                 ),
             ],
           ),
         ),
       ),
     );
   }
   
   Widget _buildSwipeableSongInfo(MediaItem currentSong) {
     return RepaintBoundary(
       child: Padding(
         padding: const EdgeInsets.symmetric(horizontal: 32),
         child: SizedBox(
           height: 100,
           child: Stack(
             alignment: Alignment.center,
             children: [
               // Current song info (moves with swipe)
               RepaintBoundary(
                 child: Transform.translate(
                   offset: Offset(
                     _swipeDirection.sign * _swipeProgress * 300, 
                     0
                   ),
                   child: Opacity(
                     opacity: (1.0 - (_swipeProgress * 0.4)).clamp(0.0, 1.0),
                     child: _buildSongInfoWidget(currentSong),
                   ),
                 ),
               ),
               
               // Next song info (slides in from right when swiping left)
               if (_swipeProgress > 0.02 && _swipeDirection < 0 && _nextSong != null)
                 RepaintBoundary(
                   child: Transform.translate(
                     offset: Offset(300 * (1.0 - _swipeProgress), 0),
                     child: Opacity(
                       opacity: (_swipeProgress * 1.1).clamp(0.0, 1.0), // More visible
                       child: _buildSongInfoWidget(_nextSong!),
                     ),
                   ),
                 ),
               
               // Previous song info (slides in from left when swiping right)
               if (_swipeProgress > 0.02 && _swipeDirection > 0 && _previousSong != null)
                 RepaintBoundary(
                   child: Transform.translate(
                     offset: Offset(-300 * (1.0 - _swipeProgress), 0),
                     child: Opacity(
                       opacity: (_swipeProgress * 1.1).clamp(0.0, 1.0), // More visible
                       child: _buildSongInfoWidget(_previousSong!),
                     ),
                   ),
                 ),
             ],
           ),
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

