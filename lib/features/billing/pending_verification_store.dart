import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Stores pending IAP verifications that need retry (persists across app restarts).
class PendingVerificationStore {
  PendingVerificationStore._();
  static final PendingVerificationStore instance = PendingVerificationStore._();

  static const String _pendingKey = 'pending_iap_verifications_v1';
  static const String _lastSyncKey = 'last_verification_sync_attempt';

  Future<void> addPendingVerification({
    required String uid,
    required String platform,
    required String productId,
    required String purchaseToken,
    required String transactionId,
    required String dedupeKey,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> pending = prefs.getStringList(_pendingKey) ?? [];
    
    final Map<String, dynamic> entry = {
      'uid': uid,
      'platform': platform,
      'productId': productId,
      'purchaseToken': purchaseToken,
      'transactionId': transactionId,
      'dedupeKey': dedupeKey,
      'addedAt': DateTime.now().toUtc().toIso8601String(),
      'attempts': 0,
    };
    
    // Avoid duplicates
    final String entryJson = jsonEncode(entry);
    if (!pending.any((String p) {
      try {
        final Map<String, dynamic> existing = jsonDecode(p);
        return existing['dedupeKey'] == dedupeKey;
      } catch (_) {
        return false;
      }
    })) {
      pending.add(entryJson);
      await prefs.setStringList(_pendingKey, pending);
    }
  }

  Future<void> removePendingVerification(String dedupeKey) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> pending = prefs.getStringList(_pendingKey) ?? [];
    
    pending.removeWhere((String p) {
      try {
        final Map<String, dynamic> entry = jsonDecode(p);
        return entry['dedupeKey'] == dedupeKey;
      } catch (_) {
        return false;
      }
    });
    
    await prefs.setStringList(_pendingKey, pending);
  }

  Future<List<Map<String, dynamic>>> getPendingVerifications() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> pending = prefs.getStringList(_pendingKey) ?? [];
    
    final List<Map<String, dynamic>> results = [];
    for (final String p in pending) {
      try {
        results.add(jsonDecode(p));
      } catch (_) {
        // Corrupted entry, skip
      }
    }
    
    return results;
  }

  Future<void> incrementAttempts(String dedupeKey) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> pending = prefs.getStringList(_pendingKey) ?? [];
    
    final List<String> updated = pending.map((String p) {
      try {
        final Map<String, dynamic> entry = jsonDecode(p);
        if (entry['dedupeKey'] == dedupeKey) {
          entry['attempts'] = (entry['attempts'] ?? 0) + 1;
          entry['lastAttemptAt'] = DateTime.now().toUtc().toIso8601String();
          return jsonEncode(entry);
        }
        return p;
      } catch (_) {
        return p;
      }
    }).toList();
    
    await prefs.setStringList(_pendingKey, updated);
  }

  Future<void> setLastSyncAttempt() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastSyncKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<DateTime?> getLastSyncAttempt() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? lastSync = prefs.getString(_lastSyncKey);
    if (lastSync == null) return null;
    try {
      return DateTime.parse(lastSync);
    } catch (_) {
      return null;
    }
  }

  Future<int> getPendingCount() async {
    final List<Map<String, dynamic>> pending = await getPendingVerifications();
    return pending.length;
  }

  Future<void> clearOldEntries({Duration maxAge = const Duration(days: 7)}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> pending = prefs.getStringList(_pendingKey) ?? [];
    final DateTime cutoff = DateTime.now().toUtc().subtract(maxAge);
    
    final List<String> filtered = pending.where((String p) {
      try {
        final Map<String, dynamic> entry = jsonDecode(p);
        final String? addedAt = entry['addedAt'];
        if (addedAt == null) return false;
        final DateTime added = DateTime.parse(addedAt);
        return added.isAfter(cutoff);
      } catch (_) {
        return false;
      }
    }).toList();
    
    await prefs.setStringList(_pendingKey, filtered);
  }
}
