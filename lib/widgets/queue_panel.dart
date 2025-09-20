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
  
  bool _isReordering = false;

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
            
            // Clear queue button
            Container(
              decoration: BoxDecoration(
                color: queueLength > 0 ? Colors.grey[800] : Colors.grey[900],
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                onPressed: queueLength > 0 ? _showClearQueueDialog : null,
                icon: Icon(
                  Icons.clear_all,
                  color: queueLength > 0 ? Colors.white : Colors.grey[600],
                  size: 18,
                ),
                tooltip: 'Clear queue',
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Reorder mode toggle
            Container(
              decoration: BoxDecoration(
                color: _isReordering 
                    ? const Color(0xFF00E676).withOpacity(0.2)
                    : (queueLength > 1 ? Colors.grey[800] : Colors.grey[900]),
                borderRadius: BorderRadius.circular(20),
                border: _isReordering 
                    ? Border.all(color: const Color(0xFF00E676), width: 1)
                    : null,
              ),
              child: IconButton(
                onPressed: queueLength > 1 ? _toggleReorderMode : null,
                icon: Icon(
                  _isReordering ? Icons.done : Icons.reorder,
                  color: _isReordering 
                      ? const Color(0xFF00E676) 
                      : (queueLength > 1 ? Colors.white : Colors.grey[600]),
                  size: 18,
                ),
                tooltip: _isReordering ? 'Done reordering' : 'Reorder queue',
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
    if (_isReordering) {
      return ReorderableListView.builder(
        itemCount: queue.length,
        onReorder: _onReorder,
        itemBuilder: (context, index) {
          final song = queue[index];
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
    } else {
      return ListView.builder(
        itemCount: queue.length,
        itemBuilder: (context, index) {
          final song = queue[index];
          final isCurrentSong = currentSong?.id == song.id;
          
          return _buildQueueItem(
            key: ValueKey(song.id),
            song: song,
            index: index,
            isCurrentSong: isCurrentSong,
            audioHandler: audioHandler,
            showReorderHandle: false,
          );
        },
      );
    }
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
            
            // Remove button
            if (!showReorderHandle)
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _removeFromQueue(song, audioHandler);
                  },
                  icon: Icon(
                    Icons.close,
                    color: Colors.grey[300],
                    size: 18,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  tooltip: 'Remove from queue',
                ),
              ),
            
            // Reorder handle
            if (showReorderHandle)
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
        onTap: !_isReordering ? () => _jumpToSong(index, audioHandler) : null,
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

  void _toggleReorderMode() {
    setState(() {
      _isReordering = !_isReordering;
    });
    HapticFeedback.selectionClick();
    
    _loggingService.logInfo('Queue reorder mode: $_isReordering');
  }

  void _onReorder(int oldIndex, int newIndex) {
    try {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      
      // TODO: Implement queue reordering in audio handler
      _loggingService.logInfo('Reordered queue item from $oldIndex to $newIndex');
      
      HapticFeedback.lightImpact();
    } catch (e, stackTrace) {
      _loggingService.logError('Error reordering queue', e, stackTrace);
    }
  }

  void _jumpToSong(int index, audioHandler) {
    try {
      audioHandler.skipToQueueItem(index);
      _loggingService.logInfo('Jumping to song at index $index');
      HapticFeedback.selectionClick();
      
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

  void _removeFromQueue(MediaItem song, audioHandler) {
    try {
      audioHandler.removeQueueItem(song);
      _loggingService.logInfo('Removed song from queue: ${song.title}');
      
      // No snackbar message - clean UX like Spotify
    } catch (e, stackTrace) {
      _loggingService.logError('Error removing song from queue', e, stackTrace);
      
      // Only show error snackbar for failures
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove "${song.title}" from queue', style: const TextStyle(color: Colors.black)),
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

  void _showClearQueueDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text(
              'Clear Queue',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to clear the entire queue? This will stop playback.',
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
              _clearQueue();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear Queue'),
          ),
        ],
      ),
    );
  }

  void _clearQueue() {
    try {
      final audioHandler = ref.read(audioHandlerProvider);
      audioHandler.clearQueue();
      
      _loggingService.logInfo('Queue cleared by user');
      
      // No snackbar message - clean UX like Spotify
    } catch (e, stackTrace) {
      _loggingService.logError('Error clearing queue', e, stackTrace);
      
      // Only show error snackbar for failures
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.black),
              SizedBox(width: 8),
              Text('Failed to clear queue', style: TextStyle(color: Colors.black)),
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
}
