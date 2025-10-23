// fix_buzzz_user.dart
// Run this script to fix the buzZz user document

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp();

  final firestore = FirebaseFirestore.instance;

  try {
    print('🔍 Looking for buzZz user...');

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
    final buzzzId = buzzzDoc.id; // Get the document ID

    print('✅ Found buzZz user with document ID: $buzzzId');

    // Update the document to include the id field
    await buzzzDoc.reference.update({
      'id': buzzzId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    print('✅ buzZz user updated successfully');

    // Verify the fix
    final updatedDoc = await buzzzDoc.reference.get();
    final userData = updatedDoc.data() as Map<String, dynamic>;
    print('📋 Updated user data:');
    print('  ID: ${userData['id']}');
    print('  Username: ${userData['username']}');
    print('  Display Name: ${userData['displayName']}');
  } catch (e) {
    print('❌ Error fixing buzZz user: $e');
  }
}
