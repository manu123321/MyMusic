import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Check if we have the necessary permissions for media access
  Future<bool> hasMediaPermissions() async {
    if (Platform.isAndroid) {
      // For Android 13+ (API 33+), check READ_MEDIA_AUDIO permission
      final audioStatus = await Permission.audio.status;
      if (audioStatus.isGranted) {
        return true;
      }
      
      // Fallback to storage permission for older Android versions
      final storageStatus = await Permission.storage.status;
      return storageStatus.isGranted;
    }
    
    if (Platform.isIOS) {
      final mediaLibraryStatus = await Permission.mediaLibrary.status;
      return mediaLibraryStatus.isGranted;
    }
    
    return false;
  }

  /// Request necessary permissions for media access
  Future<bool> requestMediaPermissions() async {
    if (Platform.isAndroid) {
      // For Android 13+ (API 33+), request READ_MEDIA_AUDIO permission
      final audioStatus = await Permission.audio.request();
      if (audioStatus.isGranted) {
        return true;
      }
      
      // Fallback to storage permission for older Android versions
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    }
    
    if (Platform.isIOS) {
      final mediaLibraryStatus = await Permission.mediaLibrary.request();
      return mediaLibraryStatus.isGranted;
    }
    
    return false;
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
    await openAppSettings();
  }

  /// Get permission status message
  Future<String> getPermissionStatusMessage() async {
    if (Platform.isAndroid) {
      final audioStatus = await Permission.audio.status;
      final storageStatus = await Permission.storage.status;
      
      if (audioStatus.isGranted || storageStatus.isGranted) {
        return 'Media access granted';
      } else if (audioStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied) {
        return 'Media access permanently denied. Please enable in settings.';
      } else {
        return 'Media access required to scan for music files';
      }
    }
    
    if (Platform.isIOS) {
      final mediaLibraryStatus = await Permission.mediaLibrary.status;
      
      if (mediaLibraryStatus.isGranted) {
        return 'Media library access granted';
      } else if (mediaLibraryStatus.isPermanentlyDenied) {
        return 'Media library access permanently denied. Please enable in settings.';
      } else {
        return 'Media library access required to scan for music files';
      }
    }
    
    return 'Unknown platform';
  }
}