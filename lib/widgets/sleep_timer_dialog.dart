import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/music_provider.dart';
import '../services/custom_audio_handler.dart';
import '../models/playback_settings.dart';

class SleepTimerDialog extends ConsumerStatefulWidget {
  const SleepTimerDialog({super.key});

  @override
  ConsumerState<SleepTimerDialog> createState() => _SleepTimerDialogState();
}

class _SleepTimerDialogState extends ConsumerState<SleepTimerDialog> {
  int _selectedMinutes = 30;
  final List<int> _presetMinutes = [5, 10, 15, 30, 45, 60, 90, 120];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text(
        'Sleep Timer',
        style: TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Stop playback after:',
            style: TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          
          // Preset buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presetMinutes.map((minutes) {
              final isSelected = _selectedMinutes == minutes;
              return ChoiceChip(
                label: Text(
                  '${minutes}m',
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontSize: 12,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedMinutes = minutes;
                  });
                },
                backgroundColor: Colors.grey[800],
                selectedColor: Colors.green,
              );
            }).toList(),
          ),
          
          const SizedBox(height: 16),
          
          // Custom time input
          Row(
            children: [
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Custom (minutes)',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                  onChanged: (value) {
                    final minutes = int.tryParse(value);
                    if (minutes != null && minutes > 0) {
                      setState(() {
                        _selectedMinutes = minutes;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () {
            final audioHandler = ref.read(audioHandlerProvider);
            (audioHandler as CustomAudioHandler).startSleepTimer(_selectedMinutes);
            Navigator.pop(context);
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Sleep timer set for $_selectedMinutes minutes'),
                backgroundColor: Colors.green,
                action: SnackBarAction(
                  label: 'Cancel',
                  textColor: Colors.white,
                  onPressed: () {
                    (audioHandler as CustomAudioHandler).cancelSleepTimer();
                  },
                ),
              ),
            );
          },
          child: const Text('Set Timer', style: TextStyle(color: Colors.green)),
        ),
      ],
    );
  }
}
