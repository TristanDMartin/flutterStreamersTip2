import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'instant_data_refresh_service.dart';

/// TikTok-style instant account switching service
class TikTokAccountSwitcher extends ChangeNotifier {
  static final TikTokAccountSwitcher _instance =
      TikTokAccountSwitcher._internal();
  factory TikTokAccountSwitcher() => _instance;
  TikTokAccountSwitcher._internal();

  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final InstantDataRefreshService _dataRefreshService =
      InstantDataRefreshService();

  // Account management
  List<SavedAccount> _savedAccounts = [];
  SavedAccount? _currentAccount;
  bool _isSwitching = false;

  // Animation state
  bool _isAnimating = false;
  double _switchProgress = 0.0;

  // ✅ SECURITY FIX: Use FlutterSecureStorage instead of SharedPreferences
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Constants
  static const String _accountsKey = 'tiktok_saved_accounts';
  static const Duration _switchAnimationDuration = Duration(milliseconds: 300);
  static const Duration _switchDelay = Duration(milliseconds: 150);

  // Getters
  List<SavedAccount> get savedAccounts => _savedAccounts;
  SavedAccount? get currentAccount => _currentAccount;
  bool get isSwitching => _isSwitching;
  bool get isAnimating => _isAnimating;
  double get switchProgress => _switchProgress;
  bool get hasMultipleAccounts => _savedAccounts.length > 1;

  /// Initialize the account switcher
  Future<void> initialize() async {
    await _loadSavedAccounts();
    _setCurrentAccount();

    // Listen to auth state changes to update current account
    _auth.authStateChanges().listen((firebase_auth.User? user) {
      debugPrint(
          '🔄 Auth state changed in TikTokAccountSwitcher: ${user != null ? 'Logged in' : 'Logged out'}');
      _setCurrentAccount();
    });
  }

  /// Load saved accounts from secure storage
  Future<void> _loadSavedAccounts() async {
    try {
      final accountsJson = await _storage.read(key: _accountsKey);

      if (accountsJson != null && accountsJson.isNotEmpty) {
        final List<dynamic> accountsList = json.decode(accountsJson);
        _savedAccounts = accountsList
            .map((account) => SavedAccount.fromJson(account))
            .toList();

        // Sort by last used (most recent first)
        _savedAccounts.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
        debugPrint('✅ TikTokAccountSwitcher: Loaded ${_savedAccounts.length} accounts from secure storage');
      } else {
        debugPrint('ℹ️ TikTokAccountSwitcher: No saved accounts found');
        _savedAccounts = [];
      }
    } catch (e) {
      debugPrint('❌ TikTokAccountSwitcher: Error loading saved accounts: $e');
      _savedAccounts = [];
    }
  }

  /// Save accounts to secure storage
  Future<void> _saveAccounts() async {
    try {
      final accountsJson = json.encode(
        _savedAccounts.map((account) => account.toJson()).toList(),
      );
      await _storage.write(key: _accountsKey, value: accountsJson);
      debugPrint('✅ TikTokAccountSwitcher: Saved ${_savedAccounts.length} accounts to secure storage');
    } catch (e) {
      debugPrint('❌ TikTokAccountSwitcher: Error saving accounts: $e');
      // Don't throw - account switching should be resilient
    }
  }

  /// Set current account based on Firebase auth state
  void _setCurrentAccount() {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      // Try to find existing account in saved accounts
      final existingAccount = _savedAccounts
          .where(
            (account) => account.uid == firebaseUser.uid,
          )
          .firstOrNull;

      if (existingAccount != null) {
        _currentAccount = existingAccount;
      } else {
        // Create new account from current Firebase user
        _currentAccount = SavedAccount.fromFirebaseUser(firebaseUser);
      }

      debugPrint(
          '✅ Current account set: ${_currentAccount?.displayName} (${_currentAccount?.email})');
    } else {
      _currentAccount = null;
      debugPrint('❌ No current Firebase user');
    }
    notifyListeners();
  }

  /// Add current account to saved accounts
  Future<void> addCurrentAccount() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      debugPrint('❌ No Firebase user to add to saved accounts');
      return;
    }

    final account = SavedAccount.fromFirebaseUser(firebaseUser);
    debugPrint(
        '🔄 Adding account to saved accounts: ${account.displayName} (${account.email})');

    // Remove if already exists
    _savedAccounts.removeWhere((a) => a.uid == account.uid);

    // Add to beginning (most recent)
    _savedAccounts.insert(0, account);

    // Limit to 5 accounts max
    if (_savedAccounts.length > 5) {
      _savedAccounts = _savedAccounts.take(5).toList();
    }

    await _saveAccounts();
    _setCurrentAccount();

    debugPrint(
        '✅ Account added. Total saved accounts: ${_savedAccounts.length}');
  }

  /// TikTok-style instant account switching
  Future<bool> switchToAccount(SavedAccount targetAccount) async {
    // Check if we're already on this account
    final currentFirebaseUser = _auth.currentUser;
    if (currentFirebaseUser != null &&
        currentFirebaseUser.uid == targetAccount.uid) {
      debugPrint(
          '✅ Already signed in as ${targetAccount.displayName} - no switch needed');
      return true; // Already on this account, consider it successful
    }

    if (_isSwitching) {
      debugPrint('❌ Already switching accounts');
      return false;
    }

    debugPrint(
        '🔄 Starting TikTok-style account switch to: ${targetAccount.displayName}');
    debugPrint(
        '🔄 Current Firebase user: ${currentFirebaseUser?.email ?? 'None'}');
    debugPrint('🔄 Target account: ${targetAccount.email}');

    _isSwitching = true;
    _isAnimating = true;
    notifyListeners();

    try {
      // Start animation
      _animateSwitch();

      // Wait for animation to start
      await Future.delayed(_switchDelay);

      // Check if this is an existing account we can switch to
      final existingAccount =
          _savedAccounts.where((a) => a.uid == targetAccount.uid).firstOrNull;

      if (existingAccount != null) {
        debugPrint(
            '✅ Found existing saved account: ${existingAccount.displayName}');

        // Perform the account switch
        final success = await _performAccountSwitch(targetAccount);

        if (success) {
          // Update last used time
          existingAccount.lastUsed = DateTime.now();
          await _saveAccounts();
          _setCurrentAccount();

          // Trigger instant data refresh for all user data
          await _triggerInstantDataRefresh();

          debugPrint(
              '✅ Account switch completed successfully with instant data refresh');
        }

        // Complete animation
        await _completeAnimation();
        return success;
      } else {
        debugPrint('❌ Target account not found in saved accounts');
        await _completeAnimation();
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error switching account: $e');
      await _completeAnimation();
      return false;
    } finally {
      _isSwitching = false;
      notifyListeners();
    }
  }

  /// Trigger instant refresh of all user data after account switch
  Future<void> _triggerInstantDataRefresh() async {
    debugPrint('🔄 Triggering comprehensive data refresh for new account...');

    try {
      // Use the comprehensive data refresh service
      await _dataRefreshService.refreshAllUserData(null);

      // Notify all listeners that data has changed
      notifyListeners();

      debugPrint('✅ Comprehensive data refresh completed');
    } catch (e) {
      debugPrint('❌ Error during data refresh: $e');
    }
  }

  /// Trigger data refresh with WidgetRef for provider invalidation
  Future<void> triggerDataRefreshWithRef(WidgetRef? ref) async {
    debugPrint('🔄 Triggering data refresh with WidgetRef...');

    try {
      // Use the comprehensive data refresh service with WidgetRef
      await _dataRefreshService.refreshAllUserData(ref);

      // Notify all listeners that data has changed
      notifyListeners();

      debugPrint('✅ Data refresh with WidgetRef completed');
    } catch (e) {
      debugPrint('❌ Error during data refresh with WidgetRef: $e');
    }
  }

  /// Animate the switching process
  void _animateSwitch() {
    _switchProgress = 0.0;
    Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _switchProgress += 16 / _switchAnimationDuration.inMilliseconds;

      if (_switchProgress >= 1.0) {
        timer.cancel();
        _switchProgress = 1.0;
      }

      notifyListeners();
    });
  }

  /// Complete the animation
  Future<void> _completeAnimation() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _isAnimating = false;
    _switchProgress = 0.0;
    notifyListeners();
  }

  /// Perform the actual account switch
  Future<bool> _performAccountSwitch(SavedAccount targetAccount) async {
    try {
      // For Google Sign-In accounts, use Google Sign-In
      if (targetAccount.provider == 'google.com') {
        // Sign out current user completely
        await _auth.signOut();
        await _googleSignIn.signOut();

        // Wait a moment for sign out to complete
        await Future.delayed(const Duration(milliseconds: 500));

        // Sign in with target account
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          debugPrint('User cancelled Google Sign-In');
          return false;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final credential = firebase_auth.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential = await _auth.signInWithCredential(credential);

        if (userCredential.user != null) {
          debugPrint('✅ Successfully switched to account: ${googleUser.email}');
          return true;
        } else {
          debugPrint('❌ Failed to sign in with credential');
          return false;
        }
      } else {
        // For other providers, show sign-in prompt
        debugPrint(
            'Account switching for ${targetAccount.provider} requires manual sign-in');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error in account switch: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      return false;
    }
  }

  /// Remove an account from saved accounts
  Future<void> removeAccount(SavedAccount account) async {
    _savedAccounts.removeWhere((a) => a.uid == account.uid);
    await _saveAccounts();

    if (_currentAccount?.uid == account.uid) {
      _currentAccount = null;
    }

    notifyListeners();
  }

  /// Clear all saved accounts
  Future<void> clearAllAccounts() async {
    _savedAccounts.clear();
    _currentAccount = null;
    await _saveAccounts();
    notifyListeners();
  }

  /// Perform Google Sign-In for adding new accounts or switching
  Future<bool> performGoogleSignIn() async {
    try {
      debugPrint('🔄 Starting Google Sign-In flow for TikTok account switcher');

      // Store current user before signing in
      final currentUserId = _auth.currentUser?.uid;
      debugPrint('🔍 Current user before sign-in: $currentUserId');

      // DON'T sign out current user - we want to add accounts without signing out
      // Only sign out from Google Sign-In so user can select a different account
      debugPrint('🔄 Signing out from Google Sign-In (not Firebase)...');
      await _googleSignIn.signOut();

      // Wait a moment for Google Sign-In to reset
      debugPrint('🔄 Waiting for Google Sign-In reset...');
      await Future.delayed(const Duration(milliseconds: 300));

      // Trigger Google Sign-In
      debugPrint('🔄 Triggering Google Sign-In...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('❌ Google Sign-In was cancelled by user');
        return false;
      }

      debugPrint('✅ Google Sign-In successful: ${googleUser.email}');
      debugPrint('🔄 Getting authentication details...');

      // Get authentication details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        debugPrint('❌ Google authentication tokens are null');
        return false;
      }

      debugPrint('🔄 Creating Firebase credential...');
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Store the original user before any sign-in operations
      final originalUser = _auth.currentUser;

      // Create temporary Firebase user to get account info
      debugPrint('🔄 Getting account info (temporary sign-in)...');
      final tempUserCredential = await _auth.signInWithCredential(credential);

      if (tempUserCredential.user != null) {
        debugPrint(
            '✅ Temporary authentication successful for: ${tempUserCredential.user!.email}');

        // Check if account already exists
        final existingAccount = _savedAccounts.firstWhere(
          (account) => account.uid == tempUserCredential.user!.uid,
          orElse: () => SavedAccount(
            uid: '',
            email: '',
            displayName: '',
            provider: '',
            lastUsed: DateTime.now(),
          ),
        );

        if (existingAccount.uid.isNotEmpty) {
          debugPrint('⚠️ Account already exists in saved accounts');
          // Don't switch accounts if just adding - keep current user signed in

          // If this is the current user, no need to do anything
          if (tempUserCredential.user!.uid == currentUserId) {
            debugPrint('✅ Selected account is already current user');
            return true;
          }

          // Otherwise, switch to this account for instant switching
          debugPrint('🔄 Switching to existing account...');
          return true;
        } else {
          // Create a SavedAccount from the temp user to save it
          final newAccount = SavedAccount(
            uid: tempUserCredential.user!.uid,
            email: tempUserCredential.user!.email ?? '',
            displayName: tempUserCredential.user!.displayName ?? 'User',
            photoUrl: tempUserCredential.user!.photoURL,
            provider: 'google.com',
            lastUsed: DateTime.now(),
            metadata: {
              'isEmailVerified': tempUserCredential.user!.emailVerified,
              'creationTime': tempUserCredential.user!.metadata.creationTime
                  ?.toIso8601String(),
              'lastSignInTime': tempUserCredential.user!.metadata.lastSignInTime
                  ?.toIso8601String(),
            },
          );

          // Remove if already exists
          _savedAccounts.removeWhere((a) => a.uid == newAccount.uid);

          // Add to beginning (most recent)
          _savedAccounts.insert(0, newAccount);

          // Limit to 5 accounts max
          if (_savedAccounts.length > 5) {
            _savedAccounts = _savedAccounts.take(5).toList();
          }

          await _saveAccounts();
          debugPrint('✅ Account added to saved accounts: ${newAccount.email}');

          // If this was just adding an account, restore the original user
          if (currentUserId != null && originalUser != null) {
            debugPrint('🔄 Restoring original user: ${originalUser.email}');

            // Sign out the new user
            await _auth.signOut();
            await _googleSignIn.signOut();

            // Wait a moment for sign out to complete
            await Future.delayed(const Duration(milliseconds: 300));

            // Re-authenticate the original user
            await _googleSignIn.signInSilently();
            final originalGoogleUser = await _googleSignIn.signInSilently();

            if (originalGoogleUser?.email == originalUser.email) {
              final originalAuth = await originalGoogleUser!.authentication;
              final originalCredential =
                  firebase_auth.GoogleAuthProvider.credential(
                accessToken: originalAuth.accessToken,
                idToken: originalAuth.idToken,
              );
              await _auth.signInWithCredential(originalCredential);
              debugPrint('✅ Restored original user: ${originalUser.email}');
            } else {
              debugPrint('⚠️ Could not restore original user silently');
            }

            // Update current account after restoration
            _setCurrentAccount();
          }

          // Notify listeners that accounts have changed
          notifyListeners();
          debugPrint('✅ Notified listeners about account changes');

          return true;
        }
      } else {
        debugPrint('❌ Firebase authentication failed - no user returned');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Google Sign-In error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
      return false;
    }
  }
}

/// Represents a saved account for instant switching
class SavedAccount {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String provider;
  DateTime lastUsed;
  final Map<String, dynamic>? metadata;

  SavedAccount({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.provider,
    required this.lastUsed,
    this.metadata,
  });

  /// Create from Firebase User
  factory SavedAccount.fromFirebaseUser(firebase_auth.User user) {
    return SavedAccount(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? 'User',
      photoUrl: user.photoURL,
      provider: user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : 'password',
      lastUsed: DateTime.now(),
      metadata: {
        'isEmailVerified': user.emailVerified,
        'creationTime': user.metadata.creationTime?.toIso8601String(),
        'lastSignInTime': user.metadata.lastSignInTime?.toIso8601String(),
      },
    );
  }

  /// Create from JSON
  factory SavedAccount.fromJson(Map<String, dynamic> json) {
    return SavedAccount(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'] ?? 'User',
      photoUrl: json['photoUrl'],
      provider: json['provider'] ?? 'password',
      lastUsed: json['lastUsed'] != null
          ? DateTime.parse(json['lastUsed'])
          : DateTime.now(),
      metadata: json['metadata'],
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'provider': provider,
      'lastUsed': lastUsed.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Check if this is the current account
  bool get isCurrent => TikTokAccountSwitcher().currentAccount?.uid == uid;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedAccount &&
          runtimeType == other.runtimeType &&
          uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}
