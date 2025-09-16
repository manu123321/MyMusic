import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:audio_service/audio_service.dart';
import '../providers/music_provider.dart';
import '../widgets/song_list_tile.dart';
import '../widgets/playlist_card.dart';
import '../widgets/quick_access_section.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../services/custom_audio_handler.dart';
import '../services/storage_service.dart';
import 'settings_screen.dart';
import 'library_screen.dart';
import 'now_playing_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(songsProvider);
    final playlists = ref.watch(playlistsProvider);
    final recentlyPlayed = ref.watch(songsProvider.notifier).getRecentlyPlayed();
    final systemPlaylists = playlists.where((p) => p.isSystemPlaylist).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App bar
            SliverAppBar(
              backgroundColor: Colors.black,
              elevation: 0,
              floating: true,
              title: const Text(
                'Good evening',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.settings, color: Colors.white),
                ),
              ],
            ),

            // Quick access sections
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    
                    // Recently played
                    if (recentlyPlayed.isNotEmpty) ...[
                      const Text(
                        'Recently played',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: recentlyPlayed.take(10).length,
                          itemBuilder: (context, index) {
                            final song = recentlyPlayed[index];
                            return Container(
                              width: 160,
                              margin: const EdgeInsets.only(right: 16),
                              child: PlaylistCard(
                                title: song.title,
                                subtitle: song.artist,
                                imagePath: song.albumArtPath,
                                onTap: () => _playSong(context, ref, song),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Made for you
                    if (systemPlaylists.isNotEmpty) ...[
                      const Text(
                        'Made for you',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: systemPlaylists.length,
                          itemBuilder: (context, index) {
                            final playlist = systemPlaylists[index];
                            return Container(
                              width: 160,
                              margin: const EdgeInsets.only(right: 16),
                              child: PlaylistCard(
                                title: playlist.name,
                                subtitle: '${playlist.songIds.length} songs',
                                imagePath: playlist.coverArtPath,
                                onTap: () => _navigateToPlaylist(context, ref, playlist),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                    const SizedBox(height: 32),

                    // Quick access
                    const Text(
                      'Quick access',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const QuickAccessSection(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Recently added songs
            if (songs.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recently added',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          _navigateToAllSongs(context);
                        },
                        child: const Text(
                          'Show all',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = songs.take(10).toList()[index];
                            return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 375),
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: SongListTile(
                              song: song,
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: songs.take(10).length,
                  ),
                ),
              ),
            ],

            // Empty state
            if (songs.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Icon(
                        Icons.music_note,
                        size: 80,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No music found',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Scan your device to find music',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () async {
                          final metadataService = ref.read(metadataServiceProvider);
                          final newSongs = await metadataService.scanDeviceForAudioFiles();
                          if (newSongs.isNotEmpty) {
                            for (final song in newSongs) {
                              await ref.read(songsProvider.notifier).addSong(song);
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Found ${newSongs.length} new music files'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No new music files found'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                        child: const Text('Scan for Music'),
                      ),
                      ],
                    ),
                  ),
                ),
              ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 100), // Space for mini player
            ),
          ],
        ),
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

  void _navigateToPlaylist(BuildContext context, WidgetRef ref, Playlist playlist) {
    // Navigate to playlist detail screen
    // For now, we'll show a simple dialog with playlist songs
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
              ? const Center(
                  child: Text(
                    'No songs in this playlist',
                    style: TextStyle(color: Colors.grey),
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

  void _navigateToAllSongs(BuildContext context) {
    // Navigate to library screen with songs tab selected
    // We'll use a simple approach by showing the library screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LibraryScreen(),
      ),
    );
  }
}
