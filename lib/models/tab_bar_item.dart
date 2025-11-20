
enum TabBarItem {
  home(0),
  discover(1),
  post(2),
  inbox(3),
  profile(4);

  const TabBarItem(this.value);
  final int value;

  String get title {
    switch (this) {
      case TabBarItem.home:
        return 'Home';
      case TabBarItem.discover:
        return 'Discover';
      case TabBarItem.post:
        return 'Post';
      case TabBarItem.inbox:
        return 'Inbox';
      case TabBarItem.profile:
        return 'Profile';
    }
  }

  static TabBarItem fromValue(int value) {
    switch (value) {
      case 0:
        return TabBarItem.home;
      case 1:
        return TabBarItem.discover;
      case 2:
        return TabBarItem.post;
      case 3:
        return TabBarItem.inbox;
      case 4:
        return TabBarItem.profile;
      default:
        return TabBarItem.home;
    }
  }
}
