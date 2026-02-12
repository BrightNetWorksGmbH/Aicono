import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';

abstract class ChangePasswordRepository {
  Future<Either<Failure, void>> changePassword(
    String currentPassword,
    String newPassword,
  );
}
