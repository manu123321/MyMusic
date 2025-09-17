import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/music_provider.dart';
import '../services/logging_service.dart';

class CreatePlaylistScreen extends ConsumerStatefulWidget {
  const CreatePlaylistScreen({super.key});

  @override
  ConsumerState<CreatePlaylistScreen> createState() => _CreatePlaylistScreenState();
}

class _CreatePlaylistScreenState extends ConsumerState<CreatePlaylistScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();
  final LoggingService _loggingService = LoggingService();
  
  bool _isCreating = false;
  bool _isPublic = false;
  String? _selectedColorTheme;
  String? _nameError;
  
  static const int _maxNameLength = 100;
  static const int _maxDescriptionLength = 500;
  
  final List<String> _colorThemes = [
    '#FF5722', // Deep Orange
    '#E91E63', // Pink
    '#9C27B0', // Purple
    '#673AB7', // Deep Purple
    '#3F51B5', // Indigo
    '#2196F3', // Blue
    '#00BCD4', // Cyan
    '#009688', // Teal
    '#4CAF50', // Green
    '#8BC34A', // Light Green
    '#CDDC39', // Lime
    '#FFC107', // Amber
  ];

  @override
  void initState() {
    super.initState();
    _nameFocusNode.addListener(_onNameFocusChanged);
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameFocusNode.removeListener(_onNameFocusChanged);
    _nameController.dispose();
    _descriptionController.dispose();
    _nameFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }
  
  void _onNameFocusChanged() {
    if (!_nameFocusNode.hasFocus) {
      _validateName();
    }
  }
  
  void _onNameChanged() {
    if (_nameError != null) {
      setState(() {
        _nameError = null;
      });
    }
  }
  
  void _validateName() {
    final name = _nameController.text.trim();
    setState(() {
      if (name.isEmpty) {
        _nameError = 'Playlist name is required';
      } else if (name.length > _maxNameLength) {
        _nameError = 'Name must be $_maxNameLength characters or less';
      } else if (_isDuplicateName(name)) {
        _nameError = 'A playlist with this name already exists';
      } else {
        _nameError = null;
      }
    });
  }
  
  bool _isDuplicateName(String name) {
    final playlists = ref.read(playlistsProvider);
    return playlists.any((p) => 
        p.name.toLowerCase() == name.toLowerCase() && !p.isSystemPlaylist);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: Colors.white),
        ),
        title: const Text(
          'Create playlist',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              
              // Playlist icon placeholder
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey[600]!,
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Icon(
                    Icons.music_note,
                    color: Colors.grey[400],
                    size: 48,
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Title
              const Text(
                'Give your playlist a name',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Name input field with validation
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    maxLength: _maxNameLength,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'My playlist #${_getNextPlaylistNumber()}',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: _nameError != null ? Colors.red : Colors.grey[600]!,
                          width: 1,
                        ),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: _nameError != null ? Colors.red : const Color(0xFF00E676),
                          width: 2,
                        ),
                      ),
                      errorBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.red,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 16,
                      ),
                      counterStyle: TextStyle(color: Colors.grey[600]),
                    ),
                    onChanged: (value) {
                      setState(() {}); // Rebuild to update create button state
                    },
                    onSubmitted: (value) {
                      _descriptionFocusNode.requestFocus();
                    },
                  ),
                  if (_nameError != null) ..[
                    const SizedBox(height: 8),
                    Text(
                      _nameError!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Description input field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Description (optional)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    focusNode: _descriptionFocusNode,
                    maxLength: _maxDescriptionLength,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Add a description for your playlist...',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 16,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.grey[600]!,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                          color: Color(0xFF00E676),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                      counterStyle: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Color theme selection
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose a color theme',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _colorThemes.map((color) {
                      final isSelected = _selectedColorTheme == color;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedColorTheme = isSelected ? null : color;
                          });
                          HapticFeedback.selectionClick();
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Color(int.parse(color.substring(1), radix: 16) + 0xFF000000),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.3),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Privacy setting
              SwitchListTile(
                title: const Text(
                  'Make playlist public',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Allow others to discover this playlist',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                value: _isPublic,
                onChanged: (value) {
                  setState(() {
                    _isPublic = value;
                  });
                  HapticFeedback.selectionClick();
                },
                activeColor: const Color(0xFF00E676),
                contentPadding: EdgeInsets.zero,
              ),
              
              const SizedBox(height: 40),
              
              // Create button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canCreatePlaylist() && !_isCreating ? _createPlaylist : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canCreatePlaylist() ? const Color(0xFF00E676) : Colors.grey[700],
                    foregroundColor: _canCreatePlaylist() ? Colors.black : Colors.grey[500],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: _canCreatePlaylist() ? 2 : 0,
                  ),
                  child: _isCreating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : const Text(
                          'Create Playlist',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Cancel button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _isCreating ? null : () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20), // Extra space at bottom for scroll
            ],
          ),
        ),
      ),
    );
  }

  int _getNextPlaylistNumber() {
    final playlists = ref.read(playlistsProvider);
    final userPlaylists = playlists.where((p) => !p.isSystemPlaylist).toList();
    return userPlaylists.length + 1;
  }

  bool _canCreatePlaylist() {
    final name = _nameController.text.trim();
    return name.isNotEmpty && 
           name.length <= _maxNameLength && 
           !_isDuplicateName(name) &&
           _nameError == null;
  }
  
  Future<void> _createPlaylist() async {
    // Final validation
    _validateName();
    if (_nameError != null) {
      HapticFeedback.heavyImpact();
      return;
    }
    
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    
    setState(() {
      _isCreating = true;
    });

    try {
      _loggingService.logInfo('Creating playlist: $name');
      
      // Create playlist with enhanced options
      await ref.read(playlistsProvider.notifier).createPlaylist(
        name,
        description: description.isEmpty ? null : description,
        colorTheme: _selectedColorTheme,
        isPublic: _isPublic,
      );
      
      _loggingService.logInfo('Playlist created successfully: $name');
      
      if (mounted) {
        // Haptic feedback for success
        HapticFeedback.lightImpact();
        
        Navigator.pop(context, true); // Return success flag
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Playlist "$name" created successfully'),
                ),
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
    } catch (e, stackTrace) {
      _loggingService.logError('Error creating playlist: $name', e, stackTrace);
      
      if (mounted) {
        HapticFeedback.heavyImpact();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Error creating playlist: ${_getDisplayError(e)}'),
                ),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _createPlaylist,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }
  
  String _getDisplayError(Object error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('duplicate') || errorStr.contains('exists')) {
      return 'A playlist with this name already exists';
    } else if (errorStr.contains('storage') || errorStr.contains('database')) {
      return 'Storage error - please try again';
    } else if (errorStr.contains('permission')) {
      return 'Permission denied';
    }
    return 'Unknown error occurred';
  }
}
