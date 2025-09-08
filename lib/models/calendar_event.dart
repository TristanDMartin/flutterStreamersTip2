import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarEvent {
  final String id;
  String title;
  String description;
  DateTime date;

  CalendarEvent({
    String? id,
    required this.title,
    required this.description,
    required this.date,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  factory CalendarEvent.create({
    required String title,
    required String description,
    required DateTime date,
  }) {
    return CalendarEvent(
      title: title,
      description: description,
      date: date,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
    };
  }

  factory CalendarEvent.fromMap(Map<String, dynamic> map) {
    final dynamic dateValue = map['date'];
    final DateTime parsedDate = dateValue is Timestamp
        ? dateValue.toDate()
        : DateTime.tryParse(dateValue?.toString() ?? '') ?? DateTime.now();
    return CalendarEvent(
      id: (map['id'] ?? '').toString().isEmpty
          ? DateTime.now().microsecondsSinceEpoch.toString()
          : map['id'].toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      date: parsedDate,
    );
  }
}

// Note: Using a simple model (no codegen) for Firestore mapping
