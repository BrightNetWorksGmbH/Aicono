class AdminEntity {
  final String id;
  final String firstName;
  final String lastName;
  final String email;

  AdminEntity({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  String get fullName => '$firstName $lastName';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AdminEntity &&
        other.id == id &&
        other.firstName == firstName &&
        other.lastName == lastName &&
        other.email == email;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        firstName.hashCode ^
        lastName.hashCode ^
        email.hashCode;
  }
}
