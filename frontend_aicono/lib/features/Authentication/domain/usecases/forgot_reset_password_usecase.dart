import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/Authentication/domain/repositories/forgot_reset_password_repository.dart';

class ForgotResetPasswordUseCase {
  final ForgotResetPasswordRepository repository;

  ForgotResetPasswordUseCase({required this.repository});

  Future<Either<Failure, String>> call({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) async {
    return await repository.resetPassword(
      token: token,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
  }
}
