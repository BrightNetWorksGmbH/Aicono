import 'package:frontend_aicono/features/Authentication/domain/entities/invitation_entity.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/switch_role_entity.dart';
import 'dart:convert';

class User {
  final String id;
  final String email;
  final String passwordHash;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String position;
  final bool isActive;
  final bool isSuperAdmin;
  final DateTime lastLogin;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> joinedVerse;
  final List<SwitchRoleEntity> roles;
  final String token;
  final String refreshToken;
  final List<InvitationEntity> pendingInvitations;

  User({
    required this.id,
    required this.email,
    required this.passwordHash,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    required this.position,
    required this.isActive,
    this.isSuperAdmin = false,
    required this.lastLogin,
    required this.createdAt,
    required this.updatedAt,
    required this.joinedVerse,
    this.roles = const [],
    required this.token,
    required this.refreshToken,
    this.pendingInvitations = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? '',
      email: json['email'] ?? '',
      passwordHash: json['password_hash'] ?? '',
      firstName: json['first_name'] ?? json['name'] ?? '',
      position: json['position'] ?? '',
      lastName: json['last_name'] ?? '',
      avatarUrl: json['avatar_url'] ?? '',
      isActive: json['is_active'] ?? true,
      isSuperAdmin: json['is_superadmin'] ?? false,
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'])
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      joinedVerse: (() {
        final raw = json['joined_verse'];
        if (raw == null) return <String>[];
        if (raw is List) {
          if (raw.isEmpty) return <String>[];
          // If backend returns list of strings
          if (raw.first is String) {
            return List<String>.from(raw.map((e) => e.toString()));
          }
          // If backend returns list of objects, map to the 'name' field if present
          return raw
              .map<String>((e) {
                if (e is Map && e.containsKey('name')) {
                  return (e['name'] ?? '').toString();
                }
                // fallback: try common keys
                if (e is Map && e.containsKey('subdomain')) {
                  return (e['subdomain'] ?? '').toString();
                }
                return e.toString();
              })
              .where((s) => s.isNotEmpty)
              .toList();
        }
        return <String>[];
      })(),
      roles: (() {
        final raw = json['roles'];
        if (raw == null || raw is! List) return <SwitchRoleEntity>[];
        return raw
            .map<SwitchRoleEntity>(
              (e) => SwitchRoleEntity.fromJson(e as Map<String, dynamic>),
            )
            .where((r) => r.bryteswitchId.isNotEmpty)
            .toList();
      })(),
      token: json['token'] ?? '',
      refreshToken: json['refresh_token'] ?? json['token'] ?? '',
      pendingInvitations:
          (json['pending_invitations'] as List?)
              ?.map((e) => InvitationEntity.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <InvitationEntity>[],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'email': email,
      'password_hash': passwordHash,
      'first_name': firstName,
      'last_name': lastName,
      'avatar_url': avatarUrl,
      'is_active': isActive,
      'is_superadmin': isSuperAdmin,
      'last_login': lastLogin.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'joined_verse': joinedVerse,
      'roles': roles.map((e) => e.toJson()).toList(),
      'token': token,
      'refresh_token': refreshToken,
      'pending_invitations': pendingInvitations.map((e) => e.toJson()).toList(),
    };
  }

  String toJsonString() => json.encode(toJson());

  factory User.fromJsonString(String jsonString) =>
      User.fromJson(json.decode(jsonString));
}
