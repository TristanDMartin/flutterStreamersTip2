import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../providers/discover_provider.dart';
import 'search_results_view.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _controller.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    // Set new timer for debounced search
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        ref.read(discoverProvider.notifier).search(query);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoverProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6137EB), // Purple (matches ProfileView)
              Color(0xFF1C135D), // Dark purple (matches ProfileView)
            ],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Search creators, videos, categories…',
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
              ),
              onChanged: _onSearchChanged,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.white),
                onPressed: () {
                  _controller.clear();
                  _debounceTimer?.cancel(); // Cancel any pending search
                  ref.read(discoverProvider.notifier).search('');
                },
              )
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Show loading indicator only when actually searching
                if (state.isSearching)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                // Always show search results (empty list when no search)
                Expanded(
                  child: SearchResultsView(
                    searchText: _controller.text, 
                    viewModel: ref.read(discoverProvider.notifier)
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
