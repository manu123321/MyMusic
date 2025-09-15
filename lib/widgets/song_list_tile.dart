import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../services/metadata_service.dart';
import '../services/custom_audio_handler.dart';
import '../screens/now_playing_screen.dart';

class SongListTile extends ConsumerWidget {
  final Song song;
  final VoidCallback? onTap;
  final VoidCallback? onMorePressed;
  final bool showAlbumArt;
  final bool showDuration;

  const SongListTile({
    super.key,
    required this.song,
    this.onTap,
    this.onMorePressed,
    this.showAlbumArt = true,
    this.showDuration = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metadataService = ref.read(metadataServiceProvider);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: showAlbumArt
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: song.albumArtPath != null
                  ? Image.file(
                      File(song.albumArtPath!),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 56,
                          height: 56,
                          color: Colors.grey[800],
                          child: const Icon(
                            Icons.music_note,
                            color: Colors.white,
                            size: 24,
                          ),
                        );
                      },
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey[800],
                      child: const Icon(
                        Icons.music_note,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
            )
          : null,
      title: Text(
        song.title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${song.artist} • ${song.album}',
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDuration)
            Text(
              metadataService.formatDuration(song.duration),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onMorePressed ??
                () {
                  _showSongOptions(context, ref);
                },
            icon: Icon(
              Icons.more_vert,
              color: Colors.grey[400],
              size: 20,
            ),
          ),
        ],
      ),
      onTap: onTap ?? () => _playSong(context, ref),
    );
  }

  Future<void> _playSong(BuildContext context, WidgetRef ref) async {
    try {
      final audioHandler = ref.read(audioHandlerProvider) as CustomAudioHandler;
      
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
        },
      );
      
      // Clear current queue and add this song
      await audioHandler.addQueueItems([mediaItem]);
      
      // Start playing
      await audioHandler.play();
      
      // Navigate to now playing screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const NowPlayingScreen(),
        ),
      );
    } catch (e) {
      print('Error playing song: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error playing song: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSongOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Song info
            Row(
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
                            return Container(
                              width: 64,
                              height: 64,
                              color: Colors.grey[800],
                              child: const Icon(
                                Icons.music_note,
                                color: Colors.white,
                                size: 32,
                              ),
                            );
                          },
                        )
                      : Container(
                          width: 64,
                          height: 64,
                          color: Colors.grey[800],
                          child: const Icon(
                            Icons.music_note,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
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
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Options
            _buildOptionTile(
              context,
              icon: Icons.play_arrow,
              title: 'Play',
              onTap: () {
                Navigator.pop(context);
                // Play song
              },
            ),
            _buildOptionTile(
              context,
              icon: Icons.playlist_add,
              title: 'Add to playlist',
              onTap: () {
                Navigator.pop(context);
                _showAddToPlaylistDialog(context, ref);
              },
            ),
            _buildOptionTile(
              context,
              icon: song.isLiked ? Icons.favorite : Icons.favorite_border,
              title: song.isLiked ? 'Remove from liked' : 'Add to liked',
              onTap: () {
                Navigator.pop(context);
                ref.read(songsProvider.notifier).toggleLike(song.id);
              },
            ),
            _buildOptionTile(
              context,
              icon: Icons.info_outline,
              title: 'Song info',
              onTap: () {
                Navigator.pop(context);
                _showSongInfoDialog(context);
              },
            ),
            _buildOptionTile(
              context,
              icon: Icons.delete_outline,
              title: 'Remove from library',
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
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
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, WidgetRef ref) {
    final playlists = ref.read(playlistsProvider.notifier).getUserPlaylists();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Add to playlist',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              return ListTile(
                title: Text(
                  playlist.name,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  '${playlist.songIds.length} songs',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                onTap: () {
                  ref
                      .read(playlistsProvider.notifier)
                      .addSongToPlaylist(playlist.id, song.id);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added to ${playlist.name}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _showSongInfoDialog(BuildContext context) {
    final metadataService = MetadataService();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Song info',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Title', song.title),
            _buildInfoRow('Artist', song.artist),
            _buildInfoRow('Album', song.album),
            if (song.genre != null) _buildInfoRow('Genre', song.genre!),
            if (song.year != null) _buildInfoRow('Year', song.year.toString()),
            if (song.trackNumber != null)
              _buildInfoRow('Track', song.trackNumber.toString()),
            _buildInfoRow('Duration', metadataService.formatDuration(song.duration)),
            _buildInfoRow('File size', metadataService.formatFileSize(0)), // TODO: Get actual file size
            _buildInfoRow('Play count', song.playCount.toString()),
            _buildInfoRow('Date added', song.dateAdded.toString().split(' ')[0]),
          ],
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
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
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

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Remove from library',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to remove "${song.title}" from your library?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              ref.read(songsProvider.notifier).deleteSong(song.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Song removed from library'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
