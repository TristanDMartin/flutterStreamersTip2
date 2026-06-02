import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/user.dart';
import '../models/user_count_fields.dart';
import '../models/user_status.dart';
import 'username_lock_service.dart';
import 'r2_media_service.dart';
import '../utils/avatar_url_resolver.dart';
import '../utils/password_validation.dart';

class AuthenticationService extends ChangeNotifier {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UsernameLockService _usernameLockService = UsernameLockService();

  StreamSubscription<firebase_auth.User?>? _authStateSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDataSub;

  User? _currentUser;
  bool _isLoading = false;
  bool _isLoggedIn = false;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;

  // Get current user profile data from Firestore
  Map<String, dynamic>? _currentUserProfile;
  Map<String, dynamic>? get currentUserProfile => _currentUserProfile;

  AuthenticationService() {
    _authStateSub = _auth.authStateChanges().listen((firebase_auth.User? user) {
      if (user != null) {
        _handleUserSignIn(user);
      } else {
        _currentUser = null;
        _isLoggedIn = false;
        notifyListeners();
      }
    });
  }

  // Handle user sign in and load user data from Firestore
  Future<void> _handleUserSignIn(firebase_auth.User firebaseUser) async {
    // appLog("🔐 handleUserSignIn called for user: ${firebaseUser.uid}");
    // appLog("👤 User display name: ${firebaseUser.displayName ?? 'nil'}");
    // appLog("📧 User email: ${firebaseUser.email ?? 'nil'}");

    try {
      final userRef = _firestore.collection("users").doc(firebaseUser.uid);
      final snapshot = await userRef.get();

      // appLog("📄 Firestore document fetch completed");
      // appLog("🔐 Document exists: ${snapshot.exists}");

      if (snapshot.exists && snapshot.data() != null) {
        // appLog("🔐 User document found in Firestore");
        final data = snapshot.data()!;

        // Note: calendarEvents and platforms can be added later if needed

        // Decode hashtags from Firestore
        List<String> hashtags = _parseHashtags(data['hashtags']) ?? [];

        // Create user object with Firestore data
        final user = User(
          id: firebaseUser.uid,
          username: data['username'] as String? ?? 'user',
          displayName: data['displayName'] as String? ?? 'User',
          bio: data['bio'] as String? ?? '',
          avatarURL: resolveAvatarUrl(data),
          onlineStatus: data['onlineStatus'] as String? ?? 'online',
          hashtags: hashtags,
          postCount: data['postCount'] as int? ?? 0,
          followerCount: UserCountFields.readFollowersCount(data),
          followingCount: UserCountFields.readFollowingCount(data),
        );

        _currentUser = user;
        _isLoggedIn = true;
        notifyListeners();

        // appLog("✅ User signed in successfully - isLoggedIn: $_isLoggedIn");

        // Set up real-time listener for user data changes
        _setupUserDataListener(firebaseUser.uid);

        // Ensure user document exists (handles any edge cases)
        await _ensureUserDocumentExists(firebaseUser);

        // Initialize user status as online
        await setUserOnline();
      } else {
        // appLog("🔐 Creating new user document in Firestore");
        await _createNewUserDocument(firebaseUser);

        // Initialize user status as online
        await setUserOnline();
      }
    } catch (e) {
      // appLog("❌ Error handling user sign in: $e");
      // Fallback to basic user data
      final user = User(
        id: firebaseUser.uid,
        username: firebaseUser.displayName?.toLowerCase().replaceAll(' ', '') ??
            'user',
        displayName: firebaseUser.displayName ?? 'User',
        bio: '',
        avatarURL: firebaseUser.photoURL,
        onlineStatus: 'online',
        hashtags: [],
        postCount: 0,
        followerCount: 0,
        followingCount: 0,
      );

      _currentUser = user;
      _isLoggedIn = true;
      notifyListeners();

      // Initialize user status as online
      await setUserOnline();
    }
  }

  // Create new user document in Firestore
  Future<void> _createNewUserDocument(firebase_auth.User firebaseUser) async {
    // appLog("🔐 Creating new user document in Firestore for: ${firebaseUser.uid}");

    // Generate a unique username from display name
    final baseUsername =
        firebaseUser.displayName?.toLowerCase().replaceAll(' ', '') ?? 'user';
    final username = await _generateUniqueUsername(baseUsername);

    final user = User(
      id: firebaseUser.uid,
      username: username,
      displayName: firebaseUser.displayName ?? 'User',
      bio: '',
      avatarURL: firebaseUser.photoURL,
      onlineStatus: 'online',
      hashtags: [],
      postCount: 0,
      followerCount: 0,
      followingCount: 0,
    );

    // Save the new user to Firestore
    await _saveUserToFirestore(user, firebaseUser.email);

    _currentUser = user;
    _isLoggedIn = true;
    notifyListeners();

    // appLog("✅ New user signed in successfully - isLoggedIn: $_isLoggedIn");

    // Set up real-time listener for the new user
    _setupUserDataListener(firebaseUser.uid);
  }

  // Generate unique username
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

  // Save user to Firestore
  Future<void> _saveUserToFirestore(User user, String? email) async {
    try {
      // Save user document with UID as document ID (for compatibility)
      await _firestore.collection('users').doc(user.id).set({
        'id': user.id,
        'uid': user.id, // Explicit UID field for clarity
        'username': user.username,
        'displayName': user.displayName,
        'bio': user.bio,
        'avatarURL': user.avatarURL,
        'avatarUrl': user.avatarURL,
        'email': email,
        'onlineStatus': user.onlineStatus,
        'hashtags': user.hashtags,
        'postCount': user.postCount,
        'followerCount': user.followerCount,
        'followingCount': user.followingCount,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Also create a username-to-UID mapping for easier tracking
      await _firestore.collection('usernames').doc(user.username).set({
        'uid': user.id,
        'username': user.username,
        'displayName': user.displayName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // appLog("✅ User document saved to Firestore with username mapping: ${user.username} -> ${user.id}");
    } catch (e) {
      // appLog("❌ Error saving user to Firestore: $e");
    }
  }

  // Set up real-time listener for user data changes
  void _setupUserDataListener(String userId) {
    _userDataSub?.cancel();
    _userDataSub = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && _currentUser != null) {
        final data = snapshot.data()!;

        // Update current user with latest data
        final updatedUser = User(
          id: _currentUser!.id,
          username: data['username'] as String? ?? _currentUser!.username,
          displayName:
              data['displayName'] as String? ?? _currentUser!.displayName,
          bio: data['bio'] as String? ?? _currentUser!.bio,
          avatarURL: resolveAvatarUrl(data) ?? _currentUser!.avatarURL,
          onlineStatus:
              data['onlineStatus'] as String? ?? _currentUser!.onlineStatus,
          hashtags: _parseHashtags(data['hashtags']) ?? _currentUser!.hashtags,
          postCount: data['postCount'] as int? ?? _currentUser!.postCount,
          followerCount: UserCountFields.readFollowersCount(data),
          followingCount: UserCountFields.readFollowingCount(data),
        );

        _currentUser = updatedUser;
        notifyListeners();
        // appLog("🔄 User data updated from Firestore listener");
      }
    });
  }

  // Ensure user document exists
  Future<void> _ensureUserDocumentExists(
      firebase_auth.User firebaseUser) async {
    try {
      final userRef = _firestore.collection("users").doc(firebaseUser.uid);
      final snapshot = await userRef.get();

      if (!snapshot.exists) {
        // appLog("🔐 User document doesn't exist, creating...");
        await _createNewUserDocument(firebaseUser);
      }
    } catch (e) {
      // appLog("❌ Error ensuring user document exists: $e");
    }
  }

  // Sign in with Google
  Future<void> signInWithGoogle() async {
    try {
      // appLog("🔐 Starting Google Sign-In process");
      setLoading(true);

      // First, sign out any existing Google session to avoid conflicts
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // appLog("❌ Google Sign-In cancelled by user");
        setLoading(false);
        return;
      }

      // appLog("✅ Google Sign-In successful for: ${googleUser.email}");

      try {
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final accessToken = googleAuth.accessToken;
        final idToken = googleAuth.idToken;

        if (accessToken == null || idToken == null) {
          // appLog("❌ Missing Google authentication tokens");
          setLoading(false);
          throw Exception("Failed to get Google authentication tokens");
        }

        final credential = firebase_auth.GoogleAuthProvider.credential(
          accessToken: accessToken,
          idToken: idToken,
        );

        // appLog("🔐 Signing in to Firebase with Google credential");
        final firebase_auth.UserCredential userCredential =
            await _auth.signInWithCredential(credential);
        final firebase_auth.User? user = userCredential.user;

        if (user != null) {
          // appLog("✅ Firebase authentication successful for: ${user.email}");
          // The auth state listener will handle the rest
        }

        setLoading(false);
        // appLog("🎉 Google Sign-In process completed successfully");
      } catch (authError) {
        // appLog("❌ Firebase authentication error: $authError");
        // Sign out from Google if Firebase auth fails
        await _googleSignIn.signOut();
        setLoading(false);
        rethrow;
      }
    } catch (e) {
      // appLog("❌ Google Sign-In error: $e");
      setLoading(false);

      // Provide more specific error messages
      if (e.toString().contains('network_error')) {
        throw Exception(
            'Network error. Please check your internet connection.');
      } else if (e.toString().contains('sign_in_canceled')) {
        throw Exception('Sign-in was cancelled.');
      } else if (e.toString().contains('sign_in_failed')) {
        throw Exception('Sign-in failed. Please try again.');
      } else {
        throw Exception('Google Sign-In failed. Please try again.');
      }
    }
  }

  // Sign in with email
  Future<void> signInWithEmail(String email, String password) async {
    try {
      // appLog("📧 Starting email authentication for: $email");
      setLoading(true);

      final userCredential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);

      if (userCredential.user != null) {
        // appLog("✅ Email authentication successful for: ${userCredential.user!.email}");
        // Auth state listener will handle the rest
      }

      setLoading(false);
    } catch (e) {
      // appLog("❌ Email sign in error: $e");
      setLoading(false);

      // Provide more specific error messages
      if (e.toString().contains('user-not-found')) {
        throw Exception('No account found with this email address');
      } else if (e.toString().contains('wrong-password')) {
        throw Exception('Incorrect password');
      } else if (e.toString().contains('invalid-email')) {
        throw Exception('Invalid email address');
      } else if (e.toString().contains('user-disabled')) {
        throw Exception('This account has been disabled');
      } else if (e.toString().contains('too-many-requests')) {
        throw Exception('Too many failed attempts. Please try again later');
      } else {
        throw Exception('Authentication failed. Please check your credentials');
      }
    }
  }

  // Sign in with username (lowercase lookup; same semantics as web LoginModal)
  Future<void> signInWithUsername(String username, String password) async {
    try {
      setLoading(true);
      final String trimmed = username.trim();
      if (trimmed.isEmpty) {
        throw Exception('Enter your username.');
      }
      final String normalizedUsername = trimmed.toLowerCase();
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: normalizedUsername)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        throw Exception('No account found with this email or username.');
      }

      final Map<String, dynamic> userData = snapshot.docs.first.data();
      final String? email = userData['email'] as String?;
      if (email == null || email.trim().isEmpty) {
        throw Exception('No account found with this email or username.');
      }

      await signInWithEmail(email.trim(), password);
    } catch (e) {
      setLoading(false);
      rethrow;
    }
  }

  // Sign up with email
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    required String username,
  }) async {
    try {
      setLoading(true);
      final String normalizedUsername = username.trim().toLowerCase();
      final String trimMail = email.trim();
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

      final firebase_auth.UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: trimMail,
        password: password,
      );

      final firebase_auth.User? user = userCredential.user;
      if (user != null) {
        final String profileName = displayName.trim().isNotEmpty
            ? displayName.trim()
            : normalizedUsername;
        await user.updateDisplayName(profileName);
        await _createOrUpdateUserDocument(
          user,
          displayName: profileName,
          username: normalizedUsername,
        );
      }

      setLoading(false);
    } catch (e) {
      setLoading(false);
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Remove FCM token before signing out
      await _removeCurrentDeviceToken();

      // Set user as offline before signing out
      await setUserOffline();

      await _auth.signOut();
      await _googleSignIn.signOut();

      _currentUser = null;
      _isLoggedIn = false;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Remove current device's FCM token from Firestore
  Future<void> _removeCurrentDeviceToken() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Get current FCM token
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;

      // Remove from deviceTokens subcollection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('deviceTokens')
          .doc(fcmToken)
          .delete();

      debugPrint("🧹 Removed FCM token on logout");
    } catch (e) {
      debugPrint("⚠️ Error removing FCM token: $e");
      // Don't fail logout if token removal fails
    }
  }

  // Create or update user document in Firestore
  Future<void> _createOrUpdateUserDocument(firebase_auth.User user,
      {String? displayName, String? username}) async {
    try {
      final userData = <String, dynamic>{
        'id': user.uid,
        'uid': user.uid,
        'email': user.email,
        'displayName': displayName ?? user.displayName ?? 'Unknown User',
        'username': username ?? _generateUsernameFromEmail(user.email ?? ''),
        'photoURL': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastSignIn': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(user.uid).set(
            userData,
            SetOptions(merge: true),
          );
    } catch (e) {
      // appLog("❌ Error creating/updating user document: $e");
    }
  }

  // Generate username from email
  String _generateUsernameFromEmail(String email) {
    final emailPrefix = email.split('@')[0];
    return emailPrefix.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
  }

  // Change password
  Future<void> changePassword(
      String currentPassword, String newPassword) async {
    try {
      setLoading(true);

      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      final String? rejectReason =
          PasswordRequirements.signupRejectReason(newPassword);
      if (rejectReason != null) {
        throw Exception(rejectReason);
      }

      // Re-authenticate user with current password
      final credential = firebase_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);

      // appLog("✅ Password updated successfully");
      setLoading(false);
    } catch (e) {
      // appLog("❌ Password change error: $e");
      setLoading(false);

      if (e.toString().contains('wrong-password')) {
        throw Exception('Current password is incorrect');
      } else if (e.toString().contains('weak-password')) {
        throw Exception('New password is too weak');
      } else {
        throw Exception('Failed to change password. Please try again');
      }
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      setLoading(true);

      await _auth.sendPasswordResetEmail(email: email);

      // appLog("✅ Password reset email sent to: $email");
      setLoading(false);
    } catch (e) {
      // appLog("❌ Password reset error: $e");
      setLoading(false);

      if (e.toString().contains('user-not-found')) {
        throw Exception('No account found with this email address');
      } else if (e.toString().contains('invalid-email')) {
        throw Exception('Invalid email address');
      } else {
        throw Exception('Failed to send password reset email');
      }
    }
  }

  // Upload avatar image to Firebase Storage and update user profile
  Future<String> uploadAvatar(File imageFile) async {
    try {
      setLoading(true);
      debugPrint(
          '🔄 Starting avatar upload for user: ${_auth.currentUser?.uid}');

      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ Avatar upload failed: User not authenticated');
        throw Exception('User not authenticated');
      }

      // Validate file exists and is readable
      if (!await imageFile.exists()) {
        debugPrint('❌ Avatar upload failed: File does not exist');
        throw Exception('Selected image file does not exist');
      }

      final fileSize = await imageFile.length();
      const maxSize = 5 * 1024 * 1024;
      if (fileSize > maxSize) {
        debugPrint('❌ Avatar upload failed: File too large ($fileSize bytes)');
        throw Exception('Image file is too large. Maximum size is 5MB.');
      }
      debugPrint('✅ File validation passed. Size: $fileSize bytes');

      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        debugPrint('❌ Avatar upload failed: No network connection');
        throw Exception(
            'No internet connection. Please check your network and try again.');
      }

      debugPrint('⬆️ Uploading avatar to R2...');
      final downloadUrl = await R2MediaService.instance.uploadAvatar(imageFile);
      debugPrint('✅ Avatar uploaded to R2: $downloadUrl');

      // Update user profile in Firestore (website + legacy readers use photoURL)
      debugPrint('💾 Updating user profile in Firestore...');
      final nowTs = FieldValue.serverTimestamp();
      await _firestore.collection('users').doc(user.uid).update({
        'avatarURL': downloadUrl,
        'avatarUrl': downloadUrl,
        'photoURL': downloadUrl,
        'avatarUpdatedAt': nowTs,
        'updatedAt': nowTs,
      });

      debugPrint('✅ Firestore profile updated successfully');

      // Best-effort mirror for list/discovery surfaces that read publicUsers.
      await _syncPublicUserAvatar(user.uid, downloadUrl);

      // Firebase Auth photoURL — web clients often read currentUser.photoURL
      try {
        await user.updatePhotoURL(downloadUrl);
        await user.reload();
        await user.getIdToken(true);
        debugPrint('✅ Firebase Auth photoURL + ID token refreshed');
      } catch (e) {
        debugPrint(
          '⚠️ Auth photoURL update failed (Firestore still has new URL): $e',
        );
      }

      // Update current user profile data
      if (_currentUserProfile != null) {
        _currentUserProfile!['avatarURL'] = downloadUrl;
        _currentUserProfile!['avatarUrl'] = downloadUrl;
        _currentUserProfile!['photoURL'] = downloadUrl;
        _currentUserProfile!['avatarUpdatedAt'] =
            DateTime.now().toIso8601String();
        _currentUserProfile!['updatedAt'] = DateTime.now().toIso8601String();
      }

      // Update current user object
      if (_currentUser != null) {
        _currentUser = User(
          id: _currentUser!.id,
          username: _currentUser!.username,
          displayName: _currentUser!.displayName,
          bio: _currentUser!.bio,
          avatarURL: downloadUrl,
          onlineStatus: _currentUser!.onlineStatus,
          hashtags: _currentUser!.hashtags,
          postCount: _currentUser!.postCount,
          followerCount: _currentUser!.followerCount,
          followingCount: _currentUser!.followingCount,
        );
        notifyListeners();
      }

      debugPrint('🎉 Avatar uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Error uploading avatar: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('❌ Error toString: ${e.toString()}');
      if (e is Exception) {
        debugPrint('❌ Exception details: ${e.toString()}');
      }

      String errorMessage = 'Failed to upload avatar';
      if (e.toString().contains('Media upload not configured')) {
        errorMessage =
            'Avatar upload is temporarily unavailable. Try again later.';
      } else if (e.toString().contains('No internet connection')) {
        errorMessage =
            'No internet connection. Please check your network and try again.';
      } else if (e.toString().contains('network') ||
          e.toString().contains('timeout')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('too large')) {
        errorMessage = e.toString().split(': ').last;
      } else if (e.toString().contains('does not exist')) {
        errorMessage = e.toString().split(': ').last;
      } else if (e.toString().contains('User not authenticated')) {
        errorMessage = 'Please sign in again to upload your avatar.';
      } else if (e.toString().contains('File too large')) {
        errorMessage = e.toString().split(': ').last;
      } else {
        errorMessage = 'Failed to upload avatar: ${e.toString()}';
      }

      throw Exception(errorMessage);
    } finally {
      setLoading(false);
    }
  }

  Future<void> _syncPublicUserAvatar(String uid, String avatarUrl) async {
    try {
      final displayName =
          _currentUser?.displayName ?? _currentUserProfile?['displayName'];
      final username =
          _currentUser?.username ?? _currentUserProfile?['username'];

      await _firestore.collection('publicUsers').doc(uid).set({
        'uid': uid,
        'id': uid,
        if (displayName != null) 'displayName': displayName,
        if (username != null) 'username': username,
        'avatarUrl': avatarUrl,
        'avatarURL': avatarUrl,
        'avatarUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ publicUsers avatar mirror updated successfully');
    } catch (e) {
      // Do not fail avatar upload if public mirror is blocked by rules.
      debugPrint('⚠️ Failed to sync publicUsers avatar mirror: $e');
    }
  }

  // Update user platforms in Firestore
  Future<void> updateUserPlatforms(List<Map<String, dynamic>> platforms) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Update user platforms in Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'platforms': platforms,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update current user profile data
      if (_currentUserProfile != null) {
        _currentUserProfile!['platforms'] = platforms;
        _currentUserProfile!['updatedAt'] = DateTime.now().toIso8601String();
      }

      // appLog('✅ User platforms updated successfully');
    } catch (e) {
      // appLog('❌ Error updating user platforms: $e');
      throw Exception('Failed to update platforms: ${e.toString()}');
    }
  }

  // Update user profile data in Firestore
  Future<void> updateUserProfile(Map<String, dynamic> userData) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Prepare update data
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add specific fields if they exist in userData
      if (userData.containsKey('displayName')) {
        updateData['displayName'] = userData['displayName'];
      }
      if (userData.containsKey('bio')) {
        updateData['bio'] = userData['bio'];
      }
      if (userData.containsKey('hashtags')) {
        updateData['hashtags'] = userData['hashtags'];
      }
      if (userData.containsKey('onlineStatus')) {
        updateData['onlineStatus'] = userData['onlineStatus'];
      }
      if (userData.containsKey('platforms')) {
        updateData['platforms'] = userData['platforms'];
      }

      // Update user profile in Firestore
      await _firestore.collection('users').doc(user.uid).update(updateData);

      // Update current user profile data
      if (_currentUserProfile != null) {
        _currentUserProfile!.addAll(updateData);
        _currentUserProfile!['updatedAt'] = DateTime.now().toIso8601String();
      }

      // appLog('✅ User profile updated successfully');
    } catch (e) {
      // appLog('❌ Error updating user profile: $e');
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  // Update user status in Firestore
  Future<void> updateUserStatus(UserStatus status) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('presence')
          .doc('status')
          .set({
        'status': status.value,
        'lastSeen': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // appLog('✅ User status updated to ${status.value}');
    } catch (e) {
      // appLog('❌ Error updating user status: $e');
      throw Exception('Failed to update status: ${e.toString()}');
    }
  }

  // Get user status stream
  Stream<UserPresence> getUserStatusStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('presence')
        .doc('status')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return const UserPresence(
          status: UserStatus.offline,
          lastSeen: null,
        );
      }

      return UserPresence.fromMap(snapshot.data()!);
    });
  }

  // Set user as online
  Future<void> setUserOnline() async {
    await updateUserStatus(UserStatus.online);
  }

  // Set user as offline
  Future<void> setUserOffline() async {
    await updateUserStatus(UserStatus.offline);
  }

  // Get user by username (for easier tracking in Firebase console)
  Future<User?> getUserByUsername(String username) async {
    try {
      // First get the UID from the username mapping
      final usernameDoc =
          await _firestore.collection('usernames').doc(username).get();
      if (!usernameDoc.exists) {
        // appLog('❌ Username not found: $username');
        return null;
      }

      final uid = usernameDoc.data()?['uid'] as String?;
      if (uid == null) {
        // appLog('❌ No UID found for username: $username');
        return null;
      }

      // Then get the full user document
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        // appLog('❌ User document not found for UID: $uid');
        return null;
      }

      final userData = userDoc.data()!;
      return User.fromMap(userData);
    } catch (e) {
      // appLog('❌ Error getting user by username: $e');
      return null;
    }
  }

  // Get all users with their usernames (for easier tracking)
  Future<List<Map<String, dynamic>>> getAllUsersWithUsernames() async {
    try {
      final snapshot = await _firestore.collection('usernames').get();
      return snapshot.docs
          .map((doc) => {
                'username': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      // appLog('❌ Error getting all users: $e');
      return [];
    }
  }

  // Helper method to parse hashtags from different data types
  List<String>? _parseHashtags(dynamic hashtagsData) {
    if (hashtagsData == null) return null;

    if (hashtagsData is List) {
      return hashtagsData.cast<String>();
    } else if (hashtagsData is String) {
      return hashtagsData.split(',').map((e) => e.trim()).toList();
    }

    return null;
  }

  // Set loading state
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  @override
  void dispose() {
    _authStateSub?.cancel();
    _userDataSub?.cancel();
    super.dispose();
  }
}

// Provider for AuthenticationService
final authServiceProvider =
    ChangeNotifierProvider<AuthenticationService>((ref) {
  return AuthenticationService();
});
