import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/logging_service.dart';

class ErrorScreen extends ConsumerStatefulWidget {
  final String error;
  final VoidCallback? onRetry;
  final bool showDetails;

  const ErrorScreen({
    super.key,
    required this.error,
    this.onRetry,
    this.showDetails = false,
  });

  @override
  ConsumerState<ErrorScreen> createState() => _ErrorScreenState();
}

class _ErrorScreenState extends ConsumerState<ErrorScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _showDetails = false;
  List<LogEntry> _recentLogs = [];

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
    _loadRecentLogs();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentLogs() async {
    try {
      final loggingService = LoggingService();
      final logs = await loggingService.getRecentLogs(limit: 20);
      if (mounted) {
        setState(() {
          _recentLogs = logs;
        });
      }
    } catch (e) {
      // Ignore errors when loading logs
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildErrorIcon(),
                        const SizedBox(height: 32),
                        _buildErrorTitle(),
                        const SizedBox(height: 16),
                        _buildErrorMessage(),
                        const SizedBox(height: 32),
                        _buildActionButtons(),
                        if (widget.showDetails || _showDetails) ...[
                          const SizedBox(height: 24),
                          _buildDetailsSection(),
                        ],
                      ],
                    ),
                  ),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorIcon() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.red.shade400,
            Colors.red.shade600,
            Colors.red.shade800,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.shade400.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Icon(
        Icons.error_outline_rounded,
        color: Colors.white,
        size: 60,
      ),
    );
  }

  Widget _buildErrorTitle() {
    return const Text(
      'Something went wrong',
      style: TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.w300,
        letterSpacing: 1.2,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[800]!,
          width: 1,
        ),
      ),
      child: Text(
        _getDisplayError(),
        style: TextStyle(
          color: Colors.grey[300],
          fontSize: 16,
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _getDisplayError() {
    // Sanitize error message for user display
    if (widget.error.toLowerCase().contains('permission')) {
      return 'The app needs permission to access your music files. Please grant the required permissions and try again.';
    } else if (widget.error.toLowerCase().contains('storage') || 
               widget.error.toLowerCase().contains('hive')) {
      return 'There was a problem accessing the app\'s storage. Please ensure you have enough free space and try again.';
    } else if (widget.error.toLowerCase().contains('audio')) {
      return 'Audio system initialization failed. Please check if other apps are using audio and try again.';
    } else if (widget.error.toLowerCase().contains('network')) {
      return 'Network connection issue. Please check your internet connection and try again.';
    }
    
    // Generic error message for production
    return 'The app encountered an unexpected error. Please try restarting the app.';
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        if (widget.onRetry != null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _showDetails = !_showDetails;
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.grey[700]!),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _showDetails ? 'Hide Details' : 'Show Details',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () {
              SystemNavigator.pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[400],
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'Close App',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[800]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Error Details',
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: _copyErrorToClipboard,
                icon: const Icon(Icons.copy, size: 20),
                color: Colors.grey[400],
                tooltip: 'Copy error details',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              widget.error,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
          if (_recentLogs.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Recent Logs',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _recentLogs.length,
                itemBuilder: (context, index) {
                  final log = _recentLogs[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${log.level.name.toUpperCase()}: ${log.message}',
                      style: TextStyle(
                        color: _getLogColor(log.level),
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getLogColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey[500]!;
      case LogLevel.info:
        return Colors.blue[300]!;
      case LogLevel.warning:
        return Colors.orange[300]!;
      case LogLevel.error:
        return Colors.red[300]!;
      case LogLevel.fatal:
        return Colors.red[600]!;
    }
  }

  Widget _buildFooter() {
    return Text(
      'If this problem persists, please contact support',
      style: TextStyle(
        color: Colors.grey[600],
        fontSize: 12,
      ),
      textAlign: TextAlign.center,
    );
  }

  void _copyErrorToClipboard() {
    final errorDetails = '''
Error: ${widget.error}
Timestamp: ${DateTime.now().toIso8601String()}
Recent Logs:
${_recentLogs.map((log) => '${log.level.name.toUpperCase()}: ${log.message}').join('\n')}
''';
    
    Clipboard.setData(ClipboardData(text: errorDetails));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Error details copied to clipboard'),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
