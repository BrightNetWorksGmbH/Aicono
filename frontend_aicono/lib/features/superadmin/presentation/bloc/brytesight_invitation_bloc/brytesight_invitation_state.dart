import 'package:equatable/equatable.dart';

abstract class BryteSightInvitationState extends Equatable {
  const BryteSightInvitationState();

  @override
  List<Object> get props => [];
}

class BryteSightInvitationInitial extends BryteSightInvitationState {}

class BryteSightInvitationLoading extends BryteSightInvitationState {}

class BryteSightInvitationSuccess extends BryteSightInvitationState {
  final String message;

  const BryteSightInvitationSuccess(this.message);

  @override
  List<Object> get props => [message];
}

class BryteSightInvitationFailure extends BryteSightInvitationState {
  final String message;

  const BryteSightInvitationFailure(this.message);

  @override
  List<Object> get props => [message];
}
