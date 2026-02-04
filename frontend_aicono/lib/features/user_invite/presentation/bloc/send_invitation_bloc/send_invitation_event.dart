import 'package:equatable/equatable.dart';
import 'package:frontend_aicono/features/user_invite/domain/entities/invitation_request_entity.dart';

abstract class SendInvitationEvent extends Equatable {
  const SendInvitationEvent();

  @override
  List<Object?> get props => [];
}

class SendInvitationSubmitted extends SendInvitationEvent {
  final InvitationRequestEntity request;

  const SendInvitationSubmitted({required this.request});

  @override
  List<Object?> get props => [request];
}

class SendInvitationReset extends SendInvitationEvent {}
