import 'dart:async';
import 'package:audio_service/audio_service.dart';
import '../models/song.dart';
import 'logging_service.dart';
import 'custom_audio_handler.dart';

/// Helper class for testing system-wide media controls functionality
class MediaControlsTestHelper {
  final LoggingService _loggingService = LoggingService();
  
  /// Test the notification panel media controls
  Future<bool> testNotificationControls(CustomAudioHandler audioHandler) async {
    _loggingService.logInfo('Testing notification panel media controls...');
    
    try {
      // Create a test song
      final testSong = Song(
        id: 'test_001',
        title: 'Test Song for Media Controls',
        artist: 'Test Artist',
        album: 'Test Album',
        filePath: 'assets/audio/MONEY.mp3', // Using your existing test file
        duration: 180000, // 3 minutes
        dateAdded: DateTime.now(),
        playCount: 0,
        isFavorite: false,
      );
      
      // Create media item and set queue
      final mediaItem = MediaItem(
        id: testSong.filePath,
        title: testSong.title,
        artist: testSong.artist,
        album: testSong.album,
        duration: Duration(milliseconds: testSong.duration),
      );
      
      // Test queue setup
      await audioHandler.setQueue([mediaItem]);
      _loggingService.logInfo('✓ Queue set successfully');
      
      // Test play functionality
      await audioHandler.play();
      await Future.delayed(const Duration(seconds: 2));
      _loggingService.logInfo('✓ Play command executed');
      
      // Test pause functionality
      await audioHandler.pause();
      await Future.delayed(const Duration(seconds: 1));
      _loggingService.logInfo('✓ Pause command executed');
      
      // Test skip next (should handle gracefully even with single song)
      await audioHandler.skipToNext();
      await Future.delayed(const Duration(seconds: 1));
      _loggingService.logInfo('✓ Skip next command executed');
      
      // Test skip previous
      await audioHandler.skipToPrevious();
      await Future.delayed(const Duration(seconds: 1));
      _loggingService.logInfo('✓ Skip previous command executed');
      
      _loggingService.logInfo('✅ Notification controls test completed successfully');
      return true;
      
    } catch (e, stackTrace) {
      _loggingService.logError('❌ Notification controls test failed', e, stackTrace);
      return false;
    }
  }
  
  /// Test lock screen media controls
  Future<bool> testLockScreenControls(CustomAudioHandler audioHandler) async {
    _loggingService.logInfo('Testing lock screen media controls...');
    
    try {
      // Verify media metadata is properly set
      final mediaItem = audioHandler.mediaItem.value;
      if (mediaItem == null) {
        _loggingService.logError('❌ No media item available for lock screen', null, null);
        return false;
      }
      
      _loggingService.logInfo('✓ Media metadata available: ${mediaItem.title}');
      
      // Test playback state updates
      final playbackState = audioHandler.playbackState.value;
      _loggingService.logInfo('✓ Playback state available: playing=${playbackState.playing}');
      
      // Test that controls are properly configured
      final controls = playbackState.controls;
      if (controls.isEmpty) {
        _loggingService.logError('❌ No media controls configured', null, null);
        return false;
      }
      
      _loggingService.logInfo('✓ Media controls configured: ${controls.length} controls');
      
      // Verify system actions are available
      final systemActions = playbackState.systemActions;
      if (systemActions.isEmpty) {
        _loggingService.logError('❌ No system actions configured', null, null);
        return false;
      }
      
      _loggingService.logInfo('✓ System actions configured: ${systemActions.length} actions');
      
      _loggingService.logInfo('✅ Lock screen controls test completed successfully');
      return true;
      
    } catch (e, stackTrace) {
      _loggingService.logError('❌ Lock screen controls test failed', e, stackTrace);
      return false;
    }
  }
  
  /// Test hardware media button handling
  Future<bool> testHardwareButtons(CustomAudioHandler audioHandler) async {
    _loggingService.logInfo('Testing hardware media button handling...');
    
    try {
      // Test custom actions for media buttons
      await audioHandler.customAction('MEDIA_BUTTON_PLAY_PAUSE');
      await Future.delayed(const Duration(milliseconds: 500));
      _loggingService.logInfo('✓ Play/Pause button simulation executed');
      
      await audioHandler.customAction('MEDIA_BUTTON_NEXT');
      await Future.delayed(const Duration(milliseconds: 500));
      _loggingService.logInfo('✓ Next button simulation executed');
      
      await audioHandler.customAction('MEDIA_BUTTON_PREVIOUS');
      await Future.delayed(const Duration(milliseconds: 500));
      _loggingService.logInfo('✓ Previous button simulation executed');
      
      _loggingService.logInfo('✅ Hardware button test completed successfully');
      return true;
      
    } catch (e, stackTrace) {
      _loggingService.logError('❌ Hardware button test failed', e, stackTrace);
      return false;
    }
  }
  
  /// Run comprehensive media controls test suite
  Future<Map<String, bool>> runComprehensiveTest(CustomAudioHandler audioHandler) async {
    _loggingService.logInfo('🧪 Starting comprehensive media controls test suite...');
    
    final results = <String, bool>{};
    
    // Test notification controls
    results['notification_controls'] = await testNotificationControls(audioHandler);
    
    // Test lock screen controls
    results['lock_screen_controls'] = await testLockScreenControls(audioHandler);
    
    // Test hardware buttons
    results['hardware_buttons'] = await testHardwareButtons(audioHandler);
    
    // Calculate overall success
    final allPassed = results.values.every((result) => result);
    results['overall_success'] = allPassed;
    
    // Log summary
    _loggingService.logInfo('📊 Test Results Summary:');
    results.forEach((test, passed) {
      final status = passed ? '✅ PASSED' : '❌ FAILED';
      _loggingService.logInfo('  $test: $status');
    });
    
    if (allPassed) {
      _loggingService.logInfo('🎉 All media controls tests passed! System integration is working correctly.');
    } else {
      _loggingService.logWarning('⚠️ Some media controls tests failed. Check the logs above for details.');
    }
    
    return results;
  }
  
  /// Generate test report
  String generateTestReport(Map<String, bool> results) {
    final buffer = StringBuffer();
    buffer.writeln('# Media Controls Test Report');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln();
    
    buffer.writeln('## Test Results');
    results.forEach((test, passed) {
      final status = passed ? 'PASSED ✅' : 'FAILED ❌';
      final testName = test.replaceAll('_', ' ').toUpperCase();
      buffer.writeln('- **$testName**: $status');
    });
    
    buffer.writeln();
    buffer.writeln('## Features Tested');
    buffer.writeln('1. **Notification Panel Controls**: Play, Pause, Skip Next/Previous buttons in notification');
    buffer.writeln('2. **Lock Screen Integration**: Media metadata and controls on lock screen');
    buffer.writeln('3. **Hardware Button Support**: Bluetooth headphones, wired headset controls');
    buffer.writeln('4. **System Integration**: AudioService configuration and media session setup');
    
    buffer.writeln();
    buffer.writeln('## Usage Instructions');
    buffer.writeln('To test manually:');
    buffer.writeln('1. Play a song in the app');
    buffer.writeln('2. Pull down notification panel - you should see media controls');
    buffer.writeln('3. Lock your device - controls should appear on lock screen');
    buffer.writeln('4. Connect Bluetooth headphones and test play/pause/skip buttons');
    
    return buffer.toString();
  }
}
