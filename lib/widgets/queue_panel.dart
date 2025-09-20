import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../providers/music_provider.dart';
import '../models/song.dart';
import '../services/logging_service.dart';
import 'sleep_timer_dialog.dart';

class QueuePanel extends ConsumerStatefulWidget {
  const QueuePanel({super.key});

  @override
  ConsumerState<QueuePanel> createState() => _QueuePanelState();
}

class _QueuePanelState extends ConsumerState<QueuePanel>
    with TickerProviderStateMixin {
  final LoggingService _loggingService = LoggingService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(queueProvider).value ?? [];
    final currentSong = ref.watch(currentSongProvider).value;
    final audioHandler = ref.read(audioHandlerProvider);

    return Semantics(
      label: 'Playback queue',
      hint: 'List of songs in the current queue. ${queue.length} songs total.',
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with queue controls
              _buildHeader(queue.length),
              const SizedBox(height: 16),
              
              // Queue content
              Expanded(
                child: queue.isEmpty ? _buildEmptyState() : _buildQueueList(queue, currentSong, audioHandler),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader(int queueLength) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Queue',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$queueLength song${queueLength == 1 ? '' : 's'} in queue',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        Row(
          children: [
             // Shuffle queue button
             Container(
               decoration: BoxDecoration(
                 color: queueLength > 1 ? Colors.grey[800] : Colors.grey[900],
                 borderRadius: BorderRadius.circular(20),
               ),
               child: Consumer(
                 builder: (context, ref, child) {
                   final playbackState = ref.watch(playbackStateProvider).value;
                   final isShuffleEnabled = playbackState?.shuffleMode == AudioServiceShuffleMode.all;
                   
                   return Container(
                     decoration: BoxDecoration(
                       color: isShuffleEnabled && queueLength > 1 ? Colors.green : Colors.grey[800],
                       borderRadius: BorderRadius.circular(20),
                     ),
                     child: IconButton(
                       onPressed: queueLength > 1 ? _toggleShuffle : null,
                       icon: Icon(
                         Icons.shuffle,
                         color: Colors.white,
                         size: 18,
                       ),
                       tooltip: isShuffleEnabled ? 'Disable shuffle' : 'Enable shuffle',
                       constraints: const BoxConstraints(
                         minWidth: 40,
                         minHeight: 40,
                       ),
                     ),
                   );
                 },
               ),
             ),
            
            const SizedBox(width: 8),
            
            // Sleep timer button
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Consumer(
                builder: (context, ref, child) {
                  final playbackSettings = ref.watch(playbackSettingsProvider);
                  final isTimerActive = playbackSettings.sleepTimerEnabled;
                  
                  return Container(
                    decoration: BoxDecoration(
                      color: isTimerActive ? Colors.green : Colors.grey[800],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      onPressed: _showSleepTimerDialog,
                      icon: Icon(
                        Icons.timer_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      tooltip: 'Sleep timer',
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[800]?.withOpacity(0.3),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.queue_music_outlined,
              size: 48,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your queue is empty',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add songs to start building your queue',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueList(List<MediaItem> queue, MediaItem? currentSong, audioHandler) {
    if (queue.isEmpty) {
      return _buildEmptyState();
    }

    // Separate current song from upcoming songs (Spotify-style)
    final currentSongList = <MediaItem>[];
    final upcomingSongs = <MediaItem>[];
    
    if (currentSong != null) {
      // Add current song first
      currentSongList.add(currentSong);
      
      // Add all other songs as upcoming
      for (final song in queue) {
        if (song.id != currentSong.id) {
          upcomingSongs.add(song);
        }
      }
    } else {
      // No current song, show all as upcoming
      upcomingSongs.addAll(queue);
    }

    return Column(
      children: [
        // Current song section (non-reorderable)
        if (currentSongList.isNotEmpty)
          _buildCurrentSongSection(currentSongList.first, audioHandler),
        
        // Upcoming songs section (reorderable)
        if (upcomingSongs.isNotEmpty)
          Expanded(
            child: _buildUpcomingSongsSection(upcomingSongs, audioHandler),
          ),
      ],
    );
  }

  Widget _buildCurrentSongSection(MediaItem currentSong, audioHandler) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: _buildQueueItem(
        key: ValueKey('current_${currentSong.id}'),
        song: currentSong,
        index: 0,
        isCurrentSong: true,
        audioHandler: audioHandler,
        showReorderHandle: false,
      ),
    );
  }

  Widget _buildUpcomingSongsSection(List<MediaItem> upcomingSongs, audioHandler) {
    return ReorderableListView.builder(
      itemCount: upcomingSongs.length,
      onReorder: _onReorderUpcoming,
      proxyDecorator: _proxyDecorator,
      buildDefaultDragHandles: false,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final song = upcomingSongs[index];
        
        return _buildQueueItem(
          key: ValueKey('upcoming_${song.id}'),
          song: song,
          index: index + 1, // Offset by 1 since current song is at index 0
          originalIndex: index, // Pass the original index for drag handling
          isCurrentSong: false,
          audioHandler: audioHandler,
          showReorderHandle: true,
        );
      },
    );
  }

  Widget _buildQueueItem({
    required Key key,
    required MediaItem song,
    required int index,
    int? originalIndex, // Original index for drag handling
    required bool isCurrentSong,
    required audioHandler,
    required bool showReorderHandle,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: song.artUri != null
              ? Image.file(
                  File(song.artUri!.toFilePath()),
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  cacheWidth: 48,
                  cacheHeight: 48,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildDefaultAlbumArt();
                  },
                )
              : _buildDefaultAlbumArt(),
        ),
        title: Text(
          song.title,
          style: TextStyle(
            color: isCurrentSong ? const Color(0xFF00E676) : Colors.white,
            fontSize: 15,
            fontWeight: isCurrentSong ? FontWeight.w600 : FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          song.artist ?? 'Unknown Artist',
          style: TextStyle(
            color: isCurrentSong ? Colors.grey[300] : Colors.grey[400],
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Play/Pause button for current song
            if (isCurrentSong)
              Consumer(
                builder: (context, ref, child) {
                  final playbackState = ref.watch(playbackStateProvider);
                  final isPlaying = playbackState.when(
                    data: (state) => state.playing,
                    loading: () => false,
                    error: (_, __) => false,
                  );
                  
                  return Container(
                    width: 34, // Reduced by 15% from 40
                    height: 34, // Reduced by 15% from 40
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        if (isPlaying) {
                          audioHandler.pause();
                        } else {
                          audioHandler.play();
                        }
                      },
                      icon: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.black,
                        size: 17, // Reduced proportionally
                      ),
                      padding: EdgeInsets.zero,
                      tooltip: isPlaying ? 'Pause' : 'Play',
                    ),
                  );
                },
              ),
            
            // Three dash queue icon for reordering (only for upcoming songs)
            if (!isCurrentSong)
              ReorderableDragStartListener(
                index: originalIndex ?? index - 1, // Use original index for correct drag behavior
                child: GestureDetector(
                  onTap: () {
                    // Provide haptic feedback when drag handle is tapped
                    HapticFeedback.selectionClick();
                  },
                  child: const Icon(
                    Icons.queue_music,
                    color: Colors.white,
                    size: 23,
                  ),
                ),
              ),
          ],
        ),
        onTap: isCurrentSong ? null : () => _jumpToSong(index, audioHandler),
      ),
    );
  }

  Widget _buildDefaultAlbumArt() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[700]!,
            Colors.grey[800]!,
          ],
        ),
      ),
      child: const Icon(
        Icons.music_note_rounded,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  void _showSleepTimerDialog() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const SleepTimerBottomSheet(),
    );
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final double animValue = Curves.easeInOut.transform(animation.value);
        final double elevation = lerpDouble(2, 8, animValue)!;
        final double scale = lerpDouble(1, 1.05, animValue)!;
        final double opacity = lerpDouble(0.8, 1.0, animValue)!;
        
        return Transform.scale(
          scale: scale,
          child: Material(
            elevation: elevation,
            shadowColor: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[900]?.withOpacity(opacity),
            // Removed border decoration for cleaner drag appearance
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  void _onReorderUpcoming(int oldIndex, int newIndex) {
    try {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      
      final audioHandler = ref.read(audioHandlerProvider);
      final queue = ref.read(queueProvider).value ?? [];
      final currentSong = ref.read(currentSongProvider).value;
      
      if (queue.isNotEmpty && currentSong != null) {
        // Find current song index in the original queue
        final currentIndex = queue.indexWhere((item) => item.id == currentSong.id);
        if (currentIndex != -1) {
          // Create a list of upcoming songs (excluding current song)
          final upcomingSongs = <MediaItem>[];
          for (int i = 0; i < queue.length; i++) {
            if (i != currentIndex) {
              upcomingSongs.add(queue[i]);
            }
          }
          
          // Reorder the upcoming songs
          final reorderedUpcoming = List<MediaItem>.from(upcomingSongs);
          final item = reorderedUpcoming.removeAt(oldIndex);
          reorderedUpcoming.insert(newIndex, item);
          
          // Rebuild the complete queue with current song first, then reordered upcoming songs
          final newQueue = <MediaItem>[];
          newQueue.add(currentSong); // Current song stays first
          newQueue.addAll(reorderedUpcoming); // Add reordered upcoming songs
          
          // Use the new non-interrupting reorder method
          audioHandler.reorderQueue(newQueue);
          
          _loggingService.logInfo('Reordered upcoming song from $oldIndex to $newIndex');
          HapticFeedback.lightImpact();
        }
      }
    } catch (e, stackTrace) {
      _loggingService.logError('Error reordering upcoming songs', e, stackTrace);
    }
  }

  void _jumpToSong(int index, audioHandler) {
    try {
      final queue = ref.read(queueProvider).value ?? [];
      final currentSong = ref.read(currentSongProvider).value;
      
      if (queue.isNotEmpty && currentSong != null) {
        // Find the current song index in the original queue
        final currentIndex = queue.indexWhere((item) => item.id == currentSong.id);
        if (currentIndex != -1) {
          // Calculate the actual index in the original queue
          // Index 0 is current song, so we don't need to jump
          if (index == 0) {
            _loggingService.logInfo('Already playing current song');
            return;
          }
          
          // For upcoming songs, find the actual index in the original queue
          int? actualIndex;
          int upcomingSongIndex = 0;
          
          for (int i = 0; i < queue.length; i++) {
            if (i != currentIndex) {
              if (upcomingSongIndex == index - 1) {
                actualIndex = i;
                break;
              }
              upcomingSongIndex++;
            }
          }
          
          if (actualIndex != null) {
            audioHandler.skipToQueueItem(actualIndex);
          }
          _loggingService.logInfo('Jumping to song at actual index $actualIndex');
          HapticFeedback.selectionClick();
        }
      }
      
      // No snackbar message - clean UX like Spotify
    } catch (e, stackTrace) {
      _loggingService.logError('Error jumping to song', e, stackTrace);
      
      // Only show error snackbar for failures
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to jump to song', style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }


  void _toggleShuffle() {
    try {
      final audioHandler = ref.read(audioHandlerProvider);
      final playbackState = ref.read(playbackStateProvider).value;
      final isShuffleEnabled = playbackState?.shuffleMode == AudioServiceShuffleMode.all;
      
      // Toggle shuffle mode
      audioHandler.setShuffleModeEnabled(!isShuffleEnabled);
      
      _loggingService.logInfo('Toggled shuffle mode: ${!isShuffleEnabled}');
      HapticFeedback.mediumImpact();
      
      // No snackbar message - clean UX like Spotify
    } catch (e, stackTrace) {
      _loggingService.logError('Error toggling shuffle', e, stackTrace);
      
      // Only show error snackbar for failures
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to toggle shuffle', style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

}
