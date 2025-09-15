import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/music_provider.dart';
import '../widgets/song_list_tile.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchResultsProvider);
    final playlistSearchResults = ref.watch(playlistSearchResultsProvider);
    final songs = ref.watch(songsProvider);
    final playlists = ref.watch(playlistsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search for songs, artists, albums...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                            ref.read(searchQueryProvider.notifier).state = '';
                          },
                          icon: Icon(Icons.clear, color: Colors.grey[500]),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                  ref.read(searchQueryProvider.notifier).state = value;
                },
              ),
            ),

            // Search results or browse content
            Expanded(
              child: _searchQuery.isEmpty
                  ? _buildBrowseContent(songs, playlists)
                  : _buildSearchResults(searchResults, playlistSearchResults),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrowseContent(songs, playlists) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Browse all
          const Text(
            'Browse all',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Categories grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildCategoryCard(
                'Recently Played',
                Icons.history,
                Colors.purple,
                () {
                  // Navigate to recently played
                },
              ),
              _buildCategoryCard(
                'Liked Songs',
                Icons.favorite,
                Colors.pink,
                () {
                  // Navigate to liked songs
                },
              ),
              _buildCategoryCard(
                'Most Played',
                Icons.trending_up,
                Colors.orange,
                () {
                  // Navigate to most played
                },
              ),
              _buildCategoryCard(
                'All Songs',
                Icons.music_note,
                Colors.blue,
                () {
                  // Navigate to all songs
                },
              ),
              _buildCategoryCard(
                'Playlists',
                Icons.playlist_play,
                Colors.green,
                () {
                  // Navigate to playlists
                },
              ),
              _buildCategoryCard(
                'Artists',
                Icons.person,
                Colors.red,
                () {
                  // Navigate to artists
                },
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Recently added
          if (songs.isNotEmpty) ...[
            const Text(
              'Recently added',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: songs.take(5).length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return SongListTile(
                  song: song,
                  onTap: () {
                    // Play song
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchResults(searchResults, playlistSearchResults) {
    if (searchResults.isEmpty && playlistSearchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching for something else',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Songs
        if (searchResults.isNotEmpty) ...[
          const Text(
            'Songs',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...searchResults.map((song) => SongListTile(
                song: song,
                onTap: () {
                  // Play song
                },
              )),
          const SizedBox(height: 32),
        ],

        // Playlists
        if (playlistSearchResults.isNotEmpty) ...[
          const Text(
            'Playlists',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...playlistSearchResults.map((playlist) => ListTile(
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
                  // Open playlist
                },
              )),
        ],
      ],
    );
  }

  Widget _buildCategoryCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
