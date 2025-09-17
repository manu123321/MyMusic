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
              'Up Next',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$queueLength song${queueLength == 1 ? '' : 's'}',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
        Row(
          children: [
            // Shuffle queue button
            IconButton(
              onPressed: queueLength > 1 ? _shuffleQueue : null,
              icon: Icon(
                Icons.shuffle,
                color: queueLength > 1 ? Colors.white : Colors.grey[600],
                size: 20,
              ),
              tooltip: 'Shuffle queue',
            ),
            
            // Clear queue button
            IconButton(
              onPressed: queueLength > 0 ? _showClearQueueDialog : null,
              icon: Icon(
                Icons.clear_all,
                color: queueLength > 0 ? Colors.white : Colors.grey[600],
                size: 20,
              ),
              tooltip: 'Clear queue',
            ),
            
            // Reorder mode toggle
            IconButton(
              onPressed: queueLength > 1 ? _toggleReorderMode : null,
              icon: Icon(
                _isReordering ? Icons.done : Icons.reorder,
                color: _isReordering 
                    ? const Color(0xFF00E676) 
                    : (queueLength > 1 ? Colors.white : Colors.grey[600]),
                size: 20,
              ),
              tooltip: _isReordering ? 'Done reordering' : 'Reorder queue',
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
          Icon(
            Icons.queue_music_outlined,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'Queue is empty',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w500,
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
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCurrentSong 
            ? const Color(0xFF00E676).withOpacity(0.1)
            : Colors.grey[800]?.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: isCurrentSong
            ? Border.all(color: const Color(0xFF00E676), width: 1)
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Queue position
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCurrentSong ? const Color(0xFF00E676) : Colors.grey[700],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: isCurrentSong ? Colors.black : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            
            // Album art
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: song.artUri != null
                  ? Image.file(
                      File(song.artUri!.toFilePath()),
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      cacheWidth: 40,
                      cacheHeight: 40,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultAlbumArt();
                      },
                    )
                  : _buildDefaultAlbumArt(),
            ),
          ],
        ),
        title: Text(
          song.title,
          style: TextStyle(
            color: isCurrentSong ? const Color(0xFF00E676) : Colors.white,
            fontSize: 14,
            fontWeight: isCurrentSong ? FontWeight.w600 : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          song.artist ?? 'Unknown Artist',
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
            // Playing indicator
            if (isCurrentSong)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'PLAYING',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            
            const SizedBox(width: 8),
            
            // Remove button
            if (!showReorderHandle)
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _removeFromQueue(song, audioHandler);
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
                tooltip: 'Remove from queue',
              ),
            
            // Reorder handle
            if (showReorderHandle)
              Icon(
                Icons.drag_handle,
                color: Colors.grey[400],
                size: 20,
              ),
          ],
        ),
        onTap: !_isReordering ? () => _jumpToSong(index, audioHandler) : null,
      ),
    );
  }

  Widget _buildDefaultAlbumArt() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(4),
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
        size: 16,
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
      // TODO: Implement jump to song functionality
      _loggingService.logInfo('Jumping to song at index $index');
      HapticFeedback.selectionClick();
    } catch (e, stackTrace) {
      _loggingService.logError('Error jumping to song', e, stackTrace);
    }
  }

  void _removeFromQueue(MediaItem song, audioHandler) {
    try {
      audioHandler.removeQueueItem(song);
      _loggingService.logInfo('Removed song from queue: ${song.title}');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${song.title}" from queue'),
          backgroundColor: Colors.orange[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (e, stackTrace) {
      _loggingService.logError('Error removing song from queue', e, stackTrace);
    }
  }

  void _shuffleQueue() {
    try {
      // TODO: Implement queue shuffle functionality
      _loggingService.logInfo('Shuffling queue');
      HapticFeedback.mediumImpact();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Queue shuffled'),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (e, stackTrace) {
      _loggingService.logError('Error shuffling queue', e, stackTrace);
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Queue cleared'),
            ],
          ),
          backgroundColor: Colors.orange[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (e, stackTrace) {
      _loggingService.logError('Error clearing queue', e, stackTrace);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('Failed to clear queue'),
            ],
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }
}
