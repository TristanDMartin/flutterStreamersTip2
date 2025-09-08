import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/connection.dart';

class ConnectionNotifier extends StateNotifier<List<Connection>> {
  ConnectionNotifier() : super(_createSampleConnections());

  static List<Connection> _createSampleConnections() {
    return [
      Connection(
        id: '1',
        displayName: 'Chili',
        username: 'chili_user',
        avatarUrl: 'https://picsum.photos/200/200?random=1',
        isOnline: true,
        lastSeen: DateTime.now(),
      ),
      Connection(
        id: '2',
        displayName: 'Nikole Glenn',
        username: 'nikole_glenn',
        avatarUrl: 'https://picsum.photos/200/200?random=2',
        isOnline: false,
        lastSeen: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Connection(
        id: '3',
        displayName: 'BrowardSh awty',
        username: 'browardsh_awty',
        avatarUrl: 'https://picsum.photos/200/200?random=3',
        isOnline: true,
        lastSeen: DateTime.now(),
      ),
      Connection(
        id: '4',
        displayName: '快乐按钮',
        username: 'happy_button',
        avatarUrl: 'https://picsum.photos/200/200?random=4',
        isOnline: false,
        lastSeen: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      Connection(
        id: '5',
        displayName: 'Alex Chen',
        username: 'alex_chen',
        avatarUrl: 'https://picsum.photos/200/200?random=5',
        isOnline: true,
        lastSeen: DateTime.now(),
      ),
      Connection(
        id: '6',
        displayName: 'Sarah Wilson',
        username: 'sarah_wilson',
        avatarUrl: 'https://picsum.photos/200/200?random=6',
        isOnline: false,
        lastSeen: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ];
  }

  void addConnection(Connection connection) {
    state = [...state, connection];
  }

  void removeConnection(String connectionId) {
    state = state.where((connection) => connection.id != connectionId).toList();
  }

  void updateConnectionStatus(String connectionId, bool isOnline) {
    state = state.map((connection) {
      if (connection.id == connectionId) {
        return connection.copyWith(
          isOnline: isOnline,
          lastSeen: DateTime.now(),
        );
      }
      return connection;
    }).toList();
  }
}

final connectionsProvider = StateNotifierProvider<ConnectionNotifier, List<Connection>>(
  (ref) => ConnectionNotifier(),
);
