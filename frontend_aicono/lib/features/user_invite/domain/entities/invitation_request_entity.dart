import 'package:equatable/equatable.dart';

/// Request parameters for sending a user invitation.
class InvitationRequestEntity extends Equatable {
  final String bryteswitchId;
  final String roleId;
  final String recipientEmail;
  final String firstName;
  final String lastName;
  final String position;
  final int expiresInDays;

  const InvitationRequestEntity({
    required this.bryteswitchId,
    required this.roleId,
    required this.recipientEmail,
    required this.firstName,
    required this.lastName,
    required this.position,
    this.expiresInDays = 7,
  });

  Map<String, dynamic> toJson() => {
    'bryteswitch_id': bryteswitchId,
    'role_id': roleId,
    'recipient_email': recipientEmail,
    'first_name': firstName,
    'last_name': lastName,
    'position': position,
    'expires_in_days': expiresInDays,
  };

  @override
  List<Object?> get props => [
    bryteswitchId,
    roleId,
    recipientEmail,
    firstName,
    lastName,
    position,
    expiresInDays,
  ];
}
