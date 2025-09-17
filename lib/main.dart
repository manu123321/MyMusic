import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/professional_audio_handler.dart';
import 'services/custom_audio_handler.dart';
import 'services/storage_service.dart';
import 'services/logging_service.dart';
import 'screens/loading_screen.dart';
import 'screens/error_screen.dart';
import 'providers/music_provider.dart';

late CustomAudioHandler audioHandler;

Future<void> main() async {
  // Setup error handling for the entire app
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize logging service first
    final loggingService = LoggingService();
    await loggingService.initialize();

    // Set up global error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      loggingService.logError('Flutter Error', details.exception, details.stack);
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
    };

    // Handle platform-specific initialization
    if (Platform.isAndroid || Platform.isIOS) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    // Initialize core services with proper error handling
    try {
      await _initializeApp();
    } catch (e, stackTrace) {
      loggingService.logError('App Initialization Failed', e, stackTrace);
      // Run minimal app with error screen
      runApp(_buildErrorApp(e.toString()));
      return;
    }

    runApp(
      ProviderScope(
        overrides: [
          audioHandlerProvider.overrideWithValue(audioHandler),
          loggingServiceProvider.overrideWithValue(loggingService),
        ],
        child: const MyApp(),
      ),
    );
  }, (error, stackTrace) {
    // Global error handler for uncaught exceptions
    final loggingService = LoggingService();
    loggingService.logError('Uncaught Exception', error, stackTrace);
    
    if (kDebugMode) {
      print('Uncaught exception: $error');
      print('Stack trace: $stackTrace');
    }
  });
}

Future<void> _initializeApp() async {
  // Initialize Hive with error handling
  try {
    await Hive.initFlutter();
  } catch (e) {
    throw AppInitializationException('Failed to initialize Hive database: $e');
  }
  
  // Initialize storage service with retry mechanism
  final storageService = StorageService();
  int retryCount = 0;
  const maxRetries = 3;
  
  while (retryCount < maxRetries) {
    try {
      await storageService.initialize();
      break;
    } catch (e) {
      retryCount++;
      if (retryCount >= maxRetries) {
        throw AppInitializationException('Failed to initialize storage after $maxRetries attempts: $e');
      }
      await Future.delayed(Duration(seconds: retryCount));
    }
  }

  // Initialize audio handler with proper error handling
  try {
    audioHandler = ProfessionalAudioHandler();
    await audioHandler.initialize();
  } catch (e) {
    throw AppInitializationException('Failed to initialize audio handler: $e');
  }
}

Widget _buildErrorApp(String error) {
  return MaterialApp(
    title: 'Music Player - Error',
    theme: ThemeData.dark(),
    home: ErrorScreen(
      error: error,
      onRetry: () async {
        // Restart the app
        SystemNavigator.pop();
      },
    ),
    debugShowCheckedModeBanner: false,
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Music Player',
      theme: _buildTheme(),
      home: const LoadingScreen(),
      debugShowCheckedModeBanner: false,
      // Add global error handling for widget builds
      builder: (context, child) {
        ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
          return _buildErrorWidget(errorDetails);
        };
        return child ?? const SizedBox.shrink();
      },
      // Handle navigation errors
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const ErrorScreen(
            error: 'Page not found',
          ),
        );
      },
    );
  }

  ThemeData _buildTheme() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.grey,
        thumbColor: Colors.white,
        overlayColor: Colors.white.withValues(alpha: 0.2),
      ),
      // Add consistent color scheme
      colorScheme: ColorScheme.dark(
        primary: const Color(0xFF00E676),
        secondary: const Color(0xFF00C853),
        surface: const Color(0xFF1A1A1A),
        error: Colors.red.shade400,
      ),
    );
  }

  Widget _buildErrorWidget(FlutterErrorDetails errorDetails) {
    return Material(
      child: Container(
        color: Colors.red.shade900,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Something went wrong',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  kDebugMode ? errorDetails.exception.toString() : 'Please restart the app',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom exception for app initialization errors
class AppInitializationException implements Exception {
  final String message;
  
  const AppInitializationException(this.message);
  
  @override
  String toString() => 'AppInitializationException: $message';
}

// Provider for logging service
final loggingServiceProvider = Provider<LoggingService>((ref) {
  throw UnimplementedError('LoggingService must be initialized in main()');
});
