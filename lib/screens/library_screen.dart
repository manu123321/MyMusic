import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../providers/music_provider.dart';
import '../widgets/song_list_tile.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../services/custom_audio_handler.dart';
import '../services/storage_service.dart';
import '../screens/now_playing_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songs = ref.watch(songsProvider);
    final playlists = ref.watch(playlistsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your Library',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          // Show sort options
                          _showSortOptions(context);
                        },
                        icon: const Icon(Icons.sort, color: Colors.white),
                      ),
                      IconButton(
                        onPressed: () {
                          // Show view options
                          _showViewOptions(context);
                        },
                        icon: const Icon(Icons.view_list, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tab bar
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[400],
              tabs: const [
                Tab(text: 'Playlists'),
                Tab(text: 'Songs'),
                Tab(text: 'Artists'),
              ],
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPlaylistsTab(playlists),
                  _buildSongsTab(songs),
                  _buildArtistsTab(songs),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistsTab(List<Playlist> playlists) {
    final userPlaylists = playlists.where((p) => !p.isSystemPlaylist).toList();
    final systemPlaylists = playlists.where((p) => p.isSystemPlaylist).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 16),

        // System playlists
        if (systemPlaylists.isNotEmpty) ...[
          const Text(
            'Made for you',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...systemPlaylists.map((playlist) => _buildPlaylistTile(playlist)),
          const SizedBox(height: 32),
        ],

        // User playlists
        if (userPlaylists.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your playlists',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  _showCreatePlaylistDialog(context);
                },
                child: const Text(
                  'Create',
                  style: TextStyle(color: Colors.green),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...userPlaylists.map((playlist) => _buildPlaylistTile(playlist)),
        ],

        // Empty state
        if (playlists.isEmpty)
          Center(
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
                  onPressed: () {
                    _showCreatePlaylistDialog(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Create Playlist'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSongsTab(List<Song> songs) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        return SongListTile(
          song: song,
          onTap: () => _playSong(context, ref, song),
        );
      },
    );
  }

  Widget _buildArtistsTab(List<Song> songs) {
    // Group songs by artist
    final artistMap = <String, List<Song>>{};
    for (final song in songs) {
      if (!artistMap.containsKey(song.artist)) {
        artistMap[song.artist] = [];
      }
      artistMap[song.artist]!.add(song);
    }

    final artists = artistMap.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        final artistSongs = artistMap[artist]!;
        final albumCount = artistSongs.map((s) => s.album).toSet().length;

        return ListTile(
          leading: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 24,
            ),
          ),
          title: Text(
            artist,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            '$albumCount albums • ${artistSongs.length} songs',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          onTap: () {
            // Navigate to artist page
          },
        );
      },
    );
  }

  Widget _buildPlaylistTile(Playlist playlist) {
    return ListTile(
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
      onTap: () {
        _navigateToPlaylist(context, ref, playlist);
      },
    );
  }

  void _showSortOptions(BuildContext context) {
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
            const Text(
              'Sort by',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSortOption('Name', Icons.sort_by_alpha),
            _buildSortOption('Date added', Icons.schedule),
            _buildSortOption('Recently played', Icons.history),
            _buildSortOption('Most played', Icons.trending_up),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String title, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      onTap: () {
        Navigator.pop(context);
        // Apply sort
      },
    );
  }

  void _showViewOptions(BuildContext context) {
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
            const Text(
              'View as',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildViewOption('List', Icons.view_list),
            _buildViewOption('Grid', Icons.grid_view),
            _buildViewOption('Compact', Icons.view_compact),
          ],
        ),
      ),
    );
  }

  Widget _buildViewOption(String title, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      onTap: () {
        Navigator.pop(context);
        // Apply view
      },
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
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

  void _navigateToPlaylist(BuildContext context, WidgetRef ref, Playlist playlist) {
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
