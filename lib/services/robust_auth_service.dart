import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../models/calendar_event.dart';
import 'auth_rate_limiting_service.dart';
import 'tiktok_account_switcher.dart';
import 'google_services_fix.dart';
import 'username_lock_service.dart';

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
  final AuthRateLimitingService _rateLimiter = AuthRateLimitingService();
  final UsernameLockService _usernameLockService = UsernameLockService();
  final TikTokAccountSwitcher _accountSwitcher = TikTokAccountSwitcher();

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
  static const Duration _minimumSpinnerTime = Duration(milliseconds: 2500);

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  bool get isCheckingAuth => _isCheckingAuth;
  bool get isRequestInFlight => _currentRequestId != null;

  // Get current user profile data from Firestore
  Map<String, dynamic>? _currentUserProfile;
  Map<String, dynamic>? get currentUserProfile => _currentUserProfile;

  RobustAuthenticationService() {
    // Set initial loading state
    _isCheckingAuth = true;

    // Check initial authentication state asynchronously
    _checkInitialAuthState();

    // Listen to authentication state changes
    _auth.authStateChanges().listen((firebase_auth.User? user) {
      debugPrint(
          "🔄 Auth state changed: ${user != null ? 'Logged in' : 'Logged out'}");
      if (user != null) {
        debugPrint("👤 User: ${user.email} (${user.uid})");
        _handleUserSignIn(user);
      } else {
        debugPrint("👤 User logged out - clearing auth state");
        _currentUser = null;
        _isLoggedIn = false;
        _isCheckingAuth = false;
        notifyListeners();
      }
    });
  }

  /// Check the initial authentication state when the service is created
  void _checkInitialAuthState() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      // User is already logged in, handle the sign in asynchronously
      await _handleUserSignIn(currentUser);
    } else {
      // No user is logged in, set the state immediately
      _currentUser = null;
      _isLoggedIn = false;
      _isCheckingAuth = false;
      notifyListeners();
    }
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
  bool get shouldShowLoading =>
      isRequestInFlight || _isMinimumSpinnerActive || _isCheckingAuth;

  /// Debounced authentication with single-flight protection
  Future<AuthRequestResult> _debouncedAuth(
    String requestType,
    Future<AuthRequestResult> Function(String requestId) authFunction,
  ) async {
    // Cancel any existing debounce timer
    _debounceTimer?.cancel();

    // Generate new request ID
    final requestId = _generateRequestId();

    // Wait for the debounce delay
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
      // Check rate limiting first
      if (await _rateLimiter.isRateLimited()) {
        final message = await _rateLimiter.getRateLimitMessage();
        return AuthRequestResult(
          requestId: requestId,
          success: false,
          error: message ??
              'Too many authentication attempts. Please try again later.',
        );
      }

      final userCredential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);

      if (userCredential.user != null) {
        // Record successful authentication
        await _rateLimiter.recordSuccess();

        // User will be handled by auth state listener
        return AuthRequestResult(
          requestId: requestId,
          success: true,
          user: _currentUser,
        );
      } else {
        // Record failed attempt
        await _rateLimiter.recordAttempt();

        return AuthRequestResult(
          requestId: requestId,
          success: false,
          error: 'Authentication failed',
        );
      }
    } catch (e) {
      // Record failed attempt
      await _rateLimiter.recordAttempt();

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
      // Check rate limiting first
      if (await _rateLimiter.isRateLimited()) {
        final message = await _rateLimiter.getRateLimitMessage();
        return AuthRequestResult(
          requestId: requestId,
          success: false,
          error: message ??
              'Too many authentication attempts. Please try again later.',
        );
      }

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
        // Record failed attempt
        await _rateLimiter.recordAttempt();

        // Debug information removed for production

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
        // Record failed attempt
        await _rateLimiter.recordAttempt();

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
      // Record failed attempt
      await _rateLimiter.recordAttempt();

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
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

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
        // Sign out from Google if Firebase auth fails
        await _googleSignIn.signOut();
        return AuthRequestResult(
          requestId: requestId,
          success: false,
          error: 'Firebase authentication failed: $authError',
        );
      }
    } catch (e) {
      // Use Google Services fix for error handling
      String errorMessage = GoogleServicesFix.getGoogleServicesErrorMessage(e);

      return AuthRequestResult(
        requestId: requestId,
        success: false,
        error: errorMessage,
      );
    }
  }

  /// Public debounced methods
  Future<AuthRequestResult> debouncedSignInWithEmail(
      String email, String password) {
    return _debouncedAuth(
        'email', (requestId) => signInWithEmail(email, password, requestId));
  }

  Future<AuthRequestResult> debouncedSignInWithUsername(
      String username, String password) {
    return _debouncedAuth('username',
        (requestId) => signInWithUsername(username, password, requestId));
  }

  Future<AuthRequestResult> debouncedSignInWithGoogle() {
    return _debouncedAuth('google', (requestId) => signInWithGoogle(requestId));
  }

  Future<AuthRequestResult> debouncedSignUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    required String username,
  }) {
    return _debouncedAuth('signup', (requestId) async {
      try {
        await signUpWithEmail(email, password, displayName, username);
        return AuthRequestResult(
          requestId: requestId,
          success: true,
          user: _currentUser,
        );
      } catch (e) {
        return AuthRequestResult(
          requestId: requestId,
          success: false,
          error: e.toString(),
        );
      }
    });
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
            await userCredential.user!
                .updateDisplayName('technqs'); // cspell:ignore technqs

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
  Future<void> signUpWithEmail(String email, String password,
      String displayName, String username) async {
    debugPrint("📝 Signing up with email: $email");

    try {
      // Validate username first
      final usernameValidation =
          await _usernameLockService.validateUsername(username);
      if (!usernameValidation.isValid) {
        throw Exception(usernameValidation.errorMessage ?? 'Invalid username');
      }

      // Check if user already exists and handle account deletion scenarios
      await _handleExistingUserCheck(email);

      // Create user with Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        debugPrint("✅ User created successfully");

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

        debugPrint("✅ Sign up completed successfully");
      } else {
        throw Exception('No user returned from Firebase');
      }
    } catch (e) {
      debugPrint("❌ Sign up error: $e");
      debugPrint("❌ Error type: ${e.runtimeType}");
      rethrow;
    }
  }

  /// Handle existing user check for account deletion scenarios
  Future<void> _handleExistingUserCheck(String email) async {
    try {
      // Check if user exists in Firestore
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        debugPrint("⚠️ User with email $email still exists in Firestore");
        // Optionally delete the Firestore document if it exists
        await userQuery.docs.first.reference.delete();
        debugPrint("🧹 Deleted existing Firestore document for $email");
      }
    } catch (e) {
      debugPrint("⚠️ Error checking existing user: $e");
      // Continue with signup even if check fails
    }
  }

  /// Create user document in Firestore
  Future<void> _createUserDocument(firebase_auth.User firebaseUser,
      {required String displayName, required String username}) async {
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
    debugPrint("🔐 _handleUserSignIn called for user: ${firebaseUser.uid}");
    debugPrint("👤 User email: ${firebaseUser.email ?? 'nil'}");
    debugPrint("👤 User display name: ${firebaseUser.displayName ?? 'nil'}");

    try {
      final userRef = _firestore.collection("users").doc(firebaseUser.uid);
      final snapshot = await userRef.get();

      if (snapshot.exists) {
        debugPrint("🔐 User document found in Firestore");
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
          calendarEvents = eventsArray
              .map((eventData) {
                if (eventData is Map<String, dynamic>) {
                  return CalendarEvent.fromMap(eventData);
                }
                return null;
              })
              .where((event) => event != null)
              .cast<CalendarEvent>()
              .toList();
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

        debugPrint("✅ User signed in successfully - isLoggedIn: $_isLoggedIn");

        // Add account to TikTok account switcher for instant switching
        await _accountSwitcher.addCurrentAccount();

        // Trigger comprehensive data refresh for the signed-in user
        await _accountSwitcher.triggerDataRefreshWithRef(null);

        // Set up real-time listener for user data changes
        _setupUserDataListener(firebaseUser.uid);

        // Ensure user document exists (handles any edge cases)
        await _ensureUserDocumentExists();
      } else {
        debugPrint(
            "🔐 User document NOT found in Firestore - creating new user");

        // For existing users who don't have a Firestore document, create one
        final baseUsername = firebaseUser.email?.split('@')[0] ?? 'user';
        final username = await _generateUniqueUsername(baseUsername);

        final user = User(
          id: firebaseUser.uid,
          username: username,
          displayName: firebaseUser.displayName ??
              firebaseUser.email?.split('@')[0] ??
              'User',
          bio: '',
          avatarURL: firebaseUser.photoURL,
          onlineStatus: 'online',
          hashtags: [],
          postCount: 0,
          followerCount: 0,
          followingCount: 0,
        );

        // Save the new user to Firestore
        await _saveUserToFirestore(user, email: firebaseUser.email);

        _currentUser = user;
        _isLoggedIn = true;
        _isCheckingAuth = false;
        notifyListeners();

        debugPrint(
            "✅ New user created and signed in successfully - isLoggedIn: $_isLoggedIn");

        // Add account to TikTok account switcher for instant switching
        await _accountSwitcher.addCurrentAccount();

        // Trigger comprehensive data refresh for the signed-in user
        await _accountSwitcher.triggerDataRefreshWithRef(null);

        // Set up real-time listener for the new user
        _setupUserDataListener(firebaseUser.uid);
      }
    } catch (e) {
      debugPrint("❌ Error in handleUserSignIn: $e");
      debugPrint("❌ Error type: ${e.runtimeType}");
      _currentUser = null;
      _isLoggedIn = false;
      _isCheckingAuth = false;
      notifyListeners();
    }
  }

  /// Set up real-time listener for user data changes
  void _setupUserDataListener(String userId) {
    // print("👂 Setting up real-time listener for user: $userId");

    _firestore.collection("users").doc(userId).snapshots().listen((snapshot) {
      if (snapshot.exists && _currentUser != null) {
        final data = snapshot.data()!;

        // Check if avatar URL has changed
        final newAvatarURLString = data['avatarURL'] as String? ?? '';
        final currentAvatarURLString = _currentUser!.avatarURL ?? '';

        if (newAvatarURLString != currentAvatarURLString &&
            newAvatarURLString.isNotEmpty) {
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
      // Check if username is available (not taken and not reserved)
      final isAvailable =
          await _usernameLockService.isUsernameAvailable(username);

      if (isAvailable) {
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
    } catch (e) {
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
      debugPrint("🔐 Starting sign out process...");

      // Check if user is already signed out
      if (_auth.currentUser == null) {
        debugPrint("⚠️ User already signed out, cleaning up state...");
        _cleanupAuthState();
        return;
      }

      // Remove FCM token before signing out
      await _removeCurrentDeviceToken();

      await _auth.signOut();
      await GoogleServicesFix.signOutFromGoogle();
      _cleanupAuthState();
      debugPrint("✅ User signed out successfully");
    } catch (e) {
      debugPrint("❌ Error signing out: $e");
      // Still cleanup state even if there was an error
      _cleanupAuthState();
      rethrow; // Re-throw the error so the UI can handle it
    }
  }

  /// Remove current device's FCM token from Firestore
  Future<void> _removeCurrentDeviceToken() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Get current FCM token
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) {
        debugPrint("⚠️ No FCM token to remove");
        return;
      }

      // Remove from deviceTokens subcollection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('deviceTokens')
          .doc(fcmToken)
          .delete();

      debugPrint("🧹 Removed FCM token for user $userId on logout");
    } catch (e) {
      debugPrint("⚠️ Error removing FCM token on logout: $e");
      // Don't fail logout if token removal fails
    }
  }

  /// Clean up authentication state
  void _cleanupAuthState() {
    _currentUser = null;
    _isLoggedIn = false;
    _isCheckingAuth = false;
    _currentRequestId = null;
    _debounceTimer?.cancel();
    _minimumSpinnerTimer?.cancel();
    _isMinimumSpinnerActive = false;
    notifyListeners();
  }

  /// Update user calendar events in Firestore
  Future<void> updateUserCalendarEvents(List<dynamic> events) async {
    if (_currentUser == null) {
      // print('❌ No current user to update calendar events');
      return;
    }

    try {
      final eventsData = events
          .map((event) => {
                'id': event.id,
                'title': event.title,
                'description': event.description,
                'date': Timestamp.fromDate(event.date),
              })
          .toList();

      await _firestore.collection('users').doc(_currentUser!.id).update({
        'calendarEvents': eventsData,
      });

      // print('✅ Calendar events successfully updated in Firestore');
    } catch (e) {
      // print('❌ Error updating calendar events in Firestore: $e');
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      debugPrint("✅ Password reset email sent to: $email");
    } catch (e) {
      debugPrint("❌ Password reset error: $e");
      rethrow;
    }
  }
}

// Provider for the robust authentication service
final robustAuthServiceProvider =
    ChangeNotifierProvider<RobustAuthenticationService>((ref) {
  return RobustAuthenticationService();
});
