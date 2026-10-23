import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  const Expense({
    required this.id,
    required this.description,
    required this.category,
    required this.amountCents,
    required this.occurredAt,
    required this.createdBy,
  });

  final String id;
  final String description;
  final String category;
  final int amountCents;
  final DateTime occurredAt;
  final String createdBy;

  factory Expense.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data == null) {
      throw FormatException('A despesa "${document.id}" está vazia.');
    }
    return Expense(
      id: document.id,
      description: _requiredString(data, document.id, 'description'),
      category: _requiredString(data, document.id, 'category'),
      amountCents: _requiredInt(data, document.id, 'amountCents'),
      occurredAt: _requiredTimestamp(data, document.id, 'occurredAt'),
      createdBy: _requiredString(data, document.id, 'createdBy'),
    );
  }

  Map<String, Object?> toMap() => {
    'description': description,
    'category': category,
    'amountCents': amountCents,
    'occurredAt': Timestamp.fromDate(occurredAt),
    'createdBy': createdBy,
  };
}

String _requiredString(Map<String, dynamic> data, String id, String field) {
  final value = data[field];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException(
    'A despesa "$id" está com o campo "$field" ausente ou inválido.',
  );
}

int _requiredInt(Map<String, dynamic> data, String id, String field) {
  final value = data[field];
  if (value is int) return value;
  throw FormatException(
    'A despesa "$id" está com o campo "$field" ausente ou não é inteiro.',
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
    'A despesa "$id" está com o campo "$field" ausente ou não é timestamp.',
  );
}
