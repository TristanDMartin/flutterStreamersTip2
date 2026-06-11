import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../models/calendar_event.dart';
import '../utils/apple_sign_in_nonce.dart';
import '../utils/avatar_url_resolver.dart';
import '../utils/user_profile_firestore.dart';
import '../utils/password_validation.dart';
import 'auth_rate_limiting_service.dart';
import 'auth_session_teardown.dart';
import 'auth_transition_state.dart';
import '../features/home/application/home_first_frame_gate.dart';
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

class PasswordResetRequestResult {
  final bool success;
  final String? message;
  final String? error;

  const PasswordResetRequestResult({
    required this.success,
    this.message,
    this.error,
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
        _googleSignIn = GoogleSignIn(
          scopes: const ['email', 'profile'],
        );
      } catch (e) {
        debugPrint(
            '❌ RobustAuthenticationService: Error creating GoogleSignIn: $e');
        _googleSignIn = GoogleSignIn(
          scopes: const ['email', 'profile'],
        );
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
  AuthTransitionState _authTransitionState = AuthTransitionState.checkingAuth;
  String? _signingOutUid;
  int _signOutGeneration = 0;
  StreamSubscription<firebase_auth.User?>? _authStateSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _userFirestoreSubscription;
  Future<void>? _userSignInInFlight;
  String? _userSignInInFlightUid;

  // Request management
  String? _currentRequestId;
  bool _oauthInProgress = false;
  Timer? _debounceTimer;
  Timer? _minimumSpinnerTimer;
  bool _isMinimumSpinnerActive = false;

  // Constants
  static const Duration _debounceDelay = Duration(milliseconds: 400);
  static const Duration _minimumSpinnerTime = Duration(milliseconds: 2500);
  static const Duration _googleSignOutTimeout = Duration(seconds: 8);
  static const Duration _googleAccountPickerTimeout = Duration(seconds: 90);
  static const Duration _googleTokenTimeout = Duration(seconds: 20);
  static const Duration _appleCredentialTimeout = Duration(seconds: 90);
  static const Duration _firebaseCredentialTimeout = Duration(seconds: 30);
  static const Duration _userHydrationTimeout = Duration(seconds: 30);

  User? get currentUser => _currentUser;
  AuthTransitionState get authTransitionState => _authTransitionState;
  bool get isSigningOut =>
      _authTransitionState == AuthTransitionState.signingOut;
  bool get isLoggedIn => resolveAuthShellLoggedIn(
        loggedInFlag: _isLoggedIn,
        transitionState: _authTransitionState,
      );
  bool get isCheckingAuth => _isCheckingAuth;
  bool get isRequestInFlight => _currentRequestId != null;
  bool get isOauthInProgress => _oauthInProgress;
  bool get isAuthSubmitting => _oauthInProgress || shouldShowLoading;

  bool _shouldIgnoreAuthUserEvent(firebase_auth.User user) {
    if (_authTransitionState == AuthTransitionState.signingIn ||
        _currentRequestId != null) {
      return false;
    }
    if (_authTransitionState == AuthTransitionState.signingOut) {
      debugPrint('AUTH_EVENT_IGNORED_DURING_SIGN_OUT uid=${user.uid}');
      return true;
    }
    if (_signingOutUid != null && user.uid == _signingOutUid) {
      debugPrint('AUTH_EVENT_IGNORED_DURING_SIGN_OUT uid=${user.uid}');
      return true;
    }
    return false;
  }

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
            _authTransitionState = AuthTransitionState.unauthenticated;
            notifyListeners();
            return;
          }
        }

        _authTransitionState = AuthTransitionState.checkingAuth;
        // Check initial authentication state asynchronously
        _checkInitialAuthState();

        // Listen to authentication state changes
        _authStateSubscription =
            _authInstance.authStateChanges().listen((firebase_auth.User? user) {
          try {
            debugPrint(
              'AUTH STATE CHANGED: ${user?.uid ?? 'SIGNED OUT'}',
            );
            if (user != null) {
              if (_shouldIgnoreAuthUserEvent(user)) {
                return;
              }
              debugPrint('AUTH_TRANSITION firebase_session_available');
              _promoteFirebaseSession(user);
              unawaited(_handleUserSignIn(user));
            } else {
              debugPrint('AUTH_TRANSITION signed_out');
              _signingOutUid = null;
              _authTransitionState = AuthTransitionState.unauthenticated;
              _cancelUserFirestoreSubscription();
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
        _authTransitionState = AuthTransitionState.unauthenticated;
        notifyListeners();
      }
    });
  }

  /// Check the initial authentication state when the service is created
  void _checkInitialAuthState() async {
    try {
      if (_authTransitionState == AuthTransitionState.signingOut) {
        return;
      }
      // CRITICAL: Check if Firebase is ready before accessing
      if (Firebase.apps.isEmpty) {
        debugPrint('⚠️ Firebase not ready - will retry auth check');
        _isCheckingAuth = false;
        _authTransitionState = AuthTransitionState.unauthenticated;
        notifyListeners();
        return;
      }

      // OPTIMIZED: Fast auth check with shorter timeout
      final firebase_auth.User? currentUser = _authInstance.currentUser;

      if (currentUser != null) {
        if (_shouldIgnoreAuthUserEvent(currentUser)) {
          return;
        }
        // User is logged in - show UI immediately, load data in background
        debugPrint('✅ User logged in - showing UI immediately');
        _promoteFirebaseSession(currentUser);

        // Load user data in background (non-blocking)
        _handleUserSignIn(currentUser).catchError((Object e) {
          debugPrint('❌ Background user data load failed: $e');
          // Don't change login state - user is still logged in
        });
      } else {
        // No user is logged in, set the state immediately
        _currentUser = null;
        _isLoggedIn = false;
        _isCheckingAuth = false;
        _authTransitionState = AuthTransitionState.unauthenticated;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error checking initial auth state: $e');
      _currentUser = null;
      _isLoggedIn = false;
      _isCheckingAuth = false;
      _authTransitionState = AuthTransitionState.unauthenticated;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _minimumSpinnerTimer?.cancel();
    _authStateSubscription?.cancel();
    _cancelUserFirestoreSubscription();
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
      isRequestInFlight ||
      _isMinimumSpinnerActive ||
      _isCheckingAuth ||
      _authTransitionState == AuthTransitionState.signingOut ||
      _authTransitionState == AuthTransitionState.signingIn;

  void _beginOauthHandoff() {
    if (_oauthInProgress) {
      return;
    }
    _oauthInProgress = true;
    _authTransitionState = AuthTransitionState.signingIn;
    debugPrint('AUTH_TRANSITION oauth_handoff_started');
    notifyListeners();
  }

  void _endOauthHandoff() {
    if (!_oauthInProgress) {
      return;
    }
    _oauthInProgress = false;
    debugPrint('AUTH_TRANSITION oauth_handoff_ended');
    notifyListeners();
  }

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
      // appLog("🚫 Ignoring stale request: $requestId (current: $_currentRequestId)");
      return AuthRequestResult(
        requestId: requestId,
        success: false,
        error: 'Request cancelled',
      );
    }

    _currentRequestId = requestId;
    _signingOutUid = null;
    _authTransitionState = AuthTransitionState.signingIn;
    debugPrint('AUTH_TRANSITION debounced_sign_in_started request=$requestId');
    _startMinimumSpinner();
    notifyListeners();

    try {
      // appLog("🚀 Starting $requestType authentication (request: $requestId)");
      final result = await authFunction(requestId);

      // Only process if this is still the current request
      if (_currentRequestId == requestId) {
        _currentRequestId = null;
        if (result.success || _isLoggedIn) {
          _authTransitionState = resolveDebouncedAuthTransition(
            resultSuccess: result.success,
            isLoggedInFlag: _isLoggedIn,
          );
        } else {
          _authTransitionState = AuthTransitionState.unauthenticated;
        }
        notifyListeners();
      } else {
        // appLog("🚫 Ignoring stale response for request: $requestId");
      }

      return result;
    } catch (e) {
      // Only process if this is still the current request
      if (_currentRequestId == requestId) {
        _currentRequestId = null;
        if (_isLoggedIn) {
          _authTransitionState = resolveDebouncedAuthTransition(
            resultSuccess: false,
            isLoggedInFlag: _isLoggedIn,
          );
        } else {
          _authTransitionState = AuthTransitionState.unauthenticated;
        }
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
          return 'No account found with this email.';
        case 'wrong-password':
        case 'invalid-credential':
        case 'invalid-login-credentials':
          return 'Incorrect password.';
        case 'account-exists-with-different-credential':
          return 'An account already exists with this email. Sign in with '
              'your original method, then link Apple in settings.';
        case 'app-check-token-invalid':
        case 'app-check-failed':
          return 'App security check failed. Register the App Check debug '
              'token in Firebase Console, or disable App Check enforcement '
              'for Authentication while testing.';
        case 'weak-password':
          return 'Password is too weak. Use a stronger password.';
        default:
          if (_isNetworkAuthError(e)) {
            return 'Network error. Please check your connection.';
          }
          return e.message ?? 'Authentication failed.';
      }
    }
    if (_isNetworkAuthError(e)) {
      return 'Network error. Please check your connection.';
    }
    return e.toString();
  }

  Future<firebase_auth.User?> _awaitVerifiedFirebaseSession(
    firebase_auth.User firebaseUser,
  ) async {
    for (int attempt = 0; attempt < 5; attempt++) {
      final firebase_auth.User? currentUser = _authInstance.currentUser;
      if (currentUser != null && currentUser.uid == firebaseUser.uid) {
        return currentUser;
      }
      if (attempt < 4) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
    }
    return _authInstance.currentUser?.uid == firebaseUser.uid
        ? _authInstance.currentUser
        : null;
  }

  Future<AuthRequestResult> _completeSuccessfulAuth({
    required String requestId,
    required firebase_auth.User firebaseUser,
    required String provider,
    bool requires2FA = false,
  }) async {
    final firebase_auth.User? verifiedUser =
        await _awaitVerifiedFirebaseSession(firebaseUser);
    if (verifiedUser == null) {
      debugPrint(
        'AUTH_TRANSITION $provider session_validation_failed '
        'expectedUid=${firebaseUser.uid} '
        'currentUid=${_authInstance.currentUser?.uid ?? 'null'}',
      );
      return AuthRequestResult(
        requestId: requestId,
        success: false,
        error: 'Authentication session could not be verified.',
      );
    }

    debugPrint(
      'AUTH_TRANSITION $provider firebase_session_verified uid=${verifiedUser.uid}',
    );
    _promoteFirebaseSession(verifiedUser);
    debugPrint('AUTH_TRANSITION $provider hydrating_profile');
    try {
      await _handleUserSignIn(firebaseUser).timeout(_userHydrationTimeout);
    } on TimeoutException {
      debugPrint('AUTH_TRANSITION $provider profile_hydration_deferred');
    } catch (error, stackTrace) {
      debugPrint('AUTH_TRANSITION $provider profile_hydration_failed: $error');
      debugPrint('$stackTrace');
    }
    debugPrint('AUTH_TRANSITION $provider authenticated');

    return AuthRequestResult(
      requestId: requestId,
      success: true,
      user: _currentUser,
      requires2FA: requires2FA,
    );
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

        return _completeSuccessfulAuth(
          requestId: requestId,
          firebaseUser: userCredential.user!,
          provider: 'email',
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
      final String? resolvedEmail =
          await resolveEmailForUsername(normalizedUsername);

      if (resolvedEmail == null || resolvedEmail.trim().isEmpty) {
        await _rateLimiter.recordAttempt();
        return AuthRequestResult(
          requestId: requestId,
          success: false,
          error: 'No account found with that username.',
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
      debugPrint("🔐 Google auth[$requestId]: starting");

      // First, sign out any existing Google session to avoid conflicts
      debugPrint("🔐 Google auth[$requestId]: resetting Google session");
      await _googleSignInInstance.signOut().timeout(_googleSignOutTimeout);

      debugPrint("🔐 Google auth[$requestId]: opening account picker");
      final GoogleSignInAccount? googleUser =
          await _googleSignInInstance.signIn().timeout(
                _googleAccountPickerTimeout,
                onTimeout: () => null,
              );

      if (googleUser == null) {
        debugPrint("ℹ️ Google auth[$requestId]: cancelled or timed out");
        return AuthRequestResult(
          requestId: requestId,
          success: false,
          error: 'Google sign-in cancelled',
        );
      }

      debugPrint("AUTH_TRANSITION google account_selected");

      try {
        debugPrint("🔐 Google auth[$requestId]: requesting auth tokens");
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication.timeout(_googleTokenTimeout);

        if (googleAuth.accessToken == null || googleAuth.idToken == null) {
          debugPrint("❌ Google auth[$requestId]: missing auth tokens");
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

        debugPrint("🔐 Google auth[$requestId]: signing into Firebase");
        final userCredential = await _authInstance
            .signInWithCredential(credential)
            .timeout(_firebaseCredentialTimeout);

        if (userCredential.user != null) {
          final firebase_auth.User hydratedUser =
              await _reloadFirebaseUser(userCredential.user!);
          await _ensureMinimalUserDocument(
            firebaseUser: hydratedUser,
            authProvider: 'google',
          );
          return _completeSuccessfulAuth(
            requestId: requestId,
            firebaseUser: hydratedUser,
            provider: 'google',
          );
        } else {
          return AuthRequestResult(
            requestId: requestId,
            success: false,
            error: 'Google authentication failed',
          );
        }
      } catch (authError) {
        debugPrint(
            "❌ Google auth[$requestId]: Firebase/token step failed: $authError");
        // Sign out from Google if Firebase auth fails
        await _googleSignInInstance
            .signOut()
            .timeout(_googleSignOutTimeout, onTimeout: () => null);
        return AuthRequestResult(
          requestId: requestId,
          success: false,
          error: 'Firebase authentication failed: $authError',
        );
      }
    } catch (e) {
      debugPrint("❌ Google auth[$requestId]: failed: $e");
      // Use Google Services fix for error handling
      String errorMessage = GoogleServicesFix.getGoogleServicesErrorMessage(e);

      return AuthRequestResult(
        requestId: requestId,
        success: false,
        error: errorMessage,
      );
    }
  }

  /// Sign in with Apple (iOS/macOS; debounced, single-flight).
  Future<AuthRequestResult> signInWithApple(String requestId) async {
    try {
      debugPrint("🔐 Apple auth[$requestId]: starting");
      final bool isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        return AuthRequestResult(
          requestId: requestId,
          success: false,
          error: 'Sign in with Apple is not available on this device',
        );
      }
      final String rawNonce = generateAppleSignInRawNonce();
      final String hashedNonce = sha256HashForAppleSignIn(rawNonce);
      debugPrint("🔐 Apple auth[$requestId]: requesting Apple ID credential");
      final AuthorizationCredentialAppleID appleCredential =
          await SignInWithApple.getAppleIDCredential(
        scopes: <AppleIDAuthorizationScopes>[
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      ).timeout(_appleCredentialTimeout);
      debugPrint(
        'APPLE CREDENTIAL RECEIVED user=${appleCredential.userIdentifier ?? 'unknown'} '
        'hasIdentityToken=${appleCredential.identityToken?.isNotEmpty == true}',
      );
      final String? identityToken = appleCredential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        debugPrint("❌ Apple auth[$requestId]: missing identity token");
        return AuthRequestResult(
          requestId: requestId,
          success: false,
          error: 'Failed to get Apple authentication token',
        );
      }
      final String authorizationCode = appleCredential.authorizationCode;
      final firebase_auth.OAuthCredential credential =
          firebase_auth.OAuthProvider('apple.com').credential(
        idToken: identityToken,
        rawNonce: rawNonce,
        accessToken: authorizationCode,
      );
      debugPrint(
        'APPLE FIREBASE CREDENTIAL CREATED provider=apple.com '
        'hasAuthCode=${authorizationCode.isNotEmpty}',
      );
      debugPrint("🔐 Apple auth[$requestId]: signing into Firebase");
      final firebase_auth.UserCredential userCredential =
          await _signInWithAppleFirebaseCredential(
        requestId: requestId,
        credential: credential,
      );
      final firebase_auth.User? firebaseUser = userCredential.user;
      debugPrint(
        'APPLE FIREBASE UID: ${firebaseUser?.uid ?? 'null'} '
        'currentUser=${_authInstance.currentUser?.uid ?? 'null'}',
      );
      if (firebaseUser == null) {
        return AuthRequestResult(
          requestId: requestId,
          success: false,
          error: 'Apple authentication failed',
        );
      }
      await _applyAppleDisplayNameIfNeeded(
        firebaseUser: firebaseUser,
        appleCredential: appleCredential,
      );
      final firebase_auth.User hydratedUser =
          await _reloadFirebaseUser(firebaseUser);
      await _ensureMinimalUserDocument(
        firebaseUser: hydratedUser,
        authProvider: 'apple',
      );
      return _completeSuccessfulAuth(
        requestId: requestId,
        firebaseUser: hydratedUser,
        provider: 'apple',
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        debugPrint("ℹ️ Apple auth[$requestId]: cancelled");
        return AuthRequestResult(
          requestId: requestId,
          success: false,
          error: 'Apple sign-in cancelled',
        );
      }
      debugPrint("❌ Apple auth[$requestId]: authorization failed: ${e.code}");
      return AuthRequestResult(
        requestId: requestId,
        success: false,
        error: _appleSignInUserMessage(e),
      );
    } on TimeoutException {
      debugPrint("❌ Apple auth[$requestId]: timed out");
      return AuthRequestResult(
        requestId: requestId,
        success: false,
        error: 'Apple sign-in timed out. Please try again.',
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      debugPrint(
        "❌ Apple auth[$requestId]: Firebase error code=${e.code} "
        'message=${e.message ?? 'null'} email=${e.email ?? 'null'}',
      );
      return AuthRequestResult(
        requestId: requestId,
        success: false,
        error: _firebaseAuthUserMessage(e),
      );
    } catch (e) {
      debugPrint("❌ Apple auth[$requestId]: failed: $e");
      return AuthRequestResult(
        requestId: requestId,
        success: false,
        error: 'Apple sign-in failed. Please try again.',
      );
    }
  }

  Future<firebase_auth.UserCredential> _signInWithAppleFirebaseCredential({
    required String requestId,
    required firebase_auth.OAuthCredential credential,
  }) async {
    try {
      return await _authInstance
          .signInWithCredential(credential)
          .timeout(_firebaseCredentialTimeout);
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code != 'invalid-credential') {
        rethrow;
      }
      debugPrint(
        'AUTH_TRANSITION apple invalid_credential_retry request=$requestId',
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));
      return _authInstance
          .signInWithCredential(credential)
          .timeout(_firebaseCredentialTimeout);
    }
  }

  Future<void> _applyAppleDisplayNameIfNeeded({
    required firebase_auth.User firebaseUser,
    required AuthorizationCredentialAppleID appleCredential,
  }) async {
    if (firebaseUser.displayName != null &&
        firebaseUser.displayName!.trim().isNotEmpty) {
      return;
    }
    final String givenName = appleCredential.givenName?.trim() ?? '';
    final String familyName = appleCredential.familyName?.trim() ?? '';
    final String displayName = '$givenName $familyName'.trim();
    if (displayName.isEmpty) {
      return;
    }
    try {
      await firebaseUser.updateDisplayName(displayName);
      await firebaseUser.reload();
    } catch (e) {
      debugPrint('⚠️ Apple auth: could not set display name: $e');
    }
  }

  String _appleSignInUserMessage(SignInWithAppleAuthorizationException error) {
    switch (error.code) {
      case AuthorizationErrorCode.failed:
        return 'Apple sign-in failed. Please try again.';
      case AuthorizationErrorCode.invalidResponse:
        return 'Apple sign-in returned an invalid response.';
      case AuthorizationErrorCode.notHandled:
        return 'Apple sign-in could not be completed.';
      case AuthorizationErrorCode.notInteractive:
        return 'Apple sign-in requires user interaction.';
      case AuthorizationErrorCode.unknown:
      default:
        return 'Apple sign-in failed. Please try again.';
    }
  }

  void _promoteFirebaseSession(firebase_auth.User firebaseUser) {
    _signingOutUid = null;
    _currentUser ??= _mapFirebaseUserToFallback(firebaseUser);
    _isLoggedIn = true;
    _isCheckingAuth = false;
    _authTransitionState = AuthTransitionState.authenticated;
    notifyListeners();
  }

  Future<firebase_auth.User> _reloadFirebaseUser(
    firebase_auth.User firebaseUser,
  ) async {
    try {
      await firebaseUser.reload();
      return _authInstance.currentUser ?? firebaseUser;
    } catch (e) {
      debugPrint('AUTH_TRANSITION profile_reload_failed: $e');
      return firebaseUser;
    }
  }

  /// Merge a minimal profile so social sign-in never fails on missing docs.
  Future<void> _ensureMinimalUserDocument({
    required firebase_auth.User firebaseUser,
    required String authProvider,
  }) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> existingSnapshot =
          await _firestoreInstance
              .collection('users')
              .doc(firebaseUser.uid)
              .get();
      final Map<String, dynamic>? existingData = existingSnapshot.data();
      final Map<String, String> avatarFields = buildProviderAvatarMergeFields(
        providerPhotoUrl: firebaseUser.photoURL,
        existingData: existingData,
      );
      await _firestoreInstance.collection('users').doc(firebaseUser.uid).set(
        <String, dynamic>{
          'uid': firebaseUser.uid,
          'id': firebaseUser.uid,
          'email': firebaseUser.email,
          'displayName': firebaseUser.displayName,
          'authProvider': authProvider,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'isDeleted': false,
          ...avatarFields,
        },
        SetOptions(merge: true),
      );
      debugPrint(
        'AUTH_TRANSITION $authProvider minimal_profile_merged uid=${firebaseUser.uid}',
      );
    } catch (e) {
      debugPrint(
        'AUTH_TRANSITION $authProvider minimal_profile_merge_failed: $e',
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
    _beginOauthHandoff();
    return _debouncedAuth(
      'google',
      (requestId) => signInWithGoogle(requestId),
    ).whenComplete(_endOauthHandoff);
  }

  Future<AuthRequestResult> debouncedSignInWithApple() {
    _beginOauthHandoff();
    return _debouncedAuth(
      'apple',
      (requestId) => signInWithApple(requestId),
    ).whenComplete(_endOauthHandoff);
  }

  /// Resolve a normalized username to the account email stored in Firestore.
  Future<String?> resolveEmailForUsername(String normalizedUsername) async {
    final String normalized = normalizedUsername.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    final QuerySnapshot<Map<String, dynamic>> lowercaseQuery =
        await _firestoreInstance
            .collection('users')
            .where('usernameLowercase', isEqualTo: normalized)
            .limit(1)
            .get();
    if (lowercaseQuery.docs.isNotEmpty) {
      return lowercaseQuery.docs.first.data()['email'] as String?;
    }
    final QuerySnapshot<Map<String, dynamic>> usernameQuery =
        await _firestoreInstance
            .collection('users')
            .where('username', isEqualTo: normalized)
            .limit(1)
            .get();
    if (usernameQuery.docs.isEmpty) {
      return null;
    }
    return usernameQuery.docs.first.data()['email'] as String?;
  }

  Future<AuthRequestResult> debouncedSignUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    required String username,
  }) {
    return _debouncedAuth('signup', (requestId) async {
      try {
        await signUpWithEmail(
          email,
          password,
          displayName,
          username,
          requestId: requestId,
        );
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
  Future<void> signUpWithEmail(
      String email, String password, String displayName, String username,
      {String? requestId}) async {
    debugPrint('AUTH_TRANSITION email_signup starting');

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

        final AuthRequestResult completion = await _completeSuccessfulAuth(
          requestId: requestId ?? _generateRequestId(),
          firebaseUser: userCredential.user!,
          provider: 'email_signup',
        );
        if (!completion.success) {
          throw Exception(completion.error ?? 'Authentication failed');
        }

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
        debugPrint(
          'AUTH_TRANSITION email_signup existing_profile_preserved',
        );
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
      final existingSnapshot = await userRef.get();
      if (existingSnapshot.exists) {
        await userRef.set(
          {
            'uid': firebaseUser.uid,
            'id': firebaseUser.uid,
            'email': firebaseUser.email,
            'updatedAt': FieldValue.serverTimestamp(),
            'isDeleted': false,
          },
          SetOptions(merge: true),
        );
      } else {
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
      }

      // appLog("✅ User document created in Firestore");
    } catch (e) {
      // appLog("❌ Error creating user document: $e");
      rethrow;
    }
  }

  /// Handle user sign in and load user data from Firestore
  Future<void> _handleUserSignIn(firebase_auth.User firebaseUser) async {
    if (_shouldIgnoreAuthUserEvent(firebaseUser)) {
      return;
    }
    final Future<void>? inFlight = _userSignInInFlight;
    if (inFlight != null && _userSignInInFlightUid == firebaseUser.uid) {
      debugPrint('AUTH_TRANSITION profile_hydration_joined');
      return inFlight;
    }

    final Future<void> hydration = _handleUserSignInOnce(firebaseUser);
    _userSignInInFlight = hydration;
    _userSignInInFlightUid = firebaseUser.uid;
    return hydration.whenComplete(() {
      if (identical(_userSignInInFlight, hydration)) {
        _userSignInInFlight = null;
        _userSignInInFlightUid = null;
      }
    });
  }

  Future<void> _handleUserSignInOnce(firebase_auth.User firebaseUser) async {
    if (_shouldIgnoreAuthUserEvent(firebaseUser)) {
      return;
    }
    debugPrint('AUTH_TRANSITION profile_hydration_started');

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

        final List<CalendarEvent> calendarEvents =
            UserProfileFirestore.parseCalendarEventsFromUserData(data);

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
        _authTransitionState = AuthTransitionState.authenticated;
        notifyListeners();

        debugPrint("✅ User signed in successfully - isLoggedIn: $_isLoggedIn");

        // Add account to TikTok account switcher for instant switching
        await _accountSwitcher.addCurrentAccount();

        _setupUserDataListener(firebaseUser.uid);
        await _ensureUserDocumentExists();

        HomeFirstFrameGate.instance.runAfterFirstFrame(() {
          if (_authTransitionState == AuthTransitionState.signingOut) {
            return;
          }
          unawaited(
            _accountSwitcher.triggerDataRefreshWithRef(
              null,
              clearCaches: false,
              invalidateHomeFeed: false,
            ),
          );
          unawaited(_registerFCMToken(firebaseUser.uid));
        });
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
        _authTransitionState = AuthTransitionState.authenticated;
        notifyListeners();

        debugPrint(
            "✅ New user created and signed in successfully - isLoggedIn: $_isLoggedIn");

        // Add account to TikTok account switcher for instant switching
        await _accountSwitcher.addCurrentAccount();

        _setupUserDataListener(firebaseUser.uid);

        HomeFirstFrameGate.instance.runAfterFirstFrame(() {
          if (_authTransitionState == AuthTransitionState.signingOut) {
            return;
          }
          unawaited(_accountSwitcher.triggerDataRefreshWithRef(null));
          unawaited(_registerFCMToken(firebaseUser.uid));
        });
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
        if (_isLoggedIn &&
            _currentUser == null &&
            _authTransitionState != AuthTransitionState.signingOut) {
          debugPrint('🔄 Retrying user data load...');
          _handleUserSignIn(firebaseUser).catchError((Object retryError) {
            debugPrint('❌ Retry failed: $retryError');
          });
        }
      });
    }
  }

  void _cancelUserFirestoreSubscription() {
    _userFirestoreSubscription?.cancel();
    _userFirestoreSubscription = null;
  }

  /// Set up real-time listener for user data changes
  void _setupUserDataListener(String userId) {
    _cancelUserFirestoreSubscription();
    _userFirestoreSubscription = _firestoreInstance
        .collection("users")
        .doc(userId)
        .snapshots()
        .listen((DocumentSnapshot<Map<String, dynamic>> snapshot) {
      if (_authTransitionState == AuthTransitionState.signingOut) {
        return;
      }
      if (snapshot.exists && _currentUser != null) {
        final data = snapshot.data()!;

        // Check if avatar URL has changed
        final newAvatarURLString = resolveAvatarUrl(data) ?? '';
        final currentAvatarURLString = _currentUser!.avatarURL ?? '';

        if (newAvatarURLString != currentAvatarURLString &&
            newAvatarURLString.isNotEmpty) {
          // appLog("🔄 Avatar URL changed in Firestore - updating app");
          // appLog("📸 Old: $currentAvatarURLString");
          // appLog("📸 New: $newAvatarURLString");

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
          // appLog("🔄 User data changed in Firestore - updating app");

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
      final String? avatarUrl = normalizeAvatarPhotoUrl(user.avatarURL);
      final userData = <String, dynamic>{
        'uid': user.id,
        'id': user.id,
        'username': user.username.toLowerCase(),
        'usernameLowercase': user.username.toLowerCase(),
        'displayName': user.displayName,
        'bio': user.bio,
        'avatarURL': avatarUrl,
        'avatarUrl': avatarUrl,
        'photoURL': avatarUrl,
        'onlineStatus': user.onlineStatus,
        'hashtags': user.hashtags,
        'aiSelf': user.aiSelf,
        'postCount': user.postCount,
        'followerCount': user.followerCount,
        'followingCount': user.followingCount,
        'updatedAt': FieldValue.serverTimestamp(),
        'isDeleted': false,
      };

      if (email != null) {
        userData['email'] = email;
      }

      await _firestoreInstance.collection('users').doc(user.id).set(
            userData,
            SetOptions(merge: true),
          );
    } catch (e) {
      rethrow;
    }
  }

  /// Ensure user document exists
  Future<void> _ensureUserDocumentExists() async {
    final firebase_auth.User? firebaseUser = _authInstance.currentUser;
    if (firebaseUser == null) {
      return;
    }
    final String? providerId = firebaseUser.providerData.isNotEmpty
        ? firebaseUser.providerData.first.providerId
        : null;
    final String authProvider = providerId == 'apple.com'
        ? 'apple'
        : providerId == 'google.com'
            ? 'google'
            : providerId ?? 'password';
    await _ensureMinimalUserDocument(
      firebaseUser: firebaseUser,
      authProvider: authProvider,
    );
  }

  /// Sign out
  Future<void> signOut() async {
    if (_authTransitionState == AuthTransitionState.signingOut) {
      debugPrint('🔐 Sign out already in progress');
      return;
    }
    if (_oauthInProgress ||
        _currentRequestId != null ||
        _authTransitionState == AuthTransitionState.signingIn) {
      debugPrint('AUTH_TRANSITION sign_out_deferred_sign_in_in_progress');
      return;
    }
    final int signOutGeneration = ++_signOutGeneration;
    try {
      debugPrint("🔐 Starting sign out process...");

      final String? signingOutUid =
          _authInstance.currentUser?.uid ?? _currentUser?.id;
      _signingOutUid = signingOutUid;

      _authTransitionState = AuthTransitionState.signingOut;
      _userSignInInFlight = null;
      _userSignInInFlightUid = null;
      _currentUser = null;
      _isLoggedIn = false;
      _isCheckingAuth = false;
      notifyListeners();

      _cancelUserFirestoreSubscription();
      await AuthSessionTeardown.executeBeforeSignOut();

      if (_signOutGeneration != signOutGeneration ||
          _currentRequestId != null ||
          _authTransitionState == AuthTransitionState.signingIn) {
        debugPrint('AUTH_TRANSITION sign_out_aborted_for_sign_in');
        final firebase_auth.User? activeUser = _authInstance.currentUser;
        if (activeUser != null) {
          _promoteFirebaseSession(activeUser);
        } else {
          _cleanupAuthState();
        }
        return;
      }

      if (_authInstance.currentUser == null) {
        debugPrint("⚠️ User already signed out, cleaning up state...");
        _cleanupAuthState();
        return;
      }

      await _removeCurrentDeviceToken();

      if (_signOutGeneration != signOutGeneration ||
          _currentRequestId != null ||
          _authTransitionState == AuthTransitionState.signingIn) {
        debugPrint('AUTH_TRANSITION sign_out_aborted_for_sign_in');
        final firebase_auth.User? activeUser = _authInstance.currentUser;
        if (activeUser != null) {
          _promoteFirebaseSession(activeUser);
        } else {
          _cleanupAuthState();
        }
        return;
      }

      await _authInstance.signOut();
      await GoogleServicesFix.signOutFromGoogle();
      _cleanupAuthState();
      debugPrint("✅ User signed out successfully");
    } catch (e) {
      debugPrint("❌ Error signing out: $e");
      _cleanupAuthState();
      rethrow;
    }
  }

  /// Register FCM token for push notifications
  Future<void> _registerFCMToken(String userId) async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Check existing permission status
      final currentSettings = await messaging.getNotificationSettings();

      // Do not prompt on sign-in. Progression prompts after the first creator
      // action so notifications feel tied to momentum, not app launch.
      if (currentSettings.authorizationStatus ==
          AuthorizationStatus.notDetermined) {
        debugPrint("ℹ️ Notification permission not requested at sign-in");
        return;
      }
      if (currentSettings.authorizationStatus !=
              AuthorizationStatus.authorized &&
          currentSettings.authorizationStatus !=
              AuthorizationStatus.provisional) {
        debugPrint("⚠️ Notification permission not granted");
        return;
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
        debugPrint("✅ FCM token obtained");

        await _firestoreInstance
            .collection('users')
            .doc(userId)
            .collection('deviceTokens')
            .doc(fcmToken)
            .set({
          'token': fcmToken,
          'platform': _fcmPlatformName(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastUsed': FieldValue.serverTimestamp(),
          'source': 'auth',
        }, SetOptions(merge: true));

        debugPrint("✅ FCM token added to deviceTokens collection");

        // Listen for token refresh
        messaging.onTokenRefresh.listen((newToken) async {
          debugPrint("🔄 FCM token refreshed");
          try {
            await _firestoreInstance
                .collection('users')
                .doc(userId)
                .collection('deviceTokens')
                .doc(newToken)
                .set({
              'token': newToken,
              'platform': _fcmPlatformName(),
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
              'lastUsed': FieldValue.serverTimestamp(),
              'source': 'auth_refresh',
            }, SetOptions(merge: true));
            debugPrint("✅ Updated FCM token in deviceTokens");
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

      debugPrint("🧹 Removed FCM token on logout");
    } catch (e) {
      debugPrint("⚠️ Error removing FCM token on logout: $e");
      // Don't fail logout if token removal fails
    }
  }

  /// Clean up authentication state
  void _cleanupAuthState() {
    _signingOutUid = null;
    _userSignInInFlight = null;
    _userSignInInFlightUid = null;
    _cancelUserFirestoreSubscription();
    _currentUser = null;
    _isLoggedIn = false;
    _isCheckingAuth = false;
    _authTransitionState = AuthTransitionState.unauthenticated;
    _currentRequestId = null;
    _debounceTimer?.cancel();
    _minimumSpinnerTimer?.cancel();
    _isMinimumSpinnerActive = false;
    notifyListeners();
  }

  /// Update user calendar events in Firestore
  Future<void> updateUserCalendarEvents(List<dynamic> events) async {
    if (_currentUser == null) {
      // appLog('❌ No current user to update calendar events');
      return;
    }

    try {
      final List<Map<String, dynamic>> eventsData =
          UserProfileFirestore.calendarEventsToFirestore(
        events.cast<CalendarEvent>(),
      );
      UserProfileFirestore.logCalendarSave(
        uid: _currentUser!.id,
        source: 'CalendarCreate',
        count: eventsData.length,
      );

      await _firestoreInstance
          .collection('users')
          .doc(_currentUser!.id)
          .update({
        UserProfileFirestore.calendarEventsField: eventsData,
      });

      // appLog('✅ Calendar events successfully updated in Firestore');
    } catch (e) {
      // appLog('❌ Error updating calendar events in Firestore: $e');
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _authInstance.sendPasswordResetEmail(email: email.trim());
      debugPrint("✅ Password reset email sent");
    } catch (e) {
      debugPrint("❌ Password reset error: $e");
      rethrow;
    }
  }

  /// Sends a reset email when possible; always returns a neutral success copy.
  Future<PasswordResetRequestResult> sendPasswordResetForIdentifier(
    String emailOrUsername,
  ) async {
    final String trimmed = emailOrUsername.trim();
    if (trimmed.isEmpty) {
      return const PasswordResetRequestResult(
        success: false,
        error: 'Enter your email or username.',
      );
    }
    String? targetEmail;
    if (trimmed.contains('@')) {
      if (!trimmed.contains('.') || trimmed.length < 5) {
        return const PasswordResetRequestResult(
          success: false,
          error: 'Enter a valid email address.',
        );
      }
      targetEmail = trimmed;
    } else {
      targetEmail = await resolveEmailForUsername(trimmed.toLowerCase());
    }
    if (targetEmail != null && targetEmail.trim().isNotEmpty) {
      try {
        await _authInstance.sendPasswordResetEmail(email: targetEmail.trim());
      } on firebase_auth.FirebaseAuthException catch (e) {
        if (e.code == 'invalid-email') {
          return const PasswordResetRequestResult(
            success: false,
            error: 'Enter a valid email address.',
          );
        }
        if (e.code == 'too-many-requests') {
          return const PasswordResetRequestResult(
            success: false,
            error: 'Too many requests. Please try again later.',
          );
        }
        if (_isNetworkAuthError(e)) {
          return const PasswordResetRequestResult(
            success: false,
            error: 'Network error. Please check your connection.',
          );
        }
      } catch (e) {
        if (_isNetworkAuthError(e)) {
          return const PasswordResetRequestResult(
            success: false,
            error: 'Network error. Please check your connection.',
          );
        }
      }
    }
    return const PasswordResetRequestResult(
      success: true,
      message:
          'Password reset email sent if an account exists for that address.',
    );
  }

  bool _isNetworkAuthError(Object error) {
    final String message = error.toString().toLowerCase();
    return message.contains('network') || message.contains('socket');
  }

  String _fcmPlatformName() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'unknown';
    }
  }
}

// Provider for the robust authentication service
final robustAuthServiceProvider =
    ChangeNotifierProvider<RobustAuthenticationService>((ref) {
  ref.keepAlive();
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
