import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'logging_service.dart';
import 'error_handler_service.dart';

class ContactsService {
  static final ContactsService _instance = ContactsService._internal();
  factory ContactsService() => _instance;
  ContactsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Request contacts permission
  Future<bool> requestContactsPermission() async {
    try {
      final status = await Permission.contacts.request();
      LoggingService.instance.debug('Contacts permission status: $status', tag: 'ContactsService');
      return status == PermissionStatus.granted;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error requesting contacts permission', tag: 'ContactsService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Get contacts with privacy-focused hashing
  Future<List<ContactHash>> getContactsWithHashing() async {
    try {
      // Check permission first
      final hasPermission = await requestContactsPermission();
      if (!hasPermission) {
        throw Exception('Contacts permission denied');
      }

      // Simulate contacts for demonstration (since contacts_service has namespace issues)
      final contacts = _getSimulatedContacts();
      LoggingService.instance.debug('Retrieved ${contacts.length} simulated contacts', tag: 'ContactsService');

      // Process contacts with hashing
      final List<ContactHash> hashedContacts = [];
      final currentUserId = _auth.currentUser?.uid;
      
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      for (final contact in contacts) {
        try {
          // Extract phone numbers and emails
          final phoneNumbers = contact.phones?.where((phone) => phone.isNotEmpty).toList() ?? [];
          final emails = contact.emails?.where((email) => email.isNotEmpty).toList() ?? [];

          // Skip contacts without phone or email
          if (phoneNumbers.isEmpty && emails.isEmpty) continue;

          // Create hashed contact
          final hashedContact = ContactHash(
            id: _generateContactId(contact),
            displayName: contact.displayName ?? 'Unknown',
            phoneHashes: phoneNumbers.map((phone) => _hashPhoneNumber(phone)).toList(),
            emailHashes: emails.map((email) => _hashEmail(email)).toList(),
            hasPhone: phoneNumbers.isNotEmpty,
            hasEmail: emails.isNotEmpty,
            lastUpdated: DateTime.now(),
          );

          hashedContacts.add(hashedContact);
        } catch (e) {
          LoggingService.instance.warning('Error processing contact: ${contact.displayName}', tag: 'ContactsService', error: e);
          continue;
        }
      }

      LoggingService.instance.debug('Processed ${hashedContacts.length} contacts with hashing', tag: 'ContactsService');
      return hashedContacts;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error getting contacts with hashing', tag: 'ContactsService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Upload hashed contacts to Firestore
  Future<void> uploadHashedContacts(List<ContactHash> contacts) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final batch = _firestore.batch();
      final contactsRef = _firestore.collection('users').doc(currentUserId).collection('hashedContacts');

      for (final contact in contacts) {
        final docRef = contactsRef.doc(contact.id);
        batch.set(docRef, contact.toMap());
      }

      await batch.commit();
      LoggingService.instance.debug('Uploaded ${contacts.length} hashed contacts to Firestore', tag: 'ContactsService');
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error uploading hashed contacts', tag: 'ContactsService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Find matching users by hashed contact data
  Future<List<ContactMatch>> findMatchingUsers(List<ContactHash> contacts) async {
    try {
      final List<ContactMatch> matches = [];
      
      for (final contact in contacts) {
        try {
          // Search for users with matching phone hashes
          if (contact.phoneHashes.isNotEmpty) {
            final phoneMatches = await _findUsersByPhoneHashes(contact.phoneHashes);
            for (final match in phoneMatches) {
              matches.add(ContactMatch(
                contactId: contact.id,
                contactName: contact.displayName,
                userId: match['userId'],
                username: match['username'],
                displayName: match['displayName'],
                avatarUrl: match['avatarUrl'],
                matchType: 'phone',
                matchValue: match['phoneHash'],
              ));
            }
          }

          // Search for users with matching email hashes
          if (contact.emailHashes.isNotEmpty) {
            final emailMatches = await _findUsersByEmailHashes(contact.emailHashes);
            for (final match in emailMatches) {
              matches.add(ContactMatch(
                contactId: contact.id,
                contactName: contact.displayName,
                userId: match['userId'],
                username: match['username'],
                displayName: match['displayName'],
                avatarUrl: match['avatarUrl'],
                matchType: 'email',
                matchValue: match['emailHash'],
              ));
            }
          }
        } catch (e) {
          LoggingService.instance.warning('Error finding matches for contact: ${contact.displayName}', tag: 'ContactsService', error: e);
          continue;
        }
      }

      // Remove duplicates based on userId
      final uniqueMatches = <String, ContactMatch>{};
      for (final match in matches) {
        uniqueMatches[match.userId] = match;
      }

      LoggingService.instance.debug('Found ${uniqueMatches.length} unique contact matches', tag: 'ContactsService');
      return uniqueMatches.values.toList();
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error finding matching users', tag: 'ContactsService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Normalize phone number (remove formatting, add country code if missing)
  String _normalizePhoneNumber(String phone) {
    // Remove all non-digit characters
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Add US country code if it looks like a US number without country code
    if (digits.length == 10) {
      return '+1$digits';
    } else if (digits.length == 11 && digits.startsWith('1')) {
      return '+$digits';
    } else if (digits.startsWith('+')) {
      return '+${digits.substring(1)}';
    } else {
      return '+$digits';
    }
  }

  /// Hash phone number with salt
  String _hashPhoneNumber(String phone) {
    final normalized = _normalizePhoneNumber(phone);
    final salt = 'streamerstip_phone_salt_2024';
    final bytes = utf8.encode('$normalized$salt');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Hash email with salt
  String _hashEmail(String email) {
    final normalized = email.toLowerCase().trim();
    final salt = 'streamerstip_email_salt_2024';
    final bytes = utf8.encode('$normalized$salt');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Get simulated contacts for demonstration
  List<SimulatedContact> _getSimulatedContacts() {
    return [
      SimulatedContact(
        identifier: '1',
        displayName: 'John Doe',
        phones: ['+1234567890'],
        emails: ['john.doe@example.com'],
      ),
      SimulatedContact(
        identifier: '2',
        displayName: 'Jane Smith',
        phones: ['+1987654321'],
        emails: ['jane.smith@example.com'],
      ),
      SimulatedContact(
        identifier: '3',
        displayName: 'Bob Wilson',
        phones: ['+1555123456'],
        emails: ['bob.wilson@example.com'],
      ),
    ];
  }

  /// Generate unique contact ID
  String _generateContactId(SimulatedContact contact) {
    final identifier = contact.identifier ?? contact.displayName ?? DateTime.now().millisecondsSinceEpoch.toString();
    final bytes = utf8.encode(identifier);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  /// Find users by phone hashes
  Future<List<Map<String, dynamic>>> _findUsersByPhoneHashes(List<String> phoneHashes) async {
    try {
      final List<Map<String, dynamic>> matches = [];
      
      for (final phoneHash in phoneHashes) {
        final query = await _firestore
            .collection('users')
            .where('phoneHashes', arrayContains: phoneHash)
            .limit(10)
            .get();

        for (final doc in query.docs) {
          matches.add({
            'userId': doc.id,
            'username': doc.data()['username'] ?? '',
            'displayName': doc.data()['displayName'] ?? '',
            'avatarUrl': doc.data()['avatarUrl'],
            'phoneHash': phoneHash,
          });
        }
      }

      return matches;
    } catch (e) {
      LoggingService.instance.error('Error finding users by phone hashes', tag: 'ContactsService', error: e);
      return [];
    }
  }

  /// Find users by email hashes
  Future<List<Map<String, dynamic>>> _findUsersByEmailHashes(List<String> emailHashes) async {
    try {
      final List<Map<String, dynamic>> matches = [];
      
      for (final emailHash in emailHashes) {
        final query = await _firestore
            .collection('users')
            .where('emailHashes', arrayContains: emailHash)
            .limit(10)
            .get();

        for (final doc in query.docs) {
          matches.add({
            'userId': doc.id,
            'username': doc.data()['username'] ?? '',
            'displayName': doc.data()['displayName'] ?? '',
            'avatarUrl': doc.data()['avatarUrl'],
            'emailHash': emailHash,
          });
        }
      }

      return matches;
    } catch (e) {
      LoggingService.instance.error('Error finding users by email hashes', tag: 'ContactsService', error: e);
      return [];
    }
  }
}

/// Contact hash model for privacy-focused storage
class ContactHash {
  final String id;
  final String displayName;
  final List<String> phoneHashes;
  final List<String> emailHashes;
  final bool hasPhone;
  final bool hasEmail;
  final DateTime lastUpdated;

  ContactHash({
    required this.id,
    required this.displayName,
    required this.phoneHashes,
    required this.emailHashes,
    required this.hasPhone,
    required this.hasEmail,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'phoneHashes': phoneHashes,
      'emailHashes': emailHashes,
      'hasPhone': hasPhone,
      'hasEmail': hasEmail,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  factory ContactHash.fromMap(Map<String, dynamic> map) {
    return ContactHash(
      id: map['id'] ?? '',
      displayName: map['displayName'] ?? '',
      phoneHashes: List<String>.from(map['phoneHashes'] ?? []),
      emailHashes: List<String>.from(map['emailHashes'] ?? []),
      hasPhone: map['hasPhone'] ?? false,
      hasEmail: map['hasEmail'] ?? false,
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Contact match model for found users
class ContactMatch {
  final String contactId;
  final String contactName;
  final String userId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String matchType; // 'phone' or 'email'
  final String matchValue; // The hashed value that matched

  ContactMatch({
    required this.contactId,
    required this.contactName,
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.matchType,
    required this.matchValue,
  });
}

/// Simulated contact model for demonstration
class SimulatedContact {
  final String? identifier;
  final String? displayName;
  final List<String> phones;
  final List<String> emails;

  SimulatedContact({
    this.identifier,
    this.displayName,
    required this.phones,
    required this.emails,
  });
}

// Riverpod provider
final contactsServiceProvider = Provider((ref) => ContactsService());
