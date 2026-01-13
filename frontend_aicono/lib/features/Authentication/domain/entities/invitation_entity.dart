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
  final bool isSetupComplete;
  final String? organizationName;
  final String? subDomain;

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
    this.isSetupComplete = false,
    this.organizationName,
    this.subDomain,
  });

  factory InvitationEntity.fromJson(Map<String, dynamic> json) {
    // Handle new API response structure
    // Extract bryteswitch_id from bryteswitch_id object or bryteswitch object
    final bryteswitchIdObj = json['bryteswitch_id'] ?? json['bryteswitch'];
    final verseId = bryteswitchIdObj != null && bryteswitchIdObj is Map
        ? (bryteswitchIdObj['_id'] ?? '')
        : (json['verse_id'] ?? json['verseId'] ?? '');

    // Extract role_id from role object
    final roleObj = json['role'];
    final roleId = roleObj != null && roleObj is Map
        ? (roleObj['_id'] ?? '')
        : (json['role_id'] ?? json['roleId'] ?? '');

    // Extract invited_by from invited_by object
    final invitedByObj = json['invited_by'];
    final invitedBy = invitedByObj != null && invitedByObj is Map
        ? (invitedByObj['_id'] ?? '')
        : (json['invited_by'] ?? json['invitedBy'] ?? '');

    // Extract email from recipient_email or email
    final email = json['recipient_email'] ?? json['email'] ?? '';

    // Determine isAccepted from status field
    final status = json['status'] ?? '';
    final isAccepted =
        status.toLowerCase() == 'accepted' ||
        status.toLowerCase() == 'completed' ||
        (json['is_accepted'] ?? json['isAccepted'] ?? false);

    // Extract is_setup_complete and organization_name from bryteswitch or bryteswitch_id object
    final bryteswitchObj = json['bryteswitch'] ?? json['bryteswitch_id'];
    final isSetupComplete = bryteswitchObj != null && bryteswitchObj is Map
        ? (bryteswitchObj['is_setup_complete'] ?? false) as bool
        : (json['is_setup_complete'] ?? false) as bool;
    final organizationName = bryteswitchObj != null && bryteswitchObj is Map
        ? (bryteswitchObj['organization_name'] ?? json['organization_name']) as String?
        : (json['organization_name'] ?? json['organizationName']) as String?;
    final subDomain = bryteswitchObj != null && bryteswitchObj is Map
        ? (bryteswitchObj['sub_domain'] ?? json['sub_domain']) as String?
        : (json['sub_domain'] ?? json['subDomain']) as String?;

    return InvitationEntity(
      id: json['_id'] ?? json['id'] ?? '',
      verseId: verseId,
      email: email,
      roleId: roleId,
      token: json['token'] ?? '',
      invitedBy: invitedBy,
      isAccepted: isAccepted,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'])
          : null,
      firstName: json['first_name'] ?? json['firstName'] ?? '',
      lastName: json['last_name'] ?? json['lastName'] ?? '',
      position: json['position'] ?? '',
      isSetupComplete: isSetupComplete,
      organizationName: organizationName,
      subDomain: subDomain,
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
      'is_setup_complete': isSetupComplete,
      'organization_name': organizationName,
      'sub_domain': subDomain,
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
    isSetupComplete,
    organizationName,
    subDomain,
  ];
}
