abstract class ForgotResetPasswordEvent {}

class ResetPasswordWithTokenRequested extends ForgotResetPasswordEvent {
  final String token;
  final String newPassword;
  final String confirmPassword;

  ResetPasswordWithTokenRequested({
    required this.token,
    required this.newPassword,
    required this.confirmPassword,
  });
}
