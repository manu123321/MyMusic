import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';

class MetadataService {
  static final MetadataService _instance = MetadataService._internal();
  factory MetadataService() => _instance;
  MetadataService._internal();

  /// Scan device storage for audio files
  Future<List<Song>> scanDeviceForAudioFiles() async {
    try {
      // Check permissions first
      if (!await _checkAndRequestPermissions()) {
        print('Permissions not granted for media access');
        return [];
      }

      List<Song> songs = [];
      
      // Get common music directories
      final musicDirectories = await _getMusicDirectories();
      
      for (final directory in musicDirectories) {
        if (await directory.exists()) {
          final directorySongs = await _scanDirectory(directory);
          songs.addAll(directorySongs);
        }
      }
      
      print('Found ${songs.length} audio files');
      return songs;
    } catch (e) {
      print('Error scanning device for audio files: $e');
      return [];
    }
  }

  /// Check and request necessary permissions
  Future<bool> _checkAndRequestPermissions() async {
    // For Android 13+ (API 33+), we need READ_MEDIA_AUDIO permission
    if (Platform.isAndroid) {
      final status = await Permission.audio.request();
      if (status.isGranted) {
        return true;
      }
      
      // Fallback to storage permission for older Android versions
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    }
    
    // For iOS, we need media library access
    if (Platform.isIOS) {
      final status = await Permission.mediaLibrary.request();
      return status.isGranted;
    }
    
    return false;
  }

  /// Get common music directories on the device
  Future<List<Directory>> _getMusicDirectories() async {
    List<Directory> directories = [];
    
    if (Platform.isAndroid) {
      // Android common music directories
      final externalStorage = Directory('/storage/emulated/0');
      if (await externalStorage.exists()) {
        directories.addAll([
          Directory('/storage/emulated/0/Music'),
          Directory('/storage/emulated/0/Download'),
          Directory('/storage/emulated/0/DCIM'),
          Directory('/storage/emulated/0/Pictures'),
        ]);
      }
      
      // Also check external SD card if available
      final sdCard = Directory('/storage/sdcard1');
      if (await sdCard.exists()) {
        directories.addAll([
          Directory('/storage/sdcard1/Music'),
          Directory('/storage/sdcard1/Download'),
        ]);
      }
    } else if (Platform.isIOS) {
      // iOS music directories
      final documentsDir = await getApplicationDocumentsDirectory();
      directories.add(documentsDir);
      
      // iOS doesn't allow direct access to Music app files,
      // but we can check Documents and other accessible directories
    }
    
    return directories;
  }

  /// Recursively scan a directory for audio files
  Future<List<Song>> _scanDirectory(Directory directory) async {
    List<Song> songs = [];
    
    try {
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File && isSupportedAudioFormat(entity.path)) {
          final song = await _createSongFromFile(entity);
          if (song != null) {
            songs.add(song);
          }
        }
      }
    } catch (e) {
      print('Error scanning directory ${directory.path}: $e');
    }
    
    return songs;
  }

  /// Create a Song object from a file
  Future<Song?> _createSongFromFile(File file) async {
    try {
      final fileName = path.basename(file.path);
      
      // Extract basic metadata from filename
      final title = _extractTitleFromFileName(fileName);
      final artist = _extractArtistFromFileName(fileName);
      final album = _extractAlbumFromFileName(fileName);
      
      // Extract duration using just_audio
      int duration = 0;
      try {
        final audioPlayer = AudioPlayer();
        await audioPlayer.setFilePath(file.path);
        final durationObj = audioPlayer.duration;
        if (durationObj != null) {
          duration = durationObj.inMilliseconds;
        }
        await audioPlayer.dispose();
      } catch (e) {
        print('Error extracting duration from ${file.path}: $e');
      }
      
      final song = Song(
        id: file.path.hashCode.toString(), // Use file path hash as unique ID
        title: title,
        artist: artist,
        album: album,
        filePath: file.path,
        duration: duration,
        dateAdded: DateTime.now(),
        playCount: 0,
        isLiked: false,
      );
      
      return song;
    } catch (e) {
      print('Error creating song from file ${file.path}: $e');
      return null;
    }
  }

  /// Extract artist from filename
  String _extractArtistFromFileName(String fileName) {
    final nameWithoutExt = path.basenameWithoutExtension(fileName);
    
    // Common patterns: "Artist - Song", "Artist_Song", "Artist.Song"
    if (nameWithoutExt.contains(' - ')) {
      return nameWithoutExt.split(' - ')[0].trim();
    } else if (nameWithoutExt.contains('_')) {
      final parts = nameWithoutExt.split('_');
      if (parts.length >= 2) {
        return parts[0].trim();
      }
    } else if (nameWithoutExt.contains('.')) {
      final parts = nameWithoutExt.split('.');
      if (parts.length >= 2) {
        return parts[0].trim();
      }
    }
    
    return 'Unknown Artist';
  }

  /// Extract album from filename
  String _extractAlbumFromFileName(String fileName) {
    final nameWithoutExt = path.basenameWithoutExtension(fileName);
    
    // Try to extract album from directory structure
    final directory = path.dirname(fileName);
    final dirName = path.basename(directory);
    
    // If directory name looks like an album name, use it
    if (dirName.isNotEmpty && dirName != 'Music' && dirName != 'Download') {
      return dirName.replaceAll('_', ' ').replaceAll('-', ' ');
    }
    
    return 'Unknown Album';
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
            // Extract duration using just_audio
            int duration = 0;
            try {
              final audioPlayer = AudioPlayer();
              await audioPlayer.setFilePath(file.path!);
              final durationObj = audioPlayer.duration;
              if (durationObj != null) {
                duration = durationObj.inMilliseconds;
              }
              await audioPlayer.dispose();
            } catch (e) {
              print('Error extracting duration from ${file.path}: $e');
            }
            
            final song = Song(
              id: file.path!.hashCode.toString(), // Use file path hash as unique ID
              title: _extractTitleFromFileName(file.name),
              artist: 'Unknown Artist',
              album: 'Unknown Album',
              filePath: file.path!,
              duration: duration,
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
