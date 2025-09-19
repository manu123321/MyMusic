import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../providers/music_provider.dart';
import '../screens/create_playlist_screen.dart';
import '../services/logging_service.dart';

class AddToPlaylistSheet extends ConsumerStatefulWidget {
  final Song song;

  const AddToPlaylistSheet({
    super.key,
    required this.song,
  });

  @override
  ConsumerState<AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends ConsumerState<AddToPlaylistSheet> {
  final LoggingService _loggingService = LoggingService();
  
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final playlists = ref.watch(playlistsProvider);
    final userPlaylists = playlists.where((p) => !p.isSystemPlaylist).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Song info
                Row(
                  children: [
                    // Album art
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.grey[800],
                      ),
                      child: widget.song.albumArtPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(
                                File(widget.song.albumArtPath!),
                                fit: BoxFit.cover,
                                width: 48,
                                height: 48,
                                cacheWidth: 48,
                                cacheHeight: 48,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.music_note,
                                    color: Colors.grey[400],
                                    size: 24,
                                  );
                                },
                              ),
                            )
                          : Icon(
                              Icons.music_note,
                              color: Colors.grey[400],
                              size: 24,
                            ),
                    ),
                    const SizedBox(width: 12),
                    // Song details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.song.title,
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
                            widget.song.artist,
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
                  ],
                ),
              ],
            ),
          ),
          
          // Create new playlist button
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: _buildNewPlaylistButton(),
          ),
          
          // Playlist list
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 350),
              child: userPlaylists.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: userPlaylists.length,
                      itemBuilder: (context, index) {
                        final playlist = userPlaylists[index];
                        return _buildPlaylistTile(playlist);
                      },
                    ),
            ),
          ),
          
          // Bottom padding
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildNewPlaylistButton() {
    return Center(
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () async {
            HapticFeedback.selectionClick();
            
            final result = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const CreatePlaylistScreen(),
              ),
            );
            
            if (result == true && mounted) {
              // Refresh playlists
              await ref.read(playlistsProvider.notifier).refreshPlaylists();
              
              // Get the newly created playlist and add the song to it
              final updatedPlaylists = ref.read(playlistsProvider);
              final userPlaylists = updatedPlaylists.where((p) => !p.isSystemPlaylist).toList();
              
              if (userPlaylists.isNotEmpty) {
                // Get the most recently created playlist
                final newestPlaylist = userPlaylists.reduce((a, b) => 
                    a.dateCreated.isAfter(b.dateCreated) ? a : b);
                
                try {
                  await ref
                      .read(playlistsProvider.notifier)
                      .addSongToPlaylist(newestPlaylist.id, widget.song.id);
                  
                  if (mounted) {
                    Navigator.of(context).pop();
                    _showSuccessSnackBar('Added to ${newestPlaylist.name}');
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.of(context).pop();
                    _showErrorSnackBar('Failed to add to playlist');
                  }
                }
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25), // Circular edges
            ),
            elevation: 2,
          ),
          child: const Text(
            'New Playlist',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistTile(Playlist playlist) {
    final isAlreadyAdded = playlist.songIds.contains(widget.song.id);
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: playlist.colorTheme != null 
              ? Color(int.parse(playlist.colorTheme!.substring(1), radix: 16) + 0xFF000000)
              : Colors.grey[800],
          borderRadius: BorderRadius.circular(6),
        ),
        child: playlist.coverArtPath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(
                  File(playlist.coverArtPath!),
                  fit: BoxFit.cover,
                  width: 48,
                  height: 48,
                  cacheWidth: 48,
                  cacheHeight: 48,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.music_note,
                      color: Colors.grey[400],
                      size: 24,
                    );
                  },
                ),
              )
            : Icon(
                Icons.music_note,
                color: Colors.grey[400],
                size: 24,
              ),
      ),
      title: Text(
        playlist.name,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${playlist.songIds.length} songs',
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 14,
        ),
      ),
      trailing: isAlreadyAdded
          ? Icon(
              Icons.check_circle,
              color: const Color(0xFF00E676),
              size: 20,
            )
          : null,
      onTap: isAlreadyAdded ? null : () => _addToPlaylist(playlist),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.playlist_play,
              size: 48,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'No playlists yet',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first playlist',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addToPlaylist(Playlist playlist) async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      HapticFeedback.lightImpact();
      
      await ref
          .read(playlistsProvider.notifier)
          .addSongToPlaylist(playlist.id, widget.song.id);

      _loggingService.logInfo('Added song to playlist: ${playlist.name}');

      if (mounted) {
        Navigator.of(context).pop();
        _showSuccessSnackBar('Added to ${playlist.name}');
      }
    } catch (e, stackTrace) {
      _loggingService.logError('Error adding to playlist', e, stackTrace);
      
      if (mounted) {
        Navigator.of(context).pop();
        _showErrorSnackBar('Failed to add to playlist');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.black, size: 20),
              const SizedBox(width: 8),
              Text(message, style: const TextStyle(color: Colors.black)),
            ],
          ),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          duration: const Duration(seconds: 2),
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
              const Icon(Icons.error_outline, color: Colors.black, size: 20),
              const SizedBox(width: 8),
              Text(message, style: const TextStyle(color: Colors.black)),
            ],
          ),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
