import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/settings/domain/repositories/change_password_repository.dart';

class ChangePasswordUseCase {
  final ChangePasswordRepository repository;

  ChangePasswordUseCase(this.repository);

  Future<Either<Failure, void>> call(
    String currentPassword,
    String newPassword,
    String confirmPassword,
  ) =>
      repository.changePassword(
        currentPassword,
        newPassword,
        confirmPassword,
      );
}
