import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/music_provider.dart';
import '../services/storage_service.dart';
import '../services/custom_audio_handler.dart';
import '../widgets/song_list_tile.dart';
import '../widgets/mini_player.dart';
import 'now_playing_screen.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({
    super.key,
    required this.playlist,
  });

  @override
  ConsumerState<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  List<Song> _songs = [];
  List<Song> _filteredSongs = [];
  bool _isLoading = true;
  bool _isShuffled = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  void _loadSongs() {
    final songs = ref.read(storageServiceProvider).getSongsByIds(widget.playlist.songIds);
    setState(() {
      _songs = songs;
      _filteredSongs = songs;
      _isLoading = false;
    });
  }

  void _filterSongs(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredSongs = _songs;
      } else {
        _filteredSongs = _songs.where((song) {
          return song.title.toLowerCase().contains(query.toLowerCase()) ||
                 song.artist.toLowerCase().contains(query.toLowerCase()) ||
                 song.album.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
        slivers: [
          // App bar with playlist info
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Colors.black,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            title: Container(
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey[900]?.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterSongs,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search in playlist...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _filterSongs('');
                          },
                          icon: Icon(Icons.clear, color: Colors.grey[400], size: 18),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            actions: [
              IconButton(
                onPressed: _showPlaylistOptions,
                icon: const Icon(Icons.more_vert, color: Colors.white),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.grey[900]!,
                      Colors.black,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Calculate available height and adjust layout accordingly
                        final availableHeight = constraints.maxHeight;
                        final isVeryCompact = availableHeight < 200;
                        final isCompact = availableHeight < 250;
                        
                        return SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: IntrinsicHeight(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Spacer(),
                                  
                                  // Playlist icon
                                  Container(
                                    width: isVeryCompact ? 60 : (isCompact ? 80 : 120),
                                    height: isVeryCompact ? 60 : (isCompact ? 80 : 120),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[800],
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.playlist_play,
                                      color: Colors.white,
                                      size: isVeryCompact ? 24 : (isCompact ? 32 : 48),
                                    ),
                                  ),
                                  
                                  SizedBox(height: isVeryCompact ? 8 : (isCompact ? 12 : 24)),

                                  SizedBox(height: isVeryCompact ? 8 : (isCompact ? 12 : 24)),
                                  
                                  // Play buttons
                                  Row(
                                    children: [
                                      // Shuffle button (now first)
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _songs.isNotEmpty ? _shufflePlaylist : null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _isShuffled ? Colors.green : Colors.grey[800],
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: isVeryCompact ? 12 : (isCompact ? 16 : 24),
                                              vertical: isVeryCompact ? 6 : (isCompact ? 8 : 12),
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                          ),
                                          icon: Icon(Icons.shuffle, size: isVeryCompact ? 14 : (isCompact ? 16 : 20)),
                                          label: Text(
                                            'Shuffle',
                                            style: TextStyle(
                                              fontSize: isVeryCompact ? 12 : (isCompact ? 14 : 16),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                      
                                      SizedBox(width: isVeryCompact ? 8 : 12),
                                      
                                      // Play button (now second)
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _songs.isNotEmpty ? _togglePlayPause : null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: isVeryCompact ? 12 : (isCompact ? 16 : 24),
                                              vertical: isVeryCompact ? 6 : (isCompact ? 8 : 12),
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                          ),
                                          icon: StreamBuilder<PlaybackState>(
                                            stream: ref.read(audioHandlerProvider).playbackState,
                                            builder: (context, snapshot) {
                                              final isPlaying = snapshot.data?.playing ?? false;
                                              return Icon(
                                                isPlaying ? Icons.pause : Icons.play_arrow, 
                                                size: isVeryCompact ? 14 : (isCompact ? 16 : 20)
                                              );
                                            },
                                          ),
                                          label: StreamBuilder<PlaybackState>(
                                            stream: ref.read(audioHandlerProvider).playbackState,
                                            builder: (context, snapshot) {
                                              final isPlaying = snapshot.data?.playing ?? false;
                                              return Text(
                                                isPlaying ? 'Pause' : 'Play',
                                                style: TextStyle(
                                                  fontSize: isVeryCompact ? 12 : (isCompact ? 14 : 16),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Songs list
          SliverToBoxAdapter(
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    ),
                  )
                : _songs.isEmpty
                    ? _buildEmptyState()
                    : _filteredSongs.isEmpty && _searchQuery.isNotEmpty
                        ? _buildNoSearchResultsState()
                        : _buildSongsList(),
          ),
        ],
            ),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        children: [
          Icon(
            Icons.music_note,
            size: 80,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'No songs in this playlist',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add songs to start listening',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResultsState() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'No songs found',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching with different keywords',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Songs list
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredSongs.length,
          itemBuilder: (context, index) {
            final song = _filteredSongs[index];
            // Find the original index in the full songs list for proper playback
            final originalIndex = _songs.indexWhere((s) => s.id == song.id);
            return SongListTile(
              song: song,
              onTap: () => _playSong(song, originalIndex >= 0 ? originalIndex : index),
              onMorePressed: () => _showRemoveFromPlaylistDialog(song),
            );
          },
        ),
      ],
    );
  }

  void _showPlaylistOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white),
              title: const Text('Edit playlist', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _editPlaylist();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete playlist', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editPlaylist() {
    // TODO: Implement edit playlist functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit playlist functionality coming soon', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete playlist',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${widget.playlist.name}"?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              ref.read(playlistsProvider.notifier).deletePlaylist(widget.playlist.id);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to playlists screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Playlist deleted', style: TextStyle(color: Colors.black)),
                  backgroundColor: Colors.white,
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showRemoveFromPlaylistDialog(Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
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

            // Remove option
            ListTile(
              leading: const Icon(Icons.remove_circle_outline, color: Colors.red),
              title: const Text('Remove from playlist', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _removeSongFromPlaylist(song);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _removeSongFromPlaylist(Song song) {
    final updatedPlaylist = widget.playlist.copyWith(
      songIds: widget.playlist.songIds.where((id) => id != song.id).toList(),
    );
    ref.read(playlistsProvider.notifier).updatePlaylist(updatedPlaylist);
    
    // Update local songs list
    setState(() {
      _songs = _songs.where((s) => s.id != song.id).toList();
      _filteredSongs = _filteredSongs.where((s) => s.id != song.id).toList();
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${song.title}" from playlist', style: const TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
        ),
      );
    }
  }

  Future<void> _playPlaylist() async {
    if (_songs.isEmpty) return;
    
    try {
      final audioHandler = ref.read(audioHandlerProvider) as CustomAudioHandler;
      
      // Convert songs to MediaItems in their original playlist order
      final mediaItems = _songs.map((song) => MediaItem(
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
      )).toList();

      // Set the entire playlist as the queue (will start from first song)
      await audioHandler.setQueue(mediaItems);
      await audioHandler.play();
      
      
      // Navigate to now playing screen
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const NowPlayingScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing playlist: $e', style: const TextStyle(color: Colors.black)),
            backgroundColor: Colors.white,
          ),
        );
      }
    }
  }

  Future<void> _togglePlayPause() async {
    if (_songs.isEmpty) return;
    
    try {
      final audioHandler = ref.read(audioHandlerProvider) as CustomAudioHandler;
      final currentState = audioHandler.playbackState.value;
      final isCurrentlyPlaying = currentState.playing;
      
      if (isCurrentlyPlaying) {
        await audioHandler.pause();
      } else {
        // Check if there's a current queue and resume, or start new playlist
        final currentQueue = audioHandler.queue.value;
        if (currentQueue.isNotEmpty) {
          await audioHandler.play();
        } else {
          // No current queue, start playlist
          if (_isShuffled) {
            await _shufflePlaylist();
          } else {
            await _playPlaylist();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error controlling playback: $e', style: const TextStyle(color: Colors.black)),
            backgroundColor: Colors.white,
          ),
        );
      }
    }
  }

  Future<void> _shufflePlaylist() async {
    if (_songs.isEmpty) return;
    
    try {
      final audioHandler = ref.read(audioHandlerProvider) as CustomAudioHandler;
      
      // Toggle shuffle state
      setState(() {
        _isShuffled = !_isShuffled;
      });
      
      if (_isShuffled) {
        // Shuffle the songs
        final shuffledSongs = List<Song>.from(_songs)..shuffle();
        
        // Convert shuffled songs to MediaItems
        final mediaItems = shuffledSongs.map((song) => MediaItem(
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
        )).toList();

        // Set the shuffled playlist as the queue
        await audioHandler.setQueue(mediaItems);
        await audioHandler.play();
      } else {
        // Play normal playlist
        await _playPlaylist();
      }
      
      // Navigate to now playing screen
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const NowPlayingScreen(),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isShuffled = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error shuffling playlist: $e', style: const TextStyle(color: Colors.black)),
            backgroundColor: Colors.white,
          ),
        );
      }
    }
  }

  Future<void> _playSong(Song song, int index) async {
    try {
      final audioHandler = ref.read(audioHandlerProvider) as CustomAudioHandler;
      
      // Convert ALL playlist songs to MediaItems in their original order, but put the selected song first
      // This ensures the selected song starts playing while maintaining the full playlist context
      final selectedSong = _songs[index];
      final beforeSelected = _songs.take(index).toList();
      final afterSelected = _songs.skip(index + 1).toList();
      
      // Reorder: selected song first, then remaining songs in order
      final reorderedSongs = [selectedSong, ...afterSelected, ...beforeSelected];
      
      final mediaItems = reorderedSongs.map((s) => MediaItem(
        id: s.filePath,
        title: s.title,
        artist: s.artist,
        album: s.album,
        duration: Duration(milliseconds: s.duration),
        artUri: s.albumArtPath != null ? Uri.file(s.albumArtPath!) : null,
        extras: {
          'songId': s.id,
          'trackNumber': s.trackNumber,
          'year': s.year,
          'genre': s.genre,
          'playlistIndex': reorderedSongs.indexOf(s), // Track original position
        },
      )).toList();

      // Set the complete playlist as the queue (selected song will be at index 0)
      await audioHandler.setQueue(mediaItems);
      await audioHandler.play();
      
      // Update recently played
      await ref.read(storageServiceProvider).addToRecentlyPlayed(song.id);
      await ref.read(storageServiceProvider).updateSongPlayCount(song.id);
      
      // Navigate to now playing screen
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const NowPlayingScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing song: $e', style: const TextStyle(color: Colors.black)),
            backgroundColor: Colors.white,
          ),
        );
      }
    }
  }
}
