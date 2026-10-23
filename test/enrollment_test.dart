import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/enrollment.dart';

void main() {
  test('interpreta um documento de matrícula válido', () {
    final enrolledAt = DateTime(2026, 10, 22);
    final enrollment = Enrollment.fromMap('enrollment-1', {
      'studentId': 'student-1',
      'studentName': 'Ana Souza',
      'enrolledAt': Timestamp.fromDate(enrolledAt),
      'status': 'active',
    });

    expect(enrollment.id, 'enrollment-1');
    expect(enrollment.studentId, 'student-1');
    expect(enrollment.studentName, 'Ana Souza');
    expect(enrollment.enrolledAt, enrolledAt);
    expect(enrollment.status, 'active');
  });

  test('identifica um campo de texto ausente e o documento da matrícula', () {
    expect(
      () => Enrollment.fromMap('enrollment-1', {
        'studentId': 'student-1',
        'studentName': 'Ana Souza',
        'enrolledAt': Timestamp.fromDate(DateTime(2026, 10, 22)),
      }),
      throwsA(
        isA<FormatException>()
            .having(
              (error) => error.message,
              'mensagem',
              contains('enrollment-1'),
            )
            .having((error) => error.message, 'mensagem', contains('status')),
      ),
    );
  });

  test('exige que enrolledAt seja uma data e hora do Firestore', () {
    expect(
      () => Enrollment.fromMap('enrollment-1', {
        'studentId': 'student-1',
        'studentName': 'Ana Souza',
        'enrolledAt': '2026-10-22',
        'status': 'active',
      }),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'mensagem',
          contains('enrolledAt'),
        ),
      ),
    );
  });
}
