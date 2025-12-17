import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';

abstract class ForgotPasswordRepository {
  Future<Either<Failure, String>> sendResetLink(String email);
}
