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
}
