import 'dart:io';
import 'package:flutter/material.dart';
import '../models/song.dart';

class CompositeAlbumArt extends StatelessWidget {
  final List<Song> songs;
  final double size;
  final double borderRadius;

  const CompositeAlbumArt({
    super.key,
    required this.songs,
    this.size = 120,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: _buildCompositeArt(),
      ),
    );
  }

  Widget _buildCompositeArt() {
    // Get unique album arts from first 4 songs
    final albumArts = _getUniqueAlbumArts();
    
    if (albumArts.isEmpty) {
      // No album arts available - show default playlist icon
      return _buildDefaultPlaylistIcon();
    } else if (albumArts.length == 1) {
      // Single album art - show it full size
      return _buildSingleAlbumArt(albumArts.first);
    } else {
      // Multiple album arts - show in grid (works for all sizes, including small ones)
      return _buildGridAlbumArt(albumArts);
    }
  }

  List<String?> _getUniqueAlbumArts() {
    final Set<String> seen = {};
    final List<String?> uniqueArts = [];
    
    for (final song in songs.take(4)) {
      if (song.albumArtPath != null) {
        final artPath = song.albumArtPath!;
        if (!seen.contains(artPath)) {
          seen.add(artPath);
          uniqueArts.add(artPath);
          if (uniqueArts.length >= 4) break;
        }
      }
    }
    
    return uniqueArts;
  }

  Widget _buildDefaultPlaylistIcon() {
    return Container(
      color: Colors.grey[800],
      child: Icon(
        Icons.playlist_play,
        color: Colors.white,
        size: size * 0.4,
      ),
    );
  }

  Widget _buildSingleAlbumArt(String? albumArtPath) {
    if (albumArtPath == null) {
      return _buildDefaultPlaylistIcon();
    }
    
    return Image.file(
      File(albumArtPath),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return _buildDefaultPlaylistIcon();
      },
    );
  }

  Widget _buildGridAlbumArt(List<String?> albumArts) {
    // Pad with nulls if we have fewer than 4 images
    while (albumArts.length < 4) {
      albumArts.add(null);
    }

    // Adjust spacing based on size - smaller spacing for smaller widgets
    final spacing = size <= 60 ? 0.5 : 1.0;

    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      physics: const NeverScrollableScrollPhysics(),
      children: albumArts.take(4).map((artPath) {
        return _buildGridItem(artPath);
      }).toList(),
    );
  }

  Widget _buildGridItem(String? albumArtPath) {
    if (albumArtPath != null) {
      return Image.file(
        File(albumArtPath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultGridItem();
        },
      );
    } else {
      return _buildDefaultGridItem();
    }
  }

  Widget _buildDefaultGridItem() {
    // Adjust icon size based on overall widget size
    final iconSize = size <= 60 ? size * 0.2 : size * 0.15;
    
    return Container(
      color: Colors.grey[800],
      child: Icon(
        Icons.music_note_rounded,
        color: Colors.white,
        size: iconSize,
      ),
    );
  }
}
