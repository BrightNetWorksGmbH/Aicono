import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/Authentication/domain/repositories/forgot_password_repository.dart';

class SendResetLinkUseCase {
  final ForgotPasswordRepository repository;

  SendResetLinkUseCase({required this.repository});

  Future<Either<Failure, String>> call(String email) async {
    return await repository.sendResetLink(email);
  }
}
