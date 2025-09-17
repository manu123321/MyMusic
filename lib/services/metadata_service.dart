import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
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

  /// Scan device storage for audio files with professional metadata extraction
  Future<List<Song>> scanDeviceForAudioFiles() async {
    try {
      _loggingService.logInfo('Starting professional device scan for audio files');
      
      // Check permissions first
      if (!await _checkAndRequestPermissions()) {
        _loggingService.logWarning('Permissions not granted for media access');
        return [];
      }

      List<Song> songs = [];
      
      // Get common music directories
      final musicDirectories = await _getMusicDirectories();
      _loggingService.logInfo('Scanning ${musicDirectories.length} directories');
      
      for (final directory in musicDirectories) {
        if (await directory.exists()) {
          try {
            final directorySongs = await _scanDirectoryWithMetadata(directory);
            songs.addAll(directorySongs);
            _loggingService.logDebug('Found ${directorySongs.length} songs in ${directory.path}');
          } catch (e, stackTrace) {
            _loggingService.logError('Error scanning directory ${directory.path}', e, stackTrace);
            // Continue with other directories
          }
        }
      }
      
      _loggingService.logInfo('Scan completed: found ${songs.length} audio files with complete metadata');
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

  /// Recursively scan a directory for audio files (legacy method, now unused)
  Future<List<Song>> _scanDirectory(Directory directory) async {
    // This method is now unused as we use on_audio_query directly
    return [];
  }

  /// Scan directory with professional metadata extraction
  Future<List<Song>> _scanDirectoryWithMetadata(Directory directory) async {
    List<Song> songs = [];
    
    try {
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File && isSupportedAudioFormat(entity.path)) {
          final song = await _createSongFromFileWithMetadata(entity);
          if (song != null) {
            songs.add(song);
          }
        }
      }
    } catch (e) {
      _loggingService.logWarning('Error scanning directory ${directory.path}: $e');
    }
    
    return songs;
  }

  /// Create Song object with professional metadata extraction
  Future<Song?> _createSongFromFileWithMetadata(File file) async {
    try {
      final filePath = file.path;
      
      // Check cache first
      if (_metadataCache.containsKey(filePath)) {
        final cachedData = _metadataCache[filePath]!;
        return _createSongFromCachedFileData(file, cachedData);
      }
      
      // Validate file
      if (!await _validateAudioFile(file)) {
        return null;
      }
      
      final fileName = path.basename(filePath);
      
      // Default to filename-based extraction
      String title = _extractTitleFromFileName(fileName);
      String artist = _extractArtistFromFileName(fileName);
      String album = _extractAlbumFromFileName(filePath);
      
      // Get file stats
      final fileStat = await file.stat();
      final fileSize = fileStat.size;
      
      // Extract metadata using audio_metadata_reader
      int duration = 0;
      int bitrate = 0;
      Uint8List? albumArtBytes;
      String? genre;
      int? trackNumber;
      int? year;
      String? albumArtist;
      String? composer;
      
      try {
        final metadata = readMetadata(file, getImage: true);
        
        // Use embedded metadata if available
        if (metadata.title != null && metadata.title!.isNotEmpty) {
          title = metadata.title!;
        }
        
        if (metadata.artist != null && metadata.artist!.isNotEmpty) {
          artist = metadata.artist!;
        }
        
        if (metadata.album != null && metadata.album!.isNotEmpty) {
          album = metadata.album!;
        }
        
        if (metadata.duration != null) {
          duration = metadata.duration!.inMilliseconds; // Duration is already a Duration object
        }
        
        // Extract additional metadata (using available fields)
        trackNumber = metadata.trackNumber;
        year = metadata.year?.year; // Convert DateTime to year
        
        // Extract album art
        if (metadata.pictures != null && metadata.pictures!.isNotEmpty) {
          albumArtBytes = metadata.pictures!.first.bytes;
        }
        
        _loggingService.logDebug('Successfully extracted metadata from $filePath: $title by $artist');
      } catch (e) {
        _loggingService.logWarning('Error extracting metadata from $filePath: $e');
        
        // Fallback to just_audio for duration if needed
        try {
          await _ensureAudioPlayerInitialized();
          await _audioPlayer!.setFilePath(filePath);
          final durationObj = _audioPlayer!.duration;
          if (durationObj != null) {
            duration = durationObj.inMilliseconds;
          }
        } catch (e) {
          _loggingService.logDebug('Fallback duration extraction failed for $filePath: $e');
        }
      }
      
      // Calculate bitrate if possible
      if (duration > 0 && fileSize > 0) {
        bitrate = ((fileSize * 8) / (duration / 1000) / 1000).round();
      }
      
      // Create metadata cache entry
      final metadataCacheEntry = {
        'title': title,
        'artist': artist,
        'album': album,
        'duration': duration,
        'fileSize': fileSize,
        'bitrate': bitrate,
        'genre': genre,
        'trackNumber': trackNumber,
        'year': year,
        'albumArtist': albumArtist,
        'composer': composer,
        'lastModified': fileStat.modified.millisecondsSinceEpoch,
      };
      _metadataCache[filePath] = metadataCacheEntry;
      
      // Save album art if available
      final songId = filePath.hashCode.toString();
      String? artworkPath;
      if (albumArtBytes != null && albumArtBytes.isNotEmpty) {
        artworkPath = await _saveAlbumArt(songId, albumArtBytes);
        _loggingService.logDebug('Saved album art for $title');
      }
      
      final song = Song(
        id: songId,
        title: title,
        artist: artist,
        album: album,
        filePath: filePath,
        duration: duration,
        fileSize: fileSize,
        bitrate: bitrate,
        albumArtPath: artworkPath,
        trackNumber: trackNumber,
        year: year,
        genre: genre,
        albumArtist: albumArtist,
        composer: composer,
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
              final song = await _createSongFromFileWithMetadata(file);
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
  Future<String?> _saveAlbumArt(String songId, Uint8List? albumArtBytes) async {
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
  
  Song _createSongFromCachedFileData(File file, Map<String, dynamic> cachedData) {
    // Check if album art exists for this song
    final songId = file.path.hashCode.toString();
    String? artworkPath = cachedData['artworkPath'];
    
    // Verify artwork file still exists
    if (artworkPath != null) {
      final artworkFile = File(artworkPath);
      if (!artworkFile.existsSync()) {
        artworkPath = null;
      }
    }
    
    return Song(
      id: songId,
      title: cachedData['title'] ?? 'Unknown Title',
      artist: cachedData['artist'] ?? 'Unknown Artist',
      album: cachedData['album'] ?? 'Unknown Album',
      filePath: file.path,
      duration: cachedData['duration'] ?? 0,
      fileSize: cachedData['fileSize'] ?? 0,
      bitrate: cachedData['bitrate'] ?? 0,
      albumArtPath: artworkPath,
      trackNumber: cachedData['trackNumber'],
      year: cachedData['year'],
      genre: cachedData['genre'],
      albumArtist: cachedData['albumArtist'],
      composer: cachedData['composer'],
      dateAdded: DateTime.now(),
      playCount: 0,
    );
  }
  
  /// Batch process files for better performance (legacy method, now unused)
  Future<List<Song>> _processBatchFiles(List<File> files) async {
    // This method is now unused as we use on_audio_query directly
    return [];
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
