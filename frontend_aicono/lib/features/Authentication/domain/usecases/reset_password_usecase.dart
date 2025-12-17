import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/reset_password_entity.dart';
import 'package:frontend_aicono/features/Authentication/domain/repositories/reset_password_repository.dart';

class ResetPasswordUseCase {
  final ResetPasswordRepository repository;

  ResetPasswordUseCase(this.repository);

  Future<Either<Failure, ResetPasswordResponse>> resetPassword(
    ResetPasswordRequest request,
  ) {
    return repository.resetPassword(request);
  }

  Future<Either<Failure, ResetPasswordResponse>> forgotPassword(String email) {
    return repository.forgotPassword(email);
  }
}
