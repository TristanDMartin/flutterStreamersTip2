import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../models/user_status.dart';

class AuthenticationService extends ChangeNotifier {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
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
    _auth.authStateChanges().listen((firebase_auth.User? user) {
    // print("🔄 Auth state changed: ${user != null ? 'Logged in' : 'Logged out'}");
      if (user != null) {
    // print("👤 User: ${user.email} (${user.uid})");
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
    // print("🔐 handleUserSignIn called for user: ${firebaseUser.uid}");
    // print("👤 User display name: ${firebaseUser.displayName ?? 'nil'}");
    // print("📧 User email: ${firebaseUser.email ?? 'nil'}");
    
    try {
      final userRef = _firestore.collection("users").doc(firebaseUser.uid);
      final snapshot = await userRef.get();
      
    // print("📄 Firestore document fetch completed");
    // print("🔐 Document exists: ${snapshot.exists}");
      
      if (snapshot.exists && snapshot.data() != null) {
    // print("🔐 User document found in Firestore");
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
          avatarURL: data['avatarURL'] as String?,
          onlineStatus: data['onlineStatus'] as String? ?? 'online',
          hashtags: hashtags,
          postCount: data['postCount'] as int? ?? 0,
          followerCount: data['followerCount'] as int? ?? 0,
          followingCount: data['followingCount'] as int? ?? 0,
        );
        
        _currentUser = user;
        _isLoggedIn = true;
        notifyListeners();
        
    // print("✅ User signed in successfully - isLoggedIn: $_isLoggedIn");
        
        // Set up real-time listener for user data changes
        _setupUserDataListener(firebaseUser.uid);
        
        // Ensure user document exists (handles any edge cases)
        await _ensureUserDocumentExists(firebaseUser);
        
        // Initialize user status as online
        await setUserOnline();
        
      } else {
    // print("🔐 Creating new user document in Firestore");
        await _createNewUserDocument(firebaseUser);
        
        // Initialize user status as online
        await setUserOnline();
      }
    } catch (e) {
    // print("❌ Error handling user sign in: $e");
      // Fallback to basic user data
      final user = User(
        id: firebaseUser.uid,
        username: firebaseUser.displayName?.toLowerCase().replaceAll(' ', '') ?? 'user',
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
    // print("🔐 Creating new user document in Firestore for: ${firebaseUser.uid}");
    
    // Generate a unique username from display name
    final baseUsername = firebaseUser.displayName?.toLowerCase().replaceAll(' ', '') ?? 'user';
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
    
    // print("✅ New user signed in successfully - isLoggedIn: $_isLoggedIn");
    
    // Set up real-time listener for the new user
    _setupUserDataListener(firebaseUser.uid);
  }

  // Generate unique username
  Future<String> _generateUniqueUsername(String baseUsername) async {
    String username = baseUsername;
    int counter = 1;
    
    while (true) {
      final query = _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1);
      
      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
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
      
    // print("✅ User document saved to Firestore with username mapping: ${user.username} -> ${user.id}");
    } catch (e) {
    // print("❌ Error saving user to Firestore: $e");
    }
  }

  // Set up real-time listener for user data changes
  void _setupUserDataListener(String userId) {
    _firestore.collection('users').doc(userId).snapshots().listen((snapshot) {
      if (snapshot.exists && _currentUser != null) {
        final data = snapshot.data()!;
        
        // Update current user with latest data
        final updatedUser = User(
          id: _currentUser!.id,
          username: data['username'] as String? ?? _currentUser!.username,
          displayName: data['displayName'] as String? ?? _currentUser!.displayName,
          bio: data['bio'] as String? ?? _currentUser!.bio,
          avatarURL: data['avatarURL'] as String? ?? _currentUser!.avatarURL,
          onlineStatus: data['onlineStatus'] as String? ?? _currentUser!.onlineStatus,
          hashtags: _parseHashtags(data['hashtags']) ?? _currentUser!.hashtags,
          postCount: data['postCount'] as int? ?? _currentUser!.postCount,
          followerCount: data['followerCount'] as int? ?? _currentUser!.followerCount,
          followingCount: data['followingCount'] as int? ?? _currentUser!.followingCount,
        );
        
        _currentUser = updatedUser;
        notifyListeners();
    // print("🔄 User data updated from Firestore listener");
      }
    });
  }

  // Ensure user document exists
  Future<void> _ensureUserDocumentExists(firebase_auth.User firebaseUser) async {
    try {
      final userRef = _firestore.collection("users").doc(firebaseUser.uid);
      final snapshot = await userRef.get();
      
      if (!snapshot.exists) {
    // print("🔐 User document doesn't exist, creating...");
        await _createNewUserDocument(firebaseUser);
      }
    } catch (e) {
    // print("❌ Error ensuring user document exists: $e");
    }
  }

  // Sign in with Google
  Future<void> signInWithGoogle() async {
    try {
    // print("🔐 Starting Google Sign-In process");
      setLoading(true);
      
      // First, sign out any existing Google session to avoid conflicts
      await _googleSignIn.signOut();
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
    // print("❌ Google Sign-In cancelled by user");
        setLoading(false);
        return;
      }

    // print("✅ Google Sign-In successful for: ${googleUser.email}");
      
      try {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        
        if (googleAuth.accessToken == null || googleAuth.idToken == null) {
    // print("❌ Missing Google authentication tokens");
          setLoading(false);
          throw Exception("Failed to get Google authentication tokens");
        }

        final credential = firebase_auth.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

    // print("🔐 Signing in to Firebase with Google credential");
        final firebase_auth.UserCredential userCredential = await _auth.signInWithCredential(credential);
        final firebase_auth.User? user = userCredential.user;
        
        if (user != null) {
    // print("✅ Firebase authentication successful for: ${user.email}");
          // The auth state listener will handle the rest
        }
        
        setLoading(false);
    // print("🎉 Google Sign-In process completed successfully");
      } catch (authError) {
    // print("❌ Firebase authentication error: $authError");
        // Sign out from Google if Firebase auth fails
        await _googleSignIn.signOut();
        setLoading(false);
        rethrow;
      }
    } catch (e) {
    // print("❌ Google Sign-In error: $e");
      setLoading(false);
      
      // Provide more specific error messages
      if (e.toString().contains('network_error')) {
        throw Exception('Network error. Please check your internet connection.');
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
    // print("📧 Starting email authentication for: $email");
      setLoading(true);
      
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      if (userCredential.user != null) {
    // print("✅ Email authentication successful for: ${userCredential.user!.email}");
        // Auth state listener will handle the rest
      }
      
      setLoading(false);
    } catch (e) {
    // print("❌ Email sign in error: $e");
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

  // Sign in with username
  Future<void> signInWithUsername(String username, String password) async {
    try {
    // print("🔐 Looking up user by username: $username");
      setLoading(true);
      
      // First, find the user by username in Firestore
    // print("🔐 Firestore instance created");
      
      final query = _firestore
          .collection('users')
          .where('username', isEqualTo: username);
    // print("🔐 Query created for username: $username");
      
      final snapshot = await query.get();
    // print("🔐 Query executed, found ${snapshot.docs.length} documents");
      
      // Log all documents for debugging
      for (int index = 0; index < snapshot.docs.length; index++) {
        // final doc = snapshot.docs[index];
    // print("📄 Document $index: ID = ${doc.id}, Data = ${doc.data()}");
      }
      
      if (snapshot.docs.isEmpty) {
    // print("❌ No user found with username: $username");
    // print("🔐 Available usernames in database:");
        // Let's also check what usernames exist in the database
        final allUsersQuery = _firestore.collection('users').limit(10);
        final allUsersSnapshot = await allUsersQuery.get();
        for (final doc in allUsersSnapshot.docs) {
          final data = doc.data();
          final username = data['username'] as String?;
          if (username != null) {
    // print("👤 Found username: $username");
          }
        }
        throw Exception('Username not found');
      }
      
      final userDoc = snapshot.docs.first;
      final userData = userDoc.data();
    // print("🔐 User data: $userData");
      
      // Try multiple ways to find the email
      String? email;
      
      // 1. Check for email field
      if (userData['email'] != null) {
        email = userData['email'] as String;
    // print("✅ Found email in 'email' field: $email");
      }
      // 2. Check if id field contains email
      else if (userData['id'] != null) {
        final idField = userData['id'] as String;
        if (idField.contains("@")) {
          email = idField;
    // print("✅ Found email in 'id' field: $email");
    // print("ℹ️ Using email directly without updating document");
        }
      }
      // 3. Check for firebaseUid to get email from Firebase Auth
      else if (userData['firebaseUid'] != null) {
        // final firebaseUid = userData['firebaseUid'] as String;
    // print("🔐 Found firebaseUid: $firebaseUid (would need admin SDK for email lookup)");
        // This would require admin SDK, but we can try to sign in with the UID
        // For now, we'll throw an error and suggest using email
        throw Exception('No email found for username. Please use email to sign in.');
      }
      
      if (email == null) {
    // print("❌ No email found for username: $username");
    // print("🔐 Available fields: ${userData.keys.toList()}");
        throw Exception('No email associated with this username');
      }
      
    // print("✅ Using email for authentication: $email");
      
      // Now sign in with the email and password
      await signInWithEmail(email, password);
      
    } catch (e) {
    // print("❌ Username lookup error: $e");
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
      
      final firebase_auth.UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final firebase_auth.User? user = userCredential.user;
      if (user != null) {
        await user.updateDisplayName(displayName);
        await _createOrUpdateUserDocument(user, displayName: displayName, username: username);
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

  // Bypass login as technqs (Development/Testing)
  Future<void> bypassLoginAsTechnqs() async {
    try {
      setLoading(true);
      
      // Fetch existing user data from Firestore
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: 'technqs')
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        throw Exception('User technqs not found in database');
      }
      
      final userDoc = querySnapshot.docs.first;
      final userData = userDoc.data();
      
      // Store the full user profile data
      _currentUserProfile = userData;
      
      // Create a User object from Firestore data
      final user = User(
        id: userData['uid'] ?? 'unknown',
        username: userData['username'] ?? 'user',
        displayName: userData['displayName'] ?? 'User',
        bio: userData['bio'] ?? '',
        avatarURL: userData['avatarURL'],
        onlineStatus: userData['onlineStatus'] ?? 'online',
        hashtags: (userData['hashtags'] as List<dynamic>?)?.cast<String>() ?? [],
        postCount: userData['postCount'] ?? 0,
        followerCount: userData['followerCount'] ?? 0,
        followingCount: userData['followingCount'] ?? 0,
      );
      
      _currentUser = user;
      _isLoggedIn = true;
      _isLoading = false;
      
      // Notify listeners of the change
      notifyListeners();
      
      // Print detailed user information
    // print("✅ Successfully bypassed login as technqs");
    // print("📊 User data loaded: ${userData['displayName']} (${userData['username']})");
    // print("📧 Email: ${userData['email']}");
    // print("🆔 UID: ${userData['uid']}");
    // print("🖼️ Avatar: ${userData['photoURL'] ?? 'No avatar'}");
      
      // Print additional profile data if available
      if (userData['bio'] != null) {
    // print("📝 Bio: ${userData['bio']}");
      }
      if (userData['platform'] != null) {
    // print("🎮 Platform: ${userData['platform']}");
      }
      if (userData['createdAt'] != null) {
    // print("📅 Created: ${userData['createdAt']}");
      }
      
    } catch (e) {
      setLoading(false);
    // print("❌ Bypass login failed: $e");
      rethrow;
    }
  }





  // Create or update user document in Firestore
  Future<void> _createOrUpdateUserDocument(firebase_auth.User user, {String? displayName, String? username}) async {
    try {
      final userData = {
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
    // print("❌ Error creating/updating user document: $e");
    }
  }

  // Generate username from email
  String _generateUsernameFromEmail(String email) {
    final emailPrefix = email.split('@')[0];
    return emailPrefix.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
  }

  // Change password
  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      setLoading(true);
      
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }
      
      // Re-authenticate user with current password
      final credential = firebase_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      
      await user.reauthenticateWithCredential(credential);
      
      // Update password
      await user.updatePassword(newPassword);
      
    // print("✅ Password updated successfully");
      setLoading(false);
    } catch (e) {
    // print("❌ Password change error: $e");
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
      
    // print("✅ Password reset email sent to: $email");
      setLoading(false);
    } catch (e) {
    // print("❌ Password reset error: $e");
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
      
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Create a reference to the file in Firebase Storage
      final ref = _storage.ref().child('avatars/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      // Upload the file
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;
      
      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Update user profile in Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'avatarURL': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update current user profile data
      if (_currentUserProfile != null) {
        _currentUserProfile!['avatarURL'] = downloadUrl;
        _currentUserProfile!['updatedAt'] = DateTime.now().toIso8601String();
      }
      
    // print('✅ Avatar uploaded successfully: $downloadUrl');
      return downloadUrl;
      
    } catch (e) {
    // print('❌ Error uploading avatar: $e');
      throw Exception('Failed to upload avatar: ${e.toString()}');
    } finally {
      setLoading(false);
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
      
    // print('✅ User platforms updated successfully');
      
    } catch (e) {
    // print('❌ Error updating user platforms: $e');
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
      
    // print('✅ User profile updated successfully');
      
    } catch (e) {
    // print('❌ Error updating user profile: $e');
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

    // print('✅ User status updated to ${status.value}');
    } catch (e) {
    // print('❌ Error updating user status: $e');
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
      final usernameDoc = await _firestore.collection('usernames').doc(username).get();
      if (!usernameDoc.exists) {
    // print('❌ Username not found: $username');
        return null;
      }
      
      final uid = usernameDoc.data()?['uid'] as String?;
      if (uid == null) {
    // print('❌ No UID found for username: $username');
        return null;
      }
      
      // Then get the full user document
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) {
    // print('❌ User document not found for UID: $uid');
        return null;
      }
      
      final userData = userDoc.data()!;
      return User.fromMap(userData);
    } catch (e) {
    // print('❌ Error getting user by username: $e');
      return null;
    }
  }

  // Get all users with their usernames (for easier tracking)
  Future<List<Map<String, dynamic>>> getAllUsersWithUsernames() async {
    try {
      final snapshot = await _firestore.collection('usernames').get();
      return snapshot.docs.map((doc) => {
        'username': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
    // print('❌ Error getting all users: $e');
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
}

// Provider for AuthenticationService
final authServiceProvider = ChangeNotifierProvider<AuthenticationService>((ref) {
  return AuthenticationService();
});
