import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/attendance_record.dart';

void main() {
  test('interpreta registro de presença', () {
    final record = AttendanceRecord.fromMap('student-1', {
      'studentId': 'student-1',
      'studentName': 'Ana Souza',
      'present': true,
    });

    expect(record.studentId, 'student-1');
    expect(record.studentName, 'Ana Souza');
    expect(record.present, isTrue);
  });

  test('interpreta falta sem converter o valor booleano', () {
    final record = AttendanceRecord.fromMap('student-1', {
      'studentId': 'student-1',
      'studentName': 'Ana Souza',
      'present': false,
    });

    expect(record.present, isFalse);
  });

  test('rejeita registro sem presença válida', () {
    expect(
      () => AttendanceRecord.fromMap('student-1', {
        'studentId': 'student-1',
        'studentName': 'Ana Souza',
        'present': 'yes',
      }),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'mensagem',
          contains('student-1'),
        ),
      ),
    );
  });
}
