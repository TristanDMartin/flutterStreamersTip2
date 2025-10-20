import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Quick script to add missing counter fields to user documents
/// This fixes the "Failed to follow user" error caused by missing followersCount fields
void main() async {
  print('🔧 User Counter Fields Fix Script');
  print('================================\n');

  try {
    // Initialize Firebase (if not already initialized)
    await Firebase.initializeApp();
    print('✅ Firebase initialized\n');

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('❌ No authenticated user. Please sign in first.');
      return;
    }

    print('User: ${currentUser.uid}\n');

    await fixUserCounterFields(currentUser.uid);

    print('\n✅ Fix complete!');
    print('\nNow try following someone again.');
  } catch (e) {
    print('❌ Error: $e');
  }
}

/// Fix counter fields for a specific user
Future<void> fixUserCounterFields(String userId) async {
  final firestore = FirebaseFirestore.instance;

  print('📋 Checking user document: $userId');

  final userDoc = await firestore.collection('users').doc(userId).get();

  if (!userDoc.exists) {
    print('❌ User document does not exist!');
    return;
  }

  final data = userDoc.data()!;

  // Check which fields are missing
  final Map<String, dynamic> updates = {};

  if (!data.containsKey('followersCount')) {
    print('  ⚠️ Missing: followersCount');
    updates['followersCount'] = 0;
  } else {
    print('  ✅ Has: followersCount = ${data['followersCount']}');
  }

  if (!data.containsKey('followingCount')) {
    print('  ⚠️ Missing: followingCount');
    updates['followingCount'] = 0;
  } else {
    print('  ✅ Has: followingCount = ${data['followingCount']}');
  }

  if (!data.containsKey('connectionsCount')) {
    print('  ⚠️ Missing: connectionsCount');
    updates['connectionsCount'] = 0;
  } else {
    print('  ✅ Has: connectionsCount = ${data['connectionsCount']}');
  }

  // Apply fixes if needed
  if (updates.isNotEmpty) {
    print('\n🔧 Adding missing fields...');
    await firestore.collection('users').doc(userId).update(updates);
    print('✅ Fields added: ${updates.keys.join(', ')}');
  } else {
    print('\n✅ No fixes needed - all fields present');
  }
}

/// Fix ALL users in the database (admin only)
Future<void> fixAllUsers() async {
  final firestore = FirebaseFirestore.instance;

  print('📋 Fetching all users...\n');

  final snapshot = await firestore.collection('users').get();

  print('Found ${snapshot.docs.length} users\n');

  int fixed = 0;
  int alreadyOk = 0;

  for (final doc in snapshot.docs) {
    final data = doc.data();

    final Map<String, dynamic> updates = {};

    if (!data.containsKey('followersCount')) {
      updates['followersCount'] = 0;
    }
    if (!data.containsKey('followingCount')) {
      updates['followingCount'] = 0;
    }
    if (!data.containsKey('connectionsCount')) {
      updates['connectionsCount'] = 0;
    }

    if (updates.isNotEmpty) {
      await doc.reference.update(updates);
      print('✅ Fixed: ${doc.id} (added ${updates.keys.length} fields)');
      fixed++;
    } else {
      alreadyOk++;
    }
  }

  print('\n📊 Summary:');
  print('  Fixed: $fixed users');
  print('  Already OK: $alreadyOk users');
  print('  Total: ${snapshot.docs.length} users');
}
