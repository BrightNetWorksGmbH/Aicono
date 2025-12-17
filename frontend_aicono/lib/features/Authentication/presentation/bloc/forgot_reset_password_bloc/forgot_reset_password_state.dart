abstract class ForgotResetPasswordState {}

class ForgotResetPasswordInitial extends ForgotResetPasswordState {}

class ForgotResetPasswordLoading extends ForgotResetPasswordState {}

class ForgotResetPasswordSuccess extends ForgotResetPasswordState {
  final String message;

  ForgotResetPasswordSuccess(this.message);
}

class ForgotResetPasswordFailure extends ForgotResetPasswordState {
  final String message;

  ForgotResetPasswordFailure(this.message);
}
