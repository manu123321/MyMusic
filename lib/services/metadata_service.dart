import 'dart:io';
import 'dart:typed_data';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import 'logging_service.dart';

class MetadataService {
  static final MetadataService _instance = MetadataService._internal();
  factory MetadataService() => _instance;
  MetadataService._internal();
  
  final LoggingService _loggingService = LoggingService();
  
  // Reusable AudioPlayer instance to avoid memory leaks
  AudioPlayer? _audioPlayer;
  
  // Cache for file metadata to avoid repeated operations
  final Map<String, Map<String, dynamic>> _metadataCache = {};
  
  // Supported audio formats
  static const List<String> _supportedFormats = [
    '.mp3', '.aac', '.m4a', '.wav', '.flac', '.ogg', '.wma', '.aiff', '.opus'
  ];

  /// Scan device storage for audio files with optimized performance
  Future<List<Song>> scanDeviceForAudioFiles() async {
    try {
      _loggingService.logInfo('Starting device scan for audio files');
      
      // Check permissions first
      if (!await _checkAndRequestPermissions()) {
        _loggingService.logWarning('Permissions not granted for media access');
        return [];
      }

      // Initialize audio player if needed
      await _ensureAudioPlayerInitialized();
      
      List<Song> songs = [];
      
      // Get common music directories
      final musicDirectories = await _getMusicDirectories();
      _loggingService.logInfo('Scanning ${musicDirectories.length} directories');
      
      for (final directory in musicDirectories) {
        if (await directory.exists()) {
          try {
            final directorySongs = await _scanDirectory(directory);
            songs.addAll(directorySongs);
            _loggingService.logDebug('Found ${directorySongs.length} songs in ${directory.path}');
          } catch (e, stackTrace) {
            _loggingService.logError('Error scanning directory ${directory.path}', e, stackTrace);
            // Continue with other directories
          }
        }
      }
      
      _loggingService.logInfo('Scan completed: found ${songs.length} audio files');
      return songs;
    } catch (e, stackTrace) {
      _loggingService.logError('Error scanning device for audio files', e, stackTrace);
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

  /// Create a Song object from a file with enhanced metadata extraction
  Future<Song?> _createSongFromFile(File file) async {
    try {
      final filePath = file.path;
      
      // Check cache first
      if (_metadataCache.containsKey(filePath)) {
        final cachedData = _metadataCache[filePath]!;
        return _createSongFromCachedData(file, cachedData);
      }
      
      // Validate file
      if (!await _validateAudioFile(file)) {
        return null;
      }
      
      final fileName = path.basename(filePath);
      
      // Extract basic metadata from filename
      final title = _extractTitleFromFileName(fileName);
      final artist = _extractArtistFromFileName(fileName);
      final album = _extractAlbumFromFileName(fileName);
      
      // Get file stats
      final fileStat = await file.stat();
      final fileSize = fileStat.size;
      
      // Extract duration using reusable audio player
      int duration = 0;
      int bitrate = 0;
      
      try {
        await _ensureAudioPlayerInitialized();
        await _audioPlayer!.setFilePath(filePath);
        
        final durationObj = _audioPlayer!.duration;
        if (durationObj != null) {
          duration = durationObj.inMilliseconds;
          
          // Estimate bitrate
          if (duration > 0) {
            bitrate = ((fileSize * 8) / (duration / 1000) / 1000).round();
          }
        }
        
        // Don't dispose here - reuse for next file
      } catch (e, stackTrace) {
        _loggingService.logWarning('Error extracting duration from $filePath', e);
      }
      
      // Create metadata cache entry
      final metadata = {
        'title': title,
        'artist': artist,
        'album': album,
        'duration': duration,
        'fileSize': fileSize,
        'bitrate': bitrate,
        'lastModified': fileStat.modified.millisecondsSinceEpoch,
      };
      _metadataCache[filePath] = metadata;
      
      final song = Song(
        id: filePath.hashCode.toString(),
        title: title,
        artist: artist,
        album: album,
        filePath: filePath,
        duration: duration,
        fileSize: fileSize,
        bitrate: bitrate,
        dateAdded: DateTime.now(),
        playCount: 0,
      );
      
      return song;
    } catch (e, stackTrace) {
      _loggingService.logError('Error creating song from file ${file.path}', e, stackTrace);
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

  /// Pick audio files using file picker with enhanced processing
  Future<List<Song>> pickAudioFiles() async {
    try {
      _loggingService.logInfo('Starting file picker for audio files');
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
        allowCompression: false,
      );

      if (result != null && result.files.isNotEmpty) {
        _loggingService.logInfo('User selected ${result.files.length} files');
        
        List<Song> songs = [];
        await _ensureAudioPlayerInitialized();
        
        for (PlatformFile platformFile in result.files) {
          if (platformFile.path != null && isSupportedAudioFormat(platformFile.path!)) {
            try {
              final file = File(platformFile.path!);
              final song = await _createSongFromFile(file);
              if (song != null) {
                songs.add(song);
              }
            } catch (e, stackTrace) {
              _loggingService.logError('Error processing picked file ${platformFile.path}', e, stackTrace);
              // Continue with other files
            }
          } else {
            _loggingService.logWarning('Unsupported file format: ${platformFile.path}');
          }
        }
        
        _loggingService.logInfo('Successfully processed ${songs.length} audio files');
        return songs;
      }
      
      _loggingService.logInfo('File picker cancelled by user');
      return [];
    } catch (e, stackTrace) {
      _loggingService.logError('Error picking audio files', e, stackTrace);
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
    return _supportedFormats.contains(extension);
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
  
  /// Helper methods for optimization
  Future<void> _ensureAudioPlayerInitialized() async {
    if (_audioPlayer == null) {
      _audioPlayer = AudioPlayer();
      _loggingService.logDebug('Initialized reusable AudioPlayer');
    }
  }
  
  Future<bool> _validateAudioFile(File file) async {
    try {
      // Check if file exists
      if (!await file.exists()) {
        _loggingService.logWarning('File does not exist: ${file.path}');
        return false;
      }
      
      // Check file size (minimum 1KB, maximum 500MB)
      final fileSize = await file.length();
      if (fileSize < 1024) {
        _loggingService.logWarning('File too small: ${file.path} (${fileSize} bytes)');
        return false;
      }
      
      if (fileSize > 500 * 1024 * 1024) {
        _loggingService.logWarning('File too large: ${file.path} (${formatFileSize(fileSize)})');
        return false;
      }
      
      // Check if file is readable
      try {
        await file.openRead(0, 1024).drain();
      } catch (e) {
        _loggingService.logWarning('File not readable: ${file.path}');
        return false;
      }
      
      return true;
    } catch (e, stackTrace) {
      _loggingService.logError('Error validating audio file: ${file.path}', e, stackTrace);
      return false;
    }
  }
  
  Song _createSongFromCachedData(File file, Map<String, dynamic> cachedData) {
    return Song(
      id: file.path.hashCode.toString(),
      title: cachedData['title'] ?? 'Unknown Title',
      artist: cachedData['artist'] ?? 'Unknown Artist',
      album: cachedData['album'] ?? 'Unknown Album',
      filePath: file.path,
      duration: cachedData['duration'] ?? 0,
      fileSize: cachedData['fileSize'] ?? 0,
      bitrate: cachedData['bitrate'] ?? 0,
      dateAdded: DateTime.now(),
      playCount: 0,
    );
  }
  
  /// Batch process files for better performance
  Future<List<Song>> _processBatchFiles(List<File> files) async {
    const batchSize = 20;
    final List<Song> allSongs = [];
    
    for (int i = 0; i < files.length; i += batchSize) {
      final batch = files.skip(i).take(batchSize);
      final batchSongs = await Future.wait(
        batch.map((file) => _createSongFromFile(file)),
      );
      
      allSongs.addAll(batchSongs.whereType<Song>());
      
      // Small delay to prevent blocking UI
      if (i + batchSize < files.length) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }
    
    return allSongs;
  }
  
  /// Clear metadata cache
  void clearCache() {
    _metadataCache.clear();
    _loggingService.logInfo('Metadata cache cleared');
  }
  
  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cacheSize': _metadataCache.length,
      'memoryUsage': _metadataCache.length * 500, // Rough estimate
    };
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    try {
      await _audioPlayer?.dispose();
      _audioPlayer = null;
      _metadataCache.clear();
      _loggingService.logInfo('MetadataService disposed');
    } catch (e, stackTrace) {
      _loggingService.logError('Error disposing MetadataService', e, stackTrace);
    }
  }
}
