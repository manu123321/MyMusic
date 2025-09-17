import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/music_provider.dart';
import '../models/playback_settings.dart';
import '../services/logging_service.dart';

class EqualizerPanel extends ConsumerStatefulWidget {
  const EqualizerPanel({super.key});

  @override
  ConsumerState<EqualizerPanel> createState() => _EqualizerPanelState();
}

class _EqualizerPanelState extends ConsumerState<EqualizerPanel>
    with TickerProviderStateMixin {
  final LoggingService _loggingService = LoggingService();
  
  final List<String> _bands = [
    '60Hz', '170Hz', '310Hz', '600Hz', '1kHz',
    '3kHz', '6kHz', '12kHz', '14kHz', '16kHz'
  ];
  
  final List<double> _gains = List.filled(10, 0.0);
  String _selectedPreset = 'Custom';
  
  late AnimationController _animationController;
  late List<AnimationController> _bandControllers;
  late List<Animation<double>> _bandAnimations;
  
  bool _isEnabled = false;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Create individual animation controllers for each band
    _bandControllers = List.generate(10, (index) {
      return AnimationController(
        duration: const Duration(milliseconds: 150),
        vsync: this,
      );
    });
    
    _bandAnimations = _bandControllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOutBack),
      );
    }).toList();
    
    // Load current settings
    _loadCurrentSettings();
    
    // Start animations
    _animationController.forward();
    for (int i = 0; i < _bandControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 50), () {
        if (mounted) {
          _bandControllers[i].forward();
        }
      });
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    for (final controller in _bandControllers) {
      controller.dispose();
    }
    super.dispose();
  }
  
  void _loadCurrentSettings() {
    final settings = ref.read(playbackSettingsProvider);
    final eqSettings = settings.equalizerSettings;
    
    for (int i = 0; i < _bands.length; i++) {
      final bandKey = _bands[i];
      if (eqSettings.containsKey(bandKey)) {
        _gains[i] = eqSettings[bandKey]!;
      }
    }
    
    _isEnabled = eqSettings.isNotEmpty;
    _selectedPreset = _detectCurrentPreset();
  }
  
  String _detectCurrentPreset() {
    // Check if current gains match any preset
    final presets = _getPresetGains();
    
    for (final preset in presets.entries) {
      bool matches = true;
      for (int i = 0; i < _gains.length; i++) {
        if ((_gains[i] - preset.value[i]).abs() > 0.1) {
          matches = false;
          break;
        }
      }
      if (matches) return preset.key;
    }
    
    return 'Custom';
  }

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
                      HapticFeedback.selectionClick();
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
                            _isEnabled = true;
                          });
                          _updateEqualizer();
                          HapticFeedback.selectionClick();
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
          
          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Enable/Disable button
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isEnabled = !_isEnabled;
                    if (!_isEnabled) {
                      _gains.fillRange(0, 10, 0.0);
                      _selectedPreset = 'Custom';
                    }
                  });
                  _updateEqualizer();
                  HapticFeedback.selectionClick();
                },
                icon: Icon(
                  _isEnabled ? Icons.equalizer : Icons.equalizer_outlined,
                  color: _isEnabled ? const Color(0xFF00E676) : Colors.grey,
                  size: 16,
                ),
                label: Text(
                  _isEnabled ? 'Enabled' : 'Disabled',
                  style: TextStyle(
                    color: _isEnabled ? const Color(0xFF00E676) : Colors.grey,
                  ),
                ),
              ),
              
              // Reset button
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _gains.fillRange(0, 10, 0.0);
                    _selectedPreset = 'Custom';
                  });
                  _updateEqualizer();
                  HapticFeedback.lightImpact();
                },
                icon: const Icon(
                  Icons.refresh,
                  color: Colors.grey,
                  size: 16,
                ),
                label: const Text(
                  'Reset',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, List<double>> _getPresetGains() {
    return {
      'Custom': List.filled(10, 0.0),
      'Pop': [2, 1, -1, -2, -1, 1, 2, 3, 2, 1],
      'Rock': [4, 3, 1, -1, -2, 1, 2, 3, 4, 3],
      'Jazz': [1, 2, 1, 0, 0, 1, 2, 1, 1, 0],
      'Classical': [0, 0, 0, 0, 0, 0, 1, 2, 2, 1],
      'Vocal': [-1, -1, 0, 2, 3, 2, 1, 0, -1, -1],
      'Bass Boost': [6, 4, 2, 0, 0, 0, 0, 0, 0, 0],
    };
  }
  
  void _applyPreset(String preset) {
    try {
      final presetGains = _getPresetGains()[preset];
      if (presetGains != null) {
        for (int i = 0; i < _gains.length && i < presetGains.length; i++) {
          _gains[i] = presetGains[i];
        }
        _isEnabled = preset != 'Custom' || _gains.any((gain) => gain != 0.0);
        _updateEqualizer();
        
        _loggingService.logInfo('Applied equalizer preset: $preset');
      }
    } catch (e, stackTrace) {
      _loggingService.logError('Error applying equalizer preset: $preset', e, stackTrace);
    }
  }

  void _updateEqualizer() {
    try {
      final settings = <String, double>{};
      for (int i = 0; i < _bands.length; i++) {
        settings[_bands[i]] = _gains[i];
      }
      
      ref.read(playbackSettingsProvider.notifier).setEqualizerSettings(settings);
      _loggingService.logDebug('Updated equalizer settings: $settings');
      
    } catch (e, stackTrace) {
      _loggingService.logError('Error updating equalizer settings', e, stackTrace);
    }
  }
}
