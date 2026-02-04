import 'package:equatable/equatable.dart';

abstract class SendInvitationState extends Equatable {
  const SendInvitationState();

  @override
  List<Object?> get props => [];
}

class SendInvitationInitial extends SendInvitationState {}

class SendInvitationLoading extends SendInvitationState {}

class SendInvitationSuccess extends SendInvitationState {}

class SendInvitationFailure extends SendInvitationState {
  final String message;

  const SendInvitationFailure({required this.message});

  @override
  List<Object?> get props => [message];
}
