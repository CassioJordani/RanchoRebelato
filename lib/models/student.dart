import 'package:cloud_firestore/cloud_firestore.dart';

class Student {
  const Student({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.isActive,
    this.cpf = '',
    this.birthDate,
    this.address = '',
    this.guardianName = '',
    this.guardianRelationship = '',
    this.guardianPhone = '',
    this.guardianCpf = '',
  });

  final String id;
  final String fullName;
  final String phone;
  final bool isActive;
  final String cpf;
  final DateTime? birthDate;
  final String address;
  final String guardianName;
  final String guardianRelationship;
  final String guardianPhone;
  final String guardianCpf;

  factory Student.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data == null) {
      throw FormatException('O cadastro do aluno "${document.id}" está vazio.');
    }
    return Student.fromMap(document.id, data);
  }

  factory Student.fromMap(String id, Map<String, dynamic> data) {
    final birthDate = data['birthDate'];
    return Student(
      id: id,
      fullName: _requiredString(data, id, 'fullName'),
      phone: _optionalString(data, id, 'phone'),
      isActive: _optionalBool(data, id, 'isActive', defaultValue: true),
      cpf: _optionalString(data, id, 'cpf'),
      birthDate: birthDate == null
          ? null
          : _optionalTimestamp(data, id, 'birthDate'),
      address: _optionalString(data, id, 'address'),
      guardianName: _optionalString(data, id, 'guardianName'),
      guardianRelationship: _optionalString(data, id, 'guardianRelationship'),
      guardianPhone: _optionalString(data, id, 'guardianPhone'),
      guardianCpf: _optionalString(data, id, 'guardianCpf'),
    );
  }

  Map<String, Object?> toMap() => {
    'fullName': fullName,
    'phone': phone,
    'isActive': isActive,
    'cpf': cpf,
    'birthDate': birthDate == null ? null : Timestamp.fromDate(birthDate!),
    'address': address,
    'guardianName': guardianName,
    'guardianRelationship': guardianRelationship,
    'guardianPhone': guardianPhone,
    'guardianCpf': guardianCpf,
  };
}

String _requiredString(Map<String, dynamic> data, String id, String field) {
  final value = data[field];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('O aluno "$id" está sem um nome válido ($field).');
}

String _optionalString(Map<String, dynamic> data, String id, String field) {
  final value = data[field];
  if (value == null) return '';
  if (value is String) return value;
  throw FormatException('O campo "$field" do aluno "$id" precisa ser texto.');
}

bool _optionalBool(
  Map<String, dynamic> data,
  String id,
  String field, {
  required bool defaultValue,
}) {
  final value = data[field];
  if (value == null) return defaultValue;
  if (value is bool) return value;
  throw FormatException(
    'O campo "$field" do aluno "$id" precisa ser verdadeiro/falso.',
  );
}

DateTime _optionalTimestamp(
  Map<String, dynamic> data,
  String id,
  String field,
) {
  final value = data[field];
  if (value is Timestamp) return value.toDate();
  throw FormatException(
    'O campo "$field" do aluno "$id" precisa ser um timestamp.',
  );
}
