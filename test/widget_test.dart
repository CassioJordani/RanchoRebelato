import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/user_role.dart';

void main() {
  test('reconhece cada perfil armazenado no Firestore', () {
    expect(UserRole.fromValue('admin'), UserRole.admin);
    expect(UserRole.fromValue('coordinator'), UserRole.coordinator);
    expect(UserRole.fromValue('instructor'), UserRole.instructor);
    expect(UserRole.fromValue('viewer'), UserRole.viewer);
  });

  test('rejeita perfis desconhecidos ou ausentes', () {
    expect(UserRole.fromValue('owner'), isNull);
    expect(UserRole.fromValue(null), isNull);
  });
}
