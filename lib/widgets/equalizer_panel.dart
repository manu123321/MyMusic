import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/music_provider.dart';
import '../models/playback_settings.dart';

class EqualizerPanel extends ConsumerStatefulWidget {
  const EqualizerPanel({super.key});

  @override
  ConsumerState<EqualizerPanel> createState() => _EqualizerPanelState();
}

class _EqualizerPanelState extends ConsumerState<EqualizerPanel> {
  final List<String> _bands = [
    '60Hz', '170Hz', '310Hz', '600Hz', '1kHz',
    '3kHz', '6kHz', '12kHz', '14kHz', '16kHz'
  ];
  
  final List<double> _gains = List.filled(10, 0.0);
  String _selectedPreset = 'Custom';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Equalizer',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Presets
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                'Custom', 'Pop', 'Rock', 'Jazz', 'Classical', 'Vocal', 'Bass Boost'
              ].map((preset) {
                final isSelected = _selectedPreset == preset;
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      preset,
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                        fontSize: 12,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedPreset = preset;
                        _applyPreset(preset);
                      });
                    },
                    backgroundColor: Colors.grey[800],
                    selectedColor: Colors.green,
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Equalizer bands
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(10, (index) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Gain value
                    Text(
                      '${_gains[index].toStringAsFixed(0)}dB',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    
                    // Slider
                    Expanded(
                      child: RotatedBox(
                        quarterTurns: -1,
                        child: Slider(
                          value: _gains[index],
                          min: -12.0,
                          max: 12.0,
                          divisions: 24,
                          onChanged: (value) {
                            setState(() {
                              _gains[index] = value;
                              _selectedPreset = 'Custom';
                            });
                            _updateEqualizer();
                          },
                          activeColor: Colors.green,
                          inactiveColor: Colors.grey[600],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Band label
                    Text(
                      _bands[index],
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 10,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Reset button
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _gains.fillRange(0, 10, 0.0);
                  _selectedPreset = 'Custom';
                });
                _updateEqualizer();
              },
              child: const Text(
                'Reset',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _applyPreset(String preset) {
    switch (preset) {
      case 'Pop':
        _gains[0] = 2; _gains[1] = 1; _gains[2] = -1; _gains[3] = -2; _gains[4] = -1;
        _gains[5] = 1; _gains[6] = 2; _gains[7] = 3; _gains[8] = 2; _gains[9] = 1;
        break;
      case 'Rock':
        _gains[0] = 4; _gains[1] = 3; _gains[2] = 1; _gains[3] = -1; _gains[4] = -2;
        _gains[5] = 1; _gains[6] = 2; _gains[7] = 3; _gains[8] = 4; _gains[9] = 3;
        break;
      case 'Jazz':
        _gains[0] = 1; _gains[1] = 2; _gains[2] = 1; _gains[3] = 0; _gains[4] = 0;
        _gains[5] = 1; _gains[6] = 2; _gains[7] = 1; _gains[8] = 1; _gains[9] = 0;
        break;
      case 'Classical':
        _gains[0] = 0; _gains[1] = 0; _gains[2] = 0; _gains[3] = 0; _gains[4] = 0;
        _gains[5] = 0; _gains[6] = 1; _gains[7] = 2; _gains[8] = 2; _gains[9] = 1;
        break;
      case 'Vocal':
        _gains[0] = -1; _gains[1] = -1; _gains[2] = 0; _gains[3] = 2; _gains[4] = 3;
        _gains[5] = 2; _gains[6] = 1; _gains[7] = 0; _gains[8] = -1; _gains[9] = -1;
        break;
      case 'Bass Boost':
        _gains[0] = 6; _gains[1] = 4; _gains[2] = 2; _gains[3] = 0; _gains[4] = 0;
        _gains[5] = 0; _gains[6] = 0; _gains[7] = 0; _gains[8] = 0; _gains[9] = 0;
        break;
      default:
        _gains.fillRange(0, 10, 0.0);
    }
    _updateEqualizer();
  }

  void _updateEqualizer() {
    final settings = <String, double>{};
    for (int i = 0; i < _bands.length; i++) {
      settings[_bands[i]] = _gains[i];
    }
    ref.read(playbackSettingsProvider.notifier).setEqualizerSettings(settings);
  }
}
