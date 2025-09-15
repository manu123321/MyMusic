import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/music_provider.dart';
import '../models/playback_settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            () {
              ref.read(songsProvider.notifier).scanDeviceForSongs();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Scanning for music...'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
          _buildActionTile(
            'Export Data',
            'Backup playlists and settings',
            Icons.backup,
            () => _exportData(context, ref),
          ),
          _buildActionTile(
            'Import Data',
            'Restore from backup',
            Icons.restore,
            () => _importData(context, ref),
          ),
          _buildActionTile(
            'Clear All Data',
            'Remove all songs and playlists',
            Icons.delete_forever,
            () => _showClearDataDialog(context, ref),
            isDestructive: true,
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
        activeColor: Colors.green,
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
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
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
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
      onTap: onTap,
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

  void _exportData(BuildContext context, WidgetRef ref) {
    // TODO: Implement data export
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export feature coming soon'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _importData(BuildContext context, WidgetRef ref) {
    // TODO: Implement data import
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Import feature coming soon'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showClearDataDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Clear All Data',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will remove all songs, playlists, and settings. This action cannot be undone.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement clear all data
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Clear data feature coming soon'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showLegalNotice(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Legal Notice',
          style: TextStyle(color: Colors.white),
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
            style: TextStyle(color: Colors.white),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
