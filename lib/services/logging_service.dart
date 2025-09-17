import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

enum LogLevel { debug, info, warning, error, fatal }

class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  late File _logFile;
  final _logController = StreamController<LogEntry>.broadcast();
  bool _isInitialized = false;
  final _dateFormatter = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
  
  // Maximum log file size (5MB)
  static const int _maxLogFileSize = 5 * 1024 * 1024;
  
  // Maximum number of log files to keep
  static const int _maxLogFiles = 5;

  Stream<LogEntry> get logStream => _logController.stream;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${appDir.path}/logs');
      
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }
      
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      _logFile = File('${logsDir.path}/app_$dateStr.log');
      
      // Rotate logs if necessary
      await _rotateLogs(logsDir);
      
      _isInitialized = true;
      
      // Log initialization
      logInfo('LoggingService initialized');
      
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize logging service: $e');
      }
      // Continue without file logging if initialization fails
      _isInitialized = true;
    }
  }

  Future<void> _rotateLogs(Directory logsDir) async {
    try {
      final logFiles = await logsDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.log'))
          .cast<File>()
          .toList();
      
      // Sort by modification time (newest first)
      logFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      
      // Remove old log files
      if (logFiles.length > _maxLogFiles) {
        for (int i = _maxLogFiles; i < logFiles.length; i++) {
          try {
            await logFiles[i].delete();
          } catch (e) {
            if (kDebugMode) {
              print('Failed to delete old log file: $e');
            }
          }
        }
      }
      
      // Check if current log file is too large
      if (await _logFile.exists()) {
        final fileSize = await _logFile.length();
        if (fileSize > _maxLogFileSize) {
          // Archive current log file
          final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
          final archivePath = '${_logFile.path}.archived_$timestamp';
          await _logFile.rename(archivePath);
          
          // Create new log file
          _logFile = File(_logFile.path);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to rotate logs: $e');
      }
    }
  }

  void logDebug(String message, [Object? data]) {
    _log(LogLevel.debug, message, data: data);
  }

  void logInfo(String message, [Object? data]) {
    _log(LogLevel.info, message, data: data);
  }

  void logWarning(String message, [Object? data]) {
    _log(LogLevel.warning, message, data: data);
  }

  void logError(String message, Object? error, [StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error: error, stackTrace: stackTrace);
  }

  void logFatal(String message, Object? error, [StackTrace? stackTrace]) {
    _log(LogLevel.fatal, message, error: error, stackTrace: stackTrace);
  }

  void _log(
    LogLevel level,
    String message, {
    Object? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final timestamp = DateTime.now();
    final entry = LogEntry(
      timestamp: timestamp,
      level: level,
      message: message,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );

    // Add to stream
    _logController.add(entry);

    // Console logging (debug mode only)
    if (kDebugMode) {
      _printToConsole(entry);
    }

    // File logging (async to avoid blocking)
    if (_isInitialized) {
      _writeToFile(entry).catchError((e) {
        if (kDebugMode) {
          print('Failed to write log to file: $e');
        }
      });
    }
  }

  void _printToConsole(LogEntry entry) {
    final levelStr = entry.level.name.toUpperCase().padRight(7);
    final timeStr = _dateFormatter.format(entry.timestamp);
    
    String output = '[$levelStr] $timeStr: ${entry.message}';
    
    if (entry.data != null) {
      output += '\n  Data: ${entry.data}';
    }
    
    if (entry.error != null) {
      output += '\n  Error: ${entry.error}';
    }
    
    if (entry.stackTrace != null) {
      output += '\n  Stack: ${entry.stackTrace}';
    }
    
    print(output);
  }

  Future<void> _writeToFile(LogEntry entry) async {
    try {
      final levelStr = entry.level.name.toUpperCase().padRight(7);
      final timeStr = _dateFormatter.format(entry.timestamp);
      
      String logLine = '[$levelStr] $timeStr: ${entry.message}';
      
      if (entry.data != null) {
        logLine += ' | Data: ${_sanitizeForLog(entry.data)}';
      }
      
      if (entry.error != null) {
        logLine += ' | Error: ${_sanitizeForLog(entry.error)}';
      }
      
      if (entry.stackTrace != null) {
        logLine += '\nStack: ${entry.stackTrace}';
      }
      
      logLine += '\n';
      
      await _logFile.writeAsString(logLine, mode: FileMode.append);
      
    } catch (e) {
      // Silently fail file logging to avoid infinite loops
      if (kDebugMode) {
        print('Failed to write to log file: $e');
      }
    }
  }

  String _sanitizeForLog(Object? obj) {
    if (obj == null) return 'null';
    
    try {
      // Try to convert to JSON for structured data
      if (obj is Map || obj is List) {
        return jsonEncode(obj);
      }
      return obj.toString();
    } catch (e) {
      // Fallback to toString if JSON encoding fails
      return obj.toString();
    }
  }

  Future<List<LogEntry>> getRecentLogs({int limit = 100}) async {
    try {
      if (!await _logFile.exists()) return [];
      
      final lines = await _logFile.readAsLines();
      final entries = <LogEntry>[];
      
      // Parse recent log entries (simplified parsing)
      for (final line in lines.take(limit)) {
        try {
          final entry = _parseLogLine(line);
          if (entry != null) {
            entries.add(entry);
          }
        } catch (e) {
          // Skip invalid log lines
        }
      }
      
      return entries.reversed.toList();
    } catch (e) {
      return [];
    }
  }

  LogEntry? _parseLogLine(String line) {
    // Simplified log parsing - in production, you might want more robust parsing
    final regex = RegExp(r'\[(\w+)\s*\] ([\d-: .]+): (.+)');
    final match = regex.firstMatch(line);
    
    if (match == null) return null;
    
    final levelStr = match.group(1)?.toLowerCase();
    final timeStr = match.group(2);
    final message = match.group(3);
    
    if (levelStr == null || timeStr == null || message == null) return null;
    
    LogLevel? level;
    for (final l in LogLevel.values) {
      if (l.name == levelStr) {
        level = l;
        break;
      }
    }
    
    if (level == null) return null;
    
    DateTime? timestamp;
    try {
      timestamp = _dateFormatter.parse(timeStr);
    } catch (e) {
      timestamp = DateTime.now();
    }
    
    return LogEntry(
      timestamp: timestamp,
      level: level,
      message: message,
    );
  }

  Future<void> clearLogs() async {
    try {
      if (await _logFile.exists()) {
        await _logFile.delete();
      }
      logInfo('Log files cleared');
    } catch (e) {
      logError('Failed to clear logs', e);
    }
  }

  void dispose() {
    _logController.close();
  }
}

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final Object? data;
  final Object? error;
  final StackTrace? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.data,
    this.error,
    this.stackTrace,
  });

  @override
  String toString() {
    return 'LogEntry(${level.name}: $message)';
  }
}
