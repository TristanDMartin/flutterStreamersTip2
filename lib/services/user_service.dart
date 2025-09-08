class UserService {
  Future<List<String>> getFollowingIds() async {
    // TODO: Implement actual Firestore fetch
    await Future.delayed(const Duration(milliseconds: 300)); // Simulate network delay
    
    // Return empty list for now
    return [];
  }
}
