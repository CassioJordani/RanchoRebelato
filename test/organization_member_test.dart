import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/organization_member.dart';
import 'package:flutter_application_1/models/user_role.dart';

void main() {
  test('interpreta um perfil viewer recém-criado', () {
    final member = OrganizationMember.fromMap('new-user', {
      'displayName': 'Novo Usuário',
      'email': 'novo@example.com',
      'role': 'viewer',
    });

    expect(member.uid, 'new-user');
    expect(member.displayName, 'Novo Usuário');
    expect(member.email, 'novo@example.com');
    expect(member.role, UserRole.viewer);
  });

  test('permite gerenciar um membro sem perfil definido', () {
    final member = OrganizationMember.fromMap('legacy-user', {
      'email': 'legacy@example.com',
    });

    expect(member.role, isNull);
    expect(member.email, 'legacy@example.com');
  });
}
