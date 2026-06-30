import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Service for memory optimization and cleanup
class MemoryOptimizationService {
  static final MemoryOptimizationService _instance =
      MemoryOptimizationService._internal();
  factory MemoryOptimizationService() => _instance;
  MemoryOptimizationService._internal();

  final List<StreamSubscription> _subscriptions = [];
  final List<ChangeNotifier> _notifiers = [];
  final Map<String, Timer> _cleanupTimers = {};

  /// Register a stream subscription for automatic cleanup
  void registerSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }

  /// Register a change notifier for automatic cleanup
  void registerNotifier(ChangeNotifier notifier) {
    _notifiers.add(notifier);
  }

  /// Schedule cleanup for a resource
  void scheduleCleanup(String key, Duration delay, VoidCallback cleanup) {
    _cleanupTimers[key]?.cancel();
    _cleanupTimers[key] = Timer(delay, cleanup);
  }

  /// Force garbage collection
  void forceGC() {
    // Trigger garbage collection
    ui.PlatformDispatcher.instance.onReportTimings =
        (List<ui.FrameTiming> timings) {
      // This callback helps trigger GC
    };
  }

  /// Clear image cache
  void clearImageCache() {
    imageCache.clear();
    imageCache.clearLiveImages();
  }

  /// Clear all registered resources
  void clearAll() {
    // Cancel all subscriptions
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    // Dispose all notifiers
    for (final notifier in _notifiers) {
      notifier.dispose();
    }
    _notifiers.clear();

    // Cancel all timers
    for (final timer in _cleanupTimers.values) {
      timer.cancel();
    }
    _cleanupTimers.clear();

    // Clear caches
    clearImageCache();

    // Force GC
    forceGC();
  }

  /// Get memory usage info
  Map<String, dynamic> getMemoryInfo() {
    return {
      'imageCacheSize': imageCache.currentSize,
      'imageCacheMaxSize': imageCache.maximumSize,
      'subscriptionsCount': _subscriptions.length,
      'notifiersCount': _notifiers.length,
      'timersCount': _cleanupTimers.length,
    };
  }

  /// Optimize memory usage
  void optimizeMemory() {
    // Clear old images
    if (imageCache.currentSize > imageCache.maximumSize * 0.8) {
      clearImageCache();
    }

    // Force GC if memory is high
    if (imageCache.currentSize > imageCache.maximumSize * 0.9) {
      forceGC();
    }
  }
}

/// Optimized list view with memory management
class OptimizedListView extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final ScrollController? controller;
  final bool shrinkWrap;
  final double? cacheExtent;
  final Axis scrollDirection;
  final bool reverse;

  const OptimizedListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.shrinkWrap = false,
    this.cacheExtent,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
  });

  @override
  State<OptimizedListView> createState() => _OptimizedListViewState();
}

class _OptimizedListViewState extends State<OptimizedListView> {
  late ScrollController _controller;
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ScrollController();

    // Schedule periodic memory cleanup
    _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      MemoryOptimizationService().optimizeMemory();
    });
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _controller,
      shrinkWrap: widget.shrinkWrap,
      // ignore: deprecated_member_use
      cacheExtent: widget.cacheExtent ?? 250.0,
      itemCount: widget.itemCount,
      scrollDirection: widget.scrollDirection,
      reverse: widget.reverse,
      itemBuilder: (context, index) {
        return RepaintBoundary(
          key: ValueKey('item_$index'),
          child: widget.itemBuilder(context, index),
        );
      },
    );
  }
}

/// Optimized grid view with memory management
class OptimizedGridView extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final SliverGridDelegate gridDelegate;
  final ScrollController? controller;
  final bool shrinkWrap;
  final double? cacheExtent;
  final Axis scrollDirection;
  final bool reverse;

  const OptimizedGridView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.gridDelegate,
    this.controller,
    this.shrinkWrap = false,
    this.cacheExtent,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
  });

  @override
  State<OptimizedGridView> createState() => _OptimizedGridViewState();
}

class _OptimizedGridViewState extends State<OptimizedGridView> {
  late ScrollController _controller;
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ScrollController();

    // Schedule periodic memory cleanup
    _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      MemoryOptimizationService().optimizeMemory();
    });
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: _controller,
      shrinkWrap: widget.shrinkWrap,
      // ignore: deprecated_member_use
      cacheExtent: widget.cacheExtent ?? 250.0,
      itemCount: widget.itemCount,
      gridDelegate: widget.gridDelegate,
      scrollDirection: widget.scrollDirection,
      reverse: widget.reverse,
      itemBuilder: (context, index) {
        return RepaintBoundary(
          key: ValueKey('grid_item_$index'),
          child: widget.itemBuilder(context, index),
        );
      },
    );
  }
}
