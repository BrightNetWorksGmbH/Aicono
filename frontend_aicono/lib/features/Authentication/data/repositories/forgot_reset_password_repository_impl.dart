import 'package:dartz/dartz.dart';
import 'package:frontend_aicono/core/error/failure.dart';
import 'package:frontend_aicono/features/Authentication/data/datasources/forgot_reset_password_remote_datasource.dart';
import 'package:frontend_aicono/features/Authentication/domain/repositories/forgot_reset_password_repository.dart';

class ForgotResetPasswordRepositoryImpl
    implements ForgotResetPasswordRepository {
  final ForgotResetPasswordRemoteDataSource remoteDataSource;

  ForgotResetPasswordRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, String>> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) async {
    return await remoteDataSource.resetPassword(
      token: token,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
  }
}
