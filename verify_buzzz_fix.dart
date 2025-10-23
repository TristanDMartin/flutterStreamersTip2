// verify_buzzz_fix.dart
// Run this script to verify the buzZz user fix

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp();

  final firestore = FirebaseFirestore.instance;

  try {
    print('🔍 Verifying buzZz user fix...');

    // Find buzZz user by username
    final buzzzQuery = await firestore
        .collection('users')
        .where('username', isEqualTo: 'buzzz')
        .get();

    if (buzzzQuery.docs.isEmpty) {
      print('❌ buzZz user not found');
      return;
    }

    final buzzzDoc = buzzzQuery.docs.first;
    final userData = buzzzDoc.data() as Map<String, dynamic>;

    print('📋 buzZz user data:');
    print('  Document ID: ${buzzzDoc.id}');
    print('  ID field: ${userData['id']}');
    print('  Username: ${userData['username']}');
    print('  Display Name: ${userData['displayName']}');
    print('  Email: ${userData['email']}');
    print('  Avatar URL: ${userData['avatarURL']}');

    // Check if the fix worked
    final hasId =
        userData['id'] != null && userData['id'].toString().isNotEmpty;
    final idMatches = userData['id'] == buzzzDoc.id;

    print('\n🧪 Verification Results:');
    print('  Has ID field: ${hasId ? '✅' : '❌'}');
    print('  ID matches document ID: ${idMatches ? '✅' : '❌'}');

    if (hasId && idMatches) {
      print('\n🎉 SUCCESS: buzZz user fix is working correctly!');
      print(
          '   The Flutter app should now load the real profile instead of sample data.');
    } else {
      print('\n❌ ISSUE: buzZz user fix needs more work.');
      if (!hasId) {
        print('   - The ID field is still missing or empty');
      }
      if (!idMatches) {
        print('   - The ID field does not match the document ID');
      }
    }
  } catch (e) {
    print('❌ Error verifying buzZz user: $e');
  }
}
