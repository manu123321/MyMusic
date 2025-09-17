import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/media_controls_test_helper.dart';
import '../providers/music_provider.dart';

/// Debug screen for testing system media controls
class TestMediaControlsScreen extends ConsumerStatefulWidget {
  const TestMediaControlsScreen({super.key});

  @override
  ConsumerState<TestMediaControlsScreen> createState() => _TestMediaControlsScreenState();
}

class _TestMediaControlsScreenState extends ConsumerState<TestMediaControlsScreen> {
  final MediaControlsTestHelper _testHelper = MediaControlsTestHelper();
  Map<String, bool>? _testResults;
  bool _isRunningTests = false;
  String? _testReport;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Controls Test'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.grey[900],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'System Media Controls Test',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This will test notification panel, lock screen, and hardware controls.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            ElevatedButton(
              onPressed: _isRunningTests ? null : _runTests,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isRunningTests
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Running Tests...'),
                      ],
                    )
                  : const Text(
                      'Run Media Controls Test',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
            
            const SizedBox(height: 16),
            
            if (_testResults != null) ...[
              Card(
                color: Colors.grey[900],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Test Results',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._testResults!.entries.map((entry) {
                        final testName = entry.key.replaceAll('_', ' ').toUpperCase();
                        final passed = entry.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                passed ? Icons.check_circle : Icons.error,
                                color: passed ? Colors.green : Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  testName,
                                  style: TextStyle(
                                    color: passed ? Colors.white : Colors.red[300],
                                  ),
                                ),
                              ),
                              Text(
                                passed ? 'PASSED' : 'FAILED',
                                style: TextStyle(
                                  color: passed ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              ElevatedButton(
                onPressed: _showDetailedReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('View Detailed Report'),
              ),
            ],
            
            const SizedBox(height: 24),
            
            Card(
              color: Colors.blue[900]?.withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[300]),
                        const SizedBox(width: 8),
                        Text(
                          'Manual Testing Instructions',
                          style: TextStyle(
                            color: Colors.blue[300],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '1. Run the automated test above first\n'
                      '2. Play a song in the app\n'
                      '3. Pull down notification panel - check media controls\n'
                      '4. Lock your device - verify controls on lock screen\n'
                      '5. Connect Bluetooth headphones - test hardware buttons',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runTests() async {
    setState(() {
      _isRunningTests = true;
      _testResults = null;
    });

    try {
      final audioHandler = ref.read(audioHandlerProvider);
      final results = await _testHelper.runComprehensiveTest(audioHandler);
      final report = _testHelper.generateTestReport(results);
      
      setState(() {
        _testResults = results;
        _testReport = report;
        _isRunningTests = false;
      });

      // Show success/failure snackbar
      if (mounted) {
        final allPassed = results['overall_success'] ?? false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              allPassed 
                  ? '✅ All tests passed! Media controls are working.'
                  : '⚠️ Some tests failed. Check the results above.',
            ),
            backgroundColor: allPassed ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }

    } catch (e) {
      setState(() {
        _isRunningTests = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Test failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showDetailedReport() {
    if (_testReport == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Detailed Test Report',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Text(
            _testReport!,
            style: const TextStyle(
              color: Colors.white70,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
