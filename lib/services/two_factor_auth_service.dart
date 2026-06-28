import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'totp_service.dart';

class TwoFactorAuthService {
  FirebaseFirestore? _firestoreCache;
  final TotpService _totpService = TotpService();

  FirebaseFirestore get _firestore {
    if (_firestoreCache == null) {
      if (Firebase.apps.isEmpty) {
        throw StateError('Firebase not initialized');
      }
      _firestoreCache = FirebaseFirestore.instance;
    }
    return _firestoreCache!;
  }

  /// Enable 2FA for a user with authenticator app
  Future<bool> enable2FA({
    required String userId,
    required String method, // 'authenticator' or 'sms'
    String? phoneNumber,
  }) async {
    try {
      final secret = _totpService.generateSecret();
      final backupCodes = _generateBackupCodes();

      await _firestore.collection('users').doc(userId).update({
        'twoFactorEnabled': true,
        'twoFactorMethod': method,
        'twoFactorSecret': secret,
        'backupCodes': backupCodes.map((code) => _hashCode(code)).toList(),
        'twoFactorEnabledAt': FieldValue.serverTimestamp(),
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
      });

      return true;
    } catch (e) {
      debugPrint('❌ Failed to enable 2FA: $e');
      return false;
    }
  }

  /// Disable 2FA for a user
  Future<bool> disable2FA(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'twoFactorEnabled': false,
        'twoFactorMethod': null,
        'twoFactorSecret': null,
        'twoFactorDisabledAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('❌ Failed to disable 2FA: $e');
      return false;
    }
  }

  /// Get 2FA status for a user
  Future<Map<String, dynamic>?> get2FAStatus(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;

      final data = doc.data();
      return {
        'enabled': data?['twoFactorEnabled'] ?? false,
        'method': data?['twoFactorMethod'],
        'secret': data?['twoFactorSecret'],
        'enabledAt': data?['twoFactorEnabledAt'],
      };
    } catch (e) {
      debugPrint('❌ Failed to get 2FA status: $e');
      return null;
    }
  }

  /// Verify 2FA code
  Future<bool> verify2FACode({
    required String userId,
    required String code,
  }) async {
    try {
      final status = await get2FAStatus(userId);
      if (status == null || !status['enabled']) {
        return false;
      }

      final method = status['method'];
      final secret = status['secret'];

      if (method == 'authenticator' && secret != null) {
        return _totpService.verifyCode(secret: secret, code: code);
      }

      return false;
    } catch (e) {
      debugPrint('❌ Failed to verify 2FA code: $e');
      return false;
    }
  }

  /// Verify backup code
  Future<bool> verifyBackupCode({
    required String userId,
    required String code,
  }) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return false;

      final data = doc.data();
      final backupCodes = data?['backupCodes'] as List<dynamic>?;

      if (backupCodes == null) return false;

      final hashedCode = _hashCode(code);
      if (backupCodes.contains(hashedCode)) {
        final updatedCodes = backupCodes.where((c) => c != hashedCode).toList();

        await _firestore.collection('users').doc(userId).update({
          'backupCodes': updatedCodes,
        });

        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Failed to verify backup code: $e');
      return false;
    }
  }

  /// Generate new backup codes
  Future<List<String>> generateNewBackupCodes(String userId) async {
    final backupCodes = _generateBackupCodes();

    await _firestore.collection('users').doc(userId).update({
      'backupCodes': backupCodes.map((code) => _hashCode(code)).toList(),
    });

    return backupCodes;
  }

  /// Check if user needs 2FA verification
  Future<bool> requires2FA(String userId) async {
    final status = await get2FAStatus(userId);
    return status?['enabled'] == true;
  }

  /// Get TOTP secret for QR code generation
  Future<String?> getTotpSecret(String userId) async {
    final status = await get2FAStatus(userId);
    return status?['secret'] as String?;
  }

  List<String> _generateBackupCodes() {
    final random = Random.secure();
    final codes = <String>[];

    for (int i = 0; i < 10; i++) {
      final code = List.generate(
        6,
        (_) => random.nextInt(36).toRadixString(36).toUpperCase(),
      ).join();
      codes.add(code);
    }

    return codes;
  }

  String _hashCode(String code) {
    return '${code.substring(0, 3)}***';
  }

  /// Get current TOTP code for testing
  String getCurrentTotpCode(String secret) {
    return _totpService.generateCode(secret);
  }
}
