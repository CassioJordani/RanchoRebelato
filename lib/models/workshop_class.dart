import 'package:cloud_firestore/cloud_firestore.dart';

class WorkshopClass {
  const WorkshopClass({
    required this.id,
    required this.name,
    required this.category,
    required this.instructorUid,
    required this.capacity,
    required this.isActive,
  });

  final String id;
  final String name;
  final String category;
  final String instructorUid;
  final int capacity;
  final bool isActive;

  factory WorkshopClass.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data == null) {
      throw FormatException(
        'O documento da turma "${document.id}" está vazio ou não existe.',
      );
    }
    return WorkshopClass.fromMap(document.id, data);
  }

  factory WorkshopClass.fromMap(String id, Map<String, dynamic> data) {
    return WorkshopClass(
      id: id,
      name: _requiredString(data, id, 'name'),
      category: _requiredString(data, id, 'category'),
      instructorUid: _requiredString(data, id, 'instructorUid'),
      capacity: _requiredInt(data, id, 'capacity'),
      isActive: _requiredBool(data, id, 'isActive'),
    );
  }

  Map<String, Object?> toMap() => {
    'name': name,
    'category': category,
    'instructorUid': instructorUid,
    'capacity': capacity,
    'isActive': isActive,
  };
}

String _requiredString(Map<String, dynamic> data, String id, String field) {
  final value = data[field];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException(
    'A turma "$id" está com o campo "$field" ausente, vazio ou não é texto. '
    'Confira esse campo no Firestore.',
  );
}

int _requiredInt(Map<String, dynamic> data, String id, String field) {
  final value = data[field];
  if (value is int) return value;
  throw FormatException(
    'A turma "$id" está com o campo "$field" ausente ou não é um número inteiro. '
    'Confira esse campo no Firestore.',
  );
}

bool _requiredBool(Map<String, dynamic> data, String id, String field) {
  final value = data[field];
  if (value is bool) return value;
  throw FormatException(
    'A turma "$id" está com o campo "$field" ausente ou não é verdadeiro/falso. '
    'Confira esse campo no Firestore.',
  );
}
