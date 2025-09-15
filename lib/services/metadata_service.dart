import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/song.dart';

class MetadataService {
  static final MetadataService _instance = MetadataService._internal();
  factory MetadataService() => _instance;
  MetadataService._internal();

  /// Scan device storage for audio files using file picker
  Future<List<Song>> scanDeviceForAudioFiles() async {
    try {
      // For now, return empty list - user will need to manually select files
      // This is a simplified approach to avoid complex permission and metadata issues
      print('Audio file scanning is simplified - use file picker to add music');
      return [];
    } catch (e) {
      print('Error scanning device for audio files: $e');
      return [];
    }
  }

  /// Pick audio files using file picker
  Future<List<Song>> pickAudioFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );

      if (result != null) {
        List<Song> songs = [];
        
        for (PlatformFile file in result.files) {
          if (file.path != null && isSupportedAudioFormat(file.path!)) {
            final song = Song(
              id: DateTime.now().millisecondsSinceEpoch.toString() + '_${file.name}',
              title: _extractTitleFromFileName(file.name),
              artist: 'Unknown Artist',
              album: 'Unknown Album',
              filePath: file.path!,
              duration: 0, // Will be determined when playing
              dateAdded: DateTime.now(),
              playCount: 0,
              isLiked: false,
            );
            songs.add(song);
          }
        }
        
        return songs;
      }
      
      return [];
    } catch (e) {
      print('Error picking audio files: $e');
      return [];
    }
  }

  /// Extract title from filename
  String _extractTitleFromFileName(String fileName) {
    // Remove extension and clean up the name
    String name = path.basenameWithoutExtension(fileName);
    // Replace underscores and hyphens with spaces
    name = name.replaceAll('_', ' ').replaceAll('-', ' ');
    // Capitalize first letter of each word
    return name.split(' ').map((word) => 
      word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : ''
    ).join(' ');
  }

  /// Extract basic metadata from audio file
  Future<Map<String, dynamic>> _extractBasicMetadata(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return {};
      }

      // Basic file information
      final stat = await file.stat();
      
      return {
        'fileSize': stat.size,
        'lastModified': stat.modified,
      };
    } catch (e) {
      print('Error extracting basic metadata from $filePath: $e');
      return {};
    }
  }

  /// Save album art to app storage and return the path
  Future<String?> _saveAlbumArt(int songId, Uint8List? albumArtBytes) async {
    if (albumArtBytes == null || albumArtBytes.isEmpty) {
      return null;
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final artworkDir = Directory(path.join(appDir.path, 'artwork'));
      
      if (!await artworkDir.exists()) {
        await artworkDir.create(recursive: true);
      }

      final artworkPath = path.join(artworkDir.path, '${songId}_artwork.jpg');
      final artworkFile = File(artworkPath);
      
      await artworkFile.writeAsBytes(albumArtBytes);
      return artworkPath;
    } catch (e) {
      print('Error saving album art: $e');
      return null;
    }
  }

  /// Get album art for a song
  Future<Uint8List?> getAlbumArt(String songId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final artworkPath = path.join(appDir.path, 'artwork', '${songId}_artwork.jpg');
      final artworkFile = File(artworkPath);
      
      if (await artworkFile.exists()) {
        return await artworkFile.readAsBytes();
      }
    } catch (e) {
      print('Error reading album art: $e');
    }
    return null;
  }

  /// Extract metadata from a specific file
  Future<Map<String, dynamic>> extractMetadataFromFile(String filePath) async {
    return await _extractBasicMetadata(filePath);
  }

  /// Check if file is a supported audio format
  bool isSupportedAudioFormat(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return [
      '.mp3', '.aac', '.m4a', '.wav', '.flac', '.ogg', '.wma', '.aiff'
    ].contains(extension);
  }

  /// Get file size in bytes
  Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (e) {
      print('Error getting file size: $e');
    }
    return 0;
  }

  /// Format file size for display
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Format duration for display
  String formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }
}
