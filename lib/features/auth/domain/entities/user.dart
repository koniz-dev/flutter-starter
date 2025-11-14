/// User entity (domain layer)
class User {
  final String id;
  final String email;
  final String? name;
  final String? avatarUrl;

  const User({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email;

  @override
  int get hashCode => id.hashCode ^ email.hashCode;
}

