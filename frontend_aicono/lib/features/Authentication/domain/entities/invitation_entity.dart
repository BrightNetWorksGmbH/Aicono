import 'package:equatable/equatable.dart';

class InvitationEntity extends Equatable {
  final String id; // _id ObjectId
  final String verseId; // ObjectId reference to Verses._id
  final String email;
  final String roleId; // ObjectId reference to Roles._id
  final String token; // unique token
  final String invitedBy; // ObjectId reference to Users._id
  final bool isAccepted;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final String firstName;
  final String lastName;
  final String position;

  const InvitationEntity({
    required this.id,
    required this.verseId,
    required this.email,
    required this.roleId,
    required this.token,
    required this.invitedBy,
    required this.isAccepted,
    required this.createdAt,
    this.expiresAt,
    this.acceptedAt,
    required this.firstName,
    required this.lastName,
    required this.position,
  });

  factory InvitationEntity.fromJson(Map<String, dynamic> json) {
    return InvitationEntity(
      id: json['_id'] ?? json['id'],
      verseId: json['verse_id'] ?? json['verseId'],
      email: json['email'],
      roleId: json['role_id'] ?? json['roleId'],
      token: json['token'],
      invitedBy: json['invited_by'] ?? json['invitedBy'],
      isAccepted: json['is_accepted'] ?? json['isAccepted'] ?? false,
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
      expiresAt: json['expires_at'] != null || json['expiresAt'] != null
          ? DateTime.parse(json['expires_at'] ?? json['expiresAt'])
          : null,
      acceptedAt: json['accepted_at'] != null || json['acceptedAt'] != null
          ? DateTime.parse(json['accepted_at'] ?? json['acceptedAt'])
          : null,
      firstName: json['first_name'] ?? json['firstName'] ?? '',
      lastName: json['last_name'] ?? json['lastName'] ?? '',
      position: json['position'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'verse_id': verseId,
      'email': email,
      'role_id': roleId,
      'token': token,
      'invited_by': invitedBy,
      'is_accepted': isAccepted,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'first_name': firstName,
      'last_name': lastName,
      'position': position,
    };
  }

  @override
  List<Object?> get props => [
    id,
    verseId,
    email,
    roleId,
    token,
    invitedBy,
    isAccepted,
    createdAt,
    expiresAt,
    acceptedAt,
    firstName,
    lastName,
    position,
  ];
}
