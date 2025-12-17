import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/Authentication/domain/entities/register_user_entity.dart';
import 'package:frontend_aicono/features/Authentication/domain/repositories/register_user_repository.dart';

class RegisterUserUseCase {
  final RegisterUserRepository repository;

  RegisterUserUseCase({required this.repository});

  Future<Either<Failure, RegisterUserResponse>> call(
    RegisterUserRequest request,
  ) async {
    return await repository.registerUser(request);
  }
}
