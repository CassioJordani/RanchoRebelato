enum UserRole {
  admin,
  coordinator,
  instructor,
  viewer;

  static UserRole? fromValue(Object? value) {
    for (final role in UserRole.values) {
      if (role.name == value) return role;
    }
    return null;
  }
}
