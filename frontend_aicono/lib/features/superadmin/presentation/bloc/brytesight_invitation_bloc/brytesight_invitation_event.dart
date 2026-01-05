import 'package:equatable/equatable.dart';

abstract class BryteSightInvitationEvent extends Equatable {
  const BryteSightInvitationEvent();

  @override
  List<Object> get props => [];
}

class SendBryteSightInvitationRequested extends BryteSightInvitationEvent {
  final String verseId;
  final String recipientEmail;

  const SendBryteSightInvitationRequested({
    required this.verseId,
    required this.recipientEmail,
  });

  @override
  List<Object> get props => [verseId, recipientEmail];
}
