import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/logging_service.dart';

class LazyLoadingList<T> extends ConsumerStatefulWidget {
  final Future<List<T>> Function(int page, int limit) loadData;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, String error)? errorBuilder;
  final int itemsPerPage;
  final ScrollController? scrollController;
  final EdgeInsets? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final Axis scrollDirection;
  final Duration loadingDelay;

  const LazyLoadingList({
    super.key,
    required this.loadData,
    required this.itemBuilder,
    this.emptyBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.itemsPerPage = 20,
    this.scrollController,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.scrollDirection = Axis.vertical,
    this.loadingDelay = const Duration(milliseconds: 300),
  });

  @override
  ConsumerState<LazyLoadingList<T>> createState() => _LazyLoadingListState<T>();
}

class _LazyLoadingListState<T> extends ConsumerState<LazyLoadingList<T>> {
  final List<T> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  bool _hasError = false;
  String? _errorMessage;
  int _currentPage = 0;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }

  Future<void> _loadInitialData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      await Future.delayed(widget.loadingDelay);

      final newItems = await widget.loadData(0, widget.itemsPerPage);

      setState(() {
        _items.clear();
        _items.addAll(newItems);
        _currentPage = 0;
        _hasMore = newItems.length == widget.itemsPerPage;
        _isLoading = false;
      });

      LoggingService.instance.debug(
        'Initial data loaded: ${newItems.length} items',
        tag: 'LazyLoadingList',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to load initial data',
        tag: 'LazyLoadingList',
        error: e,
        stackTrace: stackTrace,
      );

      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final newItems = await widget.loadData(nextPage, widget.itemsPerPage);

      setState(() {
        _items.addAll(newItems);
        _currentPage = nextPage;
        _hasMore = newItems.length == widget.itemsPerPage;
        _isLoading = false;
      });

      LoggingService.instance.debug(
        'More data loaded: ${newItems.length} items (page $nextPage)',
        tag: 'LazyLoadingList',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to load more data',
        tag: 'LazyLoadingList',
        error: e,
        stackTrace: stackTrace,
      );

      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> refresh() async {
    await _loadInitialData();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.errorBuilder?.call(context, _errorMessage!) ??
          _buildDefaultErrorWidget();
    }

    if (_items.isEmpty && _isLoading) {
      return widget.loadingBuilder?.call(context) ??
          _buildDefaultLoadingWidget();
    }

    if (_items.isEmpty && !_isLoading) {
      return widget.emptyBuilder?.call(context) ?? _buildDefaultEmptyWidget();
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: widget.padding,
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics,
        scrollDirection: widget.scrollDirection,
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return _buildLoadingIndicator();
          }
          return widget.itemBuilder(context, _items[index], index);
        },
      ),
    );
  }

  Widget _buildDefaultErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Unknown error',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadInitialData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading...'),
        ],
      ),
    );
  }

  Widget _buildDefaultEmptyWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text('No items found'),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    if (!_isLoading) return const SizedBox.shrink();

    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

// Lazy Loading Grid
class LazyLoadingGrid<T> extends ConsumerStatefulWidget {
  final Future<List<T>> Function(int page, int limit) loadData;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, String error)? errorBuilder;
  final int itemsPerPage;
  final ScrollController? scrollController;
  final EdgeInsets? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final Duration loadingDelay;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;

  const LazyLoadingGrid({
    super.key,
    required this.loadData,
    required this.itemBuilder,
    this.emptyBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.itemsPerPage = 20,
    this.scrollController,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.loadingDelay = const Duration(milliseconds: 300),
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 8.0,
    this.mainAxisSpacing = 8.0,
    this.childAspectRatio = 1.0,
  });

  @override
  ConsumerState<LazyLoadingGrid<T>> createState() => _LazyLoadingGridState<T>();
}

class _LazyLoadingGridState<T> extends ConsumerState<LazyLoadingGrid<T>> {
  final List<T> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  bool _hasError = false;
  String? _errorMessage;
  int _currentPage = 0;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }

  Future<void> _loadInitialData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      await Future.delayed(widget.loadingDelay);

      final newItems = await widget.loadData(0, widget.itemsPerPage);

      setState(() {
        _items.clear();
        _items.addAll(newItems);
        _currentPage = 0;
        _hasMore = newItems.length == widget.itemsPerPage;
        _isLoading = false;
      });

      LoggingService.instance.debug(
        'Initial grid data loaded: ${newItems.length} items',
        tag: 'LazyLoadingGrid',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to load initial grid data',
        tag: 'LazyLoadingGrid',
        error: e,
        stackTrace: stackTrace,
      );

      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final newItems = await widget.loadData(nextPage, widget.itemsPerPage);

      setState(() {
        _items.addAll(newItems);
        _currentPage = nextPage;
        _hasMore = newItems.length == widget.itemsPerPage;
        _isLoading = false;
      });

      LoggingService.instance.debug(
        'More grid data loaded: ${newItems.length} items (page $nextPage)',
        tag: 'LazyLoadingGrid',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to load more grid data',
        tag: 'LazyLoadingGrid',
        error: e,
        stackTrace: stackTrace,
      );

      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> refresh() async {
    await _loadInitialData();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.errorBuilder?.call(context, _errorMessage!) ??
          _buildDefaultErrorWidget();
    }

    if (_items.isEmpty && _isLoading) {
      return widget.loadingBuilder?.call(context) ??
          _buildDefaultLoadingWidget();
    }

    if (_items.isEmpty && !_isLoading) {
      return widget.emptyBuilder?.call(context) ?? _buildDefaultEmptyWidget();
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: GridView.builder(
        controller: _scrollController,
        padding: widget.padding,
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.crossAxisCount,
          crossAxisSpacing: widget.crossAxisSpacing,
          mainAxisSpacing: widget.mainAxisSpacing,
          childAspectRatio: widget.childAspectRatio,
        ),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return _buildLoadingIndicator();
          }
          return widget.itemBuilder(context, _items[index], index);
        },
      ),
    );
  }

  Widget _buildDefaultErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Unknown error',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadInitialData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading...'),
        ],
      ),
    );
  }

  Widget _buildDefaultEmptyWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text('No items found'),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    if (!_isLoading) return const SizedBox.shrink();

    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
