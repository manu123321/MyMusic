import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/music_provider.dart';
import '../models/playback_settings.dart';
import '../services/logging_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final LoggingService _loggingService = LoggingService();
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isScanning = false;
  bool _isClearing = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(playbackSettingsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Settings'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Playback Settings
          _buildSectionHeader('Playback'),
          _buildSwitchTile(
            'Shuffle',
            'Shuffle songs in queue',
            settings.shuffleEnabled,
            (value) {
              ref.read(playbackSettingsProvider.notifier).setShuffleEnabled(value);
            },
          ),
          _buildDropdownTile(
            'Repeat Mode',
            'Set repeat behavior',
            _getRepeatModeText(settings.repeatMode),
            () => _showRepeatModeDialog(context, ref),
          ),
          _buildSliderTile(
            'Playback Speed',
            '${settings.playbackSpeed.toStringAsFixed(1)}x',
            settings.playbackSpeed,
            0.5,
            2.0,
            (value) {
              ref.read(playbackSettingsProvider.notifier).setPlaybackSpeed(value);
            },
          ),
          _buildSliderTile(
            'Crossfade Duration',
            '${settings.crossfadeDuration}s',
            settings.crossfadeDuration.toDouble(),
            0,
            10,
            (value) {
              ref.read(playbackSettingsProvider.notifier).setCrossfadeDuration(value.toInt());
            },
          ),
          _buildSwitchTile(
            'Gapless Playback',
            'Seamless transitions between songs',
            settings.gaplessPlayback,
            (value) {
              ref.read(playbackSettingsProvider.notifier).setGaplessPlayback(value);
            },
          ),

          const SizedBox(height: 32),

          // Audio Settings
          _buildSectionHeader('Audio'),
          _buildSliderTile(
            'Volume',
            '${(settings.volume * 100).toInt()}%',
            settings.volume,
            0.0,
            1.0,
            (value) {
              ref.read(playbackSettingsProvider.notifier).setVolume(value);
            },
          ),

          const SizedBox(height: 32),

          // Sleep Timer Settings
          _buildSectionHeader('Sleep Timer'),
          _buildSwitchTile(
            'Enable Sleep Timer',
            'Auto-pause after specified time',
            settings.sleepTimerEnabled,
            (value) {
              ref.read(playbackSettingsProvider.notifier).setSleepTimerEnabled(value);
            },
          ),
          _buildSliderTile(
            'Default Duration',
            '${settings.sleepTimerDuration} minutes',
            settings.sleepTimerDuration.toDouble(),
            5,
            180,
            (value) {
              ref.read(playbackSettingsProvider.notifier).setSleepTimerDuration(value.toInt());
            },
          ),

          const SizedBox(height: 32),

          // Storage Settings
          _buildSectionHeader('Storage'),
          _buildActionTile(
            'Scan for Music',
            'Find new music files on device',
            Icons.refresh,
            _isScanning ? null : _scanForMusic,
            isLoading: _isScanning,
          ),
          _buildActionTile(
            'Export Data',
            'Backup playlists and settings',
            Icons.backup,
            _isExporting ? null : _exportData,
            isLoading: _isExporting,
          ),
          _buildActionTile(
            'Import Data',
            'Restore from backup',
            Icons.restore,
            _isImporting ? null : _importData,
            isLoading: _isImporting,
          ),
          _buildActionTile(
            'Clear All Data',
            'Remove all songs and playlists',
            Icons.delete_forever,
            _isClearing ? null : _showClearDataDialog,
            isDestructive: true,
            isLoading: _isClearing,
          ),

          const SizedBox(height: 32),

          // About
          _buildSectionHeader('About'),
          _buildInfoTile('Version', '1.0.0'),
          _buildInfoTile('Build', '1'),
          _buildActionTile(
            'Legal Notice',
            'Important legal information',
            Icons.info,
            () => _showLegalNotice(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[400]),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.green,
      ),
    );
  }

  Widget _buildDropdownTile(
    String title,
    String subtitle,
    String value,
    VoidCallback onTap,
  ) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[400]),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(color: Colors.white),
          ),
          const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildSliderTile(
    String title,
    String value,
    double currentValue,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(color: Colors.white),
          ),
          Slider(
            value: currentValue,
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: Colors.green,
            inactiveColor: Colors.grey[600],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback? onTap, {
    bool isDestructive = false,
    bool isLoading = false,
  }) {
    return ListTile(
      leading: isLoading
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDestructive ? Colors.red : const Color(0xFF00E676),
                ),
              ),
            )
          : Icon(
              icon,
              color: isDestructive ? Colors.red : Colors.white,
            ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : Colors.white,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[400]),
      ),
      trailing: onTap != null
          ? const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16)
          : null,
      onTap: onTap,
      enabled: onTap != null,
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      trailing: Text(
        value,
        style: TextStyle(color: Colors.grey[400]),
      ),
    );
  }

  String _getRepeatModeText(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.none:
        return 'Off';
      case RepeatMode.one:
        return 'One';
      case RepeatMode.all:
        return 'All';
    }
  }

  void _showRepeatModeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Repeat Mode',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: RepeatMode.values.map((mode) {
            return ListTile(
              title: Text(
                _getRepeatModeText(mode),
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                ref.read(playbackSettingsProvider.notifier).setRepeatMode(mode);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _scanForMusic() async {
    setState(() {
      _isScanning = true;
    });
    
    try {
      _loggingService.logInfo('Starting manual music scan');
      
      final metadataService = ref.read(metadataServiceProvider);
      final newSongs = await metadataService.scanDeviceForAudioFiles();
      
      if (newSongs.isNotEmpty) {
        // Add songs in batches
        await ref.read(storageServiceProvider).saveSongs(newSongs);
        await ref.read(songsProvider.notifier).loadSongs();
        
        _loggingService.logInfo('Found ${newSongs.length} new music files');
        
        _showSuccessSnackBar('Found ${newSongs.length} new music files');
      } else {
        _showInfoSnackBar('No new music files found');
      }
    } catch (e, stackTrace) {
      _loggingService.logError('Error scanning for music', e, stackTrace);
      _showErrorSnackBar('Error scanning for music: ${_getDisplayError(e)}');
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }
  
  Future<void> _exportData() async {
    setState(() {
      _isExporting = true;
    });
    
    try {
      _loggingService.logInfo('Starting data export');
      
      final storageService = ref.read(storageServiceProvider);
      final exportData = await storageService.exportData();
      
      // For now, just copy to clipboard (you can enhance this to save to file)
      await Clipboard.setData(ClipboardData(text: exportData));
      
      _loggingService.logInfo('Data exported successfully');
      _showSuccessSnackBar('Data exported to clipboard');
      
    } catch (e, stackTrace) {
      _loggingService.logError('Error exporting data', e, stackTrace);
      _showErrorSnackBar('Error exporting data: ${_getDisplayError(e)}');
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _importData() async {
    setState(() {
      _isImporting = true;
    });
    
    try {
      _loggingService.logInfo('Starting data import');
      
      // Pick file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );
      
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonData = await file.readAsString();
        
        final storageService = ref.read(storageServiceProvider);
        await storageService.importData(jsonData);
        
        // Refresh providers
        await ref.read(songsProvider.notifier).loadSongs();
        await ref.read(playlistsProvider.notifier).loadPlaylists();
        await ref.read(playbackSettingsProvider.notifier).loadSettings();
        
        _loggingService.logInfo('Data imported successfully');
        _showSuccessSnackBar('Data imported successfully');
      } else {
        _showInfoSnackBar('Import cancelled');
      }
      
    } catch (e, stackTrace) {
      _loggingService.logError('Error importing data', e, stackTrace);
      _showErrorSnackBar('Error importing data: ${_getDisplayError(e)}');
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _showClearDataDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text(
              'Clear All Data',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently remove:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 12),
            Text('• All songs from your library', style: TextStyle(color: Colors.white)),
            Text('• All playlists', style: TextStyle(color: Colors.white)),
            Text('• All settings and preferences', style: TextStyle(color: Colors.white)),
            Text('• All playback history', style: TextStyle(color: Colors.white)),
            SizedBox(height: 16),
            Text(
              'This action cannot be undone.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All Data'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _clearAllData();
    }
  }
  
  Future<void> _clearAllData() async {
    setState(() {
      _isClearing = true;
    });
    
    try {
      _loggingService.logInfo('Starting data clear operation');
      
      final storageService = ref.read(storageServiceProvider);
      await storageService.clearAllData();
      
      // Refresh all providers
      await ref.read(songsProvider.notifier).loadSongs();
      await ref.read(playlistsProvider.notifier).loadPlaylists();
      await ref.read(playbackSettingsProvider.notifier).loadSettings();
      
      _loggingService.logInfo('All data cleared successfully');
      _showSuccessSnackBar('All data cleared successfully');
      
    } catch (e, stackTrace) {
      _loggingService.logError('Error clearing data', e, stackTrace);
      _showErrorSnackBar('Error clearing data: ${_getDisplayError(e)}');
    } finally {
      if (mounted) {
        setState(() {
          _isClearing = false;
        });
      }
    }
  }

  void _showLegalNotice(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.gavel, color: Colors.blue),
            SizedBox(width: 8),
            Text(
              'Legal Notice',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            'This application is for personal use only and plays only local files.\n\n'
            '• This app does NOT stream copyrighted content from third-party services\n'
            '• This app does NOT bypass any licensing or copyright protections\n'
            '• This app ONLY accesses and plays audio files already present on your device\n'
            '• Users are responsible for ensuring they have proper rights to any music files they play\n'
            '• This app does not include any code that attempts to access streaming services or copyrighted content\n'
            '• All music files must be legally obtained and stored locally on the user\'s device\n\n'
            'Respect copyright laws and only play music you have the right to use.',
            style: TextStyle(color: Colors.white, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I Understand', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }
  
  String _getDisplayError(Object error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('permission')) {
      return 'Permission denied';
    } else if (errorStr.contains('storage') || errorStr.contains('database')) {
      return 'Storage error';
    } else if (errorStr.contains('file')) {
      return 'File operation failed';
    }
    return 'Unknown error occurred';
  }
  
  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }
  
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }
  
  void _showInfoSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.orange[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }
}
