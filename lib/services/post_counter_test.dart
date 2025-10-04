import 'package:flutter/foundation.dart';
import 'post_counter_service.dart';

/// Test utility for PostCounterService
///
/// This class provides methods to test the post counter functionality
/// and verify that counts are consistent across different views.
class PostCounterTest {
  static final PostCounterService _postCounterService = PostCounterService();

  /// Test post counting rules
  static void testPostCountingRules() {
    if (kDebugMode) {
      debugPrint('🧪 Testing Post Counting Rules...');

      // Test countable posts
      final countableTests = [
        {'status': 'published', 'privacy': 'public', 'expected': true},
        {'status': 'published', 'privacy': 'followers', 'expected': true},
        {'status': 'public', 'privacy': 'public', 'expected': true},
      ];

      // Test excluded posts
      final excludedTests = [
        {'status': 'draft', 'privacy': 'public', 'expected': false},
        {'status': 'scheduled', 'privacy': 'public', 'expected': false},
        {'status': 'archived', 'privacy': 'public', 'expected': false},
        {'status': 'deleted', 'privacy': 'public', 'expected': false},
        {'status': 'hidden', 'privacy': 'public', 'expected': false},
        {'status': 'moderation', 'privacy': 'public', 'expected': false},
        {'status': 'published', 'privacy': 'private', 'expected': false},
        {'status': 'published', 'privacy': 'friends', 'expected': false},
      ];

      // Run countable tests
      for (final test in countableTests) {
        final result = _shouldCountPost(
            test['status'] as String, test['privacy'] as String);
        final expected = test['expected'] as bool;
        debugPrint(
            '  ✅ ${test['status']}/${test['privacy']}: $result (expected: $expected)');
        assert(result == expected,
            'Countable test failed: ${test['status']}/${test['privacy']}');
      }

      // Run excluded tests
      for (final test in excludedTests) {
        final result = _shouldCountPost(
            test['status'] as String, test['privacy'] as String);
        final expected = test['expected'] as bool;
        debugPrint(
            '  ❌ ${test['status']}/${test['privacy']}: $result (expected: $expected)');
        assert(result == expected,
            'Excluded test failed: ${test['status']}/${test['privacy']}');
      }

      debugPrint('✅ All post counting rules tests passed!');
    }
  }

  /// Test post count operations
  static Future<void> testPostCountOperations(String testUserId) async {
    if (kDebugMode) {
      debugPrint('🧪 Testing Post Count Operations for user: $testUserId');

      try {
        // Get initial count
        final initialCount = await _postCounterService.getPostCount(testUserId);
        debugPrint('  📊 Initial post count: $initialCount');

        // Test increment
        final incrementResult =
            await _postCounterService.incrementPostCount(testUserId);
        debugPrint('  ➕ Increment result: $incrementResult');

        // Verify count increased
        final afterIncrement =
            await _postCounterService.getPostCount(testUserId);
        debugPrint('  📊 After increment: $afterIncrement');
        assert(afterIncrement == initialCount + 1, 'Increment failed');

        // Test decrement
        final decrementResult =
            await _postCounterService.decrementPostCount(testUserId);
        debugPrint('  ➖ Decrement result: $decrementResult');

        // Verify count decreased
        final afterDecrement =
            await _postCounterService.getPostCount(testUserId);
        debugPrint('  📊 After decrement: $afterDecrement');
        assert(afterDecrement == initialCount, 'Decrement failed');

        // Test status change (draft -> published)
        final statusChangeResult = await _postCounterService
            .updatePostCountForStatusChange(testUserId, 'draft', 'published');
        debugPrint('  🔄 Status change result: $statusChangeResult');

        // Verify count increased
        final afterStatusChange =
            await _postCounterService.getPostCount(testUserId);
        debugPrint('  📊 After status change: $afterStatusChange');
        assert(afterStatusChange == initialCount + 1, 'Status change failed');

        // Test privacy change (private -> public)
        final privacyChangeResult = await _postCounterService
            .updatePostCountForPrivacyChange(testUserId, 'private', 'public');
        debugPrint('  🔒 Privacy change result: $privacyChangeResult');

        // Verify count increased
        final afterPrivacyChange =
            await _postCounterService.getPostCount(testUserId);
        debugPrint('  📊 After privacy change: $afterPrivacyChange');
        assert(afterPrivacyChange == initialCount + 2, 'Privacy change failed');

        // Test reconciliation
        final reconciledCount =
            await _postCounterService.reconcilePostCount(testUserId);
        debugPrint('  🔧 Reconciled count: $reconciledCount');

        debugPrint('✅ All post count operations tests passed!');
      } catch (e) {
        debugPrint('❌ Post count operations test failed: $e');
        rethrow;
      }
    }
  }

  /// Test real-time updates
  static Future<void> testRealTimeUpdates(String testUserId) async {
    if (kDebugMode) {
      debugPrint('🧪 Testing Real-Time Updates for user: $testUserId');

      try {
        // Start watching post count
        final stream = _postCounterService.watchPostCount(testUserId);
        int updateCount = 0;
        int? lastCount;

        final subscription = stream.listen(
          (count) {
            updateCount++;
            lastCount = count;
            debugPrint('  📡 Real-time update #$updateCount: $count');
          },
          onError: (error) {
            debugPrint('  ❌ Real-time update error: $error');
          },
        );

        // Wait a bit for initial value
        await Future.delayed(const Duration(milliseconds: 500));

        // Make some changes to trigger updates
        await _postCounterService.incrementPostCount(testUserId);
        await Future.delayed(const Duration(milliseconds: 500));

        await _postCounterService.decrementPostCount(testUserId);
        await Future.delayed(const Duration(milliseconds: 500));

        // Cancel subscription
        await subscription.cancel();

        debugPrint('  📊 Total updates received: $updateCount');
        debugPrint('  📊 Final count: $lastCount');

        assert(updateCount > 0, 'No real-time updates received');
        debugPrint('✅ Real-time updates test passed!');
      } catch (e) {
        debugPrint('❌ Real-time updates test failed: $e');
        rethrow;
      }
    }
  }

  /// Run all tests
  static Future<void> runAllTests(String testUserId) async {
    if (kDebugMode) {
      debugPrint('🚀 Running All Post Counter Tests...');
      debugPrint('=' * 50);

      try {
        testPostCountingRules();
        await testPostCountOperations(testUserId);
        await testRealTimeUpdates(testUserId);

        debugPrint('=' * 50);
        debugPrint('🎉 All tests passed successfully!');
      } catch (e) {
        debugPrint('=' * 50);
        debugPrint('💥 Tests failed: $e');
        rethrow;
      }
    }
  }

  /// Helper method to check if a post should be counted
  static bool _shouldCountPost(String status, String privacy) {
    const countableStatuses = ['published', 'public'];
    const excludedStatuses = [
      'draft',
      'scheduled',
      'archived',
      'deleted',
      'hidden',
      'moderation',
      'private'
    ];
    const countablePrivacyLevels = ['public', 'followers'];

    final statusLower = status.toLowerCase();
    final privacyLower = privacy.toLowerCase();

    return countableStatuses.contains(statusLower) &&
        !excludedStatuses.contains(statusLower) &&
        countablePrivacyLevels.contains(privacyLower);
  }
}
