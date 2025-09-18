import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../providers/music_provider.dart';
import '../widgets/song_list_tile.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../services/custom_audio_handler.dart';
import '../services/storage_service.dart';
import '../services/logging_service.dart';
import 'now_playing_screen.dart';
import 'playlist_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final LoggingService _loggingService = LoggingService();
  
  String _searchQuery = '';
  bool _isSearching = false;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Timer for auto-dismiss functionality
  Timer? _autoDismissTimer;
  
  // Performance optimization - keep alive
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchFocusNode.addListener(_onSearchFocusChanged);
    _loadInitialData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoDismissTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }
  
  void _onSearchFocusChanged() {
    setState(() {
      // Update UI when focus changes
      if (!_searchFocusNode.hasFocus && _searchQuery.isEmpty) {
        _isSearching = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return _buildContent();
  }
  
  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }
    
    if (_errorMessage != null) {
      return _buildErrorState();
    }
    
    final songs = ref.watch(songsProvider);

    // Filter songs based on search
    final filteredSongs = _searchQuery.isEmpty
        ? songs
        : songs.where((song) {
            final query = _searchQuery.toLowerCase();
            return song.title.toLowerCase().contains(query) ||
                   song.artist.toLowerCase().contains(query) ||
                   song.album.toLowerCase().contains(query);
          }).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            // Dismiss search when tapping outside
            if (_searchFocusNode.hasFocus) {
              _searchFocusNode.unfocus();
            }
          },
          child: RefreshIndicator(
            onRefresh: _refreshData,
            color: const Color(0xFF00E676),
            backgroundColor: Colors.grey[900],
            child: Column(
              children: [
                // Header with search
                _buildHeader(),
                
                // Main content
                Expanded(
                  child: _buildMainContent(filteredSongs),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // App title and action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Music Player',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const PlaylistScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.library_music, color: Colors.white, size: 20),
                label: const Text(
                  'Your Library',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
                    const SizedBox(height: 16),
                    
          // Search bar
          Semantics(
            label: 'Search music',
            hint: 'Search for songs, artists, or albums',
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(25),
                border: _searchFocusNode.hasFocus 
                    ? Border.all(color: const Color(0xFF00E676), width: 2)
                    : Border.all(color: Colors.transparent, width: 2),
                boxShadow: _searchFocusNode.hasFocus 
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00E676).withOpacity(0.2),
                          blurRadius: 8,
                          spreadRadius: 0,
                        )
                      ]
                    : null,
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.search,
                onSubmitted: _onSearchSubmitted,
                onTap: () {
                  // Provide haptic feedback when search is activated
                  HapticFeedback.selectionClick();
                },
                decoration: InputDecoration(
                  hintText: 'Search songs, artists, albums...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.search,
                      key: ValueKey(_searchFocusNode.hasFocus),
                      color: _searchFocusNode.hasFocus 
                          ? const Color(0xFF00E676) 
                          : Colors.grey[400],
                    ),
                  ),
                  suffixIcon: _searchFocusNode.hasFocus || _isSearching
                      ? IconButton(
                          onPressed: _clearSearch,
                          icon: Icon(Icons.clear, color: Colors.grey[400]),
                          tooltip: 'Clear search',
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(List<Song> songs) {
    if (songs.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
              Text(
                _isSearching ? 'Search Results' : 'All Songs',
                style: const TextStyle(
                          color: Colors.white,
                  fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              Text(
                '${songs.length} songs',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
        const SizedBox(height: 16),
        
        // Songs list
        Expanded(
          child: songs.isEmpty
              ? _buildEmptySearchResults()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: songs.length,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: false,
                  cacheExtent: 500, // Performance optimization
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return SongListTile(
                      song: song,
                      onTap: () => _playSong(song),
                    );
                  },
                ),
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
                        Icons.music_note,
                        size: 80,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
            _isSearching ? 'No songs found' : 'No music found',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
            _isSearching 
                ? 'Try a different search term'
                : 'Scan your device to find music',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
        ],
      ),
    );
  }

  // New helper methods
  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      // Load songs if empty
      final songs = ref.read(songsProvider);
      if (songs.isEmpty) {
        await ref.read(songsProvider.notifier).loadSongs();
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to load initial data', e, stackTrace);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load music library';
      });
    }
  }
  
  Future<void> _refreshData() async {
    try {
      await ref.read(songsProvider.notifier).loadSongs();
      HapticFeedback.lightImpact();
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to refresh data', e, stackTrace);
    }
  }
  
  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _isSearching = value.isNotEmpty;
    });
    
    // Cancel any existing auto-dismiss timer
    _autoDismissTimer?.cancel();
    
    // If user manually clears all text, auto-dismiss search after a short delay
    if (value.isEmpty && _searchFocusNode.hasFocus) {
      _autoDismissTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted && _searchQuery.isEmpty && _searchFocusNode.hasFocus) {
          _searchFocusNode.unfocus();
          _loggingService.logInfo('Search auto-dismissed after clearing text');
        }
      });
    }
  }
  
  void _onSearchSubmitted(String value) {
    _searchFocusNode.unfocus();
    if (value.isNotEmpty) {
      _loggingService.logInfo('User searched for: $value');
    }
  }
  
  void _clearSearch() {
    _autoDismissTimer?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _isSearching = false;
    });
    _searchFocusNode.unfocus();
    HapticFeedback.selectionClick();
    
    // Log for analytics
    _loggingService.logInfo('Search cleared by user');
  }
  
  Widget _buildLoadingState() {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
            ),
            SizedBox(height: 16),
            Text(
              'Loading your music...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Unknown error occurred',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadInitialData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptySearchResults() {
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
  
  Future<void> _playSong(Song song) async {
    try {
      // Haptic feedback
      HapticFeedback.selectionClick();
      
      // Validate song file exists
      if (!song.fileExists) {
        _showErrorSnackBar('Song file not found: ${song.title}');
        return;
      }
      
      final audioHandler = ref.read(audioHandlerProvider);
      
      // Validate audio handler type
      if (audioHandler is! CustomAudioHandler) {
        _showErrorSnackBar('Audio service not available');
        return;
      }
      
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
      
      // Set this song as the only song in the queue
      await audioHandler.setQueue([mediaItem]);
      
      // Start playing from the beginning
      await audioHandler.seek(Duration.zero);
      await audioHandler.play();
      
      // Update recently played and play count
      await Future.wait([
        ref.read(storageServiceProvider).addToRecentlyPlayed(song.id),
        ref.read(storageServiceProvider).updateSongPlayCount(song.id),
      ]);
      
      _loggingService.logInfo('Started playing: ${song.title}');
      
      // Song will start playing and show in mini player
      // User can tap mini player to navigate to Now Playing screen
      _loggingService.logInfo('Song started playing from home screen: ${song.title}');
    } catch (e, stackTrace) {
      _loggingService.logError('Error playing song: ${song.title}', e, stackTrace);
      _showErrorSnackBar('Unable to play ${song.title}');
    }
  }
  
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
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
