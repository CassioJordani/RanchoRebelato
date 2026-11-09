import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/workshop_class.dart';

void main() {
  test('interpreta um documento válido de turma do Firestore', () {
    final workshopClass = WorkshopClass.fromMap('dance-1', {
      'name': 'Dança - Infantil',
      'category': 'Dança',
      'instructorUid': 'instructor-uid',
      'capacity': 15,
      'isActive': true,
    });

    expect(workshopClass.id, 'dance-1');
    expect(workshopClass.name, 'Dança - Infantil');
    expect(workshopClass.category, 'Dança');
    expect(workshopClass.instructorUid, 'instructor-uid');
    expect(workshopClass.capacity, 15);
    expect(workshopClass.isActive, isTrue);
  });

  test('identifica o campo de texto ausente e o documento da turma', () {
    expect(
      () => WorkshopClass.fromMap('dance-1', {
        'name': 'Dança - Infantil',
        'category': 'Dança',
        'capacity': 15,
        'isActive': true,
      }),
      throwsA(
        isA<FormatException>()
            .having((error) => error.message, 'message', contains('dance-1'))
            .having(
              (error) => error.message,
              'message',
              contains('instructorUid'),
            ),
      ),
    );
  });

  test('lê os dias e horários definidos para a turma', () {
    final workshopClass = WorkshopClass.fromMap('dance-1', {
      'name': 'Dança - Infantil',
      'category': 'Dança',
      'instructorUid': 'instructor-uid',
      'capacity': 15,
      'isActive': true,
      'schedule': [
        {'weekday': 2, 'startTime': '18:00', 'endTime': '19:30'},
        {'weekday': 5, 'startTime': '17:00', 'endTime': '18:00'},
      ],
    });

    expect(workshopClass.schedule, hasLength(2));
    expect(workshopClass.schedule.first.weekday, 2);
    expect(workshopClass.schedule.first.startTime, '18:00');
    expect(workshopClass.schedule.last.weekday, 5);
  });

  test('mantém compatibilidade com turma antiga sem horário cadastrado', () {
    final workshopClass = WorkshopClass.fromMap('dance-1', {
      'name': 'Dança - Infantil',
      'category': 'Dança',
      'instructorUid': 'instructor-uid',
      'capacity': 15,
      'isActive': true,
    });

    expect(workshopClass.schedule, isEmpty);
  });

  test('rejeita horário inválido ou dia repetido', () {
    expect(
      () => WorkshopClass.fromMap('dance-1', {
        'name': 'Dança - Infantil',
        'category': 'Dança',
        'instructorUid': 'instructor-uid',
        'capacity': 15,
        'isActive': true,
        'schedule': [
          {'weekday': 2, 'startTime': '19:00', 'endTime': '18:00'},
          {'weekday': 2, 'startTime': '18:00', 'endTime': '19:00'},
        ],
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
