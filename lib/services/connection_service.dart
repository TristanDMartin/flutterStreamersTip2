import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import '../models/user.dart' as app_user;

class ConnectionService {
  static final ConnectionService _instance = ConnectionService._internal();
  static ConnectionService get shared => _instance;
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final fa.FirebaseAuth _auth = fa.FirebaseAuth.instance;
  
  ConnectionService._internal();

  // Get user's connections
  Future<List<app_user.User>> getConnections(String userId) async {
    try {
      final connectionsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('connections')
          .get();

      final connectionIds = connectionsSnapshot.docs.map((doc) => doc.id).toList();
      
      if (connectionIds.isEmpty) return [];

      final usersSnapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: connectionIds)
          .get();

      return usersSnapshot.docs.map((doc) {
        final data = doc.data();
        return app_user.User.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error getting connections: $e');
      return [];
    }
  }

  // Check if two users are connected
  Future<bool> areConnected(String userId1, String userId2) async {
    try {
      final connectionDoc = await _firestore
          .collection('users')
          .doc(userId1)
          .collection('connections')
          .doc(userId2)
          .get();

      return connectionDoc.exists;
    } catch (e) {
      print('Error checking connection: $e');
      return false;
    }
  }

  // Send connection request
  Future<bool> sendConnectionRequest(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final inviteId = '${currentUser.uid}_${targetUserId}_${DateTime.now().millisecondsSinceEpoch}';
      
      // Add to sender's outgoing invites
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('outgoingInvites')
          .doc(inviteId)
          .set({
        'toUid': targetUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      // Add to target's incoming invites
      await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('incomingInvites')
          .doc(inviteId)
          .set({
        'fromUid': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      return true;
    } catch (e) {
      print('Error sending connection request: $e');
      return false;
    }
  }

  // Accept connection request
  Future<bool> acceptConnectionRequest(String inviteId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      // Get the invite details
      final inviteDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('incomingInvites')
          .doc(inviteId)
          .get();

      if (!inviteDoc.exists) return false;

      final inviteData = inviteDoc.data()!;
      final fromUid = inviteData['fromUid'] as String;

      // Create mutual connections
      final batch = _firestore.batch();

      // Add connection for current user
      batch.set(
        _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('connections')
            .doc(fromUid),
        {
          'connectedAt': FieldValue.serverTimestamp(),
        },
      );

      // Add connection for the other user
      batch.set(
        _firestore
            .collection('users')
            .doc(fromUid)
            .collection('connections')
            .doc(currentUser.uid),
        {
          'connectedAt': FieldValue.serverTimestamp(),
        },
      );

      // Update invite status to accepted
      batch.update(
        _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('incomingInvites')
            .doc(inviteId),
        {'status': 'accepted'},
      );

      batch.update(
        _firestore
            .collection('users')
            .doc(fromUid)
            .collection('outgoingInvites')
            .doc(inviteId),
        {'status': 'accepted'},
      );

      await batch.commit();
      return true;
    } catch (e) {
      print('Error accepting connection request: $e');
      return false;
    }
  }

  // Reject connection request
  Future<bool> rejectConnectionRequest(String inviteId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      // Get the invite details
      final inviteDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('incomingInvites')
          .doc(inviteId)
          .get();

      if (!inviteDoc.exists) return false;

      final inviteData = inviteDoc.data()!;
      final fromUid = inviteData['fromUid'] as String;

      // Update invite status to rejected
      final batch = _firestore.batch();

      batch.update(
        _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('incomingInvites')
            .doc(inviteId),
        {'status': 'rejected'},
      );

      batch.update(
        _firestore
            .collection('users')
            .doc(fromUid)
            .collection('outgoingInvites')
            .doc(inviteId),
        {'status': 'rejected'},
      );

      await batch.commit();
      return true;
    } catch (e) {
      print('Error rejecting connection request: $e');
      return false;
    }
  }

  // Get pending incoming invites
  Future<List<Map<String, dynamic>>> getPendingInvites() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    try {
      final invitesSnapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('incomingInvites')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      return invitesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error getting pending invites: $e');
      return [];
    }
  }

  // Get outgoing invites
  Future<List<Map<String, dynamic>>> getOutgoingInvites() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    try {
      final invitesSnapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('outgoingInvites')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      return invitesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error getting outgoing invites: $e');
      return [];
    }
  }

  // Check if user has sent invite to target
  Future<bool> hasSentInvite(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final invitesSnapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('outgoingInvites')
          .where('toUid', isEqualTo: targetUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      return invitesSnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking invite status: $e');
      return false;
    }
  }

  // Search users (excluding blocked and current user)
  Future<List<app_user.User>> searchUsers(String query) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    try {
      // This is a simplified search - in production you'd want more sophisticated search
      final usersSnapshot = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThan: '$query\uf8ff')
          .limit(20)
          .get();

      return usersSnapshot.docs
          .where((doc) => doc.id != currentUser.uid) // Exclude current user
          .map((doc) {
            final data = doc.data();
            return app_user.User.fromMap(data);
          })
          .toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Remove connection
  Future<bool> removeConnection(String userId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final batch = _firestore.batch();

      // Remove from current user's connections
      batch.delete(
        _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('connections')
            .doc(userId),
      );

      // Remove from other user's connections
      batch.delete(
        _firestore
            .collection('users')
            .doc(userId)
            .collection('connections')
            .doc(currentUser.uid),
      );

      await batch.commit();
      return true;
    } catch (e) {
      print('Error removing connection: $e');
      return false;
    }
  }
}
