import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../models/calendar_event.dart';

/// Request-scoped authentication result
class AuthRequestResult {
  final String requestId;
  final bool success;
  final String? error;
  final User? user;

  const AuthRequestResult({
    required this.requestId,
    required this.success,
    this.error,
    this.user,
  });
}

/// Robust authentication service with single-flight, debounced, request-scoped operations
class RobustAuthenticationService extends ChangeNotifier {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? _currentUser;
  bool _isLoggedIn = false;
  bool _isCheckingAuth = false;

  // Request management
  String? _currentRequestId;
  Timer? _debounceTimer;
  Timer? _minimumSpinnerTimer;
  bool _isMinimumSpinnerActive = false;
  
  // Constants
  static const Duration _debounceDelay = Duration(milliseconds: 400);
  static const Duration _minimumSpinnerTime = Duration(milliseconds: 500);

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  bool get isCheckingAuth => _isCheckingAuth;
  bool get isRequestInFlight => _currentRequestId != null;
  
  // Get current user profile data from Firestore
  Map<String, dynamic>? _currentUserProfile;
  Map<String, dynamic>? get currentUserProfile => _currentUserProfile;

  RobustAuthenticationService() {
    _auth.authStateChanges().listen((firebase_auth.User? user) {
    // print("🔄 Auth state changed: ${user != null ? 'Logged in' : 'Logged out'}");
      if (user != null) {
    // print("👤 User: ${user.email} (${user.uid})");
        _handleUserSignIn(user);
      } else {
        _currentUser = null;
        _isLoggedIn = false;
        _isCheckingAuth = false;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _minimumSpinnerTimer?.cancel();
    super.dispose();
  }

  /// Generate a unique request ID
  String _generateRequestId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           (1000 + (DateTime.now().microsecond % 9000)).toString();
  }

  /// Start minimum spinner timer
  void _startMinimumSpinner() {
    _isMinimumSpinnerActive = true;
    _minimumSpinnerTimer?.cancel();
    _minimumSpinnerTimer = Timer(_minimumSpinnerTime, () {
      _isMinimumSpinnerActive = false;
      if (!isRequestInFlight) {
        notifyListeners();
      }
    });
  }

  /// Check if we should show loading state
  bool get shouldShowLoading => isRequestInFlight || _isMinimumSpinnerActive;

  /// Debounced authentication with single-flight protection
  Future<AuthRequestResult> _debouncedAuth(
    String requestType,
    Future<AuthRequestResult> Function(String requestId) authFunction,
  ) async {
    // Cancel any existing debounce timer
    _debounceTimer?.cancel();
    
    // Generate new request ID
    final requestId = _generateRequestId();
    
    // Start debounce timer
    _debounceTimer = Timer(_debounceDelay, () async {
      // Check if this is still the latest request
      if (_currentRequestId != null && _currentRequestId != requestId) {
    // print("🚫 Ignoring stale request: $requestId (current: $_currentRequestId)");
        return;
      }
      
      _currentRequestId = requestId;
      _startMinimumSpinner();
      notifyListeners();
      
      try {
    // print("🚀 Starting $requestType authentication (request: $requestId)");
        final result = await authFunction(requestId);
        
        // Only process if this is still the current request
        if (_currentRequestId == requestId) {
          _currentRequestId = null;
          if (result.success) {
    // print("✅ $requestType authentication successful (request: $requestId)");
          } else {
    // print("❌ $requestType authentication failed: ${result.error} (request: $requestId)");
          }
          notifyListeners();
        } else {
    // print("🚫 Ignoring stale response for request: $requestId");
        }
      } catch (e) {
        // Only process if this is still the current request
        if (_currentRequestId == requestId) {
          _currentRequestId = null;
    // print("❌ $requestType authentication error: $e (request: $requestId)");
          notifyListeners();
        }
      }
    });
    
    // Wait for the debounce delay and then execute
    await Future.delayed(_debounceDelay);
    
    // Check if this is still the latest request
    if (_currentRequestId != null && _currentRequestId != requestId) {
    // print("🚫 Ignoring stale request: $requestId (current: $_currentRequestId)");
      return AuthRequestResult(
        requestId: requestId,
        success: false,
        error: 'Request cancelled',
      );
    }
    
    _currentRequestId = requestId;
    _startMinimumSpinner();
    notifyListeners();
    
    try {
    // print("🚀 Starting $requestType authentication (request: $requestId)");
      final result = await authFunction(requestId);
      
      // Only process if this is still the current request
      if (_currentRequestId == requestId) {
        _currentRequestId = null;
        if (result.success) {
    // print("✅ $requestType authentication successful (request: $requestId)");
        } else {
    // print("❌ $requestType authentication failed: ${result.error} (request: $requestId)");
        }
        notifyListeners();
      } else {
    // print("🚫 Ignoring stale response for request: $requestId");
      }
      
      return result;
    } catch (e) {
      // Only process if this is still the current request
      if (_currentRequestId == requestId) {
        _currentRequestId = null;
    // print("❌ $requestType authentication error: $e (request: $requestId)");
        notifyListeners();
      }
      
      return AuthRequestResult(
        requestId: requestId,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Sign in with email (debounced, single-flight)
  Future<AuthRequestResult> signInWithEmail(
    String email, 
    String password, 
    String requestId,
  ) async {
    try {
    // print("📧 Starting email authentication for: $email (request: $requestId)");
      
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      if (userCredential.user != null) {
        // User will be handled by auth state listener
        return AuthRequestResult(
          requestId: requestId,
          success: true,
          user: _currentUser,
        );
      } else {
        return AuthRequestResult(
          requestId: requestId,
          success: false,
          error: 'Authentication failed',
        );
      }
    } catch (e) {
      return AuthRequestResult(
        requestId: requestId,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Sign in with username (debounced, single-flight)
  Future<AuthRequestResult> signInWithUsername(
    String username, 
    String password, 
    String requestId,
  ) async {
    try {
    // print("🔐 Looking up user by username: $username (request: $requestId)");
      
      // First, find the user by username in Firestore (try both cases)
      QuerySnapshot usersQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      
      // If not found with original case, try lowercase
      if (usersQuery.docs.isEmpty) {
        usersQuery = await _firestore
            .collection('users')
            .where('username', isEqualTo: username.toLowerCase())
            .limit(1)
            .get();
      }
      
      // If still not found, try uppercase
      if (usersQuery.docs.isEmpty) {
        usersQuery = await _firestore
            .collection('users')
            .where('username', isEqualTo: username.toUpperCase())
            .limit(1)
            .get();
      }
      
      if (usersQuery.docs.isEmpty) {
    // print("❌ Username not found: $username (tried original, lowercase, uppercase)");
        
        // Debug: List all usernames in the database
    // print("🔍 Debug: Listing all usernames in database...");
        try {
          final allUsersQuery = await _firestore.collection('users').limit(10).get();
          for (final _ in allUsersQuery.docs) {
            // final data = doc.data();
            // final dbUsername = data['username'] as String?;
            // final dbEmail = data['email'] as String?;
    // print("👤 Found user: username='$dbUsername', email='$dbEmail'");
          }
        } catch (e) {
    // print("❌ Error listing users: $e");
        }
        
        return AuthRequestResult(
          requestId: requestId,
          success: false,
          error: 'Username not found',
        );
      }
      
      final userDoc = usersQuery.docs.first;
      final userData = userDoc.data();
      final email = (userData as Map<String, dynamic>)['email'] as String?;
      
      if (email == null || email.isEmpty) {
        return AuthRequestResult(
          requestId: requestId,
          success: false,
          error: 'No email associated with this username',
        );
      }
      
    // print("📧 Found email for username $username: $email (request: $requestId)");
      
      // Now sign in with the email and password
      return await signInWithEmail(email, password, requestId);
      
    } catch (e) {
      return AuthRequestResult(
        requestId: requestId,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Sign in with Google (debounced, single-flight)
  Future<AuthRequestResult> signInWithGoogle(String requestId) async {
    try {
    // print("🔐 Starting Google Sign-In process (request: $requestId)");
      
      // First, sign out any existing Google session to avoid conflicts
      await _googleSignIn.signOut();
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        return AuthRequestResult(
          requestId: requestId,
          success: false,
          error: 'Google sign-in cancelled',
        );
      }
      
    // print("✅ Google Sign-In successful for: ${googleUser.email}");
      
      try {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        
        if (googleAuth.accessToken == null || googleAuth.idToken == null) {
          return AuthRequestResult(
            requestId: requestId,
            success: false,
            error: 'Failed to get Google authentication tokens',
          );
        }
        
        final credential = firebase_auth.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        
    // print("🔐 Signing in to Firebase with Google credential");
        final userCredential = await _auth.signInWithCredential(credential);
        
        if (userCredential.user != null) {
    // print("✅ Firebase authentication successful for: ${userCredential.user!.email}");
          // The auth state listener will handle the rest
          return AuthRequestResult(
            requestId: requestId,
            success: true,
            user: _currentUser,
          );
        } else {
          return AuthRequestResult(
            requestId: requestId,
            success: false,
            error: 'Google authentication failed',
          );
        }
      } catch (authError) {
    // print("❌ Firebase authentication error: $authError");
        // Sign out from Google if Firebase auth fails
        await _googleSignIn.signOut();
        return AuthRequestResult(
          requestId: requestId,
          success: false,
          error: 'Firebase authentication failed: $authError',
        );
      }
    } catch (e) {
    // print("❌ Google Sign-In error: $e");
      
      // Provide more specific error messages
      String errorMessage = e.toString();
      if (e.toString().contains('network_error')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('sign_in_canceled')) {
        errorMessage = 'Sign-in was cancelled.';
      } else if (e.toString().contains('sign_in_failed')) {
        errorMessage = 'Sign-in failed. Please try again.';
      } else if (e.toString().contains('PigeonUserDetails')) {
        errorMessage = 'Google Sign-In configuration error. Please try again.';
      }
      
      return AuthRequestResult(
        requestId: requestId,
        success: false,
        error: errorMessage,
      );
    }
  }

  /// Public debounced methods
  Future<AuthRequestResult> debouncedSignInWithEmail(String email, String password) {
    return _debouncedAuth('email', (requestId) => signInWithEmail(email, password, requestId));
  }

  Future<AuthRequestResult> debouncedSignInWithUsername(String username, String password) {
    return _debouncedAuth('username', (requestId) => signInWithUsername(username, password, requestId));
  }

  Future<AuthRequestResult> debouncedSignInWithGoogle() {
    return _debouncedAuth('google', (requestId) => signInWithGoogle(requestId));
  }

  /// Quick test login with your credentials for testing
  Future<AuthRequestResult> quickTestLogin() async {
    final requestId = _generateRequestId();
    _currentRequestId = requestId;
    
    // cspell:ignore technqs
    // print("🧪 Quick test login with technqs credentials");
    
    try {
      // First try to sign in
      try {
        final userCredential = await _auth.signInWithEmailAndPassword(
          email: 'technqs@example.com', // cspell:ignore technqs Ntizzle
          password: 'Ntizzle1@1988',
        );
        
        if (userCredential.user != null) {
    // print("✅ Quick test login successful");
          await _handleUserSignIn(userCredential.user!);
          _isLoggedIn = true;
          notifyListeners();
          
          return AuthRequestResult(
            requestId: requestId,
            success: true,
            user: _currentUser,
          );
        }
      } catch (signInError) {
    // print("⚠️ Sign in failed, trying to create account: $signInError");
        
        // If sign in fails, try to create the account
        try {
          final userCredential = await _auth.createUserWithEmailAndPassword(
            email: 'technqs@example.com', // cspell:ignore technqs Ntizzle
            password: 'Ntizzle1@1988',
          );
          
          if (userCredential.user != null) {
    // print("✅ Test account created successfully");
            
            // Update display name
            await userCredential.user!.updateDisplayName('technqs'); // cspell:ignore technqs
            
            // Create user document in Firestore
            await _createUserDocument(
              userCredential.user!,
              displayName: 'technqs', // cspell:ignore technqs
              username: 'technqs', // cspell:ignore technqs
            );
            
            // Handle sign in
            await _handleUserSignIn(userCredential.user!);
            _isLoggedIn = true;
            notifyListeners();
            
            return AuthRequestResult(
              requestId: requestId,
              success: true,
              user: _currentUser,
            );
          }
        } catch (createError) {
    // print("❌ Account creation failed: $createError");
          return AuthRequestResult(
            requestId: requestId,
            success: false,
            error: 'Failed to create or sign in: $createError',
          );
        }
      }
      
    // print("❌ Quick test login failed - no user returned");
      return AuthRequestResult(
        requestId: requestId,
        success: false,
        error: 'No user returned from Firebase',
      );
    } catch (e) {
    // print("❌ Quick test login error: $e");
      return AuthRequestResult(
        requestId: requestId,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Development bypass login - creates a mock user for testing
  Future<AuthRequestResult> bypassLogin() async {
    final requestId = _generateRequestId();
    _currentRequestId = requestId;
    
    // print("🚀 Bypass login - creating mock user for development");
    
    try {
      // Create a mock user for development
      const mockUser = User(
        id: 'dev_user_123',
        displayName: 'technqs',
        username: 'technqs',
        avatarURL: null,
        bio: 'Development test user',
        hashtags: ['#developer', '#testing'],
        onlineStatus: 'online',
        aiSelf: 'I am a development test user',
        postCount: 0,
        followerCount: 0,
        followingCount: 0,
        calendarEvents: [],
      );
      
      _currentUser = mockUser;
      _isLoggedIn = true;
      notifyListeners();
      
    // print("✅ Bypass login successful - mock user created");
    // print("🔔 Mock user ID: ${mockUser.id}");
    // print("🔔 Mock user display name: ${mockUser.displayName}");
      
      return AuthRequestResult(
        requestId: requestId,
        success: true,
        user: _currentUser,
      );
    } catch (e) {
    // print("❌ Bypass login error: $e");
      return AuthRequestResult(
        requestId: requestId,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Mock follow functionality for development
  Future<bool> mockFollowUser(String targetUserId) async {
    // print("🔔 Mock follow user called for: $targetUserId");
    // print("🔔 Current user: ${_currentUser?.displayName} (${_currentUser?.id})");
    
    // Simulate a successful follow operation
    await Future.delayed(const Duration(milliseconds: 500));
    
    // print("✅ Mock follow successful for: $targetUserId");
    return true;
  }

  /// Mock unfollow functionality for development
  Future<bool> mockUnfollowUser(String targetUserId) async {
    // print("🔔 Mock unfollow user called for: $targetUserId");
    // print("🔔 Current user: ${_currentUser?.displayName} (${_currentUser?.id})");
    
    // Simulate a successful unfollow operation
    await Future.delayed(const Duration(milliseconds: 500));
    
    // print("✅ Mock unfollow successful for: $targetUserId");
    return true;
  }

  /// Sign up with email and password
  Future<void> signUpWithEmail(String email, String password, String displayName, String username) async {
    // print("📝 Signing up with email: $email");
    
    try {
      // Create user with Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (userCredential.user != null) {
    // print("✅ User created successfully");
        
        // Update display name
        await userCredential.user!.updateDisplayName(displayName);
        
        // Create user document in Firestore
        await _createUserDocument(
          userCredential.user!,
          displayName: displayName,
          username: username,
        );
        
        // Handle sign in
        await _handleUserSignIn(userCredential.user!);
        _isLoggedIn = true;
        notifyListeners();
        
    // print("✅ Sign up completed successfully");
      } else {
        throw Exception('No user returned from Firebase');
      }
    } catch (e) {
    // print("❌ Sign up error: $e");
      rethrow;
    }
  }

  /// Create user document in Firestore
  Future<void> _createUserDocument(firebase_auth.User firebaseUser, {required String displayName, required String username}) async {
    try {
      final userRef = _firestore.collection("users").doc(firebaseUser.uid);
      
      await userRef.set({
        'id': firebaseUser.uid,
        'email': firebaseUser.email,
        'displayName': displayName,
        'username': username,
        'avatarURL': null,
        'bio': '',
        'hashtags': [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isDeleted': false,
      });
      
    // print("✅ User document created in Firestore");
    } catch (e) {
    // print("❌ Error creating user document: $e");
      rethrow;
    }
  }

  /// Handle user sign in and load user data from Firestore
  Future<void> _handleUserSignIn(firebase_auth.User firebaseUser) async {
    // print("🔐 handleUserSignIn called for user: ${firebaseUser.uid}");
    // print("👤 User display name: ${firebaseUser.displayName ?? 'nil'}");
    // print("📧 User email: ${firebaseUser.email ?? 'nil'}");
    
    try {
      final userRef = _firestore.collection("users").doc(firebaseUser.uid);
      final snapshot = await userRef.get();
      
    // print("📄 Firestore document fetch completed");
    // print("🔐 Document exists: ${snapshot.exists}");
      
      if (snapshot.exists) {
    // print("🔐 User document found in Firestore");
        final data = snapshot.data()!;
        
        // Decode hashtags - handle both List and String formats
        var hashtags = <String>[];
        if (data['hashtags'] != null) {
          final hashtagsData = data['hashtags'];
          if (hashtagsData is List) {
            hashtags = List<String>.from(hashtagsData);
          } else if (hashtagsData is String) {
            hashtags = hashtagsData.split(',').map((e) => e.trim()).toList();
          }
        }
        
        // Decode aiSelf
        String aiSelf = '';
        if (data['aiSelf'] != null) {
          aiSelf = data['aiSelf'] as String;
        }
        
        // Decode calendarEvents
        var calendarEvents = <CalendarEvent>[];
        if (data['calendarEvents'] != null) {
          final eventsArray = data['calendarEvents'] as List<dynamic>;
          calendarEvents = eventsArray.map((eventData) {
            if (eventData is Map<String, dynamic>) {
              return CalendarEvent.fromMap(eventData);
            }
            return null;
          }).where((event) => event != null).cast<CalendarEvent>().toList();
        }
        
        final user = User(
          id: firebaseUser.uid,
          username: data['username'] ?? 'user',
          displayName: data['displayName'] ?? 'User',
          bio: data['bio'],
          avatarURL: data['avatarURL'],
          onlineStatus: data['onlineStatus'] ?? 'online',
          hashtags: hashtags,
          aiSelf: aiSelf,
          calendarEvents: calendarEvents,
        );
        
        _currentUser = user;
        _isLoggedIn = true;
        _isCheckingAuth = false;
        notifyListeners();
        
    // print("✅ User signed in successfully - isLoggedIn: $_isLoggedIn");
        
        // Set up real-time listener for user data changes
        _setupUserDataListener(firebaseUser.uid);
        
        // Ensure user document exists (handles any edge cases)
        await _ensureUserDocumentExists();
        
      } else {
    // print("🔐 Creating new user document in Firestore");
        
        // Generate a unique username from display name
        final baseUsername = firebaseUser.displayName?.toLowerCase().replaceAll(' ', '') ?? 'user';
        final username = await _generateUniqueUsername(baseUsername);
        
        final user = User(
          id: firebaseUser.uid,
          username: username,
          displayName: firebaseUser.displayName ?? 'User',
          bio: null,
          avatarURL: firebaseUser.photoURL,
          onlineStatus: 'online',
        );
        
        // Save the new user to Firestore
        await _saveUserToFirestore(user, email: firebaseUser.email);
        
        _currentUser = user;
        _isLoggedIn = true;
        _isCheckingAuth = false;
        notifyListeners();
        
    // print("✅ New user signed in successfully - isLoggedIn: $_isLoggedIn");
        
        // Set up real-time listener for the new user
        _setupUserDataListener(firebaseUser.uid);
      }
    } catch (e) {
    // print("❌ Error in handleUserSignIn: $e");
      _isCheckingAuth = false;
      notifyListeners();
    }
  }

  /// Set up real-time listener for user data changes
  void _setupUserDataListener(String userId) {
    // print("👂 Setting up real-time listener for user: $userId");
    
    _firestore.collection("users").doc(userId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && _currentUser != null) {
        final data = snapshot.data()!;
        
        // Check if avatar URL has changed
        final newAvatarURLString = data['avatarURL'] as String? ?? '';
        final currentAvatarURLString = _currentUser!.avatarURL ?? '';
        
        if (newAvatarURLString != currentAvatarURLString && newAvatarURLString.isNotEmpty) {
    // print("🔄 Avatar URL changed in Firestore - updating app");
    // print("📸 Old: $currentAvatarURLString");
    // print("📸 New: $newAvatarURLString");
          
          _currentUser = User(
            id: _currentUser!.id,
            username: _currentUser!.username,
            displayName: _currentUser!.displayName,
            bio: _currentUser!.bio,
            avatarURL: newAvatarURLString,
            onlineStatus: _currentUser!.onlineStatus,
            hashtags: _currentUser!.hashtags,
            aiSelf: _currentUser!.aiSelf,
            postCount: _currentUser!.postCount,
            followerCount: _currentUser!.followerCount,
            followingCount: _currentUser!.followingCount,
          );
          notifyListeners();
        }
        
        // Check for other user data changes
        final newDisplayName = data['displayName'] as String? ?? '';
        final newUsername = data['username'] as String? ?? '';
        final newBio = data['bio'] as String?;
        
        // Handle hashtags update
        var newHashtags = <String>[];
        if (data['hashtags'] != null) {
          final hashtagsData = data['hashtags'];
          if (hashtagsData is List) {
            newHashtags = List<String>.from(hashtagsData);
          } else if (hashtagsData is String) {
            newHashtags = hashtagsData.split(',').map((e) => e.trim()).toList();
          }
        }
        
        if (newDisplayName != _currentUser!.displayName ||
            newUsername != _currentUser!.username ||
            newBio != _currentUser!.bio ||
            newHashtags.toString() != _currentUser!.hashtags.toString()) {
    // print("🔄 User data changed in Firestore - updating app");
          
          _currentUser = User(
            id: _currentUser!.id,
            username: newUsername,
            displayName: newDisplayName,
            bio: newBio,
            avatarURL: _currentUser!.avatarURL,
            onlineStatus: _currentUser!.onlineStatus,
            hashtags: newHashtags,
            aiSelf: _currentUser!.aiSelf,
            postCount: _currentUser!.postCount,
            followerCount: _currentUser!.followerCount,
            followingCount: _currentUser!.followingCount,
          );
          notifyListeners();
        }
      }
    });
  }

  /// Generate unique username
  Future<String> _generateUniqueUsername(String baseUsername) async {
    String username = baseUsername;
    int counter = 1;
    
    while (true) {
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();
      
      if (query.docs.isEmpty) {
        return username;
      }
      
      username = '$baseUsername$counter';
      counter++;
    }
  }

  /// Save user to Firestore
  Future<void> _saveUserToFirestore(User user, {String? email}) async {
    try {
      final userData = {
        'username': user.username.toLowerCase(),
        'displayName': user.displayName,
        'bio': user.bio,
        'avatarURL': user.avatarURL,
        'onlineStatus': user.onlineStatus,
        'hashtags': user.hashtags,
        'aiSelf': user.aiSelf,
        'postCount': user.postCount,
        'followerCount': user.followerCount,
        'followingCount': user.followingCount,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (email != null) {
        userData['email'] = email;
      }
      
      await _firestore.collection('users').doc(user.id).set(userData);
    // print("✅ User saved to Firestore successfully");
    } catch (e) {
    // print("❌ Error saving user to Firestore: $e");
      rethrow;
    }
  }

  /// Ensure user document exists
  Future<void> _ensureUserDocumentExists() async {
    // Implementation for ensuring user document exists
    // This can be expanded based on your specific needs
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      _currentUser = null;
      _isLoggedIn = false;
      _isCheckingAuth = false;
      _currentRequestId = null;
      _debounceTimer?.cancel();
      _minimumSpinnerTimer?.cancel();
      _isMinimumSpinnerActive = false;
      notifyListeners();
    // print("✅ User signed out successfully");
    } catch (e) {
    // print("❌ Error signing out: $e");
    }
  }

  /// Update user calendar events in Firestore
  Future<void> updateUserCalendarEvents(List<dynamic> events) async {
    if (_currentUser == null) {
    // print('❌ No current user to update calendar events');
      return;
    }

    try {
      final eventsData = events.map((event) => {
        'id': event.id,
        'title': event.title,
        'description': event.description,
        'date': Timestamp.fromDate(event.date),
      }).toList();

      await _firestore.collection('users').doc(_currentUser!.id).update({
        'calendarEvents': eventsData,
      });

    // print('✅ Calendar events successfully updated in Firestore');
    } catch (e) {
    // print('❌ Error updating calendar events in Firestore: $e');
      rethrow;
    }
  }
}

// Provider for the robust authentication service
final robustAuthServiceProvider = ChangeNotifierProvider<RobustAuthenticationService>((ref) {
  return RobustAuthenticationService();
});
