import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/student.dart';

void main() {
  test('lê do Firestore os campos opcionais do aluno', () {
    final birthDate = DateTime(2014, 6, 2);
    final student = Student.fromMap('student-1', {
      'fullName': 'Ana Souza',
      'phone': '11999990000',
      'isActive': true,
      'cpf': '12345678900',
      'birthDate': Timestamp.fromDate(birthDate),
      'address': 'Rua das Flores, 10',
      'guardianName': 'Maria Souza',
      'guardianRelationship': 'Mãe',
      'guardianPhone': '11988887777',
      'guardianCpf': '98765432100',
    });

    expect(student.cpf, '12345678900');
    expect(student.birthDate, birthDate);
    expect(student.address, 'Rua das Flores, 10');
    expect(student.guardianName, 'Maria Souza');
    expect(student.guardianRelationship, 'Mãe');
    expect(student.guardianPhone, '11988887777');
    expect(student.guardianCpf, '98765432100');
  });

  test(
    'mantém documentos antigos de alunos legíveis com campos opcionais vazios',
    () {
      final student = Student.fromMap('legacy-student', {
        'fullName': 'João Lima',
        'phone': '',
        'isActive': true,
      });

      expect(student.cpf, isEmpty);
      expect(student.birthDate, isNull);
      expect(student.address, isEmpty);
      expect(student.guardianName, isEmpty);
    },
  );
}
