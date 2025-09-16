import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/permission_service.dart';
import '../services/metadata_service.dart';
import '../providers/music_provider.dart';
import 'main_screen.dart';

class LoadingScreen extends ConsumerStatefulWidget {
  const LoadingScreen({super.key});

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen>
    with TickerProviderStateMixin {
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
      final permissionService = PermissionService();
      final hasPermissions = await permissionService.hasMediaPermissions();
      
      if (hasPermissions) {
        // User has permissions, scan for music
        await _scanForMusic();
      } else {
        // First time user, request permissions
        await _requestPermissions();
      }
    } catch (e) {
      print('Error during app initialization: $e');
      // Navigate to main screen even if there's an error
      _navigateToMainScreen();
    }
  }

  Future<void> _requestPermissions() async {
    final permissionService = PermissionService();
    final granted = await permissionService.requestMediaPermissions();

    if (granted) {
      await _scanForMusic();
    } else {
      // Even if permissions are denied, navigate to main screen
      // User can manually scan later if needed
      _navigateToMainScreen();
    }
  }

  Future<void> _scanForMusic() async {
    try {
      final metadataService = MetadataService();
      final songs = await metadataService.scanDeviceForAudioFiles();
      
      // Add songs to the app
      for (final song in songs) {
        await ref.read(songsProvider.notifier).addSong(song);
      }
    } catch (e) {
      print('Error scanning for music: $e');
    } finally {
      _navigateToMainScreen();
    }
  }

  void _navigateToMainScreen() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainScreen()),
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
                  child: Text(
                    'Preparing your music library...',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                    ),
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
