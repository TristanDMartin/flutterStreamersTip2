import 'package:cloud_firestore/cloud_firestore.dart';

class ReportService {
  ReportService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<void> reportUser({
    required String reporterId,
    required String targetUserId,
    required String reason,
    String? details,
  }) async {
    final Map<String, Object?> payload = <String, Object?>{
      'reporterId': reporterId,
      'targetUserId': targetUserId,
      'reason': reason,
      'details': details,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'open',
      'type': 'user',
    };

    await _db.collection('reports').add(payload);
  }
}


