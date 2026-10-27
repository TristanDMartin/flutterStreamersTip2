import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game.dart';
import '../../services/game_service.dart';

Future<Game?> showGamePickerSheet({
  required BuildContext context,
  Game? selectedGame,
}) async {
  return showModalBottomSheet<Game>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _GamePickerSheet(selectedGame: selectedGame),
  );
}

class _GamePickerSheet extends ConsumerStatefulWidget {
  const _GamePickerSheet({this.selectedGame});

  final Game? selectedGame;

  @override
  ConsumerState<_GamePickerSheet> createState() => _GamePickerSheetState();
}

class _GamePickerSheetState extends ConsumerState<_GamePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Game> _games = [];
  List<Game> _filteredGames = [];
  bool _isLoading = true;
  Game? _selectedGame;

  @override
  void initState() {
    super.initState();
    _selectedGame = widget.selectedGame;
    _loadGames();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGames() async {
    setState(() => _isLoading = true);
    try {
      final games = await GameService().getPopularGames(limit: 100);
      if (mounted) {
        setState(() {
          _games = games;
          _filteredGames = games;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _games = GameExtension.samples;
          _filteredGames = GameExtension.samples;
          _isLoading = false;
        });
      }
    }
  }

  void _filterGames(String query) {
    if (query.isEmpty) {
      setState(() => _filteredGames = _games);
      return;
    }
    
    final queryLower = query.toLowerCase();
    setState(() {
      _filteredGames = _games
          .where((game) => game.title.toLowerCase().contains(queryLower))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Select Game',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterGames,
              decoration: InputDecoration(
                hintText: 'Search games...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: isDark 
                    ? Colors.white.withValues(alpha: 0.05) 
                    : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredGames.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.videogame_asset_off,
                              size: 64,
                              color: theme.disabledColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No games found',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.disabledColor,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredGames.length,
                        itemBuilder: (context, index) {
                          final game = _filteredGames[index];
                          final isSelected = _selectedGame?.id == game.id;

                          return ListTile(
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: isDark 
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.grey.shade200,
                              ),
                              child: const Icon(Icons.videogame_asset),
                            ),
                            title: Text(
                              game.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text('${game.clipCount} clips'),
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle,
                                    color: theme.colorScheme.primary,
                                  )
                                : null,
                            onTap: () {
                              Navigator.of(context).pop(game);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
