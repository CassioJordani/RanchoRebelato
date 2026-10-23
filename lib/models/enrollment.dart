import 'package:cloud_firestore/cloud_firestore.dart';

class Enrollment {
  const Enrollment({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.enrolledAt,
    required this.status,
  });

  final String id;
  final String studentId;
  final String studentName;
  final DateTime enrolledAt;
  final String status;

  factory Enrollment.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data == null) {
      throw FormatException(
        'A matrícula "${document.id}" está vazia ou não existe.',
      );
    }
    return Enrollment.fromMap(document.id, data);
  }

  factory Enrollment.fromMap(String id, Map<String, dynamic> data) {
    return Enrollment(
      id: id,
      studentId: _requiredString(data, id, 'studentId'),
      studentName: _requiredString(data, id, 'studentName'),
      enrolledAt: _requiredTimestamp(data, id, 'enrolledAt'),
      status: _requiredString(data, id, 'status'),
    );
  }

  Map<String, Object?> toMap() => {
    'studentId': studentId,
    'studentName': studentName,
    'enrolledAt': Timestamp.fromDate(enrolledAt),
    'status': status,
  };
}

String _requiredString(Map<String, dynamic> data, String id, String field) {
  final value = data[field];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException(
    'A matrícula "$id" está com o campo "$field" ausente, vazio ou não é texto. '
    'Confira esse campo no Firestore.',
  );
}

DateTime _requiredTimestamp(
  Map<String, dynamic> data,
  String id,
  String field,
) {
  final value = data[field];
  if (value is Timestamp) return value.toDate();
  throw FormatException(
    'A matrícula "$id" está com o campo "$field" ausente ou não é timestamp. '
    'Confira esse campo no Firestore.',
  );
}
