import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../providers/music_provider.dart';
import '../models/song.dart';
import '../services/logging_service.dart';

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
              child: IconButton(
                onPressed: queueLength > 1 ? _shuffleQueue : null,
                icon: Icon(
                  Icons.shuffle,
                  color: queueLength > 1 ? Colors.white : Colors.grey[600],
                  size: 18,
                ),
                tooltip: 'Shuffle queue',
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Sleep timer button
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                onPressed: _showSleepTimerDialog,
                icon: Icon(
                  Icons.bedtime,
                  color: Colors.white,
                  size: 18,
                ),
                tooltip: 'Sleep timer',
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
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
    // Reorder queue to show current song first
    final orderedQueue = <MediaItem>[];
    if (currentSong != null && queue.isNotEmpty) {
      // Find current song index
      final currentIndex = queue.indexWhere((item) => item.id == currentSong.id);
      if (currentIndex != -1) {
        // Add current song first
        orderedQueue.add(queue[currentIndex]);
        // Add remaining songs after current song
        for (int i = currentIndex + 1; i < queue.length; i++) {
          orderedQueue.add(queue[i]);
        }
        // Add songs before current song
        for (int i = 0; i < currentIndex; i++) {
          orderedQueue.add(queue[i]);
        }
      } else {
        orderedQueue.addAll(queue);
      }
    } else {
      orderedQueue.addAll(queue);
    }

    return ReorderableListView.builder(
      itemCount: orderedQueue.length,
      onReorder: _onReorder,
      itemBuilder: (context, index) {
        final song = orderedQueue[index];
        final isCurrentSong = currentSong?.id == song.id;
        
        return _buildQueueItem(
          key: ValueKey(song.id),
          song: song,
          index: index,
          isCurrentSong: isCurrentSong,
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
    required bool isCurrentSong,
    required audioHandler,
    required bool showReorderHandle,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isCurrentSong 
            ? const Color(0xFF00E676).withOpacity(0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isCurrentSong
            ? Border.all(color: const Color(0xFF00E676).withOpacity(0.3), width: 1)
            : null,
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
            // Playing indicator
            if (isCurrentSong)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'NOW PLAYING',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            
            const SizedBox(width: 8),
            
            // Reorder handle (always visible for direct reordering)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.drag_handle,
                color: Colors.grey[300],
                size: 18,
              ),
            ),
          ],
        ),
        onTap: () => _jumpToSong(index, audioHandler),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.bedtime, color: Color(0xFF00E676)),
            SizedBox(width: 8),
            Text(
              'Sleep Timer',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: const Text(
          'Set a timer to stop playback after a certain amount of time.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement sleep timer functionality
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
            ),
            child: const Text('Set Timer'),
          ),
        ],
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    try {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      
      final audioHandler = ref.read(audioHandlerProvider);
      final queue = ref.read(queueProvider).value ?? [];
      final currentSong = ref.read(currentSongProvider).value;
      
      if (queue.isNotEmpty && currentSong != null) {
        // Find the actual indices in the original queue
        final currentIndex = queue.indexWhere((item) => item.id == currentSong.id);
        if (currentIndex != -1) {
          // Calculate the actual indices in the original queue
          int actualOldIndex, actualNewIndex;
          
          if (oldIndex == 0) {
            actualOldIndex = currentIndex;
          } else if (oldIndex <= queue.length - currentIndex - 1) {
            actualOldIndex = currentIndex + oldIndex;
          } else {
            actualOldIndex = oldIndex - (queue.length - currentIndex - 1) - 1;
          }
          
          if (newIndex == 0) {
            actualNewIndex = currentIndex;
          } else if (newIndex <= queue.length - currentIndex - 1) {
            actualNewIndex = currentIndex + newIndex;
          } else {
            actualNewIndex = newIndex - (queue.length - currentIndex - 1) - 1;
          }
          
          // Reorder the queue
          final newQueue = List<MediaItem>.from(queue);
          final item = newQueue.removeAt(actualOldIndex);
          newQueue.insert(actualNewIndex, item);
          
          // Update the queue in audio handler
          audioHandler.setQueue(newQueue);
          
          _loggingService.logInfo('Reordered queue item from $actualOldIndex to $actualNewIndex');
          HapticFeedback.lightImpact();
        }
      }
    } catch (e, stackTrace) {
      _loggingService.logError('Error reordering queue', e, stackTrace);
    }
  }

  void _jumpToSong(int index, audioHandler) {
    try {
      final queue = ref.read(queueProvider).value ?? [];
      final currentSong = ref.read(currentSongProvider).value;
      
      if (queue.isNotEmpty && currentSong != null) {
        // Find the current song index
        final currentIndex = queue.indexWhere((item) => item.id == currentSong.id);
        if (currentIndex != -1) {
          // Calculate the actual index in the original queue
          int actualIndex;
          
          if (index == 0) {
            actualIndex = currentIndex;
          } else if (index <= queue.length - currentIndex - 1) {
            actualIndex = currentIndex + index;
          } else {
            actualIndex = index - (queue.length - currentIndex - 1) - 1;
          }
          
          audioHandler.skipToQueueItem(actualIndex);
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


  void _shuffleQueue() {
    try {
      final audioHandler = ref.read(audioHandlerProvider);
      audioHandler.setShuffleModeEnabled(true);
      _loggingService.logInfo('Shuffling queue');
      HapticFeedback.mediumImpact();
      
      // No snackbar message - clean UX like Spotify
    } catch (e, stackTrace) {
      _loggingService.logError('Error shuffling queue', e, stackTrace);
      
      // Only show error snackbar for failures
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to shuffle queue', style: TextStyle(color: Colors.black)),
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
