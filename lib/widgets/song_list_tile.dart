import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../services/logging_service.dart';
import 'add_to_playlist_sheet.dart';
import '../screens/now_playing_screen.dart';

class SongListTile extends ConsumerStatefulWidget {
  final Song song;
  final VoidCallback? onTap;
  final VoidCallback? onMorePressed;
  final bool showAlbumArt;
  final bool showDuration;
  final bool isSelected;
  final bool showPlayingIndicator;
  final bool showRating;

  const SongListTile({
    super.key,
    required this.song,
    this.onTap,
    this.onMorePressed,
    this.showAlbumArt = true,
    this.showDuration = true,
    this.isSelected = false,
    this.showPlayingIndicator = true,
    this.showRating = false,
  });

  @override
  ConsumerState<SongListTile> createState() => _SongListTileState();
}

class _SongListTileState extends ConsumerState<SongListTile>
    with AutomaticKeepAliveClientMixin {
  final LoggingService _loggingService = LoggingService();
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true; // Keep alive for performance

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final currentSong = ref.watch(currentSongProvider).value;
    final isCurrentlyPlaying = currentSong?.id == widget.song.id;

    return Semantics(
      label: 'Song: ${widget.song.title} by ${widget.song.artist}',
      hint: 'Tap to play, or tap more options for additional actions',
      child: Container(
        decoration: BoxDecoration(
          color: widget.isSelected
              ? const Color(0xFF00E676).withValues(alpha: 0.1)
              : (isCurrentlyPlaying ? Colors.grey[900]?.withValues(alpha: 0.5) : null),
          borderRadius: BorderRadius.circular(8),
          border: widget.isSelected
              ? Border.all(color: const Color(0xFF00E676), width: 1)
              : null,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _isLoading ? null : (widget.onTap ?? _playSong),
            splashColor: const Color(0xFF00E676).withOpacity(0.2),
            highlightColor: const Color(0xFF00E676).withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  // Album art with playing indicator
                  if (widget.showAlbumArt) ...[
                    _buildAlbumArt(isCurrentlyPlaying),
                    const SizedBox(width: 12),
                  ],

                  // Song information
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          widget.song.title,
                          style: TextStyle(
                            color: isCurrentlyPlaying ? const Color(0xFF00E676) : Colors.white,
                            fontSize: 16,
                            fontWeight: isCurrentlyPlaying ? FontWeight.w600 : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),

                        // Artist and album
                        Text(
                          '${widget.song.artist} • ${widget.song.album}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // Additional info row
                        if (widget.song.isFavorite)
                          const SizedBox(height: 4),
                        if (widget.song.isFavorite)
                          _buildAdditionalInfo(),
                      ],
                    ),
                  ),


                  // More options button - positioned very close to right edge
                  IconButton(
                    onPressed: widget.onMorePressed ?? _showSongOptions,
                    icon: Icon(
                      Icons.more_vert,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                    tooltip: 'More options',
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumArt(bool isCurrentlyPlaying) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: widget.song.albumArtPath != null
              ? Image.file(
            File(widget.song.albumArtPath!),
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            cacheWidth: 56,
            cacheHeight: 56,
            errorBuilder: (context, error, stackTrace) {
              return _buildDefaultAlbumArt(56);
            },
          )
              : _buildDefaultAlbumArt(56),
        ),
        if (isCurrentlyPlaying && widget.showPlayingIndicator)
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Color(0xFF00E676),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.equalizer,
                color: Colors.white,
                size: 10,
              ),
            ),
          ),
        if (_isLoading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }


  Widget _buildAdditionalInfo() {
    return Row(
      children: [
        if (widget.song.isFavorite)
          Icon(
            Icons.favorite,
            color: Colors.red[400],
            size: 12,
          ),
      ],
    );
  }


  Future<void> _playSong() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Enhanced haptic feedback for better UX
      HapticFeedback.mediumImpact();

      // Validate song file exists
      if (!widget.song.fileExists) {
        _showErrorSnackBar('Song file not found: ${widget.song.title}');
        return;
      }

      _loggingService.logInfo('Playing song: ${widget.song.title}');

      final audioHandler = ref.read(audioHandlerProvider);

      // Convert song to MediaItem
      final mediaItem = MediaItem(
        id: widget.song.filePath,
        title: widget.song.title,
        artist: widget.song.artist,
        album: widget.song.album,
        duration: Duration(milliseconds: widget.song.duration),
        artUri: widget.song.albumArtPath != null ? Uri.file(widget.song.albumArtPath!) : null,
        extras: {
          'songId': widget.song.id,
          'trackNumber': widget.song.trackNumber,
          'year': widget.song.year,
          'genre': widget.song.genre,
          'isFavorite': widget.song.isFavorite,
        },
      );

      // Set this song as the only song in the queue
      await audioHandler.setQueue([mediaItem]);

      // Small delay to ensure queue is properly set
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Start playing from the beginning
      await audioHandler.seek(Duration.zero);
      await audioHandler.play();
      
      // Small delay to ensure playback starts and state is updated
      await Future.delayed(const Duration(milliseconds: 200));

      // Update song statistics
      await Future.wait([
        ref.read(storageServiceProvider).updateSongPlayCount(widget.song.id),
        ref.read(storageServiceProvider).addToRecentlyPlayed(widget.song.id),
      ]);

      // Song will start playing and show in mini player
      // User can tap mini player to navigate to Now Playing screen
      _loggingService.logInfo('Song started playing: ${widget.song.title}');
      
      // Provide subtle visual feedback that song is now playing
      _showSuccessSnackBar('♪ Now playing: ${widget.song.title}');
    } catch (e, stackTrace) {
      _loggingService.logError('Error playing song: ${widget.song.title}', e, stackTrace);
      _showErrorSnackBar('Unable to play ${widget.song.title}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSongOptions() {
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
            _buildSongHeader(),
            const SizedBox(height: 24),

            // Options
            _buildOptionTile(
              icon: Icons.play_arrow,
              title: 'Play',
              onTap: () {
                Navigator.pop(context);
                _playSong();
              },
            ),
            _buildOptionTile(
              icon: widget.song.isFavorite ? Icons.favorite : Icons.favorite_border,
              title: widget.song.isFavorite ? 'Remove from favorites' : 'Add to favorites',
              onTap: () {
                Navigator.pop(context);
                _toggleFavorite();
              },
            ),
            _buildOptionTile(
              icon: Icons.queue_music,
              title: 'Add to queue',
              onTap: () {
                Navigator.pop(context);
                _addToQueue();
              },
            ),
            _buildOptionTile(
              icon: Icons.playlist_add,
              title: 'Add to playlist',
              onTap: () {
                Navigator.pop(context);
                _showAddToPlaylistDialog();
              },
            ),
            _buildOptionTile(
              icon: Icons.info_outline,
              title: 'Song info',
              onTap: () {
                Navigator.pop(context);
                _showSongInfoDialog();
              },
            ),
            _buildOptionTile(
              icon: Icons.remove_circle_outline,
              title: 'Remove from library',
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation();
              },
              isDestructive: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongHeader() {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: widget.song.albumArtPath != null
              ? Image.file(
            File(widget.song.albumArtPath!),
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
                widget.song.title,
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
                widget.song.artist,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.song.album.isNotEmpty)
                Text(
                  widget.song.album,
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

  void _toggleFavorite() {
    try {
      HapticFeedback.lightImpact();

      final updatedSong = widget.song.toggleFavorite();
      ref.read(songsProvider.notifier).updateSong(updatedSong);

      _loggingService.logInfo('Toggled favorite for: ${widget.song.title}');

      _showSuccessSnackBar(
          widget.song.isFavorite
              ? 'Removed from favorites'
              : 'Added to favorites'
      );
    } catch (e, stackTrace) {
      _loggingService.logError('Error toggling favorite', e, stackTrace);
      _showErrorSnackBar('Failed to update favorites');
    }
  }

  void _showAddToPlaylistDialog() {
    HapticFeedback.selectionClick();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AddToPlaylistSheet(song: widget.song),
    );
  }


  void _showSongInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Song Information',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Title', widget.song.title),
              _buildInfoRow('Artist', widget.song.artist),
              _buildInfoRow('Album', widget.song.album),
              if (widget.song.genre != null)
                _buildInfoRow('Genre', widget.song.genre!),
              if (widget.song.year != null)
                _buildInfoRow('Year', widget.song.year.toString()),
              if (widget.song.trackNumber != null)
                _buildInfoRow('Track', widget.song.trackNumber.toString()),
              _buildInfoRow('Duration', widget.song.formattedDuration),
              _buildInfoRow('File size', widget.song.formattedFileSize),
              _buildInfoRow('Bitrate', '${widget.song.bitrate} kbps'),
              _buildInfoRow('Date added', widget.song.dateAdded.toString().split(' ')[0]),
              if (widget.song.lastPlayed != null)
                _buildInfoRow('Last played', widget.song.lastPlayed.toString().split(' ')[0]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
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

  void _showDeleteConfirmation() {
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
          'Are you sure you want to remove "${widget.song.title}" from your library?\n\nThis will remove it from all playlists but won\'t delete the actual file.',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final navigator = Navigator.of(context);
                await ref.read(songsProvider.notifier).deleteSong(widget.song.id);

                if (mounted) {
                  navigator.pop();
                  _showSuccessSnackBar('Song removed from library');
                }
              } catch (e, stackTrace) {
                _loggingService.logError('Error deleting song', e, stackTrace);
                if (mounted) {
                  Navigator.of(context).pop();
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

  void _addToQueue() {
    try {
      HapticFeedback.lightImpact();
      
      final audioHandler = ref.read(audioHandlerProvider);
      
      // Convert song to MediaItem
      final mediaItem = MediaItem(
        id: widget.song.filePath,
        title: widget.song.title,
        artist: widget.song.artist,
        album: widget.song.album,
        duration: Duration(milliseconds: widget.song.duration),
        artUri: widget.song.albumArtPath != null ? Uri.file(widget.song.albumArtPath!) : null,
        extras: {
          'songId': widget.song.id,
          'trackNumber': widget.song.trackNumber,
          'year': widget.song.year,
          'genre': widget.song.genre,
          'isFavorite': widget.song.isFavorite,
        },
      );
      
      // Add to queue
      audioHandler.addQueueItem(mediaItem);
      
      _loggingService.logInfo('Added song to queue: ${widget.song.title}');
      
      _showSuccessSnackBar('♪ Added "${widget.song.title}" to queue');
    } catch (e, stackTrace) {
      _loggingService.logError('Error adding song to queue', e, stackTrace);
      _showErrorSnackBar('Failed to add song to queue');
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green[700],
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
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
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
