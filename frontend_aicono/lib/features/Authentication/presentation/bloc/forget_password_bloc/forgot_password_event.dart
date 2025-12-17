abstract class ForgotPasswordEvent {}

class SendResetLinkRequested extends ForgotPasswordEvent {
  final String email;

  SendResetLinkRequested(this.email);
}
