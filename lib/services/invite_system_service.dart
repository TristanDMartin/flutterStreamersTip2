import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'logging_service.dart';
import 'error_handler_service.dart';

class InviteSystemService {
  static final InviteSystemService _instance = InviteSystemService._internal();
  factory InviteSystemService() => _instance;
  InviteSystemService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Send SMS invite
  Future<bool> sendSMSInvite(String phoneNumber, {String? customMessage}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check SMS permission
      final status = await Permission.sms.request();
      if (status != PermissionStatus.granted) {
        throw Exception('SMS permission denied');
      }

      final inviteCode = await _getOrCreateInviteCode(currentUser.uid);
      final message = customMessage ?? _getDefaultInviteMessage(inviteCode);
      final smsUri = Uri.parse('sms:$phoneNumber?body=${Uri.encodeComponent(message)}');

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        
        // Log the invite
        await _logInvite(currentUser.uid, phoneNumber, 'sms', inviteCode);
        
        LoggingService.instance.debug('SMS invite sent to $phoneNumber', tag: 'InviteSystemService');
        return true;
      } else {
        throw Exception('Cannot launch SMS app');
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error sending SMS invite', tag: 'InviteSystemService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Send email invite
  Future<bool> sendEmailInvite(String email, {String? customMessage}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final inviteCode = await _getOrCreateInviteCode(currentUser.uid);
      final message = customMessage ?? _getDefaultInviteMessage(inviteCode);
      final emailUri = Uri.parse('mailto:$email?subject=${Uri.encodeComponent('Join me on StreamersTip!')}&body=${Uri.encodeComponent(message)}');

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
        
        // Log the invite
        await _logInvite(currentUser.uid, email, 'email', inviteCode);
        
        LoggingService.instance.debug('Email invite sent to $email', tag: 'InviteSystemService');
        return true;
      } else {
        throw Exception('Cannot launch email app');
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error sending email invite', tag: 'InviteSystemService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Share invite via native share sheet
  Future<bool> shareInvite({String? customMessage}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final inviteCode = await _getOrCreateInviteCode(currentUser.uid);
      final message = customMessage ?? _getDefaultInviteMessage(inviteCode);
      final shareUrl = _getInviteUrl(inviteCode);

      await Share.share(
        '$message\n\n$shareUrl',
        subject: 'Join me on StreamersTip!',
      );

      // Log the invite
      await _logInvite(currentUser.uid, 'share', 'share', inviteCode);
      
      LoggingService.instance.debug('Invite shared via native share', tag: 'InviteSystemService');
      return true;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error sharing invite', tag: 'InviteSystemService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Get or create invite code for user
  Future<String> _getOrCreateInviteCode(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (userDoc.exists) {
        final data = userDoc.data()!;
        final existingCode = data['inviteCode'] as String?;
        
        if (existingCode != null && existingCode.isNotEmpty) {
          return existingCode;
        }
      }

      // Generate new invite code
      final inviteCode = _generateInviteCode();
      
      // Save to user document
      await _firestore.collection('users').doc(userId).update({
        'inviteCode': inviteCode,
        'inviteCodeCreatedAt': FieldValue.serverTimestamp(),
      });

      LoggingService.instance.debug('Generated new invite code: $inviteCode', tag: 'InviteSystemService');
      return inviteCode;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error getting/creating invite code', tag: 'InviteSystemService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Generate unique invite code
  String _generateInviteCode() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'ST$random';
  }

  /// Get default invite message
  String _getDefaultInviteMessage(String inviteCode) {
    return 'Hey! Join me on StreamersTip - the best platform for content creators! Use my invite code: $inviteCode';
  }

  /// Get invite URL with deep linking
  String _getInviteUrl(String inviteCode) {
    return 'https://streamerstip.app/invite/$inviteCode';
  }

  /// Log invite for analytics
  Future<void> _logInvite(String inviterId, String recipient, String method, String inviteCode) async {
    try {
      await _firestore.collection('invites').add({
        'inviterId': inviterId,
        'recipient': recipient,
        'method': method,
        'inviteCode': inviteCode,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'sent',
      });
    } catch (e) {
      LoggingService.instance.warning('Error logging invite', tag: 'InviteSystemService', error: e);
    }
  }

  /// Process incoming invite (when user signs up with invite code)
  Future<bool> processIncomingInvite(String inviteCode) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Find the invite
      final inviteQuery = await _firestore
          .collection('invites')
          .where('inviteCode', isEqualTo: inviteCode)
          .where('status', isEqualTo: 'sent')
          .limit(1)
          .get();

      if (inviteQuery.docs.isEmpty) {
        throw Exception('Invalid invite code');
      }

      final inviteDoc = inviteQuery.docs.first;
      final inviteData = inviteDoc.data();
      final inviterId = inviteData['inviterId'] as String;

      // Update invite status
      await inviteDoc.reference.update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'acceptedBy': currentUser.uid,
      });

      // Create relationship between inviter and invitee
      await _createInviteRelationship(inviterId, currentUser.uid);

      // Award points to inviter
      await _awardInvitePoints(inviterId);

      LoggingService.instance.debug('Processed incoming invite: $inviteCode', tag: 'InviteSystemService');
      return true;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error processing incoming invite', tag: 'InviteSystemService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Create relationship between inviter and invitee
  Future<void> _createInviteRelationship(String inviterId, String inviteeId) async {
    try {
      final batch = _firestore.batch();

      // Add invitee to inviter's connections
      final inviterConnectionsRef = _firestore
          .collection('users')
          .doc(inviterId)
          .collection('connections')
          .doc(inviteeId);

      batch.set(inviterConnectionsRef, {
        'userId': inviteeId,
        'type': 'invited',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Add inviter to invitee's connections
      final inviteeConnectionsRef = _firestore
          .collection('users')
          .doc(inviteeId)
          .collection('connections')
          .doc(inviterId);

      batch.set(inviteeConnectionsRef, {
        'userId': inviterId,
        'type': 'inviter',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      LoggingService.instance.error('Error creating invite relationship', tag: 'InviteSystemService', error: e);
    }
  }

  /// Award points to inviter
  Future<void> _awardInvitePoints(String inviterId) async {
    try {
      const pointsToAward = 100;
      
      await _firestore.collection('users').doc(inviterId).update({
        'points': FieldValue.increment(pointsToAward),
        'totalInvites': FieldValue.increment(1),
        'lastInviteAwardedAt': FieldValue.serverTimestamp(),
      });

      // Log the points award
      await _firestore.collection('points').add({
        'userId': inviterId,
        'points': pointsToAward,
        'type': 'invite_reward',
        'description': 'Invited a new user',
        'createdAt': FieldValue.serverTimestamp(),
      });

      LoggingService.instance.debug('Awarded $pointsToAward points to inviter: $inviterId', tag: 'InviteSystemService');
    } catch (e) {
      LoggingService.instance.error('Error awarding invite points', tag: 'InviteSystemService', error: e);
    }
  }

  /// Get user's invite statistics
  Future<InviteStats> getInviteStats(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? {};

      final sentInvitesQuery = await _firestore
          .collection('invites')
          .where('inviterId', isEqualTo: userId)
          .get();

      final acceptedInvitesQuery = await _firestore
          .collection('invites')
          .where('inviterId', isEqualTo: userId)
          .where('status', isEqualTo: 'accepted')
          .get();

      return InviteStats(
        totalInvites: sentInvitesQuery.docs.length,
        acceptedInvites: acceptedInvitesQuery.docs.length,
        totalPoints: userData['points'] as int? ?? 0,
        inviteCode: userData['inviteCode'] as String? ?? '',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error getting invite stats', tag: 'InviteSystemService', error: e, stackTrace: stackTrace);
      return InviteStats(
        totalInvites: 0,
        acceptedInvites: 0,
        totalPoints: 0,
        inviteCode: '',
      );
    }
  }
}

/// Invite statistics model
class InviteStats {
  final int totalInvites;
  final int acceptedInvites;
  final int totalPoints;
  final String inviteCode;

  InviteStats({
    required this.totalInvites,
    required this.acceptedInvites,
    required this.totalPoints,
    required this.inviteCode,
  });

  double get acceptanceRate {
    if (totalInvites == 0) return 0.0;
    return acceptedInvites / totalInvites;
  }
}
