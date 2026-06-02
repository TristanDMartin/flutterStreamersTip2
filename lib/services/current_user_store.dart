class CurrentUserStore {
  static Map<String, dynamic>? _user;

  static Map<String, dynamic>? get user => _user;

  static void setUser(Map<String, dynamic>? data) {
    _user = data;
  }
}
