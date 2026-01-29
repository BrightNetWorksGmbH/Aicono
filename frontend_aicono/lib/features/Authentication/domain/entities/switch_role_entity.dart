import 'package:equatable/equatable.dart';

/// Represents a role tied to a Bryteswitch (organization) from the login response.
/// Used for switch switching: user can switch between organizations they have access to.
class SwitchRoleEntity extends Equatable {
  final String roleId;
  final String roleName;
  final Map<String, dynamic> permissions;
  final String bryteswitchId;
  final String organizationName;
  final String subDomain;

  const SwitchRoleEntity({
    required this.roleId,
    required this.roleName,
    required this.permissions,
    required this.bryteswitchId,
    required this.organizationName,
    required this.subDomain,
  });

  factory SwitchRoleEntity.fromJson(Map<String, dynamic> json) {
    final perms = json['permissions'];
    return SwitchRoleEntity(
      roleId: (json['role_id'] ?? '').toString(),
      roleName: (json['role_name'] ?? '').toString(),
      permissions: perms is Map<String, dynamic>
          ? Map<String, dynamic>.from(perms)
          : <String, dynamic>{},
      bryteswitchId: (json['bryteswitch_id'] ?? '').toString(),
      organizationName: (json['organization_name'] ?? '').toString(),
      subDomain: (json['sub_domain'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'role_id': roleId,
    'role_name': roleName,
    'permissions': permissions,
    'bryteswitch_id': bryteswitchId,
    'organization_name': organizationName,
    'sub_domain': subDomain,
  };

  @override
  List<Object?> get props => [
    roleId,
    roleName,
    bryteswitchId,
    organizationName,
    subDomain,
  ];
}
