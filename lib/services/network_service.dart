import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'logging_service.dart';

enum NetworkStatus { connected, disconnected, unknown }

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final LoggingService _loggingService = LoggingService();
  final Connectivity _connectivity = Connectivity();
  
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  final StreamController<NetworkStatus> _networkStatusController = 
      StreamController<NetworkStatus>.broadcast();
  
  NetworkStatus _currentStatus = NetworkStatus.unknown;
  bool _isInitialized = false;

  /// Get current network status
  NetworkStatus get currentStatus => _currentStatus;
  
  /// Stream of network status changes
  Stream<NetworkStatus> get networkStatusStream => _networkStatusController.stream;
  
  /// Check if device is currently connected to internet
  bool get isConnected => _currentStatus == NetworkStatus.connected;

  /// Initialize the network service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _loggingService.logInfo('Initializing network service');
      
      // Check initial connectivity
      await _checkConnectivity();
      
      // Listen to connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _onConnectivityChanged,
        onError: (error, stackTrace) {
          _loggingService.logError('Connectivity stream error', error, stackTrace);
        },
      );
      
      _isInitialized = true;
      _loggingService.logInfo('Network service initialized');
      
    } catch (e, stackTrace) {
      _loggingService.logError('Failed to initialize network service', e, stackTrace);
      rethrow;
    }
  }

  /// Check current connectivity status
  Future<void> _checkConnectivity() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      _updateNetworkStatus(_getNetworkStatusFromResult(connectivityResult));
    } catch (e, stackTrace) {
      _loggingService.logError('Error checking connectivity', e, stackTrace);
      _updateNetworkStatus(NetworkStatus.unknown);
    }
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(ConnectivityResult result) {
    try {
      final newStatus = _getNetworkStatusFromResult(result);
      _updateNetworkStatus(newStatus);
    } catch (e, stackTrace) {
      _loggingService.logError('Error handling connectivity change', e, stackTrace);
    }
  }

  /// Convert ConnectivityResult to NetworkStatus
  NetworkStatus _getNetworkStatusFromResult(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
      case ConnectivityResult.mobile:
      case ConnectivityResult.ethernet:
        return NetworkStatus.connected;
      case ConnectivityResult.none:
        return NetworkStatus.disconnected;
      default:
        return NetworkStatus.unknown;
    }
  }

  /// Update network status and notify listeners
  void _updateNetworkStatus(NetworkStatus newStatus) {
    if (_currentStatus != newStatus) {
      final previousStatus = _currentStatus;
      _currentStatus = newStatus;
      
      _loggingService.logInfo('Network status changed: $previousStatus -> $newStatus');
      
      if (!_networkStatusController.isClosed) {
        _networkStatusController.add(newStatus);
      }
    }
  }

  /// Test internet connectivity by attempting to connect to a reliable host
  Future<bool> testInternetConnection() async {
    try {
      _loggingService.logDebug('Testing internet connection');
      
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      
      final hasConnection = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      
      _loggingService.logDebug('Internet connection test result: $hasConnection');
      return hasConnection;
    } catch (e) {
      _loggingService.logWarning('Internet connection test failed: $e');
      return false;
    }
  }

  /// Get detailed network information
  Future<Map<String, dynamic>> getNetworkInfo() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      
      return {
        'status': _currentStatus.toString(),
        'connectivityResult': connectivityResult.toString(),
        'isConnected': isConnected,
        'timestamp': DateTime.now().toIso8601String(),
        'hasInternetAccess': await testInternetConnection(),
      };
    } catch (e, stackTrace) {
      _loggingService.logError('Error getting network info', e, stackTrace);
      return {
        'error': e.toString(),
        'status': _currentStatus.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Wait for network connection with timeout
  Future<bool> waitForConnection({Duration timeout = const Duration(seconds: 10)}) async {
    if (isConnected) return true;
    
    try {
      _loggingService.logInfo('Waiting for network connection...');
      
      final completer = Completer<bool>();
      late StreamSubscription subscription;
      
      subscription = networkStatusStream.listen((status) {
        if (status == NetworkStatus.connected) {
          if (!completer.isCompleted) {
            completer.complete(true);
          }
          subscription.cancel();
        }
      });
      
      // Set timeout
      Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
        subscription.cancel();
      });
      
      final result = await completer.future;
      _loggingService.logInfo('Wait for connection result: $result');
      return result;
      
    } catch (e, stackTrace) {
      _loggingService.logError('Error waiting for connection', e, stackTrace);
      return false;
    }
  }

  /// Dispose the network service
  Future<void> dispose() async {
    try {
      _loggingService.logInfo('Disposing network service');
      
      await _connectivitySubscription?.cancel();
      await _networkStatusController.close();
      await _errorSubject.close();
      
      _isInitialized = false;
      _loggingService.logInfo('Network service disposed');
    } catch (e, stackTrace) {
      _loggingService.logError('Error disposing network service', e, stackTrace);
    }
  }
}
