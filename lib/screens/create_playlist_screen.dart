import 'package:flutter/material.dart';
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
  final FocusNode _nameFocusNode = FocusNode();
  final LoggingService _loggingService = LoggingService();
  
  bool _isCreating = false;
  String? _nameError;
  
  static const int _maxNameLength = 100;

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
    _nameFocusNode.dispose();
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
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: Colors.white),
        ),
        title: const Text(
          'Give your playlist a name',
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
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 
                         MediaQuery.of(context).padding.top - 
                         kToolbarHeight - 
                         MediaQuery.of(context).viewInsets.bottom - 
                         48, // Account for padding
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  
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
                          hintText: 'Playlist name',
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
                      ),
                      if (_nameError != null) ...[
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
                  
                  const SizedBox(height: 16),
                  
                  // Create button positioned on the right
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _canCreatePlaylist() && !_isCreating ? _createPlaylist : null,
                      child: _isCreating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Create',
                              style: TextStyle(
                                color: _canCreatePlaylist() ? const Color(0xFF00E676) : Colors.grey[500],
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
      return;
    }
    
    final name = _nameController.text.trim();
    
    setState(() {
      _isCreating = true;
    });

    try {
      _loggingService.logInfo('Creating playlist: $name');
      
      // Create simple playlist
      await ref.read(playlistsProvider.notifier).createPlaylist(name);
      
      _loggingService.logInfo('Playlist created successfully: $name');
      
      if (mounted) {
        Navigator.pop(context, true); // Return success flag
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Playlist "$name" created successfully', style: const TextStyle(color: Colors.black)),
            backgroundColor: Colors.white,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating playlist: ${_getDisplayError(e)}', style: const TextStyle(color: Colors.black)),
            backgroundColor: Colors.white,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.black,
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
