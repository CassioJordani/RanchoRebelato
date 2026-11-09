import 'package:cloud_firestore/cloud_firestore.dart';

class WorkshopClass {
  const WorkshopClass({
    required this.id,
    required this.name,
    required this.category,
    required this.instructorUid,
    required this.capacity,
    required this.isActive,
    this.schedule = const [],
  });

  final String id;
  final String name;
  final String category;
  final String instructorUid;
  final int capacity;
  final bool isActive;
  final List<ClassSchedule> schedule;

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
      schedule: _optionalSchedule(data, id),
    );
  }

  Map<String, Object?> toMap() => {
    'name': name,
    'category': category,
    'instructorUid': instructorUid,
    'capacity': capacity,
    'isActive': isActive,
    'schedule': schedule.map((entry) => entry.toMap()).toList(),
  };
}

class ClassSchedule {
  const ClassSchedule({
    required this.weekday,
    required this.startTime,
    required this.endTime,
  });

  final int weekday;
  final String startTime;
  final String endTime;

  Map<String, Object?> toMap() => {
    'weekday': weekday,
    'startTime': startTime,
    'endTime': endTime,
  };
}

List<ClassSchedule> _optionalSchedule(Map<String, dynamic> data, String id) {
  final value = data['schedule'];
  if (value == null) return const [];
  if (value is! List) {
    throw FormatException(
      'A turma "$id" está com o campo "schedule" em formato inválido.',
    );
  }

  final schedules = <ClassSchedule>[];
  final weekdays = <int>{};
  for (final item in value) {
    if (item is! Map) {
      throw FormatException(
        'A turma "$id" contém um horário de aula inválido.',
      );
    }
    final weekday = item['weekday'];
    final startTime = item['startTime'];
    final endTime = item['endTime'];
    if (weekday is! int ||
        weekday < 1 ||
        weekday > 7 ||
        startTime is! String ||
        !_isValidTime(startTime) ||
        endTime is! String ||
        !_isValidTime(endTime) ||
        startTime.compareTo(endTime) >= 0 ||
        !weekdays.add(weekday)) {
      throw FormatException(
        'A turma "$id" contém um horário de aula inválido.',
      );
    }
    schedules.add(
      ClassSchedule(weekday: weekday, startTime: startTime, endTime: endTime),
    );
  }
  schedules.sort((a, b) => a.weekday.compareTo(b.weekday));
  return schedules;
}

bool _isValidTime(String value) =>
    RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value);

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
