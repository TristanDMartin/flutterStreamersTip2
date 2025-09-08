import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CommentsViewStateManager extends ChangeNotifier {
  static final CommentsViewStateManager _instance = CommentsViewStateManager._internal();
  static CommentsViewStateManager get shared => _instance;
  
  bool _isCommentsViewActive = false;
  String? _currentVideoId;
  String? _currentVideoCaption;
  String? _currentVideoCreatorUsername;
  
  // Persistence keys
  static const String _isActiveKey = "CommentsViewIsActive";
  static const String _videoIdKey = "CommentsViewVideoId";
  static const String _videoCaptionKey = "CommentsViewVideoCaption";
  static const String _creatorUsernameKey = "CommentsViewCreatorUsername";
  
  // Getters
  bool get isCommentsViewActive => _isCommentsViewActive;
  String? get currentVideoId => _currentVideoId;
  String? get currentVideoCaption => _currentVideoCaption;
  String? get currentVideoCreatorUsername => _currentVideoCreatorUsername;
  
  CommentsViewStateManager._internal() {
    _loadState();
  }
  
  void activateCommentsView({
    required String videoId,
    required String videoCaption,
    required String creatorUsername,
  }) {
    _isCommentsViewActive = true;
    _currentVideoId = videoId;
    _currentVideoCaption = videoCaption;
    _currentVideoCreatorUsername = creatorUsername;
    _saveState();
    notifyListeners();
  }
  
  void deactivateCommentsView() {
    _isCommentsViewActive = false;
    _currentVideoId = null;
    _currentVideoCaption = null;
    _currentVideoCreatorUsername = null;
    _saveState();
    notifyListeners();
  }
  
  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isActiveKey, _isCommentsViewActive);
      await prefs.setString(_videoIdKey, _currentVideoId ?? '');
      await prefs.setString(_videoCaptionKey, _currentVideoCaption ?? '');
      await prefs.setString(_creatorUsernameKey, _currentVideoCreatorUsername ?? '');
    } catch (e) {
      print("❌ Error saving CommentsViewStateManager state: $e");
    }
  }
  
  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isCommentsViewActive = prefs.getBool(_isActiveKey) ?? false;
      _currentVideoId = prefs.getString(_videoIdKey);
      _currentVideoCaption = prefs.getString(_videoCaptionKey);
      _currentVideoCreatorUsername = prefs.getString(_creatorUsernameKey);
    } catch (e) {
      print("❌ Error loading CommentsViewStateManager state: $e");
    }
  }
  
  Future<void> clearState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_isActiveKey);
      await prefs.remove(_videoIdKey);
      await prefs.remove(_videoCaptionKey);
      await prefs.remove(_creatorUsernameKey);
      await _loadState();
      notifyListeners();
    } catch (e) {
      print("❌ Error clearing CommentsViewStateManager state: $e");
    }
  }
}
