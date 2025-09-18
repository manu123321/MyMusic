import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/music_provider.dart';

class SleepTimerBottomSheet extends ConsumerWidget {
  const SleepTimerBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      height: screenHeight * 0.5, // 50% of screen height
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Sleep Timer',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          // Sleep timer options
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final playbackSettings = ref.watch(playbackSettingsProvider);
                final isTimerActive = playbackSettings.sleepTimerEnabled;
                
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildTimerOption(context, ref, '5 minutes', 5),
                    _buildTimerOption(context, ref, '10 minutes', 10),
                    _buildTimerOption(context, ref, '15 minutes', 15),
                    _buildTimerOption(context, ref, '30 minutes', 30),
                    _buildTimerOption(context, ref, '45 minutes', 45),
                    _buildTimerOption(context, ref, '1 hour', 60),
                    _buildEndOfTrackOption(context, ref),
                    
                    // Show "Turn off timer" option only when timer is active
                    if (isTimerActive)
                      _buildTurnOffTimerOption(context, ref),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerOption(BuildContext context, WidgetRef ref, String label, int minutes) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          _setTimer(context, ref, minutes, label);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEndOfTrackOption(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          _setEndOfTrackTimer(context, ref);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Text(
            'End of track',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTurnOffTimerOption(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          _turnOffTimer(context, ref);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Text(
            'Turn off timer',
            style: TextStyle(
              color: Colors.red[400],
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  void _setTimer(BuildContext context, WidgetRef ref, int minutes, String label) async {
    final audioHandler = ref.read(audioHandlerProvider);
    await audioHandler.startSleepTimer(minutes);
    
    // Update the playback settings provider to reflect the timer state
    final playbackSettingsNotifier = ref.read(playbackSettingsProvider.notifier);
    await playbackSettingsNotifier.setSleepTimerEnabled(true);
    await playbackSettingsNotifier.setSleepTimerDuration(minutes);
    
    if (context.mounted) {
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Your sleep timer is set for $label',
            style: const TextStyle(color: Colors.black),
          ),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  void _setEndOfTrackTimer(BuildContext context, WidgetRef ref) async {
    final audioHandler = ref.read(audioHandlerProvider);
    final currentSong = ref.read(currentSongProvider).value;
    
    if (currentSong?.duration != null) {
      // Get current position and calculate remaining time
      try {
        final positionStream = audioHandler.positionStream;
        if (positionStream == null) {
          throw Exception('Position stream not available');
        }
        final currentPosition = await positionStream.first;
        final remainingDuration = currentSong!.duration! - currentPosition;
        final remainingMinutes = remainingDuration.inMinutes;
        
        if (remainingMinutes > 0) {
          await audioHandler.startSleepTimer(remainingMinutes);
          
          // Update the playback settings provider to reflect the timer state
          final playbackSettingsNotifier = ref.read(playbackSettingsProvider.notifier);
          await playbackSettingsNotifier.setSleepTimerEnabled(true);
          await playbackSettingsNotifier.setSleepTimerDuration(remainingMinutes);
          
          if (context.mounted) {
            Navigator.pop(context);
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Your sleep timer is set to end of track',
                  style: TextStyle(color: Colors.black),
                ),
                backgroundColor: Colors.white,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }
        } else {
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Track is almost finished'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Unable to get current position'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to determine track duration'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  void _turnOffTimer(BuildContext context, WidgetRef ref) async {
    final audioHandler = ref.read(audioHandlerProvider);
    await audioHandler.cancelSleepTimer();
    
    // Update the playback settings provider to reflect the timer state
    final playbackSettingsNotifier = ref.read(playbackSettingsProvider.notifier);
    await playbackSettingsNotifier.setSleepTimerEnabled(false);
    
    if (context.mounted) {
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Sleep timer turned off',
            style: TextStyle(color: Colors.black),
          ),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }
}
