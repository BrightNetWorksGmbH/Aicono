import 'package:equatable/equatable.dart';

/// Represents a role available for assignment when inviting a user to a Bryteswitch.
class RoleEntity extends Equatable {
  final String id;
  final String name;

  const RoleEntity({required this.id, required this.name});

  factory RoleEntity.fromJson(Map<String, dynamic> json) {
    return RoleEntity(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? json['role_name'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  @override
  List<Object?> get props => [id, name];
}
