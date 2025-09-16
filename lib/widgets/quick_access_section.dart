import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../providers/music_provider.dart';
import '../models/song.dart';
import '../services/custom_audio_handler.dart';
import '../services/storage_service.dart';
import '../screens/now_playing_screen.dart';

class QuickAccessSection extends ConsumerWidget {
  const QuickAccessSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildQuickAccessCard(
                context,
                icon: Icons.history,
                title: 'Recently Played',
                subtitle: 'Your recent activity',
                onTap: () {
                  _navigateToRecentlyPlayed(context, ref);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickAccessCard(
                context,
                icon: Icons.trending_up,
                title: 'Most Played',
                subtitle: 'Your top tracks',
                onTap: () {
                  _navigateToMostPlayed(context, ref);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildQuickAccessCard(
                context,
                icon: Icons.playlist_add,
                title: 'Create Playlist',
                subtitle: 'Make your own mix',
                onTap: () {
                  _showCreatePlaylistDialog(context, ref);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAccessCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Create playlist',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Playlist name',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                ref.read(playlistsProvider.notifier).createPlaylist(
                      nameController.text,
                      description: descriptionController.text.isNotEmpty
                          ? descriptionController.text
                          : null,
                    );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Playlist "${nameController.text}" created'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }


  void _navigateToRecentlyPlayed(BuildContext context, WidgetRef ref) {
    final recentlyPlayed = ref.read(songsProvider.notifier).getRecentlyPlayed();
    _showSongsDialog(context, ref, 'Recently Played', recentlyPlayed);
  }

  void _navigateToMostPlayed(BuildContext context, WidgetRef ref) {
    final mostPlayed = ref.read(songsProvider.notifier).getMostPlayed();
    _showSongsDialog(context, ref, 'Most Played', mostPlayed);
  }

  void _showSongsDialog(BuildContext context, WidgetRef ref, String title, List<Song> songs) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: songs.isEmpty
              ? Center(
                  child: Text(
                    'No songs found',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                )
              : ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return ListTile(
                      leading: const Icon(Icons.music_note, color: Colors.white),
                      title: Text(
                        song.title,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        song.artist,
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _playSong(context, ref, song);
                      },
                    );
                  },
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

  Future<void> _playSong(BuildContext context, WidgetRef ref, Song song) async {
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
      
      // Update recently played
      await ref.read(storageServiceProvider).addToRecentlyPlayed(song.id);
      await ref.read(storageServiceProvider).updateSongPlayCount(song.id);
      
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
}
