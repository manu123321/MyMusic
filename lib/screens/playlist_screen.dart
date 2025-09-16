import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../providers/music_provider.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../services/storage_service.dart';
import '../services/custom_audio_handler.dart';
import 'now_playing_screen.dart';

class PlaylistScreen extends ConsumerStatefulWidget {
  const PlaylistScreen({super.key});

  @override
  ConsumerState<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends ConsumerState<PlaylistScreen> {
  @override
  Widget build(BuildContext context) {
    final playlists = ref.watch(playlistsProvider);
    final userPlaylists = playlists.where((p) => !p.isSystemPlaylist).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Playlists',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: _showCreatePlaylistDialog,
            icon: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
      body: userPlaylists.isEmpty
          ? _buildEmptyState()
          : _buildPlaylistsList(userPlaylists),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.playlist_add,
            size: 80,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'No playlists yet',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first playlist',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _showCreatePlaylistDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
            ),
            child: const Text('Create Playlist'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistsList(List<Playlist> playlists) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return AnimationConfiguration.staggeredList(
          position: index,
          duration: const Duration(milliseconds: 375),
          child: SlideAnimation(
            verticalOffset: 50.0,
            child: FadeInAnimation(
              child: _buildPlaylistTile(playlist),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaylistTile(Playlist playlist) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.playlist_play,
            color: Colors.white,
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
        ),
        subtitle: Text(
          '${playlist.songIds.length} songs',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) {
            switch (value) {
              case 'play':
                _playPlaylist(playlist);
                break;
              case 'edit':
                _showEditPlaylistDialog(playlist);
                break;
              case 'delete':
                _showDeleteConfirmation(playlist);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'play',
              child: Row(
                children: [
                  Icon(Icons.play_arrow, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Play', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Edit', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _showPlaylistSongs(playlist),
      ),
    );
  }

  void _showCreatePlaylistDialog() {
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

  void _showEditPlaylistDialog(Playlist playlist) {
    final nameController = TextEditingController(text: playlist.name);
    final descriptionController = TextEditingController(text: playlist.description ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Edit playlist',
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
                final updatedPlaylist = playlist.copyWith(
                  name: nameController.text,
                  description: descriptionController.text.isNotEmpty
                      ? descriptionController.text
                      : null,
                );
                ref.read(playlistsProvider.notifier).updatePlaylist(updatedPlaylist);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Playlist updated'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Playlist playlist) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete playlist',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${playlist.name}"?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              ref.read(playlistsProvider.notifier).deletePlaylist(playlist.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Playlist deleted'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showPlaylistSongs(Playlist playlist) {
    final songs = ref.read(storageServiceProvider).getSongsByIds(playlist.songIds);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          playlist.name,
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: songs.isEmpty
              ? Center(
                  child: Text(
                    'No songs in this playlist',
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
                        _playSong(song);
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

  void _playPlaylist(Playlist playlist) {
    final songs = ref.read(storageServiceProvider).getSongsByIds(playlist.songIds);
    if (songs.isNotEmpty) {
      _playSong(songs.first);
    }
  }

  Future<void> _playSong(Song song) async {
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
