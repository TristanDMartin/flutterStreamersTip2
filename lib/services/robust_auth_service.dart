import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../models/calendar_event.dart';
import '../utils/avatar_url_resolver.dart';
import '../utils/password_validation.dart';
import 'auth_rate_limiting_service.dart';
import 'tiktok_account_switcher.dart';
import 'google_services_fix.dart';
import 'username_lock_service.dart';
import 'two_factor_auth_service.dart';

/// Request-scoped authentication result
class AuthRequestResult {
  final String requestId;
  final bool success;
  final String? error;
  final User? user;
  final bool requires2FA;

  const AuthRequestResult({
    required this.requestId,
    required this.success,
    this.error,
    this.user,
    this.requires2FA = false,
  });
}

/// Robust authentication service with single-flight, debounced, request-scoped operations
class RobustAuthenticationService extends ChangeNotifier {
  // Lazy initialization for Firebase instances to prevent iOS cold start crashes
  firebase_auth.FirebaseAuth? _auth;
  GoogleSignIn? _googleSignIn;
  FirebaseFirestore? _firestore;

  firebase_auth.FirebaseAuth get _authInstance {
    if (_auth == null) {
      try {
        if (Firebase.apps.isEmpty) {
          debugPrint(
              '⚠️ RobustAuthenticationService: Firebase not initialized yet');
          throw Exception('Firebase not initialized');
        }
        _auth = firebase_auth.FirebaseAuth.instance;
      } catch (e) {
        debugPrint(
            '❌ RobustAuthenticationService: Error accessing FirebaseAuth: $e');
        rethrow;
      }
    }
    return _auth!;
  }

  GoogleSignIn get _googleSignInInstance {
    if (_googleSignIn == null) {
      try {
        _googleSignIn = GoogleSignIn();
      } catch (e) {
        debugPrint(
            '❌ RobustAuthenticationService: Error creating GoogleSignIn: $e');
        _googleSignIn = GoogleSignIn();
      }
    }
    return _googleSignIn!;
  }

  FirebaseFirestore get _firestoreInstance {
    if (_firestore == null) {
      try {
        if (Firebase.apps.isEmpty) {
          debugPrint(
              '⚠️ RobustAuthenticationService: Firebase not initialized yet');
          throw Exception('Firebase not initialized');
        }
        _firestore = FirebaseFirestore.instance;
      } catch (e) {
        debugPrint(
            '❌ RobustAuthenticationService: Error accessing Firestore: $e');
        rethrow;
      }
    }
    return _firestore!;
  }

  final AuthRateLimitingService _rateLimiter = AuthRateLimitingService();
  final UsernameLockService _usernameLockService = UsernameLockService();
  final TikTokAccountSwitcher _accountSwitcher = TikTokAccountSwitcher();
  final TwoFactorAuthService _twoFactorService = TwoFactorAuthService();

  User? _currentUser;
  bool _isLoggedIn = false;
  bool _isCheckingAuth = false;
  StreamSubscription<firebase_auth.User?>? _authStateSubscription;

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

    // CRITICAL: Defer Firebase access until after Firebase is initialized
    // This prevents iOS cold start crashes
    Future.microtask(() async {
      try {
        // Wait for Firebase to be ready (iOS cold start issue)
        if (Firebase.apps.isEmpty) {
          debugPrint(
              '⏳ Firebase not ready yet - service will initialize when ready');
          // Wait briefly and retry
          await Future.delayed(const Duration(milliseconds: 100));
          if (Firebase.apps.isEmpty) {
            debugPrint('⚠️ Firebase still not ready - will retry auth check');
            _isCheckingAuth = false;
            notifyListeners();
            return;
          }
        }

        // Check initial authentication state asynchronously
        _checkInitialAuthState();

        // Listen to authentication state changes
        _authStateSubscription =
            _authInstance.authStateChanges().listen((firebase_auth.User? user) {
          try {
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
          } catch (e) {
            debugPrint('❌ Error in auth state listener: $e');
          }
        });
      } catch (e) {
        debugPrint('❌ Error initializing RobustAuthenticationService: $e');
        _isCheckingAuth = false;
        notifyListeners();
      }
    });
  }

  /// Check the initial authentication state when the service is created
  void _checkInitialAuthState() async {
    try {
      // CRITICAL: Check if Firebase is ready before accessing
      if (Firebase.apps.isEmpty) {
        debugPrint('⚠️ Firebase not ready - will retry auth check');
        _isCheckingAuth = false;
        notifyListeners();
        return;
      }

      // OPTIMIZED: Fast auth check with shorter timeout
      final currentUser = _authInstance.currentUser;

      if (currentUser != null) {
        // User is logged in - show UI immediately, load data in background
        debugPrint('✅ User logged in - showing UI immediately');
        _isLoggedIn = true;
        _isCheckingAuth = false;
        notifyListeners();

        // Load user data in background (non-blocking)
        _handleUserSignIn(currentUser).catchError((e) {
          debugPrint('❌ Background user data load failed: $e');
          // Don't change login state - user is still logged in
        });
      } else {
        // No user is logged in, set the state immediately
        _currentUser = null;
        _isLoggedIn = false;
        _isCheckingAuth = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error checking initial auth state: $e');
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
    _authStateSubscription?.cancel();
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

  String _firebaseAuthUserMessage(Object e) {
    if (e is firebase_auth.FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'Invalid email address.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many failed attempts. Please try again later.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
        case 'invalid-login-credentials':
          return 'Incorrect email/username or password.';
        case 'weak-password':
          return 'Password is too weak. Use a stronger password.';
        default:
          return e.message ?? 'Authentication failed.';
      }
    }
    return e.toString();
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

      final userCredential = await _authInstance.signInWithEmailAndPassword(
          email: email, password: password);

      if (userCredential.user != null) {
        // Record successful authentication
        await _rateLimiter.recordSuccess();

        // Check if user has 2FA enabled
        final requires2FA = await _twoFactorService.requires2FA(
          userCredential.user!.uid,
        );

        // User will be handled by auth state listener
        return AuthRequestResult(
          requestId: requestId,
          success: true,
          user: _currentUser,
          requires2FA: requires2FA,
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
      await _rateLimiter.recordAttempt();
      return AuthRequestResult(
        requestId: requestId,
        success: false,
        error: _firebaseAuthUserMessage(e),
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

      final String trimmed = username.trim();
      if (trimmed.isEmpty) {
        await _rateLimiter.recordAttempt();
        return AuthRequestResult(
          requestId: requestId,
          success: false,
          error: 'Enter your username.',
        );
      }
      final String normalizedUsername = trimmed.toLowerCase();
      final QuerySnapshot<Map<String, dynamic>> usersQuery =
          await _firestoreInstance
              .collection('users')
              .where('username', isEqualTo: normalizedUsername)
              .limit(1)
              .get();

      if (usersQuery.docs.isEmpty) {
        await _rateLimiter.recordAttempt();
        return AuthRequestResult(
          requestId: requestId,
          success: false,
          error: 'No account found with this email or username.',
        );
      }

      final Map<String, dynamic> userData = usersQuery.docs.first.data();
      final String? resolvedEmail = userData['email'] as String?;

      if (resolvedEmail == null || resolvedEmail.trim().isEmpty) {
        await _rateLimiter.recordAttempt();
        return AuthRequestResult(
          requestId: requestId,
          success: false,
          error: 'No account found with this email or username.',
        );
      }

      return await signInWithEmail(resolvedEmail.trim(), password, requestId);
    } catch (e) {
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
      await _googleSignInInstance.signOut();

      final GoogleSignInAccount? googleUser =
          await _googleSignInInstance.signIn();

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
        final userCredential =
            await _authInstance.signInWithCredential(credential);

        if (userCredential.user != null) {
          debugPrint(
              "✅ Firebase authentication successful for: ${userCredential.user!.email}");

          // Update local auth state immediately instead of waiting only on the
          // auth state stream, which can lag on some Android Google Sign-In flows.
          await _handleUserSignIn(userCredential.user!);
          _isLoggedIn = true;
          _isCheckingAuth = false;
          notifyListeners();

          return AuthRequestResult(
            requestId: requestId,
            success: true,
            user: _currentUser ??
                _mapFirebaseUserToFallback(userCredential.user!),
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
        await _googleSignInInstance.signOut();
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

  User _mapFirebaseUserToFallback(firebase_auth.User firebaseUser) {
    return User(
      id: firebaseUser.uid,
      username: firebaseUser.displayName?.toLowerCase().replaceAll(' ', '') ??
          firebaseUser.email?.split('@').first ??
          'user',
      displayName: firebaseUser.displayName ??
          firebaseUser.email?.split('@').first ??
          'User',
      bio: '',
      avatarURL: firebaseUser.photoURL,
      onlineStatus: 'online',
      hashtags: const [],
      postCount: 0,
      followerCount: 0,
      followingCount: 0,
    );
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

  /// Sign up with email and password
  Future<void> signUpWithEmail(String email, String password,
      String displayName, String username) async {
    debugPrint("📝 Signing up with email: $email");

    try {
      final String trimmedEmail = email.trim();
      final String normalizedUsername = username.trim().toLowerCase();
      final String? pwReject = PasswordRequirements.signupRejectReason(
        password,
      );
      if (pwReject != null) {
        throw Exception(pwReject);
      }

      final UsernameValidationResult usernameValidation =
          await _usernameLockService.validateUsername(normalizedUsername);
      if (!usernameValidation.isValid) {
        throw Exception(usernameValidation.errorMessage ?? 'Invalid username');
      }

      await _handleExistingUserCheck(trimmedEmail);

      final firebase_auth.UserCredential userCredential =
          await _authInstance.createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      if (userCredential.user != null) {
        debugPrint("✅ User created successfully");

        final String profileDisplayName = displayName.trim().isNotEmpty
            ? displayName.trim()
            : normalizedUsername;
        await userCredential.user!.updateDisplayName(profileDisplayName);

        await _createUserDocument(
          userCredential.user!,
          displayName: profileDisplayName,
          username: normalizedUsername,
        );

        await _handleUserSignIn(userCredential.user!);
        _isLoggedIn = true;
        notifyListeners();

        debugPrint("✅ Sign up completed successfully");
      } else {
        throw Exception('No user returned from Firebase');
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      debugPrint("❌ Sign up FirebaseAuthException: ${e.code}");
      throw Exception(_firebaseAuthUserMessage(e));
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
      final userQuery = await _firestoreInstance
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
      final userRef =
          _firestoreInstance.collection("users").doc(firebaseUser.uid);

      await userRef.set({
        'uid': firebaseUser.uid,
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
      final userRef =
          _firestoreInstance.collection("users").doc(firebaseUser.uid);
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
          avatarURL: resolveAvatarUrl(data),
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

        // Register FCM token for push notifications
        await _registerFCMToken(firebaseUser.uid);
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

        // Register FCM token for push notifications
        await _registerFCMToken(firebaseUser.uid);
      }
    } catch (e) {
      debugPrint("❌ Error in handleUserSignIn: $e");
      debugPrint("❌ Error type: ${e.runtimeType}");
      // Don't reset login state on error - user is still authenticated with Firebase
      // Just mark auth check as complete
      _isCheckingAuth = false;
      notifyListeners();
      // Retry loading user data after a delay
      Future.delayed(const Duration(seconds: 2), () {
        if (_isLoggedIn && _currentUser == null) {
          debugPrint('🔄 Retrying user data load...');
          _handleUserSignIn(firebaseUser).catchError((retryError) {
            debugPrint('❌ Retry failed: $retryError');
          });
        }
      });
    }
  }

  /// Set up real-time listener for user data changes
  void _setupUserDataListener(String userId) {
    // print("👂 Setting up real-time listener for user: $userId");

    _firestoreInstance
        .collection("users")
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && _currentUser != null) {
        final data = snapshot.data()!;

        // Check if avatar URL has changed
        final newAvatarURLString = resolveAvatarUrl(data) ?? '';
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

      await _firestoreInstance.collection('users').doc(user.id).set(userData);
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
      if (_authInstance.currentUser == null) {
        debugPrint("⚠️ User already signed out, cleaning up state...");
        _cleanupAuthState();
        return;
      }

      // Remove FCM token before signing out
      await _removeCurrentDeviceToken();

      await _authInstance.signOut();
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

  /// Register FCM token for push notifications
  Future<void> _registerFCMToken(String userId) async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Check existing permission status
      final currentSettings = await messaging.getNotificationSettings();

      // Only request permission if not already granted
      if (currentSettings.authorizationStatus ==
          AuthorizationStatus.notDetermined) {
        debugPrint("🔔 Requesting notification permissions...");
        final settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );

        if (settings.authorizationStatus != AuthorizationStatus.authorized) {
          debugPrint("⚠️ Notification permission denied");
          return;
        }
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        String? apnsToken;
        for (int attempt = 0; attempt < 5; attempt++) {
          apnsToken = await messaging.getAPNSToken();
          if (apnsToken != null && apnsToken.isNotEmpty) {
            break;
          }
          await Future.delayed(const Duration(milliseconds: 700));
        }

        if (apnsToken == null || apnsToken.isEmpty) {
          debugPrint("ℹ️ APNS token not ready yet; deferring FCM registration");
          return;
        }
      }

      // Get FCM token (works even if permission was already granted)
      final fcmToken = await messaging.getToken();
      if (fcmToken != null) {
        debugPrint("📱 FCM Token obtained: ${fcmToken.substring(0, 20)}...");

        // Check if token already saved in Firestore
        final userDoc =
            await _firestoreInstance.collection('users').doc(userId).get();
        final existingToken = userDoc.data()?['fcmToken'] as String?;

        // Only save if token changed
        if (existingToken != fcmToken) {
          // Save token to Firestore user document
          await _firestoreInstance.collection('users').doc(userId).update({
            'fcmToken': fcmToken,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });

          debugPrint("✅ FCM token saved to Firestore for user $userId");

          // Also save to deviceTokens subcollection for multi-device support
          await _firestoreInstance
              .collection('users')
              .doc(userId)
              .collection('deviceTokens')
              .doc(fcmToken)
              .set({
            'token': fcmToken,
            'createdAt': FieldValue.serverTimestamp(),
            'lastUsed': FieldValue.serverTimestamp(),
            'platform': defaultTargetPlatform.name,
          });

          debugPrint("✅ FCM token added to deviceTokens collection");
        } else {
          debugPrint("ℹ️ FCM token unchanged, skipping Firestore update");
        }

        // Listen for token refresh
        messaging.onTokenRefresh.listen((newToken) async {
          debugPrint("🔄 FCM token refreshed");
          try {
            await _firestoreInstance.collection('users').doc(userId).update({
              'fcmToken': newToken,
              'lastTokenUpdate': FieldValue.serverTimestamp(),
            });
            debugPrint("✅ Updated FCM token in Firestore");
          } catch (e) {
            debugPrint("❌ Error updating FCM token: $e");
          }
        });
      } else {
        debugPrint("⚠️ No FCM token available");
      }
    } catch (e) {
      debugPrint("❌ Error registering FCM token: $e");
      // Don't fail sign-in if FCM registration fails
    }
  }

  /// Remove current device's FCM token from Firestore
  Future<void> _removeCurrentDeviceToken() async {
    try {
      final userId = _authInstance.currentUser?.uid;
      if (userId == null) return;

      // Get current FCM token
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) {
        debugPrint("⚠️ No FCM token to remove");
        return;
      }

      // Remove from deviceTokens subcollection
      await _firestoreInstance
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

      await _firestoreInstance
          .collection('users')
          .doc(_currentUser!.id)
          .update({
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
      await _authInstance.sendPasswordResetEmail(email: email);
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
  try {
    return RobustAuthenticationService();
  } catch (e) {
    debugPrint(
        '❌ robustAuthServiceProvider: Error creating RobustAuthenticationService: $e');
    // Return a safe instance even if initialization fails
    // The service will handle Firebase not being ready gracefully
    return RobustAuthenticationService();
  }
});
