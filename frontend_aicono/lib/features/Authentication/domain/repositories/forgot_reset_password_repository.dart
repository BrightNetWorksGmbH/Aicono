import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';

abstract class ForgotResetPasswordRepository {
  Future<Either<Failure, String>> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  });
}
