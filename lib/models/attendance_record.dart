import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceRecord {
  const AttendanceRecord({
    required this.studentId,
    required this.studentName,
    required this.present,
  });

  final String studentId;
  final String studentName;
  final bool present;

  factory AttendanceRecord.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data == null) {
      throw FormatException(
        'O registro de frequência de "${document.id}" está vazio ou não existe.',
      );
    }
    return AttendanceRecord.fromMap(document.id, data);
  }

  factory AttendanceRecord.fromMap(String id, Map<String, dynamic> data) {
    final studentId = data['studentId'];
    final studentName = data['studentName'];
    final present = data['present'];
    if (studentId is! String || studentId.trim().isEmpty) {
      throw FormatException(
        'O registro de frequência "$id" não contém um studentId válido.',
      );
    }
    if (studentName is! String || studentName.trim().isEmpty) {
      throw FormatException(
        'O registro de frequência "$id" não contém um studentName válido.',
      );
    }
    if (present is! bool) {
      throw FormatException(
        'O registro de frequência "$id" não contém uma presença válida.',
      );
    }

    return AttendanceRecord(
      studentId: studentId,
      studentName: studentName,
      present: present,
    );
  }
}
