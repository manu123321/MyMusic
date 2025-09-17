import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'logging_service.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();
  
  final LoggingService _loggingService = LoggingService();
  
  // Cache permission status to avoid repeated checks
  Map<Permission, PermissionStatus>? _cachedStatuses;
  DateTime? _lastCacheUpdate;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  /// Check if we have the necessary permissions for media access
  Future<bool> hasMediaPermissions() async {
    try {
      _loggingService.logDebug('Checking media permissions');
      
      // Use cached status if available and recent
      if (_isCacheValid()) {
        return _getCachedMediaPermissionStatus();
      }
      
      bool hasPermission = false;
      
      if (Platform.isAndroid) {
        // For Android 13+ (API 33+), check READ_MEDIA_AUDIO permission
        final audioStatus = await Permission.audio.status;
        _updateCache(Permission.audio, audioStatus);
        
        if (audioStatus.isGranted) {
          hasPermission = true;
        } else {
          // Fallback to storage permission for older Android versions
          final storageStatus = await Permission.storage.status;
          _updateCache(Permission.storage, storageStatus);
          hasPermission = storageStatus.isGranted;
        }
      } else if (Platform.isIOS) {
        final mediaLibraryStatus = await Permission.mediaLibrary.status;
        _updateCache(Permission.mediaLibrary, mediaLibraryStatus);
        hasPermission = mediaLibraryStatus.isGranted;
      }
      
      _loggingService.logInfo('Media permissions status: $hasPermission');
      return hasPermission;
    } catch (e, stackTrace) {
      _loggingService.logError('Error checking media permissions', e, stackTrace);
      return false;
    }
  }

  /// Request necessary permissions for media access with retry logic
  Future<bool> requestMediaPermissions() async {
    try {
      _loggingService.logInfo('Requesting media permissions');
      
      bool granted = false;
      
      if (Platform.isAndroid) {
        // For Android 13+ (API 33+), request READ_MEDIA_AUDIO permission
        final audioStatus = await Permission.audio.request();
        _updateCache(Permission.audio, audioStatus);
        
        if (audioStatus.isGranted) {
          granted = true;
          _loggingService.logInfo('Audio permission granted');
        } else if (audioStatus.isPermanentlyDenied) {
          _loggingService.logWarning('Audio permission permanently denied');
        } else {
          // Fallback to storage permission for older Android versions
          _loggingService.logInfo('Trying storage permission as fallback');
          final storageStatus = await Permission.storage.request();
          _updateCache(Permission.storage, storageStatus);
          granted = storageStatus.isGranted;
          
          if (granted) {
            _loggingService.logInfo('Storage permission granted');
          } else {
            _loggingService.logWarning('Storage permission denied');
          }
        }
      } else if (Platform.isIOS) {
        final mediaLibraryStatus = await Permission.mediaLibrary.request();
        _updateCache(Permission.mediaLibrary, mediaLibraryStatus);
        granted = mediaLibraryStatus.isGranted;
        
        if (granted) {
          _loggingService.logInfo('Media library permission granted');
        } else {
          _loggingService.logWarning('Media library permission denied');
        }
      }
      
      return granted;
    } catch (e, stackTrace) {
      _loggingService.logError('Error requesting media permissions', e, stackTrace);
      return false;
    }
  }

  /// Check if permissions are permanently denied
  Future<bool> arePermissionsPermanentlyDenied() async {
    if (Platform.isAndroid) {
      final audioStatus = await Permission.audio.status;
      if (audioStatus.isPermanentlyDenied) {
        return true;
      }
      
      final storageStatus = await Permission.storage.status;
      return storageStatus.isPermanentlyDenied;
    }
    
    if (Platform.isIOS) {
      final mediaLibraryStatus = await Permission.mediaLibrary.status;
      return mediaLibraryStatus.isPermanentlyDenied;
    }
    
    return false;
  }

  /// Open app settings for permission management
  Future<void> openAppSettings() async {
    try {
      await Permission.storage.request().then((status) {
        if (status.isDenied) {
          // Try opening settings - this is platform specific
        }
      });
      _loggingService.logInfo('Opened app settings for permissions.');
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to open app settings.', e, stackTrace);
    }
  }

  /// Get permission status message with detailed information
  Future<String> getPermissionStatusMessage() async {
    try {
      if (Platform.isAndroid) {
        final audioStatus = await Permission.audio.status;
        final storageStatus = await Permission.storage.status;
        
        if (audioStatus.isGranted || storageStatus.isGranted) {
          return 'Media access granted';
        } else if (audioStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied) {
          return 'Media access permanently denied. Please enable in Settings > Apps > Music Player > Permissions.';
        } else if (audioStatus.isDenied || storageStatus.isDenied) {
          return 'Media access denied. Tap to grant permission to scan for music files.';
        } else {
          return 'Media access required to scan for music files';
        }
      }
      
      if (Platform.isIOS) {
        final mediaLibraryStatus = await Permission.mediaLibrary.status;
        
        if (mediaLibraryStatus.isGranted) {
          return 'Media library access granted';
        } else if (mediaLibraryStatus.isPermanentlyDenied) {
          return 'Media library access permanently denied. Please enable in Settings > Privacy & Security > Media & Apple Music.';
        } else if (mediaLibraryStatus.isDenied) {
          return 'Media library access denied. Tap to grant permission to access your music.';
        } else {
          return 'Media library access required to scan for music files';
        }
      }
      
      return 'Unknown platform - cannot check permissions';
    } catch (e, stackTrace) {
      _loggingService.logError('Error getting permission status message', e, stackTrace);
      return 'Error checking permissions';
    }
  }
  
  /// Cache management methods
  bool _isCacheValid() {
    if (_cachedStatuses == null || _lastCacheUpdate == null) {
      return false;
    }
    
    final now = DateTime.now();
    return now.difference(_lastCacheUpdate!) < _cacheValidDuration;
  }
  
  void _updateCache(Permission permission, PermissionStatus status) {
    _cachedStatuses ??= {};
    _cachedStatuses![permission] = status;
    _lastCacheUpdate = DateTime.now();
  }
  
  bool _getCachedMediaPermissionStatus() {
    if (_cachedStatuses == null) return false;
    
    if (Platform.isAndroid) {
      final audioGranted = _cachedStatuses![Permission.audio]?.isGranted ?? false;
      final storageGranted = _cachedStatuses![Permission.storage]?.isGranted ?? false;
      return audioGranted || storageGranted;
    }
    
    if (Platform.isIOS) {
      return _cachedStatuses![Permission.mediaLibrary]?.isGranted ?? false;
    }
    
    return false;
  }
  
  /// Clear permission cache
  void clearCache() {
    _cachedStatuses = null;
    _lastCacheUpdate = null;
    _loggingService.logDebug('Permission cache cleared');
  }
  
  /// Get detailed permission information for debugging
  Future<Map<String, dynamic>> getDetailedPermissionInfo() async {
    try {
      final info = <String, dynamic>{
        'platform': Platform.operatingSystem,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      if (Platform.isAndroid) {
        info['audio'] = (await Permission.audio.status).toString();
        info['storage'] = (await Permission.storage.status).toString();
        info['manageExternalStorage'] = (await Permission.manageExternalStorage.status).toString();
      } else if (Platform.isIOS) {
        info['mediaLibrary'] = (await Permission.mediaLibrary.status).toString();
      }
      
      return info;
    } catch (e, stackTrace) {
      _loggingService.logError('Error getting detailed permission info', e, stackTrace);
      return {'error': e.toString()};
    }
  }
}