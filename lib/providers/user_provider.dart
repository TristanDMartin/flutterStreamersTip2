import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

part 'user_provider.freezed.dart';

@freezed
sealed class UserState with _$UserState {
  const factory UserState({
    String? currentUserId,
    User? currentUser,
    @Default({}) Map<String, User> users,
    String? error,
  }) = _UserState;
}

class UserNotifier extends StateNotifier<UserState> {
  UserNotifier() : super(const UserState());

  void setAuthService(AuthenticationService authService) {
    // This will be handled by ref.listen in the provider
  }

  void updateUser(User user) {
    state = state.copyWith(
      users: {...state.users, user.id: user},
      currentUser: user.id == state.currentUserId ? user : state.currentUser,
    );
  }

  User? getUser(String userId) {
    return state.users[userId];
  }

  List<String> get followingIds {
    // Mock implementation - replace with actual logic
    return ['user_1', 'user_2', 'user_3'];
  }

  bool isUserOnline(String userId) {
    // Mock implementation - replace with actual logic
    return userId == 'user_1' || userId == 'user_2';
  }

  String? get currentUserId => state.currentUserId;
  User? get currentUser => state.currentUser;
}

final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  return UserNotifier();
});
