import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/post_counter_service.dart';
import '../services/debug_post_count.dart';

/// Widget to fix post count discrepancies
///
/// This widget provides a simple interface to reconcile post counts
/// and fix any discrepancies between actual posts and the counter.
class PostCountFixWidget extends StatefulWidget {
  const PostCountFixWidget({super.key});

  @override
  State<PostCountFixWidget> createState() => _PostCountFixWidgetState();
}

class _PostCountFixWidgetState extends State<PostCountFixWidget> {
  final PostCounterService _postCounter = PostCounterService();
  final DebugPostCount _debug = DebugPostCount();
  bool _isFixing = false;
  String _status = '';
  int _currentCount = 0;
  int _actualCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCurrentStatus();
  }

  Future<void> _loadCurrentStatus() async {
    setState(() {
      _status = 'Loading current status...';
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _status = 'Error: Not authenticated';
        });
        return;
      }

      final stats = await _postCounter.getPostCountStats(userId);

      setState(() {
        _currentCount = stats['currentCount'] ?? 0;
        _status = 'Current counter: $_currentCount posts';
      });
    } catch (e) {
      setState(() {
        _status = 'Error loading status: $e';
      });
    }
  }

  Future<void> _fixPostCount() async {
    setState(() {
      _isFixing = true;
      _status = 'Fixing post count...';
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _status = '❌ Not authenticated';
          _isFixing = false;
        });
        return;
      }

      final count = await _postCounter.reconcilePostCount(userId);

      setState(() {
        _currentCount = count;
        _actualCount = count;
        _status = '✅ Post count fixed to $count posts!';
      });

      // Reload status to show updated count
      await Future.delayed(const Duration(seconds: 1));
      await _loadCurrentStatus();
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isFixing = false;
      });
    }
  }

  Future<void> _runDebug() async {
    setState(() {
      _status = 'Running debug analysis...';
    });

    try {
      await _debug.debugCurrentUser();
      setState(() {
        _status = 'Debug complete - check console for details';
      });
    } catch (e) {
      setState(() {
        _status = 'Debug error: $e';
      });
    }
  }

  Future<void> _simpleFix() async {
    setState(() {
      _isFixing = true;
      _status = 'Running simple fix...';
    });

    try {
      final success = await _debug.simpleFix();

      if (success) {
        setState(() {
          _status = '✅ Simple fix completed!';
        });

        // Reload status
        await Future.delayed(const Duration(seconds: 1));
        await _loadCurrentStatus();
      } else {
        setState(() {
          _status = '❌ Simple fix failed';
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ Simple fix error: $e';
      });
    } finally {
      setState(() {
        _isFixing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔧 Post Count Fix',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _status,
              style: TextStyle(
                color: _status.contains('✅')
                    ? Colors.green
                    : _status.contains('❌')
                        ? Colors.red
                        : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isFixing ? null : _fixPostCount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9248D2),
                      foregroundColor: Colors.white,
                    ),
                    child: _isFixing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Fix Post Count'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isFixing ? null : _loadCurrentStatus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isFixing ? null : _simpleFix,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Simple Fix'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isFixing ? null : _runDebug,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Debug'),
                ),
              ],
            ),
            if (_currentCount != _actualCount) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '⚠️ Discrepancy Detected',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Current counter: $_currentCount'),
                    Text('Actual posts: $_actualCount'),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap "Fix Post Count" to reconcile the difference.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
