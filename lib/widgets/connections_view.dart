import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';
import '../models/user.dart';
import 'user_card_view.dart';

class ConnectionsView extends ConsumerStatefulWidget {
  const ConnectionsView({super.key});

  @override
  ConsumerState<ConnectionsView> createState() => _ConnectionsViewState();
}

class _ConnectionsViewState extends ConsumerState<ConnectionsView>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _opacityController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _opacityAnimation;
  
  bool _showGrid = false;

  @override
  void initState() {
    super.initState();
    
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _opacityController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 180.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeInOut,
    ));
    
    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _opacityController,
      curve: Curves.easeInOut,
    ));
    
    // Start animation when view appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animate();
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _opacityController.dispose();
    super.dispose();
  }

  void _animate() {
    _rotationController.forward();
    _opacityController.forward().then((_) {
      setState(() {
        _showGrid = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final userManager = ref.watch(userProvider.notifier);
    final connections = _getConnections(userManager);
    final firstConnection = connections.isNotEmpty ? connections.first : null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Connections',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          if (_showGrid)
            // The main grid view
            _buildConnectionGrid(connections)
          else
            // The animated flip card
            _buildFlipCard(firstConnection),
        ],
      ),
    );
  }

  Widget _buildFlipCard(User? firstConnection) {
    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([_rotationAnimation, _opacityAnimation]),
        builder: (context, child) {
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(_rotationAnimation.value * 3.14159 / 180),
            alignment: Alignment.center,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Container(
                width: 250,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF9248D2), // Purple
                      Color(0xFF7768DF), // Another purple
                      Color(0xFF1670DE), // Blue
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'You and ${firstConnection?.username ?? 'a friend'} are now connected!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnectionGrid(List<User> connections) {
    return AnimatedOpacity(
      opacity: _showGrid ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: connections.length,
        itemBuilder: (context, index) {
          final user = connections[index];
          return GestureDetector(
            onTap: () {
              _showUserProfile(user);
            },
            child: UserCardView(user: user),
          );
        },
      ),
    );
  }

  void _showUserProfile(User user) {
    // TODO: Navigate to StreamerCardView
    // For now, show a simple dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.displayName),
        content: Text('Username: @${user.username}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  List<User> _getConnections(UserNotifier userManager) {
    // TODO: Implement actual connection logic
    // For now, return sample users
    return [
      const User(
        id: 'user_1',
        username: 'johndoe',
        displayName: 'John Doe',
      ),
      const User(
        id: 'user_2',
        username: 'janesmith',
        displayName: 'Jane Smith',
      ),
    ];
  }
}
