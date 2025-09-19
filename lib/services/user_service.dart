class UserService {
  Future<List<String>> getFollowingIds() async {
    // Placeholder - would fetch following IDs from Firestore
    await Future.delayed(const Duration(milliseconds: 300)); // Simulate network delay
    
    // Return empty list for now
    return [];
  }
}
