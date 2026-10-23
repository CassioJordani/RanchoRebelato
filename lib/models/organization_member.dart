import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_role.dart';

class OrganizationMember {
  const OrganizationMember({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
  });

  final String uid;
  final String displayName;
  final String email;
  final UserRole? role;

  factory OrganizationMember.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return OrganizationMember.fromMap(
      document.id,
      document.data() ?? const <String, dynamic>{},
    );
  }

  factory OrganizationMember.fromMap(String uid, Map<String, dynamic> data) {
    final displayName = data['displayName'];
    final email = data['email'];
    return OrganizationMember(
      uid: uid,
      displayName: displayName is String ? displayName : '',
      email: email is String ? email : '',
      role: UserRole.fromValue(data['role']),
    );
  }
}
