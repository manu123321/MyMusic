import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/permission_service.dart';
import '../services/metadata_service.dart';
import '../services/logging_service.dart';
import '../providers/music_provider.dart';
import 'main_screen.dart';
import 'error_screen.dart';

class LoadingScreen extends ConsumerStatefulWidget {
  const LoadingScreen({super.key});

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen>
    with TickerProviderStateMixin {
  final LoggingService _loggingService = LoggingService();
  String _loadingMessage = 'Initializing...';
  double _progress = 0.0;
  bool _hasError = false;
  String? _errorMessage;
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Initialize animations
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    // Start animations
    _pulseController.repeat(reverse: true);
    _rotationController.repeat();
    _fadeController.forward();

    // Start the app initialization
    _initializeApp();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      _loggingService.logInfo('Starting app initialization');
      
      // Step 1: Check network connectivity
      await _updateProgress('Checking connectivity...', 0.1);
      await _checkConnectivity();
      
      // Step 2: Initialize services
      await _updateProgress('Initializing services...', 0.2);
      await _initializeServices();
      
      // Step 3: Check permissions
      await _updateProgress('Checking permissions...', 0.4);
      final permissionService = PermissionService();
      final hasPermissions = await permissionService.hasMediaPermissions();
      
      if (hasPermissions) {
        await _scanForMusic();
      } else {
        await _requestPermissions();
      }
      
      // Step 5: Finalize
      await _updateProgress('Finalizing...', 0.9);
      await Future.delayed(const Duration(milliseconds: 500));
      
      _loggingService.logInfo('App initialization completed successfully');
      
    } catch (e, stackTrace) {
      _loggingService.logError('Error during app initialization', e, stackTrace);
      
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
      
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        _navigateToMainScreen();
      }
    }
  }

  Future<void> _requestPermissions() async {
    try {
      await _updateProgress('Requesting permissions...', 0.5);
      
      final permissionService = PermissionService();
      final granted = await permissionService.requestMediaPermissions();

      if (granted) {
        _loggingService.logInfo('Permissions granted');
        await _scanForMusic();
      } else {
        _loggingService.logWarning('Permissions denied by user');
        await _updateProgress('Permissions denied', 0.8);
        await Future.delayed(const Duration(seconds: 1));
        _navigateToMainScreen();
      }
    } catch (e, stackTrace) {
      _loggingService.logError('Error requesting permissions', e, stackTrace);
      _navigateToMainScreen();
    }
  }

  Future<void> _scanForMusic() async {
    try {
      await _updateProgress('Scanning for music...', 0.6);
      
      final metadataService = MetadataService();
      final songs = await metadataService.scanDeviceForAudioFiles();
      
      _loggingService.logInfo('Found ${songs.length} music files');
      
      if (songs.isNotEmpty) {
        await _updateProgress('Adding ${songs.length} songs...', 0.7);
        
        // Add songs in batches for better performance
        const batchSize = 50;
        for (int i = 0; i < songs.length; i += batchSize) {
          final batch = songs.skip(i).take(batchSize).toList();
          await ref.read(storageServiceProvider).saveSongs(batch);
          
          // Update progress
          final progress = 0.7 + (0.1 * (i + batch.length) / songs.length);
          await _updateProgress(
            'Added ${i + batch.length}/${songs.length} songs...', 
            progress,
          );
        }
        
        // Refresh songs provider
        await ref.read(songsProvider.notifier).loadSongs();
      }
      
      await _updateProgress('Complete!', 1.0);
      await Future.delayed(const Duration(milliseconds: 500));
      
    } catch (e, stackTrace) {
      _loggingService.logError('Error scanning for music', e, stackTrace);
    } finally {
      _navigateToMainScreen();
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isConnected = connectivityResult != ConnectivityResult.none;
      _loggingService.logInfo('Network connectivity: $isConnected');
    } catch (e) {
      _loggingService.logWarning('Failed to check connectivity: $e');
    }
  }
  
  Future<void> _initializeServices() async {
    try {
      // Initialize any additional services here
      await Future.delayed(const Duration(milliseconds: 200));
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to initialize services', e, stackTrace);
      rethrow;
    }
  }
  
  Future<void> _updateProgress(String message, double progress) async {
    if (mounted) {
      setState(() {
        _loadingMessage = message;
        _progress = progress;
      });
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
  
  void _navigateToMainScreen() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0A0A),
              Color(0xFF1A1A1A),
              Color(0xFF0A0A0A),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated app icon with premium effects
                AnimatedBuilder(
                  animation: Listenable.merge([_pulseAnimation, _rotationAnimation, _fadeAnimation]),
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Transform.rotate(
                        angle: _rotationAnimation.value * 2 * 3.14159,
                        child: Opacity(
                          opacity: _fadeAnimation.value,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF00E676),
                                  Color(0xFF00C853),
                                  Color(0xFF4CAF50),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00E676).withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                                BoxShadow(
                                  color: const Color(0xFF00E676).withOpacity(0.1),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.music_note_rounded,
                              color: Colors.white,
                              size: 60,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 40),
                
                // App title with fade animation
                // FadeTransition(
                //   opacity: _fadeAnimation,
                //   child: const Text(
                //     'Music Player',
                //     style: TextStyle(
                //       color: Colors.white,
                //       fontSize: 32,
                //       fontWeight: FontWeight.w300,
                //       letterSpacing: 2,
                //     ),
                //   ),
                // ),
                
                const SizedBox(height: 16),
                
                // Subtitle with fade animation
                // FadeTransition(
                //   opacity: _fadeAnimation,
                //   child: Text(
                //     'Your premium music experience',
                //     style: TextStyle(
                //       color: Colors.grey[400],
                //       fontSize: 16,
                //       fontWeight: FontWeight.w300,
                //       letterSpacing: 1,
                //     ),
                //   ),
                // ),
                
                const SizedBox(height: 60),
                
                // Modern loading indicator
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    width: 60,
                    height: 60,
                    child: Stack(
                      children: [
                        // Outer rotating ring
                        AnimatedBuilder(
                          animation: _rotationController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _rotationAnimation.value * 2 * 3.14159,
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF00E676).withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
                                ),
                              ),
                            );
                          },
                        ),
                        // Inner pulsing dot
                        Center(
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value * 0.5 + 0.5,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF00E676),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Loading text with fade animation
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      Text(
                        _hasError ? 'Something went wrong' : _loadingMessage,
                        style: TextStyle(
                          color: _hasError ? Colors.red[400] : Colors.grey[500],
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (!_hasError) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: 200,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: _progress,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E676),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (_hasError) ...[
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage ?? 'Unknown error',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
